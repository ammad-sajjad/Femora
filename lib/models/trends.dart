import 'cycle_engine.dart';
import 'health_store.dart';

/// What the daily logs of the last [days] days add up to. Pure calculation, no Flutter, so it is easy to test.
class TrendStats {
  final int days;
  final DateTime start; // first day of the window
  final DateTime end; // last day of the window (today)
  final List<SymptomLog?> byDay; // oldest first, one slot per day, null where nothing was logged

  final int logged;
  final double? avgMood; // 1 (bad) to 5 (great)
  final double? avgSleep; // hours
  final double? avgStress; // 1 to 5
  final double? avgEnergy; // 1 to 5
  final int sleepLogged;
  final int shortSleepDays; // under 6 hours
  final int stressLogged;
  final int highStressDays; // 4 or 5
  final int moodLogged;
  final int lowMoodDays; // low or bad
  final List<(String, int)> topSymptoms; // most frequent first
  final List<String> insights;

  const TrendStats._({
    required this.days,
    required this.start,
    required this.end,
    required this.byDay,
    required this.logged,
    required this.avgMood,
    required this.avgSleep,
    required this.avgStress,
    required this.avgEnergy,
    required this.sleepLogged,
    required this.shortSleepDays,
    required this.stressLogged,
    required this.highStressDays,
    required this.moodLogged,
    required this.lowMoodDays,
    required this.topSymptoms,
    required this.insights,
  });

  static const sleepLow = 7.0; // adults usually need 7 to 9 hours
  static const sleepHigh = 9.0;
  static const minDaysForInsights = 5;

  static String moodLabel(double score) => score >= 4.5
      ? 'great'
      : score >= 3.5
          ? 'good'
          : score >= 2.5
              ? 'okay'
              : score >= 1.5
                  ? 'low'
                  : 'bad';

  static TrendStats compute(List<SymptomLog> logs, DateTime today, int days) {
    final end = dayOf(today);
    final start = addDays(end, -(days - 1));
    final byDate = <DateTime, SymptomLog>{for (final l in logs) dayOf(l.date): l};
    final byDay = <SymptomLog?>[for (var i = 0; i < days; i++) byDate[addDays(start, i)]];
    final present = [for (final l in byDay) if (l != null) l];

    double? avg(Iterable<num> xs) => xs.isEmpty ? null : xs.map((x) => x.toDouble()).reduce((a, b) => a + b) / xs.length;

    final moods = [for (final l in present) if (l.moodScore != null) l.moodScore!];
    final sleeps = [for (final l in present) if (l.sleepHours != null) l.sleepHours!];
    final stresses = [for (final l in present) if (l.stress != null) l.stress!];
    final energies = [for (final l in present) if (l.energy != null) l.energy!];

    final counts = <String, int>{};
    for (final l in present) {
      for (final s in l.symptoms) {
        counts[s] = (counts[s] ?? 0) + 1;
      }
    }
    final top = counts.entries.toList()..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));

    final shortSleep = sleeps.where((h) => h < 6).length;
    final highStress = stresses.where((s) => s >= 4).length;
    final lowMood = moods.where((m) => m <= 2).length;
    final insights = <String>[];

    if (present.length < minDaysForInsights) {
      insights.add(present.isEmpty
          ? 'Nothing logged in this period yet. Log how you feel each day to see your patterns.'
          : 'Only ${present.length} day${present.length == 1 ? '' : 's'} logged so far. Log at least $minDaysForInsights days to see reliable patterns.');
    } else {
      final sAvg = avg(sleeps);
      if (sleeps.length >= minDaysForInsights && sAvg != null) {
        if (sAvg < sleepLow) {
          insights.add('You averaged ${sAvg.toStringAsFixed(1)} hours of sleep${shortSleep > 0 ? ' and slept under 6 hours on $shortSleep of ${sleeps.length} days' : ''}. Adults usually need 7 to 9 hours.');
        } else if (sAvg > sleepHigh) {
          insights.add('You averaged ${sAvg.toStringAsFixed(1)} hours of sleep, more than the usual 7 to 9. If you still feel tired, it is worth mentioning to a doctor.');
        } else {
          insights.add('Your sleep is on track: ${sAvg.toStringAsFixed(1)} hours on average.');
        }
      }
      if (stresses.length >= minDaysForInsights && highStress * 100 >= stresses.length * 30) {
        insights.add('Stress was high (4 or 5 of 5) on $highStress of ${stresses.length} days. Short walks, slow breathing and talking to someone can help; see a doctor if it does not ease.');
      }
      if (moods.length >= minDaysForInsights && lowMood >= 5 && lowMood * 100 >= moods.length * 40) {
        insights.add('Your mood was low or bad on $lowMood of ${moods.length} days. If low mood lasts two weeks or more, please talk to a doctor or someone you trust.');
      }
      // Does short sleep go with a worse mood?
      final both = [for (final l in present) if (l.sleepHours != null && l.moodScore != null) l];
      final short = [for (final l in both) if (l.sleepHours! < 6) l.moodScore!];
      final rest = [for (final l in both) if (l.sleepHours! >= 6) l.moodScore!];
      if (both.length >= 8 && short.length >= 3 && rest.length >= 3) {
        final a = avg(short)!;
        final b = avg(rest)!;
        if (b - a >= 0.7) {
          insights.add('On days you slept under 6 hours your mood averaged ${a.toStringAsFixed(1)} of 5, against ${b.toStringAsFixed(1)} on other days.');
        }
      }
      if (top.isNotEmpty) {
        insights.add('Most frequent symptom: ${top.first.key}, on ${top.first.value} of ${present.length} logged days.');
      }
    }

    return TrendStats._(
      days: days,
      start: start,
      end: end,
      byDay: byDay,
      logged: present.length,
      avgMood: avg(moods),
      avgSleep: avg(sleeps),
      avgStress: avg(stresses),
      avgEnergy: avg(energies),
      sleepLogged: sleeps.length,
      shortSleepDays: shortSleep,
      stressLogged: stresses.length,
      highStressDays: highStress,
      moodLogged: moods.length,
      lowMoodDays: lowMood,
      topSymptoms: [for (final e in top) (e.key, e.value)],
      insights: insights,
    );
  }

  List<double?> get moodSeries => [for (final l in byDay) l?.moodScore?.toDouble()];
  List<double?> get sleepSeries => [for (final l in byDay) l?.sleepHours];
  List<double?> get stressSeries => [for (final l in byDay) l?.stress?.toDouble()];
  List<double?> get energySeries => [for (final l in byDay) l?.energy?.toDouble()];
}
