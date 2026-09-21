# Femora: handoff notes (state on 21 September 2026)

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
| Accounts (Firebase: email, Google, phone code, guest) | Built on the other PC; 7 tests; not tried on a phone (Google and phone sign-in may need the signing fingerprint registered in Firebase) |
| Companion look and voice speed (moods, effects, short spoken answers by the phone voice) | Built on the other PC; measured through the tunnel, not heard on a phone by me |
| Word report (`scope doument/...docx`) | Updated 21 Sep for everything up to commit d354fb2 (sections 13.11 and 13.12, Q36 and Q37) |

Not built: cycle prediction (Random Forest/LSTM), trend charts, pregnancy mode, hormonal insights, most reminders. A knowledge-base (retrieval) and a question-set evaluation for the companion are planned, not built.

## Set up on a new PC
1. `git pull`. Models are in git (`backend/models/`).
2. Backend: `python -m venv backend/.venv`, install `backend/requirements.txt`, `backend/.env` (with the Gemini free-tier key) is committed on purpose at the owner's request, so a pull brings it. If Google has disabled that key, copy `backend/.env.example` to `backend/.env` and put a new key on the `GEMINI_API_KEY=` line; the key was also pasted in chat, so revoke it for anything beyond a demo. Run `backend/.venv/Scripts/uvicorn app:app --app-dir backend --host 0.0.0.0 --port 8000`. `GET /health` should show `"companion": true`.
3. App: Flutter 3.47.5 stable. `flutter pub get`, `flutter test` (69 pass), `flutter analyze` (no errors or warnings). Backend tests: `backend/.venv/Scripts/python -m pytest backend/tests` (53 pass).
4. Phone demo: `scripts\start_demo.ps1` (needs `cloudflared.exe`, path in the script or the `CLOUDFLARED` variable). Paste the printed address into the app's Server address dialog. Do not type in the script window.
5. APK: `flutter build apk --release --target-platform android-arm64` (the home PC has only 8 GB RAM and builds fail if other programs are open; paths like `D:/flutter` in the notes below are specific to the home PC).
6. **Always restart the backend after updating the code**; an old server process without the companion was once left running on port 8000.

## Latest APK
`femora-release-arm64.apk` in this folder (build 5, commit `0c4c007`, 20.9 MB, arm64). It is OLDER than the code: no APK has been built since accounts were added, and the package is now `pk.edu.au.femora` (a different app, uninstall the old one first). Older APKs in this folder (`femora-arm64-release.apk`, `femora-release.apk`) are stale and can be deleted.

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
Current as of 21 September 2026: the `.docx` in git was regenerated from `scripts/build_report.py` and now contains the
APK build 5 row and section 13.5a (voice quota). 46 pages, 18,060 words, 6 figures; the table of contents was refreshed
through Word. The script is the source of truth; the docx is generated from it. A stray lock file (`~$...docx`) had been
committed once and is now removed and ignored.

### Rebuilding the report on a fresh clone
`ml/output/` is in `.gitignore`, so the files the report reads are **not** in git and must be restored first, or the
build either crashes on a missing figure or silently prints numbers from whatever stale run is still on disk (this
happened on 21 Sep: a leftover v6 folder quietly replaced four version-7 numbers in table 28 — always diff the rebuilt
docx against the committed one and expect only the rows you meant to change).

1. Restore the Kaggle outputs (account `ammad0`, token in `~/.kaggle/access_token`, CLI at `ml/.venv/Scripts/kaggle.exe`):
   - `kernels output ammad0/femora-breast-ultrasound-resnet50 -p ml/output/breast_ultrasound` (version 7)
   - `kernels output ammad0/femora-breast-ultrasound-resnet50-busbra -p ml/output/breast_busbra` (deployed model, figures)
   - `kernels output ammad0/femora-breast-ultrasound-resnet50-uclm -p ml/output/breast_uclm` (the rejected experiment)
   - `kernels output ammad0/femora-breast-risk-xgboost -p ml/output/breast_risk` (questionnaire figures)
2. Start the backend and run `python scripts/make_report_examples.py` (writes `ml/output/report_examples.json`, the real
   API request/answer pairs printed in section 3.3).
3. Close the docx everywhere, then `python scripts/build_report.py` and `python scripts/refresh_toc.py` (Word COM fills
   the table of contents and page numbers; python-docx leaves the field empty).
Both scripts need `python-docx`, `pywin32` and Word installed; neither venv had them, so they were added to `ml/.venv`
with `VIRTUAL_ENV=ml/.venv uv pip install python-docx pywin32` (the venvs are uv-made and have no `pip`).

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
