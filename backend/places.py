"""Nearby hospitals, gynaecologists, clinics, labs and breast imaging centres.

With GOOGLE_PLACES_API_KEY in backend/.env the search uses Google Places (ratings, number of reviews, a few recent reviews,
open now, phone). Without it, OpenStreetMap (Overpass API) is used: free, no key, but no ratings and fewer phone numbers.
The key stays on the server and never reaches the phone.

Results are cached for 3 days per kind and ~1 km square, so repeated searches do not use the Google allowance. Her location
is only used for the search: it is rounded to ~1 km for the cache key and never written anywhere.
"""
import json
import math
import os
import re
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Literal

from fastapi import APIRouter, HTTPException, Query, Request
from pydantic import BaseModel

import companion

router = APIRouter()

Kind = Literal["hospital", "gynae", "clinic", "lab", "imaging"]
RADIUS_M = 8000
MAX_RESULTS = 25
CACHE_SECONDS = 3 * 24 * 3600
OVERPASS = ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter"]
GOOGLE_TEXT_SEARCH = "https://places.googleapis.com/v1/places:searchText"
GOOGLE_FIELDS = ",".join(f"places.{f}" for f in ("id", "displayName", "formattedAddress", "location", "rating", "userRatingCount",
                                                   "currentOpeningHours.openNow", "nationalPhoneNumber", "googleMapsUri", "reviews"))
GOOGLE_QUERY = {"hospital": "hospital", "gynae": "gynecologist", "clinic": "medical clinic", "lab": "medical laboratory",
                "imaging": "breast ultrasound mammography imaging centre"}


class Review(BaseModel):
    rating: float | None = None
    text: str
    when: str = ""


class Place(BaseModel):
    id: str
    name: str
    lat: float
    lon: float
    distance_km: float
    address: str = ""
    phone: str | None = None
    rating: float | None = None
    rating_count: int | None = None
    open_now: bool | None = None
    maps_url: str
    reviews: list[Review] = []


class PlacesResult(BaseModel):
    kind: str
    source: Literal["google", "openstreetmap"]
    attribution: str
    places: list[Place]


def google_key() -> str | None:
    return os.environ.get("GOOGLE_PLACES_API_KEY") or None


def distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def directions_url(lat: float, lon: float) -> str:
    return f"https://www.google.com/maps/dir/?api=1&destination={lat:.6f},{lon:.6f}"


# ---------------------------------------------------------------- OpenStreetMap

def overpass_query(lat: float, lon: float, r: int = RADIUS_M) -> str:
    """Every health place around her in one query (searching names on the public server is too slow and times out)."""
    a = f"(around:{r},{lat},{lon})"
    return ("[out:json][timeout:40];("
            f'nwr["amenity"~"^(hospital|clinic|doctors)$"]{a};'
            f'nwr["healthcare"~"^(hospital|clinic|doctor|centre|laboratory|radiology|sample_collection)$"]{a};'
            ");out center tags 600;")


GYNAE = re.compile(r"gyn|matern|women|woman|mother|ladies|lady doctor|zachgi|obstet", re.I)
LAB = re.compile(r"\blab\b|laborator|diagnostic|patholog|chughtai|excel lab|sample collection", re.I)
IMAGING = re.compile(r"imaging|radiolog|x-?ray|\bscan|ultrasound|mammogra|\bmri\b|\bct\b|diagnostic", re.I)


def kinds_of(tags: dict) -> set[str]:
    """Which searches a mapped place belongs to, from its tags and its name."""
    name = f"{tags.get('name', '')} {tags.get('name:en', '')}"
    amenity, health = tags.get("amenity", ""), tags.get("healthcare", "")
    speciality = tags.get("healthcare:speciality", "")
    out = set()
    if amenity == "hospital" or health == "hospital":
        out.add("hospital")
    if amenity in ("clinic", "doctors") or health in ("clinic", "doctor", "centre"):
        out.add("clinic")
    if re.search(r"gynaecolog|gynecolog|obstetric", speciality) or GYNAE.search(name):
        out.add("gynae")
    if health in ("laboratory", "sample_collection") or LAB.search(name):
        out.add("lab")
    if health == "radiology" or re.search(r"radiolog", speciality) or IMAGING.search(name):
        out.add("imaging")
    return out


def parse_overpass(data: dict, lat: float, lon: float, kind: str | None = None) -> list[Place]:
    out = []
    for e in data.get("elements", []):
        tags = e.get("tags", {})
        if kind is not None and kind not in kinds_of(tags):
            continue
        name = tags.get("name:en") or tags.get("name")
        la, lo = e.get("lat") or e.get("center", {}).get("lat"), e.get("lon") or e.get("center", {}).get("lon")
        if not name or la is None or lo is None:
            continue
        addr = ", ".join(x for x in (tags.get("addr:street"), tags.get("addr:city")) if x)
        out.append(Place(id=f"osm-{e.get('type', 'n')}{e.get('id')}", name=name, lat=la, lon=lo,
                         distance_km=round(distance_km(lat, lon, la, lo), 2), address=addr,
                         phone=tags.get("phone") or tags.get("contact:phone"), maps_url=directions_url(la, lo)))
    return out


_areas: dict[tuple, tuple[float, dict]] = {}  # raw OpenStreetMap answer per ~1 km square, shared by all five searches


def fetch_area(lat: float, lon: float) -> dict:
    key = (round(lat, 2), round(lon, 2))
    with _lock:
        hit = _areas.get(key)
        if hit and time.time() - hit[0] < CACHE_SECONDS:
            return hit[1]
    body = urllib.parse.urlencode({"data": overpass_query(lat, lon)}).encode()
    last: Exception | None = None
    for url in OVERPASS * 2:  # the public servers are often busy: each is tried twice
        try:
            req = urllib.request.Request(url, data=body, headers={"User-Agent": "Femora/1.0 (FYP, Air University Islamabad)"})
            with urllib.request.urlopen(req, timeout=60) as r:
                data = json.load(r)
            if "runtime error" in data.get("remark", ""):  # the server gave up part-way: try the mirror
                raise RuntimeError(data["remark"])
            with _lock:
                _areas[key] = (time.time(), data)
                if len(_areas) > 200:
                    del _areas[min(_areas, key=lambda k: _areas[k][0])]
            return data
        except Exception as e:
            last = e
    raise last or RuntimeError("no answer")


def search_osm(kind: str, lat: float, lon: float) -> list[Place]:
    return parse_overpass(fetch_area(lat, lon), lat, lon, kind)


# ---------------------------------------------------------------- Google Places (New)

def parse_google(data: dict, lat: float, lon: float) -> list[Place]:
    out = []
    for p in data.get("places", []):
        loc = p.get("location", {})
        la, lo = loc.get("latitude"), loc.get("longitude")
        if la is None or lo is None:
            continue
        reviews = []
        for r in (p.get("reviews") or [])[:3]:
            text = ((r.get("text") or {}).get("text") or "").strip()
            if text:
                reviews.append(Review(rating=r.get("rating"), text=text[:400], when=r.get("relativePublishTimeDescription", "")))
        out.append(Place(id=p.get("id", ""), name=(p.get("displayName") or {}).get("text", ""), lat=la, lon=lo,
                         distance_km=round(distance_km(lat, lon, la, lo), 2), address=p.get("formattedAddress", ""),
                         phone=p.get("nationalPhoneNumber"), rating=p.get("rating"), rating_count=p.get("userRatingCount"),
                         open_now=(p.get("currentOpeningHours") or {}).get("openNow"),
                         maps_url=p.get("googleMapsUri") or directions_url(la, lo), reviews=reviews))
    return out


def search_google(kind: str, lat: float, lon: float) -> list[Place]:
    body = {"textQuery": GOOGLE_QUERY[kind], "maxResultCount": 20,
            "locationBias": {"circle": {"center": {"latitude": lat, "longitude": lon}, "radius": float(RADIUS_M)}}}
    req = urllib.request.Request(GOOGLE_TEXT_SEARCH, data=json.dumps(body).encode(), method="POST",
                                 headers={"Content-Type": "application/json", "X-Goog-Api-Key": google_key(), "X-Goog-FieldMask": GOOGLE_FIELDS})
    with urllib.request.urlopen(req, timeout=20) as r:
        return parse_google(json.load(r), lat, lon)


# ---------------------------------------------------------------- cache and endpoint

_cache: dict[tuple, tuple[float, PlacesResult]] = {}
_lock = threading.Lock()


def reset_cache() -> None:
    with _lock:
        _cache.clear()
        _areas.clear()


def nearby(kind: str, lat: float, lon: float) -> PlacesResult:
    key = (kind, round(lat, 2), round(lon, 2), google_key() is not None)
    now = time.time()
    with _lock:
        hit = _cache.get(key)
        if hit and now - hit[0] < CACHE_SECONDS:
            return hit[1]
    places: list[Place] = []
    source = "openstreetmap"
    if google_key():
        try:
            places, source = search_google(kind, lat, lon), "google"
        except Exception:
            places = []  # quota or network: fall back to OpenStreetMap rather than showing nothing
    if source == "openstreetmap":
        places = search_osm(kind, lat, lon)
    seen, unique = set(), []
    for p in sorted(places, key=lambda p: p.distance_km):
        k = (p.name.lower(), round(p.lat, 3), round(p.lon, 3))
        if k not in seen and p.distance_km <= RADIUS_M / 1000 * 1.5:
            seen.add(k)
            unique.append(p)
    result = PlacesResult(
        kind=kind, source=source, places=unique[:MAX_RESULTS],
        attribution="Ratings and reviews from Google" if source == "google" else "Map data © OpenStreetMap contributors")
    with _lock:
        _cache[key] = (now, result)
        if len(_cache) > 500:
            del _cache[min(_cache, key=lambda k: _cache[k][0])]
    return result


@router.get("/places/nearby", response_model=PlacesResult)
def places_nearby(request: Request, kind: Kind = "hospital", lat: float = Query(ge=-90, le=90), lon: float = Query(ge=-180, le=180)):
    companion.check_rate(companion.client_id(request))
    try:
        return nearby(kind, lat, lon)
    except Exception:
        raise HTTPException(502, "The map search is not answering right now. Please try again in a minute.")
