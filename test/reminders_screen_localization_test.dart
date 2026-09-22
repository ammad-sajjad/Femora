import 'package:femora/models/cycle_engine.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/models/reminders.dart';
import 'package:femora/models/self_exam.dart';
import 'package:femora/screens/reminders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_reminders.dart';

final _base = DateTime(2026, 1, 1);
DateTime _d(int offset) => addDays(_base, offset);
DateTime _at(int offset, int h) => DateTime(2026, 1, 1 + offset, h);
PeriodEntry _p(int offset) => PeriodEntry(start: _d(offset));

class _Harness {
  final Recorder rec = Recorder();
  late final HealthStore store = HealthStore()
    ..now = (() => _at(100, 10))
    ..profile = HealthProfile(language: 'ur', onboarded: true)
    ..periods = [_p(0), _p(28), _p(56), _p(84)];
  late final RemindersState reminders = RemindersState(service: rec, clock: () => _at(100, 10));
  late final SelfExamState exam = SelfExamState(reminders: rec);

  Widget get widget => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: reminders),
          ChangeNotifierProvider.value(value: exam),
        ],
        child: const MaterialApp(home: RemindersScreen()),
      );
}

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 4200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('titles, switches and section headers are in Urdu', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_Harness().widget);
    expect(find.text('یاد دہانیاں'), findsOneWidget);
    expect(find.text('پیریڈ آنے والا ہے'), findsOneWidget);
    expect(find.text('زرخیز دورانیہ اور بیضہ دانی'), findsOneWidget);
    expect(find.text('میرا دن درج کریں'), findsOneWidget);
    expect(find.text('ماہانہ بریسٹ سیلف ایگزام'), findsOneWidget);
    expect(find.text('دوائی'), findsOneWidget);
    expect(find.text('آنے والی'), findsOneWidget);
    expect(find.text('کوئی یاد دہانی سیٹ نہیں ہے۔ اوپر سے کوئی ایک آن کریں۔'), findsOneWidget);
  });

  testWidgets('period reminder options and the daily time button read in Urdu', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget);
    await tester.tap(find.byKey(const Key('rem_period')));
    await tester.pumpAndSettle();
    expect(find.text('اسی دن'), findsOneWidget);
    expect(find.text('1 دن پہلے'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('rem_daily')));
    await tester.tap(find.byKey(const Key('rem_daily')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('rem_daily_time')));
    expect(find.textContaining('روزانہ'), findsWidgets);
  });

  testWidgets('the medication dialog is in Urdu', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_Harness().widget);
    await tester.ensureVisible(find.byKey(const Key('med_add')));
    await tester.tap(find.byKey(const Key('med_add')));
    await tester.pumpAndSettle();
    expect(find.text('دوائی کی یاد دہانی'), findsOneWidget);
    expect(find.text('دوائی کا نام'), findsOneWidget);
    expect(find.text('منسوخ کریں'), findsOneWidget);
    expect(find.text('شامل کریں'), findsOneWidget);
    await tester.tap(find.text('منسوخ کریں'));
    await tester.pumpAndSettle();
  });

  testWidgets('the upcoming list shows an Urdu time for a daily reminder', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget);
    await tester.ensureVisible(find.byKey(const Key('rem_daily')));
    await tester.tap(find.byKey(const Key('rem_daily')));
    await tester.pumpAndSettle();
    final upcoming = h.reminders.upcoming(h.store.cycle);
    expect(upcoming.any((r) => r.repeatsDaily), isTrue);
    await tester.ensureVisible(find.byKey(const Key('rem_upcoming')));
    expect(find.text('کوئی یاد دہانی سیٹ نہیں ہے۔ اوپر سے کوئی ایک آن کریں۔'), findsNothing);
    expect(find.textContaining('روزانہ،'), findsOneWidget);
    expect(find.textContaining('بجے'), findsWidgets); // Urdu clock suffix
  });
}
