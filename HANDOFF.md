# Femora: handoff notes (state on 20 September 2026)

Read this first when continuing on another PC (or in a new Claude Code session: say "read HANDOFF.md and continue").
The earlier chat transcript lives only on the home PC, so this file carries the context.

## What Femora is
Flutter women's-health app (FYP, Air University Islamabad; team Arshia Naseer, Ali Haider Bilal, Ammad Sajjad; supervisor Mustabshera Fatima). Models run on a FastAPI backend (`backend/`); the phone app talks to it through an address set in the app (long-press the header → *Server address*).

## What is done
| Area | State |
|---|---|
| PCOS risk (XGBoost) | Done and connected |
| Breast ultrasound (ResNet50, gate, threshold 0.25) | Done and connected: accuracy 71.8% at the screening threshold, cancers caught 89.2%, AUC 0.87 |
| Breast risk questionnaire (BCSC XGBoost) | Done and connected |
| Self-exam guide + monthly reminder | Done |
| AI companion (Gemini chat, Urdu/English, voice in and out, safety rules) | Built; chat and speech-to-text verified live; voice on a real phone only partly tested (see below) |
| On-device health store, onboarding, Home snapshot | Done (Home reads the real store) |
| One-tap lab-style PDF health report (sample mode with watermark) | Done; rendered and checked, not yet opened on a phone |
| Word report (`scope doument/...docx`) | Updated to APK build 4 (see "Report" below) |

Not built: cycle prediction (Random Forest/LSTM), trend charts, accounts/login, pregnancy mode, hormonal insights, most reminders. A knowledge-base (retrieval) and a question-set evaluation for the companion are planned, not built.

## Set up on a new PC
1. `git pull`. Models are in git (`backend/models/`).
2. Backend: `python -m venv backend/.venv`, install `backend/requirements.txt`, `backend/.env` (with the Gemini free-tier key) is committed on purpose at the owner's request, so a pull brings it. If Google has disabled that key, copy `backend/.env.example` to `backend/.env` and put a new key on the `GEMINI_API_KEY=` line; the key was also pasted in chat, so revoke it for anything beyond a demo. Run `backend/.venv/Scripts/uvicorn app:app --app-dir backend --host 0.0.0.0 --port 8000`. `GET /health` should show `"companion": true`.
3. App: Flutter 3.47.5 stable. `flutter pub get`, `flutter test` (58 pass), `flutter analyze` (no errors or warnings). Backend tests: `backend/.venv/Scripts/python -m pytest backend/tests` (53 pass).
4. Phone demo: `scripts\start_demo.ps1` (needs `cloudflared.exe`, path in the script or the `CLOUDFLARED` variable). Paste the printed address into the app's Server address dialog. Do not type in the script window.
5. APK: `flutter build apk --release --target-platform android-arm64` (the home PC has only 8 GB RAM and builds fail if other programs are open; paths like `D:/flutter` in the notes below are specific to the home PC).
6. **Always restart the backend after updating the code**; an old server process without the companion was once left running on port 8000.

## Latest APK
`femora-release-arm64.apk` in this folder (build 5, commit `0c4c007`, 20.9 MB, arm64). Older APKs in this folder (`femora-arm64-release.apk`, `femora-release.apk`) are stale and can be deleted.

## Voice: what happened and the current design
- On the phone, speech recognition worked but the companion did not speak. Cause (verified): Gemini text-to-speech on a free key allows **10 requests a day per model**; testing used it up (HTTP 429).
- Fixes (commit `0c4c007`): server tries two voice models (`gemini-3.1-flash-tts-preview`, then `gemini-2.5-flash-preview-tts`); the app falls back to the **phone's own voice** (flutter_tts) if the AI voice fails; AI voice audio is played from a temp file. English phone voice works on any phone; Urdu needs an Urdu voice installed on the phone.
- **Still to verify on a real phone (task #7):** spoken English answer, spoken Urdu answer, speaker button, report preview/share, Home tab with real data. Only tested with a fake speaker and desk checks so far.
- Chat model: `gemini-3.1-flash-lite` (backup `gemini-3.6-flash`). A paid key removes the daily voice limit and the free-tier data-use caveat.

## Bugs found and fixed in the last session (all committed)
Home tab showed a fake "Ayesha" and fake cycle data; emergency detector missed Roman Urdu "bohat zyada bleeding"; stale backend on port 8000; report watermark drawn solid black; Urdu speech transcribed in Devanagari (retry added); voice quota (above).

## Standing instructions from the user
- Keep the Word report up to date with every change (edit `scripts/build_report.py`, rebuild with python-docx, refresh the table of contents through Word COM, check the pages visually, commit script and .docx together).
- Build the release APK after changes and put a copy where the user can reach it (Desktop on the home PC, and the repo root).
- Work autonomously; ask before pushing unless told to push.
- Never repeat keys in output. `backend/.env` is committed by the owner's explicit choice (free key); do not add other secrets to the repo.

## Report (Word) status
`scripts/build_report.py` is current, including APK build 5 and section 13.5a (voice quota). The `.docx` in git was last regenerated before the build 5 row was added: Word held a lock on the file at the end of the session. On the home PC close the docx everywhere, run the build script, then refresh via Word COM. The script is the source of truth; the docx is generated from it. A stray lock file (`~$...docx`) had been committed once and is now removed and ignored.

## Open items and ideas
1. Real-phone check (task #7).
2. Push status: see `git status` / `git log origin/main..`.
3. Companion improvements: grounded knowledge base (NIH/CDC/MedlinePlus passages) and a several-hundred-question evaluation set; clinician review of wording.
4. Cycle tracking/prediction, trend charts, accounts, pregnancy mode, hormonal insights.
5. Revoke the exposed Gemini key and the Hugging Face token; use a paid Gemini key for real users.
6. Mammography is recorded as future work in the README.

## Where things are
- `backend/companion.py`: Gemini chat, voice, safety rules, fallback. `backend/app.py`: API. `backend/models/`: trained models.
- `lib/models/health_store.dart`, `chat_state.dart`; `lib/services/voice_service.dart`, `report_service.dart`, `api_service.dart`; `lib/screens/` (home, companion, onboarding, report, breast, PCOS, cycle).
- `test/`: Flutter tests; `backend/tests/`: backend tests.
- `ml/`: training notebooks and pinned splits; `scripts/`: demo script and report generator.
