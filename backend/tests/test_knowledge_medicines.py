import pytest
from fastapi.testclient import TestClient

import app as api
import companion
import knowledge
import medicines


@pytest.fixture(autouse=True)
def _reset():
    companion.reset_rate_limits()


# ---------------------------------------------------------------- trusted notes

@pytest.mark.parametrize("question,topic", [
    ("I have really bad period cramps", "period_pain"),
    ("mujhe pait mein dard hai periods ke dauran", "period_pain"),
    ("ماہواری میں درد بہت ہوتا ہے", "period_pain"),
    ("What is PCOS and can I get pregnant with it?", "pcos"),
    ("burning when I pee and need to go all the time", "uti"),
    ("peshab mein jalan ho rahi hai", "uti"),
    ("white discharge like cottage cheese and itching", "thrush"),
    ("safed pani bohat aata hai", "discharge"),
    ("I found a lump in my breast", "breast_lump"),
    ("my period is late, could I be pregnant?", "missed_period"),
    ("khoon ki kami hai, bohat thakawat hoti hai", "anaemia"),
    ("I get hot flushes and night sweats", "menopause"),
    ("sar dard rehta hai", "headache"),
    ("acidity and heartburn after dinner", "heartburn"),
    ("how do I check my breasts", "self_exam"),
])
def test_questions_find_the_right_topic(question, topic):
    found = knowledge.search(question)
    assert topic in [t.id for t in found]   # among the two passages the model is given


def test_unrelated_question_finds_nothing():
    assert knowledge.search("What is the capital of France?") == []


def test_every_topic_has_a_source_and_a_real_summary():
    ids = [t.id for t in knowledge.TOPICS]
    assert len(ids) == len(set(ids))
    for t in knowledge.TOPICS:
        assert t.url.startswith("https://") and t.source and 60 <= len(t.text.split()) <= 200, t.id


def test_keywords_match_whole_words_only():
    # "sad" must not match inside "Sadia"
    assert all(t.id != "stress_mood" for t in knowledge.search("Sadia asked about her cycle"))


# ---------------------------------------------------------------- medicine table

def names(s):
    return [o.name.split(" (")[0] for o in s.options]


def test_period_pain_offers_ibuprofen_and_paracetamol():
    [s] = medicines.suggest("I have terrible period cramps")
    assert names(s) == ["ibuprofen", "paracetamol"] and not s.removed


@pytest.mark.parametrize("message", [
    "I'm pregnant and have a headache",
    "headache, and I have asthma",
    "sar dard hai aur mujhe dama hai",
    "headache but I take warfarin",
])
def test_ibuprofen_is_removed_for_pregnancy_asthma_and_blood_thinners(message):
    [s] = medicines.suggest(message)
    assert "ibuprofen" not in names(s) and "paracetamol" in names(s)
    assert s.removed and s.removed[0][0].name.startswith("ibuprofen")
    assert "LEFT OUT ibuprofen" in s.prompt_block()


def test_the_health_context_counts_too():
    [s] = medicines.suggest("I have period cramps", context="Profile: age 30. Pregnancy: pregnant, week 12.")
    assert names(s) == ["paracetamol"]


def test_liver_disease_removes_paracetamol():
    [s] = medicines.suggest("I have a fever and I have hepatitis")
    assert names(s) == ["ibuprofen"]


def test_thrush_first_time_or_pregnant_means_no_self_treatment():
    [s] = medicines.suggest("itching down there, first time this has happened")
    assert names(s) == []
    assert "do not name any" in s.prompt_block()
    [s] = medicines.suggest("I think I have a yeast infection")
    assert names(s) == ["clotrimazole vaginal cream or pessary"]


def test_young_age_removes_age_limited_options():
    [s] = medicines.suggest("I think I have thrush", context="Profile: age 14, height 150 cm.")
    assert names(s) == []


def test_no_problem_no_medicines():
    assert medicines.suggest("What is ovulation?") == []


def test_red_flags_are_always_in_the_block():
    [s] = medicines.suggest("bad headache")
    assert "See a doctor instead of self-treating if" in s.prompt_block()


# ---------------------------------------------------------------- wired into /chat

def test_chat_gives_the_model_notes_and_medicines_and_returns_sources(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "test")
    seen = {}

    def fake_post(model, body, timeout):
        seen["system"] = body["systemInstruction"]["parts"][0]["text"]
        seen["model"] = model
        seen["max"] = body["generationConfig"]["maxOutputTokens"]
        return {"candidates": [{"content": {"parts": [{"text": "**What may be causing it**\n- cramps"}]}}]}

    monkeypatch.setattr(companion, "_post", fake_post)
    r = TestClient(api.app).post("/chat", json={"messages": [{"role": "user", "text": "I'm pregnant and my period cramps hurt"}]})
    j = r.json()
    assert "TRUSTED NOTES" in seen["system"] and "Period pain" in seen["system"]
    assert "MEDICINE OPTIONS" in seen["system"] and "LEFT OUT ibuprofen" in seen["system"]
    assert seen["model"] == companion.CHAT_MODEL and seen["max"] > 1000
    assert j["sources"][0]["url"] == "https://www.nhs.uk/symptoms/period-pain/"


def test_spoken_answers_use_the_fast_model_and_stay_short(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "test")
    seen = {}

    def fake_post(model, body, timeout):
        seen["model"], seen["max"] = model, body["generationConfig"]["maxOutputTokens"]
        seen["system"] = body["systemInstruction"]["parts"][0]["text"]
        return {"candidates": [{"content": {"parts": [{"text": "ok"}]}}]}

    monkeypatch.setattr(companion, "_post", fake_post)
    TestClient(api.app).post("/chat", json={"messages": [{"role": "user", "text": "What is PCOS?"}], "brief": True})
    assert seen["model"] == companion.CHAT_MODEL_FAST and seen["max"] <= 1200 and "spoken aloud" in seen["system"]


def test_without_a_matching_problem_no_medicines_are_offered(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "test")
    seen = {}
    monkeypatch.setattr(companion, "_post", lambda m, b, timeout: seen.update(s=b["systemInstruction"]["parts"][0]["text"]) or
                        {"candidates": [{"content": {"parts": [{"text": "ok"}]}}]})
    TestClient(api.app).post("/chat", json={"messages": [{"role": "user", "text": "When is my fertile window?"}]})
    assert "MEDICINE OPTIONS (checked" not in seen["s"] and "TRUSTED NOTES" in seen["s"]
