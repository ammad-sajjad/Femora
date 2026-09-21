import 'package:femora/models/cycle_engine.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/models/trends.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 6, 20);
DateTime ago(int n) => addDays(_today, -n);

SymptomLog log(int daysAgo, {String? mood, double? sleep, int? stress, int? energy, List<String> symptoms = const []}) =>
    SymptomLog(date: ago(daysAgo), symptoms: symptoms, mood: mood, sleepHours: sleep, stress: stress, energy: energy);

void main() {
  group('the daily log', () {
    test('sleep, stress and energy survive saving and loading', () {
      final l = SymptomLog(date: ago(1), symptoms: const ['cramps'], mood: 'low', notes: 'tired', sleepHours: 5.5, stress: 4, energy: 2);
      final back = SymptomLog.fromJson(l.toJson());
      expect(back.sleepHours, 5.5);
      expect(back.stress, 4);
      expect(back.energy, 2);
      expect(back.moodScore, 2);
    });

    test('entries saved before these fields existed still load', () {
      final old = SymptomLog.fromJson({'date': ago(2).toIso8601String(), 'symptoms': ['acne'], 'mood': 'good', 'notes': ''});
      expect(old.sleepHours, isNull);
      expect(old.stress, isNull);
      expect(old.energy, isNull);
      expect(old.moodScore, 4);
    });

    test('mood becomes a number from bad 1 to great 5, and nothing for no mood', () {
      expect([for (final m in ['bad', 'low', 'okay', 'good', 'great']) log(0, mood: m).moodScore], [1, 2, 3, 4, 5]);
      expect(log(0).moodScore, isNull);
    });
  });

  group('the window', () {
    test('has one slot per day, oldest first, empty where nothing was logged', () {
      final s = TrendStats.compute([log(0, mood: 'good'), log(2, mood: 'low')], _today, 7);
      expect(s.byDay, hasLength(7));
      expect(s.start, ago(6));
      expect(s.end, _today);
      expect(s.byDay.last!.mood, 'good');
      expect(s.byDay[4]!.mood, 'low'); // two days ago
      expect(s.byDay[5], isNull);
      expect(s.logged, 2);
      expect(s.moodSeries.last, 4);
      expect(s.moodSeries[5], isNull);
    });

    test('ignores entries outside it', () {
      final s = TrendStats.compute([log(40, mood: 'bad'), log(1, mood: 'great')], _today, 30);
      expect(s.logged, 1);
      expect(s.avgMood, 5);
    });

    test('averages skip days where a value was not logged', () {
      final s = TrendStats.compute([log(0, sleep: 6, stress: 2), log(1, sleep: 8), log(2, stress: 4, energy: 3)], _today, 7);
      expect(s.avgSleep, 7);
      expect(s.avgStress, 3);
      expect(s.avgEnergy, 3);
      expect(s.avgMood, isNull);
    });

    test('an empty period says so and has no averages', () {
      final s = TrendStats.compute(const [], _today, 30);
      expect(s.logged, 0);
      expect(s.avgSleep, isNull);
      expect(s.insights.single, contains('Nothing logged'));
    });

    test('counts symptoms, most frequent first', () {
      final s = TrendStats.compute([
        log(0, symptoms: ['cramps', 'acne']),
        log(1, symptoms: ['cramps']),
        log(2, symptoms: ['cramps', 'fatigue']),
        log(3, symptoms: ['acne']),
      ], _today, 7);
      expect(s.topSymptoms.first, ('cramps', 3));
      expect(s.topSymptoms[1], ('acne', 2));
      expect(s.topSymptoms.last, ('fatigue', 1));
    });
  });

  group('insights', () {
    test('few days logged: ask for more instead of drawing conclusions', () {
      final s = TrendStats.compute([log(0, sleep: 4), log(1, sleep: 4)], _today, 30);
      expect(s.insights.single, contains('Log at least 5 days'));
    });

    test('short sleep is reported with the count of short nights', () {
      final s = TrendStats.compute([for (var i = 0; i < 8; i++) log(i, sleep: i.isEven ? 5 : 6.5)], _today, 30);
      expect(s.avgSleep, closeTo(5.75, 1e-9));
      expect(s.shortSleepDays, 4);
      expect(s.insights.first, contains('averaged 5.8 hours'));
      expect(s.insights.first, contains('under 6 hours on 4 of 8'));
    });

    test('good sleep is acknowledged', () {
      final s = TrendStats.compute([for (var i = 0; i < 6; i++) log(i, sleep: 8)], _today, 30);
      expect(s.insights.first, contains('on track'));
    });

    test('very long sleep suggests mentioning it to a doctor if still tired', () {
      final s = TrendStats.compute([for (var i = 0; i < 6; i++) log(i, sleep: 10)], _today, 30);
      expect(s.insights.first, contains('more than the usual'));
    });

    test('frequent high stress is flagged, occasional is not', () {
      final often = TrendStats.compute([for (var i = 0; i < 10; i++) log(i, stress: i < 4 ? 5 : 2)], _today, 30);
      expect(often.highStressDays, 4);
      expect(often.insights.join(' '), contains('Stress was high'));
      final rare = TrendStats.compute([for (var i = 0; i < 10; i++) log(i, stress: i == 0 ? 5 : 2)], _today, 30);
      expect(rare.insights.join(' '), isNot(contains('Stress was high')));
    });

    test('a run of low moods suggests talking to someone after two weeks', () {
      final s = TrendStats.compute([for (var i = 0; i < 10; i++) log(i, mood: i < 6 ? 'low' : 'good')], _today, 30);
      expect(s.lowMoodDays, 6);
      expect(s.insights.join(' '), contains('two weeks or more'));
    });

    test('short sleep going with a worse mood is pointed out', () {
      final logs = [
        for (var i = 0; i < 4; i++) log(i, sleep: 5, mood: 'low'),
        for (var i = 4; i < 9; i++) log(i, sleep: 8, mood: 'good'),
      ];
      final s = TrendStats.compute(logs, _today, 30);
      expect(s.insights.join(' '), contains('slept under 6 hours your mood averaged 2.0 of 5, against 4.0'));
    });

    test('mood labels', () {
      expect(TrendStats.moodLabel(4.8), 'great');
      expect(TrendStats.moodLabel(3.6), 'good');
      expect(TrendStats.moodLabel(3.0), 'okay');
      expect(TrendStats.moodLabel(2.0), 'low');
      expect(TrendStats.moodLabel(1.2), 'bad');
    });
  });

  group('the store', () {
    test('keeps sleep, stress and energy and finds an entry by day', () async {
      final s = HealthStore()..now = () => _today;
      await s.addLog(SymptomLog(date: _today, symptoms: const [], sleepHours: 7, stress: 3, energy: 4));
      expect(s.logOn(_today)!.sleepHours, 7);
      expect(s.logOn(ago(1)), isNull);
      // a second save for the same day replaces the first
      await s.addLog(SymptomLog(date: _today, symptoms: const ['acne'], sleepHours: 6));
      expect(s.logs, hasLength(1));
      expect(s.logOn(_today)!.sleepHours, 6);
    });

    test('keeps up to a year of daily logs', () async {
      final s = HealthStore()..now = () => _today;
      for (var i = 0; i < 400; i++) {
        await s.addLog(SymptomLog(date: ago(i), symptoms: const []));
      }
      expect(s.logs, hasLength(HealthStore.maxLogs));
      expect(HealthStore.maxLogs, 365);
      expect(s.logs.last.date, _today);
    });

    test('the companion hears the recent averages', () async {
      final s = HealthStore()..now = () => _today;
      await s.addLog(SymptomLog(date: _today, symptoms: const ['cramps'], mood: 'low', sleepHours: 5, stress: 4, energy: 2));
      await s.addLog(SymptomLog(date: ago(1), symptoms: const [], sleepHours: 6, stress: 2, energy: 2));
      final ctx = s.companionContext();
      expect(ctx, contains('average sleep 5.5 h'));
      expect(ctx, contains('stress 3.0 of 5'));
      expect(ctx, contains('energy 2.0 of 5'));
    });
  });
}
