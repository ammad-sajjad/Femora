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
| Breast ultrasound — ResNet50 (BUSI + BrEaST-Lesions-USG) | [femora-breast-ultrasound-resnet50](https://www.kaggle.com/code/ammad0/femora-breast-ultrasound-resnet50) | 🟡 Connected (v6): 73.7% test accuracy, 0.85 malignant ROC-AUC (5-fold CV 84.0%, 0.94). v7 (ultrasound gate + recipe comparison) trained on Kaggle, not installed yet |
| Breast cancer risk questionnaire — XGBoost (BCSC) | `ml/notebooks/breast_risk` | 🟡 Notebook ready; `backend/models` holds a synthetic **placeholder** until the BCSC data file is added |

### Retraining on Kaggle

```bash
ml/.venv/bin/python ml/build_notebooks.py
ml/.venv/bin/kaggle kernels push -p ml/notebooks/pcos
ml/.venv/bin/kaggle kernels output ammad0/femora-pcos-risk-xgboost -p ml/output/pcos
cp ml/output/pcos/model/pcos_xgb.json ml/output/pcos/model/pcos_meta.json backend/models/
```

## Breast health module: status & next steps

Endpoints: `POST /predict/breast/scan` (ultrasound image upload) and `POST /predict/breast/risk` (questionnaire).
App: `lib/screens/breast_health_screen.dart` (upload, results with heatmap, risk profile, self-exam guide + monthly reminder).

On Windows, start the backend with `backend\.venv\Scripts\uvicorn app:app --app-dir backend --host 0.0.0.0 --port 8000`
(first time: `uv venv backend/.venv --python 3.12`, then `uv pip install --python backend/.venv/Scripts/python.exe -r backend/requirements.txt`).

To do:
1. **Install notebook v7 outputs:** `ml/.venv/Scripts/kaggle kernels output ammad0/femora-breast-ultrasound-resnet50 -p ml/output/breast_ultrasound`,
   then copy `breast_resnet50.onnx`, `breast_meta.json` and `breast_gate.npz` to `backend/models/`, and the two `samples/*.png` to `assets/images/`.
   The backend applies the "is this an ultrasound?" gate once `breast_gate.npz` is present. Until then (v6), grayscale non-ultrasound images get through.
2. **Train the questionnaire model:** download the BCSC Risk Estimation dataset (https://www.bcsc-research.org/index.php/datasets/rfdataset) into `ml/data/bcsc/`,
   upload it as the private Kaggle dataset `ammad0/bcsc-risk-estimation`, push `ml/notebooks/breast_risk`, and replace the placeholder
   `breast_risk_xgb.json` / `breast_risk_meta.json`.
3. **Verify the Android build** (`flutter build apk --debug`) for the self-exam reminder notifications.

Data: BUSI (Al-Dhabyani et al., 2020, *Data in Brief*); BrEaST-Lesions-USG (Pawłowska et al., 2024, The Cancer Imaging Archive, CC BY 4.0).
The two demo scans in `assets/images/breast_sample_*.png` come from BrEaST's held-out test split.
