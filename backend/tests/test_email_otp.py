import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import app as backend  # noqa: E402
import email_otp  # noqa: E402

client = TestClient(backend.app)


@pytest.fixture(autouse=True)
def fake_services(monkeypatch):
    sent = {}
    monkeypatch.setattr(email_otp, "_send_email", lambda to, code: sent.__setitem__(to, code))
    monkeypatch.setattr(email_otp, "_custom_token", lambda email: f"token-for-{email}")
    email_otp._pending.clear()
    return sent


def test_the_right_code_returns_a_sign_in_token(fake_services):
    assert client.post("/auth/email/start", json={"email": " Ayesha@Example.com "}).status_code == 200
    code = fake_services["ayesha@example.com"]
    assert len(code) == 6 and code.isdigit()
    r = client.post("/auth/email/verify", json={"email": "ayesha@example.com", "code": code})
    assert r.status_code == 200 and r.json()["token"] == "token-for-ayesha@example.com"
    # a code works only once
    assert client.post("/auth/email/verify", json={"email": "ayesha@example.com", "code": code}).status_code == 410


def test_a_wrong_code_is_refused_and_too_many_end_the_code(fake_services):
    client.post("/auth/email/start", json={"email": "a@b.co"})
    real = fake_services["a@b.co"]
    wrong = "000000" if real != "000000" else "111111"
    for _ in range(email_otp.MAX_ATTEMPTS):
        assert client.post("/auth/email/verify", json={"email": "a@b.co", "code": wrong}).status_code == 401
    assert client.post("/auth/email/verify", json={"email": "a@b.co", "code": real}).status_code == 429


def test_asking_again_within_a_minute_is_refused(fake_services):
    assert client.post("/auth/email/start", json={"email": "a@b.co"}).status_code == 200
    assert client.post("/auth/email/start", json={"email": "a@b.co"}).status_code == 429


def test_a_bad_email_is_refused():
    assert client.post("/auth/email/start", json={"email": "not-an-email"}).status_code == 422


def test_an_expired_code_is_refused(fake_services, monkeypatch):
    client.post("/auth/email/start", json={"email": "a@b.co"})
    code = fake_services["a@b.co"]
    monkeypatch.setattr(email_otp.time, "time", lambda: 10**12)
    assert client.post("/auth/email/verify", json={"email": "a@b.co", "code": code}).status_code == 410
