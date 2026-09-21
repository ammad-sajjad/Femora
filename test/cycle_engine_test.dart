import 'package:femora/models/cycle_engine.dart';
import 'package:femora/models/cycle_params.dart';
import 'package:flutter_test/flutter_test.dart';

final _base = DateTime(2026, 1, 1);
DateTime d(int offset) => addDays(_base, offset);
PeriodEntry p(int offset, {int? endOffset}) => PeriodEntry(start: d(offset), end: endOffset == null ? null : d(endOffset));

/// Periods that start every [len] days, [count] of them, beginning on day 0.
List<PeriodEntry> every(int len, int count) => [for (var i = 0; i < count; i++) p(i * len)];

void main() {
  group('with no history', () {
    test('there is nothing to predict and nothing to flag', () {
      final e = CycleEngine(const [], d(10));
      expect(e.hasHistory, isFalse);
      expect(e.nextStart, isNull);
      expect(e.flags, isEmpty);
      expect(e.phase, isNull);
      expect(e.companionSummary(), isNull);
      expect(e.dayInfo(d(3)).period, isFalse);
    });

    test('one logged start falls back to the study average and says so', () {
      final e = CycleEngine([p(0)], d(4));
      expect(e.n, 0);
      expect(e.lengthDays, kCycleParams.lengthMean.round()); // 29
      expect(e.nextStart, d(29));
      expect(e.windowHalf, 4);
      expect(e.cycleDay, 5);
      expect(e.basis, contains('research study'));
      expect(e.regularity, 'not enough cycles yet');
    });
  });

  group('personalising', () {
    test('regular 28-day cycles pull the prediction to 28 and narrow the window', () {
      final e = CycleEngine(every(28, 5), d(120));
      expect(e.n, 4);
      expect(e.lengths, [28, 28, 28, 28]);
      expect(e.lengthDays, 28);
      expect(e.nextStart, d(140));
      expect(e.daysUntilNext, 20);
      expect(e.windowHalf, lessThan(4));
      expect(e.regularity, 'regular');
      expect(e.basis, contains('4 logged cycles'));
    });

    test('long cycles move the prediction towards her own length, not the population average', () {
      final e = CycleEngine(every(35, 5), d(150));
      expect(e.lengthDays, inInclusiveRange(33, 34));
      expect(e.lengthDays, greaterThan(kCycleParams.lengthMean.round()));
    });

    test('the estimate is her average blended with the population average', () {
      final e = CycleEngine([p(0), p(27), p(56), p(83)], d(90)); // 27, 29, 27
      final mean = (27 + 29 + 27) / 3;
      final expected = (3 * mean + kCycleParams.tau * kCycleParams.lengthMean) / (3 + kCycleParams.tau);
      expect(e.lengthEstimate, closeTo(expected, 1e-9));
    });

    test('a gap that is really a missed log is not used for averaging', () {
      final e = CycleEngine([p(0), p(28), p(56), p(200)], d(210));
      expect(e.lengths, [28, 28]);
      expect(e.n, 2);
    });

    test('two starts less than 15 days apart are not treated as a cycle', () {
      final e = CycleEngine([p(0), p(10)], d(12));
      expect(e.n, 0);
      expect(e.lastStart, d(10));
    });

    test('starts given out of order or twice are cleaned up', () {
      final e = CycleEngine([p(28), p(0), p(28), p(56)], d(60));
      expect(e.periods.map((x) => x.start), [d(0), d(28), d(56)]);
    });
  });

  group('ovulation, fertile window and phases', () {
    test('ovulation is 13 days before the expected period and the window runs from 5 days before to 1 after', () {
      final e = CycleEngine(every(28, 5), d(120));
      expect(e.ovulation, d(112 + 15));
      expect(e.fertileStart, d(112 + 10));
      expect(e.fertileEnd, d(112 + 16));
    });

    test('phases follow the cycle day', () {
      final e = CycleEngine(every(28, 5), d(112)); // day 1 of the last cycle
      expect(e.phaseOn(d(112)), CyclePhase.menstrual);
      expect(e.phaseOn(d(116)), CyclePhase.menstrual); // 5 predicted period days
      expect(e.phaseOn(d(117)), CyclePhase.follicular);
      expect(e.phaseOn(d(112 + 14)), CyclePhase.ovulation);
      expect(e.phaseOn(d(112 + 15)), CyclePhase.ovulation);
      expect(e.phaseOn(d(112 + 17)), CyclePhase.luteal);
      expect(e.phaseOn(d(-3)), isNull); // before the first log
    });

    test('a period she ended earlier uses her real length', () {
      final e = CycleEngine([p(0, endOffset: 6), p(28, endOffset: 34), p(56, endOffset: 62), p(84)], d(90));
      expect(e.averagePeriod, 7);
      expect(e.phaseOn(d(6)), CyclePhase.menstrual); // day 7 of the first cycle
      expect(e.phaseOn(d(7)), CyclePhase.follicular);
    });

    test('the calendar marks logged days, projected periods and the fertile window', () {
      final e = CycleEngine([p(84, endOffset: 88), ...[p(0), p(28), p(56)]], d(90)); // ovulation (day 99) is still ahead
      expect(e.dayInfo(d(85)).period, isTrue);
      expect(e.dayInfo(d(89)).period, isFalse);
      final next = e.nextStart!;
      expect(e.dayInfo(next).predictedPeriod, isTrue);
      expect(e.dayInfo(addDays(next, e.periodDays - 1)).predictedPeriod, isTrue);
      expect(e.dayInfo(addDays(next, e.periodDays + 2)).predictedPeriod, isFalse);
      final ov = e.ovulation!;
      expect(e.dayInfo(ov).ovulation, isTrue);
      expect(e.dayInfo(addDays(ov, -3)).fertile, isTrue);
      expect(e.dayInfo(addDays(ov, 4)).fertile, isFalse);
      // a second projected cycle is drawn too
      expect(e.dayInfo(addDays(next, e.lengthDays)).predictedPeriod, isTrue);
    });
  });

  group('an unfinished period', () {
    test('is ongoing, counts as the menstrual phase and is projected to continue', () {
      final e = CycleEngine(every(28, 3)..add(p(84)), d(86)); // started 2 days ago
      expect(e.periodOngoing, isTrue);
      expect(e.cycleDay, 3);
      expect(e.phase, CyclePhase.menstrual);
      expect(e.dayInfo(d(85)).period, isTrue);
      expect(e.dayInfo(d(87)).predictedPeriod, isTrue);
      expect(e.companionSummary(), contains('ongoing'));
    });
  });

  group('lateness and irregularity', () {
    test('a period more than the window late is flagged, and advice gets stronger after two weeks', () {
      final late12 = CycleEngine(every(28, 3), d(56 + 40));
      expect(late12.isLate, isTrue);
      expect(late12.daysUntilNext, -12);
      final f = late12.flags.firstWhere((x) => x.id == 'late');
      expect(f.text, contains('12 days later'));
      expect(f.seeDoctor, isFalse);
      final late15 = CycleEngine(every(28, 3), d(56 + 43));
      expect(late15.flags.firstWhere((x) => x.id == 'late').seeDoctor, isTrue);
      expect(late12.phase, CyclePhase.luteal); // still waiting, not projecting a new period
      expect(late12.dayInfo(d(56 + 45)).predictedPeriod, isFalse);
    });

    test('being one day past the expected date inside the window is not flagged', () {
      final e = CycleEngine(every(28, 3), d(56 + 29));
      expect(e.isLate, isTrue);
      expect(e.flags.where((x) => x.id == 'late'), isEmpty);
    });

    test('three months without a logged period asks her to see a doctor', () {
      final e = CycleEngine(every(28, 3), d(56 + 100));
      final f = e.flags.first;
      expect(f.id, 'missed3');
      expect(f.seeDoctor, isTrue);
    });

    test('cycles that vary by more than a week are called irregular and point to the PCOS check', () {
      final e = CycleEngine([p(0), p(24), p(60), p(87), p(125)], d(130)); // 24, 36, 27, 38
      expect(e.spread, 14);
      expect(e.regularity, 'irregular');
      final ids = e.flags.map((f) => f.id);
      expect(ids, containsAll(['long', 'irregular']));
      expect(e.flags.firstWhere((f) => f.id == 'irregular').text, contains('PCOS'));
    });

    test('regular cycles raise no irregularity flag', () {
      final e = CycleEngine([p(0), p(27), p(56), p(83), p(112)], d(115));
      expect(e.flags.map((f) => f.id), isNot(contains('irregular')));
    });

    test('a very short last cycle and a very long period are noted', () {
      final short = CycleEngine([p(0), p(28), p(48)], d(50));
      expect(short.flags.map((f) => f.id), contains('short'));
      final longPeriod = CycleEngine([p(0, endOffset: 8), p(28)], d(30));
      final f = longPeriod.flags.firstWhere((x) => x.id == 'longperiod');
      expect(f.seeDoctor, isTrue);
      expect(f.text, contains('9 days'));
    });
  });

  group('helpers', () {
    test('date maths ignores daylight saving changes', () {
      expect(daysBetween(DateTime(2026, 3, 1), DateTime(2026, 4, 1)), 31);
      expect(daysBetween(DateTime(2026, 10, 20), DateTime(2026, 11, 20)), 31);
      expect(addDays(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 1));
    });

    test('period entries keep only the day and survive saving', () {
      final e = PeriodEntry(start: DateTime(2026, 5, 3, 22, 30), end: DateTime(2026, 5, 7, 8));
      expect(e.start, DateTime(2026, 5, 3));
      expect(e.length, 5);
      final back = PeriodEntry.fromJson(e.toJson());
      expect(back.start, e.start);
      expect(back.end, e.end);
      expect(PeriodEntry(start: d(0)).length, isNull);
    });

    test('the companion summary carries counts and a regularity word but no dates', () {
      final s = CycleEngine(every(28, 5), d(120)).companionSummary()!;
      expect(s, startsWith('Cycle tracking:'));
      expect(s, contains('4 cycles logged'));
      expect(s, contains('regular'));
      expect(s, isNot(contains('2026')));
    });
  });
}
