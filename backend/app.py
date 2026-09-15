"""Femora inference API.

Run from the repo root:
    backend/.venv/bin/uvicorn app:app --app-dir backend --host 0.0.0.0 --port 8000
"""
import json
from pathlib import Path

import numpy as np
import xgboost as xgb
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

MODELS = Path(__file__).parent / "models"

app = FastAPI(title="Femora API", version="0.1.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

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
    return {"status": "ok", "models": ["pcos"]}


@app.post("/predict/pcos", response_model=PcosResult)
def predict_pcos(a: PcosAnswers):
    bmi = a.weight_kg / (a.height_cm / 100) ** 2
    waist_hip = a.waist_in / a.hip_in if a.waist_in and a.hip_in else DEFAULT_WAIST_HIP
    values = {
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
    features = pcos_meta["features"]
    dm = xgb.DMatrix(np.array([[values[f] for f in features]], dtype=float), feature_names=features)
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
