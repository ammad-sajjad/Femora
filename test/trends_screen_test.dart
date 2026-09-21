import 'package:femora/models/cycle_engine.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/models/models.dart';
import 'package:femora/screens/trends_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 6, 20, 10);
DateTime ago(int days) => addDays(DateTime(2026, 6, 20), -days);

class _Harness {
  final HealthStore store = HealthStore()..now = () => _now;
  final AppState app = AppState()..now = () => _now;
  Widget get widget => MultiProvider(
        providers: [ChangeNotifierProvider.value(value: app), ChangeNotifierProvider.value(value: store)],
        child: const MaterialApp(home: TrendsScreen()),
      );
}

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 6000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

String _tile(WidgetTester tester, String key) {
  final texts = find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)).evaluate().map((e) => (e.widget as Text).data!).toList();
  return texts.last;
}

List<SymptomLog> _tenDays() => [
      for (var i = 0; i < 10; i++)
        SymptomLog(
          date: ago(i),
          symptoms: i.isEven ? const ['cramps', 'fatigue'] : const ['cramps'],
          mood: const ['good', 'okay', 'low', 'good', 'great', 'okay', 'low', 'good', 'okay', 'good'][i],
          sleepHours: i < 5 ? 5.5 : 8,
          stress: i < 3 ? 5 : 2,
          energy: 3,
        ),
    ];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('with nothing logged it explains, and Log today goes to the Cycle tab', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget);
    expect(find.byKey(const Key('trend_empty')), findsOneWidget);
    expect(find.byKey(const Key('trend_mood')), findsNothing);
    await tester.tap(find.byKey(const Key('trend_log_today')));
    await tester.pumpAndSettle();
    expect(h.app.currentTabIndex, 1);
  });

  testWidgets('with logs it shows the numbers, the charts and plain-language notes', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.logs = _tenDays();
    await tester.pumpWidget(h.widget);
    expect(_tile(tester, 'tile_logged'), '10 of 30');
    expect(_tile(tester, 'tile_sleep'), '6.8 h'); // (5 x 5.5 + 5 x 8) / 10 = 6.75
    expect(_tile(tester, 'tile_energy'), '3.0 / 5');
    expect(_tile(tester, 'tile_stress'), '2.9 / 5'); // (3 x 5 + 7 x 2) / 10 = 2.9
    for (final k in ['trend_mood', 'trend_sleep', 'trend_stress', 'trend_symptoms', 'trend_insights']) {
      expect(find.byKey(Key(k)), findsOneWidget, reason: k);
    }
    expect(find.text('cramps'), findsOneWidget); // most frequent symptom listed
    expect(find.text('fatigue'), findsOneWidget);
    expect(find.textContaining('Stress was high'), findsOneWidget);
    expect(find.textContaining('not a diagnosis'), findsOneWidget);
  });

  testWidgets('the period can be changed to 7 or 90 days', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.logs = [..._tenDays(), SymptomLog(date: ago(50), symptoms: const ['acne'], mood: 'bad')];
    await tester.pumpWidget(h.widget);
    expect(_tile(tester, 'tile_logged'), '10 of 30');
    await tester.tap(find.byKey(const Key('trend_range_7')));
    await tester.pumpAndSettle();
    expect(_tile(tester, 'tile_logged'), '7 of 7');
    await tester.tap(find.byKey(const Key('trend_range_90')));
    await tester.pumpAndSettle();
    expect(_tile(tester, 'tile_logged'), '11 of 90');
  });

  testWidgets('a chart with no data for that measure says so instead of drawing an empty plot', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.logs = [for (var i = 0; i < 6; i++) SymptomLog(date: ago(i), symptoms: const ['acne'], mood: 'good')];
    await tester.pumpWidget(h.widget);
    expect(find.text('No sleep logged in this period.'), findsOneWidget);
    expect(find.text('No stress or energy logged in this period.'), findsOneWidget);
    expect(find.byKey(const Key('trend_mood')), findsOneWidget);
    expect(_tile(tester, 'tile_sleep'), '-');
  });

  testWidgets('few logged days ask for more instead of drawing conclusions', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.logs = [SymptomLog(date: _now, symptoms: const [], mood: 'low', sleepHours: 4)];
    await tester.pumpWidget(h.widget);
    expect(find.textContaining('Log at least 5 days'), findsOneWidget);
  });
}
