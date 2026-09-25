"""Femora inference API.

Run from the repo root:
    backend/.venv/bin/uvicorn app:app --app-dir backend --host 0.0.0.0 --port 8000
"""
import base64
import io
import json
from pathlib import Path
from typing import Literal

import numpy as np
import onnxruntime as ort
import xgboost as xgb
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image, ImageOps, UnidentifiedImageError
from pydantic import BaseModel, Field

import companion
import lesion_outline
import places
import report_reader
import whatsapp

MODELS = Path(__file__).parent / "models"

app = FastAPI(title="Femora API", version="0.2.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
app.include_router(companion.router)   # AI companion: /chat, /voice/transcribe, /voice/speak
app.include_router(report_reader.router)  # /report/explain: photo of a medical report explained in Urdu or English
app.include_router(places.router)  # /places/nearby: hospitals, gynaecologists, clinics, labs, imaging
app.include_router(whatsapp.router)  # /whatsapp/webhook: the companion on WhatsApp (Meta Cloud API)

pcos_meta = json.loads((MODELS / "pcos_meta.json").read_text())
pcos_model = xgb.Booster()
pcos_model.load_model(MODELS / "pcos_xgb.json")

DISCLAIMER = (
    "This is a risk awareness estimate based on self-reported answers, not a medical diagnosis. "
    "Please consult a gynecologist or endocrinologist for proper evaluation."
)


# ---------------------------------------------------------------- PCOS

class PcosAnswers(BaseModel):
    age: int = Field(ge=12, le=60)
    height_cm: float = Field(ge=120, le=210)
    weight_kg: float = Field(ge=25, le=200)
    waist_in: float | None = Field(default=None, ge=15, le=70)
    hip_in: float | None = Field(default=None, ge=15, le=80)
    irregular_cycle: bool
    period_days: int = Field(ge=0, le=15)
    weight_gain: bool
    hair_growth: bool
    skin_darkening: bool
    hair_loss: bool
    pimples: bool
    fast_food: bool
    regular_exercise: bool


class Factor(BaseModel):
    key: str
    label: str


class Guidance(BaseModel):
    key: str  # icon hint for the app
    title: str
    description: str


class PcosResult(BaseModel):
    probability: float
    risk_level: str  # low | medium | high
    bmi: float
    factors: list[Factor]
    guidance: list[Guidance]
    disclaimer: str


# Median waist:hip ratio in the training data, used when the user skips the tape measurement
DEFAULT_WAIST_HIP = 0.89

FACTOR_LABELS = {
    "irregular_cycle": "Irregular Cycles",
    "weight_gain": "Weight Gain",
    "hair_growth": "Excess Hair Growth",
    "skin_darkening": "Skin Darkening",
    "hair_loss": "Hair Loss",
    "pimples": "Acne",
    "fast_food": "Frequent Fast Food",
    "regular_exercise": "Low Exercise",
    "waist_hip_ratio": "Waist-Hip Ratio",
}


def factor_label(feature: str, a: PcosAnswers) -> str | None:
    """Tag text for an answer that raised the risk, or None if the answer shouldn't be shown as a factor."""
    if feature == "period_days":
        return "Short Periods" if a.period_days <= 3 else "Long Periods" if a.period_days >= 7 else None
    if feature == "regular_exercise":
        return None if a.regular_exercise else FACTOR_LABELS[feature]
    if feature == "waist_hip_ratio":
        return FACTOR_LABELS[feature] if a.waist_in and a.hip_in else None
    if feature in FACTOR_LABELS and getattr(a, feature):
        return FACTOR_LABELS[feature]
    return None


def risk_level(p: float) -> str:
    bands = pcos_meta["risk_bands"]
    if p < bands["low"][1]:
        return "low"
    if p < bands["medium"][1]:
        return "medium"
    return "high"


def pcos_guidance(a: PcosAnswers, bmi: float, level: str) -> list[Guidance]:
    tips = []
    if level == "high":
        tips.append(Guidance(
            key="specialist",
            title="See a Specialist",
            description="Your answers match patterns commonly seen with PCOS. A gynecologist can confirm with "
                        "an ultrasound and hormone blood tests (LH, FSH, AMH, testosterone).",
        ))
    elif level == "medium":
        tips.append(Guidance(
            key="monitor",
            title="Keep Monitoring",
            description="Some of your answers are associated with PCOS. Track your cycles for the next 2–3 months "
                        "and consult a doctor if they stay irregular.",
        ))
    if bmi >= 25 or a.weight_gain:
        tips.append(Guidance(
            key="nutrition",
            title="Nutrition Adjustments",
            description="Choose high-fiber, low-glycemic foods and lean protein to help stabilize blood sugar "
                        "and insulin levels.",
        ))
    if not a.regular_exercise:
        tips.append(Guidance(
            key="exercise",
            title="Lifestyle Focus",
            description="Around 150 minutes of moderate activity a week, including strength training, "
                        "can improve insulin sensitivity.",
        ))
    if a.irregular_cycle:
        tips.append(Guidance(
            key="tracking",
            title="Track Your Cycle",
            description="Log your period dates in Femora so cycle irregularity can be monitored over time.",
        ))
    if not tips:
        tips.append(Guidance(
            key="healthy",
            title="Healthy Habits",
            description="Your answers suggest a low risk. Keep a balanced diet, stay active and keep logging your cycles.",
        ))
    return tips


@app.get("/health")
def health():
    models = ["pcos", "breast_scan", "breast_risk"] + (["lesion_outline"] if outliner is not None else [])
    return {"status": "ok", "models": models, "companion": companion.api_key() is not None, "whatsapp": whatsapp.enabled(),
            "places": "google" if places.google_key() else "openstreetmap"}


def pcos_values(a: PcosAnswers) -> dict[str, float]:
    """The model's inputs for one set of answers."""
    bmi = a.weight_kg / (a.height_cm / 100) ** 2
    waist_hip = a.waist_in / a.hip_in if a.waist_in and a.hip_in else DEFAULT_WAIST_HIP
    return {
        "bmi": bmi,
        "irregular_cycle": int(a.irregular_cycle),
        "period_days": a.period_days,
        "waist_hip_ratio": waist_hip,
        "weight_gain": int(a.weight_gain),
        "hair_growth": int(a.hair_growth),
        "skin_darkening": int(a.skin_darkening),
        "hair_loss": int(a.hair_loss),
        "pimples": int(a.pimples),
        "fast_food": int(a.fast_food),
        "regular_exercise": int(a.regular_exercise),
    }


def pcos_matrix(values: dict[str, float]) -> "xgb.DMatrix":
    features = pcos_meta["features"]
    return xgb.DMatrix(np.array([[values[f] for f in features]], dtype=float), feature_names=features)


@app.post("/predict/pcos", response_model=PcosResult)
def predict_pcos(a: PcosAnswers):
    values = pcos_values(a)
    bmi = values["bmi"]
    features = pcos_meta["features"]
    dm = pcos_matrix(values)
    p = float(pcos_model.predict(dm)[0])

    # Per-answer contributions (SHAP values) — the answers pushing risk up become the result tags
    contribs = pcos_model.predict(dm, pred_contribs=True)[0][:-1]
    ranked = sorted(zip(features, contribs), key=lambda fc: fc[1], reverse=True)
    factors = [Factor(key=f, label=label) for f, c in ranked if c > 0.05 and (label := factor_label(f, a))]
    if bmi >= 25:
        factors.insert(0, Factor(key="bmi", label=f"BMI {bmi:.1f}"))

    level = risk_level(p)
    return PcosResult(
        probability=round(p, 4),
        risk_level=level,
        bmi=round(bmi, 1),
        factors=factors[:3],
        guidance=pcos_guidance(a, bmi, level),
        disclaimer=DISCLAIMER,
    )


# ---------------------------------------------------------------- PCOS "what if"

class WhatIfChange(BaseModel):
    """One scenario: the things a person can influence, changed. Anything left out stays as answered."""
    label: str = Field(min_length=1, max_length=60)
    weight_kg: float | None = Field(default=None, ge=25, le=200)
    waist_in: float | None = Field(default=None, ge=15, le=70)
    regular_exercise: bool | None = None
    fast_food: bool | None = None


class WhatIfRequest(BaseModel):
    answers: PcosAnswers
    scenarios: list[WhatIfChange] = Field(min_length=1, max_length=8)


class WhatIfOutcome(BaseModel):
    label: str
    probability: float
    risk_level: str
    bmi: float
    change_points: float  # percentage points against the answers as given (negative = lower)


class WhatIfResult(BaseModel):
    baseline_probability: float
    baseline_risk_level: str
    outcomes: list[WhatIfOutcome]
    note: str


WHATIF_NOTE = (
    "This shows what the model would estimate if those answers were different. It comes from a small study of 541 women and "
    "describes patterns, not what will happen to you. Please do not change your diet, exercise or weight because of it without asking your doctor."
)


@app.post("/predict/pcos/whatif", response_model=WhatIfResult)
def predict_pcos_whatif(req: WhatIfRequest):
    a = req.answers
    base_p = float(pcos_model.predict(pcos_matrix(pcos_values(a)))[0])
    outcomes = []
    for sc in req.scenarios:
        changed = a.model_copy(update={k: v for k, v in {
            "weight_kg": sc.weight_kg,
            "waist_in": sc.waist_in,
            "regular_exercise": sc.regular_exercise,
            "fast_food": sc.fast_food,
        }.items() if v is not None})
        values = pcos_values(changed)
        p = float(pcos_model.predict(pcos_matrix(values))[0])
        outcomes.append(WhatIfOutcome(label=sc.label, probability=round(p, 4), risk_level=risk_level(p), bmi=round(values["bmi"], 1),
                                      change_points=round((p - base_p) * 100, 1)))
    return WhatIfResult(baseline_probability=round(base_p, 4), baseline_risk_level=risk_level(base_p), outcomes=outcomes, note=WHATIF_NOTE)


# ---------------------------------------------------------------- Breast ultrasound (Module A)

breast_meta = json.loads((MODELS / "breast_meta.json").read_text())
breast_session = ort.InferenceSession(str(MODELS / breast_meta["onnx_file"]), providers=["CPUExecutionProvider"])
# The "is this an ultrasound?" gate ships with models trained by notebook version 7 onwards
breast_gate = dict(np.load(MODELS / breast_meta["gate_file"])) if "gate_file" in breast_meta else None
outliner = lesion_outline.load()   # optional second model that draws the lesion's outline

SCAN_CLASSES = breast_meta["classes"]  # normal, benign, malignant
MALIGNANT = SCAN_CLASSES.index("malignant")
SCAN_SIZE = breast_meta["input"]["size"]
SCAN_MEAN = np.array(breast_meta["input"]["mean"], np.float32)[:, None, None]
SCAN_STD = np.array(breast_meta["input"]["std"], np.float32)[:, None, None]
MAX_UPLOAD_BYTES = 10 * 1024 * 1024
HEATMAP_SIZE = 512

SCAN_DISCLAIMER = (
    "This AI screening is an assistive tool and does not replace professional medical diagnosis. "
    "Consult your doctor for conclusive results."
)
SCAN_TITLES = {"normal": "Likely Normal", "benign": "Likely Benign", "malignant": "Suspicious Finding"}


class ScanProbability(BaseModel):
    key: str
    label: str
    probability: float


class BreastScanResult(BaseModel):
    prediction: str  # normal | benign | malignant
    title: str
    confidence: float  # calibrated probability of the predicted class
    probabilities: list[ScanProbability]
    heatmap_jpeg: str | None  # base64 JPEG of the scan with the model's focus overlaid (benign / malignant only)
    outline: lesion_outline.LesionOutline | None = None  # the lesion's edge, shape and relative size (benign / malignant only)
    summary: str  # plain-language explanation, also handed to the AI companion
    guidance: list[Guidance]
    model_accuracy: float  # accuracy on held-out test scans, shown for context
    disclaimer: str


# Preprocessing must match ml/build_notebooks.py (BREAST_ULTRASOUND) exactly
def pad_square(img: Image.Image, fill: int = 0) -> Image.Image:
    w, h = img.size
    s = max(w, h)
    canvas = Image.new(img.mode, (s, s), fill)
    canvas.paste(img, ((s - w) // 2, (s - h) // 2))
    return canvas


def to_gray(img: Image.Image) -> Image.Image:
    if img.mode in ("I", "I;16", "I;16B", "F"):  # 16-bit / float exports from hospital systems: stretch to 8 bits
        a = np.asarray(img, np.float32)
        a = (a - a.min()) / max(float(a.max() - a.min()), 1e-6) * 255
        return Image.fromarray(a.astype(np.uint8))
    return img.convert("L")


def scan_tensor(gray: Image.Image) -> np.ndarray:
    x = np.asarray(pad_square(gray).resize((SCAN_SIZE, SCAN_SIZE), Image.BILINEAR), np.float32) / 255.0
    return ((np.repeat(x[None], 3, 0) - SCAN_MEAN) / SCAN_STD)[None].astype(np.float32)


def colour_fraction(img: Image.Image) -> float:
    """Share of clearly coloured pixels: B-mode ultrasound is grey (sometimes tinted), photos and Doppler are not."""
    a = np.asarray(img.convert("RGB").resize((128, 128)), np.int16)
    diff = np.maximum.reduce([abs(a[..., 0] - a[..., 1]), abs(a[..., 1] - a[..., 2]), abs(a[..., 0] - a[..., 2])])
    return float((diff > 30).mean())


def ultrasound_score(embedding: np.ndarray) -> float:
    """The ultrasound gate's probability that the image is a breast ultrasound (logistic regression on the embedding)."""
    z = (embedding - breast_gate["mean"]) / breast_gate["scale"]
    return float(1 / (1 + np.exp(-(z @ breast_gate["coef"] + breast_gate["intercept"]))))


# Heatmap colours: blue -> cyan -> yellow -> red
HEAT_STOPS = np.array([0.0, 0.35, 0.65, 1.0])
HEAT_COLOURS = np.array([[0, 0, 255], [0, 255, 255], [255, 255, 0], [255, 0, 0]], np.float32)


def heatmap_jpeg(gray: Image.Image, cam: np.ndarray) -> str:
    """Overlays the class activation map on the scan, cropped back to the scan's shape, as a base64 JPEG."""
    w, h = gray.size
    s = HEATMAP_SIZE
    base = np.asarray(pad_square(gray).resize((s, s), Image.BILINEAR), np.float32)
    c = np.maximum(cam, 0)
    c = c / c.max() if c.max() > 0 else c
    heat = np.asarray(Image.fromarray((c * 255).astype(np.uint8)).resize((s, s), Image.BILINEAR), np.float32) / 255
    colour = np.stack([np.interp(heat, HEAT_STOPS, HEAT_COLOURS[:, k]) for k in range(3)], -1)
    alpha = 0.6 * heat[..., None]  # cool areas stay see-through so the scan remains readable
    out = base[..., None] * (1 - alpha) + colour * alpha
    sw, sh = round(w * s / max(w, h)), round(h * s / max(w, h))
    left, top = (s - sw) // 2, (s - sh) // 2
    buf = io.BytesIO()
    Image.fromarray(out.clip(0, 255).astype(np.uint8)).crop((left, top, left + sw, top + sh)).save(buf, format="JPEG", quality=85)
    return base64.b64encode(buf.getvalue()).decode()


def scan_summary(prediction: str, p: np.ndarray, accuracy: float) -> str:
    pct = {c: round(float(v) * 100) for c, v in zip(SCAN_CLASSES, p)}
    if prediction == "malignant":
        text = (f"The AI flagged this scan as suspicious. It estimates a {pct['malignant']}% likelihood that the "
                "highlighted area is malignant. This is not a diagnosis: many suspicious-looking areas turn out to be "
                "benign after further tests. Please show this scan to a doctor or breast specialist soon.")
    elif prediction == "benign":
        text = (f"The AI rated the area it found as most likely benign ({pct['benign']}%), meaning not cancer. Benign "
                "findings such as cysts and fibroadenomas are common. The heatmap shows where the model looked. Your "
                "doctor will decide whether it needs a follow-up scan.")
    else:
        text = (f"The AI did not find a lesion-like area and rated this scan {pct['normal']}% likely normal. That is "
                "reassuring, but keep doing monthly self-exams and follow your doctor's screening advice.")
    return f"{text} On scans it had never seen before, the model was right {accuracy:.0%} of the time."


def scan_guidance(prediction: str) -> list[Guidance]:
    if prediction == "malignant":
        return [
            Guidance(key="specialist", title="See a Specialist Soon",
                     description="Share this scan with a breast specialist or radiologist within the next two weeks. "
                                 "They may recommend a biopsy, which is the only way to know for sure."),
            Guidance(key="report", title="Bring Your Report",
                     description="Take the original ultrasound images and the radiologist's written report "
                                 "(with its BI-RADS score) to your appointment."),
            Guidance(key="support", title="Don't Panic",
                     description="Many findings that look suspicious on ultrasound turn out to be benign after further tests."),
        ]
    if prediction == "benign":
        return [
            Guidance(key="monitor", title="Follow Up With Your Doctor",
                     description="Benign findings such as cysts and fibroadenomas are common. Your doctor will tell you "
                                 "whether a repeat scan in a few months is needed."),
            Guidance(key="self_exam", title="Monthly Self-Exam",
                     description="Check your breasts once a month and report any change in the lump's size or feel."),
        ]
    return [
        Guidance(key="self_exam", title="Monthly Self-Exam",
                 description="Keep checking your breasts once a month, a few days after your period ends."),
        Guidance(key="screening", title="Routine Screening",
                 description="From age 40, ask your doctor about a mammogram every 1–2 years. In Pakistan, breast "
                             "cancer is most common between 40 and 50."),
    ]


@app.post("/predict/breast/scan", response_model=BreastScanResult)
def predict_breast_scan(image: UploadFile = File(...)):
    data = image.file.read(MAX_UPLOAD_BYTES + 1)
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(413, "The image is larger than 10 MB. Please upload a smaller file.")
    try:
        img = Image.open(io.BytesIO(data))
        img.load()
    except (UnidentifiedImageError, OSError):
        raise HTTPException(422, "This file isn't an image we can read. Please upload a PNG or JPG scan.")
    img = ImageOps.exif_transpose(img)
    gray = to_gray(img)

    # Reject uploads the model was never trained for, before trusting its prediction
    if img.mode not in ("L", "I", "I;16", "I;16B", "F") and colour_fraction(img) > breast_meta["colour_limit"]:
        raise HTTPException(422, "This looks like a colour photo or a colour Doppler scan. "
                                 "Please upload a grayscale (B-mode) breast ultrasound image.")
    logits, embedding, cam = breast_session.run(None, {"image": scan_tensor(gray)})
    if breast_gate is not None and ultrasound_score(embedding[0]) < breast_meta["gate_threshold"]:
        raise HTTPException(422, "This doesn't look like a breast ultrasound scan. Please upload the ultrasound "
                                 "image itself, cropped to the scan if possible.")

    z = logits[0] / breast_meta["temperature"]
    p = np.exp(z - z.max())
    p /= p.sum()
    # Screening rule: flag as suspicious whenever P(malignant) passes the sensitivity-tuned threshold
    k = MALIGNANT if p[MALIGNANT] >= breast_meta["malignant_threshold"] else int(p.argmax())
    prediction = SCAN_CLASSES[k]
    accuracy = breast_meta["test_metrics"]["accuracy"]
    return BreastScanResult(
        prediction=prediction,
        title=SCAN_TITLES[prediction],
        confidence=round(float(p[k]), 4),
        probabilities=[ScanProbability(key=c, label=c.capitalize(), probability=round(float(v), 4))
                       for c, v in zip(SCAN_CLASSES, p)],
        heatmap_jpeg=heatmap_jpeg(gray, cam[0, k]) if prediction != "normal" else None,
        outline=outliner.outline(gray) if outliner is not None and prediction != "normal" else None,
        summary=scan_summary(prediction, p, accuracy),
        guidance=scan_guidance(prediction),
        model_accuracy=accuracy,
        disclaimer=SCAN_DISCLAIMER,
    )


# ---------------------------------------------------------------- Breast cancer risk questionnaire (Module B)

risk_meta = json.loads((MODELS / "breast_risk_meta.json").read_text())
risk_model = xgb.Booster()
risk_model.load_model(MODELS / "breast_risk_xgb.json")

RISK_DISCLAIMER = (
    "This is a risk awareness estimate based on self-reported answers, not a medical diagnosis. "
    "Please see a doctor for a clinical breast examination and screening advice."
)
RISK_LEVEL_TEXT = {"low": "low", "medium": "moderately raised", "high": "high"}

Symptom = Literal["breast_lump", "armpit_lump", "nipple_discharge", "nipple_change", "skin_change",
                  "shape_change", "breast_pain"]

# NICE NG12 suspected-cancer referral rules: the age from which a symptom needs an urgent (2-week) appointment.
# None = see a doctor, but not urgently. Breast pain alone is not a warning sign.
SYMPTOM_RULES = {
    "breast_lump": ("Breast Lump", 30),
    "armpit_lump": ("Armpit Lump", 30),
    "nipple_discharge": ("Nipple Discharge", 50),
    "nipple_change": ("Nipple Changes", 50),
    "skin_change": ("Skin Changes", 0),
    "shape_change": ("Change in Size or Shape", None),
}


class BreastRiskAnswers(BaseModel):
    age: int = Field(ge=18, le=100)
    height_cm: float = Field(ge=120, le=210)
    weight_kg: float = Field(ge=25, le=200)
    menopause: Literal["pre", "post", "unknown"]
    hormone_therapy: bool | None = None  # currently on HRT; only asked after menopause, None = not sure
    surgical_menopause: bool | None = None  # menopause caused by removing the ovaries
    first_birth: Literal["under_30", "30_or_older", "never", "unknown"]
    relatives_with_breast_cancer: int | None = Field(default=None, ge=0, le=2)  # mother/sister/daughter; 2 = two or more
    breast_biopsy: bool | None = None
    breast_density: Literal["a", "b", "c", "d"] | None = None  # BI-RADS density from a mammogram report
    last_mammogram: Literal["normal", "false_positive"] | None = None  # None = never had one / don't know
    symptoms: list[Symptom] = []


class RedFlag(BaseModel):
    key: str
    label: str
    urgency: str  # urgent | soon


class BreastRiskResult(BaseModel):
    probability: float  # estimated chance of a breast cancer diagnosis in the next year
    average_probability: float  # the same for the average woman in the age group
    relative_risk: float
    risk_level: str  # low | medium | high
    age_group: str
    factors: list[Factor]
    red_flags: list[RedFlag]
    urgency: str  # none | soon | urgent, from the reported symptoms
    guidance: list[Guidance]
    notes: list[str]
    summary: str
    disclaimer: str


def risk_features(a: BreastRiskAnswers, bmi: float) -> dict[str, float]:
    """Answers -> BCSC Risk Estimation coding. NaN = unknown (BCSC code 9)."""
    nan = float("nan")
    post_menopause = a.age >= 55 or a.menopause == "post"  # BCSC codes "post-menopausal or age 55+" together
    return {
        "agegrp": min(max((a.age - 35) // 5 + 1, 1), 10),
        "menopaus": 1 if post_menopause else 0 if a.menopause == "pre" else nan,
        "bmi": 1 if bmi < 25 else 2 if bmi < 30 else 3 if bmi < 35 else 4,
        "agefirst": {"under_30": 0, "30_or_older": 1, "never": 2}.get(a.first_birth, nan),
        "nrelbc": nan if a.relatives_with_breast_cancer is None else a.relatives_with_breast_cancer,
        "brstproc": nan if a.breast_biopsy is None else int(a.breast_biopsy),
        "hrt": int(a.hormone_therapy) if post_menopause and a.hormone_therapy is not None else nan,
        "surgmeno": int(a.surgical_menopause) if post_menopause and a.surgical_menopause is not None else nan,
        "density": {"a": 1, "b": 2, "c": 3, "d": 4}.get(a.breast_density, nan),
        "lastmamm": {"normal": 0, "false_positive": 1}.get(a.last_mammogram, nan),
    }


def risk_factor_label(feature: str, v: float, bmi: float) -> str | None:
    """Tag text for an answer that raised the risk, or None if it shouldn't be shown as a factor."""
    if np.isnan(v):
        return None
    if feature == "nrelbc" and v >= 1:
        return "Family History" if v == 1 else "Strong Family History"
    if feature == "brstproc" and v == 1:
        return "Previous Biopsy"
    if feature == "density" and v >= 3:
        return "Dense Breasts"
    if feature == "hrt" and v == 1:
        return "Hormone Therapy"
    if feature == "agefirst" and v >= 1:
        return "First Birth After 30" if v == 1 else "No Births"
    if feature == "bmi" and v >= 2:
        return f"BMI {bmi:.1f}"
    if feature == "lastmamm" and v == 1:
        return "Past Abnormal Mammogram"
    return None


def red_flags(a: BreastRiskAnswers) -> list[RedFlag]:
    flags = []
    for s in a.symptoms:
        if s in SYMPTOM_RULES:
            label, urgent_from = SYMPTOM_RULES[s]
            urgent = urgent_from is not None and a.age >= urgent_from
            flags.append(RedFlag(key=s, label=label, urgency="urgent" if urgent else "soon"))
    return sorted(flags, key=lambda f: f.urgency != "urgent")


def risk_guidance(a: BreastRiskAnswers, values: dict, level: str, flags: list[RedFlag]) -> list[Guidance]:
    tips = []
    reported = ", ".join(f.label.lower() for f in flags)
    if flags and flags[0].urgency == "urgent":
        tips.append(Guidance(
            key="urgent",
            title="See a Doctor Within 2 Weeks",
            description=f"You reported: {reported}. Doctors recommend getting this checked promptly. Most of these "
                        "turn out not to be cancer, but only an examination (usually with an ultrasound) can tell.",
        ))
    elif flags:
        tips.append(Guidance(
            key="specialist",
            title="Book a Check-Up",
            description=f"You reported: {reported}. It is most likely harmless, but a doctor should examine it.",
        ))
    elif "breast_pain" in a.symptoms:
        tips.append(Guidance(
            key="info",
            title="About Breast Pain",
            description="Breast pain on its own is rarely a sign of cancer and often follows your cycle. See a doctor "
                        "if it lasts more than a few weeks or you notice a lump or other change.",
        ))
    if level == "high":
        genetics = " and about genetic counselling (BRCA testing)" if values["nrelbc"] == 2 else ""
        tips.append(Guidance(
            key="screening",
            title="Talk to a Doctor About Screening",
            description="Your risk factors add up to well above average for your age. Ask a doctor about starting "
                        f"screening earlier or more often{genetics}.",
        ))
    elif level == "medium":
        tips.append(Guidance(
            key="screening",
            title="Discuss Your Screening Plan",
            description="Your risk is somewhat above average for your age. A doctor can advise when to start "
                        "mammograms and how often.",
        ))
    elif a.age >= 40:
        tips.append(Guidance(
            key="screening",
            title="Routine Screening",
            description="From age 40, ask your doctor about a mammogram every 1–2 years. In Pakistan, breast cancer "
                        "is most common between 40 and 50.",
        ))
    if values["menopaus"] == 1 and values["bmi"] >= 2:
        tips.append(Guidance(
            key="nutrition",
            title="Healthy Weight",
            description="After menopause, extra weight raises breast cancer risk. Regular activity and a balanced "
                        "diet help.",
        ))
    if values["hrt"] == 1:
        tips.append(Guidance(
            key="hrt",
            title="Review Hormone Therapy",
            description="Hormone therapy slightly raises breast cancer risk. Ask your doctor whether you still need it.",
        ))
    tips.append(Guidance(
        key="self_exam",
        title="Monthly Self-Exam",
        description="Check your breasts once a month so you notice changes early. Femora can remind you.",
    ))
    return tips[:4]


def risk_notes(a: BreastRiskAnswers, group: str) -> list[str]:
    notes = []
    if risk_meta.get("placeholder"):
        notes.append("Demo model: this estimate comes from a placeholder trained on synthetic data, not real patients.")
    if a.age < 35:
        notes.append(f"The risk model is based on women aged 35–84, so it used the {group} group for you. Breast "
                     "cancer is less common at your age, so treat this as an upper estimate.")
    elif a.age > 84:
        notes.append(f"The risk model is based on women aged 35–84, so it used the {group} group for you.")
    if a.breast_density is None and a.age >= 40:
        notes.append("Adding your breast density from a mammogram report makes the estimate more precise.")
    return notes


@app.post("/predict/breast/risk", response_model=BreastRiskResult)
def predict_breast_risk(a: BreastRiskAnswers):
    bmi = a.weight_kg / (a.height_cm / 100) ** 2
    values = risk_features(a, bmi)
    features = risk_meta["features"]
    dm = xgb.DMatrix(np.array([[values[f] for f in features]], dtype=float), feature_names=features)
    p = float(risk_model.predict(dm)[0])

    # Compare with the average woman of the same age, so age alone never makes someone "high risk"
    average = risk_meta["age_average_risk"][str(values["agegrp"])]
    rr = p / average
    bands = risk_meta["relative_risk_bands"]
    level = "low" if rr < bands["medium"][0] else "medium" if rr < bands["high"][0] else "high"
    group = risk_meta["age_groups"][str(values["agegrp"])]

    # Per-answer contributions (SHAP values); age is excluded because it is already the comparison baseline
    contribs = risk_model.predict(dm, pred_contribs=True)[0][:-1]
    ranked = sorted(zip(features, contribs), key=lambda fc: fc[1], reverse=True)
    factors = [Factor(key=f, label=label) for f, c in ranked
               if c > 0.05 and f != "agegrp" and (label := risk_factor_label(f, values[f], bmi))][:3]
    flags = red_flags(a)

    summary = (f"Based on your answers, your estimated chance of a breast cancer diagnosis in the next year is "
               f"{p:.2%}, compared with {average:.2%} for the average woman aged {group}. That is {rr:.1f} times "
               f"the average, which Femora counts as {RISK_LEVEL_TEXT[level]} risk.")
    if factors:
        summary += " The answers that raised your estimate most: " + ", ".join(f.label.lower() for f in factors) + "."
    if flags:
        summary += (" Separately, you reported symptoms a doctor should check: "
                    + ", ".join(f.label.lower() for f in flags) + ".")
    return BreastRiskResult(
        probability=round(p, 5),
        average_probability=round(average, 5),
        relative_risk=round(rr, 2),
        risk_level=level,
        age_group=group,
        factors=factors,
        red_flags=flags,
        urgency=flags[0].urgency if flags else "none",
        guidance=risk_guidance(a, values, level, flags),
        notes=risk_notes(a, group),
        summary=summary,
        disclaimer=RISK_DISCLAIMER,
    )
