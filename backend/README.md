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
- `POST /chat`, `POST /voice/transcribe`, `POST /voice/speak` (AI companion; answers grounded in `knowledge.py`, medicines only from `medicines.py`)
- `POST /report/explain` (photo of a lab or ultrasound report)
- `GET|POST /whatsapp/webhook` (the companion on WhatsApp)

## Femora on WhatsApp: setup

1. At https://developers.facebook.com create an app of type **Business**, add the **WhatsApp** product.
   Meta gives a free **test number** that can message up to 5 phone numbers you register (enough for a demo).
2. In *WhatsApp > API Setup*, copy the **temporary access token** and the **Phone number ID** into `backend/.env` as
   `WHATSAPP_TOKEN` and `WHATSAPP_PHONE_NUMBER_ID`, and add your own phone under *To*.
   (The temporary token lasts 24 hours; for longer, create a System User token in Business Settings.)
3. Choose any long random `WHATSAPP_VERIFY_TOKEN`, and copy the app secret (*Settings > Basic*) into `WHATSAPP_APP_SECRET`.
4. Start the server where Meta can reach it over HTTPS (for the demo: `scripts/start_demo.ps1` prints a tunnel address).
5. In *WhatsApp > Configuration*, set the callback URL to `https://<address>/whatsapp/webhook`, paste the verify token,
   and subscribe to the **messages** field.
6. Message the test number from your phone: text, a voice note, or a photo of a lab report.

`GET /health` shows `"whatsapp": true` once the keys are set. Messages are answered in the background and kept in memory
for at most an hour (nothing is written to disk). For a public launch a dedicated number (a new SIM not already on
WhatsApp) and Meta business verification are needed, and the server must be online all the time.

Awareness only, not a medical diagnosis. Docs: `/docs`.
Breast risk model data: *Data collection and sharing was supported by the National Cancer Institute-funded Breast Cancer Surveillance Consortium (HHSN261201100031C).*
