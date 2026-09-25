import 'package:femora/models/cycle_engine.dart';
import 'package:femora/models/doctor_link.dart';
import 'package:femora/models/doctor_summary.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/models/report_reader.dart';
import 'package:femora/models/self_exam.dart';
import 'package:femora/screens/doctor_qr_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_reminders.dart';

final _now = DateTime(2026, 9, 20, 9, 30);

HealthStore _fullStore() {
  final s = HealthStore()
    ..now = (() => _now)
    ..profile = HealthProfile(name: 'Ayesha Khan', age: 27, heightCm: 162, weightKg: 68, onboarded: true);
  s.periods = [for (final ago in [92, 64, 36, 8]) PeriodEntry(start: _now.subtract(Duration(days: ago)), end: _now.subtract(Duration(days: ago - 4)))];
  s.pcos = PcosSummary(date: _now, percent: 71, level: 'high', bmi: 25.9, factors: const ['Irregular cycles', 'Acne']);
  s.breastRisk = BreastRiskSummary(
      date: _now, probability: 0.0062, average: 0.0042, relativeRisk: 1.66, level: 'medium', ageGroup: '25-29', factors: const [], redFlags: const ['Breast lump']);
  s.scan = ScanSummary(date: _now, prediction: 'benign', title: 'Likely Benign', confidence: 0.9, probabilities: const {'normal': 0.02, 'benign': 0.9, 'malignant': 0.08}, modelAccuracy: 0.718);
  s.logs = [for (var i = 0; i < 6; i++) SymptomLog(date: _now.subtract(Duration(days: i)), symptoms: i.isEven ? const ['cramps'] : const ['headache'], mood: 'good')];
  s.reports = [
    ExplainedReport(
      date: _now,
      kind: 'blood_test',
      summary: '',
      findings: const [
        ReportFinding(name: 'Hemoglobin', value: '10.8', unit: 'g/dL', status: 'low', explanation: ''),
        ReportFinding(name: 'TSH', value: '2.1', status: 'normal', explanation: ''),
      ],
      questions: const [],
      urgency: 'none',
      language: 'en',
      disclaimer: '',
    ),
  ];
  return s;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the summary gives a doctor the essentials in plain English, short enough for a scannable QR', () {
    final text = DoctorSummary.build(_fullStore(), lastSelfExam: _now.subtract(const Duration(days: 3)));
    expect(text, startsWith('FEMORA HEALTH SUMMARY'));
    expect(text, contains('Ayesha Khan, 27 y, BMI 25.9'));
    expect(text, contains('LMP 12 Sep (day 9)'));
    expect(text, contains('avg 28 d over 3 cycles'));
    expect(text, contains('PCOS screen (20 Sep): high risk (71%); Irregular cycles, Acne'));
    expect(text, contains('1.7x average for age 25-29; REPORTS: Breast lump'));
    expect(text, contains('Likely Benign, P(malignant) 8%'));
    expect(text, contains('Hemoglobin 10.8 g/dL (low)'));
    expect(text, isNot(contains('TSH'))); // only out-of-range values
    expect(text, contains('cramps 3d, headache 3d'));
    expect(text, contains('Last self-exam: 17 Sep'));
    expect(text.length, lessThanOrEqualTo(DoctorSummary.maxLength));
  });

  test('with nothing logged the summary says so', () {
    final s = HealthStore()..now = (() => _now);
    expect(DoctorSummary.build(s), contains('No results logged yet.'));
  });

  test('the link carries the whole report, compressed after the # so it never reaches a server', () {
    final store = _fullStore();
    final link = DoctorLink.build(store, lastSelfExam: _now.subtract(const Duration(days: 3)));
    expect(link, startsWith('https://femora.web.app/#r='));
    expect(link.length, lessThanOrEqualTo(DoctorLink.maxLength));
    // ignore: avoid_print
    print('full report link: ${link.length} characters');
    final r = DoctorLink.decode(link.split('#r=').last);
    expect(r['p'], {'n': 'Ayesha Khan', 'a': 27, 'h': 162, 'w': 68});
    expect(r['pc'], {'d': 0, 'pct': 71, 'lv': 'high', 'bmi': 259, 'f': ['Irregular cycles', 'Acne']});
    expect(r['sc']['pb'], [2, 90, 8]);
    expect(r['br']['rf'], ['Breast lump']);
    expect(r['cy']['ls'], -8); // last period 8 days before the report
    expect(r['cy']['cd'], 9);
    expect(r['wl']['ex'], -3);
    expect(r['lab']['f'], [['Hemoglobin', '10.8', 'g/dL', 'low']]); // only out-of-range values
    expect((r['id'] as String), startsWith('FEM-260920-'));
  });

  test('a very full report drops the daily charts first to stay scannable', () {
    final store = _fullStore();
    store.logs = [
      for (var i = 0; i < 30; i++)
        SymptomLog(date: _now.subtract(Duration(days: i)), symptoms: const ['cramps', 'headache', 'bloating', 'acne'], mood: 'okay', sleepHours: 6.5 + (i % 3), stress: 1 + i % 5, energy: 1 + (i * 7) % 5),
    ];
    final link = DoctorLink.build(store);
    expect(link.length, lessThanOrEqualTo(DoctorLink.maxLength));
    final wl = DoctorLink.decode(link.split('#r=').last)['wl'] as Map<String, dynamic>;
    expect(wl['lc'], 30); // the averages stay even when the charts go
  });

  testWidgets('the screen shows a QR code holding the report link, and a preview of the page', (tester) async {
    final store = _fullStore();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: SelfExamState(reminders: Recorder())),
      ],
      child: const MaterialApp(home: DoctorQrScreen()),
    ));
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsOneWidget);
    expect(find.textContaining('nothing is uploaded'), findsOneWidget);
    expect(find.byKey(const Key('doctor_qr_preview')), findsOneWidget);
  });
}
