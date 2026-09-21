import 'dart:convert';

import 'package:femora/models/cycle_engine.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/services/report_service.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 20, 14, 5);

ReportData _empty() => ReportData(
      profile: HealthProfile(onboarded: true),
      pcos: null,
      scan: null,
      scanImage: null,
      breastRisk: null,
      lastSelfExam: null,
      logs: const [],
      generated: _now,
    );

bool _isPdf(List<int> b) => b.length > 1000 && latin1.decode(b.sublist(0, 5)) == '%PDF-';

int _pageCount(List<int> bytes) => RegExp(r'/Type\s*/Page[^s]').allMatches(latin1.decode(bytes, allowInvalid: true)).length;

void main() {
  test('an empty report is still a valid PDF that says nothing has been done yet', () async {
    final bytes = await buildReport(_empty());
    expect(_isPdf(bytes), isTrue);
    expect(_pageCount(bytes), greaterThanOrEqualTo(1));
  });

  test('the sample report is a valid PDF and is bigger than the empty one', () async {
    final sample = await buildReport(ReportData.sample(now: _now));
    final empty = await buildReport(_empty());
    expect(_isPdf(sample), isTrue);
    expect(sample.length, greaterThan(empty.length));
  });

  test('a full real report with an image builds', () async {
    final s = ReportData.sample(now: _now);
    final full = ReportData(
      profile: s.profile,
      pcos: s.pcos,
      scan: s.scan,
      scanImage: base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='),
      breastRisk: BreastRiskSummary(
        date: _now,
        probability: 0.0062,
        average: 0.0042,
        relativeRisk: 1.66,
        level: 'medium',
        ageGroup: '50-54',
        factors: const ['Family History', 'Previous Biopsy'],
        redFlags: const ['Breast Lump (urgent)'],
      ),
      lastSelfExam: _now.subtract(const Duration(days: 45)),
      logs: s.logs,
      generated: _now,
    );
    final bytes = await buildReport(full);
    expect(_isPdf(bytes), isTrue);
  });

  test('a malignant-looking result and non-Latin names do not break the report', () async {
    final s = ReportData.sample(now: _now);
    final data = ReportData(
      profile: HealthProfile(name: 'عائشہ خان', age: 30, heightCm: 160, weightKg: 55, onboarded: true),
      pcos: s.pcos,
      scan: ScanSummary(date: _now, prediction: 'malignant', title: 'Suspicious Finding', confidence: 0.91, probabilities: const {'normal': 0.01, 'benign': 0.08, 'malignant': 0.91}, modelAccuracy: 0.718),
      scanImage: null,
      breastRisk: s.breastRisk,
      lastSelfExam: null,
      logs: const [],
      generated: _now,
    );
    expect(_isPdf(await buildReport(data)), isTrue);
  });

  test('many log entries spill over to further pages without failing', () async {
    final s = ReportData.sample(now: _now);
    final data = ReportData(
      profile: s.profile,
      pcos: s.pcos,
      scan: s.scan,
      scanImage: null,
      breastRisk: s.breastRisk,
      lastSelfExam: s.lastSelfExam,
      logs: [for (var i = 0; i < 60; i++) SymptomLog(date: _now.subtract(Duration(days: i)), symptoms: const ['fatigue', 'cramps', 'acne', 'nausea'], mood: 'low', notes: 'n' * 200)],
      generated: _now,
    );
    expect(_isPdf(await buildReport(data)), isTrue);
  });

  test('cycle data adds a panel: the report with periods is bigger than the same report without', () async {
    final s = ReportData.sample(now: _now);
    expect(s.periods, hasLength(5));
    final without = ReportData(profile: s.profile, pcos: s.pcos, scan: s.scan, scanImage: null, breastRisk: s.breastRisk, lastSelfExam: s.lastSelfExam, logs: s.logs, generated: _now);
    final withCycle = ReportData(profile: s.profile, pcos: s.pcos, scan: s.scan, scanImage: null, breastRisk: s.breastRisk, lastSelfExam: s.lastSelfExam, logs: s.logs, periods: s.periods, generated: _now);
    final a = await buildReport(without);
    final b = await buildReport(withCycle);
    expect(_isPdf(b), isTrue);
    expect(b.length, greaterThan(a.length));
  });

  test('late, irregular and one-period cycle histories all build', () async {
    final s = ReportData.sample(now: _now);
    ReportData with_(List<PeriodEntry> ps) => ReportData(profile: s.profile, pcos: s.pcos, scan: null, scanImage: null, breastRisk: null, lastSelfExam: null, logs: const [], periods: ps, generated: _now);
    DateTime ago(int n) => _now.subtract(Duration(days: n));
    for (final ps in [
      [for (final n in [100, 72, 44]) PeriodEntry(start: ago(n), end: ago(n - 4))], // 12+ days late
      [for (final n in [155, 131, 95, 68, 30]) PeriodEntry(start: ago(n), end: ago(n - 5))], // irregular
      [PeriodEntry(start: ago(3))], // first period, still ongoing
      [PeriodEntry(start: ago(40), end: ago(28))], // 13-day period
    ]) {
      expect(_isPdf(await buildReport(with_(ps))), isTrue);
    }
  });

  test('report ids look like lab report numbers and differ between patients', () {
    final a = reportId(ReportData.sample(now: _now));
    expect(RegExp(r'^FEM-260920-[0-9A-Z]{6}$').hasMatch(a), isTrue, reason: a);
    final other = ReportData(profile: HealthProfile(name: 'Someone Else', age: 31), pcos: null, scan: null, scanImage: null, breastRisk: null, lastSelfExam: null, logs: const [], generated: _now);
    expect(reportId(other), isNot(a));
  });

  test('the sample data is clearly marked as a sample', () {
    final s = ReportData.sample(now: _now);
    expect(s.isSample, isTrue);
    expect(s.profile.name, 'Sample Patient');
    expect(ReportData.fromStore(HealthStore(), now: _now).isSample, isFalse);
  });
}
