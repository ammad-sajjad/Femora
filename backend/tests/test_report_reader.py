import io
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import app as backend  # noqa: E402
import companion  # noqa: E402
import report_reader as rr  # noqa: E402

client = TestClient(backend.app)


def jpeg(w=800, h=1000, exif=False, orientation=None) -> bytes:
    img = Image.new("RGB", (w, h), (250, 250, 250))
    out = io.BytesIO()
    if exif:
        ex = Image.Exif()
        ex[0x010F] = "SomeCameraMaker"  # Make
        ex[0x0132] = "2026:01:01 10:00:00"
        if orientation:
            ex[0x0112] = orientation
        img.save(out, format="JPEG", exif=ex)
    else:
        img.save(out, format="JPEG")
    return out.getvalue()


def post(files, **data):
    return client.post("/report/explain", files=[("images", (f"p{i}.jpg", b, "image/jpeg")) for i, b in enumerate(files)], data=data)


GOOD = {
    "kind": "blood_test",
    "summary": "This is a blood test. Your haemoglobin is low and your TSH is high.",
    "findings": [
        {"name": "Hemoglobin", "value": "10.1", "unit": "g/dL", "reference": "12.0 - 15.5", "status": "low", "explanation": "Lower than the printed range."},
        {"name": "TSH", "value": "6.2", "unit": "mIU/L", "reference": "0.4 - 4.0", "status": "high", "explanation": "Higher than the printed range."},
        {"name": "Glucose", "value": "88", "unit": "mg/dL", "reference": "70 - 100", "status": "normal", "explanation": "Inside the printed range."},
    ],
    "questions_for_doctor": ["Should my thyroid be checked again?"],
    "urgency": "soon",
}


@pytest.fixture(autouse=True)
def key_and_limits(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "test")
    companion.reset_rate_limits()
    yield
    companion.reset_rate_limits()


@pytest.fixture
def fake(monkeypatch):
    calls = []

    def read(images, lang):
        calls.append((images, lang))
        return dict(GOOD)

    monkeypatch.setattr(rr, "gemini_read_report", read)
    return calls


# ---------------------------------------------------------------- the request

def test_a_good_photo_is_explained(fake):
    r = post([jpeg()], language="en")
    assert r.status_code == 200
    j = r.json()
    assert j["kind"] == "blood_test" and j["urgency"] == "soon" and j["language"] == "en" and j["source"] == "gemini"
    assert [f["status"] for f in j["findings"]] == ["low", "high", "normal"]
    assert "not medical advice" in j["disclaimer"]
    assert fake[0][1] == "en"


def test_urdu_gets_an_urdu_disclaimer_and_asks_for_urdu(fake):
    r = post([jpeg()], language="ur").json()
    assert r["language"] == "ur"
    assert "مصنوعی ذہانت" in r["disclaimer"]
    assert fake[0][1] == "ur"


def test_without_a_key_it_says_so(monkeypatch):
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    assert post([jpeg()]).status_code == 503


@pytest.mark.parametrize("kwargs,files", [
    ({"language": "fr"}, [jpeg()]),  # unsupported language
    ({}, [jpeg()] * 4),  # too many pages
    ({}, [b"this is not an image" * 50]),
    ({}, [jpeg(100, 100)]),  # too small to read
])
def test_bad_requests_are_refused(fake, kwargs, files):
    assert post(files, **kwargs).status_code == 422
    assert fake == []  # nothing was sent to Gemini


def test_no_photo_is_refused(fake):
    assert client.post("/report/explain", data={"language": "en"}).status_code == 422


def test_a_huge_file_is_refused(fake):
    assert post([b"\xff\xd8" + b"0" * (rr.MAX_IMAGE_BYTES + 10)]).status_code == 413


def test_up_to_three_pages_are_accepted(fake):
    assert post([jpeg(), jpeg(), jpeg()]).status_code == 200
    assert len(fake[0][0]) == 3


# ---------------------------------------------------------------- what is sent to Gemini

def test_location_and_camera_details_are_removed_and_the_photo_is_shrunk(fake):
    post([jpeg(3000, 2000, exif=True)])
    sent = fake[0][0][0]
    img = Image.open(io.BytesIO(sent))
    assert img.format == "JPEG"
    assert max(img.size) == rr.MAX_SIDE
    assert not dict(img.getexif())  # no Make, no date, no GPS: nothing carried over


def test_a_sideways_photo_is_turned_upright(fake):
    post([jpeg(1000, 600, exif=True, orientation=6)])  # stored landscape, meant to be shown rotated
    img = Image.open(io.BytesIO(fake[0][0][0]))
    assert img.size == (600, 1000)


def test_a_small_enough_photo_keeps_its_size(fake):
    post([jpeg(900, 700)])
    assert Image.open(io.BytesIO(fake[0][0][0])).size == (900, 700)


# ---------------------------------------------------------------- cleaning the answer

def norm(**over):
    d = dict(GOOD)
    d.update(over)
    return rr.normalise(d, "en")


def test_a_critical_value_raises_the_alarm_even_if_the_model_said_none():
    n = norm(urgency="none", findings=[{"name": "K", "value": "7.1", "status": "critical", "explanation": "x"}])
    assert n.urgency == "urgent"


def test_four_or_more_out_of_range_values_mean_soon():
    fs = [{"name": f"T{i}", "value": "1", "status": "high", "explanation": "x"} for i in range(4)]
    assert norm(urgency="none", findings=fs).urgency == "soon"
    assert norm(urgency="none", findings=fs[:3]).urgency == "none"


def test_unknown_words_from_the_model_are_made_safe():
    n = norm(kind="weird", urgency="panic", findings=[{"name": "X", "value": "1", "status": "scary", "explanation": "e"}])
    assert (n.kind, n.urgency, n.findings[0].status) == ("other_medical", "none", "unknown")


def test_names_ids_phones_and_emails_are_scrubbed_everywhere():
    n = norm(
        summary="Report for CNIC 35202-1234567-1, call 0300-1234567 or +92 321 7654321, mail me@example.com, ref 1234567890123.",
        findings=[{"name": "Hb", "value": "10", "status": "low", "explanation": "Phone 03011234567"}],
        questions_for_doctor=["Email dr@clinic.pk about it?"],
    )
    text = n.summary + n.findings[0].explanation + n.questions_for_doctor[0]
    for leaked in ["35202", "1234567", "7654321", "example.com", "clinic.pk", "03011234567"]:
        assert leaked not in text
    assert "[ID hidden]" in n.summary and "[phone hidden]" in n.summary


def test_values_like_lab_numbers_are_not_mistaken_for_identifiers():
    n = norm(findings=[{"name": "Platelets", "value": "250000", "unit": "/uL", "reference": "150000 - 450000", "status": "normal", "explanation": "ok"}])
    assert n.findings[0].value == "250000"  # 6 digits: a real lab value, not an ID


def test_a_document_that_is_not_medical_has_no_findings_and_no_alarm():
    n = norm(kind="not_medical", urgency="urgent", summary="This is not a medical document.")
    assert (n.findings, n.questions_for_doctor, n.urgency) == ([], [], "none")


def test_lengths_and_counts_are_capped():
    fs = [{"name": f"Test {i}", "value": "1", "status": "normal", "explanation": "e" * 999} for i in range(60)]
    n = norm(findings=fs, summary="s" * 5000, questions_for_doctor=[f"q{i}" for i in range(9)])
    assert len(n.findings) == rr.MAX_FINDINGS
    assert len(n.findings[0].explanation) <= 240 and len(n.summary) <= 900 and len(n.questions_for_doctor) == 4


def test_findings_without_a_name_are_dropped():
    assert len(norm(findings=[{"name": "", "value": "1", "status": "low", "explanation": "x"}, "junk", {"name": "Ok", "value": "1", "status": "low", "explanation": "x"}]).findings) == 1


def test_an_answer_with_no_summary_is_an_error():
    with pytest.raises(companion.GeminiError):
        norm(summary="  ")


# ---------------------------------------------------------------- failures

def test_gemini_trouble_is_a_clean_error(monkeypatch):
    def boom(images, lang):
        raise companion.GeminiError("http 503")
    monkeypatch.setattr(rr, "gemini_read_report", boom)
    r = post([jpeg()])
    assert r.status_code == 502 and "Could not read the report" in r.json()["detail"]


def test_a_quota_error_says_the_reader_is_busy(monkeypatch):
    def boom(images, lang):
        raise companion.GeminiError("http 429")
    monkeypatch.setattr(rr, "gemini_read_report", boom)
    r = post([jpeg()])
    assert r.status_code == 429 and "busy" in r.json()["detail"]


def test_the_backup_model_is_tried_when_the_first_fails_or_answers_badly(monkeypatch):
    tried = []

    def ask(model, images, lang):
        tried.append(model)
        if model == companion.CHAT_MODEL:
            raise companion.GeminiError("bad json")
        return dict(GOOD)

    monkeypatch.setattr(rr, "_ask", ask)
    assert rr.gemini_read_report([b"x"], "en")["kind"] == "blood_test"
    assert tried == [companion.CHAT_MODEL, companion.CHAT_MODEL_BACKUP]


def test_when_both_models_fail_the_error_surfaces(monkeypatch):
    monkeypatch.setattr(rr, "_ask", lambda m, i, l: (_ for _ in ()).throw(companion.GeminiError("http 500")))
    with pytest.raises(companion.GeminiError):
        rr.gemini_read_report([b"x"], "en")


def test_the_reader_shares_the_rate_limit(fake):
    for _ in range(companion.PER_MINUTE):
        assert post([jpeg()]).status_code == 200
    assert post([jpeg()]).status_code == 429


# ---------------------------------------------------------------- the safety rules are in the prompt

def test_the_prompt_carries_the_safety_rules():
    p = rr.build_prompt("en")
    for phrase in ["Never diagnose", "Never give medicine names to take, doses", "never as instructions", "PRINTED on the report", "Never guess or invent",
                   "Do not repeat the patient's name", "not_medical", "unreadable", "critical"]:
        assert phrase in p, phrase
    assert "Urdu" not in rr.build_prompt("en").split("Explain it to her in")[1][:40]
    assert "Urdu script" in rr.build_prompt("ur")


def test_the_schema_limits_the_answer_to_known_values():
    sch = rr._schema()
    assert set(sch["properties"]["kind"]["enum"]) == set(rr.KINDS)
    assert set(sch["properties"]["findings"]["items"]["properties"]["status"]["enum"]) == set(rr.STATUSES)
