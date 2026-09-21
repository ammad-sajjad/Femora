import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/cycle_engine.dart';
import '../models/health_store.dart';

/// Everything the report shows, gathered in one place (from the on-device store, or sample data for demos).
class ReportData {
  final HealthProfile profile;
  final PcosSummary? pcos;
  final ScanSummary? scan;
  final Uint8List? scanImage; // heatmap of the latest scan
  final BreastRiskSummary? breastRisk;
  final DateTime? lastSelfExam;
  final List<SymptomLog> logs;
  final List<PeriodEntry> periods;
  final DateTime generated;
  final bool isSample;

  const ReportData({
    required this.profile,
    required this.pcos,
    required this.scan,
    required this.scanImage,
    required this.breastRisk,
    required this.lastSelfExam,
    required this.logs,
    required this.generated,
    this.periods = const [],
    this.isSample = false,
  });

  factory ReportData.fromStore(HealthStore store, {DateTime? lastSelfExam, DateTime? now}) => ReportData(
        profile: store.profile,
        pcos: store.pcos,
        scan: store.scan,
        scanImage: store.scanHeatmap,
        breastRisk: store.breastRisk,
        lastSelfExam: lastSelfExam,
        logs: store.logs,
        periods: store.periods,
        generated: now ?? DateTime.now(),
      );

  /// Clearly marked demo data, for showing the report without entering anything.
  factory ReportData.sample({DateTime? now, Uint8List? scanImage}) {
    final n = now ?? DateTime.now();
    final day = DateTime(n.year, n.month, n.day);
    return ReportData(
      profile: HealthProfile(name: 'Sample Patient', age: 27, heightCm: 162, weightKg: 68, concerns: {'pcos', 'breast'}, onboarded: true),
      pcos: PcosSummary(date: day.subtract(const Duration(days: 2)), percent: 71, level: 'high', bmi: 25.9, factors: const ['Irregular Cycles', 'Weight Gain', 'Acne']),
      scan: ScanSummary(
        date: day.subtract(const Duration(days: 1)),
        prediction: 'benign',
        title: 'Likely Benign',
        confidence: 0.88,
        probabilities: const {'normal': 0.05, 'benign': 0.88, 'malignant': 0.07},
        modelAccuracy: 0.718,
      ),
      scanImage: scanImage,
      breastRisk: BreastRiskSummary(
        date: day.subtract(const Duration(days: 1)),
        probability: 0.0033,
        average: 0.0034,
        relativeRisk: 0.99,
        level: 'low',
        ageGroup: '45-49',
        factors: const [],
        redFlags: const [],
      ),
      lastSelfExam: day.subtract(const Duration(days: 12)),
      logs: [
        for (var i = 6; i >= 0; i--)
          SymptomLog(
            date: day.subtract(Duration(days: i)),
            symptoms: i.isEven ? const ['fatigue', 'cramps'] : const ['acne'],
            mood: const ['okay', 'low', 'good', 'okay', 'low', 'okay', 'good'][i],
          ),
      ],
      periods: [for (final ago in [118, 90, 62, 34, 6]) PeriodEntry(start: day.subtract(Duration(days: ago)), end: day.subtract(Duration(days: ago - 4)))],
      generated: n,
      isSample: true,
    );
  }
}

const _berry = PdfColor.fromInt(0xFF9E1B46);
const _ink = PdfColor.fromInt(0xFF2C2538);
const _muted = PdfColor.fromInt(0xFF6E6A7A);
const _line = PdfColor.fromInt(0xFFD9C3CC);
const _tint = PdfColor.fromInt(0xFFFBE9EF);
const _red = PdfColor.fromInt(0xFFC62828);
const _amber = PdfColor.fromInt(0xFFB26A00);
const _green = PdfColor.fromInt(0xFF2E7D32);

const _interestLabels = {'pcos': 'PCOS', 'cycle': 'Cycle tracking', 'pregnancy': 'Pregnancy', 'breast': 'Breast health'};

/// Base PDF fonts only cover Latin text: replace anything else so nothing is drawn as an empty box.
String _t(String s) => s.replaceAll(RegExp(r'[^\x20-\x7E -ÿ]'), '?');

String reportId(ReportData d) {
  final seed = '${d.profile.name}${d.profile.age}${d.pcos?.date}${d.scan?.date}${d.breastRisk?.date}${d.generated.millisecondsSinceEpoch ~/ 60000}';
  var h = 7;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return 'FEM-${DateFormat('yyMMdd').format(d.generated)}-${h.toRadixString(36).toUpperCase().padLeft(6, '0').substring(0, 6)}';
}

Future<Uint8List> buildReport(ReportData d) async {
  final doc = pw.Document(title: 'Femora Health Screening Report', author: 'Femora', creator: 'Femora app', subject: 'AI screening summary');
  final id = reportId(d);
  final when = DateFormat('d MMM yyyy, HH:mm').format(d.generated);

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 28, 34, 44),
        buildBackground: d.isSample
            ? (ctx) => pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Center(
                    child: pw.Transform.rotate(
                      angle: 0.62,
                      child: pw.Text('SAMPLE DATA', style: pw.TextStyle(fontSize: 78, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFF2E6EB))),
                    ),
                  ),
                )
            : null,
      ),
      header: (ctx) => _header(id, when),
      footer: (ctx) => _footer(ctx, id),
      build: (ctx) => [
        pw.SizedBox(height: 8),
        _patientBlock(d, id, when),
        pw.SizedBox(height: 12),
        _summaryBox(d),
        pw.SizedBox(height: 14),
        _pcosPanel(d),
        _scanPanel(d),
        _riskPanel(d),
        _cyclePanel(d),
        _wellnessPanel(d),
        _nextSteps(d),
        pw.SizedBox(height: 14),
        _clinicianBox(),
        pw.SizedBox(height: 10),
        _disclaimer(),
      ],
    ),
  );
  return doc.save();
}

// ---------------------------------------------------------------- page furniture

pw.Widget _header(String id, String when) => pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _berry, width: 1.6))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('femora', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: _berry)),
              pw.Text("AI WOMEN'S HEALTH SCREENING REPORT", style: pw.TextStyle(fontSize: 8.5, letterSpacing: 1.2, color: _muted, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Report ID: $id', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _ink)),
              pw.Text('Generated: $when', style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
            ],
          ),
        ],
      ),
    );

pw.Widget _footer(pw.Context ctx, String id) => pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _line, width: 0.6))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              'Femora AI screening summary for awareness. Not a laboratory report, not a clinical record and not a medical diagnosis. Always confirm with a doctor.',
              style: const pw.TextStyle(fontSize: 7.2, color: _muted),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Text('$id   Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: _muted)),
        ],
      ),
    );

pw.Widget _patientBlock(ReportData d, String id, String when) {
  final p = d.profile;
  final bmi = p.bmi;
  pw.Widget cell(String k, String v) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(k.toUpperCase(), style: pw.TextStyle(fontSize: 6.8, letterSpacing: 0.8, color: _muted, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 1.5),
            pw.Text(_t(v), style: pw.TextStyle(fontSize: 10, color: _ink, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );
  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all(color: _line, width: 0.8), borderRadius: pw.BorderRadius.circular(5)),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Table(
            columnWidths: const {0: pw.FlexColumnWidth(1.3), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1.1)},
            children: [
              pw.TableRow(children: [
                cell('Patient name', p.name.isEmpty ? 'Not provided' : p.name),
                cell('Age / sex', '${p.age ?? '-'} years / Female'),
                cell('Report date', DateFormat('d MMM yyyy').format(d.generated)),
              ]),
              pw.TableRow(children: [
                cell('Height / weight', '${p.heightCm == null ? '-' : '${p.heightCm!.round()} cm'} / ${p.weightKg == null ? '-' : '${p.weightKg!.round()} kg'}'),
                cell('BMI', bmi == null ? '-' : '${bmi.toStringAsFixed(1)} kg/m2'),
                cell('Interests', p.concerns.isEmpty ? '-' : p.concerns.map((c) => _interestLabels[c] ?? c).join(', ')),
              ]),
            ],
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: 'FEMORA:$id', width: 52, height: 52, drawText: false),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- summary and panels

({String label, PdfColor colour}) _levelStyle(String level) => switch (level) {
      'high' => (label: 'HIGH', colour: _red),
      'medium' => (label: 'MEDIUM', colour: _amber),
      _ => (label: 'LOW', colour: _green),
    };

pw.Widget _summaryBox(ReportData d) {
  final points = <String>[
    if (d.pcos != null) 'PCOS screening: ${d.pcos!.percent}% probability (${_levelStyle(d.pcos!.level).label}).',
    if (d.scan != null) 'Breast ultrasound screening: ${d.scan!.title} (${(d.scan!.confidence * 100).round()}% model confidence).',
    if (d.breastRisk != null) 'Breast cancer risk: ${d.breastRisk!.relativeRisk.toStringAsFixed(2)} x the age average (${_levelStyle(d.breastRisk!.level).label}).',
    if (d.breastRisk != null && d.breastRisk!.redFlags.isNotEmpty) 'Reported symptoms needing a doctor: ${d.breastRisk!.redFlags.join(', ')}.',
    if (d.periods.isNotEmpty) _cycleSummaryLine(CycleEngine(d.periods, d.generated)),
  ];
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(color: _tint, borderRadius: pw.BorderRadius.circular(5), border: pw.Border.all(color: _line, width: 0.6)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('SUMMARY OF FINDINGS', style: pw.TextStyle(fontSize: 8.5, letterSpacing: 1, fontWeight: pw.FontWeight.bold, color: _berry)),
        pw.SizedBox(height: 5),
        if (points.isEmpty)
          pw.Text('No screening has been completed yet. Complete the PCOS check, the breast questionnaire or an ultrasound scan in the Femora app to fill this report.',
              style: const pw.TextStyle(fontSize: 9.5, color: _ink))
        else
          for (final p in points)
            pw.Padding(padding: const pw.EdgeInsets.only(bottom: 2.5), child: pw.Text('-  $p', style: const pw.TextStyle(fontSize: 9.5, color: _ink))),
      ],
    ),
  );
}

pw.Widget _panelTitle(String title, String date) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 6, bottom: 4),
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      decoration: const pw.BoxDecoration(color: _berry),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 9.5, letterSpacing: 0.8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          pw.Text(date, style: const pw.TextStyle(fontSize: 8, color: PdfColors.white)),
        ],
      ),
    );

/// One lab-style result table: test | result | reference | flag.
pw.Widget _resultTable(List<({String test, String result, String reference, String flag, PdfColor colour})> rows) {
  pw.Widget head(String t) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 6),
        child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _ink)),
      );
  pw.Widget body(String t, {bool bold = false, PdfColor colour = _ink}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 6),
        child: pw.Text(_t(t), style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: colour)),
      );
  return pw.Table(
    border: pw.TableBorder(
      horizontalInside: const pw.BorderSide(color: _line, width: 0.5),
      bottom: const pw.BorderSide(color: _line, width: 0.8),
    ),
    columnWidths: const {0: pw.FlexColumnWidth(2.6), 1: pw.FlexColumnWidth(1.7), 2: pw.FlexColumnWidth(3), 3: pw.FlexColumnWidth(1.1)},
    children: [
      pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF3ECEF)), children: [head('TEST'), head('RESULT'), head('REFERENCE / INTERPRETATION'), head('FLAG')]),
      for (final r in rows)
        pw.TableRow(children: [body(r.test), body(r.result, bold: true), body(r.reference), body(r.flag, bold: true, colour: r.colour)]),
    ],
  );
}

pw.Widget _note(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4, bottom: 6),
      child: pw.Text(_t(text), style: pw.TextStyle(fontSize: 8.6, color: _muted, fontStyle: pw.FontStyle.italic)),
    );

pw.Widget _pending(String title, String text) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [_panelTitle(title, 'Not done yet'), _note(text)],
    );

pw.Widget _pcosPanel(ReportData d) {
  const title = 'PANEL 1: PCOS RISK SCREENING';
  final p = d.pcos;
  if (p == null) return _pending(title, 'The PCOS questionnaire has not been completed. Use the PCOS tab in the app.');
  final s = _levelStyle(p.level);
  final bmiFlag = p.bmi < 18.5 ? ('L', _amber) : p.bmi >= 25 ? ('H', _amber) : ('NORMAL', _green);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _panelTitle(title, DateFormat('d MMM yyyy').format(p.date)),
      _resultTable([
        (test: 'PCOS risk probability', result: '${p.percent} %', reference: 'Low < 30 %   Medium 30-60 %   High >= 60 %', flag: s.label, colour: s.colour),
        (test: 'Body mass index (BMI)', result: '${p.bmi.toStringAsFixed(1)} kg/m2', reference: '18.5 - 24.9 kg/m2', flag: bmiFlag.$1, colour: bmiFlag.$2),
        (test: 'Main contributing answers', result: p.factors.isEmpty ? 'None' : '${p.factors.length} noted', reference: p.factors.isEmpty ? '-' : p.factors.join('; '), flag: '-', colour: _muted),
      ]),
      _note(p.level == 'low'
          ? 'Interpretation: the answers given show few patterns commonly seen with PCOS. Keep tracking your cycle.'
          : 'Interpretation: the answers match patterns commonly seen with PCOS. This is a screening estimate from self-reported answers, not a diagnosis. '
              'A gynecologist can confirm with an ultrasound and hormone blood tests (LH, FSH, AMH, testosterone).'),
    ],
  );
}

pw.Widget _scanPanel(ReportData d) {
  const title = 'PANEL 2: BREAST ULTRASOUND AI SCREENING';
  final s = d.scan;
  if (s == null) return _pending(title, 'No ultrasound image has been analysed. Use the Breast tab in the app.');
  final flagged = s.prediction == 'malignant';
  final pr = s.probabilities;
  String pct(String k) => '${((pr[k] ?? 0) * 100).round()} %';
  final table = _resultTable([
    (test: 'AI classification', result: s.title, reference: 'Normal / Benign / Suspicious (malignant)', flag: flagged ? 'REVIEW' : s.prediction == 'benign' ? 'BENIGN' : 'NORMAL', colour: flagged ? _red : _green),
    (test: 'Model confidence', result: '${(s.confidence * 100).round()} %', reference: 'Calibrated probability of the predicted class', flag: '-', colour: _muted),
    (test: 'Class probabilities', result: 'N ${pct('normal')}', reference: 'Benign ${pct('benign')}   Malignant ${pct('malignant')}', flag: '-', colour: _muted),
    (test: 'Flagging rule', result: '>= 25 %', reference: 'Flagged suspicious when the malignant probability is 25 % or more', flag: '-', colour: _muted),
    (test: 'Model accuracy (held-out scans)', result: '${(s.modelAccuracy * 100).round()} %', reference: 'About 89 % of cancers caught; benign scans are often flagged', flag: '-', colour: _muted),
  ]);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _panelTitle(title, DateFormat('d MMM yyyy').format(s.date)),
      if (d.scanImage != null)
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: table),
          pw.SizedBox(width: 10),
          pw.Column(children: [
            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(color: _line, width: 0.6)),
              child: pw.Image(pw.MemoryImage(d.scanImage!), width: 128, height: 100, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(height: 2),
            pw.Text('AI focus map (illustrative)', style: const pw.TextStyle(fontSize: 7, color: _muted)),
          ]),
        ])
      else
        table,
      _note(flagged
          ? 'Interpretation: the scan has features doctors want to look at more closely. This is not a diagnosis. A breast specialist will usually examine you and may recommend a biopsy; please arrange this soon.'
          : 'Interpretation: the area found was rated as most likely ${s.prediction == 'normal' ? 'normal' : 'benign (not cancer)'}. The AI can miss cancers and can flag benign scans; follow your doctor\'s advice about follow-up imaging.'),
    ],
  );
}

pw.Widget _riskPanel(ReportData d) {
  const title = 'PANEL 3: BREAST CANCER RISK ASSESSMENT';
  final r = d.breastRisk;
  if (r == null) return _pending(title, 'The breast risk questionnaire has not been completed. Use the Breast tab in the app.');
  final s = _levelStyle(r.level);
  final urgent = r.redFlags.isNotEmpty;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _panelTitle(title, DateFormat('d MMM yyyy').format(r.date)),
      _resultTable([
        (test: 'One-year risk estimate', result: '${(r.probability * 100).toStringAsFixed(2)} %', reference: 'Average for age ${r.ageGroup}: ${(r.average * 100).toStringAsFixed(2)} %', flag: '-', colour: _muted),
        (test: 'Relative risk (vs age average)', result: '${r.relativeRisk.toStringAsFixed(2)} x', reference: 'Low < 1.35   Medium 1.35-2.4   High > 2.4', flag: s.label, colour: s.colour),
        (test: 'Answers that raised the estimate', result: r.factors.isEmpty ? 'None' : '${r.factors.length}', reference: r.factors.isEmpty ? '-' : r.factors.join('; '), flag: '-', colour: _muted),
        (test: 'Reported symptoms', result: urgent ? '${r.redFlags.length}' : 'None', reference: urgent ? r.redFlags.join('; ') : 'No symptoms needing a doctor were reported', flag: urgent ? 'SEE DOCTOR' : '-', colour: urgent ? _red : _muted),
      ]),
      _note('Interpretation: this is an estimate of the chance of a breast cancer diagnosis in the next year from risk factors (BCSC data). It cannot say whether cancer is present. Reported symptoms follow NICE referral guidance and need a doctor regardless of the estimate.'),
    ],
  );
}

String _cycleSummaryLine(CycleEngine e) {
  final avg = e.averageLength == null ? '' : ', average cycle ${e.averageLength!.toStringAsFixed(1)} days (${e.regularity})';
  return 'Menstrual cycle: ${e.n} cycle${e.n == 1 ? '' : 's'} logged$avg.';
}

List<String> _cycleSteps(ReportData d) {
  if (d.periods.isEmpty) return const [];
  final e = CycleEngine(d.periods, d.generated);
  return [for (final f in e.flags) if (f.seeDoctor) f.text];
}

pw.Widget _cyclePanel(ReportData d) {
  const title = 'PANEL 4: MENSTRUAL CYCLE';
  if (d.periods.isEmpty) return _pending(title, 'No periods have been logged. Use the Cycle tab in the app to log the first day of your last period.');
  final e = CycleEngine(d.periods, d.generated);
  String date(DateTime x) => DateFormat('d MMM yyyy').format(x);
  final avg = e.averageLength;
  final per = e.averagePeriod;
  final avgFlag = avg == null ? ('-', _muted) : (avg < 21 || avg > 35) ? ('REVIEW', _amber) : ('NORMAL', _green);
  final regFlag = e.regularity == 'irregular' ? ('REVIEW', _amber) : e.regularity == 'regular' ? ('REGULAR', _green) : ('-', _muted);
  final perFlag = per == null ? ('-', _muted) : per > 7 ? ('REVIEW', _amber) : ('NORMAL', _green);
  final late = e.isLate;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _panelTitle(title, date(e.lastStart!)),
      _resultTable([
        (test: 'Cycles logged (complete)', result: '${e.n}', reference: 'At least 3 give a personal prediction', flag: '-', colour: _muted),
        (test: 'Average cycle length', result: avg == null ? 'Not enough data' : '${avg.toStringAsFixed(1)} days', reference: '21 - 35 days', flag: avgFlag.$1, colour: avgFlag.$2),
        (test: 'Cycle regularity', result: e.regularity, reference: e.spread == null ? 'Longest minus shortest of recent cycles: 7 days or less' : 'Recent cycles differ by ${e.spread} days (regular: 7 or less)', flag: regFlag.$1, colour: regFlag.$2),
        (test: 'Average period length', result: per == null ? 'Not logged' : '${per.toStringAsFixed(1)} days', reference: '2 - 7 days', flag: perFlag.$1, colour: perFlag.$2),
        (test: 'Last period started', result: date(e.lastStart!), reference: e.periodOngoing ? 'Period ongoing: day ${e.cycleDay}' : 'Today is cycle day ${e.cycleDay}', flag: '-', colour: _muted),
        if (late)
          (test: 'Next period', result: 'Late by ${-e.daysUntilNext!} days', reference: 'Expected ${date(e.nextStart!)}', flag: 'LATE', colour: _amber)
        else ...[
          (test: 'Next period (predicted)', result: date(e.nextStart!), reference: 'Likely between ${DateFormat('d MMM').format(e.nextStartEarliest!)} and ${DateFormat('d MMM').format(e.nextStartLatest!)}', flag: '-', colour: _muted),
          (test: 'Ovulation (estimate)', result: DateFormat('d MMM').format(e.ovulation!), reference: 'Fertile window ${DateFormat('d MMM').format(e.fertileStart!)} to ${DateFormat('d MMM').format(e.fertileEnd!)}', flag: '-', colour: _muted),
        ],
      ]),
      _note('Interpretation: ${e.basis} Ovulation and the fertile window are estimates from cycle length, not measurements, and must not be used to avoid pregnancy.'),
      for (final f in e.flags) _note('Note: ${f.text}'),
    ],
  );
}

pw.Widget _wellnessPanel(ReportData d) {
  const title = 'PANEL 5: SELF-EXAMINATION AND WELLNESS LOG';
  final now = d.generated;
  final recent = d.logs.where((l) => now.difference(l.date).inDays < 30).toList();
  final counts = <String, int>{};
  for (final l in recent) {
    for (final s in l.symptoms) {
      counts[s] = (counts[s] ?? 0) + 1;
    }
  }
  final top = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final moods = <String, int>{};
  for (final l in recent) {
    if (l.mood != null) moods[l.mood!] = (moods[l.mood!] ?? 0) + 1;
  }
  final exam = d.lastSelfExam;
  final overdue = exam != null && now.difference(exam).inDays > 30;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _panelTitle(title, 'Last 30 days'),
      _resultTable([
        (
          test: 'Last breast self-exam',
          result: exam == null ? 'Not logged' : DateFormat('d MMM yyyy').format(exam),
          reference: 'Once a month, 3 to 5 days after your period',
          flag: exam == null ? '-' : overdue ? 'DUE' : 'OK',
          colour: overdue ? _amber : exam == null ? _muted : _green
        ),
        (test: 'Daily logs recorded', result: '${recent.length}', reference: 'Days with symptoms, mood or notes saved', flag: '-', colour: _muted),
        (
          test: 'Most frequent symptoms',
          result: top.isEmpty ? 'None' : top.first.key,
          reference: top.isEmpty ? '-' : top.take(4).map((e) => '${e.key} (${e.value}d)').join(';  '),
          flag: '-',
          colour: _muted
        ),
        (
          test: 'Mood pattern',
          result: moods.isEmpty ? 'Not logged' : (moods.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key,
          reference: moods.isEmpty ? '-' : moods.entries.map((e) => '${e.key} ${e.value}d').join(';  '),
          flag: (moods['low'] ?? 0) + (moods['bad'] ?? 0) >= 3 ? 'REVIEW' : '-',
          colour: _amber
        ),
      ]),
      _note('Interpretation: logs are self-reported. Persistent low mood or symptoms that keep returning are worth discussing with a doctor.'),
    ],
  );
}

pw.Widget _nextSteps(ReportData d) {
  final steps = <String>[
    if (d.breastRisk != null && d.breastRisk!.redFlags.isNotEmpty) 'See a doctor about the reported breast symptoms (${d.breastRisk!.redFlags.join(', ')}), ideally within two weeks.',
    if (d.scan != null && d.scan!.prediction == 'malignant') 'Show the ultrasound and this report to a breast specialist soon; a biopsy is the only way to be sure.',
    if (d.pcos != null && d.pcos!.level != 'low') 'Book a gynecologist visit to discuss the PCOS screening; ask about an ultrasound and hormone blood tests.',
    ..._cycleSteps(d),
    if (d.pcos != null && d.pcos!.bmi >= 25) 'Ask about nutrition and activity plans; even modest weight change can help cycles.',
    if (d.breastRisk != null && d.breastRisk!.level != 'low') 'Ask your doctor when to start mammograms and how often, given your risk factors.',
    'Do a breast self-exam every month and keep logging your symptoms, mood and cycle in Femora.',
    'Bring this report to your appointment.',
  ];
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _panelTitle('RECOMMENDED NEXT STEPS', ''),
      for (var i = 0; i < steps.length; i++)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.SizedBox(width: 16, child: pw.Text('${i + 1}.', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _berry))),
            pw.Expanded(child: pw.Text(_t(steps[i]), style: const pw.TextStyle(fontSize: 9.5, color: _ink))),
          ]),
        ),
    ],
  );
}

pw.Widget _clinicianBox() => pw.Container(
      height: 70,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _line, width: 0.8), borderRadius: pw.BorderRadius.circular(5)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('FOR CLINICIAN USE (optional)', style: pw.TextStyle(fontSize: 7.5, letterSpacing: 0.8, fontWeight: pw.FontWeight.bold, color: _muted)),
          pw.Spacer(),
          pw.Row(children: [
            pw.Expanded(child: pw.Text('Notes / plan: ______________________________________________', style: const pw.TextStyle(fontSize: 8, color: _muted))),
            pw.Text('Signature: ____________________', style: const pw.TextStyle(fontSize: 8, color: _muted)),
          ]),
        ],
      ),
    );

pw.Widget _disclaimer() => pw.Text(
      'How to read this report: Femora combines an AI model for breast ultrasound images (ResNet50), a risk model built on BCSC data and a PCOS model built on 541 women from Kerala, India. '
      'Results are estimates with known limits (for example, about one cancer in ten can be missed on ultrasound and many benign scans are flagged). '
      'Nothing here replaces an examination, imaging or tests ordered by a doctor.',
      style: const pw.TextStyle(fontSize: 7.6, color: _muted),
    );
