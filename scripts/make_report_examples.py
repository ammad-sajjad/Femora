"""Records the real API examples the Word report prints (ml/output/report_examples.json).

Run with the backend running, then rebuild the report:
    backend/.venv/Scripts/uvicorn app:app --app-dir backend --host 127.0.0.1 --port 8000
    <python> scripts/make_report_examples.py [http://127.0.0.1:8000]

ml/output/ is not in git, so this file has to be recreated on a fresh clone before scripts/build_report.py runs.
The two request bodies are the ones section 3.3 of the report describes; keep them unchanged so the printed
answers stay comparable between report versions.
"""
import json
import sys
import urllib.request
from pathlib import Path

BASE = sys.argv[1].rstrip("/") if len(sys.argv) > 1 else "http://127.0.0.1:8000"
OUT = Path(__file__).resolve().parent.parent / "ml" / "output" / "report_examples.json"

PCOS_REQ = {"age": 24, "height_cm": 160, "weight_kg": 68, "waist_in": 32, "hip_in": 38, "irregular_cycle": True,
            "period_days": 4, "weight_gain": True, "hair_growth": True, "skin_darkening": False, "hair_loss": False,
            "pimples": True, "fast_food": True, "regular_exercise": False}
RISK_REQ = {"age": 52, "height_cm": 160, "weight_kg": 72, "menopause": "post", "hormone_therapy": False,
            "surgical_menopause": False, "first_birth": "30_or_older", "relatives_with_breast_cancer": 1,
            "breast_biopsy": True, "breast_density": "c", "last_mammogram": "normal", "symptoms": ["breast_lump"]}


def post(path, body):
    req = urllib.request.Request(BASE + path, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read())


examples = {"pcos_req": PCOS_REQ, "pcos": post("/predict/pcos", PCOS_REQ),
            "risk_req": RISK_REQ, "risk": post("/predict/breast/risk", RISK_REQ)}
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(examples, indent=1, ensure_ascii=False), encoding="utf-8")
print(f"wrote {OUT}: PCOS {examples['pcos']['probability']} ({examples['pcos']['risk_level']}), "
      f"breast risk {examples['risk']['probability']} ({examples['risk']['risk_level']})")
