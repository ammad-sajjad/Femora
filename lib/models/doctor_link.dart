import 'dart:convert';

import 'package:archive/archive.dart';

import '../services/report_service.dart';
import 'analytics.dart';
import 'cycle_engine.dart';
import 'health_store.dart';
import 'hormone_insights.dart';
import 'pulse.dart';

/// "Show my doctor" as a link: the whole report, packed into the QR code.
///
/// The QR holds `https://femora.web.app/#r=<data>`. The data is the report's content (the same numbers and notes
/// as the PDF report), as compact JSON, zlib-compressed and base64url-encoded. It sits after the `#`, which a
/// browser never sends to any server: the page at femora.web.app (`doctor_view/index.html`) is a fixed file that
/// only unpacks and draws it on the doctor's phone. Nothing is uploaded and nothing is stored.
///
/// Dates are whole days relative to the report date, to keep the code small. A QR code much above ~1,700
/// characters gets too dense to scan from another phone's screen, so the least important parts (daily charts,
/// then log patterns) are dropped first when a report is very full.
class DoctorLink {
  static const viewer = 'https://femora.web.app/';
  static const maxLength = 1700;

  static String build(HealthStore store, {DateTime? lastSelfExam}) {
    final data = ReportData.fromStore(store, lastSelfExam: lastSelfExam, now: store.now());
    final full = payload(data, store);
    for (final drop in const [<String>[], ['ms', 'es', 'ss'], ['pt'], ['hn'], ['sy', 'mo']]) {
      final wl = full['wl'] as Map<String, dynamic>?;
      final cy = full['cy'] as Map<String, dynamic>?;
      for (final k in drop) {
        wl?.remove(k);
        cy?.remove(k);
      }
      final link = '$viewer#r=${encode(full)}';
      if (link.length <= maxLength) return link;
    }
    return '$viewer#r=${encode(full)}';
  }

  static String encode(Map<String, dynamic> payload) =>
      base64Url.encode(ZLibEncoder().encodeBytes(utf8.encode(jsonEncode(payload)), level: 9)).replaceAll('=', '');

  /// The inverse of [encode] (the web page does the same in JavaScript); used by the tests.
  static Map<String, dynamic> decode(String data) {
    final padded = data.padRight((data.length + 3) ~/ 4 * 4, '=');
    return jsonDecode(utf8.decode(ZLibDecoder().decodeBytes(base64Url.decode(padded)))) as Map<String, dynamic>;
  }

  static Map<String, dynamic> payload(ReportData d, HealthStore store) {
    final today = DateTime(d.generated.year, d.generated.month, d.generated.day);
    int day(DateTime x) => DateTime(x.year, x.month, x.day).difference(today).inDays;
    int x10(double v) => (v * 10).round();
    final p = d.profile;

    final out = <String, dynamic>{
      'v': 1,
      't': d.generated.millisecondsSinceEpoch ~/ 60000,
      'id': reportId(d),
      'p': {
        if (p.name.trim().isNotEmpty) 'n': p.name.trim(),
        if (p.age != null) 'a': p.age,
        if (p.heightCm != null) 'h': p.heightCm!.round(),
        if (p.weightKg != null) 'w': p.weightKg!.round(),
        if (p.concerns.isNotEmpty) 'c': p.concerns.toList(),
      },
    };

    final pc = d.pcos;
    if (pc != null) {
      out['pc'] = {'d': day(pc.date), 'pct': pc.percent, 'lv': pc.level, 'bmi': x10(pc.bmi), if (pc.factors.isNotEmpty) 'f': pc.factors};
    }
    final sc = d.scan;
    if (sc != null) {
      int pct(String k) => ((sc.probabilities[k] ?? 0) * 100).round();
      out['sc'] = {
        'd': day(sc.date),
        'pr': sc.prediction,
        'ti': sc.title,
        'cf': (sc.confidence * 100).round(),
        'pb': [pct('normal'), pct('benign'), pct('malignant')],
        'ac': (sc.modelAccuracy * 100).round(),
      };
    }
    final br = d.breastRisk;
    if (br != null) {
      out['br'] = {
        'd': day(br.date),
        'p': (br.probability * 10000).round(),
        'av': (br.average * 10000).round(),
        'rr': (br.relativeRisk * 100).round(),
        'lv': br.level,
        'ag': br.ageGroup,
        if (br.factors.isNotEmpty) 'f': br.factors,
        if (br.redFlags.isNotEmpty) 'rf': br.redFlags,
      };
    }

    final e = CycleEngine(d.periods, d.generated);
    final ins = HormoneInsights(e, d.logs, d.generated);
    if (d.periods.isNotEmpty && e.hasHistory) {
      final history = CycleHistory.of(e);
      final backtest = CycleBacktest.compute(d.periods);
      out['cy'] = {
        'n': e.n,
        if (e.averageLength != null) 'avg': x10(e.averageLength!),
        'reg': e.regularity,
        if (e.spread != null) 'sp': e.spread,
        if (e.averagePeriod != null) 'per': x10(e.averagePeriod!),
        'ls': day(e.lastStart!),
        'cd': e.cycleDay,
        if (e.periodOngoing) 'on': 1,
        if (e.isLate) 'late': -e.daysUntilNext!,
        if (e.nextStart != null) 'nx': day(e.nextStart!),
        if (!e.isLate && e.nextStartEarliest != null) 'ne': day(e.nextStartEarliest!),
        if (!e.isLate && e.nextStartLatest != null) 'nl': day(e.nextStartLatest!),
        if (!e.isLate && e.ovulation != null) 'ov': day(e.ovulation!),
        if (!e.isLate && e.fertileStart != null) 'fs': day(e.fertileStart!),
        if (!e.isLate && e.fertileEnd != null) 'fe': day(e.fertileEnd!),
        if (history.lengths.length >= 2) 'len': history.lastLengths(12),
        if (backtest.summary != null) 'bt': backtest.summary,
        'ba': e.basis,
        if (e.flags.isNotEmpty) 'fl': [for (final f in e.flags) f.text],
        if (ins.patterns.isNotEmpty) 'pt': [for (final n in ins.patterns) n.text],
        if (ins.flags.isNotEmpty) 'hn': [for (final n in ins.flags) n.text],
      };
    }
    final doctorSteps = [
      if (d.periods.isNotEmpty) for (final f in e.flags) if (f.seeDoctor) f.text,
      for (final f in ins.flags) if (f.seeDoctor) f.text,
    ];
    if (doctorSteps.isNotEmpty) out['st'] = doctorSteps;

    final now = d.generated;
    final recent = d.logs.where((l) => now.difference(l.date).inDays < 30).toList();
    final counts = <String, int>{};
    final moods = <String, int>{};
    for (final l in recent) {
      for (final s in l.symptoms) {
        counts[s] = (counts[s] ?? 0) + 1;
      }
      if (l.mood != null) moods[l.mood!] = (moods[l.mood!] ?? 0) + 1;
    }
    double? mean(Iterable<num?> xs) {
      final v = [for (final x in xs) if (x != null) x.toDouble()];
      return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
    }

    List<List<int>> series(num? Function(SymptomLog) f, {int scale = 1}) => [
          for (final l in recent)
            if (f(l) != null) [day(l.date), (f(l)! * scale).round()],
        ];
    final top = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final avgSleep = mean(recent.map((l) => l.sleepHours));
    final avgStress = mean(recent.map((l) => l.stress));
    final avgEnergy = mean(recent.map((l) => l.energy));
    out['wl'] = {
      if (d.lastSelfExam != null) 'ex': day(d.lastSelfExam!),
      'lc': recent.length,
      if (avgSleep != null) 'sl': x10(avgSleep),
      if (avgStress != null) 'st': x10(avgStress),
      if (avgEnergy != null) 'en': x10(avgEnergy),
      if (top.isNotEmpty) 'sy': [for (final t in top.take(4)) [t.key, t.value]],
      if (moods.isNotEmpty) 'mo': [for (final m in moods.entries) [m.key, m.value]],
      'ms': series((l) => l.moodScore),
      'es': series((l) => l.energy),
      'ss': series((l) => l.sleepHours, scale: 10),
    };

    if (store.heartReadings.isNotEmpty) {
      final last = store.heartReadings.last;
      final h = HeartInsights(store.heartReadings, e, now);
      out['hr'] = {'b': last.bpm, 'd': day(last.date), if (h.usual != null) 'u': h.usual, 'k': h.resting.length};
    }
    if (store.reports.isNotEmpty) {
      final r = store.reports.first;
      out['lab'] = {
        'd': day(r.date),
        'f': [
          for (final f in r.findings.where((f) => f.outOfRange).take(6)) [f.name, f.value, f.unit, f.status],
        ],
      };
    }
    return out;
  }
}
