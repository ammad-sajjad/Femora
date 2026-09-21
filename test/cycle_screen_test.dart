import 'package:femora/models/cycle_engine.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/models/models.dart';
import 'package:femora/screens/cycle_calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 6, 20, 10);
DateTime ago(int days) => addDays(DateTime(2026, 6, 20), -days);
PeriodEntry p(int daysAgo, {int? lengthDays}) => PeriodEntry(start: ago(daysAgo), end: lengthDays == null ? null : addDays(ago(daysAgo), lengthDays - 1));

class _Harness {
  final HealthStore store = HealthStore()..now = () => _now;
  final AppState app = AppState()..now = () => _now;
  Widget get widget => MultiProvider(
        providers: [ChangeNotifierProvider.value(value: app), ChangeNotifierProvider.value(value: store)],
        child: const MaterialApp(home: CycleCalendarScreen()),
      );
}

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 4200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) => (tester.widget(find.byKey(Key(key))) as Text).data!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a new user is invited to log a period, and one tap starts tracking', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget);
    expect(find.text('Track your cycle'), findsOneWidget);
    expect(find.byKey(const Key('cycle_next')), findsNothing);

    await _tap(tester, find.byKey(const Key('log_period_start')));
    expect(h.store.periods.single.start, ago(0));
    expect(_text(tester, 'cycle_title'), 'Period day 1');
    expect(find.byKey(const Key('log_period_end')), findsOneWidget); // the button now ends the period
    expect(find.text('My period ended today'), findsOneWidget);
  });

  testWidgets('with logged cycles it shows the cycle day, phase, next period and the honest basis', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.periods = [p(120, lengthDays: 5), p(92, lengthDays: 5), p(64, lengthDays: 5), p(36, lengthDays: 5), p(8, lengthDays: 5)];
    await tester.pumpWidget(h.widget);
    expect(_text(tester, 'cycle_title'), 'Cycle day 9 · Follicular phase');
    expect(_text(tester, 'cycle_next'), '10 Jul · in 20 days');
    expect(_text(tester, 'cycle_window'), startsWith('Likely between'));
    expect(_text(tester, 'cycle_basis'), contains('4 logged cycles'));
    expect(find.text('Ovulation (estimate)'), findsOneWidget);
    expect(find.textContaining('not a way to prevent pregnancy'), findsOneWidget);
    expect(find.byKey(const Key('cycle_history')), findsOneWidget);
    expect(find.textContaining('28-day cycle'), findsWidgets);
    expect(find.byKey(const Key('cycle_flags')), findsNothing); // nothing unusual
  });

  testWidgets('the month grid opens on the current month and can be browsed', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.periods = [p(36, lengthDays: 5), p(8, lengthDays: 5)];
    await tester.pumpWidget(h.widget);
    expect(_text(tester, 'month_title'), 'June 2026');
    expect(find.byKey(const Key('cycle_day_2026-06-20')), findsOneWidget);
    await _tap(tester, find.byKey(const Key('month_next')));
    expect(_text(tester, 'month_title'), 'July 2026');
    expect(find.byKey(const Key('cycle_day_2026-07-31')), findsOneWidget);
    await _tap(tester, find.byKey(const Key('month_prev')));
    await _tap(tester, find.byKey(const Key('month_prev')));
    expect(_text(tester, 'month_title'), 'May 2026');
  });

  testWidgets('an unfinished period offers to end it, and saves the length', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.periods = [p(30, lengthDays: 5), p(2)];
    await tester.pumpWidget(h.widget);
    expect(_text(tester, 'cycle_title'), 'Period day 3');
    await _tap(tester, find.byKey(const Key('log_period_end')));
    expect(h.store.periods.last.length, 3);
    expect(find.byKey(const Key('log_period_start')), findsOneWidget);
  });

  testWidgets('a refused log explains why instead of failing quietly', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.periods = [p(10, lengthDays: 5)];
    await tester.pumpWidget(h.widget);
    await _tap(tester, find.byKey(const Key('log_period_start')));
    expect(find.textContaining('already logged'), findsOneWidget);
    expect(h.store.periods, hasLength(1));
  });

  testWidgets('a period that is very late is flagged with advice', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.periods = [p(96, lengthDays: 5), p(68, lengthDays: 5), p(40, lengthDays: 5)];
    await tester.pumpWidget(h.widget);
    expect(_text(tester, 'cycle_next'), contains('12 days late'));
    expect(find.byKey(const Key('cycle_flags')), findsOneWidget);
    expect(find.textContaining('12 days later than expected'), findsOneWidget);
    expect(find.text('Ovulation (estimate)'), findsNothing); // no predictions while she is late
  });

  testWidgets('irregular cycles are named and lead to the PCOS check', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.periods = [p(155, lengthDays: 5), p(131, lengthDays: 5), p(95, lengthDays: 5), p(68, lengthDays: 5), p(30, lengthDays: 5)]; // 24, 36, 27, 38
    await tester.pumpWidget(h.widget);
    expect(find.textContaining('vary by 14 days'), findsOneWidget);
    expect(find.textContaining('irregular'), findsWidgets);
    await _tap(tester, find.byKey(const Key('flags_pcos')));
    expect(h.app.currentTabIndex, 2);
  });

  testWidgets('tapping a past day lets her log a period start there', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.periods = [p(60, lengthDays: 5)];
    await tester.pumpWidget(h.widget);
    await _tap(tester, find.byKey(const Key('cycle_day_2026-06-10')));
    expect(find.text('My period started this day'), findsOneWidget);
    await tester.tap(find.byKey(const Key('day_log_start')));
    await tester.pumpAndSettle();
    expect(h.store.periods.map((e) => e.start), [ago(60), ago(10)]);
  });

  testWidgets('tapping a logged start day offers removal', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.periods = [p(60, lengthDays: 5), p(10, lengthDays: 5)];
    await tester.pumpWidget(h.widget);
    await _tap(tester, find.byKey(const Key('cycle_day_2026-06-10')));
    await tester.tap(find.byKey(const Key('day_remove')));
    await tester.pumpAndSettle();
    expect(h.store.periods.map((e) => e.start), [ago(60)]);
  });

  testWidgets('a future day cannot be logged', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.periods = [p(8, lengthDays: 5)];
    await tester.pumpWidget(h.widget);
    await _tap(tester, find.byKey(const Key('cycle_day_2026-06-25')));
    expect(find.text('My period started this day'), findsNothing);
    expect(find.textContaining('once it has started'), findsOneWidget);
  });

  testWidgets('symptom and mood logging still works below the calendar', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget);
    expect(find.text('Log Symptoms'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('mood_good')));
    expect(h.app.mood, 'good');
  });
}
