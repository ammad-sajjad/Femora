# Femora

AI-powered women's health & wellness app (FYP, Air University Islamabad).

```
lib/        Flutter app
backend/    FastAPI server that serves the trained ML models
ml/         Kaggle training notebooks (built by ml/build_notebooks.py)
```

## Running the PCOS risk flow

**1. Start the backend** (first time only: `python3 -m venv backend/.venv && backend/.venv/bin/pip install -r backend/requirements.txt`, and on macOS `brew install libomp`)

```bash
backend/.venv/bin/uvicorn app:app --app-dir backend --host 0.0.0.0 --port 8000
```

Check it at http://localhost:8000/docs.

**2. Run the app**

| Where the app runs | Command |
|---|---|
| Android emulator | `flutter run` (uses `http://10.0.2.2:8000` automatically) |
| Chrome / iOS simulator | `flutter run` (uses `http://localhost:8000`) |
| Physical phone (same Wi-Fi) | `flutter run --dart-define=API_BASE_URL=http://<your-computer-ip>:8000` |

Find your computer's IP on macOS with `ipconfig getifaddr en0`.

## Models

| Model | Notebook | Status |
|---|---|---|
| PCOS risk — XGBoost (self-reported features) | [femora-pcos-risk-xgboost](https://www.kaggle.com/code/ammad0/femora-pcos-risk-xgboost) | ✅ Trained & connected — 84.4% accuracy, 0.88 ROC-AUC |
| Cycle prediction — Random Forest | — | Planned |
| Personalized cycle — LSTM | — | Planned |
| Breast ultrasound — ResNet50 | — | Planned |
| Breast symptom risk | — | Planned |

### Retraining on Kaggle

```bash
ml/.venv/bin/python ml/build_notebooks.py
ml/.venv/bin/kaggle kernels push -p ml/notebooks/pcos
ml/.venv/bin/kaggle kernels output ammad0/femora-pcos-risk-xgboost -p ml/output/pcos
cp ml/output/pcos/model/pcos_xgb.json ml/output/pcos/model/pcos_meta.json backend/models/
```
