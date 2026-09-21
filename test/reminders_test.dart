import 'package:femora/models/cycle_engine.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/models/reminders.dart';
import 'fake_reminders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _base = DateTime(2026, 1, 1);
DateTime d(int offset) => addDays(_base, offset);
DateTime at(int offset, int h, [int m = 0]) => DateTime(_base.year, _base.month, _base.day + offset, h, m);
PeriodEntry p(int offset) => PeriodEntry(start: d(offset));

/// Regular 28-day cycles; today is day 100 at 10:00, the next period is expected on day 112 (23 April).
CycleEngine regular({int today = 100}) => CycleEngine([p(0), p(28), p(56), p(84)], at(today, 10));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final now = at(100, 10);

  group('what the planner schedules', () {
    test('nothing is on by default', () {
      expect(ReminderPlanner.plan(const ReminderSettings(), regular(), now), isEmpty);
    });

    test('a period reminder one day before, for the next two periods, with the likely window', () {
      final plan = ReminderPlanner.plan(const ReminderSettings(period: true), regular(), now);
      expect(plan.map((r) => r.id), [ReminderPlanner.periodBase, ReminderPlanner.periodBase + 1]);
      expect(plan.first.when, at(111, 9));
      expect(plan.first.title, 'Period coming up');
      expect(plan.first.body, contains('in 1 day'));
      expect(plan.first.body, contains('around 23 Apr'));
      expect(plan.first.body, contains('between 20 Apr and 26 Apr'));
      expect(plan.last.when, at(139, 9)); // the period after that: day 140
    });

    test('on the day, two and three days before', () {
      DateTime first(int before) => ReminderPlanner.plan(ReminderSettings(period: true, periodDaysBefore: before), regular(), now).first.when;
      expect(first(0), at(112, 9));
      expect(first(2), at(110, 9));
      expect(first(3), at(109, 9));
      expect(ReminderPlanner.plan(const ReminderSettings(period: true, periodDaysBefore: 0), regular(), now).first.body, contains('expected today'));
    });

    test('a reminder time that has already passed is skipped', () {
      final e = regular(today: 111);
      final plan = ReminderPlanner.plan(const ReminderSettings(period: true), e, at(111, 10));
      expect(plan, hasLength(1)); // day 111 at 9:00 is gone; only the following period remains
      expect(plan.single.id, ReminderPlanner.periodBase + 1);
    });

    test('the fertile window and ovulation day are announced for the coming cycles, not for days already gone', () {
      final plan = ReminderPlanner.plan(const ReminderSettings(fertile: true), regular(), now);
      final fertile = plan.where((r) => r.kind == ReminderKind.fertile).toList();
      final ovulation = plan.where((r) => r.kind == ReminderKind.ovulation).toList();
      expect(fertile.map((r) => r.id), [ReminderPlanner.fertileBase + 1, ReminderPlanner.fertileBase + 2]);
      expect(ovulation.map((r) => r.id), [ReminderPlanner.ovulationBase + 1, ReminderPlanner.ovulationBase + 2]);
      expect(fertile.first.when, at(122, 9)); // 5 days before ovulation on day 127
      expect(fertile.first.body, contains('from 3 May to 9 May'));
      expect(fertile.first.body, contains('not a way to prevent pregnancy'));
      expect(ovulation.first.when, at(127, 9));
    });

    test('while a period is late there are no predictions to remind about', () {
      final late = CycleEngine([p(0), p(28), p(56)], at(96, 10));
      expect(late.isLate, isTrue);
      expect(ReminderPlanner.plan(const ReminderSettings(period: true, fertile: true), late, at(96, 10)), isEmpty);
    });

    test('with no logged period there is nothing to predict', () {
      expect(ReminderPlanner.plan(const ReminderSettings(period: true, fertile: true), CycleEngine(const [], now), now), isEmpty);
    });

    test('the daily log reminder repeats, and starts today or tomorrow depending on the time', () {
      final evening = ReminderPlanner.plan(const ReminderSettings(dailyLog: true, dailyHour: 20), regular(), now).single;
      expect(evening.when, at(100, 20));
      expect(evening.repeatsDaily, isTrue);
      expect(evening.id, ReminderPlanner.dailyLogId);
      final morning = ReminderPlanner.plan(const ReminderSettings(dailyLog: true, dailyHour: 8, dailyMinute: 30), regular(), now).single;
      expect(morning.when, at(101, 8, 30));
    });

    test('each enabled medication repeats daily at its own time; disabled ones are left out', () {
      final s = const ReminderSettings(medications: [
        Medication(id: 0, name: 'Vitamin D', hour: 8, minute: 0),
        Medication(id: 3, name: 'Iron', hour: 21, minute: 15),
        Medication(id: 4, name: 'Old one', hour: 7, minute: 0, enabled: false),
      ]);
      final plan = ReminderPlanner.plan(s, regular(), now);
      expect(plan.map((r) => r.id), [ReminderPlanner.medicationBase + 3, ReminderPlanner.medicationBase]); // by time: 21:15 today, then 8:00 tomorrow
      expect(plan.first.body, 'Iron');
      expect(plan.first.when, at(100, 21, 15));
      expect(plan.every((r) => r.repeatsDaily), isTrue);
      expect(plan.first.title, 'Medication reminder');
    });

    test('everything on gives unique ids, sorted by time', () {
      final s = const ReminderSettings(period: true, fertile: true, dailyLog: true, medications: [Medication(id: 0, name: 'X', hour: 9, minute: 0)]);
      final plan = ReminderPlanner.plan(s, regular(), now);
      expect(plan.map((r) => r.id).toSet().length, plan.length);
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].when.isBefore(plan[i - 1].when), isFalse);
      }
    });

    test('a medication body carries only the name the user typed, never advice', () {
      final plan = ReminderPlanner.plan(const ReminderSettings(medications: [Medication(id: 1, name: 'Metformin', hour: 22, minute: 0)]), regular(), now);
      expect(plan.single.body, 'Metformin');
      expect(plan.single.body, isNot(contains('mg')));
    });
  });

  group('the settings on the phone', () {
    late Recorder rec;
    late RemindersState state;
    setUp(() {
      rec = Recorder();
      state = RemindersState(service: rec, clock: () => now);
    });

    test('turning the period reminder on asks permission once and schedules it', () async {
      final err = await state.update(state.settings.copyWith(period: true), regular());
      expect(err, isNull);
      expect(rec.permissionAsks, 1);
      expect(rec.scheduled.map((r) => r.id), [ReminderPlanner.periodBase, ReminderPlanner.periodBase + 1]);
      expect(rec.scheduled.first.channel, 'period');
      expect(state.scheduledIds, [ReminderPlanner.periodBase, ReminderPlanner.periodBase + 1]);
    });

    test('settings and what was scheduled survive a restart', () async {
      await state.update(state.settings.copyWith(period: true, periodDaysBefore: 2, dailyLog: true, dailyHour: 7, dailyMinute: 45), regular());
      final again = RemindersState(service: Recorder(), clock: () => now);
      await again.load();
      expect(again.loaded, isTrue);
      expect(again.settings.period, isTrue);
      expect(again.settings.periodDaysBefore, 2);
      expect(again.settings.dailyLog, isTrue);
      expect((again.settings.dailyHour, again.settings.dailyMinute), (7, 45));
      expect(again.scheduledIds, isNotEmpty);
    });

    test('turning it off cancels what was scheduled and asks for nothing', () async {
      await state.update(state.settings.copyWith(period: true), regular());
      rec.scheduled.clear();
      rec.permissionAsks = 0;
      await state.update(state.settings.copyWith(period: false), regular());
      expect(rec.cancelled, containsAll([ReminderPlanner.periodBase, ReminderPlanner.periodBase + 1]));
      expect(rec.scheduled, isEmpty);
      expect(rec.permissionAsks, 0);
      expect(state.scheduledIds, isEmpty);
    });

    test('refused permission leaves the setting off and says why', () async {
      rec.allow = false;
      final err = await state.update(state.settings.copyWith(dailyLog: true), regular());
      expect(err, contains('Allow notifications'));
      expect(state.settings.dailyLog, isFalse);
      expect(rec.scheduled, isEmpty);
    });

    test('on a platform without notifications it explains and changes nothing', () async {
      rec.supported = false;
      final err = await state.update(state.settings.copyWith(period: true), regular());
      expect(err, contains('mobile app'));
      expect(state.settings.period, isFalse);
      expect(state.supported, isFalse);
    });

    test('a new period log recalculates: old reminders are cancelled and the new dates scheduled', () async {
      await state.update(state.settings.copyWith(period: true), regular());
      final before = rec.scheduled.first.when;
      rec.scheduled.clear();
      rec.cancelled.clear();
      final moved = CycleEngine([p(0), p(28), p(56), p(84), p(113)], at(115, 10));
      final later = RemindersState(service: rec, clock: () => at(115, 10));
      await later.load();
      await later.update(later.settings.copyWith(period: true), moved);
      rec.scheduled.clear();
      await state.apply(moved);
      expect(rec.cancelled, containsAll([ReminderPlanner.periodBase, ReminderPlanner.periodBase + 1]));
      expect(before, at(111, 9));
    });

    test('medications: added with a free id, scheduled daily, switched off and removed', () async {
      final e = regular();
      expect(await state.addMedication('  Vitamin D ', 8, 0, e), isNull);
      expect(await state.addMedication('Iron', 21, 30, e), isNull);
      expect(state.settings.medications.map((m) => (m.id, m.name)), [(0, 'Vitamin D'), (1, 'Iron')]);
      expect(rec.scheduled.where((r) => r.daily).map((r) => r.id).toSet(), {ReminderPlanner.medicationBase, ReminderPlanner.medicationBase + 1});

      rec.scheduled.clear();
      expect(await state.setMedicationEnabled(0, false, e), isNull);
      expect(rec.scheduled.map((r) => r.id), [ReminderPlanner.medicationBase + 1]);

      expect(await state.setMedicationTime(1, 6, 15, e), isNull);
      expect(state.settings.medications.last.hour, 6);

      expect(await state.removeMedication(0, e), isNull);
      expect(state.settings.medications.map((m) => m.name), ['Iron']);
      expect(await state.addMedication('Zinc', 9, 0, e), isNull);
      expect(state.settings.medications.map((m) => m.id), [1, 0]); // the freed id is reused
    });

    test('medication names are checked', () async {
      final e = regular();
      expect(await state.addMedication('   ', 8, 0, e), contains('name'));
      expect(await state.addMedication('x' * 41, 8, 0, e), contains('under 40'));
      for (var i = 0; i < ReminderSettings.maxMedications; i++) {
        expect(await state.addMedication('Med $i', 8, 0, e), isNull);
      }
      expect(await state.addMedication('One too many', 8, 0, e), contains('up to 10'));
    });

    test('delete all my data cancels every reminder and clears the settings', () async {
      await state.update(state.settings.copyWith(period: true, dailyLog: true), regular());
      final ids = state.scheduledIds;
      rec.cancelled.clear();
      await state.clearAll();
      expect(rec.cancelled, containsAll(ids));
      expect(state.settings.anyOn, isFalse);
      final again = RemindersState(service: rec, clock: () => now);
      await again.load();
      expect(again.settings.anyOn, isFalse);
    });

    test('damaged saved settings fall back to everything off', () async {
      SharedPreferences.setMockInitialValues({'reminders_v1': '{not json'});
      final s = RemindersState(service: rec, clock: () => now);
      await s.load();
      expect(s.loaded, isTrue);
      expect(s.settings.anyOn, isFalse);
    });

    test('upcoming lists what will be sent next', () async {
      await state.update(state.settings.copyWith(period: true), regular());
      expect(state.upcoming(regular()).map((r) => r.kind), [ReminderKind.period, ReminderKind.period]);
    });
  });

  group('the store tells reminders when the cycle changes', () {
    test('logging, ending and removing a period, and loading an account, all call the hook', () async {
      var calls = 0;
      final store = HealthStore()..now = () => at(100, 10);
      store.onCycleChanged = () => calls++;
      await store.logPeriodStart(d(95));
      await store.logPeriodEnd(d(99));
      await store.removePeriod(d(95));
      await store.load();
      var cleared = 0;
      store.onCleared = () => cleared++;
      await store.clearAll();
      expect(calls, 5);
      expect(cleared, 1);
    });
  });
}
