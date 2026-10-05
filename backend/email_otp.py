"""Sign-in with a 6-digit code sent by email, in place of SMS codes (Firebase only sends SMS on its paid plan).

/auth/email/start  emails a code through Brevo's HTTP API (Railway blocks SMTP on its free plans).
/auth/email/verify checks the code and returns a Firebase custom token; the app signs in with it, so the
account is an ordinary Firebase user with a verified email.

Settings (environment): BREVO_API_KEY, OTP_SENDER_EMAIL (a sender verified in Brevo), and the Firebase
service account as FIREBASE_SERVICE_ACCOUNT (the JSON itself) or FIREBASE_SERVICE_ACCOUNT_FILE (a path).
"""

import hashlib
import hmac
import json
import os
import re
import secrets
import threading
import time
import urllib.error
import urllib.request

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

router = APIRouter()

CODE_TTL_SECONDS = 10 * 60
RESEND_AFTER_SECONDS = 60
MAX_ATTEMPTS = 5
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

_lock = threading.Lock()
_pending: dict[str, dict] = {}  # email -> {"hash", "expires", "sent", "attempts"}
_firebase_app = None


class EmailStart(BaseModel):
    email: str = Field(min_length=3, max_length=254)


class EmailVerify(BaseModel):
    email: str = Field(min_length=3, max_length=254)
    code: str = Field(min_length=4, max_length=10)


class EmailToken(BaseModel):
    token: str


def _normalise(email: str) -> str:
    email = email.strip().lower()
    if not EMAIL_RE.match(email):
        raise HTTPException(422, "That email address does not look right.")
    return email


def _hash(email: str, code: str) -> str:
    return hashlib.sha256(f"{email}:{code}".encode("utf-8")).hexdigest()


def configured() -> bool:
    return bool(os.environ.get("BREVO_API_KEY") and os.environ.get("OTP_SENDER_EMAIL")
                and (os.environ.get("FIREBASE_SERVICE_ACCOUNT") or os.environ.get("FIREBASE_SERVICE_ACCOUNT_FILE")))


def _send_email(to: str, code: str) -> None:
    key, sender = os.environ.get("BREVO_API_KEY"), os.environ.get("OTP_SENDER_EMAIL")
    if not key or not sender:
        raise HTTPException(503, "Email codes are not set up on the server yet.")
    html = (f"<p>Your Femora sign-in code is:</p><p style='font-size:28px;font-weight:bold;letter-spacing:6px'>{code}</p>"
            "<p>It expires in 10 minutes. If you did not ask for it, you can ignore this email.</p>")
    body = {"sender": {"name": "Femora", "email": sender}, "to": [{"email": to}],
            "subject": f"Your Femora code: {code}", "htmlContent": html,
            "textContent": f"Your Femora sign-in code is {code}. It expires in 10 minutes."}
    req = urllib.request.Request("https://api.brevo.com/v3/smtp/email", data=json.dumps(body).encode("utf-8"),
                                 headers={"api-key": key, "Content-Type": "application/json", "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            r.read()
    except urllib.error.HTTPError as e:
        print(f"[email_otp] Brevo refused the email: HTTP {e.code} {e.read()[:300]!r}")
        raise HTTPException(502, "We could not send the email. Please try again in a minute.")
    except (urllib.error.URLError, TimeoutError) as e:
        print(f"[email_otp] Brevo unreachable: {e}")
        raise HTTPException(502, "We could not send the email. Please try again in a minute.")


def _firebase():
    global _firebase_app
    if _firebase_app is None:
        import firebase_admin  # imported on first use so the models start without it
        from firebase_admin import credentials
        raw, path = os.environ.get("FIREBASE_SERVICE_ACCOUNT"), os.environ.get("FIREBASE_SERVICE_ACCOUNT_FILE")
        if raw:
            cred = credentials.Certificate(json.loads(raw))
        elif path:
            cred = credentials.Certificate(path)
        else:
            raise HTTPException(503, "Email codes are not set up on the server yet.")
        _firebase_app = firebase_admin.initialize_app(cred, name="email-otp")
    return _firebase_app


def _custom_token(email: str) -> str:
    from firebase_admin import auth
    app = _firebase()
    try:
        user = auth.get_user_by_email(email, app=app)
        if not user.email_verified:
            auth.update_user(user.uid, email_verified=True, app=app)
    except auth.UserNotFoundError:
        user = auth.create_user(email=email, email_verified=True, display_name=email.split("@")[0], app=app)
    token = auth.create_custom_token(user.uid, app=app)
    return token.decode("utf-8") if isinstance(token, bytes) else token


@router.post("/auth/email/start")
def start(req: EmailStart):
    email = _normalise(req.email)
    now = time.time()
    with _lock:
        prev = _pending.get(email)
        if prev and now - prev["sent"] < RESEND_AFTER_SECONDS:
            raise HTTPException(429, "A code was just sent. Please wait a minute before asking again.")
        code = f"{secrets.randbelow(1_000_000):06d}"
        _pending[email] = {"hash": _hash(email, code), "expires": now + CODE_TTL_SECONDS, "sent": now, "attempts": 0}
    try:
        _send_email(email, code)
    except HTTPException:
        with _lock:
            _pending.pop(email, None)
        raise
    return {"sent": True}


@router.post("/auth/email/verify", response_model=EmailToken)
def verify(req: EmailVerify):
    email, code = _normalise(req.email), req.code.strip()
    with _lock:
        entry = _pending.get(email)
        if entry is None or time.time() > entry["expires"]:
            _pending.pop(email, None)
            raise HTTPException(410, "This code has expired. Please ask for a new one.")
        entry["attempts"] += 1
        if entry["attempts"] > MAX_ATTEMPTS:
            _pending.pop(email, None)
            raise HTTPException(429, "Too many wrong codes. Please ask for a new one.")
        if not hmac.compare_digest(entry["hash"], _hash(email, code)):
            raise HTTPException(401, "That code is not correct. Please check the email and try again.")
        _pending.pop(email, None)
    return EmailToken(token=_custom_token(email))
