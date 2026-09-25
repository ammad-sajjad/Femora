"""Over-the-counter medicine suggestions, from a hand-checked table (not a trained model).

The companion may name a medicine only if it comes from this table. For each everyday problem the table lists common pharmacy
options available in Pakistan, who should not take each one, and the signs that mean a doctor is needed instead. Before the
options reach the language model, everything unsafe for this user is removed, using what she wrote and what the app knows
(pregnancy, breastfeeding, asthma, stomach ulcer, kidney or liver disease, blood thinners, age). The model is then told to
use only what is left, to say "follow the directions on the packet", and never to give doses or tell her to stop a medicine.

Sources: NHS medicines pages (checked 25 Sep 2026): ibuprofen, paracetamol, clotrimazole, loperamide, benzoyl peroxide, antacids;
NHS condition pages for constipation, dehydration and period pain.
"""
import re
from dataclasses import dataclass, field


@dataclass(frozen=True)
class Option:
    name: str  # generic name, with common local brand examples where helpful
    note: str  # one practical tip
    avoid: frozenset[str] = field(default_factory=frozenset)  # condition keys that rule this option out
    min_age: int = 12


@dataclass(frozen=True)
class Problem:
    id: str
    keywords: tuple[str, ...]
    options: tuple[Option, ...]
    red_flags: str  # when to see a doctor instead of self-treating


NSAID_AVOID = frozenset({"pregnant", "asthma", "ulcer", "kidney", "blood_thinner", "heart"})
PARACETAMOL_AVOID = frozenset({"liver"})

IBUPROFEN = Option("ibuprofen (for example Brufen)", "take it with or after food; it works best started at the first sign of pain",
                   NSAID_AVOID)
PARACETAMOL = Option("paracetamol (for example Panadol)", "do not take it together with other products that also contain paracetamol",
                     PARACETAMOL_AVOID)

PROBLEMS: list[Problem] = [
    Problem("period_pain",
            ("period pain", "cramps", "cramp", "painful period", "dysmenorrh", "pait dard", "pet dard", "pait mein dard", "mahwari dard",
             "periods mein dard", "پیٹ درد", "پیٹ میں درد", "ماہواری میں درد", "ماہواری درد", "مروڑ"),
            (IBUPROFEN, PARACETAMOL),
            "pain not helped by painkillers, pain between periods or during sex, fever, unusual discharge, or pain that is new or getting worse"),
    Problem("headache",
            ("headache", "migraine", "sir dard", "sar dard", "sar mein dard", "sir mein dard", "سر درد", "سر میں درد"),
            (PARACETAMOL, IBUPROFEN),
            "a sudden very severe headache, headache with stiff neck, fever or rash, after a head injury, with weakness, confusion or vision "
            "problems, or in pregnancy with swelling or blurred vision; also painkillers needed on more than 15 days a month"),
    Problem("fever",
            ("fever", "temperature", "bukhar", "بخار"),
            (PARACETAMOL, IBUPROFEN),
            "fever above 39 °C, lasting more than 3 days, with a stiff neck, rash, breathing difficulty or confusion, or any fever in pregnancy"),
    Problem("heartburn",
            ("heartburn", "acidity", "acid reflux", "indigestion", "tezabiyat", "tezabiat", "seene mein jalan", "تیزابیت", "سینے میں جلن", "بدہضمی"),
            (Option("an antacid or alginate syrup or tablet (for example Gaviscon or Mucaine)",
                    "take it after meals and at bedtime, and leave 2 hours between it and other medicines", frozenset({"kidney"})),),
            "heartburn most days for 3 weeks, difficulty swallowing, weight loss, vomiting, black stools, or chest pain spreading to the arm, "
            "jaw or back"),
    Problem("constipation",
            ("constipation", "qabz", "قبض", "hard stool"),
            (Option("ispaghula husk (isabgol)", "stir it into a full glass of water and drink plenty of fluids through the day", frozenset()),),
            "constipation for more than 2 weeks despite this, blood in the stool, weight loss, or severe tummy pain"),
    Problem("diarrhoea",
            ("diarrhoea", "diarrhea", "loose motion", "loose motions", "dast", "دست", "اسہال"),
            (Option("oral rehydration solution (ORS)", "sip it often, especially after each loose stool", frozenset(), min_age=0),
             Option("loperamide (for example Imodium)", "only for short-term relief, never with blood in the stool or a high fever",
                    frozenset({"pregnant", "breastfeeding", "bloody_stool"}))),
            "blood in the diarrhoea, high fever, severe tummy pain, signs of dehydration, or diarrhoea lasting more than 7 days"),
    Problem("thrush",
            ("thrush", "yeast infection", "fungal infection", "vaginal itching", "itching down there", "cottage cheese", "kharish", "khujli",
             "خارش", "کھجلی"),
            (Option("clotrimazole vaginal cream or pessary (for example Canesten)", "use the whole course even if itching settles sooner",
                    frozenset({"pregnant", "first_thrush"}), min_age=16),),
            "first time ever having these symptoms, pregnancy, under 16 or over 60, more than two episodes in 6 months, smelly or coloured "
            "discharge, fever, or tummy pain"),
    Problem("acne",
            ("acne", "pimples", "spots", "breakouts", "daane", "danay", "keel", "مہاسے", "دانے", "کیل"),
            (Option("benzoyl peroxide gel (for example Oxy or Benzac)", "start with a low strength once a day; it can dry the skin and bleach "
                    "fabric", frozenset()),),
            "acne that is moderate or severe, leaves scars, or affects your mood"),
    Problem("breast_pain",
            ("breast pain", "sore breasts", "tender breasts", "chhati mein dard", "چھاتی میں درد"),
            (PARACETAMOL, IBUPROFEN),
            "pain in one spot that does not go away after the next period, a lump, redness, warmth, swelling or fever"),
]

# Conditions recognised in her message or the app's health context (English, Roman Urdu, Urdu)
CONDITION_WORDS = {
    "pregnant": ("pregnan", "expecting a baby", "hamila", "hamla", "umeed se", "حاملہ", "حمل", "امید سے"),
    "breastfeeding": ("breastfeed", "breast feed", "nursing my baby", "doodh pilati", "دودھ پلاتی"),
    "asthma": ("asthma", "dama", "دمہ"),
    "ulcer": ("ulcer", "stomach bleed", "السر"),
    "kidney": ("kidney disease", "kidney problem", "gurde", "گردے"),
    "liver": ("liver disease", "hepatitis", "jigar", "یرقان", "جگر", "ہیپاٹائٹس"),
    "blood_thinner": ("warfarin", "blood thinner", "anticoagulant", "aspirin daily"),
    "heart": ("heart failure", "heart disease", "dil ki bimari", "دل کی بیماری"),
    "bloody_stool": ("blood in stool", "blood in my stool", "bloody diarrh", "khoon wale dast", "خون والے دست"),
    "first_thrush": ("first time", "never had", "pehli dafa", "پہلی دفعہ", "پہلی بار"),
}
CONDITION_LABELS = {
    "pregnant": "pregnancy", "breastfeeding": "breastfeeding", "asthma": "asthma", "ulcer": "a stomach ulcer", "kidney": "kidney disease",
    "liver": "liver disease", "blood_thinner": "a blood thinner", "heart": "heart disease", "bloody_stool": "blood in the stool",
    "first_thrush": "this being the first time",
}

AGE = re.compile(r"\bage (\d{1,2})\b")


def _has(text: str, words) -> bool:
    return any(w in text for w in words)


def conditions(text: str) -> set[str]:
    t = text.lower()
    return {k for k, words in CONDITION_WORDS.items() if _has(t, words)}


@dataclass
class Suggestion:
    problem: Problem
    options: list[Option]
    removed: list[tuple[Option, list[str]]]  # left out, and why

    def prompt_block(self) -> str:
        lines = [f"Problem: {self.problem.id.replace('_', ' ')}"]
        if self.options:
            lines += [f"- {o.name}: {o.note}" for o in self.options]
        else:
            lines.append("- No over-the-counter medicine is suitable for her from this list; do not name any. Say a pharmacist or doctor "
                         "can advise what is safe.")
        for o, why in self.removed:
            lines.append(f"- LEFT OUT {o.name} because of {', '.join(CONDITION_LABELS.get(w, w) for w in why)}: say briefly why she "
                         "should not take it.")
        lines.append(f"- See a doctor instead of self-treating if: {self.problem.red_flags}.")
        return "\n".join(lines)


def suggest(message: str, context: str | None = None, limit: int = 2) -> list[Suggestion]:
    """Medicine options for the problems in her message, with the unsafe ones removed."""
    t = message.lower()
    found = [p for p in PROBLEMS if _has(t, p.keywords)][:limit]
    if not found:
        return []
    cond = conditions(message) | conditions(context or "")
    m = AGE.search((context or "").lower())
    age = int(m.group(1)) if m else None
    out = []
    for p in found:
        keep, removed = [], []
        for o in p.options:
            why = sorted(o.avoid & cond)
            if age is not None and age < o.min_age:
                why.append(f"age under {o.min_age}")
            (removed.append((o, why)) if why else keep.append(o))
        out.append(Suggestion(p, keep, removed))
    return out
