import 'package:femora/models/cycle_engine.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/models/hormone_insights.dart';
import 'package:flutter_test/flutter_test.dart';

final _base = DateTime(2026, 1, 1);
DateTime d(int offset) => addDays(_base, offset);
PeriodEntry p(int offset) => PeriodEntry(start: d(offset));

SymptomLog log(int offset, {List<String> symptoms = const [], String? mood, double? sleep, int? stress, int? energy}) =>
    SymptomLog(date: d(offset), symptoms: symptoms, mood: mood, sleepHours: sleep, stress: stress, energy: energy);

/// 28-day cycles from day 0: period days 0-4, follicular 5-13, ovulation 14-16, luteal 17-27.
/// Logged: cramps on period days; good mood, high energy and 8 h sleep in the follicular phase;
/// bloating, tenderness, low mood, low energy and 6.5 h sleep in the luteal phase.
List<SymptomLog> typicalLogs(int cycles) {
  final out = <SymptomLog>[];
  for (var c = 0; c < cycles; c++) {
    final b = c * 28;
    for (var i = 0; i < 5; i++) {
      out.add(log(b + i, symptoms: ['cramps'], mood: 'okay', energy: 3));
    }
    for (var i = 5; i < 14; i++) {
      out.add(log(b + i, mood: 'good', energy: 4, sleep: 8));
    }
    for (var i = 17; i < 28; i++) {
      out.add(log(b + i, symptoms: ['bloating', 'tender'], mood: 'low', energy: 2, sleep: 6.5));
    }
  }
  return out;
}

CycleEngine regular(DateTime today) => CycleEngine([p(0), p(28), p(56), p(84)], today);

void main() {
  curveAndLinkTests();
  group('symptoms across the phases', () {
    final today = d(100);
    final ins = HormoneInsights(regular(today), typicalLogs(4).where((l) => !l.date.isAfter(today)), today);

    test('logs are sorted into the phase their day fell in', () {
      expect(ins.byPhase[CyclePhase.menstrual]!.days, 20);
      expect(ins.byPhase[CyclePhase.follicular]!.days, 36);
      expect(ins.byPhase[CyclePhase.luteal]!.days, 33);
      expect(ins.byPhase[CyclePhase.ovulation]!.days, 0);
      expect(ins.cyclesWithLogs, 4);
      expect(ins.phaseLogs, 89);
    });

    test('per-phase averages and symptom shares', () {
      final lut = ins.byPhase[CyclePhase.luteal]!;
      expect(lut.avgMood, 2);
      expect(lut.avgEnergy, 2);
      expect(lut.avgSleep, 6.5);
      expect(lut.share('bloating'), 1);
      expect(lut.share('acne'), 0);
      expect(ins.byPhase[CyclePhase.follicular]!.avgMood, 4);
      expect(ins.byPhase[CyclePhase.menstrual]!.share('cramps'), 1);
    });

    test('a premenstrual pattern is found and worded gently', () {
      final n = ins.patterns.firstWhere((x) => x.id == 'pms');
      expect(n.text, contains('bloating'));
      expect(n.text, contains('breast tenderness'));
      expect(n.text, contains('a lower mood'));
      expect(n.text, contains('see a doctor'));
      expect(n.seeDoctor, isFalse);
    });

    test('period cramps, the energy dip and shorter sleep are found', () {
      expect(ins.patterns.firstWhere((x) => x.id == 'cramps').text, contains('20 of 20 period days'));
      final e = ins.patterns.firstWhere((x) => x.id == 'energy').text;
      expect(e, contains('lowest in the luteal phase (2.0 of 5)'));
      expect(e, contains('highest in the follicular phase (4.0)'));
      expect(ins.patterns.firstWhere((x) => x.id == 'sleep').text, contains('1.5 hours less'));
    });

    test('nothing here is a persistent-symptom flag', () {
      expect(ins.flags, isEmpty);
      expect(ins.hasPatternData, isTrue);
    });
  });

  group('too little data says nothing', () {
    test('one cycle of logs gives cramps at most, never cross-phase patterns', () {
      final today = d(30);
      final ins = HormoneInsights(regular(today), typicalLogs(1), today);
      expect(ins.cyclesWithLogs, 1);
      expect(ins.patterns.map((x) => x.id), ['cramps']);
      expect(ins.hasPatternData, isFalse);
    });

    test('fewer than 5 logged days in a phase are not compared', () {
      final today = d(60);
      final logs = [
        for (var c = 0; c < 2; c++) ...[
          for (var i = 5; i < 12; i++) log(c * 28 + i, mood: 'good', energy: 4),
          for (var i = 17; i < 19; i++) log(c * 28 + i, symptoms: ['bloating', 'tender'], mood: 'low', energy: 2),
        ],
      ];
      final ins = HormoneInsights(regular(today), logs, today);
      expect(ins.byPhase[CyclePhase.luteal]!.days, 4);
      expect(ins.patterns.where((x) => x.id == 'pms' || x.id == 'energy'), isEmpty);
    });

    test('no logged periods: no phases, and only symptom flags can appear', () {
      final today = d(100);
      final logs = [for (var i = 0; i < 30; i++) log(70 + i, symptoms: ['acne'])];
      final ins = HormoneInsights(CycleEngine(const [], today), logs, today);
      expect(ins.phaseLogs, 0);
      expect(ins.patterns, isEmpty);
      expect(ins.flags.map((f) => f.id), ['acne']);
    });

    test('logs given out of order are handled', () {
      final today = d(100);
      final shuffled = typicalLogs(4).where((l) => !l.date.isAfter(today)).toList().reversed;
      final ins = HormoneInsights(regular(today), shuffled, today);
      expect(ins.byPhase[CyclePhase.menstrual]!.days, 20);
      expect(ins.patterns.map((x) => x.id), contains('pms'));
    });
  });

  group('symptoms that keep coming back', () {
    final today = d(100);
    List<SymptomLog> daily(String s, {int days = 30, int from = 0}) => [for (var i = from; i < from + days; i++) log(100 - i, symptoms: [s], mood: 'good')];

    test('acne on most days is flagged, worded as a link to hormones, and not urgent on its own', () {
      final ins = HormoneInsights(regular(today), daily('acne', days: 30), today);
      final f = ins.flags.single;
      expect(f.id, 'acne');
      expect(f.text, contains('30 of 30 days'));
      expect(f.text, contains('androgen'));
      expect(f.seeDoctor, isFalse);
    });

    test('acne on a few days, or too few logged days, is not flagged', () {
      final few = [for (var i = 0; i < 30; i++) log(100 - i, symptoms: i < 8 ? ['acne'] : [], mood: 'good')];
      expect(HormoneInsights(regular(today), few, today).flags, isEmpty);
      final tooFew = [for (var i = 0; i < 9; i++) log(100 - i, symptoms: ['acne'])];
      expect(HormoneInsights(regular(today), tooFew, today).flags, isEmpty);
    });

    test('irregular cycles together with acne raise the PCOS pattern and advise a doctor', () {
      final irregular = CycleEngine([p(0), p(24), p(60), p(87), p(125)], d(130)); // 24, 36, 27, 38
      final logs = [for (var i = 0; i < 30; i++) log(130 - i, symptoms: ['acne'])];
      final ins = HormoneInsights(irregular, logs, d(130));
      expect(ins.flags.map((f) => f.id), containsAll(['acne', 'pcos_pattern']));
      expect(ins.flags.firstWhere((f) => f.id == 'pcos_pattern').text, contains('not a diagnosis'));
      expect(ins.flags.every((f) => f.seeDoctor), isTrue);
    });

    test('hair loss or extra hair on 5 days is flagged and advises a doctor', () {
      final logs = [for (var i = 0; i < 12; i++) log(100 - i, symptoms: i < 5 ? ['excess hair'] : [], mood: 'okay')];
      final ins = HormoneInsights(regular(today), logs, today);
      final f = ins.flags.single;
      expect(f.id, 'hair');
      expect(f.seeDoctor, isTrue);
    });

    test('tiredness on half of the last 30 days advises a blood test', () {
      final ins = HormoneInsights(regular(today), daily('fatigue', days: 30), today);
      final f = ins.flags.single;
      expect(f.id, 'fatigue');
      expect(f.text, contains('blood test'));
      expect(f.seeDoctor, isTrue);
    });

    test('two weeks of low mood advises talking to someone', () {
      final logs = [for (var i = 0; i < 14; i++) log(100 - i, mood: i < 11 ? 'low' : 'good')];
      final ins = HormoneInsights(regular(today), logs, today);
      expect(ins.flags.single.id, 'lowmood');
      expect(ins.flags.single.text, contains('11 of the last 14 days'));
    });

    test('cramps on many days outside the period are flagged', () {
      final logs = [for (var i = 0; i < 20; i++) log(100 - i, symptoms: i < 6 ? ['cramps'] : [], mood: 'good')]; // days 95-100 are ovulation, luteal
      final ins = HormoneInsights(regular(today), logs, today);
      expect(ins.flags.map((f) => f.id), contains('cramps_outside'));
    });

    test('flags that advise a doctor come first', () {
      final logs = [for (var i = 0; i < 30; i++) log(100 - i, symptoms: ['acne', 'fatigue'])];
      final ins = HormoneInsights(regular(today), logs, today);
      expect(ins.flags.first.id, 'fatigue');
      expect(ins.flags.first.seeDoctor, isTrue);
      expect(ins.flags.last.id, 'acne');
    });
  });

  group('phase background and the companion', () {
    test('every phase has hormones, feelings and at least two tips', () {
      for (final ph in CyclePhase.values) {
        final i = phaseInfo[ph]!;
        expect(i.hormones, isNotEmpty);
        expect(i.feelings, isNotEmpty);
        expect(i.tips.length, greaterThanOrEqualTo(2));
      }
    });

    test('the current phase gets its background, and a user with no periods gets none', () {
      final today = d(100);
      expect(HormoneInsights(regular(today), const [], today).currentInfo, phaseInfo[CyclePhase.ovulation]);
      expect(HormoneInsights(CycleEngine(const [], today), const [], today).currentInfo, isNull);
    });

    test('the companion hears the note ids, not the details', () {
      final today = d(100);
      final s = HormoneInsights(regular(today), typicalLogs(4).where((l) => !l.date.isAfter(today)), today).companionSummary()!;
      expect(s, startsWith('Hormonal insights:'));
      expect(s, contains('pms'));
      expect(s, isNot(contains('2026')));
      expect(HormoneInsights(regular(today), const [], today).companionSummary(), isNull);
    });
  });
}

// ------------------------------------------------------------ curves and links (added with the screen)
void curveAndLinkTests() {
  group('the typical hormone curves', () {
    test('have one value per day, all between 0 and 1', () {
      final c = typicalHormoneCurves(28);
      for (final line in [c.estrogen, c.progesterone, c.lh]) {
        expect(line, hasLength(28));
        expect(line.every((v) => v >= 0 && v <= 1), isTrue);
      }
    });

    test('estrogen peaks just before ovulation, LH at ovulation, progesterone a week later', () {
      final c = typicalHormoneCurves(28); // ovulation index 15
      int peak(List<double> xs) => xs.indexOf(xs.reduce((a, b) => a > b ? a : b));
      expect(peak(c.estrogen), inInclusiveRange(13, 15));
      expect(peak(c.lh), inInclusiveRange(14, 15));
      expect(peak(c.progesterone), inInclusiveRange(21, 23));
      expect(c.progesterone.take(14).every((v) => v < 0.1), isTrue); // near zero before ovulation
      expect(c.estrogen.first, lessThan(0.3)); // low at the start of the period
    });

    test('shift with a longer cycle', () {
      final c = typicalHormoneCurves(35); // ovulation index 22
      int peak(List<double> xs) => xs.indexOf(xs.reduce((a, b) => a > b ? a : b));
      expect(peak(c.lh), inInclusiveRange(21, 22));
      expect(c.estrogen, hasLength(35));
    });
  });

  group('links to the rest of the app', () {
    test('the companion is told which patterns and flags were found', () {
      final today = d(100);
      final s = HealthStore()..now = () => today.add(const Duration(hours: 9));
      s.periods = [p(0), p(28), p(56), p(84)];
      s.logs = typicalLogs(4).where((l) => !l.date.isAfter(today)).toList();
      final ctx = s.companionContext();
      expect(ctx, contains('Hormonal insights:'));
      expect(ctx, contains('pms'));
    });

    test('nothing about hormones is sent when there is nothing to say', () {
      final s = HealthStore()..now = () => d(100);
      expect(s.companionContext(), isNot(contains('Hormonal insights')));
    });
  });
}
