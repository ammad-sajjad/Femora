import 'dart:math' as math;

import 'cycle_engine.dart';
import 'health_store.dart';

/// Plain-language background for one phase of the cycle. General information, not the user's measured hormones.
class PhaseInfo {
  final String hormones;
  final String feelings;
  final List<String> tips;
  const PhaseInfo({required this.hormones, required this.feelings, required this.tips});
}

const phaseInfo = <CyclePhase, PhaseInfo>{
  CyclePhase.menstrual: PhaseInfo(
    hormones: 'Estrogen and progesterone are at their lowest. Their drop is what makes the lining of the womb shed as your period.',
    feelings: 'Cramps, tiredness, backache and a lower mood are common in the first days. Many women feel lighter once the bleeding eases.',
    tips: [
      'Warmth on the lower belly and gentle movement such as walking or stretching often ease cramps.',
      'Iron-rich food (lentils, spinach, beans, meat) helps replace what is lost; drink plenty of fluids.',
      'Rest when you can. Ask a doctor or pharmacist which pain relief is right for you.',
    ],
  ),
  CyclePhase.follicular: PhaseInfo(
    hormones: 'Estrogen climbs steadily as an egg matures. This is usually the phase with the most stable mood and energy.',
    feelings: 'Energy, focus and skin often improve. Many women feel most sociable and motivated now.',
    tips: [
      'A good time for exercise, strength work and tasks that need concentration.',
      'Protein, fibre and plenty of water keep energy steady.',
      'Keep your usual sleep routine; it sets you up for the second half of the cycle.',
    ],
  ),
  CyclePhase.ovulation: PhaseInfo(
    hormones: 'Estrogen peaks and a surge of LH releases an egg. This is the most fertile part of the cycle.',
    feelings: 'Some women notice more energy, clearer skin, slightly higher body temperature afterwards, clear cervical mucus, or a mild one-sided twinge.',
    tips: [
      'Drink water and eat regular balanced meals; appetite can change around ovulation.',
      'A mild twinge is common. Severe or lasting pain should be checked by a doctor.',
      'This estimate is not contraception: ovulation can shift from cycle to cycle.',
    ],
  ),
  CyclePhase.luteal: PhaseInfo(
    hormones: 'Progesterone rises after ovulation. If there is no pregnancy, progesterone and estrogen both fall in the days before the period.',
    feelings: 'Bloating, breast tenderness, cravings, tiredness, poorer sleep and mood swings are common, most of all in the last week before a period (premenstrual symptoms).',
    tips: [
      'Regular meals with whole grains, vegetables and protein; go easy on salt and caffeine.',
      'Light to moderate exercise and a fixed bedtime help mood and sleep.',
      'Nuts, seeds and leafy greens are good sources of magnesium. Plan lighter days if you tire easily.',
    ],
  ),
};

/// What the daily logs show for the days that fall in one phase.
class PhaseStats {
  final CyclePhase phase;
  final int days; // logged days in this phase
  final double? avgMood;
  final double? avgEnergy;
  final double? avgSleep;
  final double? avgStress;
  final Map<String, int> symptomDays; // symptom -> days it was logged

  const PhaseStats({required this.phase, required this.days, this.avgMood, this.avgEnergy, this.avgSleep, this.avgStress, this.symptomDays = const {}});

  /// Share of the logged days in this phase on which [symptom] was logged (0 to 1).
  double share(String symptom) => days == 0 ? 0 : (symptomDays[symptom] ?? 0) / days;
}

/// One observation or warning, always worded as something worth knowing, never as a diagnosis.
class InsightNote {
  final String id;
  final String text;
  final bool seeDoctor;
  const InsightNote(this.id, this.text, {this.seeDoctor = false});
}

/// Looks at the daily log across the phases of the menstrual cycle, and at symptoms that keep coming back.
class HormoneInsights {
  static const minPhaseDays = 5; // logged days needed in a phase before it is compared
  static const windowDays = 60; // how far back "persistent" looks
  static const minWindowLogs = 10; // logged days needed in that window before anything is called persistent
  static const trackedSymptoms = ['cramps', 'bloating', 'headache', 'fatigue', 'acne', 'backache', 'tender', 'nausea', 'hair loss', 'excess hair'];

  final CycleEngine engine;
  final DateTime today;
  final List<SymptomLog> logs; // oldest first

  late final Map<CyclePhase, PhaseStats> byPhase;
  late final int phaseLogs; // logs that fall inside a known cycle
  late final int cyclesWithLogs;
  late final List<InsightNote> patterns;
  late final List<InsightNote> flags;

  HormoneInsights(this.engine, Iterable<SymptomLog> all, DateTime now)
      : today = dayOf(now),
        logs = ([...all]..sort((a, b) => a.date.compareTo(b.date))) {
    final assigned = <CyclePhase, List<SymptomLog>>{for (final p in CyclePhase.values) p: []};
    final cycles = <DateTime>{};
    var n = 0;
    for (final l in logs) {
      final phase = engine.hasHistory ? engine.phaseOn(l.date) : null;
      if (phase == null) continue;
      assigned[phase]!.add(l);
      n++;
      final start = engine.periods.lastWhere((e) => !e.start.isAfter(dayOf(l.date)), orElse: () => engine.periods.first).start;
      cycles.add(start);
    }
    phaseLogs = n;
    cyclesWithLogs = cycles.length;
    byPhase = {for (final p in CyclePhase.values) p: _stats(p, assigned[p]!)};
    patterns = _patterns(assigned);
    flags = _flags();
  }

  static double? _avg(Iterable<num?> xs) {
    final v = [for (final x in xs) if (x != null) x.toDouble()];
    return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
  }

  static PhaseStats _stats(CyclePhase phase, List<SymptomLog> ls) {
    final counts = <String, int>{};
    for (final l in ls) {
      for (final s in l.symptoms) {
        counts[s] = (counts[s] ?? 0) + 1;
      }
    }
    return PhaseStats(
      phase: phase,
      days: ls.length,
      avgMood: _avg(ls.map((l) => l.moodScore)),
      avgEnergy: _avg(ls.map((l) => l.energy)),
      avgSleep: _avg(ls.map((l) => l.sleepHours)),
      avgStress: _avg(ls.map((l) => l.stress)),
      symptomDays: counts,
    );
  }

  static String _list(List<String> xs) => xs.length <= 1 ? xs.join() : '${xs.sublist(0, xs.length - 1).join(', ')} and ${xs.last}';

  List<InsightNote> _patterns(Map<CyclePhase, List<SymptomLog>> assigned) {
    final out = <InsightNote>[];
    final lut = byPhase[CyclePhase.luteal]!;
    final men = byPhase[CyclePhase.menstrual]!;
    final restLogs = [...assigned[CyclePhase.menstrual]!, ...assigned[CyclePhase.follicular]!, ...assigned[CyclePhase.ovulation]!];
    final rest = _stats(CyclePhase.follicular, restLogs);

    // Cramps on period days
    if (men.days >= 3 && men.share('cramps') >= 0.6) {
      final c = men.symptomDays['cramps']!;
      out.add(InsightNote('cramps', 'You logged cramps on $c of ${men.days} period days. Period pain is common. If it stops you doing normal things or is getting worse, please see a doctor: conditions such as endometriosis or fibroids can cause it.'));
    }

    if (cyclesWithLogs >= 2) {
      // Premenstrual pattern: things that pick up in the luteal phase
      if (lut.days >= minPhaseDays && rest.days >= minPhaseDays) {
        final rising = <String>[
          for (final s in const ['bloating', 'tender', 'headache', 'fatigue', 'backache'])
            if (lut.share(s) - rest.share(s) >= 0.25 && (lut.symptomDays[s] ?? 0) >= 2) s == 'tender' ? 'breast tenderness' : s,
        ];
        final moodDrop = lut.avgMood != null && rest.avgMood != null && rest.avgMood! - lut.avgMood! >= 0.6;
        if (rising.length >= 2 || (rising.isNotEmpty && moodDrop)) {
          final things = [...rising, if (moodDrop) 'a lower mood'];
          out.add(InsightNote('pms', 'Before your period you logged ${_list(things)} more often than at other times of your cycle. This premenstrual pattern is common. Regular meals, exercise and sleep help; if it disrupts your daily life or your mood drops a lot, please see a doctor.'));
        }
      }
      // Energy by phase
      final withEnergy = [for (final s in byPhase.values) if (s.days >= minPhaseDays && s.avgEnergy != null) s];
      if (withEnergy.length >= 2) {
        withEnergy.sort((a, b) => a.avgEnergy!.compareTo(b.avgEnergy!));
        final low = withEnergy.first;
        final high = withEnergy.last;
        if (high.avgEnergy! - low.avgEnergy! >= 1.0) {
          out.add(InsightNote('energy', 'Your energy was lowest in the ${low.phase.label.toLowerCase()} (${low.avgEnergy!.toStringAsFixed(1)} of 5) and highest in the ${high.phase.label.toLowerCase()} (${high.avgEnergy!.toStringAsFixed(1)}). Plan demanding tasks for your higher-energy days.'));
        }
      }
      // Sleep before the period
      final fol = byPhase[CyclePhase.follicular]!;
      if (lut.days >= minPhaseDays && fol.days >= minPhaseDays && lut.avgSleep != null && fol.avgSleep != null && fol.avgSleep! - lut.avgSleep! >= 0.75) {
        out.add(InsightNote('sleep', 'You slept about ${(fol.avgSleep! - lut.avgSleep!).toStringAsFixed(1)} hours less on average in the luteal phase than in the follicular phase. Poorer sleep before a period is common; a fixed bedtime and less caffeine in the afternoon can help.'));
      }
    }
    return out;
  }

  List<InsightNote> _flags() {
    final out = <InsightNote>[];
    final from = addDays(today, -(windowDays - 1));
    final win = [for (final l in logs) if (!dayOf(l.date).isBefore(from) && !dayOf(l.date).isAfter(today)) l];
    if (win.length >= minWindowLogs) {
      int count(String s, [Iterable<SymptomLog>? within]) => (within ?? win).where((l) => l.symptoms.contains(s)).length;
      final acne = count('acne');
      final acneFlag = acne >= 14 && acne * 2 >= win.length;
      final hair = win.where((l) => l.symptoms.contains('hair loss') || l.symptoms.contains('excess hair')).length;
      final hairFlag = hair >= 5;
      final irregular = engine.hasHistory && (engine.regularity == 'irregular' || (engine.lengths.isNotEmpty && engine.lengths.last > 35));

      if (acneFlag) {
        out.add(InsightNote(
          'acne',
          'Acne was logged on $acne of ${win.length} days over the last $windowDays days. Ongoing acne can be linked to raised androgen hormones, as in PCOS; a doctor can check with a blood test and a skin plan.',
          seeDoctor: irregular || hairFlag,
        ));
      }
      if (hairFlag) {
        out.add(InsightNote('hair', 'Hair loss or extra hair growth was logged on $hair days over the last $windowDays days. These can be signs of hormone imbalance such as PCOS or a thyroid problem, and are worth a check with a doctor.', seeDoctor: true));
      }
      if ((acneFlag || hairFlag) && irregular) {
        out.add(const InsightNote('pcos_pattern', 'Irregular cycles together with acne or extra hair are the combination doctors look for when they check for PCOS. This is not a diagnosis. The PCOS check in Femora, or a visit to a gynaecologist, can help you decide.', seeDoctor: true));
      }
      final recent = [for (final l in win) if (!dayOf(l.date).isBefore(addDays(today, -29))) l];
      final tired = count('fatigue', recent);
      if (recent.length >= minWindowLogs && tired >= 10 && tired * 2 >= recent.length) {
        out.add(InsightNote('fatigue', 'Tiredness was logged on $tired of ${recent.length} days over the last 30 days. Causes include low iron, thyroid problems and poor sleep, and a simple blood test can check them. Please mention it to a doctor.', seeDoctor: true));
      }
      final fortnight = [for (final l in win) if (!dayOf(l.date).isBefore(addDays(today, -13))) l];
      final low = fortnight.where((l) => (l.moodScore ?? 5) <= 2).length;
      if (fortnight.length >= 10 && low >= 10) {
        out.add(InsightNote('lowmood', 'Your mood was low or bad on $low of the last 14 days. Low mood that lasts two weeks or more is worth talking about with a doctor or someone you trust, whatever the cause.', seeDoctor: true));
      }
      if (engine.hasHistory) {
        final outside = win.where((l) => l.symptoms.contains('cramps') && engine.phaseOn(l.date) != null && engine.phaseOn(l.date) != CyclePhase.menstrual).length;
        if (outside >= 5) {
          out.add(InsightNote('cramps_outside', 'Cramps were logged on $outside days outside your period. Pelvic pain that is not part of a period should be checked by a doctor.', seeDoctor: true));
        }
      }
    }
    // Most serious first
    out.sort((a, b) => (b.seeDoctor ? 1 : 0) - (a.seeDoctor ? 1 : 0));
    return out;
  }

  PhaseInfo? get currentInfo => engine.phase == null ? null : phaseInfo[engine.phase!];

  /// Enough data to say something about patterns across phases.
  bool get hasPatternData => cyclesWithLogs >= 2 && phaseLogs >= minPhaseDays * 2;

  /// One line for the companion (no dates).
  String? companionSummary() {
    if (!engine.hasHistory) return null;
    final ids = [...patterns.map((p) => p.id), ...flags.map((f) => f.id)];
    if (ids.isEmpty) return null;
    return 'Hormonal insights: ${ids.join(', ')}${flags.any((f) => f.seeDoctor) ? ' (some worth a doctor visit)' : ''}.';
  }
}

/// The textbook shape of estrogen, progesterone and LH across a cycle of [length] days (0 to 1, relative levels).
/// An illustration only: it is drawn from the average cycle and is not the user's measured hormones.
({List<double> estrogen, List<double> progesterone, List<double> lh}) typicalHormoneCurves(int length, {int lutealDays = 13}) {
  double bump(double d, double centre, double width) {
    final z = (d - centre) / width;
    return math.exp(-z * z);
  }

  final o = (length - lutealDays).toDouble(); // ovulation day index
  final e = <double>[], p = <double>[], l = <double>[];
  for (var i = 0; i < length; i++) {
    final d = i.toDouble();
    e.add((0.12 + 0.88 * bump(d, o - 1, 2.6) + 0.42 * bump(d, o + 7, 3.6)).clamp(0.0, 1.0));
    p.add(d < o ? 0.04 : (0.04 + 0.96 * bump(d, o + 7, 3.4)).clamp(0.0, 1.0));
    l.add((0.08 + 0.92 * bump(d, o - 0.5, 0.9)).clamp(0.0, 1.0));
  }
  return (estrogen: e, progesterone: p, lh: l);
}
