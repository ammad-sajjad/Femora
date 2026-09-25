"""Femora on WhatsApp (Meta WhatsApp Cloud API).

A woman messages the Femora number and gets the same companion as in the app, with the same safety rules:
- text in English, Roman Urdu or Urdu gets the companion's answer (red-flag notes and Rescue 1122 included);
- a voice note is transcribed first (Urdu or English), then answered;
- a photo of a lab or ultrasound report is read and explained, like the app's report reader.
Replies are text: the free AI voice allows only about 10 answers a day, far too few for WhatsApp.

Privacy: nothing is written to disk. The last few turns of each conversation are kept in memory for up to an hour so
follow-up questions make sense, then forgotten. The first message from a number gets a short note on what Femora is and
that messages pass through Meta and Google. Reminders are not sent over WhatsApp: messages a business starts cost money
and need approved templates.

Setup (see backend/README.md): WHATSAPP_TOKEN, WHATSAPP_PHONE_NUMBER_ID, WHATSAPP_VERIFY_TOKEN and WHATSAPP_APP_SECRET in
backend/.env, and the webhook URL https://<server>/whatsapp/webhook in the Meta app dashboard.
"""
import hashlib
import hmac
import json
import os
import re
import threading
import time
import urllib.error
import urllib.request
from collections import OrderedDict, deque

from fastapi import APIRouter, BackgroundTasks, HTTPException, Request
from fastapi.responses import PlainTextResponse

import companion
import report_reader

GRAPH = "https://graph.facebook.com/v21.0"
MAX_TURNS = 6  # remembered per conversation
MEMORY_SECONDS = 3600
MAX_TEXT = 4000  # WhatsApp's limit is 4096

router = APIRouter()


def config() -> dict[str, str | None]:
    return {k: os.environ.get(k) or None for k in
            ("WHATSAPP_TOKEN", "WHATSAPP_PHONE_NUMBER_ID", "WHATSAPP_VERIFY_TOKEN", "WHATSAPP_APP_SECRET")}


def enabled() -> bool:
    c = config()
    return bool(c["WHATSAPP_TOKEN"] and c["WHATSAPP_PHONE_NUMBER_ID"] and c["WHATSAPP_VERIFY_TOKEN"])


# ---------------------------------------------------------------- memory (in RAM only)

_lock = threading.Lock()
_conversations: dict[str, tuple[float, deque]] = {}
_seen_ids: OrderedDict[str, None] = OrderedDict()  # Meta retries deliveries; answer each message once
_greeted: set[str] = set()


def _history(wa_id: str) -> deque:
    now = time.time()
    with _lock:
        for k in [k for k, (t, _) in _conversations.items() if now - t > MEMORY_SECONDS]:
            del _conversations[k]
        t, turns = _conversations.get(wa_id, (now, deque(maxlen=MAX_TURNS)))
        _conversations[wa_id] = (now, turns)
        return turns


def _first_time(message_id: str) -> bool:
    with _lock:
        if message_id in _seen_ids:
            return False
        _seen_ids[message_id] = None
        while len(_seen_ids) > 2000:
            _seen_ids.popitem(last=False)
        return True


def reset() -> None:
    with _lock:
        _conversations.clear()
        _seen_ids.clear()
        _greeted.clear()


# ---------------------------------------------------------------- formatting

def to_whatsapp(text: str) -> str:
    """WhatsApp uses *bold* (one star) and has no headings; '- ' bullets read fine as they are."""
    text = re.sub(r"^#{1,4}\s*(.+)$", r"*\1*", text, flags=re.M)
    text = re.sub(r"\*\*(.+?)\*\*", r"*\1*", text)
    text = re.sub(r"^\s*\*\s+", "- ", text, flags=re.M)  # "* item" bullets would turn into bold
    return text.strip()[:MAX_TEXT]


WELCOME = {
    "en": ("Assalam o alaikum, I'm Femora, a women's health companion. I can explain symptoms, periods, PMOS/PCOS, pregnancy "
           "questions and lab reports (send a photo), in English or Urdu, by text or voice note. I'm not a doctor and can't "
           "examine you. Your messages pass through WhatsApp (Meta) and Google's AI to be answered; Femora does not store them."),
    "ur": ("السلام علیکم، میں Femora ہوں، خواتین کی صحت کی ساتھی۔ میں علامات، ماہواری، PCOS، حمل کے سوالات اور لیب رپورٹس "
           "(تصویر بھیجیں) اردو یا انگریزی میں، لکھ کر یا وائس نوٹ سے سمجھا سکتی ہوں۔ میں ڈاکٹر نہیں ہوں اور معائنہ نہیں کر سکتی۔ "
           "جواب کے لیے آپ کے پیغامات واٹس ایپ (Meta) اور گوگل کی AI سے گزرتے ہیں؛ Femora انہیں محفوظ نہیں کرتی۔"),
}


def report_text(r: report_reader.ReportExplanation) -> str:
    lines = [r.summary]
    abnormal = [f for f in r.findings if f.status in ("low", "high", "abnormal", "critical")]
    if abnormal:
        lines.append("")
        lines.append("*" + ("قابلِ توجہ نتائج" if r.language == "ur" else "Values to note") + "*")
        lines += [f"- {f.name}: {f.value} {f.unit} ({f.status}). {f.explanation}".replace("  ", " ") for f in abnormal[:8]]
    if r.questions_for_doctor:
        lines.append("")
        lines.append("*" + ("ڈاکٹر سے پوچھیں" if r.language == "ur" else "Questions for your doctor") + "*")
        lines += [f"- {q}" for q in r.questions_for_doctor[:4]]
    lines.append("")
    lines.append("_" + r.disclaimer + "_")
    return "\n".join(lines)


# ---------------------------------------------------------------- Meta Graph API

def _graph(method: str, url: str, body: dict | None = None, raw: bool = False, timeout: float = 30):
    token = config()["WHATSAPP_TOKEN"]
    req = urllib.request.Request(url, method=method, data=None if body is None else json.dumps(body).encode(),
                                 headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        data = r.read()
    return data if raw else json.loads(data)


def send_text(to: str, text: str) -> None:
    _graph("POST", f"{GRAPH}/{config()['WHATSAPP_PHONE_NUMBER_ID']}/messages",
           {"messaging_product": "whatsapp", "to": to, "type": "text", "text": {"body": text[:MAX_TEXT], "preview_url": False}})


def download_media(media_id: str) -> tuple[bytes, str]:
    info = _graph("GET", f"{GRAPH}/{media_id}")
    return _graph("GET", info["url"], raw=True, timeout=60), info.get("mime_type", "")


# ---------------------------------------------------------------- handling one message

def handle(message: dict) -> None:
    wa_id = message.get("from", "")
    kind = message.get("type")
    try:
        companion.check_rate("wa:" + wa_id)
    except HTTPException:
        send_text(wa_id, "You are sending messages very quickly. Please wait a minute and try again.")
        return

    if kind == "image":
        try:
            data, _ = download_media(message["image"]["id"])
            r = report_reader.normalise(report_reader.gemini_read_report([report_reader.prepare_image(data)], "en"), "auto")
            reply = report_text(r)
        except HTTPException as e:
            reply = e.detail
        except Exception:
            reply = "I could not read that photo. Please send a clear, well-lit photo of one page of the report."
        _greet_then(wa_id, reply, "en")
        return

    if kind == "audio":
        try:
            data, mime = download_media(message["audio"]["id"])
            text = companion.gemini_transcribe(data, mime.split(";")[0] or "audio/ogg", "auto").strip()
        except Exception:
            text = ""
        if not text:
            send_text(wa_id, "Sorry, I could not understand the voice note. Please try again or type your question.")
            return
    elif kind == "text":
        text = message.get("text", {}).get("body", "").strip()[: companion.MAX_MESSAGE_CHARS]
    else:
        send_text(wa_id, "I can read text, voice notes and photos of medical reports. Please send one of those.")
        return
    if not text:
        return

    turns = _history(wa_id)
    turns.append(companion.ChatMessage(role="user", text=text))
    req = companion.ChatRequest(messages=list(turns)[-companion.MAX_TURNS:], context=None, language="auto")
    res = companion.respond(req)
    turns.append(companion.ChatMessage(role="assistant", text=res.reply[: companion.MAX_MESSAGE_CHARS]))
    reply = res.reply
    if res.sources:
        reply += "\n\n_" + ("ماخذ" if res.language == "ur" else "Based on") + ": " + ", ".join(s.title for s in res.sources) + "_"
    _greet_then(wa_id, reply, res.language)


def _greet_then(wa_id: str, reply: str, lang: str) -> None:
    with _lock:
        first = wa_id not in _greeted
        _greeted.add(wa_id)
    if first:
        send_text(wa_id, WELCOME.get(lang, WELCOME["en"]))
    send_text(wa_id, to_whatsapp(reply))


def _safe_handle(message: dict) -> None:
    try:
        handle(message)
    except Exception:
        pass  # never crash the worker; Meta would retry the whole delivery


# ---------------------------------------------------------------- webhook

@router.get("/whatsapp/webhook")
def verify(request: Request):
    """Meta calls this once when the webhook is set up."""
    q = request.query_params
    token = config()["WHATSAPP_VERIFY_TOKEN"]
    if token and q.get("hub.mode") == "subscribe" and hmac.compare_digest(q.get("hub.verify_token", ""), token):
        return PlainTextResponse(q.get("hub.challenge", ""))
    raise HTTPException(403, "Verification failed.")


@router.post("/whatsapp/webhook")
async def receive(request: Request, background: BackgroundTasks):
    if not enabled():
        raise HTTPException(503, "WhatsApp is not set up on this server.")
    body = await request.body()
    secret = config()["WHATSAPP_APP_SECRET"]
    if secret:  # only Meta knows the app secret, so this proves the delivery came from Meta
        expected = "sha256=" + hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
        if not hmac.compare_digest(request.headers.get("x-hub-signature-256", ""), expected):
            raise HTTPException(403, "Bad signature.")
    try:
        payload = json.loads(body)
    except ValueError:
        raise HTTPException(400, "Not JSON.")
    for entry in payload.get("entry", []):
        for change in entry.get("changes", []):
            for m in change.get("value", {}).get("messages", []) or []:
                if m.get("id") and _first_time(m["id"]):
                    background.add_task(_safe_handle, m)  # answer after replying 200, so Meta does not time out and retry
    return {"ok": True}
