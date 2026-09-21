import 'package:femora/models/cycle_engine.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/models/models.dart';
import 'package:femora/screens/cycle_calendar_screen.dart';
import 'package:femora/screens/hormone_insights_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _base = DateTime(2026, 1, 1);
DateTime d(int offset) => addDays(_base, offset);
PeriodEntry p(int offset) => PeriodEntry(start: d(offset));
SymptomLog log(int offset, {List<String> symptoms = const [], String? mood, double? sleep, int? energy}) =>
    SymptomLog(date: d(offset), symptoms: symptoms, mood: mood, sleepHours: sleep, energy: energy);

/// 28-day cycles: period days 0-4 (cramps), follicular 5-13 (good), luteal 17-27 (bloating, tenderness, low mood).
List<SymptomLog> typicalLogs(int cycles, int lastDay) => [
      for (var c = 0; c < cycles; c++) ...[
        for (var i = 0; i < 5; i++) log(c * 28 + i, symptoms: ['cramps'], mood: 'okay', energy: 3),
        for (var i = 5; i < 14; i++) log(c * 28 + i, mood: 'good', energy: 4, sleep: 8),
        for (var i = 17; i < 28; i++) log(c * 28 + i, symptoms: ['bloating', 'tender'], mood: 'low', energy: 2, sleep: 6.5),
      ]
    ].where((l) => !l.date.isAfter(d(lastDay))).toList();

class _Harness {
  final int today;
  late final HealthStore store = HealthStore()..now = (() => d(today).add(const Duration(hours: 10)));
  late final AppState app = AppState()..now = (() => d(today).add(const Duration(hours: 10)));
  _Harness([this.today = 100]);
  Widget widget([Widget home = const HormoneInsightsScreen()]) => MultiProvider(
        providers: [ChangeNotifierProvider.value(value: app), ChangeNotifierProvider.value(value: store)],
        child: MaterialApp(home: home),
      );
}

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 6400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

String _cell(WidgetTester tester, String key) => ((tester.widget(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)).first)) as Text).data!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('with no periods it invites her to log one, and still shows the typical hormone pattern', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget());
    expect(find.byKey(const Key('hi_empty')), findsOneWidget);
    expect(find.byKey(const Key('hi_curves')), findsOneWidget);
    expect(find.textContaining('textbook shapes, not your measured levels'), findsOneWidget);
    expect(find.byKey(const Key('hi_table')), findsNothing);
    expect(find.byKey(const Key('hi_patterns')), findsNothing);
    await tester.tap(find.byKey(const Key('hi_log_period')));
    await tester.pumpAndSettle();
    expect(h.app.currentTabIndex, 1);
  });

  testWidgets('with logged cycles it shows the phase, the table, the patterns and tips', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.periods = [p(0), p(28), p(56), p(84)];
    h.store.logs = typicalLogs(4, 100);
    await tester.pumpWidget(h.widget());
    expect(((tester.widget(find.byKey(const Key('hi_phase_title')))) as Text).data, 'Ovulation window');
    expect(find.textContaining('Estrogen peaks'), findsOneWidget);
    expect(_cell(tester, 'hi_cell_bloating_luteal'), '100%');
    expect(_cell(tester, 'hi_cell_cramps_menstrual'), '100%');
    expect(_cell(tester, 'hi_cell_bloating_ovulation'), '·'); // no logs in the ovulation phase: left blank
    expect(_cell(tester, 'hi_cell_bloating_follicular'), '0%');
    expect(find.byKey(const Key('note_pms')), findsOneWidget);
    expect(find.byKey(const Key('note_cramps')), findsOneWidget);
    expect(find.byKey(const Key('note_energy')), findsOneWidget);
    expect(find.byKey(const Key('hi_flags')), findsNothing);
    expect(find.byKey(const Key('hi_tips')), findsOneWidget);
    expect(find.textContaining('not a diagnosis'), findsOneWidget);
  });

  testWidgets('with too few logs it says how much is needed instead of inventing a pattern', (tester) async {
    _tallScreen(tester);
    final h = _Harness(40);
    h.store.periods = [p(0), p(28)];
    h.store.logs = [log(36, symptoms: ['bloating'], mood: 'low')];
    await tester.pumpWidget(h.widget());
    expect(find.byKey(const Key('hi_need_data')), findsOneWidget);
    expect(find.textContaining('at least two cycles'), findsOneWidget);
    expect(find.byKey(const Key('note_pms')), findsNothing);
  });

  testWidgets('a persistent symptom with irregular cycles is flagged and leads to the PCOS check', (tester) async {
    _tallScreen(tester);
    final h = _Harness(130);
    h.store.periods = [p(0), p(24), p(60), p(87), p(125)]; // 24, 36, 27, 38
    h.store.logs = [for (var i = 0; i < 30; i++) log(130 - i, symptoms: ['acne'], mood: 'good')];
    await tester.pumpWidget(h.widget());
    expect(find.byKey(const Key('hi_flags')), findsOneWidget);
    expect(find.text('Worth checking'), findsOneWidget);
    expect(find.byKey(const Key('note_acne')), findsOneWidget);
    expect(find.byKey(const Key('note_pcos_pattern')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('hi_pcos')));
    await tester.tap(find.byKey(const Key('hi_pcos')));
    await tester.pumpAndSettle();
    expect(h.app.currentTabIndex, 2);
  });

  testWidgets('the hormone chart names the cycle length and the day she is on', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.periods = [p(0), p(28), p(56), p(84)];
    await tester.pumpWidget(h.widget());
    expect(find.textContaining('a cycle of 28 days'), findsOneWidget);
    expect(find.textContaining('dashed line marks today (day 17)'), findsOneWidget);
  });

  testWidgets('it opens from the Cycle tab', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget(const CycleCalendarScreen()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('open_insights')));
    await tester.tap(find.byKey(const Key('open_insights')));
    await tester.pumpAndSettle();
    expect(find.text('Hormonal insights'), findsWidgets);
    expect(find.byKey(const Key('hi_curves')), findsOneWidget);
    await tester.tap(find.byKey(const Key('insights_back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open_insights')), findsOneWidget);
  });

  testWidgets('the new hormone-related symptoms can be logged', (tester) async {
    final app = AppState();
    expect(app.symptoms.map((s) => s.name.toLowerCase()), containsAll(['hair loss', 'excess hair']));
  });
}
