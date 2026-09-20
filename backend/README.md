---
title: Femora API
emoji: 🌸
colorFrom: pink
colorTo: purple
sdk: docker
app_port: 7860
pinned: false
---

# Femora API

FastAPI service behind the Femora women's-health app (FYP, Air University Islamabad).
Serves the trained models: PCOS risk (XGBoost), breast ultrasound classifier (ResNet50, ONNX) and breast cancer risk questionnaire (XGBoost, BCSC).

- `GET /health`
- `POST /predict/pcos`
- `POST /predict/breast/scan` (multipart image upload)
- `POST /predict/breast/risk`

Awareness only, not a medical diagnosis. Docs: `/docs`.
Breast risk model data: *Data collection and sharing was supported by the National Cancer Institute-funded Breast Cancer Surveillance Consortium (HHSN261201100031C).*
