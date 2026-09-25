import pytest
from fastapi.testclient import TestClient

import app as api
import companion
import doctors
import oladoc
import places

ISB = (33.6844, 73.0479)
client = TestClient(api.app)

GOOGLE = {"places": [
    {"id": "d1", "displayName": {"text": "Dr. Sadia Khan (MBBS, FCPS) - Gynecologist"}, "formattedAddress": "F-8 Markaz, Islamabad, Pakistan",
     "location": {"latitude": 33.71, "longitude": 73.04}, "rating": 4.9, "userRatingCount": 3,
     "currentOpeningHours": {"openNow": True}, "nationalPhoneNumber": "0300 1234567", "googleMapsUri": "https://maps.google.com/?cid=1",
     "regularOpeningHours": {"weekdayDescriptions": ["Monday: 5:00 – 9:00 PM"]},
     "photos": [{"name": "places/d1/photos/p1", "authorAttributions": [{"displayName": "Clinic owner"}]}],
     "reviews": [{"rating": 5, "text": {"text": "Listened patiently."}, "relativePublishTimeDescription": "a month ago",
                  "authorAttribution": {"displayName": "Ayesha"}}]},
    {"id": "d2", "displayName": {"text": "Prof. Dr. Nasreen Akhtar | Obstetrician & Gynaecologist"}, "formattedAddress": "Saddar, Rawalpindi",
     "location": {"latitude": 33.60, "longitude": 73.05}, "rating": 4.7, "userRatingCount": 240},
    {"id": "h1", "displayName": {"text": "Shifa International Hospital"}, "formattedAddress": "H-8, Islamabad",
     "location": {"latitude": 33.68, "longitude": 73.07}, "rating": 4.2, "userRatingCount": 9000},
]}


@pytest.fixture(autouse=True)
def _reset(monkeypatch):
    doctors.reset_cache()
    places.reset_cache()
    oladoc.reset_cache()
    companion.reset_rate_limits()
    monkeypatch.delenv("GOOGLE_PLACES_API_KEY", raising=False)
    # tests never reach oladoc.com; the tests that need it put in a page
    monkeypatch.setattr(oladoc, "_get", lambda url: (_ for _ in ()).throw(OSError("offline")))


# One doctor card as it appears on an Oladoc listing page (trimmed), with its schema.org record
OLADOC_PAGE = """
<script type="application/ld+json">{"@context": "http://schema.org", "@type": "Physician", "name": "Prof. Dr. Ghazala Sadiq",
 "url": "https://oladoc.com/pakistan/islamabad/dr/gynecologist/ghazala-sadiq/3817",
 "areaServed": [{"name": "Peshawar Road, Rawalpindi", "@type": "GeoCircle", "geoMidpoint": {"latitude": 33.6000, "longitude": 73.0380}},
                {"name": "H-13, Islamabad", "@type": "GeoCircle", "geoMidpoint": {"latitude": 33.6248, "longitude": 72.9730}}],
 "hospitalAffiliation": {"@type": "Hospital", "name": "Al Sadiq Saad Shaheed Hospital", "address": {"streetAddress": "Main Peshawar Road, Rawalpindi"}},
 "AvailableService": {"name": ["Consultancy", "Antenatal Care, Caesarean (C-Section)"]}}</script>
<div class="card doc-listing-card doc-card-2 filter gynecologist">
 <img src="https://d1t78adged64l7.cloudfront.net/images/profile-pics/doctors/ghazala.webp" alt="x" class="img-fluid card-img-overlay p-0 ">
 <h2 class="doctor-name-heading"><a class="doctor-name nearme mb-1" href="https://oladoc.com/pakistan/islamabad/dr/gynecologist/ghazala-sadiq/3817">Prof. Dr. Ghazala Sadiq <!-- --> </a></h2>
 <span class="pmc-verified-pill"><svg><path d="M6"/></svg><b class="pmc-verified-text">PMDC Verified</b></span>
 <p class="mb-1 od-text-dark-muted text-truncate-dots">Gynecologist, Obstetrician</p>
 <p class="mb-1 text-truncate">F.C.P.S. (Gynecology &amp; Obstetrician), M.C.P.S, M.B.B.S</p>
 <div class="item review-wrapper"><span class="font-weight-medium">Under 15 Min</span> <span class="od-wte-text-muted">Wait Time</span></div>
 <div class="item review-wrapper"><span class="font-weight-medium">35 Years</span> <span class="od-wte-text-muted">Experience</span></div>
 <a href="#reviews" class="review-wrapper"><span class="font-weight-medium review-with-icon"> <svg><path d="M7"/></svg> 4.7 </span>
  <span class="od-wte-text-muted"> <span class="d-inline-block">683</span> Reviews </span></a>
 <a href="https://oladoc.com/appointment/6911/3817" class="border-bottom d-block text-body py-2"><div class="d-flex disc-list">
  <strong class="list-item appointment-location-main-heading">Al Sadiq Saad Shaheed Hospital </strong>
  <strong class="ml-auto flex-shrink-0"><small class="font-weight-bold">Rs. </small>3,000</strong></div>
  <div class="locality-holder"><span class="px-2 onlin-vc-text">Peshawar Road</span></div>
  <div class="row align-items-center text-available"><span class="mx-2 icon-available"></span> <span class="col pl-0">Available tomorrow</span></div></a>
 <a href="https://oladoc.com/appointment/6911/3817" class="frame d-block text-decoration-none"><div class="p-2 listing-locations">
  <span class="text-truncate d-block mb-1 font-weight-medium">Al Sadiq Saad Shaheed Hospital (Peshawar Road)</span><span class="doctor-fee"> Rs. 3,000 </span></div></a>
 <a href="https://oladoc.com/appointment/4681/3817" class="frame d-block text-decoration-none"><div class="p-2 listing-locations">
  <span class="text-truncate d-block mb-1 font-weight-medium">Online Video Consultation </span><span class="doctor-fee"> Rs. 1,500 </span>
  <span class="pl-2">Online</span></div></a>
</div>
"""


def test_oladoc_card_is_read_in_full():
    [d] = oladoc.parse_listing(OLADOC_PAGE)
    assert d["name"] == "Prof. Dr. Ghazala Sadiq" and d["pmdc_verified"] and d["specialty"] == "Gynecologist, Obstetrician"
    assert (d["experience_years"], d["rating"], d["rating_count"], d["wait_time"]) == (35, 4.7, 683, "Under 15 Min")
    assert d["photo"].startswith("https://d1t78adged64l7.cloudfront.net/")
    # the same clinic in the booking list and as a small card is one clinic
    assert [(c["name"], c["fee"], c["available"]) for c in d["clinics"]] == [
        ("Al Sadiq Saad Shaheed Hospital", 3000, "Available tomorrow"), ("Online Video Consultation", 1500, "Online")]
    assert len(d["spots"]) == 2


def test_without_google_doctors_come_from_oladoc_nearest_clinic_first(monkeypatch):
    asked = []
    monkeypatch.setattr(oladoc, "_get", lambda url: asked.append(url) or (OLADOC_PAGE if len(asked) == 1 else ""))
    monkeypatch.setattr(oladoc.time, "sleep", lambda s: None)
    r = client.get("/doctors/nearby", params={"specialty": "gynae", "lat": 33.60, "lon": 73.03}).json()  # Rawalpindi
    assert asked[0] == "https://oladoc.com/pakistan/rawalpindi/gynecologist"
    assert r["source"] == "oladoc" and "permission" in r["attribution"]
    [d] = r["doctors"]
    assert d["experience_years"] == 35 and d["fee"] == 1500 and d["pmdc_verified"] and d["city"] == "Rawalpindi"
    assert d["qualifications"] == ["F.C.P.S. (Gynecology & Obstetrician)", "M.C.P.S", "M.B.B.S"]
    assert d["distance_km"] < 1.5  # the Peshawar Road clinic, not the one in H-13
    assert d["profile_url"] == d["oladoc_url"] == "https://oladoc.com/pakistan/islamabad/dr/gynecologist/ghazala-sadiq/3817"
    # a second search is served from the cache, not from Oladoc again
    doctors.reset_cache()
    client.get("/doctors/nearby", params={"specialty": "gynae", "lat": 33.60, "lon": 73.03})
    assert len([u for u in asked if u.endswith("/gynecologist")]) == 1


def test_oladoc_photos_pass_through_but_other_hosts_do_not(monkeypatch):
    monkeypatch.setattr(doctors, "fetch_photo", lambda ref: (b"webp", "image/webp"))
    assert client.get("/doctors/photo", params={"ref": "https://d1t78adged64l7.cloudfront.net/images/x.webp"}).status_code == 200
    assert client.get("/doctors/photo", params={"ref": "https://example.com/x.webp"}).status_code == 404


def test_names_are_split_into_name_specialty_and_degrees():
    assert doctors.split_name("Dr. Sadia Khan (MBBS, FCPS) - Gynecologist", "X") == ("Dr. Sadia Khan", "Gynecologist", ["MBBS", "FCPS"])
    assert doctors.split_name("Dr Hina Rauf", "Gynecologist") == ("Dr Hina Rauf", "Gynecologist", [])
    assert doctors.split_name("Prof. Dr. Nasreen Akhtar | Obstetrician & Gynaecologist", "X")[1] == "Obstetrician & Gynaecologist"


def test_only_doctors_own_listings_count():
    assert doctors.is_doctor("Dr. Sadia Khan") and doctors.is_doctor("Prof. Nasreen") and doctors.is_doctor("Assoc. Prof. Dr. Amna")
    assert not doctors.is_doctor("Shifa International Hospital") and not doctors.is_doctor("Drip Lab")


def test_google_listing_becomes_a_ranked_mini_profile(monkeypatch):
    monkeypatch.setenv("GOOGLE_PLACES_API_KEY", "k")
    monkeypatch.setattr(doctors, "search_google", lambda s, lat, lon: doctors.parse_google(GOOGLE, lat, lon, s))
    r = client.get("/doctors/nearby", params={"specialty": "gynae", "lat": ISB[0], "lon": ISB[1]}).json()
    assert r["source"] == "google" and "Google" in r["attribution"]
    names = [d["name"] for d in r["doctors"]]
    assert "Shifa International Hospital" not in names  # hospitals are in Nearby care, not here
    # 4.7 from 240 reviews ranks above 4.9 from 3
    assert names == ["Prof. Dr. Nasreen Akhtar", "Dr. Sadia Khan"]
    sadia = r["doctors"][1]
    assert sadia["qualifications"] == ["MBBS", "FCPS"] and sadia["city"] == "Islamabad" and sadia["open_now"] is True
    assert sadia["reviews"][0] == {"author": "Ayesha", "rating": 5.0, "text": "Listened patiently.", "when": "a month ago"}
    assert sadia["photo"] == "places/d1/photos/p1" and sadia["photo_credit"] == "Clinic owner"
    assert sadia["oladoc_url"].startswith("https://www.google.com/search?q=site%3Aoladoc.com+Dr.+Sadia+Khan")


def test_without_a_key_mapped_doctors_come_from_openstreetmap(monkeypatch):
    area = {"elements": [
        {"type": "node", "id": 7, "lat": 33.69, "lon": 73.05, "tags": {"name": "Dr. Farah Gynae Clinic", "amenity": "doctors"}},
        {"type": "node", "id": 8, "lat": 33.69, "lon": 73.05, "tags": {"name": "Dr. Ali Skin Clinic", "amenity": "doctors"}},
        {"type": "node", "id": 9, "lat": 33.69, "lon": 73.05, "tags": {"name": "City Hospital", "amenity": "hospital"}},
    ]}
    monkeypatch.setattr(places, "fetch_area", lambda lat, lon: area)
    r = client.get("/doctors/nearby", params={"specialty": "gynae", "lat": ISB[0], "lon": ISB[1]}).json()
    assert r["source"] == "openstreetmap" and [d["name"] for d in r["doctors"]] == ["Dr. Farah Gynae Clinic"]
    assert r["doctors"][0]["rating"] is None


def test_photo_needs_a_valid_reference_and_the_key(monkeypatch):
    assert client.get("/doctors/photo", params={"ref": "places/d1/photos/p1"}).status_code == 404  # no key
    monkeypatch.setenv("GOOGLE_PLACES_API_KEY", "k")
    assert client.get("/doctors/photo", params={"ref": "https://evil.example/x"}).status_code == 404
    monkeypatch.setattr(doctors, "fetch_photo", lambda ref: (b"\xff\xd8jpeg", "image/jpeg"))
    r = client.get("/doctors/photo", params={"ref": "places/d1/photos/p1"})
    assert r.status_code == 200 and r.content == b"\xff\xd8jpeg" and r.headers["content-type"] == "image/jpeg"


def test_search_failure_is_a_clean_error(monkeypatch):
    monkeypatch.setattr(places, "fetch_area", lambda lat, lon: (_ for _ in ()).throw(RuntimeError("down")))
    assert client.get("/doctors/nearby", params={"lat": ISB[0], "lon": ISB[1]}).status_code == 502
