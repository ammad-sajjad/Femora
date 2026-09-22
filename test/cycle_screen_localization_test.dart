import 'package:femora/models/cycle_engine.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/models/models.dart';
import 'package:femora/screens/cycle_calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 6, 20, 10);
DateTime _ago(int days) => addDays(DateTime(2026, 6, 20), -days);
PeriodEntry _p(int daysAgo, {int? lengthDays}) => PeriodEntry(start: _ago(daysAgo), end: lengthDays == null ? null : addDays(_ago(daysAgo), lengthDays - 1));

class _Harness {
  final HealthStore store = HealthStore()..now = () => _now;
  final AppState app = AppState()..now = () => _now;
  _Harness() {
    store.profile = HealthProfile(language: 'ur', onboarded: true);
  }
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the title, buttons and empty cycle card are in Urdu', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget);
    expect(find.text('میرا سائیکل'), findsOneWidget);
    expect(find.text('میرے رجحانات دیکھیں'), findsOneWidget);
    expect(find.text('ہارمونل بصیرت'), findsOneWidget);
    expect(find.text('یاد دہانیاں'), findsOneWidget);
  });

  testWidgets('the log form (day chooser, header, symptoms, mood, sleep, notes, save button) is in Urdu', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.periods = [_p(120, lengthDays: 5), _p(92, lengthDays: 5), _p(64, lengthDays: 5), _p(36, lengthDays: 5), _p(8, lengthDays: 5)];
    await tester.pumpWidget(h.widget);

    expect(find.text('آج'), findsWidgets); // the "Today" chip, and possibly the header
    expect(find.text('کل'), findsOneWidget); // "Yesterday" chip
    expect(find.textContaining('آج • سائیکل کا دن'), findsOneWidget);
    expect(find.text('علامات درج کریں'), findsOneWidget);
    expect(find.text('درد'), findsOneWidget); // Cramps
    expect(find.text('بالوں کا گرنا'), findsOneWidget); // Hair loss
    expect(find.text('موڈ'), findsOneWidget);
    expect(find.text('اچھا'), findsWidgets); // "Good" mood label, and possibly the Energy caption
    expect(find.text('نیند'), findsOneWidget);
    expect(find.text('سیٹ نہیں'), findsOneWidget); // "Not set"
    expect(find.text('تناؤ'), findsOneWidget);
    expect(find.text('پرسکون'), findsOneWidget); // Calm
    expect(find.text('توانائی'), findsOneWidget);
    expect(find.text('بہت اچھا'), findsWidgets); // Great mood / Great energy caption
    expect(find.text('نوٹس'), findsOneWidget);
    expect(find.text('آج کا لاگ محفوظ کریں'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('save_log')));
    await tester.tap(find.byKey(const Key('save_log')));
    await tester.pump();
    expect(find.text('آج کا ہیلتھ لاگ کامیابی سے محفوظ ہو گیا!'), findsOneWidget);
  });

  testWidgets('picking Another day shows the Urdu date and Urdu save label', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget);
    await tester.ensureVisible(find.byKey(const Key('log_day_yesterday')));
    await tester.tap(find.byKey(const Key('log_day_yesterday')));
    await tester.pump();
    expect(find.textContaining('اندراج برائے'), findsOneWidget);
    expect(find.textContaining('جون'), findsWidgets); // Urdu month name in the date (chip and header)
    expect(find.textContaining('کا لاگ محفوظ کریں'), findsOneWidget);
  });

  testWidgets('the cycle-phase tip shown on the log card is in Urdu', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.periods = [_p(120, lengthDays: 5), _p(92, lengthDays: 5), _p(64, lengthDays: 5), _p(36, lengthDays: 5), _p(8, lengthDays: 5)];
    await tester.pumpWidget(h.widget);
    final engine = CycleEngine(h.store.periods, _now);
    expect(engine.phase, isNotNull);
    expect(find.text(engine.phase!.tipIn('ur')), findsOneWidget);
  });
}
