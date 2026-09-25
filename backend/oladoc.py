"""Doctor listings from Oladoc, used with Oladoc's permission.

Oladoc (hello@oladoc.com, 25 Sep 2026) granted Air University's team permission to use its data for developing and
demonstrating Femora, and offered an official API key later. Until that key arrives, this reads Oladoc's public listing
pages for a specialty in a city ("Gynecologist in Islamabad"), gently: at most three pages (30 doctors) per search, one
request at a time, a clear user agent, and every result cached for a day. When the API key comes, only fetch_listing()
needs to change.

Each listing page has, per doctor, a card (name, PMDC verified, specialties, qualifications, wait time, years of
experience, rating, number of reviews, photo, clinics with fee and availability) and a schema.org Physician record with
the clinics' map coordinates, which give the distance from her.
"""
import html as htmllib
import json
import math
import re
import threading
import time
import urllib.request

BASE = "https://oladoc.com/pakistan"
USER_AGENT = "Femora/1.0 (Air University Islamabad FYP; academic use with Oladoc's permission)"
PAGES = 3  # 10 doctors a page
CACHE_SECONDS = 24 * 3600
SLUG = {"gynae": "gynecologist", "breast": "breast-surgeon", "endocrine": "endocrinologist", "fertility": "fertility-consultant"}
CITIES = {  # Oladoc has a listing for every one of these (checked 25 Sep 2026)
    "Islamabad": (33.6844, 73.0479), "Rawalpindi": (33.5651, 73.0169), "Lahore": (31.5204, 74.3587), "Karachi": (24.8607, 67.0011),
    "Peshawar": (34.0151, 71.5249), "Quetta": (30.1798, 66.9750), "Multan": (30.1575, 71.5249), "Faisalabad": (31.4504, 73.1350),
    "Hyderabad": (25.3960, 68.3578), "Sialkot": (32.4945, 74.5229), "Gujranwala": (32.1877, 74.1945), "Abbottabad": (34.1688, 73.2215),
}
IMAGE_HOSTS = ("https://d1t78adged64l7.cloudfront.net/", "https://s3-eu-west-1.amazonaws.com/mdpk/")


def distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    p1, p2 = math.radians(lat1), math.radians(lat2)
    a = math.sin((p2 - p1) / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(math.radians(lon2 - lon1) / 2) ** 2
    return 2 * 6371.0 * math.asin(math.sqrt(a))


def nearest_city(lat: float, lon: float) -> str:
    return min(CITIES, key=lambda c: distance_km(lat, lon, *CITIES[c]))


def _text(fragment: str) -> str:
    return re.sub(r"\s+", " ", htmllib.unescape(re.sub(r"<[^>]+>", " ", fragment))).strip()


def _int(s: str) -> int | None:
    digits = re.sub(r"[^\d]", "", s or "")
    return int(digits) if digits else None


def _physicians(page: str) -> dict[str, dict]:
    """The schema.org Physician records on a page, by profile address."""
    out = {}
    for block in re.findall(r'<script type="application/ld\+json"[^>]*>(.*?)</script>', page, re.S):
        try:
            d = json.loads(block, strict=False)
        except ValueError:
            continue
        if isinstance(d, dict) and d.get("@type") == "Physician" and d.get("url"):
            out[d["url"]] = d
    return out


def parse_listing(page: str) -> list[dict]:
    """Every doctor card on one listing page, as plain dicts (doctors.py turns them into Doctor records)."""
    records = _physicians(page)
    body = re.sub(r"<script.*?</script>", "", page, flags=re.S)
    starts = [m.start() for m in re.finditer(r'<div class="card doc-listing-card', body)]
    out = []
    for i, s in enumerate(starts):
        # the last card runs on to the end of the page, so each card is capped (a real card is ~15 KB)
        card = re.sub(r"<svg.*?</svg>|<!--.*?-->", "", body[s: min(starts[i + 1] if i + 1 < len(starts) else len(body), s + 40000)], flags=re.S)
        m = re.search(r'<a class="doctor-name[^"]*" href="([^"]+)"[^>]*>(.*?)</a>', card, re.S)
        if not m:
            continue
        url, name = m.group(1), _text(m.group(2))
        paras = [_text(p) for p in re.findall(r'<p class="mb-1[^"]*">(.*?)</p>', card, re.S)]
        stats = {}
        # (no lazy or nested whitespace groups here: those backtracked for seconds on every card)
        for value, label in re.findall(r'<span class="font-weight-medium[^"]*">([^<]*)</span>\s*<span class="od-wte-text-muted">([^<]*)</span>', card):
            stats.setdefault(label.strip(), value.strip())
        rating = re.search(r'review-with-icon">\s*([\d.]+)\s*<', card)
        reviews = re.search(r'<span class="d-inline-block[^"]*">\s*([\d,]+)\s*</span>\s*Reviews', card)
        photo = re.search(r'<img[^>]*?src="(https://[^"]+)"', card)
        # A clinic appears in the booking list and again as a small card (some doctors only have the cards): one per booking link
        clinics, known = [], set()
        for booking, block in re.findall(r'<a href="(https://oladoc\.com/appointment/[^"]+)" class="border-bottom[^"]*"[^>]*>(.*?)</a>', card, re.S):
            head = re.search(r'appointment-location-main-heading">(.*?)</strong>', block, re.S)
            fee = re.search(r"</small>\s*([\d,]+)\s*</strong>", block)
            area = re.search(r'onlin-vc-text">(.*?)</span>', block, re.S)
            when = re.search(r'<span class="col pl-0">(.*?)</span>', block, re.S)
            if head and booking not in known:
                known.add(booking)
                clinics.append({"name": _text(head.group(1)), "area": _text(area.group(1)) if area else "", "fee": _int(fee.group(1)) if fee else None,
                                "available": _text(when.group(1)) if when else "", "booking_url": booking})
        for booking, block in re.findall(r'<a href="(https://oladoc\.com/appointment/[^"]+)" class="frame[^"]*"[^>]*>(.*?)</a>', card, re.S):
            head = re.search(r'<span class="text-truncate[^"]*">(.*?)</span>', block, re.S)
            fee = re.search(r'doctor-fee">\s*Rs\.\s*([\d,]+)', block)
            when = re.search(r"(Available [^<]+|Online)\s*<", block)
            if head and booking not in known:
                known.add(booking)
                clinics.append({"name": _text(head.group(1)), "area": "", "fee": _int(fee.group(1)) if fee else None,
                                "available": _text(when.group(1)) if when else "", "booking_url": booking})
        rec = records.get(url, {})
        spots = [(a["geoMidpoint"]["latitude"], a["geoMidpoint"]["longitude"], a.get("name", ""))
                 for a in (rec.get("areaServed") or []) if isinstance(a, dict) and a.get("geoMidpoint")]
        hospital = rec.get("hospitalAffiliation") or {}
        address = (hospital.get("address") or {}).get("streetAddress", "") if isinstance(hospital, dict) else ""
        services = (rec.get("AvailableService") or {}).get("name") or []
        experience = re.search(r"(\d+)", stats.get("Experience", ""))
        out.append({
            "url": url, "name": name,
            "specialty": paras[0] if paras else "",
            "qualifications": paras[1] if len(paras) > 1 else "",
            "pmdc_verified": "PMDC Verified" in card,
            "wait_time": stats.get("Wait Time", ""),
            "experience_years": int(experience.group(1)) if experience else None,
            "rating": float(rating.group(1)) if rating else None,
            "rating_count": _int(reviews.group(1)) if reviews else None,
            "photo": photo.group(1) if photo and photo.group(1).startswith(IMAGE_HOSTS) else None,
            "clinics": clinics,
            "spots": spots,
            "address": address,
            "about": services[1] if len(services) > 1 and isinstance(services[1], str) else "",
        })
    return out


_cache: dict[tuple, tuple[float, list[dict]]] = {}
_lock = threading.Lock()  # one fetch at a time, so a burst of searches never becomes a burst of requests to Oladoc


def reset_cache() -> None:
    with _lock:
        _cache.clear()


def _get(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept-Language": "en"})
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.read().decode("utf-8", "replace")


def fetch_listing(specialty: str, city: str) -> list[dict]:
    key = (specialty, city)
    with _lock:
        hit = _cache.get(key)
        if hit and time.time() - hit[0] < CACHE_SECONDS:
            return hit[1]
        doctors, seen = [], set()
        base = f"{BASE}/{city.lower().replace(' ', '-')}/{SLUG[specialty]}"
        for page in range(PAGES):
            try:
                found = parse_listing(_get(base if page == 0 else f"{base}/{page * 10}"))
            except Exception:
                if page == 0:
                    raise
                break
            new = [d for d in found if d["url"] not in seen]
            if not new:
                break
            seen.update(d["url"] for d in new)
            doctors += new
            time.sleep(0.5)
        _cache[key] = (time.time(), doctors)
        return doctors
