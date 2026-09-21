import 'package:femora/models/cycle_engine.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/models/models.dart';
import 'package:femora/models/reminders.dart';
import 'package:femora/models/self_exam.dart';
import 'package:femora/screens/cycle_calendar_screen.dart';
import 'package:femora/screens/reminders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_reminders.dart';

final _base = DateTime(2026, 1, 1);
DateTime d(int offset) => addDays(_base, offset);
DateTime at(int offset, int h) => DateTime(2026, 1, 1 + offset, h);
PeriodEntry p(int offset) => PeriodEntry(start: d(offset));

class _Harness {
  final Recorder rec = Recorder();
  late final HealthStore store = HealthStore()..now = (() => at(100, 10));
  late final RemindersState reminders = RemindersState(service: rec, clock: () => at(100, 10));
  late final SelfExamState exam = SelfExamState(reminders: rec);
  final AppState app = AppState();

  _Harness({bool withPeriods = true}) {
    if (withPeriods) store.periods = [p(0), p(28), p(56), p(84)];
  }

  Widget widget([Widget home = const RemindersScreen()]) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: app),
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: reminders),
          ChangeNotifierProvider.value(value: exam),
        ],
        child: MaterialApp(home: home),
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('nothing is on at first, and the list says so', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget());
    expect(find.byKey(const Key('rem_none')), findsOneWidget);
    expect(find.byKey(const Key('rem_unsupported')), findsNothing);
    expect(find.byKey(const Key('rem_before_1')), findsNothing);
  });

  testWidgets('turning on the period reminder schedules it, shows the timing choices and lists what is coming', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget());
    await _tap(tester, find.byKey(const Key('rem_period')));
    expect(h.reminders.settings.period, isTrue);
    expect(h.rec.scheduled.map((r) => r.title), everyElement('Period coming up'));
    expect(h.rec.permissionAsks, 1);
    expect(find.byKey(const Key('rem_before_2')), findsOneWidget);
    expect(find.text('Period coming up'), findsWidgets); // in the Coming up list

    await _tap(tester, find.byKey(const Key('rem_before_2')));
    expect(h.reminders.settings.periodDaysBefore, 2);
    expect(h.rec.scheduled.map((r) => r.when), contains(at(110, 9))); // two days before the period expected on day 112
    expect(find.byKey(const Key('rem_none')), findsNothing);
  });

  testWidgets('with no period logged it says a date is needed', (tester) async {
    _tallScreen(tester);
    final h = _Harness(withPeriods: false);
    await tester.pumpWidget(h.widget());
    await _tap(tester, find.byKey(const Key('rem_period')));
    expect(find.byKey(const Key('rem_need_period')), findsOneWidget);
    expect(h.rec.scheduled, isEmpty); // nothing to schedule yet
  });

  testWidgets('refused permission keeps the switch off and explains', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.rec.allow = false;
    await tester.pumpWidget(h.widget());
    await _tap(tester, find.byKey(const Key('rem_daily')));
    expect(find.textContaining('Allow notifications'), findsOneWidget);
    expect(h.reminders.settings.dailyLog, isFalse);
    expect(find.byKey(const Key('rem_daily_time')), findsNothing);
  });

  testWidgets('on a phone without notifications the screen explains, and switching on says why it cannot', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.rec.supported = false;
    await tester.pumpWidget(h.widget());
    expect(find.byKey(const Key('rem_unsupported')), findsOneWidget);
    await _tap(tester, find.byKey(const Key('rem_fertile')));
    expect(find.textContaining('mobile app'), findsWidgets);
    expect(h.reminders.settings.fertile, isFalse);
  });

  testWidgets('the daily log reminder shows its time and repeats', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget());
    await _tap(tester, find.byKey(const Key('rem_daily')));
    expect(find.text('Every day at 8:00 PM'), findsOneWidget);
    expect(h.rec.scheduled.single.daily, isTrue);
    await h.reminders.update(h.reminders.settings.copyWith(dailyHour: 7, dailyMinute: 45), h.store.cycle);
    await tester.pumpAndSettle();
    expect(find.text('Every day at 7:45 AM'), findsOneWidget);
    expect(find.textContaining('Every day, 7:45 AM'), findsOneWidget); // and in the Coming up list
  });

  testWidgets('a medication reminder is added with a name and a time, and appears everywhere', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget());
    await _tap(tester, find.byKey(const Key('med_add')));
    expect(find.textContaining('only reminds you'), findsWidgets);
    await tester.enterText(find.byKey(const Key('med_name')), 'Vitamin D');
    await tester.tap(find.byKey(const Key('med_confirm')));
    await tester.pumpAndSettle();
    expect(h.reminders.settings.medications.single.name, 'Vitamin D');
    expect(find.text('Vitamin D'), findsOneWidget);
    expect(find.text('Every day at 8:00 AM'), findsOneWidget);
    expect(find.text('Medication reminder: Vitamin D'), findsOneWidget);
    expect(h.rec.scheduled.single.id, ReminderPlanner.medicationBase);
  });

  testWidgets('an empty medication name is refused, and Cancel adds nothing', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget());
    await _tap(tester, find.byKey(const Key('med_add')));
    await tester.tap(find.byKey(const Key('med_confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Type the name'), findsOneWidget);
    expect(h.reminders.settings.medications, isEmpty);
    await _tap(tester, find.byKey(const Key('med_add')));
    await tester.enterText(find.byKey(const Key('med_name')), 'Iron');
    await tester.tap(find.byKey(const Key('med_cancel')));
    await tester.pumpAndSettle();
    expect(h.reminders.settings.medications, isEmpty);
  });

  testWidgets('a medication can be switched off, back on, and deleted', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await h.reminders.addMedication('Iron', 21, 30, h.store.cycle);
    await tester.pumpWidget(h.widget());
    expect(find.text('Every day at 9:30 PM'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('med_switch_0')));
    expect(h.reminders.settings.medications.single.enabled, isFalse);
    expect(find.text('Medication reminder: Iron'), findsNothing);
    await _tap(tester, find.byKey(const Key('med_switch_0')));
    expect(find.text('Medication reminder: Iron'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('med_delete_0')));
    expect(h.reminders.settings.medications, isEmpty);
    expect(find.text('Iron'), findsNothing);
  });

  testWidgets('the monthly self-exam reminder is switched here too', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget());
    await _tap(tester, find.byKey(const Key('rem_selfexam')));
    expect(h.exam.reminderOn, isTrue);
    expect(h.rec.monthlyDays, hasLength(1));
    await _tap(tester, find.byKey(const Key('rem_selfexam')));
    expect(h.exam.reminderOn, isFalse);
    expect(h.rec.monthlyCancelled, isTrue);
  });

  testWidgets('it opens from the Cycle tab', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget(const CycleCalendarScreen()));
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('open_reminders')));
    expect(find.text('Coming up'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reminders_back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open_reminders')), findsOneWidget);
  });
}
