import 'package:femora/models/analytics.dart';
import 'package:femora/models/cycle_engine.dart';
import 'package:femora/models/cycle_params.dart';
import 'package:flutter_test/flutter_test.dart';

final _base = DateTime(2026, 1, 1);
DateTime d(int offset) => addDays(_base, offset);
PeriodEntry p(int offset, {int? endOffset}) => PeriodEntry(start: d(offset), end: endOffset == null ? null : d(endOffset));

/// Starts spaced by [gaps]: [0, g1, g1+g2, ...].
List<PeriodEntry> spaced(List<int> gaps) {
  var at = 0;
  return [p(0), for (final g in gaps) p(at += g)];
}

void main() {
  group('replaying the prediction on her own cycles', () {
    test('one point per completed cycle, each predicted only from the cycles before it', () {
      final bt = CycleBacktest.compute(spaced([28, 28, 28, 28]));
      expect(bt.n, 4);
      expect(bt.points.map((x) => x.priorCycles), [0, 1, 2, 3]);
      // the first cycle can only use the study average, the later ones learn her 28 days
      expect(bt.points.first.predicted, kCycleParams.lengthMean.round()); // 29
      expect(bt.points.last.predicted, 28);
      expect(bt.points.map((x) => x.actual), everyElement(28));
    });

    test('the error shrinks as the prediction learns a regular cycle', () {
      final bt = CycleBacktest.compute(spaced([28, 28, 28, 28, 28, 28]));
      expect(bt.points.first.error, 1); // 29 vs 28
      expect(bt.points.last.error, 0);
      expect(bt.meanError, lessThan(bt.meanPopulationError!)); // beats "everyone is 29 days"
      expect(bt.populationWithin3, 6);
    });

    test('for a woman with long cycles it beats the average clearly', () {
      final bt = CycleBacktest.compute(spaced([36, 35, 37, 36, 35, 36]));
      expect(bt.meanPopulationError, greaterThan(5));
      expect(bt.meanError, lessThan(bt.meanPopulationError! - 2));
      expect(bt.summary, contains('Learning from your own cycles is helping'));
    });

    test('irregular cycles are counted honestly: the prediction is often out', () {
      final bt = CycleBacktest.compute(spaced([24, 36, 27, 38, 25, 40]));
      expect(bt.within3, lessThan(bt.n));
      expect(bt.meanError, greaterThan(3));
    });

    test('a summary needs at least 3 completed cycles', () {
      expect(CycleBacktest.compute(spaced([28, 28])).summary, isNull);
      expect(CycleBacktest.compute(spaced([28, 28])).enough, isFalse);
      final s = CycleBacktest.compute(spaced([28, 28, 28])).summary!;
      expect(s, contains('Over your 3 logged cycles'));
      expect(s, contains('within 3 days 3 times (100%)'));
    });

    test('a cycle close to the average says there is little to gain', () {
      final bt = CycleBacktest.compute(spaced([29, 29, 29, 29]));
      expect(bt.summary, contains('little to gain'));
    });

    test('gaps that are duplicates or missed logs are not cycles', () {
      final bt = CycleBacktest.compute([p(0), p(10), p(38), p(66), p(300)]); // 10 (duplicate), 28, 28, 234 (missed)
      expect(bt.points.map((x) => x.actual), [28, 28]);
    });

    test('no periods or one period give nothing', () {
      expect(CycleBacktest.compute(const []).n, 0);
      expect(CycleBacktest.compute([p(0)]).n, 0);
      expect(CycleBacktest.compute(const []).meanError, isNull);
    });
  });

  group('cycle history', () {
    test('lists the completed cycles with their start dates and period lengths', () {
      final e = CycleEngine([p(0, endOffset: 4), p(28, endOffset: 33), p(56)], d(60));
      final h = CycleHistory.of(e);
      expect(h.lengths, [28, 28]);
      expect(h.starts, [d(0), d(28)]);
      expect(h.periodLengths, [5, 6]);
      expect(h.average, 28);
      expect((h.shortest, h.longest), (28, 28));
    });

    test('counts cycles outside 21 to 35 days and keeps the most recent ones', () {
      final e = CycleEngine(spaced([20, 28, 36, 28, 40]), d(200));
      final h = CycleHistory.of(e);
      expect(h.outsideNormal, 3); // 20, 36, 40
      expect(h.lastLengths(3), [36, 28, 40]);
      expect(h.lastStarts(3), hasLength(3));
      expect(h.lastLengths(10), h.lengths);
    });

    test('an empty history has no figures', () {
      final h = CycleHistory.of(CycleEngine(const [], d(0)));
      expect(h.lengths, isEmpty);
      expect(h.average, isNull);
      expect(h.shortest, isNull);
      expect(h.outsideNormal, 0);
    });
  });
}
