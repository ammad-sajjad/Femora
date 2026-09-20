"""Builds the Femora progress report (Word) into the "scope doument" folder.

Run:  <python with python-docx> scripts/build_report.py
Numbers are read from the project's metadata files wherever possible, so the report matches what was measured.
"""
import json
from pathlib import Path

from docx import Document
from docx.enum.section import WD_ORIENT
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "scope doument" / "Femora - Project Progress and Technical Report.docx"
BERRY, DEEP, PINK, GREY = RGBColor(0x9E, 0x1B, 0x46), RGBColor(0x5A, 0x0F, 0x2A), "FBE9EF", RGBColor(0x55, 0x55, 0x55)

load = lambda p: json.loads((ROOT / p).read_text(encoding="utf-8"))
UB = load("backend/models/breast_meta.json")                       # deployed ultrasound model (BUS-BRA)
V7 = load("ml/output/breast_ultrasound/model/breast_meta.json")     # v7
UC = load("ml/output/breast_uclm/model/breast_meta.json")           # BUS-UCLM experiment
RK = load("backend/models/breast_risk_meta.json")                   # risk questionnaire
pct = lambda x, d=1: f"{x * 100:.{d}f}%"

doc = Document()

# ------------------------------------------------------------------ page + styles
sec = doc.sections[0]
sec.page_width, sec.page_height = Cm(21.0), Cm(29.7)
sec.left_margin = sec.right_margin = Cm(2.2)
sec.top_margin, sec.bottom_margin = Cm(2.3), Cm(2.0)
TEXT_W = 16.6

def set_font(style, name="Calibri", size=None, bold=None, color=None):
    style.font.name = name
    rpr = style.element.get_or_add_rPr()
    rf = rpr.find(qn("w:rFonts"))
    if rf is None:
        rf = OxmlElement("w:rFonts"); rpr.append(rf)
    for a in ("w:ascii", "w:hAnsi", "w:eastAsia", "w:cs"):
        rf.set(qn(a), name)
    if size: style.font.size = Pt(size)
    if bold is not None: style.font.bold = bold
    if color is not None: style.font.color.rgb = color

st = doc.styles
set_font(st["Normal"], size=10.5)
st["Normal"].paragraph_format.space_after = Pt(6)
st["Normal"].paragraph_format.line_spacing = 1.12
for name, size, before, after, color in (("Heading 1", 17, 20, 8, BERRY), ("Heading 2", 13, 14, 5, DEEP), ("Heading 3", 11, 10, 3, DEEP)):
    set_font(st[name], size=size, bold=True, color=color)
    st[name].paragraph_format.space_before, st[name].paragraph_format.space_after = Pt(before), Pt(after)
    st[name].paragraph_format.keep_with_next = True
set_font(st["List Bullet"], size=10.5)
st["List Bullet"].paragraph_format.space_after = Pt(3)
set_font(st["Caption"], size=9, bold=False, color=GREY)

# ------------------------------------------------------------------ helpers
def shade(cell, hex_fill):
    tcpr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear"); shd.set(qn("w:color"), "auto"); shd.set(qn("w:fill"), hex_fill)
    tcpr.append(shd)

def cell_margins(table, top=50, bottom=50, left=90, right=90):
    tblpr = table._tbl.tblPr
    m = OxmlElement("w:tblCellMar")
    for side, v in (("top", top), ("left", left), ("bottom", bottom), ("right", right)):
        e = OxmlElement(f"w:{side}"); e.set(qn("w:w"), str(v)); e.set(qn("w:type"), "dxa"); m.append(e)
    tblpr.append(m)

def borders(table, color="D9C3CC"):
    tblpr = table._tbl.tblPr
    b = OxmlElement("w:tblBorders")
    for side in ("top", "left", "bottom", "right", "insideH", "insideV"):
        e = OxmlElement(f"w:{side}")
        e.set(qn("w:val"), "single"); e.set(qn("w:sz"), "4"); e.set(qn("w:space"), "0"); e.set(qn("w:color"), color)
        b.append(e)
    tblpr.append(b)

def set_widths(t, widths):
    """Word lays tables out from the grid, so set the grid columns and every cell."""
    for i, w in enumerate(widths):
        t.columns[i].width = Cm(w)
        for c in t.columns[i].cells:
            c.width = Cm(w)

def para(text="", bold=False, italic=False, size=None, color=None, align=None, after=None, style=None, keep=False):
    p = doc.add_paragraph(style=style)
    if text:
        add_runs(p, text, bold=bold, italic=italic, size=size, color=color)
    if align is not None: p.alignment = align
    if after is not None: p.paragraph_format.space_after = Pt(after)
    if keep: p.paragraph_format.keep_with_next = True
    return p

def add_runs(p, text, bold=False, italic=False, size=None, color=None):
    """Supports **bold** segments inside text."""
    parts = text.split("**")
    for i, part in enumerate(parts):
        if not part: continue
        r = p.add_run(part)
        r.bold = bold or (i % 2 == 1)
        r.italic = italic
        if size: r.font.size = Pt(size)
        if color is not None: r.font.color.rgb = color

def bullets(items):
    for t in items:
        add_runs(doc.add_paragraph(style="List Bullet"), t)

H1 = lambda t: doc.add_heading(t, 1)
H2 = lambda t: doc.add_heading(t, 2)
H3 = lambda t: doc.add_heading(t, 3)

_tn, _fn = [0], [0]

def table(headers, rows, widths, caption=None, size=9, first_bold=False, align_right_from=None, note=None):
    if caption:
        _tn[0] += 1
        p = para(f"Table {_tn[0]}. {caption}", style="Caption", keep=True)
        p.paragraph_format.space_before, p.paragraph_format.space_after = Pt(8), Pt(3)
    t = doc.add_table(rows=1, cols=len(headers))
    t.alignment = WD_TABLE_ALIGNMENT.CENTER
    t.autofit = False
    borders(t); cell_margins(t)
    def fill(cell, text, bold=False, color=None, right=False):
        cell.text = ""
        p = cell.paragraphs[0]
        p.paragraph_format.space_after = Pt(0); p.paragraph_format.line_spacing = 1.0
        add_runs(p, str(text), bold=bold, size=size, color=color)
        if right: p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    for i, h in enumerate(headers):
        c = t.rows[0].cells[i]; fill(c, h, bold=True, color=RGBColor(255, 255, 255)); shade(c, "9E1B46")
    trpr = t.rows[0]._tr.get_or_add_trPr()
    th = OxmlElement("w:tblHeader"); th.set(qn("w:val"), "true"); trpr.append(th)
    for ri, row in enumerate(rows):
        cells = t.add_row().cells
        cs = OxmlElement("w:cantSplit"); cs.set(qn("w:val"), "true"); t.rows[-1]._tr.get_or_add_trPr().append(cs)
        for i, v in enumerate(row):
            fill(cells[i], v, bold=(first_bold and i == 0), right=(align_right_from is not None and i >= align_right_from))
            if ri % 2 == 1: shade(cells[i], PINK)
    set_widths(t, widths)
    if len(rows) <= 7:   # keep short tables on one page; longer ones flow with a repeating header
        for row in t.rows[:-1]:
            for c in row.cells:
                for pp in c.paragraphs: pp.paragraph_format.keep_with_next = True
    if align_right_from is not None:
        for c in t.rows[0].cells[align_right_from:]:
            c.paragraphs[0].alignment = WD_ALIGN_PARAGRAPH.RIGHT
    if note:
        p = para(note, italic=True, size=8.5, color=GREY, after=8); p.paragraph_format.space_before = Pt(3)
    else:
        para("", after=4)
    return t

def figure(path, caption, width=15.5):
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.keep_with_next = True; p.paragraph_format.space_after = Pt(2)
    p.add_run().add_picture(str(ROOT / path), width=Cm(width))
    _fn[0] += 1
    c = para(f"Figure {_fn[0]}. {caption}", style="Caption", align=WD_ALIGN_PARAGRAPH.CENTER, after=10)

def callout(title, text):
    t = doc.add_table(rows=1, cols=1); t.alignment = WD_TABLE_ALIGNMENT.CENTER; t.autofit = False
    c = t.rows[0].cells[0]; set_widths(t, [TEXT_W]); shade(c, PINK); cell_margins(t, 90, 90, 160, 160)
    tcpr = c._tc.get_or_add_tcPr(); b = OxmlElement("w:tcBorders")
    left = OxmlElement("w:left"); left.set(qn("w:val"), "single"); left.set(qn("w:sz"), "24"); left.set(qn("w:color"), "9E1B46"); b.append(left)
    tcpr.append(b)
    c.text = ""
    p = c.paragraphs[0]; p.paragraph_format.space_after = Pt(2)
    add_runs(p, title, bold=True, color=BERRY, size=10.5)
    p2 = c.add_paragraph(); p2.paragraph_format.space_after = Pt(0)
    add_runs(p2, text, size=10)
    para("", after=4)

def field(paragraph, instr):
    """Inserts a Word field (PAGE, TOC ...) as separate runs, the form Word expects."""
    def run_with(child):
        r = paragraph.add_run(); r._r.append(child); return r
    for kind in ("begin", "separate", "end"):
        pass
    f = OxmlElement("w:fldChar"); f.set(qn("w:fldCharType"), "begin"); run_with(f)
    it = OxmlElement("w:instrText"); it.set(qn("xml:space"), "preserve"); it.text = f" {instr} "; run_with(it)
    f = OxmlElement("w:fldChar"); f.set(qn("w:fldCharType"), "separate"); run_with(f)
    t = OxmlElement("w:t"); t.text = "1"; run_with(t)
    f = OxmlElement("w:fldChar"); f.set(qn("w:fldCharType"), "end"); run_with(f)

def page_break():
    doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)

# ------------------------------------------------------------------ header / footer
hp = sec.header.paragraphs[0]
add_runs(hp, "femora  |  Project Progress and Technical Report", size=8.5, color=GREY)
fp = sec.footer.paragraphs[0]; fp.alignment = WD_ALIGN_PARAGRAPH.CENTER
add_runs(fp, "Awareness only, not a medical diagnosis   ·   Page ", size=8.5, color=GREY)
field(fp, "PAGE")
for r in fp.runs: r.font.size = Pt(8.5)

# ------------------------------------------------------------------ extra helpers (new)
def H1(t, new_page=False):
    h = doc.add_heading(t, 1)
    h.paragraph_format.page_break_before = new_page
    return h

def code_block(text):
    t = doc.add_table(rows=1, cols=1); t.alignment = WD_TABLE_ALIGNMENT.CENTER; t.autofit = False
    c = t.rows[0].cells[0]; set_widths(t, [TEXT_W]); shade(c, "F4F4F8"); cell_margins(t, 60, 60, 120, 120)
    c.text = ""
    lines = text.strip("\n").split("\n")
    for i, ln in enumerate(lines):
        p = c.paragraphs[0] if i == 0 else c.add_paragraph()
        p.paragraph_format.space_after = Pt(0); p.paragraph_format.line_spacing = 1.0
        r = p.add_run(ln if ln else " "); r.font.name = "Consolas"; r.font.size = Pt(8)
        r._element.rPr.rFonts.set(qn("w:eastAsia"), "Consolas")
    para("", after=4)

EX = json.loads((ROOT / "ml/output/report_examples.json").read_text(encoding="utf-8"))
PC = load("backend/models/pcos_meta.json")
def js(o, n=None):
    s = json.dumps(o, indent=2, ensure_ascii=False)
    return s

# ------------------------------------------------------------------ title page
for _ in range(4): para("", after=10)
para("femora", bold=True, size=54, color=BERRY, align=WD_ALIGN_PARAGRAPH.LEFT, after=2)
para("AI-Powered Women's Health & Wellness Application", size=17, color=DEEP, after=26)
para("Project Progress and Technical Report", bold=True, size=24, after=4)
para("Models, App, Backend and Demo Build: full technical detail", size=14, color=GREY, after=40)
tt = doc.add_table(rows=0, cols=2); tt.autofit = False
for a, b in (("Team", "Arshia Naseer (232428)\nAli Haider Bilal (232398)\nAmmad Sajjad (232497)"),
             ("Supervisor", "Mustabshera Fatima"),
             ("Department", "Computer Science, Air University Islamabad"),
             ("Report date", "20 September 2026"),
             ("Source code", "github.com/ammad-sajjad/Femora (branch main, state as of the AI companion commit 8c5eb71)")):
    cells = tt.add_row().cells
    cells[0].text = ""; cells[1].text = ""
    add_runs(cells[0].paragraphs[0], a, bold=True, color=BERRY)
    lines = b.split("\n"); add_runs(cells[1].paragraphs[0], lines[0])
    for ln in lines[1:]: add_runs(cells[1].add_paragraph(), ln)
    for c in cells:
        for p in c.paragraphs: p.paragraph_format.space_after = Pt(2)
set_widths(tt, [3.6, 12.6])
para("", after=30)
para("Femora provides health awareness and risk information only. It is not a medical diagnosis and does not replace a doctor.",
     italic=True, size=9.5, color=GREY)
page_break()

# ------------------------------------------------------------------ contents
para("Contents", bold=True, size=17, color=BERRY, after=8)
p = doc.add_paragraph(); field(p, 'TOC \\o "1-2" \\h \\z \\u')

# ================================================================== 1 SUMMARY
H1("1. Executive summary", new_page=True)
para("This report records the state of the Femora project as of 20 September 2026: what was built, how each part works, which settings and data were used, "
     "how well the models perform on data they never saw, what was tried and rejected, and what remains. It is written so that each number and each design "
     "choice can be traced to a file in the repository. The main work of this period was the Breast Cancer module (scope 6.3) and the app and server changes "
     "needed to run the models on a phone.")
table(["Module (scope ref.)", "Status", "Evidence"], [
    ["PCOS risk (6.4)", "Done", "XGBoost on 541 women; 84.4% accuracy, AUC 0.88 on a 109-woman test split (from the earlier training run)"],
    ["Breast ultrasound classifier (6.3A)", "Done", "ResNet50 with an ultrasound gate. On 710 held-out scans: accuracy 71.8% at the screening threshold (80.4% at a neutral threshold), cancers caught 89.2%, AUC 0.87"],
    ["Breast risk questionnaire (6.3B)", "Done", "XGBoost trained on 2.39 million real mammograms (BCSC): AUC 0.64, calibration 1.01"],
    ["Breast self-exam guide and reminder (6.3)", "Done", "Guide, logging and a monthly notification"],
    ["Breast AI chatbot (6.3C)", "Done (prototype)", "The AI companion answers about the user's own ultrasound and questionnaire results; the Breast tab has \"Discuss with AI\" buttons"],
    ["Cycle tracking and prediction (6.2)", "Prototype UI", "Static screens, hard-coded cycle day. No Random Forest or LSTM yet"],
    ["Symptom and mood tracker (6.10)", "Basic version", "Symptoms, mood and notes are saved on the phone (one entry a day) and reach the report and the AI companion; no trend charts yet"],
    ["AI healthcare companion (6.7)", "Done (prototype)", "Gemini chat with Urdu and English voice in and out, safety rules, personal context from the on-device health store (section 13)"],
    ["Health report (6.9)", "Done (first version)", "One tap makes a lab-style PDF with one panel per test (section 13.6)"],
    ["Onboarding (6.1)", "Basic version", "First-launch profile (no accounts or login)"],
    ["Accounts and login (6.1), pregnancy care (6.5), hormonal insights (6.6), reminders (6.8, only self-exam exists)", "Not started", "See section 12"],
], [5.6, 2.4, 8.6], caption="Status of the scope modules")
H3("Key findings")
bullets([
    "**The first ultrasound model did not generalise.** Version 7 scored 79.7% accuracy on its own test set, but on scans from a hospital it had never seen it caught only 72% of cancers (AUC 0.69).",
    "**Adding a third hospital dataset fixed most of that.** Training also on BUS-BRA (1,875 scans, four scanners) with a patient-level split raised the AUC on unseen patients from 0.69 to 0.87, and cancers caught from 72% to 91% (at the notebook threshold).",
    "**One model, two operating points.** On the 710 held-out scans the deployed ultrasound model scores accuracy 71.8%, sensitivity 89.2%, specificity 63.6% at the screening threshold (0.25). With a neutral decision rule (most likely class wins) the same model scores accuracy 80.4%, sensitivity 77.5%, specificity 82.6%. The AUC, 0.87, is the same in both.",
    "**The risk questionnaire is now trained on real data.** AUC 0.64 is normal for risk-factor models; its strength is calibration (expected/observed cancers = 1.01).",
    "**One planned improvement was tested and rejected.** Adding the BUS-UCLM dataset gave no measurable gain, so it is documented but not deployed.",
    "**The app now runs on a phone.** A release APK (19 MB) was built. Hugging Face Docker hosting turned out to need a paid plan, so the demo uses a free tunnel to the backend on the developer PC.",
    "**The ultrasound gate was strengthened.** A real non-breast ultrasound had slipped through, so the gate was retrained with other-organ ultrasounds. It now refuses the organs it saw and about 43% to 60% of unseen ones, and wrongly refuses 0.3% of real breast scans; classifications did not change.",
    "**The app now has a personal AI companion.** It uses Google Gemini through the backend, understands and speaks Urdu and English, and knows the user's own results (without their name) because the whole app now saves to one on-device health store. Safety rules run on the server, not in the model (section 13).",
    "**A one-tap report.** The health report is a lab-style PDF (one panel per test, reference ranges, flags, QR code, report number) that can be shared or printed, with a sample-data mode for demonstrations.",
    "**About half of the scope is working.** The largest gaps are cycle prediction, trend charts, accounts, pregnancy mode and hormonal insights.",
])

# ================================================================== 2 BACKGROUND
H1("2. Project background and scope")
para("Femora is a final-year project at Air University Islamabad: a mobile application that combines menstrual-cycle tracking, PCOS risk "
     "screening, breast-health awareness and an AI companion in one app. The streamlined scope agreed on 29 June 2026 is:")
bullets([
    "**Domain 1, menstrual cycle:** log cycle dates and symptoms; a Random Forest (about 70% accuracy on day one) and a personalised LSTM after three or more cycles (85 to 90%).",
    "**Domain 2, PCOS:** a risk questionnaire and an XGBoost classifier giving a Low, Medium or High risk score.",
    "**Domain 3, breast cancer:** (A) ultrasound upload classified by a ResNet50 CNN; (B) a symptom and risk questionnaire scored by XGBoost; (C) a chatbot that explains the results.",
])
para("Every output is for awareness only and must be followed up with a qualified doctor. All figures in this report were measured on "
     "held-out data and come from files in the project repository (model metadata, Kaggle notebook outputs and test logs). Where a number was chosen "
     "after seeing test results, or rests on very few samples, the text says so.")

# ================================================================== 3 ARCHITECTURE
H1("3. System architecture")
H2("3.1 Overview")
para("The machine-learning models run on a server, not inside the app. The phone sends the questionnaire answers or the scan image "
     "to a small web service and receives the result. Models are trained offline in Kaggle notebooks and exported to files the server loads. "
     "The reasons for this split are in Appendix F (Q1).")
table(["Layer", "Technology", "Where"], [
    ["Mobile app", "Flutter / Dart (Android). provider, http, image_picker, shared_preferences, flutter_local_notifications", "lib/"],
    ["Backend API", "FastAPI + uvicorn; ONNX Runtime (ultrasound), XGBoost (PCOS and risk), Pillow, pydantic validation", "backend/app.py"],
    ["Models", "ONNX ResNet50 (47 MB, three outputs), two XGBoost boosters (335 KB and 248 KB), metadata JSON files", "backend/models/"],
    ["Training", "Kaggle notebooks (GPU T4 for ultrasound, CPU for XGBoost); PyTorch, scikit-learn, imbalanced-learn, ONNX", "ml/build_notebooks.py"],
    ["Demo hosting", "Cloudflare quick tunnel from the developer PC, started by one script", "scripts/start_demo.ps1"],
], [3.0, 9.6, 4.0], caption="Architecture layers")
H2("3.2 What happens when a user taps a button")
bullets([
    "**1. The app checks the input** against the same ranges the server uses (for example age 12 to 60 for PCOS) and blocks submission with a message if required choices are missing.",
    "**2. The app sends an HTTP request** to the server address: JSON for the questionnaires, a multipart form with the image for scans. Timeouts: 15 seconds for JSON, 45 seconds for a scan upload.",
    "**3. The tunnel forwards the request** over HTTPS to the backend on the PC (port 8000).",
    "**4. FastAPI validates the request** with pydantic. Out-of-range or missing fields return HTTP 422 with an explanation; images over 10 MB return 413.",
    "**5. The server prepares the input:** for a scan, EXIF rotation, grayscale, pad to square, resize to 224 × 224, normalise; for the questionnaires, convert answers to the model's feature coding.",
    "**6. The model runs:** ONNX Runtime for the ResNet50 (about 95 ms on this PC's CPU); XGBoost for the two questionnaire models (a few milliseconds).",
    "**7. The server post-processes:** temperature scaling and the screening threshold (scan); per-answer SHAP contributions to name the top risk factors (PCOS and risk); a heatmap from class activation maps (scan); guidance text chosen by rules.",
    "**8. The server returns JSON** and the app renders it (result card, probability bars, heatmap toggle, guidance cards, disclaimer).",
])
H2("3.3 API reference")
para("Interactive documentation is generated automatically at /docs on the running server. The tables below list every field.")
table(["Field (POST /predict/pcos)", "Type and allowed range", "Meaning"], [
    ["age", "integer 12 to 60", "Years. Collected, but not used by the model (section 5.2)"],
    ["height_cm, weight_kg", "number 120 to 210, 25 to 200", "Used to compute BMI = kg / (m squared)"],
    ["waist_in, hip_in", "optional, 15 to 70 and 15 to 80", "Waist-to-hip ratio; if skipped, the median 0.89 is used"],
    ["irregular_cycle", "boolean", "Periods are irregular"],
    ["period_days", "integer 0 to 15", "Days a period usually lasts"],
    ["weight_gain, hair_growth, skin_darkening, hair_loss, pimples", "boolean", "Symptoms noticed in the past six months"],
    ["fast_food, regular_exercise", "boolean", "Lifestyle answers"],
], [5.6, 4.4, 6.6], caption="PCOS request")
table(["Field (PCOS response)", "Meaning"], [
    ["probability, risk_level", "Model probability (0 to 1) and the band: low below 0.30, medium 0.30 to 0.60, high 0.60 and above"],
    ["bmi", "Computed BMI, rounded to one decimal"],
    ["factors", "Up to three answers that raised the risk most (SHAP contribution above 0.05), for example \"Excess Hair Growth\"; BMI is added if 25 or more"],
    ["guidance, disclaimer", "Rule-based advice cards and the awareness-only disclaimer"],
], [5.0, 11.6], caption="PCOS response")
table(["Field (POST /predict/breast/risk)", "Type and allowed range", "Meaning"], [
    ["age", "integer 18 to 100", "Mapped to a 5-year group from 35-39 to 80-84; outside that range the nearest group is used and a note is added"],
    ["height_cm, weight_kg", "as above", "BMI group 1 to 4"],
    ["menopause", "pre | post | unknown", "Post-menopausal or age 55 and over is coded together, as BCSC does"],
    ["hormone_therapy, surgical_menopause", "optional boolean", "Only used when post-menopausal"],
    ["first_birth", "under_30 | 30_or_older | never | unknown", "Age at first birth"],
    ["relatives_with_breast_cancer", "optional 0, 1 or 2", "Mother, sister or daughter; 2 means two or more"],
    ["breast_biopsy", "optional boolean", "Previous breast biopsy"],
    ["breast_density", "optional a | b | c | d", "BI-RADS density from a mammogram report"],
    ["last_mammogram", "optional normal | false_positive", "Result of the last mammogram, if any"],
    ["symptoms", "list of breast_lump, armpit_lump, nipple_discharge, nipple_change, skin_change, shape_change, breast_pain", "Handled by referral rules, not by the model"],
], [5.0, 5.0, 6.6], caption="Breast risk request")
table(["Field (risk response)", "Meaning"], [
    ["probability, average_probability, relative_risk", "Estimated one-year risk, the average for the same age group, and their ratio"],
    ["risk_level, age_group", "low (ratio below 1.35), medium (1.35 to 2.4) or high (2.4 and above); the age group used"],
    ["factors", "Up to three answers that raised the estimate most (age is excluded)"],
    ["red_flags, urgency", "Symptoms needing a doctor, each marked urgent or soon; urgency is the most severe (none, soon, urgent)"],
    ["guidance, notes, summary, disclaimer", "Advice cards, model-scope notes, a plain-language summary, the disclaimer"],
], [5.6, 11.0], caption="Breast risk response")
table(["Field (POST /predict/breast/scan)", "Meaning"], [
    ["image (multipart file)", "PNG or JPG ultrasound, up to 10 MB. Anything the server cannot read as an image returns 422"],
    ["prediction, title, confidence", "normal, benign or malignant; a display title (Likely Normal, Likely Benign, Suspicious Finding); the calibrated probability of the predicted class"],
    ["probabilities", "Calibrated probability of each class"],
    ["heatmap_jpeg", "Base64 JPEG of the scan with the class activation map overlaid (only for benign and malignant)"],
    ["summary, guidance, disclaimer", "Plain-language explanation (also passed to the AI companion), advice cards, disclaimer"],
    ["model_accuracy", "Accuracy shown to the user, read from the model's metadata (0.7183)"],
], [5.6, 11.0], caption="Scan request and response")
para("A real PCOS request and the server's real answer (produced by the running backend):", keep=True)
NL = chr(10)
fmt = lambda d: "{" + NL + ("," + NL).join(f'  "{k}": {json.dumps(v)}' for k, v in d.items()) + NL + "}"
code_block("REQUEST  POST /predict/pcos" + NL + json.dumps(EX["pcos_req"]) + NL + NL + "RESPONSE (guidance shortened)" + NL
           + fmt({k: EX["pcos"][k] for k in ("probability", "risk_level", "bmi", "factors")}))
para("A real breast risk request and answer (a 52-year-old with a reported lump; guidance text shortened):", keep=True)
rk_short = {k: EX["risk"][k] for k in ("probability", "average_probability", "relative_risk", "risk_level", "age_group", "factors", "red_flags", "urgency")}
code_block("REQUEST  POST /predict/breast/risk" + NL + json.dumps(EX["risk_req"]) + NL + NL + "RESPONSE (guidance, notes and summary omitted)" + NL + fmt(rk_short))
table(["HTTP status", "When", "What the app tells the user"], [
    ["200", "Success", "The result screen"],
    ["413", "Image larger than 10 MB", "The server's explanation (please upload a smaller file)"],
    ["422", "Invalid answers, unreadable file, colour photo or Doppler scan, not an ultrasound", "The server's explanation of what to change"],
    ["other / no answer", "Server error, timeout, no connection", "\"Server error\", \"The server took too long\" or \"Could not reach the Femora server\""],
], [2.6, 7.2, 6.8], caption="Errors and how the app reports them")
H2("3.4 Privacy, safety and security design")
bullets([
    "Uploaded scans are read into memory, classified and discarded; the server code never writes them to disk. The server stores no personal data and there are no accounts yet.",
    "Uploads are limited to 10 MB, and images that are not grayscale ultrasounds are refused before any prediction is made (section 6.9).",
    "Every result carries a disclaimer and advises seeing a doctor. Result wording says \"suspicious\" or \"likely\", never \"you have\".",
    "**Known gaps for a real launch:** the server allows requests from any origin (CORS set to *), has no authentication or rate limiting, and the Android app allows plain-http traffic (a development convenience). The demo tunnel terminates TLS at Cloudflare, so Cloudflare can technically see traffic. These are acceptable for a demonstration and must be fixed before real users.",
])
H2("3.5 Repository layout")
table(["Path", "Contents"], [
    ["lib/", "Flutter app: main.dart, screens/ (12, incl. onboarding and report), models/ (state, health store, chat), services/ (API, reminders, voice, report), widgets/ (12), theme/"],
    ["backend/", "app.py (API), companion.py (Gemini chat, voice, safety), .env (API key, not committed), models/ (ONNX, XGBoost, metadata, gate), Dockerfile, requirements files"],
    ["ml/", "build_notebooks.py (writes the Kaggle notebooks), notebooks/, v7_split.csv and busbra_split.csv (pinned splits)"],
    ["test/", "Flutter tests (breast flow, PCOS flow, server address, health store, chat, companion, onboarding, report)"],
    ["scripts/", "start_demo.ps1 (server and tunnel), build_report.py (this report)"],
    ["assets/images/", "The two demo scans used inside the app"],
    ["scope doument/", "The scope document (PDF) and this report"],
], [3.6, 13.0], caption="Where things are")

# ================================================================== 4 APP
H1("4. Mobile application in detail")
H2("4.1 Technology")
table(["Item", "Detail"], [
    ["Framework", "Flutter 3.47.5 (stable), Dart; Material design; single codebase (built for Android)"],
    ["State management", "provider (ChangeNotifier classes)"],
    ["Networking", "http package; JSON and multipart requests; static server address with an in-app override"],
    ["Local storage", "shared_preferences (keys: health_store_v1, health_scan_heatmap_v1, companion_chat_v1, self_exam_last, self_exam_reminder, api_base_url)"],
    ["Voice and report", "record (WAV microphone capture), audioplayers (playback), pdf and printing (report PDF, preview, share)"],
    ["Media", "image_picker (gallery and camera; images capped at 2048 px wide and JPEG quality 95)"],
    ["Notifications", "flutter_local_notifications, timezone, flutter_timezone"],
    ["Design", "Inter font; colours berry #9E1B46, deep berry #831438, rose #FF4D79, pink #F03D68, background #F9F9FC"],
    ["Package", "com.example.femora, version 1.0.0 (build 1)"],
], [3.6, 13.0], caption="App technology")
H2("4.2 Screens")
table(["Screen (bottom tab)", "What it does", "State"], [
    ["Home dashboard", "Health snapshot (PCOS, ultrasound, breast risk, self-exam), quick log, next-step card", "Working: reads the health store; the old fake cycle day, hormone cards and insight text were removed because there is no cycle prediction yet"],
    ["Cycle calendar", "Calendar, phase display, daily symptom, mood and notes log", "Log saved on the phone (one entry a day); no prediction yet"],
    ["PCOS assessment", "Questionnaire (four sections), risk gauge, factor tags, guidance cards", "Working: calls /predict/pcos"],
    ["Breast health", "Ultrasound upload and result with heatmap; risk questionnaire and result; self-exam guide and reminder", "Working: calls both breast endpoints"],
    ["AI companion", "Personal chat with Gemini, voice in and out (Urdu and English), settings, health report", "Working: calls /chat and /voice endpoints (section 13)"],
], [3.8, 8.0, 4.8], caption="The five tabs")
H2("4.3 State and data flow")
table(["Class", "Responsibility"], [
    ["AppState", "Selected tab, calendar day, symptom chips and mood; saves the daily log to the health store"],
    ["HealthStore", "Profile, latest PCOS, scan, risk, heatmap and daily log on the phone; builds the name-free context for the companion (section 13)"],
    ["ChatState, VoiceController", "Conversation and sending; microphone recording, transcription and read-aloud"],
    ["PcosState", "Submits the PCOS answers, holds loading, result and error"],
    ["BreastState", "Submits a scan or the risk answers; holds the scan result and the risk result; returns an error message or null"],
    ["SelfExamState", "Date of the last self-exam and the reminder switch, stored on the device; schedules or cancels the notification"],
    ["ApiService", "All HTTP calls, timeouts and error messages; server address (built-in default, build option, or in-app setting)"],
], [3.4, 13.2], caption="State classes")
H2("4.4 PCOS assessment flow")
bullets([
    "**Sections:** About You (age, height, weight, optional waist and hip), Your Cycle (regular or irregular; days a period lasts), Symptoms (weight gain, excess hair growth, skin darkening, hair loss, acne, from the past six months), Lifestyle (fast food often; exercise regularly).",
    "The button \"Calculate My Risk\" shows a spinner while the request runs. Required yes/no questions that are unanswered are highlighted and block submission; numeric fields show their allowed range.",
    "The result screen shows the risk gauge and band, the top contributing answers as tags, guidance cards and the disclaimer. If the server cannot be reached the form stays open with an error message.",
])
H2("4.5 Breast health flow")
bullets([
    "**Ultrasound upload.** A bottom sheet offers: choose from gallery, take a photo of the scan (not on web), or two built-in sample scans (benign and malignant) for demonstrations.",
    "**Result.** After the request, the screen shows the class title, the calibrated confidence, a probability bar for each class, the scan with a switch to show the heatmap, guidance cards and the disclaimer. A button sends the plain-language summary to the AI companion.",
    "**Rejected uploads.** If the server refuses an image (colour photo, not an ultrasound, too large), the app shows the server's explanation in place of a result.",
    "**Risk questionnaire.** Questions: age, height, weight, menopause status, hormone therapy and surgical menopause (only if post-menopausal), age at first birth, close relatives with breast cancer (none, one, two or more), previous biopsy, breast density (optional), last mammogram (optional), and symptoms (lump, armpit lump, nipple discharge, nipple change, skin change, size or shape change, breast pain). Required choices block submission until answered.",
    "**Risk result.** Shows the one-year risk against the age average, the band, the answers that raised it, any red-flag symptoms with urgency, guidance, notes and the disclaimer. An info button explains what the numbers mean.",
])
H2("4.6 Breast self-exam and the monthly reminder")
bullets([
    "The **self-exam guide** is a step-by-step screen. The user can log that they did an exam; the app stores the date and shows days until the next one is due (30-day interval; negative means overdue).",
    "The **reminder** is a local notification, scheduled on the phone (no server involved). It repeats every month on the day of the last exam (capped at day 28 so short months are not skipped) at 10:00, in the phone's time zone. Title: \"Time for your monthly self-exam\".",
    "Android delivers it with inexact timing (allowed while idle), which needs no exact-alarm permission. Permission to show notifications is requested when the user turns the reminder on; if refused, the app explains how to allow it. Logging a new exam re-anchors the schedule. The receiver is also registered for reboot so the reminder survives a restart.",
])
H2("4.7 Server address setting")
para("Because the free tunnel gives a new address on every start, the app has a hidden setting: long-press the header, choose Server address and paste the address. "
     "Only addresses starting with http:// or https:// are accepted; a trailing slash is removed. The value is saved on the phone and loaded at startup; \"Reset\" restores the built-in default "
     "(10.0.2.2:8000 on the Android emulator, localhost elsewhere, or the build option API_BASE_URL).")
H2("4.8 Android configuration")
bullets([
    "Permissions: INTERNET, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED (plus vibrate, added by the notification library). Plain-http traffic is allowed (usesCleartextTraffic).",
    "The release APK is for 64-bit ARM (arm64-v8a), 19 MB, signed with a debug key (APK signature scheme v2): suitable for installing directly, not for the Play Store.",
    "Build tools: JDK 17, Android SDK platform 36 (plus 35, 34 and 33 required by plugins), build-tools 36.0.0, NDK 28.2.",
])
H2("4.9 Automated tests")
table(["Test file", "Test", "Checks"], [
    ["breast_flow_test", "risk questionnaire sends answers and shows the risk profile", "Answers reach the API in the right format; result displayed"],
    ["breast_flow_test", "questionnaire blocks submission until required choices are answered", "Validation"],
    ["breast_flow_test", "sample scan is analysed and the result can be discussed with the AI companion", "Upload path, result, hand-off to the chat"],
    ["breast_flow_test", "shows the server explanation when an upload is rejected", "Error path (422)"],
    ["breast_flow_test", "self-exam can be logged and the monthly reminder toggled", "Local storage and reminder switch"],
    ["pcos_flow_test", "questionnaire sends answers and shows the model result", "PCOS happy path"],
    ["pcos_flow_test", "shows an error and stays on the form when the server is unreachable", "PCOS failure path"],
    ["server_address_test", "a saved address overrides the default, and reset restores it", "Server setting logic"],
    ["server_address_test", "addresses that are not http(s) are rejected and change nothing", "Input validation"],
    ["server_address_test", "the saved address is loaded at startup", "Persistence"],
    ["widget_test", "Counter increments smoke test", "Stale template test: fails, also on the previous main branch"],
], [3.4, 8.2, 5.0], caption="Flutter tests (10 pass; the stale template test fails)", size=8.5)

# ================================================================== 5 PCOS
H1("5. PCOS risk model")
para("This module was completed before this reporting period and was not retrained here; the details below come from its notebook and metadata. It shows how a questionnaire model was built "
     "for the same app, and the same honesty standard is applied.")
H2("5.1 Data and preparation")
bullets([
    "**Dataset:** Polycystic ovary syndrome (PCOS), Kottarathil, Kaggle: 541 women from ten hospitals in Kerala, India, with clinical and lab columns and a PCOS yes/no label. Sheet \"Full_new\" of PCOS_data_without_infertility.xlsx.",
    "**Cleaning:** identifier columns dropped; every column forced to numeric (a few lab values had typos such as \"1.99.\"); missing values filled with the column median.",
    "**Derived columns:** irregular_cycle = cycle type is not \"regular\" (code 2); waist_hip_ratio = waist / hip.",
])
H2("5.2 Features and constraints")
para("The app can only ask what a woman can answer herself, so the deployed model uses 11 self-reportable features and no blood tests or ultrasound counts. "
     "A model on the full clinical columns was trained alongside as a reference upper bound.")
table(["Feature", "Source column", "Monotone constraint", "Importance"], [
    [f, {"bmi": "BMI", "irregular_cycle": "derived", "period_days": "Cycle length (days)", "waist_hip_ratio": "derived",
         "weight_gain": "Weight gain (Y/N)", "hair_growth": "hair growth (Y/N)", "skin_darkening": "Skin darkening (Y/N)", "hair_loss": "Hair loss (Y/N)",
         "pimples": "Pimples (Y/N)", "fast_food": "Fast food (Y/N)", "regular_exercise": "Reg. exercise (Y/N)"}[f],
     {1: "can only raise risk", -1: "can only lower risk", 0: "free"}[PC["monotone_constraints"][f]], f"{PC['feature_importance'][f]:.3f}"]
    for f in PC["features"]
], [3.6, 4.6, 4.6, 3.8], caption="PCOS features (deployed model)", align_right_from=3)
bullets([
    "**Monotonic constraints** keep the model medically sensible and explainable: a symptom can never lower the risk and regular exercise can never raise it. Period length and waist-to-hip ratio have no one-directional relationship, so they are learned freely.",
    "**Age is excluded.** Every woman in the dataset is 20 to 48 and PCOS patients are only about two years younger, so an unconstrained model learned a spurious \"younger means higher risk\" rule that would not hold for app users. The age question is asked but not used.",
])
H2("5.3 Model and training")
table(["Setting", "Value"], [
    ["Algorithm", "XGBoost classifier (gradient-boosted trees), binary logistic objective"],
    ["Trees / depth / learning rate", "300 trees, maximum depth 3, learning rate 0.05"],
    ["Subsampling", "subsample 0.9, colsample_bytree 0.9"],
    ["Metric during training / seed", "logloss / random_state 42"],
    ["Class imbalance", "SMOTE (synthetic minority oversampling) on the training rows only; inside each fold during cross-validation, so synthetic copies never reach a test fold"],
    ["Hold-out split", "80% training / 20% test (109 women), stratified by label"],
    ["Model comparison", "5-fold stratified cross-validation of logistic regression, random forest (300 trees) and XGBoost, on the self-report and the full-clinical features"],
], [5.0, 11.6], caption="PCOS training settings")
H2("5.4 Results")
tm = PC["test_metrics"]
table(["Measure (threshold 0.5)", "Value"], [
    ["Accuracy", pct(tm["accuracy"])], ["Precision", pct(tm["precision"])], ["Recall (sensitivity)", pct(tm["recall"])],
    ["F1", pct(tm["f1"])], ["AUC", f"{tm['roc_auc']:.3f}"], ["Test size", str(tm["test_size"])],
], [8.0, 8.6], caption="PCOS hold-out results", align_right_from=1,
    note="Implied confusion matrix on the 109 women: 27 true positives, 65 true negatives, 8 false positives, 9 false negatives (derived from the metrics). With only 109 women the 95% uncertainty on the accuracy is about 7 points.")
rows = [[r["features"], r["model"], r["accuracy"], r["f1"], r["recall"], r["roc_auc"]] for r in PC["cv_results"]]
table(["Features", "Model", "Accuracy", "F1", "Recall", "AUC"], rows, [3.6, 3.4, 2.4, 2.4, 2.4, 2.4], caption="5-fold cross-validation (mean ± standard deviation)", size=8.5,
      note="On the self-report features the three models are statistically indistinguishable (differences smaller than one standard deviation); XGBoost is not the best in cross-validation. It was kept because the scope names it, it supports monotonic constraints and per-answer explanations (SHAP).")
bv = PC["risk_band_validation"]
table(["Risk band", "Women in test set", "Actual PCOS rate"], [[b["band"], str(b["women"]), pct(b["pcos_rate"], 0)] for b in bv], [5.0, 5.8, 5.8],
      caption="Do the bands separate risk?", align_right_from=1, note="Bands: Low below 30%, Medium 30% to 60%, High 60% and above. The observed PCOS rate rises from 10% to 79% across the bands.")
H2("5.5 How the app uses it")
bullets([
    "The server computes BMI and the waist-to-hip ratio (median 0.89 if the tape measurements are skipped), builds the 11-feature row and predicts the probability.",
    "**Explanations:** XGBoost's per-answer SHAP contributions are computed; answers that push the risk up by more than 0.05 (log-odds) become the result tags, at most three. \"Low exercise\", \"Short periods\" (3 days or fewer) and \"Long periods\" (7 or more) are shown only when they apply.",
    "**Guidance rules:** high risk suggests a specialist and lists the confirming tests (ultrasound and hormone blood tests); medium suggests monitoring cycles for 2 to 3 months; BMI 25 or more or weight gain adds nutrition advice; no regular exercise adds a 150-minute activity tip; irregular cycles add a tracking tip; otherwise \"Healthy Habits\".",
])
H2("5.6 Limitations")
bullets([
    "Trained on 541 women from one region; not validated on Pakistani women.",
    "Self-reported symptoms are noisy and the model sees no blood tests, so it flags risk but cannot diagnose PCOS.",
    "The hold-out accuracy rests on 109 women; cross-validated accuracy is about 80%.",
])

# ================================================================== 6 ULTRASOUND
H1("6. Breast ultrasound classifier (component A)")
H2("6.1 What it does")
para("The user uploads a breast ultrasound image. The model returns calibrated probabilities for normal, benign and malignant, a heatmap of "
     "where it looked, a plain-language explanation and guidance. A scan is flagged as suspicious whenever the probability of malignancy "
     "reaches the screening threshold, even if another class is more likely. This is deliberate: a screening tool should rarely miss a cancer.")
H2("6.2 Datasets")
table(["Dataset", "Content", "Role", "Source and terms"], [
    ["BUSI", "780 images, 600 women, Baheya Hospital, Cairo; 766 kept after de-duplication; normal / benign / malignant", "Training", "Al-Dhabyani et al., Data in Brief 2020"],
    ["BrEaST-Lesions-USG", "256 scans, 256 patients; every label confirmed by biopsy or follow-up", "Training", "Pawłowska et al. 2024, TCIA, CC BY 4.0"],
    ["BUS-BRA", "1,875 images, 1,064 patients, four scanners (GE Logiq 5, GE Logiq 7, Toshiba Aplio 300, U-Systems); biopsy-proven benign / malignant; National Cancer Institute, Rio de Janeiro", "Training and external test", "Gómez-Flores et al., Medical Physics 2024; citation required"],
    ["BUS-UCLM", "683 images, 38 patients, Siemens ACUSON S2000, Spain (normal, benign, malignant)", "Experiment only (not deployed)", "Vallez et al., Scientific Data 2025, CC BY 4.0"],
    ["Natural Images, Chest X-ray, Brain MRI", "Photos, chest radiographs and brain scans from Kaggle", "Ultrasound gate only", "Public Kaggle datasets"],
], [3.0, 6.6, 2.7, 4.3], caption="Datasets used for the ultrasound module")
table(["Hospital", "Class", "Train", "Validation", "Test", "Total"], [
    ["BUSI", "normal", "91", "19", "21", "131"], ["BUSI", "benign", "306", "62", "61", "429"], ["BUSI", "malignant", "146", "29", "31", "206"],
    ["BrEaST", "normal", "2", "1", "1", "4"], ["BrEaST", "benign", "115", "22", "17", "154"], ["BrEaST", "malignant", "67", "14", "17", "98"],
    ["BUS-BRA", "benign", "772", "126", "370", "1,268"], ["BUS-BRA", "malignant", "352", "63", "192", "607"],
    ["**All**", "**normal**", "**93**", "**20**", "**22**", "**135**"], ["**All**", "**benign**", "**1,193**", "**210**", "**448**", "**1,851**"],
    ["**All**", "**malignant**", "**565**", "**106**", "**240**", "**911**"],
], [3.0, 3.0, 2.6, 2.6, 2.6, 2.8], caption="Images per hospital, class and split (final deployed model; 2,897 images)", align_right_from=2,
    note="Normal scans are rare (135 in total, only 22 in the test set), so the normal class is the least reliable. BUS-BRA has no normal class.")
H2("6.3 Data-quality decisions")
bullets([
    "**Lesion masks are not training images.** BUSI ships a black image with a white blob (the lesion outline) next to each scan. Those masks are excluded from training and used only to check the heatmaps.",
    "**Near-duplicates are grouped.** A 256-bit perceptual (difference) hash groups images within 12 bits (about 5%) of each other. Groups are never split across train and test, and groups with conflicting labels are dropped (14 images; 148 images fell into 67 duplicate groups).",
    "**BUS-BRA is split by patient.** Both breasts of a patient stay in the same split (about 60% train, 10% validation, 30% test), so the model cannot memorise a patient.",
    "**The old test set is pinned.** BUSI and BrEaST keep the exact split of version 7 (stored in ml/v7_split.csv), so old and new models are scored on the same original images.",
    "**A pre-augmented BUSI copy was rejected.** A Kaggle dataset of rotated and sharpened BUSI copies would leak near-identical images into the test set.",
    "**BUS-UCLM marked and Doppler images were excluded.** 144 of the 154 images with on-screen measurement marks show a lesion, so the marks would teach the model that marks mean lesion.",
])
H2("6.4 Method and settings")
table(["Setting", "Value"], [
    ["Preprocessing (same code in training and server)", "EXIF rotation, convert to grayscale, pad to a square with black (not stretch: lesion shape matters), bilinear resize to 224 × 224, repeat to 3 channels, ImageNet mean (0.485, 0.456, 0.406) and standard deviation (0.229, 0.224, 0.225)"],
    ["Backbone", "ResNet50 (torchvision, ImageNet weights V2), about 25.6 million parameters"],
    ["Head", "Global average pooling, dropout 0.3, linear layer 2048 to 3 classes"],
    ["Loss", "Cross-entropy with label smoothing 0.05, multiplied per image by a weight (below)"],
    ["Sample weights", "Inverse class frequency; the source-balanced recipe also multiplies by inverse hospital frequency so each hospital counts equally; normalised to mean 1"],
    ["Optimiser", "AdamW, weight decay 1e-4"],
    ["Phase 1 (4 epochs)", "Backbone frozen; only the new head trains, learning rate 1e-3"],
    ["Phase 2 (26 epochs)", "All layers train: backbone learning rate 1e-4, head 5e-4, cosine decay to zero over the 26 epochs (stepped every batch)"],
    ["Batch size, precision", "32 images; mixed precision (fp16 autocast with gradient scaling) on the GPU"],
    ["Training images", "Pre-resized (padded) to 288 × 288, then randomly cropped to 224 × 224 with the augmentations below; validation and test use the plain 224 × 224 image"],
    ["Epoch selection", "The final model keeps the epoch with the best validation macro-F1 (epoch 23 of 30); cross-validation folds use the last epoch, so their estimate is not optimistic"],
    ["Cross-validation", "5-fold StratifiedGroupKFold on train + validation, stratified by hospital and class, grouped by duplicate group or patient; out-of-fold predictions reused for calibration and the threshold"],
    ["Reproducibility", "Random seed 42 everywhere; splits stored in ml/v7_split.csv and ml/busbra_split.csv"],
    ["Hardware", "Kaggle NVIDIA Tesla T4 GPU (version 7 trained in 27 min 44 s)"],
], [5.0, 11.6], caption="Ultrasound training settings", size=8.5)
table(["Augmentation", "Standard recipe", "Scanner recipe (selected)"], [
    ["Random resized crop (scale / aspect)", "0.70 to 1.00 / 0.85 to 1.18", "0.55 to 1.00 / 0.80 to 1.25"],
    ["Horizontal flip", "yes (never vertical: the transducer is always at the top)", "yes"],
    ["Rotation", "up to 10 degrees, 50% of images", "up to 12 degrees, 50%"],
    ["Brightness and contrast jitter", "± 0.25", "± 0.40"],
    ["Gaussian blur (kernel 5, sigma 0.1 to 1.5)", "no", "30% of images"],
    ["Sharpness change (factor 2.0)", "no", "30% of images"],
    ["Hospital weighting", "no", "each hospital counts equally"],
], [5.6, 5.4, 5.6], caption="The two training recipes", size=8.5,
    note="The scanner recipe imitates differences between machines (zoom, blur, sharpness, gain and contrast).")
H2("6.5 Selecting the recipe by cross-validation")
para("The rule was fixed in advance: the recipe with the higher mean malignant AUC across hospitals on out-of-fold predictions wins. The test set was not touched.")
cvrows = []
for r in UB["cv_results"]:
    cvrows.append([r["recipe"].split(" +")[0].capitalize() if r["recipe"] == "baseline" else "Scanner", str(r["fold"]), f"{r['accuracy']:.3f}", f"{r['macro_f1']:.3f}", f"{r['malignant_sensitivity']:.3f}", f"{r['malignant_auc']:.3f}"])
table(["Recipe", "Fold", "Accuracy", "Macro-F1", "Cancers caught", "AUC"], cvrows, [3.4, 1.8, 2.8, 2.8, 3.2, 2.6], caption="Cross-validation, fold by fold", size=8.5, align_right_from=1)
rc = UB["recipe_comparison"]
table(["Recipe", "CV accuracy", "CV AUC", "BUSI AUC", "BrEaST AUC", "BUS-BRA AUC", "Selection score"], [
    [("Baseline" if r["recipe"] == "baseline" else "Scanner (selected)"), r["cv_accuracy"], r["cv_malignant_auc"], f"{r['BUSI_malignant_auc']:.3f}", f"{r['BrEaST_malignant_auc']:.3f}", f"{r['BUS-BRA_malignant_auc']:.3f}", f"{r['selection_score']:.4f}"] for r in rc
], [3.2, 2.6, 2.6, 2.0, 2.2, 2.4, 1.6], caption="Recipe comparison (mean ± standard deviation)", size=8.5, align_right_from=1,
    note="The two recipes are effectively tied (0.901 both); the scanner recipe was chosen by the fixed rule and is more stable across folds (standard deviation 0.014 against 0.027 for accuracy).")
H2("6.6 Calibration, threshold and export")
bullets([
    "**Temperature scaling** divides the network's logits by T = 1.1425, fitted on 2,187 out-of-fold predictions, so a stated confidence matches how often it is right. On the test set the expected calibration error fell from 0.0385 to 0.0289.",
    "**Screening threshold.** The notebook picked the highest threshold that still catches at least 90% of malignant scans on the out-of-fold predictions (0.21). The deployed value is 0.25 (section 6.10).",
    f"**ONNX export.** Opset 17; input \"image\" of shape batch × 3 × 224 × 224; outputs logits (batch × 3), embedding (batch × 2048) and class activation maps (batch × 3 × 7 × 7); dynamic batch size. Convolution and linear weights are stored in fp16 and cast to fp32 when loaded, keeping the file at 47 MB (fp32 would be 94 MB, near GitHub's 100 MB limit). The fp32 export matches PyTorch to within {UB['onnx_parity']['fp32_export_max_abs_diff']:.1e} in probability; the deployed file differs by at most {UB['onnx_parity']['deployed_max_abs_diff']:.3f} and changes the predicted class of {UB['onnx_parity']['test_predictions_changed_by_fp16']} of 710 test scans. Every reported test number is computed with the exported ONNX model, the same one the server runs.",
    "**Speed.** The model call takes about 95 ms per scan on this PC's CPU (median 94 ms, 95th percentile 106 ms; measured on 40 scans). End-to-end time is dominated by the upload.",
])
H2("6.7 Model versions")
table(["Version", "What changed", "Status"], [
    ["v6", "BUSI + BrEaST; first working model", "Replaced"],
    ["v7", "Added the ultrasound gate, calibration and a fixed split. Test accuracy 79.7% on its own 148 scans", "Replaced; kept as a fallback"],
    ["BUS-BRA model", "v7 pipeline plus BUS-BRA (third hospital, four scanners), patient-level split, separate Kaggle notebook", "Deployed in the app"],
    ["UCLM model", "BUS-BRA model plus BUS-UCLM (mostly normal scans, a fifth scanner)", "Tested, not deployed"],
], [3.0, 9.6, 4.0], caption="Ultrasound model history")

H2("6.8 Results")
H3("6.8.1 The problem found in version 7")
para("Before training anything new, version 7 was run, unchanged, on all 1,875 BUS-BRA scans, which it had never seen. It caught 76.9% of cancers, "
     "cleared 58.4% of benign scans and had an AUC of only 0.733. Accuracy differed strongly by scanner:")
table(["Scanner (BUS-BRA)", "Scans", "AUC", "Cancers caught", "Benign cleared"], [
    ["GE Logiq 5", "809", "0.756", "74%", "66%"], ["GE Logiq 7", "902", "0.735", "84%", "49%"],
    ["Toshiba Aplio 300", "139", "0.746", "59%", "77%"], ["U-Systems", "25", "0.812", "64%", "79%"],
], [5.4, 2.2, 2.6, 3.2, 3.2], caption="Version 7 on unseen scanners (notebook threshold 0.22)", align_right_from=1)
H3("6.8.2 Version 7 against the BUS-BRA model on unseen patients")
para("The fair comparison uses the 562 scans of BUS-BRA test patients (192 malignant), which neither model trained on. "
     "Confidence intervals come from 2,000 bootstrap resamples of the test scans.")
table(["Measure", "Version 7", "BUS-BRA model (threshold 0.21)"], [
    ["AUC (95% interval)", "0.691 (0.643 to 0.735)", "0.866 (0.832 to 0.896)"],
    ["Cancers caught", "72.4% (65.9 to 78.7)", "91.1% (86.8 to 95.0)"],
    ["Benign scans cleared", "58.4% (53.3 to 63.1)", "53.2% (48.3 to 58.2)"],
], [4.6, 5.6, 6.4], caption="Unseen BUS-BRA patients (562 scans)", note="The AUC gain is 0.175 (95% interval 0.136 to 0.214); the new model was better in 100% of resamples.")
H3("6.8.3 The original 148 test scans")
v7t, nt = V7["test_metrics"], UB["test_metrics_v7_subset"]
table(["Measure", "Version 7", "BUS-BRA model (threshold 0.21)"], [
    ["Accuracy", pct(v7t["accuracy"]), pct(nt["accuracy"])],
    ["Cancers caught", pct(v7t["malignant_sensitivity"]), pct(nt["malignant_sensitivity"])],
    ["Benign scans cleared", pct(v7t["malignant_specificity"]), pct(nt["malignant_specificity"])],
    ["AUC", f"{v7t['malignant_auc']:.3f}", f"{nt['malignant_auc']:.3f}"],
], [4.6, 5.6, 6.4], caption="The 148 scans both models were tested on",
    note="This set is small: four extra correct or wrong images move accuracy by about 2.7 points. AUC and sensitivity improved; accuracy and specificity dipped slightly.")
H3("6.8.4 Final results of the deployed model")
tm, old, bra = UB["test_metrics"], UB["threshold_note"]["old_scans_at_deployed_threshold"], UB["threshold_note"]["busbra_scans_at_deployed_threshold"]
table(["Test group", "Scans", "Accuracy", "Cancers caught", "Non-cancer cleared", "AUC"], [
    ["All held-out scans", "710", pct(tm["accuracy"]), pct(tm["malignant_sensitivity"]), pct(tm["malignant_specificity"]), f"{tm['malignant_auc']:.3f}"],
    ["Original BUSI + BrEaST scans", "148", pct(old["accuracy"]), pct(old["malignant_sensitivity"]), pct(old["malignant_specificity"]), f"{UB['test_metrics_v7_subset']['malignant_auc']:.3f}"],
    ["BUS-BRA unseen patients", "562", pct(bra["accuracy"]), pct(bra["malignant_sensitivity"]), pct(bra["malignant_specificity"]), f"{UB['test_metrics_busbra']['malignant_auc']:.3f}"],
], [5.0, 1.6, 2.4, 2.8, 3.0, 1.8], caption="Deployed ultrasound model at the screening threshold 0.25", align_right_from=1,
    note="Accuracy is three-class (normal, benign, malignant). Sensitivity and specificity treat malignant against everything else. Approximate 95% uncertainty: accuracy ± 3.3 points (710 scans), cancers caught ± 3.9 points (240 malignant scans).")
H3("6.8.5 One model, different decision rules")
cmp_rows = UB["comparison"]
table(["Decision rule (all 710 test scans)", "Accuracy", "Macro-F1", "Cancers caught", "Benign / normal cleared", "AUC"], [
    ["Frozen ImageNet ResNet50 + logistic regression (baseline)", pct(cmp_rows[0]["accuracy"]), f"{cmp_rows[0]['macro_f1']:.3f}", pct(cmp_rows[0]["malignant_sensitivity"]), pct(cmp_rows[0]["malignant_specificity"]), f"{cmp_rows[0]['malignant_auc']:.3f}"],
    ["Fine-tuned, most likely class wins (argmax)", pct(cmp_rows[1]["accuracy"]), f"{cmp_rows[1]['macro_f1']:.3f}", pct(cmp_rows[1]["malignant_sensitivity"]), pct(cmp_rows[1]["malignant_specificity"]), f"{cmp_rows[1]['malignant_auc']:.3f}"],
    ["Fine-tuned, screening threshold 0.21", "68.3%", "0.731", "90.8%", "57.4%", "0.869"],
    ["**Fine-tuned, screening threshold 0.25 (deployed)**", "**71.8%**", "**0.754**", "**89.2%**", "**63.6%**", "**0.869**"],
], [6.0, 2.0, 1.9, 2.4, 2.6, 1.7], caption="Same network, different decision rules", size=8.5, align_right_from=1,
    note="Fine-tuning lifts the AUC from 0.77 (frozen features) to 0.87. The neutral rule gives the highest accuracy (80.4%); the screening rule trades about 9 points of accuracy for about 12 points of cancers caught.")
H3("6.8.6 Errors in detail (threshold 0.25, 710 scans)")
table(["Actual class", "Predicted normal", "Predicted benign", "Predicted malignant", "Total"], [
    ["Normal", "18", "0", "4", "22"], ["Benign", "3", "278", "167", "448"], ["Malignant", "0", "26", "214", "240"],
], [3.6, 3.4, 3.4, 3.8, 2.4], caption="Confusion matrix of the deployed model", align_right_from=1)
table(["Class", "Precision", "Recall", "F1", "Support"], [
    ["Normal", "85.7%", "81.8%", "0.837", "22"], ["Benign", "91.4%", "62.1%", "0.739", "448"], ["Malignant", "55.6%", "89.2%", "0.685", "240"],
], [4.0, 3.2, 3.2, 3.0, 3.2], caption="Per-class scores of the deployed model", align_right_from=1,
    note="Macro AUC (one class against the others) is 0.913. The main error is benign scans flagged malignant (167 of 448); missed cancers are 26 scans, all predicted benign, none predicted normal.")
H3("6.8.7 Results by hospital and scanner")
rows = []
for k, v in UB["per_source_test"].items():
    rows.append([k + " (hospital)", v["images"], pct(v["accuracy"]), pct(v["malignant_sensitivity"]), pct(v["malignant_specificity"]), f"{v['malignant_auc']:.3f}"])
for k, v in UB["per_device_test"].items():
    rows.append([k.split(" @")[0] + " (scanner)", v["images"], pct(v["accuracy"]), pct(v["malignant_sensitivity"]), pct(v["malignant_specificity"]), f"{v['malignant_auc']:.3f}"])
table(["Group", "Scans", "Accuracy", "Cancers caught", "Benign cleared", "AUC"], rows, [5.0, 1.6, 2.4, 2.8, 3.0, 1.8],
      caption="Held-out results by hospital and scanner (notebook threshold 0.21)", align_right_from=1,
      note="BrEaST has only 35 test scans and U-Systems only a handful, so those rows are indicative, not conclusive.")
figure("ml/output/breast_busbra/model/breast_evaluation.png",
       "Confusion matrix (all 710 test scans) and ROC curves by hospital, at the notebook threshold 0.21. At 0.25 fewer benign scans are flagged.", 16.0)
figure("ml/output/breast_busbra/model/breast_training_curve.png", "Training loss and validation macro-F1 by epoch (dotted line: start of full fine-tuning; dashed: chosen epoch 23).", 12.0)
H3("6.8.8 The BUS-UCLM experiment")
table(["Measure", "BUS-BRA model", "UCLM model"], [
    ["AUC, all test scans", f"{UB['test_metrics']['malignant_auc']:.3f}", f"{UC['test_metrics']['malignant_auc']:.3f}"],
    ["AUC, BUS-BRA unseen patients", f"{UB['test_metrics_busbra']['malignant_auc']:.3f}", f"{UC['test_metrics_busbra']['malignant_auc']:.3f}"],
    ["Cancers caught (notebook threshold)", "90.8%", pct(UC["test_metrics"]["malignant_sensitivity"])],
    ["Benign cleared (notebook threshold)", "57.4%", pct(UC["test_metrics"]["malignant_specificity"])],
    ["Screening threshold fitted", "0.21", f"{UC['malignant_threshold']:.2f}"],
], [6.4, 5.0, 5.2], caption="Adding BUS-UCLM (same 710 test scans)",
    note="Decision: not deployed. The AUC did not change, and the model caught fewer cancers because its threshold drifted (fitted on training data that included the easier UCLM scans).")
H2("6.9 Rejecting uploads that are not breast ultrasounds")
para("People will upload the wrong image. A classifier would still answer normal, benign or malignant for a selfie or an X-ray, so the server runs two checks first.")
bullets([
    "**Colour check:** B-mode ultrasound is grey. Images where more than 10% of (downsampled) pixels are clearly coloured (channel difference above 30) are refused, which also catches colour Doppler scans.",
    "**Ultrasound gate:** a logistic regression (regularisation C = 0.1, balanced classes, standardised inputs) on the network's 2,048-number embedding. Positives: the training ultrasounds. Negatives: 600 grayscale photos from four everyday categories (airplane, car, cat, dog) and 400 chest X-rays. Its acceptance threshold is the lower of 0.5 and the 1st percentile of validation ultrasound scores, so about 99% of real scans pass (deployed value 0.5). An earlier feature-distance check was tried and rejected because photos and X-rays landed at the same distances as real scans.",
    "**Held-out tests of the gate:** photos of other categories (colour and grayscale), other chest X-rays, and brain MRIs, an image type it never saw.",
])
rows = [[r["images"], r["n"], pct(r["rejected_colour"]), pct(r["rejected_gate"]), pct(r["rejected_total"])] for r in UB["ood_evaluation"]]
table(["Uploaded images", "Count", "Rejected by colour", "Rejected by gate", "Rejected in total"], rows, [6.2, 1.6, 2.9, 2.9, 3.0],
      caption="Original ultrasound gate (before the update below)", align_right_from=1,
      note="Real test ultrasounds are never wrongly rejected. About 6% of unseen brain MRIs still pass. Ultrasounds of other organs were not part of this test; one such image passed, which led to the update below (section 6.13).")
figure("ml/output/breast_busbra/model/breast_gate.png", "Score distributions of the original gate for ultrasounds and the other image types (log scale).", 12.5)
G2 = UB["gate_v2"]
H3("Gate update (20 September 2026): refusing ultrasounds of other organs")
para("The web-image check (section 6.13) showed that an ultrasound of another body part passed the gate, because the gate had only seen photos and X-rays as negatives. "
     "The gate was therefore retrained (ml/train_gate_v2.py). Only the gate changed: the classifier network is untouched, so no ultrasound result changed. The gate is a logistic regression on the network's 2,048-number embedding, "
     "so retraining needed only the embeddings of new images, which were computed locally on the CPU.")
bullets([
    "**Training negatives:** 600 grayscale photos (four categories), 400 chest X-rays, and other-organ ultrasounds: 250 thyroid nodule ultrasounds (DDTI), 250 thyroid ultrasounds (AUITD, Algeria), 250 fetal head ultrasounds and 250 kidney ultrasounds (Kaggle datasets). Positives: the 1,851 training breast ultrasounds. Same settings as before (regularisation 0.1, balanced classes, standardised inputs).",
    f"**Threshold:** the lower of 0.5 and the 1st percentile of validation breast scores, now {G2['threshold']:.3f} (was {G2['previous_threshold']:.3f}), so about 99% of validation breast scans still pass.",
    "**Honest estimate for unseen organs:** a first version was trained without the kidney and the AUITD thyroid data, so those two sets were genuinely unseen. It refused 43% of unseen thyroid ultrasounds (a different dataset) and 60% of kidney ultrasounds (an organ it never saw). The deployed version then also trained on those two sets, so its scores on them are no longer a test of generalisation.",
])
rows = [[r["images"], r["n"], pct(r["rejected_old_gate"]), pct(r["rejected_new_gate"])] for r in G2["evaluation_final_gate"]]
table(["Held-out images", "Count", "Refused by the old gate", "Refused by the updated gate"], rows, [8.0, 1.6, 3.5, 3.5],
      caption="Old gate against the updated (deployed) gate (colour check and gate together)", align_right_from=1,
      note="The first row must stay near 0%: the updated gate wrongly refuses 0.3% of real breast test scans (2 of 710). The thyroid, kidney and fetal rows use other images of sources the updated gate trained on, so they are in-distribution.")
rows = [[r["images"], r["n"], pct(r["rejected_old_gate"]), pct(r["rejected_new_gate"])] for r in G2["unseen_estimate"]["rows"] if "ultrasound" in r["images"].lower() and "Breast" not in r["images"]]
table(["Truly unseen ultrasounds (first version)", "Count", "Refused by the old gate", "Refused by the first new gate"], rows, [8.0, 1.6, 3.5, 3.5],
      caption="Generalisation to unseen ultrasound datasets and organs", align_right_from=1,
      note="The fetal row is the same dataset as its training images, so it is not a generalisation test. New organs (liver, abdomen, carotid, obstetric scans) are therefore refused only partly; more organ data would help.")
para("After installing the updated gate, the earlier checks were repeated through the API: the two built-in demo scans, the real carcinoma and fibroadenoma web images and all seven test-kit scans (clean, compressed, low resolution and annotated) still pass; "
     "the generic non-breast ultrasound that slipped through before is now refused; the two wrong images are still refused; colour-tinted images are still refused by the colour check.")
H2("6.10 The screening threshold decision")
para("The notebook fitted a threshold of 0.21 (at least 90% of cancers caught on out-of-fold predictions). After the results were in, the threshold "
     "was raised to 0.25 to reduce false alarms, and the displayed accuracy in the app was updated with it.")
table(["Threshold", "Accuracy", "Cancers caught", "Non-cancer cleared", "Missed cancers (of 240)"], [
    ["0.21 (notebook)", "68.3%", "90.8%", "57.4%", "22"], ["**0.25 (deployed)**", "**71.8%**", "**89.2%**", "**63.6%**", "**26**"],
    ["0.30", "73.9%", "85.8%", "68.5%", "34"],
], [3.8, 2.6, 3.2, 3.6, 3.4], caption="Threshold trade-off on the 710 held-out scans", align_right_from=1)
callout("Honest caveat", "The value 0.25 was chosen after looking at these test scans, so a small amount of tuning on the test set is involved. It is a choice "
        "about where to trade false alarms against missed cancers, not a model improvement. Going to 0.30 would miss 8 more cancers to clear about 5 more points of non-cancer scans, "
        "which is not a good trade for a screening tool.")
H2("6.11 Explainability")
ce = UB["cam_evaluation"]
para(f"The heatmap is a class activation map: because the network ends in global average pooling and one linear layer, the map is the classifier's weights applied to every position of the last 7 × 7 feature map, "
     "which is exact. The server upsamples it to 512 pixels, colours it blue to cyan to yellow to red, overlays it with up to 60% opacity where it is hot, crops it back to the scan's shape and returns it as a JPEG (quality 85). "
     f"Checked against the radiologists' lesion outlines on {ce['lesion_images']} test scans, its hottest point "
     f"falls inside the lesion {pct(ce['pointing_game'], 0)} of the time, against {pct(ce['pointing_game_chance'], 0)} for a random point, with a mean overlap (IoU) of {ce['mean_iou']:.2f}. "
     "That beats chance but is weak, so the app should describe the heatmap as illustrative of where the model looked, not as the tumour location.")
figure("ml/output/breast_busbra/model/breast_cam_examples.png", "Class activation maps (colour) against radiologist lesion outlines (white).", 15.5)
H2("6.12 Limitations")
bullets([
    "More than one in three benign scans is still flagged suspicious; on unseen scanners the rate is higher.",
    "The test set mixes very different data: BUS-BRA contains only lesions that were sent for biopsy, so its benign cases are harder than a typical benign lump. Real-world false-alarm rates will differ.",
    "About one third of the test scans are malignant, far above real screening prevalence. At realistic prevalence most flagged scans would be false alarms, which is normal for a screening tool but must be explained to users.",
    "The Toshiba scanner, the BrEaST hospital and the U-Systems scanner remain weak; they need more scans from those machines.",
    "Telling benign from malignant on a single ultrasound image is hard even for radiologists, so further gains from retraining are expected to be small.",
    "All training hospitals are in Egypt, Poland and Brazil; none is in Pakistan.",
    "**Ultrasounds of other body parts are only partly refused.** The original gate let them through. The updated gate refuses the organs it was trained on (thyroid, fetal head, kidney) but only about 43% to 60% of unseen ones, so a scan of another organ can still receive a breast verdict (section 6.9).",
])
H2("6.13 Informal check with images from the web")
para("Because users may try images found online, two experiments were run through the running server (20 September 2026). They are informal: two real web images are far too few to estimate accuracy.")
H3("Real images from Wikipedia (free licences; descriptions give the label)")
table(["Image", "Description", "App result"], [
    ["Mamma ca 1.jpg (497 x 344 px)", "Breast carcinoma on ultrasound (malignant)", "Suspicious Finding, 93%: correct"],
    ["Breast US Fibroadenoma (Nevit, 600 x 550 px)", "Fibroadenoma (benign)", "Suspicious Finding, 66%: a false alarm (malignant 66%, benign 29%)"],
    ["Ultrasound Scan ND (800 x 600 px)", "Generic medical ultrasound, organ not stated (not a breast scan)", "Original gate: passed and returned Likely Benign, 96% (should have been refused). After the gate update (section 6.9): refused"],
], [5.4, 5.6, 5.6], caption="Web images through the deployed model", size=8.5,
    note="The images were taken from Wikipedia articles (the Wikimedia Commons site itself was not reachable from the development PC). The benign false alarm is consistent with the measured false-alarm rate (about a third of non-cancer scans).")
H3("Web-style damage to the seven test-kit scans")
table(["Change applied", "Same answer as the clean upload", "Refused by the checks", "Different answer"], [
    ["Heavy JPEG compression (quality 30)", "7 of 7", "0", "0"],
    ["Low resolution (shrunk to a quarter, enlarged back)", "7 of 7", "0", "0"],
    ["Annotation marks and text (white line, yellow crosses, caption)", "7 of 7", "0", "0"],
    ["Sepia colour tint", "4 of 7", "3", "0"],
], [7.4, 3.8, 2.8, 2.6], caption="Robustness to typical web changes (7 scans)", size=8.5, align_right_from=1,
    note="Confidence moved by up to about 35 points on one scan with annotation marks (79% to 44%), but the class did not change. Tinted images are often refused because the colour check treats them as photos or Doppler scans.")
para("**Conclusion.** Compression, low resolution and on-screen marks do not change the answer. Colour-tinted or colour Doppler images are refused. Grayscale ultrasounds of other organs were wrongly accepted by the original gate; the updated gate (section 6.9) refuses the generic example and the organs it was trained on, but unseen organs only partly. A benign lesion can still be flagged, so results on web images "
     "should not be read as validation. Adding more organs (abdomen, carotid, obstetric) as gate negatives would improve this further.")

# ================================================================== 7 RISK
H1("7. Breast cancer risk questionnaire (component B)")
H2("7.1 Data and design")
d = RK["dataset"]
para(f"The model is trained on the Breast Cancer Surveillance Consortium (BCSC) Risk Estimation dataset: {d['mammograms']:,} screening mammograms of women with "
     f"no previous breast cancer (recorded 1996 to 2002), aggregated into {d['combinations']:,} risk-factor combinations, with {d['cancers_1yr']:,} cancers (invasive or DCIS) diagnosed within one year of the mammogram. "
     "Each row is one combination plus a count, so training uses the counts as sample weights. The dataset ships with its own training and validation flag, used as supplied.")
bullets([
    "**Only questions a woman can answer:** age, menopause, body-mass index, age at first birth, close relatives with breast cancer, previous breast biopsy, hormone therapy. Breast density and the last mammogram result are optional. \"Don't know\" is treated as missing, exactly as BCSC codes it (XGBoost learns which branch missing values should follow).",
    "**Race and ethnicity are excluded:** US census categories do not transfer to Femora's users.",
    "**Monotonic constraints** on established risk factors (age, family history, biopsy, density, hormone therapy) keep the model medically sensible: adding a risk factor never lowers the estimate.",
    "**No re-balancing (SMOTE):** the goal is a calibrated absolute risk, not a classifier.",
    "**Symptoms** (lump, nipple discharge, skin change) are not in any public outcome dataset, so the app handles them with NICE NG12 referral rules, separate from the model (section 7.5).",
])
H2("7.2 How answers become model inputs")
table(["Model input", "Coding from the answers"], [
    ["agegrp", "(age - 35) / 5 + 1, limited to 1 to 10 (35-39 up to 80-84); younger or older women use the nearest group and get a note"],
    ["menopaus", "1 if post-menopausal or age 55 and over; 0 if pre-menopausal; missing if unknown"],
    ["bmi", "1 below 25; 2 for 25 to under 30; 3 for 30 to under 35; 4 for 35 and over"],
    ["agefirst", "0 first birth under 30; 1 at 30 or older; 2 never; missing if unknown"],
    ["nrelbc", "0, 1 or 2 (two or more) close relatives with breast cancer; missing if unanswered"],
    ["brstproc", "1 previous breast biopsy, 0 none; missing if unanswered"],
    ["hrt, surgmeno", "Current hormone therapy; menopause from ovary removal. Only used when post-menopausal, otherwise missing"],
    ["density", "BI-RADS a, b, c, d coded 1 to 4; missing if not known"],
    ["lastmamm", "0 normal, 1 false positive; missing if never had one or unknown"],
], [3.2, 13.4], caption="Feature coding (identical in the notebook and the server)")
H2("7.3 Model settings")
table(["Setting", "Value"], [
    ["Algorithm", "XGBoost classifier, histogram tree method, binary logistic objective"],
    ["Trees", "Up to 1,000 with early stopping after 50 rounds without improvement; stopped at 80 trees"],
    ["Depth / learning rate", "Maximum depth 4 / learning rate 0.03"],
    ["Sampling", "subsample 0.8, colsample_bytree 0.9, minimum child weight 20"],
    ["Constraints", "Monotone increasing for agegrp, nrelbc, brstproc, hrt and density; free for menopaus, bmi, agefirst, surgmeno and lastmamm"],
    ["Sample weights", "The count column (number of mammograms in each combination)"],
    ["Early stopping data", "A stratified 15% slice of the training rows; the BCSC validation split is never touched during training"],
    ["Seed", "42"],
], [4.4, 12.2], caption="Risk model training settings")
H2("7.4 Results")
rows = [[m["model"].replace("—", "-"), f"{m['roc_auc']:.4f}", f"{m['brier']:.6f}", f"{m['expected_over_observed']:.3f}"] for m in RK["comparison"]]
table(["Model", "AUC", "Brier score", "Expected / observed"], rows, [8.4, 2.4, 2.8, 3.0],
      caption=f"Validation on about {int(sum(b['women'] for b in RK['band_validation'])):,} mammograms", align_right_from=1,
      note="Expected / observed compares the number of cancers the model predicts with the number that occurred; 1.00 is perfect. All numbers are weighted by the mammogram counts.")
para("**Why not report an accuracy percentage.** Only about 0.5% of these women develop cancer within a year. A model that says nobody has cancer would be 99.5% "
     "accurate and useless. AUC and calibration are the honest measures. An AUC of 0.64 is normal for risk-factor models (published models score roughly 0.6 to 0.7): "
     "risk factors say who is at somewhat higher risk, not who has cancer. The model adds about four AUC points over age alone (0.60).")
bands = RK["band_validation"]
table(["Risk band", "Share of women", "Cancers observed", "Observed risk vs age average"], [
    [b["band"].capitalize(), pct(b["share_of_women"], 2), f"{int(b['cases']):,}", f"{b['observed_rr_vs_age_average']:.2f} x"] for b in bands
], [3.4, 4.0, 4.2, 5.0], caption="Do the bands separate risk? (validation data)", align_right_from=1,
    note="Bands compare a woman's risk with the average for her age: low below 1.35 times, medium 1.35 to 2.4, high above 2.4 (NICE familial-risk categories). The high band holds only about 0.03% of women (5 cancers), so it will rarely appear and its value is uncertain.")
table(["Age group", "Average one-year risk per 1,000 women"], [[RK["age_groups"][k], f"{RK['age_average_risk'][k] * 1000:.2f}"] for k in sorted(RK["age_groups"], key=int)],
      [5.0, 11.6], caption="Age baseline used for the comparison", align_right_from=1)
figure("ml/output/breast_risk/model/breast_risk_evaluation.png", "Calibration by risk decile and ROC curve on the validation data.", 15.5)
figure("ml/output/breast_risk/model/breast_risk_feature_importance.png", "Which questions matter most to the model (age and breast density dominate).", 11.5)
H2("7.5 What the user sees and why")
bullets([
    "**Factors.** SHAP contributions above 0.05 (excluding age) name up to three answers that raised the estimate: Family History or Strong Family History, Previous Biopsy, Dense Breasts (density c or d), Hormone Therapy, First Birth After 30, No Births, BMI, Past Abnormal Mammogram.",
    "**Symptoms follow NICE NG12 referral rules, not the model.** Urgent means a doctor within two weeks; soon means a check-up. Breast pain alone is not treated as a warning sign.",
    "**Guidance** depends on the level and flags: urgent symptoms, a check-up, a screening discussion for medium or high risk (mentioning genetic counselling when two or more relatives are affected), routine mammograms from age 40, weight and hormone-therapy advice after menopause, and the monthly self-exam.",
    "**Notes** appear when the age is outside 35 to 84 or when breast density is missing for a woman of 40 or older.",
])
table(["Symptom", "Urgent (two-week) from age", "Otherwise"], [
    ["Breast lump", "30", "Check-up soon"], ["Armpit lump", "30", "Check-up soon"], ["Nipple discharge", "50", "Check-up soon"],
    ["Nipple changes", "50", "Check-up soon"], ["Skin changes", "any age", "-"], ["Change in size or shape", "never urgent", "Check-up soon"], ["Breast pain", "not a flag", "Information only"],
], [5.4, 5.6, 5.6], caption="Symptom referral rules (NICE NG12)")
H2("7.6 Behaviour check through the API")
table(["Example profile (45 years unless stated)", "One-year risk", "Compared with average", "Level"], [
    ["Typical woman", "0.33%", "0.99 x", "Low"], ["25 years (model covers 35 to 84, so 35-39 is used)", "0.23%", "0.83 x", "Low"],
    ["60 years, post-menopausal", "0.55%", "0.92 x", "Low"], ["Mother or sister with breast cancer", "0.42%", "1.26 x", "Low"],
    ["Two or more close relatives", "0.49%", "1.47 x", "Medium"], ["Previous breast biopsy", "0.43%", "1.28 x", "Low"],
    ["Very dense breasts (BI-RADS d)", "0.37%", "1.10 x", "Low"],
    ["Two or more relatives + biopsy + dense breasts", "0.67%", "2.02 x", "Medium"],
], [8.2, 2.6, 3.4, 2.4], caption="Risk estimates rise sensibly as factors are added", align_right_from=1)
H2("7.7 Deviation from the scope document")
para("The scope document names the Wisconsin dataset for this component. Wisconsin holds 30 measurements of cell nuclei from biopsy images, none of which a user "
     "can self-report, so it cannot power a questionnaire. BCSC was used instead. A Wisconsin model is still trained in the notebook for comparison "
     f"(accuracy {RK['wisconsin_reference']['test']['accuracy'] * 100:.1f}%, AUC {RK['wisconsin_reference']['test']['roc_auc']:.3f} on 114 held-out biopsies), which shows the panel why it was not used. "
     "This change should be reported to the supervisor.")
H2("7.8 Limitations")
bullets([
    "The AUC of 0.64 was measured on BCSC's own validation split (US data). The model has not been validated on Pakistani women.",
    "The data covers 1996 to 2002 and screening populations, and it contains no symptomatic patients.",
    "Breast density is a strong predictor but most users will not know it; the estimate is less precise without it.",
])

# ================================================================== 8 OTHER
H1("8. Other parts of the breast module")
bullets([
    "**Self-exam guide and monthly reminder (done):** described in section 4.6.",
    "**Chatbot on results (6.3C, done as a prototype):** the AI companion now answers through the backend (section 13). The Breast tab has \"Discuss with AI\" buttons that send the user's own result to it.",
    "**Mammography (future work):** a mammogram is a different image type, so it would need its own model, dataset and upload path, plus a router to send each upload to the right model. It would not raise the ultrasound accuracy. Public data is mostly older film scans, so a domain gap like the one measured for ultrasound is likely. It was recorded in the README backlog and deferred until the core modules are finished.",
])

# ================================================================== 9 DEPLOYMENT
H1("9. Deployment and demo build")
H2("9.1 Hosting options considered")
table(["Option", "Outcome"], [
    ["Hugging Face Docker Space", "Attempted with the prepared Docker files. The service refused (HTTP 402): Docker Spaces on free hardware now require a PRO subscription. Not used."],
    ["Vercel", "Judged unsuitable: serverless functions have tight size (about 250 MB), request-body (about 4.5 MB) and time limits, and would reload the models on every cold start. Limits should be checked against current Vercel documentation."],
    ["Railway, Render, Cloud Run", "Not evaluated in depth. The Docker files work on any of them; free allowances differ and must be checked."],
    ["**PC + free Cloudflare quick tunnel (chosen)**", "Free, HTTPS, no host account. Works only while the PC is on, and the address changes on each start."],
], [4.6, 12.0], caption="Where the backend can run")
H2("9.2 Demo procedure")
bullets([
    "Run scripts\\start_demo.ps1. It starts the backend and the tunnel, waits until the new tunnel name is visible in DNS, checks /health and prints the public address.",
    "In the app, long-press the header, choose Server address, paste the address and save.",
    "Keep the PC awake during the demo. Do not type or paste anything in the script window: pressing Enter there stops the server and the tunnel, and the address must be pasted into the phone app instead.",
])
para("**Lesson from the first phone run (20 September 2026).** The first attempt failed because the address was pasted into the script window's \"press Enter to stop\" prompt, "
     "which shut the server and tunnel down (and the emulator default address was typed instead of the tunnel address). After restarting the script and pasting the new address into the app, the app connected and worked. "
     "The script's stop prompt now says clearly not to type or paste there, and a harmless clean-up error message about the temporary log file (caused by the short Windows temp path) was removed.")
H2("9.3 Build environment and workarounds")
table(["Item", "Detail"], [
    ["Development PC", "Windows 11, 8 GB RAM, little free space on C:, so Flutter, JDK, Android SDK, Gradle cache and package cache live on D:"],
    ["Backend runtime", "Python 3.12; fastapi 0.141.1, uvicorn 0.53.0, xgboost 3.4.1 (xgboost-cpu in Docker), numpy 2.5.3, onnxruntime 1.30.0, pillow 12.3.0, python-multipart 0.0.32"],
    ["Training", "Kaggle notebooks (GPU: Tesla T4). Library versions are those of Kaggle's image at run time"],
    ["Gradle memory", "The project asks for an 8 GB heap, which crashed the build on this PC. Lower limits (1.5 GB heap) and Kotlin incremental compilation off were set in the user-level Gradle file only, without changing project files"],
    ["Docker files", "backend/Dockerfile (python:3.12-slim, libgomp for xgboost, non-root user, port 7860) and pinned requirements-space.txt. Booting the app from a clean environment on port 7860 was verified; Docker itself is not installed on the PC, so the image was not built locally"],
], [3.6, 13.0], caption="Environment", size=8.5)
H2("9.4 APK builds")
table(["Build", "Source state", "Result"], [
    ["1 (20 Sep 2026)", "Commit 6479090 (in-app server address setting added)", "app-release.apk, 19.0 MB (19,873,821 bytes), arm64-v8a, APK signature scheme v2 (debug key), SHA-256 starts 1e8848241c77dd1a. First build took about 13 minutes (cold Gradle cache)"],
    ["2 (20 Sep 2026)", "Commit 8b0caf7 (only the report, README and scripts changed since build 1)", "Same size, same SHA-256: the rebuild is byte-for-byte identical, which confirms the APK matches the current app code. Took under one minute (warm cache)"],
    ["3 (20 Sep 2026)", "Commit 8c5eb71 (AI companion, voice, health store, report)", "app-release.apk, 20.9 MB (21,892,133 bytes), arm64-v8a; adds the RECORD_AUDIO permission. A first attempt crashed the Gradle JVM for lack of memory on the 8 GB PC and succeeded when nothing else was running"],
    ["4 (20 Sep 2026)", "Commit 72ecf4b (Home wired to the health store, heavy-bleeding detector fix)", "app-release.apk, 20.9 MB (21,891,981 bytes), arm64-v8a, RECORD_AUDIO present; SHA-256 starts 2ef1b6e6094741c2. Two earlier attempts of this build were stopped by low memory on the 8 GB PC; it succeeded once other programs used less memory"],
], [3.0, 5.6, 8.0], caption="Release APK builds", size=8.5,
    note="Both builds pass apksigner verification and request INTERNET, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED and VIBRATE (build 3 also RECORD_AUDIO). The file is copied to the user's Desktop as femora-release-arm64.apk. Build 1 was installed and run on the developer's phone on 20 September 2026 (section 10).")

# ================================================================== 10 VERIFICATION
H1("10. Verification and testing")
table(["What", "How", "Result"], [
    ["Ultrasound end to end", "Demo scans and a real BUS-BRA scan through the API", "Benign demo: benign (96%); malignant demo: malignant (78%); real scan classified"],
    ["Wrong uploads", "Colour noise and a grayscale gradient", "Both refused with an explanatory message"],
    ["Threshold change", "Reran the model on all 710 test scans; first reproduced the notebook's 68.3% at 0.21", "Reproduced, then 71.8% at 0.25"],
    ["Risk questionnaire", "Eight profiles through the API", "Risk rises with each added factor; no placeholder warning"],
    ["Flutter tests", "Breast flows, PCOS flow, server-address logic, health store, chat state, companion screen with a fake microphone, onboarding and app launch, report builder", "54 of 54 pass; flutter analyze reports no errors or warnings"],
    ["Companion backend tests", "backend/tests/test_companion.py: safety detector, language detection, prompt building, request validation, rate limit, speech clean-up, fallback (Gemini calls are faked)", "50 of 50 pass"],
    ["Live Gemini check", "Real calls with the developer's key against the running backend: English and Urdu chat with personal context, emergency and breast-lump wording, a prompt-injection attempt, Urdu speech to text, text to speech, both models, both demo scans and a colour photo", "Chat 1.5 to 3 s, speech synthesis 4 to 6 s; Urdu speech transcribed in Urdu script after a stricter prompt and an automatic retry"],
    ["Notebooks", "Every Kaggle notebook was run first as a tiny smoke test, then in full", "All stages ran; ONNX parity checks passed"],
    ["Backend boot", "Clean environment, pinned requirements, port 7860", "/health, scan, risk and /docs all answered"],
    ["Tunnel", "Script self-test", "Public HTTPS address reached the backend"],
    ["Release APK", "Signature and permission check; second build compared by checksum", "Verified; internet permission present; rebuild identical to the first build"],
    ["Updated ultrasound gate", "Held-out sets through the gate offline, then demo scans, real web images and the kit scans (with damage) through the API", "Breast scans still pass (0.3% wrongly refused); other-organ ultrasound refused; unseen organs only partly (43% to 60%)"],
    ["First run on a real phone","APK installed on the developer's phone; demo script started; tunnel address pasted into the in-app Server address dialog", "Connected and working, confirmed by the developer after one retry (see the lesson in section 9.2)"],
], [3.6, 7.2, 5.8], caption="Verification performed")
para("**Not verified:** the phone run was confirmed as working in general; each feature (both questionnaires, scan upload with the demo scans and a wrong image, heatmap toggle, self-exam reminder notification) was not itemised, "
     "so per-feature results on the phone are not yet recorded. The backend Docker image has not been built. The older template test (widget_test.dart) that used to fail was replaced by a real app-launch test (test/app_flow_test.dart).")
H2("10.1 Checking the ultrasound module on a phone")
para("A test kit of real held-out scans (never used in training) was prepared on the developer's Desktop (folder femora-test-scans, with a READ_ME_FIRST.txt). "
     "It is not stored in the repository because it contains dataset images whose terms require citation. The expected results below were computed with the same ONNX model, temperature and screening threshold the server uses; "
     "the phone's result may differ by a few points because the app's image picker can re-encode the picture.")
table(["Test file", "Real label", "Expected in the app"], [
    ["01_benign_BUS-BRA", "benign", "Likely Benign, about 84% (heatmap available)"],
    ["02_benign_BUS-BRA", "benign", "Likely Benign, about 93%"],
    ["03_benign_BUSI", "benign", "Likely Benign, about 91%"],
    ["04_malignant_BUS-BRA", "malignant", "Suspicious Finding, about 79%"],
    ["05_malignant_BUS-BRA", "malignant", "Suspicious Finding, about 91%"],
    ["06_malignant_BUSI", "malignant", "Suspicious Finding, about 93%"],
    ["07_normal_BUSI", "normal", "Likely Normal, about 91% (no heatmap)"],
    ["08_WRONG_colour_noise", "not an ultrasound", "Refused: looks like a colour photo or colour Doppler scan"],
    ["09_WRONG_grayscale_gradient", "not an ultrasound", "Refused: does not look like a breast ultrasound"],
], [5.2, 3.4, 8.0], caption="Phone test kit for the ultrasound module", size=8.5,
    note="The seven ultrasound scans were chosen because the model handles them correctly. Across the whole test set it still misses about one cancer in ten and flags about a third of non-cancer scans, so other scans can give a different answer without being a bug.")
para("**How to run the check:** (1) start the demo script and set the server address in the app; (2) copy the kit to the phone; (3) in the Breast tab choose Upload, then Choose from Gallery, and open each file in turn; "
     "(4) compare the title and percentage, check that the heatmap toggle appears for benign and malignant results only, that the guidance cards and the disclaimer show, and that the two wrong images are refused with a message; "
     "(5) also try the two built-in sample scans and an ordinary photo from the gallery (it should be refused).")
H2("10.2 Checking the two questionnaires on a phone")
para("A checklist file (femora-questionnaire-tests.txt, on the developer's Desktop) lists the exact answers to enter and the results the server gives. The expected values were produced by the running backend.")
table(["Test", "Answers to enter (in short)", "Expected result"], [
    ["PCOS P1", "24 y, 165 cm, 58 kg, regular cycles, no symptoms, exercises", "about 1%, Low, Healthy Habits"],
    ["PCOS P2", "P1 plus acne", "about 1%, Low, tag Acne"],
    ["PCOS P3", "P1 but irregular cycles, weight gain, 70 kg", "about 7%, Low, BMI 25.7"],
    ["PCOS P4", "irregular, weight gain, hair growth, skin darkening, acne, fast food, no exercise", "about 99%, High, See a Specialist"],
    ["PCOS P5", "P4 without waist and hip", "still about 99%, High"],
    ["Risk R1", "45 y, no risk factors", "0.33% a year, 0.99 x, Low"],
    ["Risk R2", "one close relative", "0.42%, 1.26 x, Low, Family History"],
    ["Risk R3", "two or more relatives", "0.49%, 1.47 x, Medium"],
    ["Risk R4", "two or more relatives, biopsy, density d", "0.67%, 2.02 x, Medium, three factors"],
    ["Risk R5", "60 y, post-menopausal", "0.62%, 1.04 x, Low"],
    ["Risk R6", "25 y", "0.23%, 0.83 x, Low, note about the 35 to 84 range"],
    ["Risk R7", "45 y plus breast lump", "risk unchanged; red flag Breast Lump, urgent, See a Doctor Within 2 Weeks"],
    ["Risk R8", "38 y plus nipple discharge", "red flag, soon (urgent only from age 50)"],
    ["Risk R9", "45 y plus breast pain only", "no red flag"],
], [2.6, 8.0, 6.0], caption="Phone test profiles for the questionnaires", size=8.5, first_bold=True,
    note="Form checks: unanswered required questions block submission; out-of-range numbers show their allowed range; with the server stopped the app shows \"Could not reach the Femora server\" and keeps the form open.")

# ================================================================== 11 LIMITS + ETHICS
H1("11. Limitations, ethics and risks")
H2("11.1 Failure modes and mitigations")
table(["Failure", "Consequence", "Mitigation today", "Still needed"], [
    ["Cancer missed by the ultrasound model (about 11% of malignant scans)", "False reassurance", "Low screening threshold; every result advises a doctor; disclaimer", "Clinical validation; clear wording that a benign result is not a clearance"],
    ["Benign scan flagged suspicious (about 36% of non-cancer scans)", "Worry, an unneeded visit", "Wording \"suspicious, get it checked\"; guidance says most findings prove benign", "Explain real-world prevalence in the app"],
    ["Wrong image uploaded", "Meaningless prediction", "Colour check and ultrasound gate (about 6% of unseen brain MRIs still pass)", "A stronger out-of-distribution check"],
    ["Ultrasound of another body part", "A breast verdict for a non-breast scan (observed once, before the gate update)", "Gate retrained with thyroid, fetal-head and kidney ultrasounds; unseen organs refused only about 43% to 60%", "More organs (liver, abdomen, carotid, obstetric) as gate negatives"],
    ["New scanner or hospital", "Lower accuracy than reported", "Trained on three hospitals and four scanners", "More local data; per-scanner monitoring"],
    ["Risk model on a different population", "Miscalibrated risk", "Relative-to-age wording", "Validation on local data"],
    ["Server unreachable", "No result", "Clear error messages, form stays open", "Real hosting; offline fallback"],
    ["User treats output as a diagnosis", "Harm from delay or overreaction", "Disclaimers on every result; onboarding states the limits", "Clinical review of the wording"],
    ["AI companion gives unsafe or wrong advice", "Harm, false reassurance", "Server-side red-flag detector, no-diagnosis and no-dose rules, short plain answers, offline rule-based fallback", "Review by a clinician; grounded knowledge base (section 13.8)"],
], [4.4, 3.2, 5.0, 4.0], caption="Failure modes", size=8.5)
H2("11.2 Ethical and legal points")
bullets([
    "**Not a medical device.** Femora offers awareness and risk information. Using it as a diagnostic tool would require clinical validation and regulatory approval that this project does not claim.",
    "**Bias and representation.** The ultrasound data comes from Egypt, Poland and Brazil and the risk data from the United States. None is from Pakistan, the intended users, so performance there is unknown. This is stated in the report and should be in the app's about screen.",
    "**Privacy.** Scans and answers are processed in memory and not stored server-side. Images travel to a server, so real deployment needs HTTPS, a trusted host, a privacy notice and user consent. The demo tunnel passes traffic through Cloudflare.",
    "**Data terms.** BUS-BRA requires citation; BCSC requires the funding citation and its redistribution terms are not spelled out, so the private Kaggle copy must not be made public without checking them.",
    "**Fairness of communication.** Results avoid diagnostic words, always recommend a doctor and present uncertainty (calibrated probabilities, honest accuracy).",
])
H2("11.3 Other limitations")
bullets([
    "**Test-set tuning.** The 0.25 threshold was chosen after seeing the test results.",
    "**Small subgroups.** BrEaST (35 test scans), the normal class (22 test scans) and U-Systems (a few scans) cannot support firm conclusions.",
    "**Demo hosting.** The tunnel exposes a development server; it is suitable for a demonstration, not for real users.",
    "**Scope.** About half of the scope, mainly cycle prediction, trend charts, accounts, pregnancy and hormonal insights, is not built.",
    "**Companion privacy.** The free Gemini tier may use submitted text to improve Google products; a paid key with a data-use opt-out is needed for real users (section 13.7).",
])

# ================================================================== 12 REMAINING
H1("12. Remaining work and recommended order")
table(["Order", "Item (scope ref.)", "What is needed"], [
    ["1", "Trend charts for the symptom and mood log (6.10)", "Basic saving is done (section 13); charts, sleep and stress inputs remain"],
    ["2", "Cycle tracking and prediction (6.2)", "Random Forest on the Fehring data, then an LSTM on the IEEE mcPHASES data; real calendar instead of hard-coded days"],
    ["3", "Companion improvements (6.7)", "Grounded knowledge base (retrieval from NIH, CDC and MedlinePlus text), a question-set evaluation, clinician review of wording, trend charts on Home"],
    ["4", "Accounts (6.1)", "Authentication and cloud backup; the first-launch profile itself is done"],
    ["5", "Pregnancy mode, reminders, hormonal insights (6.5, 6.8, 6.6)", "Pregnancy tracking and warning signs; period, ovulation, medication and hydration reminders; phase-specific insights"],
    ["6", "Report history (6.9)", "The one-tap report and the Home snapshot exist; saved report history and charts remain"],
    ["7", "Hardening", "Run on a real phone, real hosting with authentication, optional lesion-focused ultrasound model, mammography (future work)"],
], [1.5, 5.6, 9.5], caption="Suggested plan")

# ================================================================== 13 COMPANION
H1("13. AI companion, personal health store and health report")
para("This chapter covers the work added on 20 September 2026: a Gemini-based AI companion that understands and speaks Urdu and English, "
     "the on-device health store that connects every part of the app to it, first-launch onboarding, and a one-tap lab-style health report. "
     "All of it is in commits b098f85 (backend) and 8c5eb71 (app).")
H2("13.1 What the user gets")
bullets([
    "**Personal companion.** The AI tab greets the user by first name, lists what it knows (for example \"PCOS high 71%\", the last ultrasound, the last self-exam) and answers with that context.",
    "**Voice both ways.** The user taps the microphone, speaks in Urdu or English, taps again, and the question is transcribed, answered and read aloud. A speaker button on each answer reads it on demand, and read-aloud can be switched off.",
    "**Interconnected app.** PCOS results, ultrasound results (with the heatmap), risk-questionnaire results, the daily symptom and mood log and the self-exam date all save into one store on the phone; the companion and the report read from it. The Breast tab has Discuss with AI buttons that open the companion with the user's own result.",
    "**Onboarding.** On first launch: name, age, height, weight, areas of interest, language and a Personalise switch. Everything is optional and can be skipped or edited later.",
    "**One-tap report.** A separate feature (section 13.6) that makes a professional PDF from the same store.",
])
H2("13.2 Architecture")
table(["Part", "Where", "Job"], [
    ["Companion API", "backend/companion.py (router included by app.py)", "Endpoints /companion/status, /chat, /voice/transcribe, /voice/speak; safety detector; prompt building; rate limit; offline fallback"],
    ["Gemini models", "Google Generative Language REST API, key in backend/.env (git-ignored, docker-ignored)", "Chat and speech-to-text: gemini-3.1-flash-lite (backup gemini-3.6-flash); text-to-speech: gemini-3.1-flash-tts-preview, voice Kore"],
    ["Health store", "lib/models/health_store.dart", "Profile, latest PCOS, scan, risk, heatmap image and daily log kept in shared_preferences; builds the name-free context text"],
    ["Chat state", "lib/models/chat_state.dart", "Conversation, sending, retry, persistence, last nine turns as history"],
    ["Voice", "lib/services/voice_service.dart", "Recording (record package, WAV 16 kHz mono, 45 s cap) and playback (audioplayers); a fake device is used in tests"],
    ["Screens", "lib/screens/ai_companion_screen.dart, onboarding_screen.dart, report_screen.dart", "Chat UI, profile form, PDF preview and share"],
    ["Report builder", "lib/services/report_service.dart", "Builds the PDF with the pdf package; PdfPreview from the printing package shows, saves and prints it"],
], [3.0, 5.6, 8.0], caption="Companion architecture", size=8.5)
para("The API key never enters the app: the phone talks only to the Femora backend, which calls Gemini. The same pattern keeps the safety logic where the user cannot change it.")
H2("13.3 What happens when the user sends a message")
bullets([
    "**1.** The app packs the message, up to nine earlier turns (starting with a user turn), the language preference and, if Personalise is on, the name-free context text.",
    "**2.** The backend checks size limits (2,000 characters a message, 12 turns, 3,500 characters of context) and a per-IP rate limit, and returns a plain explanation with HTTP 413, 422 or 429 when a limit is hit.",
    "**3.** A deterministic red-flag detector, written in code and working in English, Roman Urdu and Urdu script, scans the message for emergencies (for example heavy bleeding, chest pain, a breast lump, thoughts of self-harm) and sets an urgency of none, soon or urgent. This does not depend on the model.",
    "**4.** The system prompt is built from fixed rules plus the user's context inside a delimited block (user_health_context) that the model is told to treat as data, not instructions.",
    "**5.** Gemini answers. If Gemini fails or times out the backup model is tried, and then a rule-based fallback reply is returned so the user always gets a safe answer.",
    "**6.** The server adds an urgent or soon note when the detector fired (for example calling Rescue 1122 in Pakistan) and returns reply, source (gemini or fallback), urgency and language.",
    "**7.** The app shows the answer; urgent answers are highlighted with \"Please get medical help\". If speaking is on, it requests /voice/speak and plays the audio.",
])
H2("13.4 Safety rules")
table(["Rule", "How it is enforced"], [
    ["Never diagnose; say likely, may, could", "System prompt; plus a doctor recommendation for anything serious"],
    ["No medicine doses or prescriptions", "System prompt rule"],
    ["Emergencies get a clear urgent message with Rescue 1122", "Server-side detector, independent of the model; tested in three languages"],
    ["Lumps and other breast symptoms are marked as needing a doctor soon", "Detector level soon, appended note"],
    ["Plain text, short answers, the user's language", "System prompt; text cleaned before speaking"],
    ["Instructions hidden in a message or in the context are ignored", "Delimited context block and a rule to treat it as data"],
    ["Cost and abuse control", "Length limits, turn limit, per-IP rate limit, audio limit of 3 MB, speech limit of 900 characters"],
    ["Works without Gemini", "Rule-based fallback answers common topics (PCOS, cycle, breast checks, emergencies)"],
], [7.0, 9.6], caption="Companion safety design", size=8.5)
H2("13.5 Voice: results from live tests")
table(["Step", "Model", "Measured", "Notes"], [
    ["Chat", "gemini-3.1-flash-lite", "about 1.5 to 3 s", "Chosen after gemini-2.5-flash turned out to be closed to new keys and gemini-3.8-flash gave 503 errors under load; gemini-3.6-flash is the backup"],
    ["Speech to text", "gemini-3.1-flash-lite (audio input)", "about 2 s", "English correct. Urdu was first returned in Devanagari script; a stricter prompt plus an automatic retry when Devanagari is detected fixed it, verified live"],
    ["Text to speech", "gemini-3.1-flash-tts-preview, voice Kore", "about 4 to 6 s", "Returns 24 kHz PCM that the server wraps as WAV; the answer text is cleaned (no symbols) before speaking"],
], [2.6, 4.2, 2.8, 7.0], caption="Voice pipeline", size=8.5,
    note="Each voice question therefore takes roughly 8 to 12 seconds end to end (transcribe, answer, speak). The answer text appears first, before the audio is ready. Urdu and English speech was checked with generated audio; recognition of real voices on a phone microphone should be tried on the day.")
H2("13.6 The health report generator")
para("The report is a separate feature (Companion menu, Health report) built to look like a diagnostic-laboratory report. It is Femora-branded, not modelled on any lab's branding, and it says on every page that it is an AI screening summary and not a laboratory or clinical record.")
table(["Section", "Content"], [
    ["Header", "femora wordmark, report ID (FEM-YYMMDD plus six characters derived from the profile), generation time"],
    ["Patient block", "Name, age and sex, height and weight, BMI, report date, interests, and a QR code carrying the report ID"],
    ["Summary of findings", "One line per completed test in plain words"],
    ["Panel 1: PCOS risk screening", "Probability with Low, Medium, High flag and the reference bands (below 30, 30 to 60, 60 and above), BMI against 18.5 to 24.9, the answers that raised the risk; interpretation and the tests a gynaecologist would use"],
    ["Panel 2: breast ultrasound AI screening", "Classification, confidence, class probabilities, the 25% flagging rule, the model's held-out accuracy, and the heatmap image"],
    ["Panel 3: breast cancer risk assessment", "One-year risk against the average for the age group, relative risk with Low, Medium, High, the answers that raised it, and symptoms needing a doctor"],
    ["Panel 4: self-exam and wellness log", "Last breast self-exam and recent symptom and mood entries"],
    ["Recommended next steps, clinician box, disclaimer", "Advice list, a box for a doctor's notes, and the awareness-only disclaimer"],
    ["Footer", "Report ID and page x of y on every page"],
], [5.0, 11.6], caption="Report layout (A4, multi-page)", size=8.5)
bullets([
    "**Sample mode.** A switch on the report screen builds a report from made-up data marked \"Sample Patient\" with a faint diagonal SAMPLE DATA watermark, for demonstrations without real data. A first version drew the watermark solid black over the text; the colour was changed to a very light pink and rechecked by rendering the PDF to images.",
    "**Empty state.** A report with no results is still valid and says which tests have not been done.",
    "**Characters.** The built-in PDF fonts only cover Latin text, so non-Latin text (for example an Urdu name) is replaced by a safe placeholder instead of failing; this is a known limit.",
    "**Sharing.** The preview screen offers save, print and share; the file name is Femora-Health-Report-date.pdf.",
])
H2("13.7 Privacy design")
bullets([
    "Everything the app knows is stored on the phone. The server keeps nothing.",
    "The user's name is never sent to Gemini; only a short summary such as \"PCOS screening (today): 71% = high risk\" is sent, and only if Personalise is on.",
    "Delete all my data (in the companion menu) clears the profile, results, log and conversation on the phone.",
    "**Caveat.** With a free Gemini key, Google may use submitted text to improve its products. A paid key with data-use opt-out (or an institutional agreement) is needed before real users are given the app.",
    "**Secrets.** The Gemini key lives only in backend/.env, which is excluded from Git and from the Docker build. The key and a Hugging Face token were pasted into a chat during development, so both should be revoked and replaced.",
])
H2("13.8 Would pretrained question datasets help?")
para("Question-and-answer datasets (for example medical exam or consumer-health question sets) do not improve a hosted model like Gemini through fine-tuning here: the model is not trained by the app. They are useful in two other ways. "
     "First, as an evaluation set: run several hundred questions through the companion and check the answers for safety and accuracy. Second, as a knowledge base for retrieval: split trusted public text (NIH, CDC, MedlinePlus) into passages, find the passages closest to the question and give them to the model so the answer is grounded and can cite a source. "
     "Both are recorded as the next step for the companion; neither is built yet.")
H2("13.9 Tests")
table(["Suite", "Count", "What it covers"], [
    ["backend/tests/test_companion.py", "50", "Red-flag detector in three languages, language detection, prompt construction and injection wording, request limits, rate limit, speech clean-up, PCM to WAV, fallback replies, endpoints with a faked Gemini"],
    ["test/health_store_test.dart", "part of 44 new", "Saving and loading, one log entry a day and a 60-entry cap, name-free context text, clear-all"],
    ["test/chat_state_test.dart", "part of 44 new", "History rules, personalisation switch, retry of an unanswered message, persistence"],
    ["test/companion_flow_test.dart", "part of 44 new", "Typing indicator, suggestion chips, failed message and Try again, urgent highlight, full voice flow with a fake microphone, missing permission, speaker button, Delete all my data"],
    ["test/app_flow_test.dart", "part of 44 new", "First launch shows onboarding, skipping is remembered, form validation, editing a saved profile"],
    ["test/home_flow_test.dart", "part of 44 new", "Home shows the real name and only real results, empty state, rows open the right tab, next-step rules, relative dates"],
    ["test/report_service_test.dart", "part of 44 new", "Empty, sample and full reports build as valid PDFs; long logs spill onto more pages; report IDs"],
], [5.6, 2.6, 8.4], caption="New tests", size=8.5,
    note="All 54 Flutter tests (10 earlier plus 44 new) and all 50 backend tests pass. The companion screen's real speech recognition and the real microphone are not covered by automatic tests because they need a phone.")
H2("13.10 Defects found while building, and their fixes")
table(["Problem", "Fix"], [
    ["A coloured card containing a switch tile threw a Material assertion (real UI bug caught by a test)", "Wrapped the tile in a transparent Material"],
    ["A breast lump was rated no urgency", "Added a soon level and mapped lumps and discharge to it"],
    ["Urdu speech was transcribed in Devanagari", "Stricter prompt and automatic retry"],
    ["Report watermark covered the text", "Much lighter colour"],
    ["The mock chat and a fake pre-selected symptom were still in the app", "Removed; the chat is real and symptoms start empty"],
    ["Home tab greeted every user as Ayesha and showed a fake cycle day, stress, sleep and insight (found while checking the app in Chrome)", "Home rewritten to read the health store; fake values removed; six new tests"],
    ["The emergency detector missed \"mujhe bohat zyada bleeding ho rahi hai aur chakkar aa rahe hain\" (found by the live check; the model advised a doctor, but no urgent flag was set)", "A bleeding word together with an intensity word (heavy, a lot, bohat, zyada, Urdu equivalents) now counts as an emergency; four new tests"],
    ["An older backend process was still running on port 8000 without the companion (found while starting the check)", "Killed and restarted; the demo script and README stress restarting the server after updates"],
], [8.0, 8.6], caption="Issues and fixes", size=8.5)

# ================================================================== 14 CONCLUSION
H1("14. Conclusion")
para("The breast module now consists of two models backed by measured evidence and an honest account of their limits. The most valuable result of this "
     "period was not a higher accuracy figure but a truthful one: testing on a hospital the model had never seen exposed a large gap, adding the right data "
     "closed most of it, and a further experiment that did not help was documented and rejected. The app can be shown on a phone today and now includes a voice-enabled, personalised AI companion and a one-tap "
     "health report. About half of the scope, mainly cycle prediction, trend charts, accounts, pregnancy and hormonal insights, remains to be built.")

# ================================================================== APPENDICES
H1("Appendix A. Metric glossary", new_page=True)
table(["Term", "Meaning"], [
    ["Accuracy", "Share of scans given the right class. Misleading when one class is rare."],
    ["Sensitivity, recall (cancers caught)", "Of the truly malignant scans, the share flagged suspicious."],
    ["Specificity (non-cancer cleared)", "Of the scans that are not malignant, the share not flagged."],
    ["Precision", "Of the scans flagged malignant, the share that truly are."],
    ["F1, macro-F1", "Balance of precision and recall; macro averages the classes equally."],
    ["AUC", "The chance that a random malignant scan scores higher than a random non-malignant one (0.5 = coin flip, 1.0 = perfect). Independent of any threshold."],
    ["Calibration, ECE", "Whether predicted probabilities match reality; the expected calibration error is the average gap."],
    ["Expected / observed", "Predicted number of cancers divided by the number that occurred (risk model)."],
    ["Brier score", "Mean squared error of the predicted probabilities (lower is better)."],
    ["Threshold", "The malignancy probability at or above which a scan is flagged suspicious."],
    ["Held-out / external test", "Data the model never trained on; external means from a different hospital."],
    ["Patient-level split", "All images of one patient go to the same split so the model cannot memorise a person."],
    ["Transfer learning, fine-tuning", "Starting from a network trained on millions of everyday photos and adjusting it to ultrasound."],
    ["SHAP", "A way to split a prediction into the contribution of each answer."],
    ["SMOTE", "Creating synthetic examples of the rare class to balance training data."],
    ["Monotonic constraint", "A rule that a feature can only push the prediction one way."],
    ["ONNX", "A portable file format for trained networks, run here with ONNX Runtime."],
    ["Class activation map (heatmap)", "A picture of which image regions raised the score of a class."],
], [4.6, 12.0], caption="Terms used in this report", size=8.5)

H1("Appendix B. Reproducibility")
table(["Item", "Where"], [
    ["Repository", "github.com/ammad-sajjad/Femora (branch main)"],
    ["Notebook builder", "ml/build_notebooks.py (writes the Kaggle notebooks to ml/notebooks/; cells for the PCOS, ultrasound, BUS-BRA, BUS-UCLM and risk notebooks)"],
    ["Pinned splits", "ml/v7_split.csv (BUSI + BrEaST from v7), ml/busbra_split.csv (all three datasets)"],
    ["Kaggle notebooks", "femora-pcos-risk-xgboost; femora-breast-ultrasound-resnet50 (v6, v7); femora-breast-ultrasound-resnet50-busbra (deployed); femora-breast-ultrasound-resnet50-uclm (experiment); femora-breast-risk-xgboost (deployed)"],
    ["Kaggle dataset", "ammad0/bcsc-risk-estimation (private copy of BCSC risk.txt)"],
    ["Backend", "backend/app.py, backend/models/, backend/Dockerfile, backend/requirements-space.txt"],
    ["Demo", "scripts/start_demo.ps1 (server + tunnel), README section \"Demo on a phone\""],
    ["Gate retraining", "ml/train_gate_v2.py (runs on the CPU; datasets in D:/dl/gate; set GATE_FINAL=1 for the deployed version). Embedding caches and outputs are in ml/output/gate_v2 and are not committed; the previous gate is kept there as breast_gate_previous.npz"],
    ["This report", "scripts/build_report.py (numbers are read from the model metadata files)"],
], [4.0, 12.6], caption="Where things are")
para("To rebuild a model: run ml/build_notebooks.py, push the notebook with the Kaggle command line, download its output, and copy the model files into backend/models/ "
     "(details in the README). To run the backend: uvicorn app:app from the backend folder; the app then connects to it.")

H1("Appendix C. Data sources and citations")
bullets([
    "Al-Dhabyani W. et al. Dataset of breast ultrasound images. Data in Brief, 2020 (BUSI).",
    "Pawłowska A. et al. BrEaST-Lesions-USG. The Cancer Imaging Archive, 2024 (CC BY 4.0).",
    "Gómez-Flores W., Gregorio-Calas M.J., Pereira W.C.A. BUS-BRA: a breast ultrasound dataset for assessing computer-aided diagnosis systems. Medical Physics 51, 2024.",
    "Vallez N. et al. BUS-UCLM: breast ultrasound lesion segmentation dataset. Scientific Data, 2025 (CC BY 4.0).",
    "Breast Cancer Surveillance Consortium Risk Estimation Dataset (Barlow et al., JNCI 2006). Required statement: \"Data collection and sharing was supported by the National Cancer Institute-funded Breast Cancer Surveillance Consortium (HHSN261201100031C).\"",
    "Kottarathil P. Polycystic ovary syndrome (PCOS) dataset, Kaggle.",
    "Gate training and testing only (no model file contains these images): DDTI thyroid ultrasound (Kaggle dasmehdixtr/ddti-thyroid-ultrasound-images); Algerian thyroid ultrasound AUITD (azouzmaroua); fetal head ultrasound (ankit8467); kidney ultrasound with and without stones (gurjeetkaurmangat); Natural Images (prasunroy); COVID-19 chest X-ray train and test sets (khoongweihao); brain MRI (navoneel). Their licences were not individually checked, so they are used only locally for this experiment.",
    "Wolberg W. et al. Breast Cancer Wisconsin (Diagnostic) dataset, UCI Machine Learning Repository, 1993 (comparison only).",
    "He K. et al. Deep Residual Learning for Image Recognition (ResNet), CVPR 2016. Chen T., Guestrin C. XGBoost, KDD 2016. Chawla N. et al. SMOTE, JAIR 2002. Lundberg S., Lee S. SHAP, NeurIPS 2017. Guo C. et al. On Calibration of Modern Neural Networks (temperature scaling), ICML 2017.",
])

H1("Appendix D. Key decisions and why")
table(["Decision", "Reason"], [
    ["Keep v7 untouched; each experiment in its own Kaggle notebook", "Clean comparison and a one-file rollback"],
    ["Pin the old test split and split BUS-BRA by patient", "Comparable numbers; no patient or copy leaks into the test set"],
    ["Deploy the BUS-BRA model, not the UCLM model", "Measured gain on unseen patients; UCLM gave none and missed more cancers"],
    ["Exclude marked and Doppler UCLM images", "On-screen marks would leak the lesion label"],
    ["Screening threshold 0.25", "Fewer false alarms for one percentage point of sensitivity; disclosed as chosen after seeing the test set"],
    ["BCSC instead of Wisconsin for the questionnaire", "A questionnaire needs inputs a user can self-report"],
    ["Age excluded from the PCOS model", "The narrow age range let the model learn a spurious rule"],
    ["Mammography deferred", "Different modality needing a new model; recorded as future work"],
    ["Free tunnel instead of paid hosting", "Hugging Face Docker Spaces require PRO; Vercel unsuitable"],
    ["Retrain only the gate, with other-organ ultrasounds", "A non-breast ultrasound passed the old gate; changing only the gate leaves every classification unchanged. Kept the honest unseen-organ estimate (43% to 60% refused) separate from the deployed version's scores"],
    ["In-app server address setting", "The free tunnel address changes on each start"],
    ["Call Gemini from the backend, never from the app", "An API key inside an APK can be extracted; the backend also holds the safety rules and rate limit"],
    ["gemini-3.1-flash-lite for chat and speech recognition", "Fastest model available to a new key (1.5 to 3 s); 2.5-flash was closed to new users and 3.8-flash returned 503 under load; 3.6-flash kept as backup"],
    ["Red flags detected in code, not by the model", "Emergency handling must not depend on a model's judgement; it also works when Gemini is down"],
    ["Send a name-free summary to the model", "The model does not need identity to be helpful; limits what leaves the phone"],
    ["Store everything on the phone", "No accounts or server database needed for a demonstration; the user can erase it all"],
    ["Report as a separate PDF feature with a sample mode", "Shows the whole app connected in one page and can be demonstrated without real data"],
    ["Retrieval and evaluation, not fine-tuning, for question datasets", "A hosted model cannot be fine-tuned by the app; datasets are more useful to test answers and to ground them in trusted text"],
], [7.4, 9.2], caption="Decision log")

H1("Appendix E. Commit history (main branch)")
table(["Commit", "Date", "Change"], [
    ["9f369f5", "19 Sep 2026", "Add breast health module: ultrasound CNN, risk questionnaire, self-exam"],
    ["0654525", "19 Sep 2026", "Document breast module status and next steps in README"],
    ["f40904a", "19 Sep 2026", "Add BUS-BRA breast ultrasound model and multi-scanner evaluation"],
    ["88b30f7", "20 Sep 2026", "Add BUS-UCLM experiment notebook (not deployed) and record result"],
    ["e8eea4a", "20 Sep 2026", "Set breast screening threshold to 0.25 and refresh demo scan"],
    ["238b7ea", "20 Sep 2026", "Train breast risk questionnaire model on real BCSC data"],
    ["ce35151", "20 Sep 2026", "Add Hugging Face Space (Docker) files for the backend"],
    ["6479090", "20 Sep 2026", "Add in-app server address setting and free-tunnel demo script"],
    ["8ca482f", "20 Sep 2026", "Fix tunnel path in README"],
    ["8b0caf7", "20 Sep 2026", "Add detailed project progress and technical report (Word)"],
    ["493889f", "20 Sep 2026", "Update report: APK builds, verification and panel questions"],
    ["70fd06a", "20 Sep 2026", "Record first real-phone run; clearer demo script prompt"],
    ["79c81f6, 2397213, 0249b7b", "20 Sep 2026", "Report: phone test plans (ultrasound, questionnaires) and the informal web-image check"],
    ["f168378", "20 Sep 2026", "Retrain the ultrasound gate to refuse other-organ ultrasounds (ml/train_gate_v2.py, new breast_gate.npz and metadata)"],
    ["b098f85", "20 Sep 2026", "Add AI companion backend: Gemini chat, voice in and out, safety rules"],
    ["8c5eb71", "20 Sep 2026", "Add AI companion app: onboarding, on-device health store, chat with voice, one-tap lab-style report"],
], [2.4, 3.0, 11.2], caption="Commits made during this period")

H1("Appendix F. Questions a panel may ask")
qa = [
    ("Q1. Why does the app need a server? Why not run the models on the phone?",
     "The ultrasound network is 47 MB and the questionnaire models use Python libraries (XGBoost, SHAP explanations). Keeping them on a server lets us update a model without shipping a new APK and keeps the app small. The cost is that a connection is needed and images leave the phone. Running an ONNX model on the device is possible and is listed as a future option."),
    ("Q2. Why ResNet50?",
     "It is the model named in the scope, it transfers well from ImageNet to small medical datasets, and its final layers (global average pooling plus one linear layer) make class activation maps exact. It exports cleanly to ONNX. A stronger network might add a point of AUC at most on this amount of data."),
    ("Q3. Why 224 × 224? Do small lesions get lost?",
     "224 is ResNet50's standard input and keeps training and serving fast. Small lesions can lose detail after resizing; a lesion-focused two-step model (find the lesion, then classify the crop) is the most promising future improvement."),
    ("Q4. The accuracy is only 72%. Why?",
     "Three reasons. The task is hard even for radiologists. The test set is mostly scans from a hospital and scanners the model never saw. And the deployed threshold favours catching cancers: with a neutral decision rule the same model scores 80.4%. The threshold-free AUC is 0.87. Very high published numbers on these datasets often come from splits where the same patient or copies of an image appear in both train and test; ours does not."),
    ("Q5. Did you tune on the test set?",
     "No for the model: training, recipe selection and calibration used only training and validation data (with out-of-fold predictions). The one exception is disclosed: the final threshold 0.25 was chosen after seeing test results, as a trade-off, and the notebook's own value (0.21) is also reported."),
    ("Q6. How do you know the model works on new hospitals?",
     "We tested it that way. Version 7 was run on 1,875 BUS-BRA scans it had never seen and scored AUC 0.73. The final model was trained with part of BUS-BRA and tested on other BUS-BRA patients (AUC 0.87). A truly new hospital would probably score somewhat lower, as the BrEaST results (AUC 0.65 on 35 scans) suggest."),
    ("Q7. How do you prevent data leakage?",
     "Near-duplicate images are grouped by a perceptual hash and kept in one split; BUS-BRA is split by patient (both breasts together); lesion masks are never used as training images; the old test set is pinned so old and new models are scored on the same scans; a pre-augmented dataset and marked UCLM images were rejected."),
    ("Q8. What does calibration mean and how did you do it?",
     "A calibrated model's 80% confidence is right about 80% of the time. We fitted one temperature (1.14) on out-of-fold predictions and divide the logits by it; the expected calibration error on the test set fell from 0.0385 to 0.0289."),
    ("Q9. What if someone uploads a photo or an X-ray?",
     "A colour check refuses colour images and Doppler scans, and an ultrasound gate refuses grayscale non-ultrasounds. Held-out tests of the updated gate: 99% of unseen photos, 100% of chest X-rays and 99% of brain MRIs are refused, as are 92% to 100% of other-organ ultrasounds it was trained on (thyroid, fetal head, kidney); only 0.3% of real breast test ultrasounds are wrongly refused. Ultrasounds of organs it has never seen are refused only about 43% to 60% of the time, so some wrong images can still pass."),
    ("Q10. Is this a medical diagnosis?",
     "No. Femora provides awareness and risk information, says so on every result, and always recommends seeing a doctor. It would need clinical validation and regulatory approval to be used as a diagnostic tool."),
    ("Q11. What data does the app store?",
     "On the phone: the profile, the latest PCOS, ultrasound and risk results, the daily log, the chat history, the date of the last self-exam, the reminder switch and the server address (all in app storage). On the server: nothing is stored. When the user chats, a short name-free summary and the message go to Google Gemini through the backend; this can be switched off (Personalise) and everything can be erased with Delete all my data."),
    ("Q12. Is the demo connection secure?",
     "The tunnel uses HTTPS, but Cloudflare terminates it and could see the traffic, so it is suitable for a demo only. The server also has no authentication and allows any origin. A real launch needs a trusted host, authentication, rate limiting and a privacy notice."),
    ("Q13. Why is XGBoost used for PCOS when it is not the best model in cross-validation?",
     "On the self-reported features logistic regression, random forest and XGBoost are statistically tied (AUC 0.87 to 0.88). XGBoost is named in the scope, supports monotonic constraints (a symptom can never lower the risk) and gives per-answer explanations."),
    ("Q14. Why is age not used in the PCOS model?",
     "Every woman in the dataset is 20 to 48 and patients were only about two years younger, so the model learned a spurious rule that younger means higher risk. That would not hold for app users."),
    ("Q15. Why SMOTE, and could it leak?",
     "The PCOS data has fewer positives than negatives. SMOTE is applied only to training rows, and inside each cross-validation fold, so synthetic copies never appear in a test fold."),
    ("Q16. Why is the risk model's AUC only 0.64?",
     "Risk factors cannot separate people who will and will not develop cancer; published risk models score about 0.6 to 0.7. Its value is calibration: predicted and observed cancers agree (ratio 1.01), and women in the medium band really had 1.9 times the average risk."),
    ("Q17. Why BCSC instead of the Wisconsin dataset in the scope?",
     "Wisconsin's inputs are cell measurements from a biopsy, which a user cannot self-report. BCSC has exactly the questions a woman can answer. We still trained a Wisconsin model (96.5% accuracy) to show the comparison."),
    ("Q18. How are the risk bands defined?",
     "As a multiple of the average risk for the woman's age group, using NICE familial-risk categories: low below 1.35, medium 1.35 to 2.4, high above 2.4. Age alone therefore never makes someone high risk."),
    ("Q19. What do the factor tags mean?",
     "They come from SHAP values: for each answer, how much it pushed this woman's prediction up. Answers above 0.05 (log-odds) are named, at most three."),
    ("Q20. Why did BUS-UCLM not help?",
     "It has only 38 patients and mostly normal scans, and its marked and Doppler images had to be excluded. The AUC did not change and the fitted threshold drifted, so the model caught fewer cancers. We kept the earlier model."),
    ("Q21. Would this work for Pakistani women?",
     "Unknown. The scan data is from Egypt, Poland and Brazil and the risk data from the United States. Validating on local hospital data is the most important next step before real use."),
    ("Q22. Are the results reproducible?",
     "Yes: seed 42, pinned split files, notebooks generated from one script, and model files with metadata are in the repository. Every reported number is read from those files."),
    ("Q23. How fast is a scan analysed?",
     "The model call takes about 95 ms on a laptop CPU. The upload dominates the total time, and the app allows up to 45 seconds."),
    ("Q24. How would you deploy this for real users?",
     "Package the backend in Docker (files are ready), host it on a paid or institutional service with HTTPS, add authentication and rate limits, restrict CORS, log without storing images, and monitor performance. Then validate on local data."),
    ("Q25. What would you do with more time?",
     "Build the missing modules (cycle prediction, trend charts, accounts, pregnancy mode), add a grounded knowledge base to the companion, try a lesion-focused two-step ultrasound model, collect local scans, add mammography, and consider on-device inference."),
    ("Q26. Which phones can run the APK?",
     "The release build targets 64-bit ARM Android phones (arm64-v8a), which covers nearly all phones made in recent years, and uses Flutter's default minimum Android version. A phone that only supports 32-bit ARM would need a different build. It is 19 MB and is installed directly (not through the Play Store), so Android asks to allow installs from unknown sources."),
    ("Q27. Is the APK build reproducible?",
     "Yes in practice: a second build from the same source produced a byte-for-byte identical file (same SHA-256), so the APK on the phone matches the code in the repository."),
    ("Q28. What is not finished?",
     "About half of the scope: cycle prediction, trend charts, accounts and login, pregnancy mode, hormonal insights and most reminders. Section 12 gives the plan."),
    ("Q29. Will it work on ultrasound images downloaded from the internet?",
     "Often, with limits. In an informal check, compression, low resolution and annotation marks did not change the answer on 7 of 7 test scans; colour-tinted images were refused; a real carcinoma image was flagged (93%), a real fibroadenoma image was a false alarm (66% malignant), and a generic non-breast ultrasound was wrongly accepted. Two images cannot measure accuracy, so web images should be used only for demonstrations (section 6.13)."),
    ("Q30. How does the AI companion know about me?",
     "Every result (PCOS, ultrasound, risk questionnaire) and daily log entry is saved in a store on the phone. When you chat, the app sends a short name-free summary of that store with your question, if Personalise is on. The model uses it to answer about your situation. Switch it off, or delete all data, in the companion menu."),
    ("Q31. Can the AI give dangerous advice?",
     "It is instructed never to diagnose or give doses, and emergencies are caught by code on the server, not left to the model: they always get an urgent message and Rescue 1122. If Gemini is unavailable a rule-based reply is used. It can still be wrong, so every answer points to a doctor, and clinician review of the wording is listed as future work."),
    ("Q32. Does it really understand Urdu speech?",
     "Yes, in our tests: Gemini transcribed Urdu speech correctly once we required Urdu script (it first returned Devanagari, so the server retries automatically). Real phone microphones and accents should be tested before the demo."),
    ("Q33. Where does my voice and data go?",
     "The phone sends the recording or text to the Femora backend, which forwards it to Google's Gemini service and returns the answer. Nothing is stored by Femora. With a free Gemini key Google may use the text to improve its products, so a paid key with opt-out would be used for real users."),
    ("Q34. Is the report a real medical report?",
     "No. It copies the layout of a lab report (panels, reference ranges, flags, report number) for readability but says on every page that it is an AI screening summary. It carries Femora branding only, and demo reports are watermarked SAMPLE DATA."),
    ("Q35. Would millions of medical questions make the companion better?",
     "Not by training, because the model is hosted by Google. They are valuable to test the companion at scale and, as trusted text, to retrieve passages that ground its answers. Both are planned, neither is built."),
]
table(["Question", "Answer"], [[q, a] for q, a in qa], [5.4, 11.2], caption="Anticipated questions", size=8.5, first_bold=True)

OUT.parent.mkdir(exist_ok=True)
doc.save(str(OUT))
print("saved", OUT)
