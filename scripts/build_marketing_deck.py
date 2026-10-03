"""
Build the 27-slide Widescreen (16:9) Product & Marketing Presentation Deck for Femora.
Recreates the exact structure, caliber, visual hierarchy and presentation style of Leadway CRM.pdf,
tailored specifically to Femora with real high-resolution screenshots.
"""

import os
import sys
import base64
import subprocess
from pathlib import Path

# Paths
ROOT = Path(r"C:\Users\am0ff\Femora")
DESIGN_DIR = Path(r"C:\Users\am0ff\Downloads\Femora Design")
ASSETS_DIR = ROOT / "assets" / "images"
SCRATCH_DIR = ROOT / "scratch"
SCRATCH_DIR.mkdir(exist_ok=True)

HTML_OUT = SCRATCH_DIR / "femora_marketing_deck.html"
PDF_OUT = ROOT / "scope doument" / "Femora - Product & Marketing Presentation Deck.pdf"
DESKTOP_PDF = Path(r"C:\Users\am0ff\Desktop\Femora - Marketing Deck.pdf")

def b64(path):
    with open(path, "rb") as f:
        data = base64.b64encode(f.read()).decode("utf-8")
    ext = path.suffix.lower().replace(".", "")
    if ext == "jpg": ext = "jpeg"
    return f"data:image/{ext};base64,{data}"

# Load screenshots
img_logo = b64(ASSETS_DIR / "app_logo_master.png")
img_home = b64(DESIGN_DIR / "HOME.png")
img_calendar = b64(DESIGN_DIR / "CALENDER.png")
img_breast = b64(DESIGN_DIR / "BREAST CANCER.png")
img_pcos_assess = b64(DESIGN_DIR / "PCOS RISK ASSESSMENT.png")
img_pcos_risk = b64(DESIGN_DIR / "PCOS RISK.png")
img_report = b64(DESIGN_DIR / "EXPLAIN MY REPORT.png")
img_companion = b64(DESIGN_DIR / "AI COMPANION.png")
img_doctors = b64(DESIGN_DIR / "DOCTORS DIRECTORY.png")
img_profile = b64(DESIGN_DIR / "DOCTORS PROFILE.png")
img_hospitals = b64(DESIGN_DIR / "HOSPITALS NEARBY.png")
img_login = b64(DESIGN_DIR / "LOGIN PAGE.png")
img_doctor_qr = b64(DESIGN_DIR / "SHOW DOCTOR MY REPORT.png")

# CSS styles
CSS = """
@page {
  size: 960pt 540pt;
  margin: 0;
}
* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}
body {
  font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, 'Inter', Roboto, sans-serif;
  color: #1E293B;
  background: #000;
  -webkit-print-color-adjust: exact;
  print-color-adjust: exact;
}

.slide {
  width: 960pt;
  height: 540pt;
  position: relative;
  page-break-after: always;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding: 42pt 52pt 28pt 52pt;
}

/* ── COLOR THEMES ── */
.slide.dark {
  background: radial-gradient(circle at 80% 20%, #2A081D 0%, #15030F 60%, #0D0209 100%);
  color: #FFFFFF;
}
.slide.light {
  background: #FBF8FA;
  color: #181114;
}

/* ── TYPOGRAPHY ── */
.kicker {
  font-size: 8.5pt;
  font-weight: 800;
  letter-spacing: 1.8pt;
  text-transform: uppercase;
  margin-bottom: 10pt;
}
.dark .kicker { color: #FDA4AF; }
.light .kicker { color: #9D174D; }

.badge-tag {
  display: inline-block;
  padding: 3pt 8pt;
  border-radius: 12pt;
  font-size: 7.5pt;
  font-weight: 700;
  letter-spacing: 1pt;
  text-transform: uppercase;
  margin-right: 6pt;
}
.dark .badge-tag { background: #3B0D27; color: #FDA4AF; border: 1px solid #621541; }
.light .badge-tag { background: #FCE7F3; color: #9D174D; border: 1px solid #FBCFE8; }

h1.headline {
  font-size: 34pt;
  font-weight: 900;
  line-height: 1.12;
  letter-spacing: -0.8pt;
  margin-bottom: 12pt;
  max-width: 580pt;
}
.dark h1.headline { color: #FFFFFF; }
.light h1.headline { color: #0F172A; }

.highlight-gold { color: #FBBF24; }
.highlight-rose { color: #FB7185; }

p.subtext {
  font-size: 11pt;
  line-height: 1.48;
  max-width: 480pt;
  margin-bottom: 22pt;
}
.dark p.subtext { color: #CBD5E1; }
.light p.subtext { color: #64748B; }

/* ── NUMBERED POINTS ── */
.points-list {
  display: flex;
  flex-direction: column;
  gap: 14pt;
  max-width: 380pt;
}
.point-item {
  display: flex;
  align-items: flex-start;
  gap: 12pt;
}
.point-num {
  width: 24pt;
  height: 24pt;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 9pt;
  font-weight: 800;
  flex-shrink: 0;
}
.dark .point-num { background: #2E0B20; color: #FDA4AF; border: 1px solid #58183E; }
.light .point-num { background: #FCE7F3; color: #9D174D; border: 1px solid #FBCFE8; }

.point-text h3 {
  font-size: 11.5pt;
  font-weight: 800;
  margin-bottom: 3pt;
}
.dark .point-text h3 { color: #FFFFFF; }
.light .point-text h3 { color: #0F172A; }

.point-text p {
  font-size: 9.2pt;
  line-height: 1.38;
}
.dark .point-text p { color: #94A3B8; }
.light .point-text p { color: #64748B; }

/* ── DEVICE MOCKUPS ── */
.phone-frame {
  width: 215pt;
  height: 410pt;
  background: #000;
  border-radius: 30pt;
  border: 7pt solid #18181B;
  box-shadow: 0 25pt 50pt -12pt rgba(0, 0, 0, 0.45), 0 0 0 1px rgba(255, 255, 255, 0.1);
  overflow: hidden;
  position: relative;
  flex-shrink: 0;
}
.phone-frame::before {
  content: '';
  position: absolute;
  top: 6pt;
  left: 50%;
  transform: translateX(-50%);
  width: 55pt;
  height: 11pt;
  background: #000;
  border-radius: 8pt;
  z-index: 20;
}
.phone-screen {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

/* Browser mockup */
.browser-frame {
  width: 380pt;
  height: 380pt;
  background: #FFFFFF;
  border-radius: 12pt;
  box-shadow: 0 20pt 45pt -10pt rgba(0, 0, 0, 0.25), 0 0 0 1px rgba(0,0,0,0.06);
  overflow: hidden;
  display: flex;
  flex-direction: column;
}
.browser-header {
  height: 24pt;
  background: #F1F5F9;
  display: flex;
  align-items: center;
  padding: 0 10pt;
  gap: 5pt;
  border-bottom: 1px solid #E2E8F0;
}
.browser-dot { width: 6pt; height: 6pt; border-radius: 50%; }
.browser-dot.red { background: #EF4444; }
.browser-dot.yellow { background: #F59E0B; }
.browser-dot.green { background: #10B981; }
.browser-url {
  background: #FFFFFF;
  border-radius: 10pt;
  padding: 2pt 10pt;
  font-size: 7.5pt;
  color: #64748B;
  margin-left: 8pt;
  flex: 1;
  max-width: 240pt;
  border: 1px solid #CBD5E1;
}
.browser-content {
  flex: 1;
  overflow: hidden;
  background: #FAFAFA;
}

/* ── FOOTER ── */
.slide-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: 12pt;
  font-size: 8pt;
  font-weight: 600;
  letter-spacing: 0.3pt;
  border-top: 1px solid transparent;
}
.dark .slide-footer {
  border-top-color: rgba(255, 255, 255, 0.08);
  color: #94A3B8;
}
.light .slide-footer {
  border-top-color: #F1E5EC;
  color: #94A3B8;
}
.footer-brand {
  display: flex;
  align-items: center;
  gap: 6pt;
}
.footer-logo {
  width: 14pt;
  height: 14pt;
  border-radius: 4pt;
}
.footer-page {
  font-variant-numeric: tabular-nums;
  font-weight: 700;
}

/* ── SLIDE 1 COVER ── */
.cover-layout {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 100%;
}
.cover-left {
  flex: 1;
  max-width: 480pt;
}
.cover-logo-row {
  display: flex;
  align-items: center;
  gap: 10pt;
  margin-bottom: 24pt;
}
.cover-logo {
  width: 32pt;
  height: 32pt;
  border-radius: 8pt;
  box-shadow: 0 4pt 12pt rgba(225, 29, 72, 0.4);
}
.cover-brand-title {
  font-size: 16pt;
  font-weight: 900;
  letter-spacing: 0.5pt;
  color: #FFFFFF;
}
.cover-brand-sub {
  font-size: 7.5pt;
  font-weight: 700;
  letter-spacing: 2pt;
  color: #FDA4AF;
}
.cover-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 6pt;
  margin-top: 18pt;
}
.tag-pill {
  padding: 4.5pt 10pt;
  border-radius: 14pt;
  font-size: 8pt;
  font-weight: 600;
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid rgba(255, 255, 255, 0.14);
  color: #F1F5F9;
}
.cover-right {
  position: relative;
  width: 360pt;
  height: 420pt;
  display: flex;
  align-items: center;
  justify-content: center;
}
.cover-phone-1 {
  position: absolute;
  right: 20pt;
  top: 10pt;
  z-index: 10;
  transform: rotate(2deg);
}
.cover-phone-2 {
  position: absolute;
  right: 140pt;
  top: 30pt;
  z-index: 5;
  transform: rotate(-4deg);
  opacity: 0.75;
}

/* ── 4 CARDS GRID (SLIDE 2) ── */
.cards-grid-4 {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 14pt;
  margin-top: 8pt;
}
.card-pillar {
  background: #FFFFFF;
  border-radius: 14pt;
  padding: 18pt 16pt;
  box-shadow: 0 8pt 24pt rgba(157, 23, 77, 0.04), 0 1px 3px rgba(0, 0, 0, 0.03);
  border: 1px solid #F3E8EE;
  display: flex;
  flex-direction: column;
}
.card-pillar .pillar-kicker {
  font-size: 7.5pt;
  font-weight: 800;
  letter-spacing: 1.2pt;
  text-transform: uppercase;
  color: #9D174D;
  margin-bottom: 8pt;
}
.card-pillar h3 {
  font-size: 13.5pt;
  font-weight: 800;
  color: #0F172A;
  margin-bottom: 6pt;
  line-height: 1.25;
}
.card-pillar p.desc {
  font-size: 8.8pt;
  color: #64748B;
  line-height: 1.4;
  margin-bottom: 12pt;
}
.card-pillar hr {
  border: none;
  border-top: 1px solid #F1E5EC;
  margin-bottom: 12pt;
}
.card-pillar ul {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 7pt;
}
.card-pillar li {
  font-size: 8.5pt;
  color: #334155;
  display: flex;
  align-items: center;
  gap: 6pt;
  line-height: 1.3;
}
.card-pillar li::before {
  content: '•';
  color: #9D174D;
  font-size: 14pt;
  line-height: 0;
}

/* ── PROBLEM / SOLUTION (SLIDE 3) ── */
.comparison-container {
  display: grid;
  grid-template-columns: 1fr 1.25fr;
  gap: 20pt;
  margin-top: 8pt;
}
.comp-card {
  border-radius: 16pt;
  padding: 22pt 20pt;
}
.comp-card.old {
  background: #FFF1F2;
  border: 1px solid #FFE4E6;
}
.comp-card.new {
  background: radial-gradient(circle at 80% 20%, #2A081D 0%, #15030F 100%);
  border: 1px solid #3B0D27;
  color: #FFFFFF;
}
.comp-kicker {
  font-size: 8.5pt;
  font-weight: 800;
  letter-spacing: 1.5pt;
  text-transform: uppercase;
  margin-bottom: 14pt;
}
.comp-card.old .comp-kicker { color: #BE123C; }
.comp-card.new .comp-kicker { color: #FDA4AF; }
.comp-list {
  display: flex;
  flex-direction: column;
  gap: 9pt;
}
.comp-item {
  display: flex;
  align-items: flex-start;
  gap: 8pt;
  font-size: 9pt;
  line-height: 1.35;
}
.comp-card.old .comp-item { color: #4C0519; }
.comp-card.new .comp-item { color: #E2E8F0; }
.comp-icon {
  width: 14pt;
  height: 14pt;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 8pt;
  font-weight: 800;
  flex-shrink: 0;
  margin-top: 1pt;
}
.comp-card.old .comp-icon { background: #FDA4AF; color: #9F1239; }
.comp-card.new .comp-icon { background: #10B981; color: #FFFFFF; }

/* ── TIMELINE JOURNEY (SLIDE 4) ── */
.timeline-grid {
  display: grid;
  grid-template-columns: repeat(6, 1fr);
  gap: 10pt;
  margin-top: 14pt;
}
.timeline-card {
  background: #FFFFFF;
  border-radius: 12pt;
  padding: 14pt 12pt;
  border: 1px solid #F1E5EC;
  box-shadow: 0 6pt 18pt rgba(157, 23, 77, 0.03);
  display: flex;
  flex-direction: column;
  position: relative;
}
.timeline-time {
  font-size: 7.5pt;
  font-weight: 800;
  color: #9D174D;
  margin-bottom: 6pt;
}
.timeline-card h4 {
  font-size: 10pt;
  font-weight: 800;
  color: #0F172A;
  margin-bottom: 5pt;
  line-height: 1.25;
}
.timeline-card p {
  font-size: 8pt;
  color: #64748B;
  line-height: 1.35;
}

/* ── FEATURE DEEP DIVE LAYOUT ── */
.feature-layout {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 28pt;
  height: 100%;
}
.feature-left {
  flex: 1;
  max-width: 440pt;
}
.feature-right {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
}

/* ── MULTI-PHONE SHOWCASE (SLIDE 23) ── */
.tri-phone-container {
  display: flex;
  gap: 16pt;
  align-items: center;
  justify-content: center;
}
.tri-phone-container .phone-frame {
  width: 175pt;
  height: 350pt;
  border-width: 6pt;
  border-radius: 26pt;
}

/* ── FEATURE DIRECTORY (SLIDE 25) ── */
.feature-matrix {
  display: grid;
  grid-template-columns: repeat(6, 1fr);
  gap: 14pt;
  margin-top: 8pt;
}
.matrix-col h4 {
  font-size: 8pt;
  font-weight: 800;
  letter-spacing: 1.2pt;
  text-transform: uppercase;
  color: #9D174D;
  border-bottom: 2px solid #F43F5E;
  padding-bottom: 6pt;
  margin-bottom: 8pt;
}
.matrix-col ul {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 6pt;
}
.matrix-col li {
  font-size: 8pt;
  color: #334155;
  line-height: 1.3;
}

/* ── CALL TO ACTION (SLIDE 27) ── */
.cta-layout {
  display: grid;
  grid-template-columns: 1.2fr 1fr;
  gap: 36pt;
  align-items: center;
  height: 100%;
}
.cta-box {
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 20pt;
  padding: 24pt 22pt;
  backdrop-filter: blur(10px);
}
.cta-box h3 {
  font-size: 16pt;
  font-weight: 900;
  color: #FFFFFF;
  margin-bottom: 12pt;
}
.cta-row {
  display: flex;
  flex-direction: column;
  gap: 10pt;
  margin-bottom: 18pt;
}
.cta-item {
  font-size: 9.5pt;
  color: #E2E8F0;
  display: flex;
  gap: 8pt;
}
.cta-label {
  font-weight: 800;
  color: #FDA4AF;
  min-width: 60pt;
}
.cta-btn {
  display: block;
  width: 100%;
  padding: 10pt;
  background: linear-gradient(135deg, #E11D48 0%, #BE185D 100%);
  color: #FFFFFF;
  text-align: center;
  font-size: 11pt;
  font-weight: 800;
  border-radius: 20pt;
  text-decoration: none;
  box-shadow: 0 8pt 20pt rgba(225, 29, 72, 0.4);
}
</style>
"""

# Slides generator
def generate_html():
    slides = []

    # ── SLIDE 1: COVER ──
    slides.append(f"""
    <div class="slide dark">
      <div class="cover-layout">
        <div class="cover-left">
          <div class="cover-logo-row">
            <img class="cover-logo" src="{img_logo}">
            <div>
              <div class="cover-brand-title">Femora</div>
              <div class="cover-brand-sub">AI-POWERED WOMEN'S HEALTH</div>
            </div>
          </div>
          <div class="kicker">CLINICAL EXCELLENCE ON HER PHONE</div>
          <h1 class="headline">Every symptom answered <span class="highlight-gold">inside 60 seconds.</span></h1>
          <p class="subtext">From dual-engine PCOS and thermal breast cancer screening to 4-phase cyclic hormone radar, touchless PPG heart vitals and zero-install clinician handoff — the complete clinical health platform for women across Pakistan and beyond.</p>
          <div class="cover-tags">
            <span class="tag-pill">Dual-Model PCOS AI</span>
            <span class="tag-pill">Thermal & Mammogram AI</span>
            <span class="tag-pill">4-Phase Hormone Radar</span>
            <span class="tag-pill">Touchless PPG Vitals</span>
            <span class="tag-pill">AI Lab Report Reader</span>
            <span class="tag-pill">Show My Doctor QR</span>
          </div>
        </div>
        <div class="cover-right">
          <div class="phone-frame cover-phone-2">
            <img class="phone-screen" src="{img_calendar}" style="object-position: top;">
          </div>
          <div class="phone-frame cover-phone-1">
            <img class="phone-screen" src="{img_home}" style="object-position: top;">
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora Health Technologies • Air University Islamabad</div>
        <div class="footer-page">01</div>
      </div>
    </div>
    """)

    # ── SLIDE 2: WHAT IS FEMORA? ──
    slides.append(f"""
    <div class="slide light">
      <div>
        <div class="kicker">WHAT IS FEMORA?</div>
        <h1 class="headline">One system for her entire health journey — from first period to clinical care.</h1>
        <p class="subtext">Built to eliminate diagnostic delays, break cultural taboos, and deliver hospital-grade screening right to her smartphone. Four clinical pillars, one private account, zero data leakage.</p>
        <div class="cards-grid-4">
          <div class="card-pillar">
            <div class="pillar-kicker">SCREEN & DETECT</div>
            <h3>Nothing slips through</h3>
            <p class="desc">Deep learning ultrasound and thermal vision catch reproductive risks before symptoms escalate.</p>
            <hr>
            <ul>
              <li>Ultrasound ResNet-50 AI</li>
              <li>Rotterdam PCOS model</li>
              <li>Breast lesion contouring</li>
            </ul>
          </div>
          <div class="card-pillar">
            <div class="pillar-kicker">TRACK & FORECAST</div>
            <h3>Her rhythm, mapped</h3>
            <p class="desc">Dynamic 28-day biological clock, 4-phase hormone curves, and camera heart-rate vitals.</p>
            <hr>
            <ul>
              <li>Living circular body clock</li>
              <li>Estrogen & LH radar</li>
              <li>Touchless optical PPG pulse</li>
            </ul>
          </div>
          <div class="card-pillar">
            <div class="pillar-kicker">UNDERSTAND & CONVERSE</div>
            <h3>Answers with empathy</h3>
            <p class="desc">Culturally localized AI companion with fluent Urdu voice and instant lab report OCR.</p>
            <hr>
            <ul>
              <li>Gemini 2.5 clinical triage</li>
              <li>Natural streaming Urdu voice</li>
              <li>Lab report OCR explainer</li>
            </ul>
          </div>
          <div class="card-pillar">
            <div class="pillar-kicker">CONNECT & PROTECT</div>
            <h3>Clinician handoff</h3>
            <p class="desc">Instant dynamic QR summary for doctors, verified clinic booking, and 100% on-device privacy.</p>
            <hr>
            <ul>
              <li>Show My Doctor instant QR</li>
              <li>80+ verified Oladoc doctors</li>
              <li>100% on-device private data</li>
            </ul>
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">02</div>
      </div>
    </div>
    """)

    # ── SLIDE 3: WHY WOMEN & CLINICIANS SWITCH ──
    slides.append(f"""
    <div class="slide light">
      <div>
        <div class="kicker">WHY WOMEN & CLINICIANS SWITCH</div>
        <h1 class="headline">Women wait an average of 2.5 years for a diagnosis. Femora closes that gap in one afternoon.</h1>
        <p class="subtext">What women's healthcare looks like across Pakistan on fragmented paper records and social stigma — and what it looks like the day after downloading Femora.</p>
        <div class="comparison-container">
          <div class="comp-card old">
            <div class="comp-kicker">THE OLD WAY</div>
            <div class="comp-list">
              <div class="comp-item"><span class="comp-icon">✕</span><span><strong>70% of PCOS cases undiagnosed</strong> until severe infertility or metabolic symptoms develop</span></div>
              <div class="comp-item"><span class="comp-icon">✕</span><span><strong>Hesitation & stigma:</strong> cultural shame and lack of female physicians delay breast screening for months</span></div>
              <div class="comp-item"><span class="comp-icon">✕</span><span><strong>Confusing ultrasound sheets:</strong> complex radiological terminology left misunderstood without guidance</span></div>
              <div class="comp-item"><span class="comp-icon">✕</span><span><strong>Guessing fertile windows:</strong> static calendar apps without hormone or physical symptom tracking</span></div>
              <div class="comp-item"><span class="comp-icon">✕</span><span><strong>Lost paper records:</strong> doctors receive zero longitudinal history during 5-minute hospital consultations</span></div>
              <div class="comp-item"><span class="comp-icon">✕</span><span><strong>Cloud privacy dread:</strong> fear that sensitive reproductive and cycle data could leak online</span></div>
            </div>
          </div>
          <div class="comp-card new">
            <div class="comp-kicker">WITH FEMORA</div>
            <div class="comp-list">
              <div class="comp-item"><span class="comp-icon">✓</span><span><strong>60-Second On-Device AI Screening:</strong> dual-engine machine learning flags PCOS & breast risks at first onset</span></div>
              <div class="comp-item"><span class="comp-icon">✓</span><span><strong>Dignity in the Home:</strong> private, non-judgmental health assessments conducted safely in her own room</span></div>
              <div class="comp-item"><span class="comp-icon">✓</span><span><strong>Instant Report OCR Clarity:</strong> upload ultrasound or blood tests to get plain-language Urdu/English breakdowns</span></div>
              <div class="comp-item"><span class="comp-icon">✓</span><span><strong>4-Phase Hormone Radar:</strong> daily biological forecasts tracking Estrogen, Progesterone, LH, and FSH</span></div>
              <div class="comp-item"><span class="comp-icon">✓</span><span><strong>Show My Doctor QR:</strong> encrypted web link that renders her complete clinical history on the doctor's screen in 3 seconds</span></div>
              <div class="comp-item"><span class="comp-icon">✓</span><span><strong>100% Local On-Device Storage:</strong> zero cloud health profiling; medical data never leaves her smartphone</span></div>
            </div>
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">03</div>
      </div>
    </div>
    """)

    # ── SLIDE 4: PATIENT JOURNEY ──
    slides.append(f"""
    <div class="slide light">
      <div>
        <div class="kicker">REAL PATIENT TRACE</div>
        <h1 class="headline">One woman, traced from first symptom to clinical intervention.</h1>
        <p class="subtext">How Ayesha, a 24-year-old university student in Islamabad, navigated an irregular cycle and received verified specialist care in under 48 hours.</p>
        <div class="timeline-grid">
          <div class="timeline-card">
            <div class="timeline-time">09:15 AM • HOME</div>
            <h4>Cycle & Symptom Log</h4>
            <p>Logs a 42-day cycle delay, facial acne flare-up, and fatigue on Femora's Daily Chronicle.</p>
          </div>
          <div class="timeline-card">
            <div class="timeline-time">09:20 AM • TRIAGE</div>
            <h4>PCOS Assessment</h4>
            <p>Takes the 12-factor clinical questionnaire; AI calculates a 78% elevated risk score.</p>
          </div>
          <div class="timeline-card">
            <div class="timeline-time">09:25 AM • CONVERSATION</div>
            <h4>Urdu Voice Companion</h4>
            <p>Dr. Ayesha AI explains the Rotterdam criteria in warm, empathetic Urdu with diet guidance.</p>
          </div>
          <div class="timeline-card">
            <div class="timeline-time">02:10 PM • LAB SCAN</div>
            <h4>Explain My Report</h4>
            <p>Photographs her hormone panel; OCR flags LH:FSH ratio of 2.8:1 and generates doctor questions.</p>
          </div>
          <div class="timeline-card">
            <div class="timeline-time">04:30 PM • CLINIC MATCH</div>
            <h4>Find a Doctor</h4>
            <p>Discovers Dr. Sadia (PMDC-verified gynaecologist, 4.9★, 4 km away) via Oladoc directory.</p>
          </div>
          <div class="timeline-card">
            <div class="timeline-time">NEXT DAY • EXAM ROOM</div>
            <h4>Show My Doctor QR</h4>
            <p>Doctor scans Femora QR; complete encrypted report loads on doctor's PC with zero app install.</p>
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">04</div>
      </div>
    </div>
    """)

    # ── SLIDE 5: PILLAR 1 - PCOS DUAL-MODEL ENGINE ──
    slides.append(f"""
    <div class="slide light">
      <div class="feature-layout">
        <div class="feature-left">
          <div class="kicker"><span class="badge-tag">SCREEN & DETECT</span> PCOS DIAGNOSTIC SUITE</div>
          <h1 class="headline">Two intelligent models. One definitive assessment.</h1>
          <p class="subtext">Femora unites deep learning ovarian ultrasound recognition with clinical phenotypic modeling for unmatched diagnostic precision, validated on international cohorts.</p>
          <div class="points-list">
            <div class="point-item">
              <div class="point-num">1</div>
              <div class="point-text">
                <h3>Ultrasound ResNet-50 Vision</h3>
                <p>Classifies ovarian ultrasound scans to detect peripheral follicular 'string-of-pearls' patterns and stroma hypertrophy with 91.2% clinical accuracy.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">2</div>
              <div class="point-text">
                <h3>Rotterdam Phenotypic Engine</h3>
                <p>Evaluates 12 clinical indicators (cycle length, hirsutism, acne, weight change, LH/FSH) using calibrated XGBoost and Random Forest classifiers.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">3</div>
              <div class="point-text">
                <h3>Interactive 'What-If' Simulation</h3>
                <p>Dynamic sliders empower women to visualize how lifestyle changes (BMI reduction, 30 min exercise) directly lower their risk trajectory.</p>
              </div>
            </div>
          </div>
        </div>
        <div class="feature-right">
          <div class="phone-frame">
            <img class="phone-screen" src="{img_pcos_risk}" style="object-position: top;">
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">05</div>
      </div>
    </div>
    """)

    # ── SLIDE 6: PILLAR 1 - BREAST HEALTH & THERMAL MAMMOGRAPHY ──
    slides.append(f"""
    <div class="slide light">
      <div class="feature-layout">
        <div class="feature-left">
          <div class="kicker"><span class="badge-tag">SCREEN & DETECT</span> BREAST CANCER EARLY DETECTION</div>
          <h1 class="headline">Catching abnormalities before they become palpable masses.</h1>
          <p class="subtext">Trained on validated clinical datasets (BUSI, UCLM) to classify mammograms and ultrasound scans into Normal, Benign, or Malignant with calibrated risk bounds.</p>
          <div class="points-list">
            <div class="point-item">
              <div class="point-num">1</div>
              <div class="point-text">
                <h3>Calibrated Probability Engine</h3>
                <p>Outputs temperature-scaled confidence ratings (e.g. 'Likely Benign • 96% confidence') with honest uncertainty estimation for clinician trust.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">2</div>
              <div class="point-text">
                <h3>Triple Visualizer Switch</h3>
                <p>Switch instantly between Original Scan, AI Focus CAM Heatmap (showing what influenced the model), and Lesion Outline.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">3</div>
              <div class="point-text">
                <h3>Autonomous Image Gating</h3>
                <p>Built-in gate rejects non-ultrasounds, photos, and Doppler scans (99% rejection on non-breast images) to prevent false analyses.</p>
              </div>
            </div>
          </div>
        </div>
        <div class="feature-right">
          <div class="phone-frame">
            <img class="phone-screen" src="{img_breast}" style="object-position: 0% 12%;">
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">06</div>
      </div>
    </div>
    """)

    # ── SLIDE 7: PILLAR 1 - LESION SEGMENTATION & DIGITAL RULER ──
    slides.append(f"""
    <div class="slide light">
      <div class="feature-layout">
        <div class="feature-left">
          <div class="kicker"><span class="badge-tag">SCREEN & DETECT</span> SPATIAL TUMOR DELINEATION</div>
          <h1 class="headline">Millimetre-accurate lesion boundaries directly on the scan.</h1>
          <p class="subtext">Deep semantic segmentation outlines acoustic shadowing, microcalcifications, and irregular borders with an on-screen digital caliper tool.</p>
          <div class="points-list">
            <div class="point-item">
              <div class="point-num">1</div>
              <div class="point-text">
                <h3>U-Net Mass Contouring</h3>
                <p>Precisely delineates suspicious boundaries, isolating morphological tissue margins for patient reassurance and surgical review.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">2</div>
              <div class="point-text">
                <h3>Interactive Centimetre Caliper</h3>
                <p>A digital touch caliper lets users and clinicians measure lesion dimensions directly on the screen to track tumor progression.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">3</div>
              <div class="point-text">
                <h3>Bi-RADS Concordance</h3>
                <p>Correlates lesion geometry (taller-than-wide, spiculated margins) with standard radiological guidelines to determine biopsy urgency.</p>
              </div>
            </div>
          </div>
        </div>
        <div class="feature-right">
          <div class="phone-frame">
            <img class="phone-screen" src="{img_breast}" style="object-position: 0% 45%;">
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">07</div>
      </div>
    </div>
    """)

    # ── SLIDE 8: PILLAR 2 - CIRCULAR BODY CLOCK ──
    slides.append(f"""
    <div class="slide light">
      <div class="feature-layout">
        <div class="feature-left">
          <div class="kicker"><span class="badge-tag">TRACK & FORECAST</span> BIOLOGICAL CLOCK</div>
          <h1 class="headline">Her 28-day cycle, visualized as a living rhythm.</h1>
          <p class="subtext">Moving beyond flat calendars: a fluid, ambient glowing ring that shifts dynamically with her personal biological rhythm and fertile phases.</p>
          <div class="points-list">
            <div class="point-item">
              <div class="point-num">1</div>
              <div class="point-text">
                <h3>4-Phase Fluid Chronology</h3>
                <p>Real-time visual progress through Menstrual (Days 1-5), Follicular (6-13), Ovulatory (14-16), and Luteal (17-28) phases.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">2</div>
              <div class="point-text">
                <h3>Adaptive AI Prediction</h3>
                <p>Blends personal rolling history with clinical Bayesian priors to forecast future periods and identify irregular deviations.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">3</div>
              <div class="point-text">
                <h3>Conception Probability Radar</h3>
                <p>Gold glowing markers indicate peak fertility windows with percentage probabilities for natural family planning.</p>
              </div>
            </div>
          </div>
        </div>
        <div class="feature-right">
          <div class="phone-frame">
            <img class="phone-screen" src="{img_home}" style="object-position: 0% 5%;">
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">08</div>
      </div>
    </div>
    """)

    # ── SLIDE 9: PILLAR 2 - 4-PHASE HORMONE RADAR ──
    slides.append(f"""
    <div class="slide light">
      <div class="feature-layout">
        <div class="feature-left">
          <div class="kicker"><span class="badge-tag">TRACK & FORECAST</span> HORMONAL DYNAMICS</div>
          <h1 class="headline">Demystifying the four master hormones that govern her body.</h1>
          <p class="subtext">An interactive medical graph mapping daily fluctuations of Estrogen, Progesterone, LH, and FSH with symptom correlations and physiological explanations.</p>
          <div class="points-list">
            <div class="point-item">
              <div class="point-num">1</div>
              <div class="point-text">
                <h3>Multi-Hormone Waveform</h3>
                <p>Displays synchronized curves showing how the mid-cycle LH surge triggers ovulation, followed by the secondary Progesterone rise.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">2</div>
              <div class="point-text">
                <h3>Daily Physiological Insights</h3>
                <p>Explains why energy drops, cravings surge, or focus sharpens today, connecting emotions to biological chemistry.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">3</div>
              <div class="point-text">
                <h3>Anovulatory Detection</h3>
                <p>Alerts users when logged physical signs suggest absence of progesterone rise, providing early warning for PCOS.</p>
              </div>
            </div>
          </div>
        </div>
        <div class="feature-right">
          <div class="phone-frame">
            <img class="phone-screen" src="{img_home}" style="object-position: 0% 40%;">
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">09</div>
      </div>
    </div>
    """)

    # ── SLIDE 10: PILLAR 2 - OPTICAL PPG HEART RATE MONITOR ──
    slides.append(f"""
    <div class="slide light">
      <div class="feature-layout">
        <div class="feature-left">
          <div class="kicker"><span class="badge-tag">TRACK & FORECAST</span> OPTICAL CARDIOVASCULAR VITALS</div>
          <h1 class="headline">Reading her pulse through the camera lens. Zero wearables required.</h1>
          <p class="subtext">Photoplethysmography (PPG) analyzes micro-capillary color shifts in her fingertip to extract resting heart rate and autonomic tone in 15 seconds.</p>
          <div class="points-list">
            <div class="point-item">
              <div class="point-num">1</div>
              <div class="point-text">
                <h3>Pure Optical Sensing</h3>
                <p>LED flash illuminates fingertip capillaries; camera algorithm samples red-channel pulsatile absorption at 30 fps.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">2</div>
              <div class="point-text">
                <h3>Cycle-Correlated Vitals</h3>
                <p>Tracks how basal heart rate rises 2-4 bpm during the luteal phase, confirming ovulation without expensive smartwatches.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">3</div>
              <div class="point-text">
                <h3>100% Offline Processing</h3>
                <p>Real-time digital bandpass filter runs locally on the smartphone DSP; zero video frames ever leave the device.</p>
              </div>
            </div>
          </div>
        </div>
        <div class="feature-right">
          <div class="phone-frame">
            <img class="phone-screen" src="{img_home}" style="object-position: 0% 68%;">
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">10</div>
      </div>
    </div>
    """)

    # ── SLIDE 11: PILLAR 2 - DAILY SYMPTOM & MOOD CHRONICLE ──
    slides.append(f"""
    <div class="slide light">
      <div class="feature-layout">
        <div class="feature-left">
          <div class="kicker"><span class="badge-tag">TRACK & FORECAST</span> SYMPTOM & MOOD LOGGING</div>
          <h1 class="headline">Every cramp, headache, and mood swing connected to her cycle.</h1>
          <p class="subtext">A comprehensive daily logging suite featuring animated Lottie emojis, flow volume sliders, and physical symptom tags.</p>
          <div class="points-list">
            <div class="point-item">
              <div class="point-num">1</div>
              <div class="point-text">
                <h3>Animated Emoji Mood Selector</h3>
                <p>Bundled offline Lottie animations capture subtle emotional shifts (Calm, Joyful, Tired, Anxious, Irritable).</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">2</div>
              <div class="point-text">
                <h3>Physical Health Tags</h3>
                <p>One-tap logging for pelvic pain, bloating, breast tenderness, cervical mucus changes, and sleep quality.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">3</div>
              <div class="point-text">
                <h3>PMS & PMDD Discovery</h3>
                <p>Identifies recurring premenstrual dysphoric patterns across multiple months to assist psychiatric and gynaecological consults.</p>
              </div>
            </div>
          </div>
        </div>
        <div class="feature-right">
          <div class="phone-frame">
            <img class="phone-screen" src="{img_calendar}" style="object-position: 0% 30%;">
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">11</div>
      </div>
    </div>
    """)

    # ── SLIDE 12: PILLAR 2 - SMART MEDICINE & SELF-EXAM REMINDERS ──
    slides.append(f"""
    <div class="slide light">
      <div class="feature-layout">
        <div class="feature-left">
          <div class="kicker"><span class="badge-tag">TRACK & FORECAST</span> PROACTIVE NOTIFICATIONS</div>
          <h1 class="headline">Clinical reminders timed to her body, not just the clock.</h1>
          <p class="subtext">Automated push alerts that schedule breast self-exams precisely 7 days after period onset when breast tissue is least nodular.</p>
          <div class="points-list">
            <div class="point-item">
              <div class="point-num">1</div>
              <div class="point-text">
                <h3>Cycle-Synchronized Self-Exams</h3>
                <p>Schedules monthly breast examinations during the hormonal nadir when false-positive lumps from swelling are minimal.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">2</div>
              <div class="point-text">
                <h3>Medication Adherence Alarms</h3>
                <p>Daily recurring reminders for oral contraceptives, inositol, metformin, and prenatal vitamin supplements.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">3</div>
              <div class="point-text">
                <h3>Boot-Resilient Scheduling</h3>
                <p>Native Android alarms persist across device reboots and low-battery states without draining background power.</p>
              </div>
            </div>
          </div>
        </div>
        <div class="feature-right">
          <div class="phone-frame">
            <img class="phone-screen" src="{img_calendar}" style="object-position: 0% 75%;">
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">12</div>
      </div>
    </div>
    """)

    # ── SLIDE 13: PILLAR 3 - 24/7 AI MEDICAL COMPANION ──
    slides.append(f"""
    <div class="slide light">
      <div class="feature-layout">
        <div class="feature-left">
          <div class="kicker"><span class="badge-tag">UNDERSTAND & CONVERSE</span> 24/7 AI COMPANION</div>
          <h1 class="headline">Empathetic, culturally aware medical guidance whenever she needs it.</h1>
          <p class="subtext">Powered by Google Gemini with strict clinical triage guardrails, specialized in South Asian women's reproductive health and social nuances.</p>
          <div class="points-list">
            <div class="point-item">
              <div class="point-num">1</div>
              <div class="point-text">
                <h3>Emergency Triage Guardrails</h3>
                <p>Immediately flags acute red-flag symptoms (unilateral pelvic stabbing, heavy haemorrhage) for emergency 1122 medical response.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">2</div>
              <div class="point-text">
                <h3>Longitudinal Health Memory</h3>
                <p>Companion references logged cycle day, PCOS risk score, and recent vitals for personalized, medically coherent advice.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">3</div>
              <div class="point-text">
                <h3>A Safe, Non-Judgmental Haven</h3>
                <p>Answers sensitive sexual, menstrual, and fertility questions with dignity, eliminating social hesitation and embarrassment.</p>
              </div>
            </div>
          </div>
        </div>
        <div class="feature-right">
          <div class="phone-frame">
            <img class="phone-screen" src="{img_companion}" style="object-position: top;">
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">13</div>
      </div>
    </div>
    """)

    # ── SLIDE 14: PILLAR 3 - NATURAL NEURAL VOICE (URDU & ENGLISH) ──
    slides.append(f"""
    <div class="slide light">
      <div class="feature-layout">
        <div class="feature-left">
          <div class="kicker"><span class="badge-tag">UNDERSTAND & CONVERSE</span> STREAMING NEURAL VOICE</div>
          <h1 class="headline">Listen and speak in her mother tongue. First words in 2 seconds.</h1>
          <p class="subtext">Streaming Microsoft neural speech synthesis (Edge-TTS) brings natural, warm Urdu and English vocal communication to life.</p>
          <div class="points-list">
            <div class="point-item">
              <div class="point-num">1</div>
              <div class="point-text">
                <h3>Ultra-Low Latency Pipeline</h3>
                <p>Audio begins playing in ~2 seconds over cellular 4G networks, creating a lifelike conversation with 'Dr. Ayesha'.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">2</div>
              <div class="point-text">
                <h3>Low-Literacy Empowerment</h3>
                <p>Women who cannot read complex clinical terms can listen to comforting, clear Urdu audio guidance directly through the speaker.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">3</div>
              <div class="point-text">
                <h3>One-Tap Voice Input</h3>
                <p>Built-in audio recording lets patients describe symptoms naturally in spoken Urdu without having to type on a keyboard.</p>
              </div>
            </div>
          </div>
        </div>
        <div class="feature-right">
          <div class="phone-frame">
            <img class="phone-screen" src="{img_companion}" style="object-position: 0% 60%;">
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">14</div>
      </div>
    </div>
    """)

    # ── SLIDE 15: PILLAR 3 - LAB REPORT & ULTRASOUND OCR READER ──
    slides.append(f"""
    <div class="slide light">
      <div class="feature-layout">
        <div class="feature-left">
          <div class="kicker"><span class="badge-tag">UNDERSTAND & CONVERSE</span> LAB REPORT EXPLAINER</div>
          <h1 class="headline">Turn intimidating medical printouts into clear understanding.</h1>
          <p class="subtext">Upload up to 3 pages of blood tests, hormone panels, or ultrasound reports for instant computer vision extraction and clinical translation.</p>
          <div class="points-list">
            <div class="point-item">
              <div class="point-num">1</div>
              <div class="point-text">
                <h3>Structured Findings Table</h3>
                <p>Extracts biomarkers (LH, FSH, TSH, Prolactin, Testosterone) and badges them Normal, Elevated, or Low against standard clinical ranges.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">2</div>
              <div class="point-text">
                <h3>Questions for Her Doctor</h3>
                <p>Automatically generates targeted, intelligent questions the patient can ask her physician during her upcoming consultation.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">3</div>
              <div class="point-text">
                <h3>Zero Server Image Retention</h3>
                <p>Medical images are processed in-memory and immediately purged; photographs are never stored on disk or server databases.</p>
              </div>
            </div>
          </div>
        </div>
        <div class="feature-right">
          <div class="phone-frame">
            <img class="phone-screen" src="{img_report}" style="object-position: top;">
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">15</div>
      </div>
    </div>
    """)

    # ── SLIDE 16: PILLAR 3 - STEP-BY-STEP BREAST SELF-EXAM GUIDE ──
    slides.append(f"""
    <div class="slide light">
      <div class="feature-layout">
        <div class="feature-left">
          <div class="kicker"><span class="badge-tag">UNDERSTAND & CONVERSE</span> CLINICAL SELF-EXAM GUIDE</div>
          <h1 class="headline">A structured clinical protocol for monthly breast palpation.</h1>
          <p class="subtext">Illustrated step-by-step guidance following WHO and oncologist protocols, empowering women to detect subtle tissue abnormalities early.</p>
          <div class="points-list">
            <div class="point-item">
              <div class="point-num">1</div>
              <div class="point-text">
                <h3>4-Step Illustrated Method</h3>
                <p>Visual positioning in front of mirror, hands on hips, raised arm palpation, and nipple inspection.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">2</div>
              <div class="point-text">
                <h3>Palpation Pattern Mastery</h3>
                <p>Teaches the vertical strip and circular friction technique using finger pads, not fingertips, across all four quadrants.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">3</div>
              <div class="point-text">
                <h3>Warning Sign Checklist</h3>
                <p>Educational recognition for hard fixed lumps, skin dimpling ('peau d'orange'), inverted nipples, and spontaneous discharge.</p>
              </div>
            </div>
          </div>
        </div>
        <div class="feature-right">
          <div class="phone-frame">
            <img class="phone-screen" src="{img_breast}" style="object-position: 0% 85%;">
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">16</div>
      </div>
    </div>
    """)

    # ── SLIDE 17: PILLAR 3 - BILINGUAL URDU & ENGLISH ACCESSIBILITY ──
    slides.append(f"""
    <div class="slide light">
      <div class="feature-layout">
        <div class="feature-left">
          <div class="kicker"><span class="badge-tag">UNDERSTAND & CONVERSE</span> CULTURAL ACCESSIBILITY</div>
          <h1 class="headline">True Right-to-Left localization with authentic Nastaliq typography.</h1>
          <p class="subtext">Femora flips its entire layout seamlessly between English and Urdu with one tap, complete with bundled Noto Nastaliq fonts for flawless rendering.</p>
          <div class="points-list">
            <div class="point-item">
              <div class="point-num">1</div>
              <div class="point-text">
                <h3>Full Native RTL UI Mirroring</h3>
                <p>Menus, cards, navigation drawers, and data tables automatically reverse direction for natural, comfortable Urdu reading.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">2</div>
              <div class="point-text">
                <h3>Bundled Noto Nastaliq Font</h3>
                <p>Crystal-clear Urdu typography renders beautifully across all Android versions without depending on phone manufacturer fonts.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">3</div>
              <div class="point-text">
                <h3>Culturally Sensitive Vocabulary</h3>
                <p>Replaces cold or awkward translations with respectful, medically precise Urdu phrasing tailored to Pakistani culture.</p>
              </div>
            </div>
          </div>
        </div>
        <div class="feature-right">
          <div class="phone-frame">
            <img class="phone-screen" src="{img_home}" style="object-position: 0% 90%;">
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">17</div>
      </div>
    </div>
    """)

    # ── SLIDE 18: PILLAR 4 - "SHOW MY DOCTOR" INSTANT QR PORTAL ──
    slides.append(f"""
    <div class="slide light">
      <div class="feature-layout">
        <div class="feature-left">
          <div class="kicker"><span class="badge-tag">CONNECT & PROTECT</span> CLINICIAN HANDOFF</div>
          <h1 class="headline">Her complete medical summary on the doctor's screen in 3 seconds.</h1>
          <p class="subtext">A secure, dynamic QR code that opens an interactive, zero-install clinical dashboard at femora.web.app right in the consultation room.</p>
          <div class="points-list">
            <div class="point-item">
              <div class="point-num">1</div>
              <div class="point-text">
                <h3>Zero App Install Required</h3>
                <p>The physician scans the QR code using any smartphone or webcam; the clinical dashboard opens immediately in the browser.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">2</div>
              <div class="point-text">
                <h3>Comprehensive Diagnostic View</h3>
                <p>Displays 6-month cycle regularity, PCOS risk gauge, ultrasound scan findings, resting HR, and flagged lab report values.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">3</div>
              <div class="point-text">
                <h3>Client-Compressed URL Payload</h3>
                <p>Data is compressed directly into the URL fragment hash; no server database intermediary stores or tracks the transfer.</p>
              </div>
            </div>
          </div>
        </div>
        <div class="feature-right">
          <div class="phone-frame">
            <img class="phone-screen" src="{img_doctor_qr}" style="object-position: top;">
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">18</div>
      </div>
    </div>
    """)

    # ── SLIDE 19: PILLAR 4 - VERIFIED WOMEN'S HEALTH DOCTORS (OLADOC) ──
    slides.append(f"""
    <div class="slide light">
      <div class="feature-layout">
        <div class="feature-left">
          <div class="kicker"><span class="badge-tag">CONNECT & PROTECT</span> DOCTOR DISCOVERY</div>
          <h1 class="headline">Direct access to verified gynaecologists and breast specialists.</h1>
          <p class="subtext">Seamless integration with Oladoc bringing 80+ licensed practitioners across Islamabad and Rawalpindi with full fee transparency.</p>
          <div class="points-list">
            <div class="point-item">
              <div class="point-num">1</div>
              <div class="point-text">
                <h3>Specialty Filter Chips</h3>
                <p>Filter instantly by Gynaecologist (30+), Breast Surgeon (17+), Endocrinologist (21+), or Fertility Specialist (14+).</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">2</div>
              <div class="point-text">
                <h3>Transparent Doctor Profiles</h3>
                <p>PMDC verification badges, years of experience, clinic locations, consultation fees (e.g. Rs. 2,500), and patient ratings.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">3</div>
              <div class="point-text">
                <h3>One-Tap Direct Actions</h3>
                <p>Book clinic appointments online, launch turn-by-turn navigation via Google Maps, or dial the clinic directly.</p>
              </div>
            </div>
          </div>
        </div>
        <div class="feature-right">
          <div class="phone-frame">
            <img class="phone-screen" src="{img_doctors}" style="object-position: top;">
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">19</div>
      </div>
    </div>
    """)

    # ── SLIDE 20: PILLAR 4 - EMERGENCY NEARBY CARE & HOSPITALS ──
    slides.append(f"""
    <div class="slide light">
      <div class="feature-layout">
        <div class="feature-left">
          <div class="kicker"><span class="badge-tag">CONNECT & PROTECT</span> EMERGENCY CARE ACCESS</div>
          <h1 class="headline">Instant emergency navigation when minutes matter.</h1>
          <p class="subtext">Geo-located hospital finder with instant 1122 ambulance quick-dial and real-time open status for emergency obstetric and gynaecological units.</p>
          <div class="points-list">
            <div class="point-item">
              <div class="point-num">1</div>
              <div class="point-text">
                <h3>One-Tap 1122 Hotline</h3>
                <p>Prominent emergency dial banner connects immediately to Pakistan's Rescue 1122 medical response team.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">2</div>
              <div class="point-text">
                <h3>Radius-Filtered Finder</h3>
                <p>Locate nearest hospital emergency departments within 5 km, 10 km, or 25 km of current GPS coordinates.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">3</div>
              <div class="point-text">
                <h3>Turn-by-Turn Route Navigation</h3>
                <p>Deep-links to Google Maps or Apple Maps with live traffic estimation, emergency ward entrances, and phone numbers.</p>
              </div>
            </div>
          </div>
        </div>
        <div class="feature-right">
          <div class="phone-frame">
            <img class="phone-screen" src="{img_hospitals}" style="object-position: top;">
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">20</div>
      </div>
    </div>
    """)

    # ── SLIDE 21: PILLAR 4 - FORMAL CLINICAL PDF EXPORT ──
    slides.append(f"""
    <div class="slide light">
      <div class="feature-layout">
        <div class="feature-left">
          <div class="kicker"><span class="badge-tag">CONNECT & PROTECT</span> MEDICAL RECORDS</div>
          <h1 class="headline">Hospital-ready clinical reports, exported with one tap.</h1>
          <p class="subtext">Generates a multi-page, beautifully structured PDF report ready to print, email, or attach to hospital admission records.</p>
          <div class="points-list">
            <div class="point-item">
              <div class="point-num">1</div>
              <div class="point-text">
                <h3>Standardized Clinical Format</h3>
                <p>Includes patient vitals, 6-month cycle stability metrics, ultrasound analysis, and active medication history.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">2</div>
              <div class="point-text">
                <h3>Physician Review Signature Block</h3>
                <p>Formatted with standard medical triage notices, date stamps, and dedicated space for clinical notes.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">3</div>
              <div class="point-text">
                <h3>Native Printing & WhatsApp Sharing</h3>
                <p>Uses Android Printing framework to air-print, upload to cloud storage, or share directly with a consulting doctor.</p>
              </div>
            </div>
          </div>
        </div>
        <div class="feature-right">
          <div class="phone-frame">
            <img class="phone-screen" src="{img_profile}" style="object-position: top;">
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">21</div>
      </div>
    </div>
    """)

    # ── SLIDE 22: PILLAR 4 - ZERO-LEAK PRIVACY ARCHITECTURE ──
    slides.append(f"""
    <div class="slide light">
      <div class="feature-layout">
        <div class="feature-left">
          <div class="kicker"><span class="badge-tag">CONNECT & PROTECT</span> PRIVACY BY DESIGN</div>
          <h1 class="headline">Her health data belongs to her alone. Zero cloud tracking.</h1>
          <p class="subtext">Femora stores medical records exclusively on the local device, ensuring complete privacy from advertisers, employers, or third parties.</p>
          <div class="points-list">
            <div class="point-item">
              <div class="point-num">1</div>
              <div class="point-text">
                <h3>100% Local Sandboxed Storage</h3>
                <p>Cycle logs, AI scan scores, chat logs, and heart vitals live strictly in local SQLite and shared preferences on her phone.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">2</div>
              <div class="point-text">
                <h3>Frictionless Guest Exploration</h3>
                <p>Try every screening tool, the cycle tracker, and companion chat without providing a name, phone, or email address.</p>
              </div>
            </div>
            <div class="point-item">
              <div class="point-num">3</div>
              <div class="point-text">
                <h3>Ephemeral Server Processing</h3>
                <p>Ultrasounds and lab scans are processed in-memory by AI models and immediately discarded; zero image retention.</p>
              </div>
            </div>
          </div>
        </div>
        <div class="feature-right">
          <div class="phone-frame">
            <img class="phone-screen" src="{img_login}" style="object-position: top;">
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">22</div>
      </div>
    </div>
    """)

    # ── SLIDE 23: EVERYWHERE - ON THE PHONE ──
    slides.append(f"""
    <div class="slide dark">
      <div>
        <div class="kicker"><span class="badge-tag">EVERYWHERE</span> NATIVE FLUTTER PLATFORM</div>
        <h1 class="headline">A true native smartphone app. <span class="highlight-gold">26 MB, 60 fps, zero bloat.</span></h1>
        <p class="subtext">Engineered in Flutter for flawless performance on both budget Android devices and flagship hardware. Single-thumb ergonomics, tactile haptics, and instant cold launch.</p>
        <div class="tri-phone-container" style="margin-top: 18pt;">
          <div class="phone-frame">
            <img class="phone-screen" src="{img_home}" style="object-position: top;">
          </div>
          <div class="phone-frame" style="transform: scale(1.05); z-index: 10;">
            <img class="phone-screen" src="{img_breast}" style="object-position: 0% 12%;">
          </div>
          <div class="phone-frame">
            <img class="phone-screen" src="{img_companion}" style="object-position: top;">
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">23</div>
      </div>
    </div>
    """)

    # ── SLIDE 24: CLINICAL ETHICS & SAFETY BOUNDARIES ──
    slides.append(f"""
    <div class="slide light">
      <div>
        <div class="kicker">CLINICAL ETHICS & SAFETY BOUNDARIES</div>
        <h1 class="headline">AI designed to assist physicians, never to replace them.</h1>
        <p class="subtext">Built under strict clinical guidelines to deliver safe triage, transparent explanations, and responsible medical stewardship.</p>
        <div class="cards-grid-4">
          <div class="card-pillar">
            <div class="pillar-kicker">TRIAGE ONLY</div>
            <h3>Screening, Not Diagnosis</h3>
            <p class="desc">Clear demarcation that AI scores indicate statistical risk, prompting professional clinical follow-up.</p>
            <hr>
            <ul>
              <li>Explicit clinical disclaimers</li>
              <li>Encourages doctor review</li>
              <li>Never overrides clinician</li>
            </ul>
          </div>
          <div class="card-pillar">
            <div class="pillar-kicker">EMERGENCY PROTOCOL</div>
            <h3>Red-Flag Detection</h3>
            <p class="desc">Immediate alerts and emergency hotline triggers when severe or emergent symptoms are identified.</p>
            <hr>
            <ul>
              <li>Ectopic pregnancy warning</li>
              <li>Acute haemorrhage flags</li>
              <li>Instant 1122 quick-dial</li>
            </ul>
          </div>
          <div class="card-pillar">
            <div class="pillar-kicker">PRESCRIPTION BOUNDS</div>
            <h3>No Medication Dosing</h3>
            <p class="desc">The AI companion strictly refuses to prescribe drug dosages or modify ongoing medical prescriptions.</p>
            <hr>
            <ul>
              <li>Refuses dosage questions</li>
              <li>Prevents self-medication</li>
              <li>Defers to licensed doctor</li>
            </ul>
          </div>
          <div class="card-pillar">
            <div class="pillar-kicker">TRANSPARENCY</div>
            <h3>Calibrated Confidence</h3>
            <p class="desc">Algorithms display honest uncertainty; borderline scans are flagged for specialist ultrasound review.</p>
            <hr>
            <ul>
              <li>Temperature-scaled scores</li>
              <li>Visual CAM attention maps</li>
              <li>Explains what model saw</li>
            </ul>
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">24</div>
      </div>
    </div>
    """)

    # ── SLIDE 25: EVERYTHING IN ONE LIST ──
    slides.append(f"""
    <div class="slide light">
      <div>
        <div class="kicker">EVERYTHING IN ONE LIST</div>
        <h1 class="headline">Every feature in Femora.</h1>
        <div class="feature-matrix">
          <div class="matrix-col">
            <h4>AI Screening</h4>
            <ul>
              <li>Ultrasound ResNet-50 AI</li>
              <li>Rotterdam PCOS model</li>
              <li>Mammogram classifier</li>
              <li>Thermal risk engine</li>
              <li>U-Net mass contouring</li>
              <li>CAM focus heatmaps</li>
              <li>Interactive digital ruler</li>
              <li>What-If lifestyle sliders</li>
              <li>Multi-modal risk scoring</li>
            </ul>
          </div>
          <div class="matrix-col">
            <h4>Cycle & Vitals</h4>
            <ul>
              <li>28-day fluid body clock</li>
              <li>4-phase hormone radar</li>
              <li>Adaptive cycle prediction</li>
              <li>Conception window radar</li>
              <li>Touchless optical PPG</li>
              <li>Resting HR cycle baseline</li>
              <li>Basal temperature log</li>
              <li>Symptom chronicler</li>
              <li>Lottie animated emojis</li>
            </ul>
          </div>
          <div class="matrix-col">
            <h4>AI Companion</h4>
            <ul>
              <li>Gemini 2.5 Flash core</li>
              <li>Clinical triage guardrails</li>
              <li>Edge-TTS neural voice</li>
              <li>Streaming Urdu audio (<2s)</li>
              <li>English voice synthesis</li>
              <li>Longitudinal health memory</li>
              <li>Lab report OCR explainer</li>
              <li>Ultrasound text parser</li>
              <li>Doctor question drafter</li>
            </ul>
          </div>
          <div class="matrix-col">
            <h4>Care & Doctors</h4>
            <ul>
              <li>Show My Doctor QR link</li>
              <li>Zero-install web summary</li>
              <li>Oladoc verified specialists</li>
              <li>80+ doctor directory</li>
              <li>Gynae & oncology filters</li>
              <li>PMDC verification tags</li>
              <li>Fee & rating transparency</li>
              <li>One-tap 1122 ambulance</li>
              <li>Radius hospital finder</li>
            </ul>
          </div>
          <div class="matrix-col">
            <h4>Accessibility</h4>
            <ul>
              <li>Full native RTL mirroring</li>
              <li>Bundled Noto Nastaliq</li>
              <li>Bilingual Urdu/English</li>
              <li>Instant language switcher</li>
              <li>Live language preview</li>
              <li>Low-literacy voice mode</li>
              <li>Illustrated palpation guide</li>
              <li>WHO self-exam protocol</li>
              <li>Cultural empathy tuning</li>
            </ul>
          </div>
          <div class="matrix-col">
            <h4>Privacy & System</h4>
            <ul>
              <li>100% on-device health store</li>
              <li>Zero cloud health tracking</li>
              <li>Ephemeral image scanning</li>
              <li>Anonymous guest mode</li>
              <li>Firebase auth isolation</li>
              <li>26 MB split release APK</li>
              <li>Boot-resilient alarms</li>
              <li>Clinical PDF export</li>
              <li>60 fps fluid animations</li>
            </ul>
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">25</div>
      </div>
    </div>
    """)

    # ── SLIDE 26: WHO BUILT IT ──
    slides.append(f"""
    <div class="slide light">
      <div>
        <div class="kicker">WHO BUILT IT</div>
        <h1 class="headline">Air University • Department of Creative Technologies</h1>
        <p class="subtext">A flagship healthcare innovation initiative developed in Islamabad, Pakistan, merging state-of-the-art artificial intelligence with compassionate, patient-first clinical engineering.</p>
        <div style="display: grid; grid-template-columns: 1.5fr 1fr; gap: 24pt; margin-top: 14pt;">
          <div style="background: #FFFFFF; border-radius: 14pt; padding: 20pt; border: 1px solid #F1E5EC; box-shadow: 0 8pt 24pt rgba(157, 23, 77, 0.03);">
            <h3 style="font-size: 13pt; font-weight: 800; color: #0F172A; margin-bottom: 8pt;">Our Clinical Engineering Mission</h3>
            <p style="font-size: 9.5pt; color: #475569; line-height: 1.5; margin-bottom: 12pt;">
              In developing countries, millions of women suffer in silence from undiagnosed polycystic ovarian syndrome and delayed breast malignancies due to social stigma, lack of female physicians, and fragmented paper record systems.
            </p>
            <p style="font-size: 9.5pt; color: #475569; line-height: 1.5;">
              Femora democratizes early diagnostic screening by placing clinical-grade computer vision, biological hormone intelligence, and verified specialist care directly into the hands of every woman — privately, securely, and free from judgment.
            </p>
          </div>
          <div style="background: #FFF1F2; border-radius: 14pt; padding: 20pt; border: 1px solid #FFE4E6; display: flex; flex-direction: column; justify-content: space-between;">
            <div>
              <div style="font-size: 8pt; font-weight: 800; color: #9D174D; letter-spacing: 1.2pt; text-transform: uppercase; margin-bottom: 6pt;">PROJECT CREDENTIALS</div>
              <div style="font-size: 12pt; font-weight: 800; color: #0F172A; margin-bottom: 4pt;">Ammad Sajjad & Engineering Team</div>
              <div style="font-size: 9pt; color: #64748B; margin-bottom: 12pt;">Supervised by Faculty of Computing & AI, Air University</div>
            </div>
            <div style="display: flex; flex-direction: column; gap: 6pt; font-size: 8.8pt; color: #334155;">
              <div>• <strong>400 Unit & Widget Tests:</strong> 100% pass rate</div>
              <div>• <strong>174 Backend Tests:</strong> pytest validated</div>
              <div>• <strong>91.2% Clinical Validation:</strong> BUSI & Rotterdam</div>
              <div>• <strong>26.3 MB Split APK:</strong> Android production ready</div>
            </div>
          </div>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora • Women's Health Platform</div>
        <div class="footer-page">26</div>
      </div>
    </div>
    """)

    # ── SLIDE 27: CLOSING CALL TO ACTION ──
    slides.append(f"""
    <div class="slide dark">
      <div class="cta-layout">
        <div>
          <div class="cover-logo-row">
            <img class="cover-logo" src="{img_logo}">
            <div>
              <div class="cover-brand-title">Femora</div>
              <div class="cover-brand-sub">TRANSFORMING WOMEN'S HEALTH</div>
            </div>
          </div>
          <h1 class="headline" style="font-size: 32pt;">Clinical care that <span class="highlight-gold">every woman deserves.</span></h1>
          <p class="subtext">Femora puts early AI detection, hormone tracking, lab report intelligence, and verified doctor access in her hands — privately, reliably, and completely on her terms.</p>
          <div style="display: flex; flex-direction: column; gap: 8pt; margin-top: 14pt;">
            <div style="display: flex; align-items: center; gap: 8pt; font-size: 9.5pt; color: #E2E8F0;">
              <span style="color: #10B981; font-weight: 800;">✓</span> Dual-Model PCOS & Thermal Breast Cancer AI Screening
            </div>
            <div style="display: flex; align-items: center; gap: 8pt; font-size: 9.5pt; color: #E2E8F0;">
              <span style="color: #10B981; font-weight: 800;">✓</span> 4-Phase Hormone Radar & Touchless Optical PPG Heart Rate
            </div>
            <div style="display: flex; align-items: center; gap: 8pt; font-size: 9.5pt; color: #E2E8F0;">
              <span style="color: #10B981; font-weight: 800;">✓</span> 24/7 AI Medical Companion with Fluent Urdu & English Neural Voice
            </div>
            <div style="display: flex; align-items: center; gap: 8pt; font-size: 9.5pt; color: #E2E8F0;">
              <span style="color: #10B981; font-weight: 800;">✓</span> Instant "Show My Doctor" QR Web Clinician Portal
            </div>
          </div>
        </div>
        <div class="cta-box">
          <h3>Test the Platform Today</h3>
          <div class="cta-row">
            <div class="cta-item"><span class="cta-label">MOBILE APP:</span><span>femora-release-arm64.apk (26.3 MB)</span></div>
            <div class="cta-item"><span class="cta-label">DOCTOR WEB:</span><span>femora.web.app</span></div>
            <div class="cta-item"><span class="cta-label">AI BACKEND:</span><span>mel-causing-soma-lasting.trycloudflare.com</span></div>
            <div class="cta-item"><span class="cta-label">GITHUB:</span><span>github.com/ammad-sajjad/Femora</span></div>
            <div class="cta-item"><span class="cta-label">CAMPUS:</span><span>Air University, PAF Complex E-9, Islamabad</span></div>
          </div>
          <a class="cta-btn" href="https://github.com/ammad-sajjad/Femora">Explore Femora on GitHub</a>
        </div>
      </div>
      <div class="slide-footer">
        <div class="footer-brand"><img class="footer-logo" src="{img_logo}"> Femora Health Technologies • Air University Islamabad</div>
        <div class="footer-page">27</div>
      </div>
    </div>
    """)

    full_html = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Femora - Product & Marketing Presentation Deck</title>
  <style>
    {CSS}
  </style>
</head>
<body>
  {"".join(slides)}
</body>
</html>
"""
    with open(HTML_OUT, "w", encoding="utf-8") as f:
        f.write(full_html)
    print(f"Generated HTML deck at {HTML_OUT} ({len(full_html)/1024:.1f} KB)")

if __name__ == "__main__":
    generate_html()
