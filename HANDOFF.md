# Femora: handoff notes (state on 23 September 2026)

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
| Cycle tracking and prediction (scope 6.2) | Built 21 Sep (commit 388032f): logging, calendar with phases, predictions, late/irregular notes, Home card, report Panel 4, companion context. 44 tests; not tried on a phone. Prediction = her own average blended with the study average (`lib/models/cycle_engine.dart`; study in `ml/cycle_eval.py`, results `ml/cycle_results.json`) |
| Symptom and mood tracker (6.10), hormonal insights (6.6), reminders (6.8), dashboard (6.9) | Built 21 Sep in that order, each tested and committed (report chapter 15). Nothing about them has been tried on a phone; in particular no notification has been delivered on a real device yet |
| PCOS what-if simulator | Built 22 Sep (commit 8bc67ca): server endpoint, live sliders, quick wins, safety limits |
| Medical report reader (photo of a lab or ultrasound report, explained in Urdu or English) | Built 22 Sep (commit 7d25fc2); tested with a fake Gemini only, not yet with the real service or a phone camera. The old key's 401 is fixed: `backend/.env` got a new key on 23 Sep and a live /chat call returned a Gemini answer |
| Urdu/English switch | Whole-app mechanism and every screen's layout done (commits f40568f, 28c4e68, 0acc7b7). Still English only: generated clinical text, the Self-Exam steps, reminder notification text, the PDF report and the sign-in screen. Urdu not yet reviewed by a native speaker |
| Marketing showcase and supervisor progress report | PDFs in `scope doument/` (commit f2a454a); screenshots come from `lib/dev/screenshot_harness.dart` (dev only, not in the shipped app) |
| Word report (`scope doument/...docx`) | Updated 21 Sep for everything up to commit d354fb2 (sections 13.11 and 13.12, Q36 and Q37) |

Not built: pregnancy care (6.5) and its reminders. A knowledge-base (retrieval) and a question-set evaluation for the companion are planned, not built.

## Set up on a new PC
1. `git pull`. Models are in git (`backend/models/`).
2. Backend: `python -m venv backend/.venv`, install `backend/requirements.txt`, `backend/.env` (with the Gemini free-tier key) is committed on purpose at the owner's request, so a pull brings it. If Google has disabled that key, copy `backend/.env.example` to `backend/.env` and put a new key on the `GEMINI_API_KEY=` line; the key was also pasted in chat, so revoke it for anything beyond a demo. Run `backend/.venv/Scripts/uvicorn app:app --app-dir backend --host 0.0.0.0 --port 8000`. `GET /health` should show `"companion": true`.
3. App: Flutter 3.47.5 stable. `flutter pub get`, `flutter test` (350 pass as of commit 0acc7b7), `flutter analyze` (no errors or warnings). Backend tests: `backend/.venv/Scripts/python -m pytest backend/tests` (97 pass).
4. Phone demo: `scripts\start_demo.ps1` (needs `cloudflared.exe`, path in the script or the `CLOUDFLARED` variable). Paste the printed address into the app's Server address dialog. Do not type in the script window.
5. APK: `flutter build apk --release --target-platform android-arm64` (the home PC has only 8 GB RAM and builds fail if other programs are open; paths like `D:/flutter` in the notes below are specific to the home PC).
6. **Always restart the backend after updating the code**; an old server process without the companion was once left running on port 8000.

## Latest APK
`femora-release-arm64.apk` in this folder (build 6, 23 Sep 2026, built from commit `f2a454a`, 24.4 MB, arm64; a copy is also on the Desktop). It includes everything listed above: accounts, cycle tracking, the trackers, reminders, PCOS what-if, report reader and the Urdu switch. Package is `pk.edu.au.femora`; if build 5 or older is on the phone, uninstall it first (it is a different app). Build 6 has not been installed on a phone yet. Older APKs in this folder (`femora-arm64-release.apk`, `femora-release.apk`) are stale and can be deleted.

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

## Decision (21 September 2026): breast module improvement is closed
The owner decided to stop improving the breast ultrasound module. It stays as deployed (screening threshold 0.25, accuracy 71.8%, AUC 0.87).
Known limitation left as is: the ultrasound gate wrongly refuses about 4% of genuine breast scans from other hospitals (measured on BUSI-WHU, report section 6.14). The fix, if ever wanted, is to retrain the gate with BUSI-WHU scans as extra positives (`ml/train_gate_v2.py`; the scans are on the home PC in `D:\dl\busi_whu`, not in git). No labelled outside test set exists yet.

## Cycle tracking notes (21 September 2026)
- Measured on the Fehring data: next period within 3 days 67% (95% interval 60-75%) on day one, 82% (78-86%) with 3+ cycles; the scope's 85-90% personalised target was not reached, and a Random Forest gave no gain, so no RF or LSTM is shipped (report chapter 14).
- **Word report locking:** the Word that automation opens is actually WPS Office; after a table-of-contents refresh it can stay alive and lock the .docx. Find the holder (Restart Manager) and stop that one process, then rebuild. `scripts/build_report.py` accepts `REPORT_OUT=<path>` to build elsewhere.

## Modules 6.10, 6.6, 6.8, 6.9 (21 September 2026)
- The only scope module still unbuilt is **6.5 Pregnancy care**. Smaller gaps: hydration reminders and a grounded knowledge base for the companion (6.7).
- Test totals: Flutter 237, backend 53; `flutter analyze` has no errors or warnings.
- A fresh APK has not been built since accounts and all of this were added (the machine ran out of memory twice); the APK in the repo root is old and installs as a different app.

## Plan after the scope (agreed 22 September 2026)
Supervisor: pregnancy care (6.5) moves to FYP III. Order agreed with the owner: (B) PCOS what-if simulator [done], (A) photograph a lab or ultrasound report and have the companion explain it in Urdu or English [built and tested with a fake Gemini; NOT yet run against the real service because the committed Gemini key returns HTTP 401 and probably was disabled after it was published; put a new key in backend/.env and run a real photo in English and Urdu], (D) Urdu and English language switch for the whole app [STARTED: the app-wide mechanism (locale, automatic right-to-left, bundled Urdu font) is built and tested, and every screen's own layout (navigation, forms, dialogs, buttons, empty states) is now bilingual, including a live language preview in onboarding before saving; deliberately left for later: the generated clinical text (hormonal-insight flags/patterns, PCOS/breast guidance, reminder notification text, the Self-Exam Guide's step instructions) and the PDF report, plus a native speaker's review of all the Urdu written so far], then better companion answers and a more human voice, then two-way live conversation (E), then AI outlining the lesion on the ultrasound (C, kept separate). A human-sounding voice needs a paid text-to-speech service or a paid Gemini key (the free voice allows about 10 replies a day); Urdu wording should be reviewed by a native speaker.
