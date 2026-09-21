import 'dart:math' as math;

import 'cycle_engine.dart';
import 'cycle_params.dart';

/// One completed cycle and how well its length would have been predicted from the cycles before it.
class BacktestPoint {
  final DateTime start; // first day of that cycle
  final int actual; // real length in days
  final int predicted; // what Femora would have predicted at its start
  final int priorCycles; // how many earlier cycles the prediction could use
  final int populationPredicted; // the average woman's cycle length, for comparison

  const BacktestPoint({required this.start, required this.actual, required this.predicted, required this.priorCycles, required this.populationPredicted});

  int get error => (actual - predicted).abs();
  int get populationError => (actual - populationPredicted).abs();
}

/// "Prediction analytics": replays the user's own history. For every completed cycle it asks what Femora would have
/// predicted for its length using only the cycles logged before it, and compares that with what really happened,
/// and with simply using the average woman's cycle length.
class CycleBacktest {
  static const minCycles = 3; // completed cycles needed before a summary is shown

  final List<BacktestPoint> points;
  const CycleBacktest(this.points);

  int get n => points.length;
  bool get enough => n >= minCycles;

  double? get meanError => n == 0 ? null : points.map((p) => p.error).reduce((a, b) => a + b) / n;
  double? get meanPopulationError => n == 0 ? null : points.map((p) => p.populationError).reduce((a, b) => a + b) / n;
  int get within3 => points.where((p) => p.error <= 3).length;
  int get populationWithin3 => points.where((p) => p.populationError <= 3).length;

  /// Plain-language summary, or null until there are enough cycles.
  String? get summary {
    if (!enough) return null;
    final mine = meanError!;
    final base = meanPopulationError!;
    final better = mine < base - 0.05;
    return 'Over your $n logged cycles the predicted length was within 3 days $within3 times (${(within3 * 100 / n).round()}%) and off by '
        '${mine.toStringAsFixed(1)} days on average. Using the average woman\'s ${kCycleParams.lengthMean.round()}-day cycle instead would have been off by '
        '${base.toStringAsFixed(1)} days. ${better ? 'Learning from your own cycles is helping.' : 'Your cycles are close to the average, so there is little to gain yet.'}';
  }

  static CycleBacktest compute(Iterable<PeriodEntry> logged) {
    final starts = CycleEngine(logged, DateTime.now()).periods; // cleaned, oldest first
    final pts = <BacktestPoint>[];
    for (var i = 0; i + 1 < starts.length; i++) {
      final actual = daysBetween(starts[i].start, starts[i + 1].start);
      if (actual < CycleEngine.minCycle || actual > CycleEngine.maxCycle) continue; // duplicates and missed logs are not cycles
      final prefix = starts.sublist(0, i + 1);
      final e = CycleEngine(prefix, starts[i].start);
      pts.add(BacktestPoint(start: starts[i].start, actual: actual, predicted: e.lengthDays, priorCycles: e.n, populationPredicted: kCycleParams.lengthMean.round()));
    }
    return CycleBacktest(pts);
  }
}

/// Cycle history figures for the dashboard.
class CycleHistory {
  final List<int> lengths; // completed cycles, oldest first
  final List<DateTime> starts; // the start of each of those cycles
  final List<int> periodLengths; // logged period lengths, oldest first

  const CycleHistory({required this.lengths, required this.starts, required this.periodLengths});

  static CycleHistory of(CycleEngine e) {
    final ls = <int>[];
    final ss = <DateTime>[];
    for (var i = 0; i + 1 < e.periods.length; i++) {
      final len = daysBetween(e.periods[i].start, e.periods[i + 1].start);
      if (len >= CycleEngine.minCycle && len <= CycleEngine.maxCycle) {
        ls.add(len);
        ss.add(e.periods[i].start);
      }
    }
    return CycleHistory(lengths: ls, starts: ss, periodLengths: [for (final p in e.periods) if (p.length != null) p.length!]);
  }

  /// The last [n] cycles.
  List<int> lastLengths(int n) => lengths.length <= n ? lengths : lengths.sublist(lengths.length - n);
  List<DateTime> lastStarts(int n) => starts.length <= n ? starts : starts.sublist(starts.length - n);

  int? get shortest => lengths.isEmpty ? null : lengths.reduce(math.min);
  int? get longest => lengths.isEmpty ? null : lengths.reduce(math.max);
  double? get average => lengths.isEmpty ? null : lengths.reduce((a, b) => a + b) / lengths.length;
  int get outsideNormal => lengths.where((l) => l < 21 || l > 35).length;
}
