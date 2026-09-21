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

class _Harness {
  final HealthStore store = HealthStore()..now = () => _now;
  late final AppState app = (AppState()..now = (() => _now))..onSaveLog = store.addLog;
  Widget get widget => MultiProvider(
        providers: [ChangeNotifierProvider.value(value: app), ChangeNotifierProvider.value(value: store)],
        child: const MaterialApp(home: CycleCalendarScreen()),
      );
}

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 5200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sleep, stress, energy, mood and symptoms are saved together for today', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    expect(find.text('Not set'), findsOneWidget);

    await _tap(tester, find.text('Cramps'));
    await _tap(tester, find.byKey(const Key('mood_low')));
    h.app.setSleep(6.5);
    await tester.pumpAndSettle();
    expect(find.text('6.5 hours'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('stress_4')));
    await _tap(tester, find.byKey(const Key('energy_2')));
    await _tap(tester, find.byKey(const Key('save_log')));

    final saved = h.store.logOn(_now)!;
    expect(saved.symptoms, ['cramps']);
    expect(saved.mood, 'low');
    expect(saved.sleepHours, 6.5);
    expect(saved.stress, 4);
    expect(saved.energy, 2);
  });

  testWidgets('opening the tab shows what was already saved today, and saving again replaces it', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.logs = [SymptomLog(date: _now, symptoms: const ['acne'], mood: 'good', notes: 'slept badly', sleepHours: 5, stress: 3, energy: 2)];
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    expect(h.app.mood, 'good');
    expect(h.app.sleepHours, 5);
    expect(h.app.stress, 3);
    expect(h.app.energy, 2);
    expect(find.text('5.0 hours'), findsOneWidget);
    expect(find.text('slept badly'), findsOneWidget);
    expect(h.app.symptoms.firstWhere((s) => s.id == 'acne').isSelected, isTrue);

    await _tap(tester, find.byKey(const Key('stress_5')));
    await _tap(tester, find.byKey(const Key('save_log')));
    expect(h.store.logs, hasLength(1));
    expect(h.store.logs.single.stress, 5);
    expect(h.store.logs.single.notes, 'slept badly');
  });

  testWidgets('tapping the chosen level again, or the cross beside sleep, clears it', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('energy_3')));
    expect(h.app.energy, 3);
    await _tap(tester, find.byKey(const Key('energy_3')));
    expect(h.app.energy, isNull);
    h.app.setSleep(8);
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('sleep_clear')));
    expect(h.app.sleepHours, isNull);
    expect(find.text('Not set'), findsOneWidget);
  });

  testWidgets('yesterday can be logged without touching today', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.logs = [SymptomLog(date: _now, symptoms: const [], mood: 'great', sleepHours: 8)];
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();

    await _tap(tester, find.byKey(const Key('log_day_yesterday')));
    expect(h.app.loggingToday, isFalse);
    expect(h.app.mood, isNull); // yesterday had nothing saved: the form is empty
    expect(find.textContaining('Logging for 19 Jun'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('mood_bad')));
    h.app.setSleep(4.5);
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('save_log')));

    expect(h.store.logs, hasLength(2));
    expect(h.store.logOn(ago(1))!.mood, 'bad');
    expect(h.store.logOn(ago(1))!.sleepHours, 4.5);
    expect(h.store.logOn(_now)!.mood, 'great'); // today untouched
    expect(find.textContaining('Save log for 19 Jun'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('log_day_today')));
    expect(h.app.mood, 'great');
    expect(h.app.sleepHours, 8);
  });

  testWidgets('a different account starts with an empty form', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await h.store.useAccount('anna');
    await h.store.addLog(SymptomLog(date: _now, symptoms: const [], mood: 'good', sleepHours: 7));
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    expect(h.app.sleepHours, 7);
    await h.store.useAccount('sara');
    await tester.pumpAndSettle();
    expect(h.app.sleepHours, isNull);
    expect(h.app.mood, isNull);
  });

  testWidgets('See my trends opens the trends screen', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('open_trends')));
    expect(find.text('My trends'), findsOneWidget);
    await tester.tap(find.byKey(const Key('trends_back')));
    await tester.pumpAndSettle();
    expect(find.text('Save Today\'s Log'), findsOneWidget);
  });
}
