import 'package:intl/intl.dart';

import 'cycle_engine.dart';
import 'health_store.dart';

/// The "Show my doctor" summary: a short, plain-text handover a clinician can read in under a minute.
///
/// It goes inside the QR code itself, so a doctor's phone camera shows it with no app, no internet and no upload.
/// It is always in English (the language of clinical notes in Pakistan) and deliberately compact: a QR code much
/// above ~800 characters becomes too dense to scan reliably from another phone's screen.
class DoctorSummary {
  static const maxLength = 800;

  static String build(HealthStore store, {DateTime? lastSelfExam}) {
    final n = store.now();
    final day = DateFormat('d MMM yyyy');
    final short = DateFormat('d MMM');
    final p = store.profile;
    final lines = <String>['FEMORA HEALTH SUMMARY (self-reported + AI screening; not a diagnosis)'];

    final who = <String>[
      if (p.name.trim().isNotEmpty) p.name.trim(),
      if (p.age != null) '${p.age} y',
      if (p.bmi != null) 'BMI ${p.bmi!.toStringAsFixed(1)}',
    ];
    if (who.isNotEmpty) lines.add('Patient: ${who.join(', ')}');

    final e = CycleEngine(store.periods, n);
    if (e.hasHistory) {
      final avg = e.averageLength;
      lines.add('Cycle: LMP ${short.format(e.lastStart!)} (day ${e.cycleDay})'
          '${avg == null ? '' : ', avg ${avg.round()} d over ${e.n} cycles'}'
          '${e.spread == null ? '' : ', range ${e.spread} d'}'
          '${e.averagePeriod == null ? '' : ', bleeds ~${e.averagePeriod!.round()} d'}'
          '${e.isLate ? ', LATE ${-e.daysUntilNext!} d' : ', next ~${short.format(e.nextStart!)}'}');
      // Short clinical labels instead of the patient-facing sentences
      final flags = [
        for (final f in e.flags)
          switch (f.id) {
            'missed3' => 'no period for ${daysBetween(e.lastStart!, n)} d',
            'late' => 'late ${-e.daysUntilNext!} d',
            'short' => 'last cycle ${e.lengths.last} d (<21)',
            'long' => 'last cycle ${e.lengths.last} d (>35)',
            'irregular' => 'irregular (varies ${e.spread} d)',
            'longperiod' => 'last period >7 d',
            _ => f.id,
          },
      ];
      if (flags.isNotEmpty) lines.add('Cycle flags: ${flags.join('; ')}');
    }

    final recent = store.logs.where((l) => n.difference(l.date).inDays < 30).toList();
    if (recent.isNotEmpty) {
      final counts = <String, int>{};
      for (final l in recent) {
        for (final s in l.symptoms) {
          counts[s] = (counts[s] ?? 0) + 1;
        }
      }
      final top = (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).map((x) => '${x.key} ${x.value}d');
      lines.add('Symptoms, last 30 d (${recent.length} days logged): ${top.isEmpty ? 'none reported' : top.join(', ')}');
    }

    final pc = store.pcos;
    if (pc != null) {
      lines.add('PCOS screen (${short.format(pc.date)}): ${pc.level} risk (${pc.percent}%)'
          '${pc.factors.isEmpty ? '' : '; ${pc.factors.take(4).join(', ')}'}');
    }
    final br = store.breastRisk;
    if (br != null) {
      lines.add('Breast risk, BCSC model (${short.format(br.date)}): ${br.relativeRisk.toStringAsFixed(1)}x average for age ${br.ageGroup}'
          '${br.redFlags.isEmpty ? '' : '; REPORTS: ${br.redFlags.join(', ')}'}');
    }
    final sc = store.scan;
    if (sc != null) {
      lines.add('Breast US, AI screen (${short.format(sc.date)}): ${sc.title}, P(malignant) ${((sc.probabilities['malignant'] ?? 0) * 100).round()}%');
    }
    if (lastSelfExam != null) lines.add('Last self-exam: ${short.format(lastSelfExam)}');
    if (store.reports.isNotEmpty) {
      final r = store.reports.first;
      final abnormal = r.findings.where((f) => f.outOfRange).take(4).map((f) => '${f.name} ${f.value}${f.unit.isEmpty ? '' : ' ${f.unit}'} (${f.status})');
      lines.add('Lab photo read ${short.format(r.date)}: ${abnormal.isEmpty ? 'all values within printed ranges' : abnormal.join(', ')}');
    }
    if (lines.length == 1) lines.add('No results logged yet.');
    lines.add('Generated ${day.format(n)} by the Femora app.');

    final text = lines.join('\n');
    return text.length <= maxLength ? text : '${text.substring(0, maxLength - 1)}…';
  }
}
