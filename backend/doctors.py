"""Find a doctor: individual women's-health doctors near her, each with a mini profile.

With GOOGLE_PLACES_API_KEY in backend/.env the search uses Google Places: many doctors in Pakistan have their own Google
profile ("Dr. Sadia Khan - Gynecologist"), with a star rating, the number of reviews, up to five recent reviews, photos,
phone, website and opening hours. Places whose name is not a doctor's (hospitals, labs) are left out, because "Nearby care"
already lists those.

Without a Google key the doctors come from Oladoc (oladoc.py), which granted Air University's team permission to use its
data for developing and demonstrating Femora (25 Sep 2026): PMDC verification, qualifications, years of experience,
rating, number of reviews, fee and the clinics she can book, each linking to the doctor's Oladoc page. If Oladoc cannot
be reached, OpenStreetMap is searched for mapped doctors instead (names only, no ratings).

The key stays on the server. Photos go through /doctors/photo so the phone never sees it. Her location is only used for
the search and, as in places.py, is rounded to ~1 km for the cache key and never stored.
"""
import json
import re
import threading
import time
import urllib.parse
import urllib.request
from typing import Literal

from fastapi import APIRouter, HTTPException, Query, Request
from fastapi.responses import Response
from pydantic import BaseModel

import companion
import oladoc
import places

router = APIRouter()

Specialty = Literal["gynae", "breast", "endocrine", "fertility"]
GOOGLE_QUERY = {"gynae": "gynecologist doctor", "breast": "breast surgeon doctor", "endocrine": "endocrinologist doctor",
                "fertility": "infertility specialist doctor"}
SPECIALTY_LABEL = {"gynae": "Gynecologist", "breast": "Breast surgeon", "endocrine": "Endocrinologist", "fertility": "Fertility specialist"}
OSM_SPECIALTY = {"gynae": r"gynaecolog|gynecolog|obstetric", "breast": r"breast|surgery|oncolog",
                 "endocrine": r"endocrin|diabet", "fertility": r"fertil|reproduct|ivf"}
GOOGLE_FIELDS = ",".join(f"places.{f}" for f in (
    "id", "displayName", "formattedAddress", "location", "rating", "userRatingCount", "currentOpeningHours.openNow",
    "regularOpeningHours.weekdayDescriptions", "nationalPhoneNumber", "websiteUri", "googleMapsUri", "reviews", "photos",
    "editorialSummary"))
RADIUS_M = 15000  # doctors are fewer than hospitals: search a wider area
MAX_RESULTS = 30
CACHE_SECONDS = 3 * 24 * 3600

# A doctor's own listing starts with a title: "Dr.", "Dr", "Doctor", "Prof.", "Assoc. Prof. Dr."
TITLE = re.compile(r"^\s*(?:(?:assoc(?:iate)?|asst|assistant)\.?\s+)?(?:prof(?:essor)?\.?\s+)?(?:dr|doctor)\b\.?|^\s*prof(?:essor)?\.?\s", re.I)
DEGREE = re.compile(r"\b(MBBS|FCPS|MCPS|MRCOG|FRCOG|FACOG|MRCP|FRCS|FRCP|DGO|MD|MS|PhD|MPhil|MSc|DMRD|FCPS-II|CHPE|DABOG|MHPE)\b", re.I)
PHOTO_REF = re.compile(r"^places/[A-Za-z0-9_-]+/photos/[A-Za-z0-9_-]+$")
CITIES = ("Islamabad", "Rawalpindi", "Lahore", "Karachi", "Peshawar", "Quetta", "Multan", "Faisalabad", "Hyderabad", "Sialkot",
          "Gujranwala", "Abbottabad", "Bahawalpur", "Sargodha", "Sukkur", "Mardan", "Gujrat", "Sahiwal", "Wah Cantt", "Taxila")


class DoctorReview(BaseModel):
    author: str = ""
    rating: float | None = None
    text: str
    when: str = ""


class Clinic(BaseModel):
    name: str
    area: str = ""
    fee: int | None = None  # rupees
    available: str = ""  # "Available tomorrow"
    booking_url: str


class Doctor(BaseModel):
    id: str
    name: str
    specialty: str  # what her own listing says, else the specialty searched for
    qualifications: list[str] = []
    about: str = ""
    address: str = ""
    city: str = ""
    lat: float
    lon: float
    distance_km: float | None = None  # None: no clinic location known (e.g. online consultations only)
    experience_years: int | None = None
    wait_time: str = ""
    pmdc_verified: bool = False
    fee: int | None = None  # the lowest consultation fee, rupees
    clinics: list[Clinic] = []
    profile_url: str | None = None
    phone: str | None = None
    website: str | None = None
    rating: float | None = None
    rating_count: int | None = None
    open_now: bool | None = None
    hours: list[str] = []
    reviews: list[DoctorReview] = []
    photo: str | None = None  # a Google photo reference, fetched through /doctors/photo
    photo_credit: str = ""
    maps_url: str
    oladoc_url: str


class DoctorsResult(BaseModel):
    specialty: str
    source: Literal["google", "oladoc", "openstreetmap"]
    attribution: str
    doctors: list[Doctor]


# ---------------------------------------------------------------- reading a listing

def is_doctor(name: str) -> bool:
    return bool(TITLE.match(name))


def split_name(raw: str, fallback_specialty: str) -> tuple[str, str, list[str]]:
    """'Dr. Sadia Khan (MBBS, FCPS) - Gynecologist' -> ('Dr. Sadia Khan', 'Gynecologist', ['MBBS', 'FCPS'])."""
    quals = list(dict.fromkeys(m.upper() for m in DEGREE.findall(raw)))
    name = re.split(r"\s[-|–—,]\s|\s\(|\(|\||,", raw, maxsplit=1)[0].strip(" -–—|,")
    name = DEGREE.sub("", name).strip(" -–—|,")
    rest = raw[len(name):]
    rest = DEGREE.sub("", re.sub(r"[()]", " ", rest))
    rest = re.sub(r"\s+", " ", rest).strip(" -–—|,/")
    specialty = rest if 3 <= len(rest) <= 60 and re.search(r"[A-Za-z]{3}", rest) else fallback_specialty
    return name or raw.strip(), specialty, quals


def city_of(address: str) -> str:
    for c in CITIES:
        if c.lower() in address.lower():
            return c
    return ""


def oladoc_search(name: str, specialty: str, city: str) -> str:
    q = " ".join(x for x in ("site:oladoc.com", name, specialty, city) if x)
    return "https://www.google.com/search?q=" + urllib.parse.quote_plus(q)


def rank(d: Doctor) -> tuple:
    """Best first: a rating backed by many reviews beats a perfect score from two, then the nearer doctor."""
    far = d.distance_km if d.distance_km is not None else 1e9
    if d.rating is None:
        return (1, 0.0, far)
    n = d.rating_count or 0
    bayes = (d.rating * n + 4.2 * 8) / (n + 8)
    return (0, -bayes, far)


def from_oladoc(raw: dict, lat: float, lon: float, specialty: str, city: str) -> Doctor:
    """One doctor from an Oladoc listing: the nearest of her clinics gives the distance."""
    spots = sorted(raw["spots"], key=lambda s: places.distance_km(lat, lon, s[0], s[1]))
    la, lo = (spots[0][0], spots[0][1]) if spots else oladoc.CITIES.get(city, (lat, lon))
    online = any("online" in c["name"].lower() for c in raw["clinics"])
    if spots and online and places.distance_km(lat, lon, spots[0][0], spots[0][1]) > 60:
        spots = []  # a city listing can include a doctor from another city who consults online: shown as "Online"
    fees = [c["fee"] for c in raw["clinics"] if c.get("fee")]
    quals = [q.strip() for q in re.split(r",\s*(?![^()]*\))", raw["qualifications"]) if q.strip()]
    return Doctor(
        id="ola-" + raw["url"].rstrip("/").rsplit("/", 1)[-1], name=raw["name"], specialty=raw["specialty"] or SPECIALTY_LABEL[specialty],
        qualifications=quals[:6], about=raw.get("about", ""), address=raw.get("address") or (spots[0][2] if spots else ""), city=city,
        lat=la, lon=lo, distance_km=round(places.distance_km(lat, lon, la, lo), 2) if spots else None,
        experience_years=raw["experience_years"], wait_time=raw["wait_time"], pmdc_verified=raw["pmdc_verified"],
        fee=min(fees) if fees else None, clinics=[Clinic(**c) for c in raw["clinics"]], profile_url=raw["url"],
        rating=raw["rating"], rating_count=raw["rating_count"], photo=raw["photo"],
        maps_url=places.directions_url(la, lo), oladoc_url=raw["url"])


def search_oladoc(specialty: str, lat: float, lon: float) -> list[Doctor]:
    city = oladoc.nearest_city(lat, lon)
    return [from_oladoc(raw, lat, lon, specialty, city) for raw in oladoc.fetch_listing(specialty, city)]


def parse_google(data: dict, lat: float, lon: float, specialty: str) -> list[Doctor]:
    out = []
    for p in data.get("places", []):
        raw = (p.get("displayName") or {}).get("text", "")
        loc = p.get("location") or {}
        la, lo = loc.get("latitude"), loc.get("longitude")
        if not is_doctor(raw) or la is None or lo is None:
            continue
        name, spec, quals = split_name(raw, SPECIALTY_LABEL[specialty])
        address = p.get("formattedAddress", "")
        reviews = []
        for r in (p.get("reviews") or [])[:5]:
            text = ((r.get("text") or {}).get("text") or "").strip()
            if text:
                reviews.append(DoctorReview(author=(r.get("authorAttribution") or {}).get("displayName", ""), rating=r.get("rating"),
                                            text=text[:600], when=r.get("relativePublishTimeDescription", "")))
        photos = p.get("photos") or []
        credit = ", ".join(a.get("displayName", "") for a in (photos[0].get("authorAttributions") or [])) if photos else ""
        city = city_of(address)
        out.append(Doctor(
            id=p.get("id", ""), name=name, specialty=spec, qualifications=quals,
            about=((p.get("editorialSummary") or {}).get("text") or ""), address=address, city=city, lat=la, lon=lo,
            distance_km=round(places.distance_km(lat, lon, la, lo), 2), phone=p.get("nationalPhoneNumber"), website=p.get("websiteUri"),
            rating=p.get("rating"), rating_count=p.get("userRatingCount"), open_now=(p.get("currentOpeningHours") or {}).get("openNow"),
            hours=(p.get("regularOpeningHours") or {}).get("weekdayDescriptions") or [], reviews=reviews,
            photo=photos[0].get("name") if photos else None, photo_credit=credit,
            maps_url=p.get("googleMapsUri") or places.directions_url(la, lo), oladoc_url=oladoc_search(name, spec, city)))
    return out


def search_google(specialty: str, lat: float, lon: float) -> list[Doctor]:
    body = {"textQuery": GOOGLE_QUERY[specialty], "pageSize": 20,
            "locationBias": {"circle": {"center": {"latitude": lat, "longitude": lon}, "radius": float(RADIUS_M)}}}
    req = urllib.request.Request(places.GOOGLE_TEXT_SEARCH, data=json.dumps(body).encode(), method="POST",
                                 headers={"Content-Type": "application/json", "X-Goog-Api-Key": places.google_key(),
                                          "X-Goog-FieldMask": GOOGLE_FIELDS})
    with urllib.request.urlopen(req, timeout=20) as r:
        return parse_google(json.load(r), lat, lon, specialty)


def search_osm(specialty: str, lat: float, lon: float) -> list[Doctor]:
    out = []
    pattern = re.compile(OSM_SPECIALTY[specialty], re.I)
    for e in places.fetch_area(lat, lon).get("elements", []):
        tags = e.get("tags", {})
        raw = tags.get("name:en") or tags.get("name") or ""
        la, lo = e.get("lat") or e.get("center", {}).get("lat"), e.get("lon") or e.get("center", {}).get("lon")
        if not is_doctor(raw) or la is None or lo is None:
            continue
        if not pattern.search(f"{tags.get('healthcare:speciality', '')} {raw}") and not (specialty == "gynae" and places.GYNAE.search(raw)):
            continue
        name, spec, quals = split_name(raw, SPECIALTY_LABEL[specialty])
        address = ", ".join(x for x in (tags.get("addr:street"), tags.get("addr:city")) if x)
        city = tags.get("addr:city") or city_of(address)
        out.append(Doctor(id=f"osm-{e.get('type', 'n')}{e.get('id')}", name=name, specialty=spec, qualifications=quals, address=address,
                          city=city, lat=la, lon=lo, distance_km=round(places.distance_km(lat, lon, la, lo), 2),
                          phone=tags.get("phone") or tags.get("contact:phone"), website=tags.get("website"),
                          maps_url=places.directions_url(la, lo), oladoc_url=oladoc_search(name, spec, city)))
    return out


# ---------------------------------------------------------------- cache and endpoints

_cache: dict[tuple, tuple[float, DoctorsResult]] = {}
_photos: dict[str, tuple[float, bytes, str]] = {}
_lock = threading.Lock()


def reset_cache() -> None:
    with _lock:
        _cache.clear()
        _photos.clear()


def nearby_doctors(specialty: str, lat: float, lon: float) -> DoctorsResult:
    key = (specialty, round(lat, 2), round(lon, 2), places.google_key() is not None)
    now = time.time()
    with _lock:
        hit = _cache.get(key)
        if hit and now - hit[0] < CACHE_SECONDS:
            return hit[1]
    # Google when a key is set, else Oladoc (used with its permission), else the free map
    found: list[Doctor] = []
    source = ""
    if places.google_key():
        try:
            found, source = search_google(specialty, lat, lon), "google"
        except Exception:
            found = []  # quota or network: try the next source rather than showing nothing
    if not source:
        try:
            found = search_oladoc(specialty, lat, lon)
            source = "oladoc" if found else ""
        except Exception:
            found = []
    if not source:
        found, source = search_osm(specialty, lat, lon), "openstreetmap"
    seen, unique = set(), []
    for d in sorted(found, key=rank):
        k = (d.name.lower(), round(d.lat, 3), round(d.lon, 3))
        # Oladoc lists a whole city; the others are searched around her, so far-off matches are dropped
        near = source == "oladoc" or (d.distance_km is not None and d.distance_km <= RADIUS_M / 1000 * 2)
        if k not in seen and near:
            seen.add(k)
            unique.append(d)
    result = DoctorsResult(specialty=specialty, source=source, doctors=unique[:MAX_RESULTS], attribution={
        "google": "Ratings, reviews and photos from Google",
        "oladoc": "Doctor listings, ratings and fees from oladoc.com, used with Oladoc's permission",
        "openstreetmap": "Map data © OpenStreetMap contributors"}[source])
    with _lock:
        _cache[key] = (now, result)
        if len(_cache) > 300:
            del _cache[min(_cache, key=lambda k: _cache[k][0])]
    return result


def fetch_photo(ref: str) -> tuple[bytes, str]:
    with _lock:
        hit = _photos.get(ref)
        if hit and time.time() - hit[0] < CACHE_SECONDS:
            return hit[1], hit[2]
    if ref.startswith(oladoc.IMAGE_HOSTS):  # Oladoc's photo, passed through so the app on the web can show it
        url = ref
    else:
        url = f"https://places.googleapis.com/v1/{ref}/media?maxWidthPx=320&maxHeightPx=320&key={urllib.parse.quote(places.google_key() or '')}"
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": oladoc.USER_AGENT}), timeout=20) as r:
        data, mime = r.read(), r.headers.get("Content-Type", "image/jpeg")
    with _lock:
        _photos[ref] = (time.time(), data, mime)
        if len(_photos) > 400:
            del _photos[min(_photos, key=lambda k: _photos[k][0])]
    return data, mime


@router.get("/doctors/nearby", response_model=DoctorsResult)
def doctors_nearby(request: Request, specialty: Specialty = "gynae", lat: float = Query(ge=-90, le=90), lon: float = Query(ge=-180, le=180)):
    companion.check_rate(companion.client_id(request))
    try:
        return nearby_doctors(specialty, lat, lon)
    except Exception:
        raise HTTPException(502, "The doctor search is not answering right now. Please try again in a minute.")


@router.get("/doctors/photo")
def doctor_photo(ref: str = Query(max_length=600)):
    google_photo = PHOTO_REF.match(ref) and places.google_key()
    if not google_photo and not ref.startswith(oladoc.IMAGE_HOSTS):
        raise HTTPException(404, "No photo.")
    try:
        data, mime = fetch_photo(ref)
    except Exception:
        raise HTTPException(404, "No photo.")
    return Response(content=data, media_type=mime, headers={"Cache-Control": "public, max-age=86400"})
