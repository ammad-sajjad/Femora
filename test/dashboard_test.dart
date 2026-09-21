import 'package:femora/models/cycle_engine.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/models/models.dart';
import 'package:femora/models/reminders.dart';
import 'package:femora/models/self_exam.dart';
import 'package:femora/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_reminders.dart';

final _base = DateTime(2026, 1, 1);
DateTime d(int offset) => addDays(_base, offset);
PeriodEntry p(int offset, {int len = 5}) => PeriodEntry(start: d(offset), end: d(offset + len - 1));
SymptomLog log(int offset, {List<String> symptoms = const [], String? mood, double? sleep, int? stress, int? energy}) =>
    SymptomLog(date: d(offset), symptoms: symptoms, mood: mood, sleepHours: sleep, stress: stress, energy: energy);

class _Harness {
  final int today;
  final Recorder rec = Recorder();
  late final HealthStore store = HealthStore()..now = (() => d(today).add(const Duration(hours: 10)));
  late final AppState app = AppState()..now = (() => d(today).add(const Duration(hours: 10)));
  _Harness([this.today = 100]);

  Widget get widget => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: app),
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: RemindersState(service: rec, clock: () => d(today))),
          ChangeNotifierProvider.value(value: SelfExamState(reminders: rec)),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      );

  /// 28-day cycles with the usual pattern in the log (cramps, good follicular days, low luteal days).
  void fill() {
    store.periods = [p(0), p(28), p(56), p(84)];
    store.logs = [
      for (var c = 0; c < 4; c++) ...[
        for (var i = 0; i < 5; i++) log(c * 28 + i, symptoms: ['cramps'], mood: 'okay', energy: 3, sleep: 7, stress: 3),
        for (var i = 5; i < 14; i++) log(c * 28 + i, mood: 'good', energy: 4, sleep: 8, stress: 2),
        for (var i = 17; i < 28; i++) log(c * 28 + i, symptoms: ['bloating', 'tender'], mood: 'low', energy: 2, sleep: 6.5, stress: 4),
      ]
    ].where((l) => !l.date.isAfter(d(100))).toList();
  }
}

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 12000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

String _tile(WidgetTester tester, String key) {
  final texts = find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)).evaluate().map((e) => (e.widget as Text).data!).toList();
  return texts.last;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a new user sees empty states that explain what to log, not made-up charts', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget);
    expect(_tile(tester, 'glance_day'), '-');
    expect(_tile(tester, 'glance_next'), '-');
    expect(_tile(tester, 'glance_avg'), '-');
    expect(find.byKey(const Key('dash_no_history')), findsOneWidget);
    expect(find.byKey(const Key('dash_analytics_empty')), findsOneWidget);
    expect(find.byKey(const Key('dash_phase_empty')), findsOneWidget);
    expect(find.text('Not checked yet'), findsNWidgets(2));
    expect(find.text('Not scanned yet'), findsOneWidget);
  });

  testWidgets('with a cycle history it shows the headline numbers, the history chart and the prediction check', (tester) async {
    _tallScreen(tester);
    final h = _Harness()..fill();
    await tester.pumpWidget(h.widget);
    expect(_tile(tester, 'glance_day'), '17 · Ovulation');
    expect(_tile(tester, 'glance_next'), 'In 12 days');
    expect(_tile(tester, 'glance_avg'), '28.0 days');
    expect(_tile(tester, 'glance_regularity'), 'regular');
    expect(find.byKey(const Key('dash_cycle_history')), findsOneWidget);
    expect(find.textContaining('Average 28.0 days, shortest 28, longest 28. All within 21 to 35 days.'), findsOneWidget);
    expect(find.byKey(const Key('dash_analytics_text')), findsOneWidget);
    expect(find.textContaining('Over your 3 logged cycles'), findsOneWidget);
    expect(find.byKey(const Key('dash_analytics_empty')), findsNothing);
  });

  testWidgets('two cycles are not enough for a prediction check, and it says how many are needed', (tester) async {
    _tallScreen(tester);
    final h = _Harness(70);
    h.store.periods = [p(0), p(28), p(56)];
    await tester.pumpWidget(h.widget);
    expect(find.textContaining('Only 2 cycles to check so far. Three are needed.'), findsOneWidget);
  });

  testWidgets('symptoms, mood and the hormone sections use the same log', (tester) async {
    _tallScreen(tester);
    final h = _Harness()..fill();
    await tester.pumpWidget(h.widget);
    expect(find.byKey(const Key('trend_mood')), findsOneWidget);
    expect(find.byKey(const Key('trend_sleep')), findsOneWidget);
    expect(find.byKey(const Key('trend_symptoms')), findsOneWidget);
    expect(find.byKey(const Key('hi_curves')), findsOneWidget);
    expect(find.byKey(const Key('dash_phase_avgs')), findsOneWidget);
    expect(find.byKey(const Key('dash_phase_empty')), findsNothing);
    expect(find.text('Luteal'), findsWidgets);
    expect(find.byKey(const Key('hi_table')), findsOneWidget);
    expect(find.textContaining('pattern'), findsWidgets);
  });

  testWidgets('a persistent symptom is counted on the dashboard', (tester) async {
    _tallScreen(tester);
    final h = _Harness(130);
    h.store.periods = [p(0), p(24), p(60), p(87), p(125)];
    h.store.logs = [for (var i = 0; i < 30; i++) log(130 - i, symptoms: ['acne'], mood: 'good')];
    await tester.pumpWidget(h.widget);
    expect(_tile(tester, 'glance_regularity'), 'irregular');
    expect(find.byKey(const Key('dash_insight_count')), findsOneWidget);
    expect(find.textContaining('worth checking'), findsOneWidget);
  });

  testWidgets('latest results show what was done and lead back to the test', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.pcos = PcosSummary(date: d(98), percent: 71, level: 'high', bmi: 25.9, factors: const []);
    await tester.pumpWidget(h.widget);
    expect(find.text('High · 71% · 2 days ago'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('dash_pcos')));
    await tester.tap(find.byKey(const Key('dash_pcos')));
    await tester.pumpAndSettle();
    expect(h.app.currentTabIndex, 2);
  });

  testWidgets('links open the trends, the hormonal insights and the reminders; the report link is there', (tester) async {
    _tallScreen(tester);
    final h = _Harness()..fill();
    await tester.pumpWidget(h.widget);
    expect(find.byKey(const Key('dash_open_report')), findsOneWidget);
    for (final (key, title, back) in [('dash_open_trends', 'My trends', 'trends_back'), ('dash_open_insights', 'Hormonal insights', 'insights_back'), ('dash_open_reminders', 'Reminders', 'reminders_back')]) {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expect(find.text(title), findsWidgets, reason: key);
      await tester.tap(find.byKey(Key(back)));
      await tester.pumpAndSettle();
    }
  });
}
