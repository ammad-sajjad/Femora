import pytest
from fastapi.testclient import TestClient

import app as api
import companion
import places

ISB = (33.6844, 73.0479)

OSM = {"elements": [
    {"type": "node", "id": 1, "lat": 33.70, "lon": 73.05, "tags": {"name": "Far Hospital", "amenity": "hospital", "phone": "051-111"}},
    {"type": "way", "id": 2, "center": {"lat": 33.685, "lon": 73.048}, "tags": {"name": "Near Hospital", "amenity": "hospital"}},
    {"type": "node", "id": 3, "lat": 33.686, "lon": 73.05, "tags": {"amenity": "hospital"}},  # no name: skipped
    {"type": "node", "id": 4, "lat": 33.685, "lon": 73.048, "tags": {"name": "Near Hospital"}},  # duplicate: skipped
]}

GOOGLE = {"places": [{
    "id": "g1", "displayName": {"text": "Women's Care Clinic"}, "formattedAddress": "F-8, Islamabad",
    "location": {"latitude": 33.71, "longitude": 73.04}, "rating": 4.6, "userRatingCount": 212,
    "currentOpeningHours": {"openNow": True}, "nationalPhoneNumber": "0300 1234567", "googleMapsUri": "https://maps.google.com/?cid=1",
    "reviews": [{"rating": 5, "text": {"text": "Very kind doctor."}, "relativePublishTimeDescription": "a month ago"}],
}]}


@pytest.fixture(autouse=True)
def _reset(monkeypatch):
    places.reset_cache()
    companion.reset_rate_limits()
    monkeypatch.delenv("GOOGLE_PLACES_API_KEY", raising=False)


def test_distance():
    assert places.distance_km(33.6844, 73.0479, 33.6844, 73.0479) == 0
    assert 260 <= places.distance_km(33.6844, 73.0479, 31.5204, 74.3587) <= 280  # Islamabad to Lahore, straight line ~270 km


def test_openstreetmap_results_are_named_deduplicated_and_nearest_first(monkeypatch):
    calls = []

    class R:
        def __init__(self, d):
            import io, json
            self.b = io.BytesIO(json.dumps(d).encode())

        def read(self, *a):
            return self.b.read(*a)

        def __enter__(self):
            return self

        def __exit__(self, *a):
            pass

    monkeypatch.setattr(places.urllib.request, "urlopen", lambda req, timeout: calls.append(req.full_url) or R(OSM))
    r = TestClient(api.app).get("/places/nearby", params={"kind": "hospital", "lat": ISB[0], "lon": ISB[1]}).json()
    assert r["source"] == "openstreetmap" and "OpenStreetMap" in r["attribution"]
    assert [p["name"] for p in r["places"]] == ["Near Hospital", "Far Hospital"]
    assert r["places"][1]["phone"] == "051-111" and r["places"][0]["rating"] is None
    assert r["places"][0]["maps_url"].startswith("https://www.google.com/maps/dir/?api=1&destination=33.685")
    # the same search again comes from the cache
    TestClient(api.app).get("/places/nearby", params={"kind": "hospital", "lat": ISB[0] + 0.0004, "lon": ISB[1]})  # same ~1 km square
    assert len(calls) == 1


def test_google_gives_ratings_reviews_and_open_now(monkeypatch):
    monkeypatch.setenv("GOOGLE_PLACES_API_KEY", "k")
    seen = {}
    monkeypatch.setattr(places, "search_google", lambda kind, lat, lon: seen.update(kind=kind) or places.parse_google(GOOGLE, lat, lon))
    r = TestClient(api.app).get("/places/nearby", params={"kind": "gynae", "lat": ISB[0], "lon": ISB[1]}).json()
    p = r["places"][0]
    assert r["source"] == "google" and seen["kind"] == "gynae"
    assert (p["rating"], p["rating_count"], p["open_now"]) == (4.6, 212, True)
    assert p["reviews"][0]["text"] == "Very kind doctor." and p["maps_url"] == "https://maps.google.com/?cid=1"


def test_google_failing_falls_back_to_openstreetmap(monkeypatch):
    monkeypatch.setenv("GOOGLE_PLACES_API_KEY", "k")

    def boom(*a):
        raise RuntimeError("quota")

    monkeypatch.setattr(places, "search_google", boom)
    monkeypatch.setattr(places, "search_osm", lambda kind, lat, lon: places.parse_overpass(OSM, lat, lon))
    r = TestClient(api.app).get("/places/nearby", params={"kind": "hospital", "lat": ISB[0], "lon": ISB[1]}).json()
    assert r["source"] == "openstreetmap" and r["places"]


def test_one_query_fetches_every_health_place_around_her():
    q = places.overpass_query(*ISB)
    assert q.startswith("[out:json]") and "around:8000,33.6844,73.0479" in q and "laboratory" in q


@pytest.mark.parametrize("tags,expected", [
    ({"amenity": "hospital", "name": "PIMS"}, {"hospital"}),
    ({"amenity": "clinic", "name": "Alrehman Family Clinic -- Lady Doctor Samina"}, {"clinic", "gynae"}),
    ({"amenity": "hospital", "healthcare:speciality": "general;gynaecology"}, {"hospital", "gynae"}),
    ({"healthcare": "laboratory", "name": "Chughtai Lab"}, {"lab"}),
    ({"amenity": "clinic", "name": "Islamabad Diagnostic Centre"}, {"clinic", "lab", "imaging"}),
    ({"amenity": "doctors", "name": "City Ultrasound and X-Ray"}, {"clinic", "imaging"}),
    ({"amenity": "hospital", "name": "Maternity Hospital"}, {"hospital", "gynae"}),
])
def test_places_are_sorted_into_the_right_searches(tags, expected):
    assert places.kinds_of(tags) == expected


def test_the_area_is_fetched_once_for_all_searches(monkeypatch):
    calls = []
    monkeypatch.setattr(places, "fetch_area", lambda lat, lon: calls.append(1) or OSM)
    c = TestClient(api.app)
    c.get("/places/nearby", params={"kind": "hospital", "lat": ISB[0], "lon": ISB[1]})
    c.get("/places/nearby", params={"kind": "hospital", "lat": ISB[0], "lon": ISB[1]})
    assert len(calls) == 1


def test_bad_input_and_outage(monkeypatch):
    c = TestClient(api.app)
    assert c.get("/places/nearby", params={"kind": "spa", "lat": 1, "lon": 1}).status_code == 422
    assert c.get("/places/nearby", params={"lat": 100, "lon": 1}).status_code == 422
    monkeypatch.setattr(places, "search_osm", lambda *a: (_ for _ in ()).throw(RuntimeError("down")))
    assert c.get("/places/nearby", params={"lat": 1, "lon": 1}).status_code == 502
