import hashlib
import hmac
import json

import pytest
from fastapi.testclient import TestClient

import app as api
import companion
import report_reader
import whatsapp

SECRET = "app-secret"


@pytest.fixture(autouse=True)
def _setup(monkeypatch):
    for k, v in {"WHATSAPP_TOKEN": "tok", "WHATSAPP_PHONE_NUMBER_ID": "123", "WHATSAPP_VERIFY_TOKEN": "verify-me",
                 "WHATSAPP_APP_SECRET": SECRET, "GEMINI_API_KEY": "test"}.items():
        monkeypatch.setenv(k, v)
    whatsapp.reset()
    companion.reset_rate_limits()


@pytest.fixture
def sent(monkeypatch):
    out = []
    monkeypatch.setattr(whatsapp, "send_text", lambda to, text: out.append((to, text)))
    return out


def deliver(message: dict, secret: str = SECRET):
    body = json.dumps({"entry": [{"changes": [{"value": {"messages": [message]}}]}]}).encode()
    sig = "sha256=" + hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    return TestClient(api.app).post("/whatsapp/webhook", content=body, headers={"x-hub-signature-256": sig, "content-type": "application/json"})


def text(body: str, mid: str = "m1", sender: str = "923001234567") -> dict:
    return {"from": sender, "id": mid, "type": "text", "text": {"body": body}}


def test_meta_verification_handshake():
    c = TestClient(api.app)
    ok = c.get("/whatsapp/webhook", params={"hub.mode": "subscribe", "hub.verify_token": "verify-me", "hub.challenge": "42"})
    assert ok.status_code == 200 and ok.text == "42"
    assert c.get("/whatsapp/webhook", params={"hub.mode": "subscribe", "hub.verify_token": "wrong", "hub.challenge": "42"}).status_code == 403


def test_a_forged_delivery_is_refused(sent):
    assert deliver(text("hi"), secret="not-the-secret").status_code == 403
    assert sent == []


def test_first_message_gets_the_welcome_then_the_answer(monkeypatch, sent):
    monkeypatch.setattr(companion, "gemini_chat", lambda req, lang, *_: "**Why it happens**\n* heat helps")
    assert deliver(text("I have period cramps")).status_code == 200
    assert len(sent) == 2
    assert "I'm not a doctor" in sent[0][1] and "Meta" in sent[0][1]
    assert sent[1][1].startswith("*Why it happens*\n- heat helps")  # converted to WhatsApp formatting
    assert "Based on: NHS: Period pain" in sent[1][1]
    deliver(text("thanks", mid="m2"))
    assert len(sent) == 3  # no second welcome


def test_follow_ups_keep_the_conversation(monkeypatch, sent):
    seen = []
    monkeypatch.setattr(companion, "gemini_chat", lambda req, lang, *_: seen.append([m.text for m in req.messages]) or "ok")
    deliver(text("What is PCOS?", mid="a"))
    deliver(text("And the diet?", mid="b"))
    assert seen[-1] == ["What is PCOS?", "ok", "And the diet?"]


def test_other_numbers_have_their_own_conversation(monkeypatch, sent):
    seen = []
    monkeypatch.setattr(companion, "gemini_chat", lambda req, lang, *_: seen.append(len(req.messages)) or "ok")
    deliver(text("one", mid="a", sender="1"))
    deliver(text("two", mid="b", sender="2"))
    assert seen == [1, 1]


def test_a_retried_delivery_is_answered_once(monkeypatch, sent):
    monkeypatch.setattr(companion, "gemini_chat", lambda req, lang, *_: "ok")
    deliver(text("hello", mid="same"))
    deliver(text("hello", mid="same"))
    assert len(sent) == 2  # welcome + one answer


def test_emergencies_keep_the_urgent_note(monkeypatch, sent):
    monkeypatch.setattr(companion, "gemini_chat", lambda req, lang, *_: "Rest.")
    deliver(text("I have heavy bleeding and feel faint"))
    assert "Rescue 1122" in sent[-1][1]


def test_voice_notes_are_transcribed_and_answered(monkeypatch, sent):
    monkeypatch.setattr(whatsapp, "download_media", lambda mid: (b"OggS" + b"\0" * 2000, "audio/ogg; codecs=opus"))
    heard = {}
    monkeypatch.setattr(companion, "gemini_transcribe", lambda audio, mime, lang: heard.update(mime=mime) or "sar dard ho raha hai")
    monkeypatch.setattr(companion, "gemini_chat", lambda req, lang, *_: "jawab " + req.messages[-1].text)
    deliver({"from": "9", "id": "v1", "type": "audio", "audio": {"id": "media-1"}})
    assert heard["mime"] == "audio/ogg" and sent[-1][1].startswith("jawab sar dard ho raha hai")


def test_report_photos_are_read(monkeypatch, sent):
    monkeypatch.setattr(whatsapp, "download_media", lambda mid: (b"jpeg", "image/jpeg"))
    monkeypatch.setattr(report_reader, "prepare_image", lambda data: data)
    monkeypatch.setattr(report_reader, "gemini_read_report", lambda images, lang: {
        "kind": "blood_test", "summary": "A routine blood test.", "urgency": "none", "questions_for_doctor": ["Do I need iron?"],
        "findings": [{"name": "Hemoglobin", "value": "10.8", "unit": "g/dL", "reference": "12-15.5", "status": "low",
                      "explanation": "Slightly low."}]})
    deliver({"from": "9", "id": "i1", "type": "image", "image": {"id": "media-2"}})
    reply = sent[-1][1]
    assert "A routine blood test." in reply and "Hemoglobin: 10.8 g/dL (low)" in reply and "Do I need iron?" in reply


def test_other_message_types_get_a_helpful_note(sent):
    deliver({"from": "9", "id": "s1", "type": "sticker", "sticker": {"id": "x"}})
    assert "text, voice notes and photos" in sent[-1][1]


def test_not_configured_means_not_available(monkeypatch):
    monkeypatch.delenv("WHATSAPP_TOKEN")
    assert TestClient(api.app).post("/whatsapp/webhook", json={}).status_code == 503


def test_whatsapp_formatting():
    assert whatsapp.to_whatsapp("## Title\n**bold** word\n* item") == "*Title*\n*bold* word\n- item"
