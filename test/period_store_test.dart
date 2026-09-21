import 'package:femora/models/cycle_engine.dart';
import 'package:femora/models/health_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _today = DateTime(2026, 6, 20, 10);
DateTime day(int daysAgo) => addDays(DateTime(2026, 6, 20), -daysAgo);

HealthStore _store() => HealthStore()..now = () => _today;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a logged period start is saved and survives a restart', () async {
    final s = _store();
    expect(await s.logPeriodStart(day(3)), isNull);
    expect(s.periods, hasLength(1));
    expect(s.cycle.cycleDay, 4);

    final again = _store();
    await again.load();
    expect(again.periods.single.start, day(3));
    expect(again.periods.single.end, isNull);
  });

  test('ending the period records its length', () async {
    final s = _store();
    await s.logPeriodStart(day(5));
    expect(await s.logPeriodEnd(day(1)), isNull);
    expect(s.periods.single.length, 5);
    final again = _store();
    await again.load();
    expect(again.periods.single.end, day(1));
  });

  test('the future cannot be logged, and the same day twice is refused', () async {
    final s = _store();
    expect(await s.logPeriodStart(addDays(_today, 1)), contains('already started'));
    expect(await s.logPeriodStart(day(2)), isNull);
    expect(await s.logPeriodStart(day(2)), contains('already logged'));
    expect(s.periods, hasLength(1));
  });

  test('a start less than 15 days from another period is refused with the date of the other one', () async {
    final s = _store();
    await s.logPeriodStart(day(20));
    final msg = await s.logPeriodStart(day(10));
    expect(msg, contains('already logged on'));
    expect(msg, contains('${day(20).day}/${day(20).month}/${day(20).year}'));
    expect(s.periods, hasLength(1));
  });

  test('an end date needs an earlier start, must not be too far away and must not pass the next period', () async {
    final s = _store();
    expect(await s.logPeriodEnd(day(1)), contains('started first'));
    await s.logPeriodStart(day(60));
    await s.logPeriodStart(day(30));
    expect(await s.logPeriodEnd(day(40)), contains('more than 15 days'));
    expect(await s.logPeriodEnd(addDays(_today, 1)), contains('already happened'));
    expect(await s.logPeriodEnd(day(56)), isNull);
    expect(s.periods.first.length, 5);
    expect(s.periods.last.end, isNull);
  });

  test('periods can be removed', () async {
    final s = _store();
    await s.logPeriodStart(day(50));
    await s.logPeriodStart(day(20));
    await s.removePeriod(day(50));
    expect(s.periods.map((e) => e.start), [day(20)]);
  });

  test('two accounts on one phone keep separate cycles', () async {
    final s = _store();
    await s.useAccount('anna');
    await s.logPeriodStart(day(10));
    await s.useAccount('sara');
    expect(s.periods, isEmpty);
    await s.logPeriodStart(day(4));
    await s.useAccount('anna');
    expect(s.periods.single.start, day(10));
  });

  test('delete all my data removes the cycle history too', () async {
    final s = _store();
    await s.logPeriodStart(day(10));
    await s.clearAll();
    expect(s.periods, isEmpty);
    final again = _store();
    await again.load();
    expect(again.periods, isEmpty);
  });

  test('the companion hears about the cycle, without dates', () async {
    final s = _store();
    for (final ago in [84, 56, 28, 0]) {
      await s.logPeriodStart(day(ago));
    }
    final ctx = s.companionContext();
    expect(ctx, contains('Cycle tracking:'));
    expect(ctx, contains('3 cycles logged'));
    expect(ctx, isNot(contains('2026')));
  });

  test('a store with no periods adds no cycle line', () {
    expect(_store().companionContext(), isNot(contains('Cycle tracking')));
  });

  test('data saved before cycle tracking existed still loads', () async {
    SharedPreferences.setMockInitialValues({
      'health_store_v1_guest': '{"profile":{"name":"A","onboarded":true},"pcos":null,"breastRisk":null,"scan":null,"logs":[]}',
    });
    final s = _store();
    await s.load();
    expect(s.profile.name, 'A');
    expect(s.periods, isEmpty);
  });
}
