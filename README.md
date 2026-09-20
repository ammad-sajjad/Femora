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
| Breast ultrasound — ResNet50 (BUSI + BrEaST + BUS-BRA) | [femora-breast-ultrasound-resnet50-busbra](https://www.kaggle.com/code/ammad0/femora-breast-ultrasound-resnet50-busbra) | 🟡 Connected (BUS-BRA model, replaces v7): AUC 0.87 / sensitivity 91% / specificity 53% on 562 held-out BUS-BRA scans (unseen patients); v7 scored AUC 0.69 / 72% / 58% on the same scans. On v7's original 148 test scans: AUC 0.88, sensitivity 90%, specificity 73%, accuracy 77% (v7: 0.84, 81%, 81%, 80%). Ultrasound gate included |
| Breast cancer risk questionnaire — XGBoost (BCSC) | `ml/notebooks/breast_risk` | 🟡 Notebook ready; `backend/models` holds a synthetic **placeholder** until the BCSC data file is added |

### Breast ultrasound: v7 vs the BUS-BRA model

- The BUS-BRA notebook is a separate copy of v7's pipeline (`ml/build_notebooks.py`, `BREAST_ULTRASOUND_BUSBRA`). BUSI/BrEaST keep v7's exact split (`ml/v7_split.csv`); BUS-BRA is split by patient (60/10/30%).
- It flags more cancers (higher sensitivity) at the cost of more false alarms on the old test scans, and generalises much better to a new hospital. BrEaST (35 test scans, AUC 0.65) did not improve, and the U-Systems / Toshiba scanners are still weak (few scans).
- The accuracy shown in the app is the model's accuracy on the combined test set (68%): it includes the harder BUS-BRA scans and the screening threshold that favours catching cancer.
- **BUS-UCLM round (not deployed):** adding BUS-UCLM (`femora-breast-ultrasound-resnet50-uclm`, train/validation only, same 710 test scans) gave no measurable gain: AUC 0.868 vs 0.869 overall and 0.863 vs 0.866 on BUS-BRA, with lower sensitivity (85% vs 91%; its screening threshold drifted to 0.13). Marked and Doppler UCLM images were excluded on purpose (marks would leak the label). Its BrEaST AUC rose 0.65 to 0.84 but that is only 35 scans, within noise.
- To go back to v7: rerun `kaggle kernels output ammad0/femora-breast-ultrasound-resnet50 -p ml/output/breast_ultrasound` (version 7) and copy its `model/` files into `backend/models/`.
- Cite: Gómez-Flores et al., *BUS-BRA*, Medical Physics 2024.

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
1. ~~Install notebook v7 outputs~~ — done: `backend/models/` holds the v7 ONNX, meta and `breast_gate.npz`; the gate rejects colour and non-ultrasound uploads.
2. **Train the questionnaire model:** download the BCSC Risk Estimation dataset (https://www.bcsc-research.org/index.php/datasets/rfdataset) into `ml/data/bcsc/`,
   upload it as the private Kaggle dataset `ammad0/bcsc-risk-estimation`, push `ml/notebooks/breast_risk`, and replace the placeholder
   `breast_risk_xgb.json` / `breast_risk_meta.json`.
3. ~~Verify the Android build~~ — `flutter build apk --debug` succeeds (self-exam reminder notifications compile). Not yet tested on a physical device.

Data: BUSI (Al-Dhabyani et al., 2020, *Data in Brief*); BUS-BRA (Gómez-Flores et al., 2024, *Medical Physics*); BrEaST-Lesions-USG (Pawłowska et al., 2024, The Cancer Imaging Archive, CC BY 4.0).
The two demo scans in `assets/images/breast_sample_*.png` come from BrEaST's held-out test split.

## Future work (not in the submitted scope)

- **Mammography (X-ray of the breast) as a second breast-imaging option.** Needs its own model and dataset (e.g. CBIS-DDSM, INbreast, VinDr-Mammo; check access),
  high-resolution multi-view input, and a modality router so uploads go to the right model (the current ultrasound gate would likely reject mammograms as "not an ultrasound").
  Added 2026-09-19; decided to finish the core modules first. Chest X-ray and MRI are not planned (chest X-ray is not used for breast screening; breast-MRI data is scarce).
