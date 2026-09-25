import 'package:femora/models/cycle_engine.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/models/models.dart';
import 'package:femora/models/reminders.dart';
import 'package:femora/models/self_exam.dart';
import 'package:femora/screens/home_dashboard_screen.dart';
import 'package:femora/services/reminder_service.dart';
import 'package:femora/widgets/body_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoReminders extends ReminderService {
  @override
  bool get isSupported => false;
}

final _now = DateTime(2026, 9, 20, 9, 30);

Widget _home(HealthStore store, AppState app, {SelfExamState? exam}) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: app),
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: exam ?? SelfExamState(reminders: _NoReminders())),
      ],
      child: const MaterialApp(home: HomeDashboardScreen()),
    );

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

HealthStore _storeWith({bool pcos = false, bool scan = false, bool risk = false, bool cycle = false, List<SymptomLog> logs = const []}) {
  final s = HealthStore()
    ..now = (() => _now)
    ..profile = HealthProfile(name: 'Ayesha Khan', onboarded: true);
  if (pcos) s.pcos = PcosSummary(date: _now.subtract(const Duration(days: 2)), percent: 71, level: 'high', bmi: 25.9, factors: const ['Acne']);
  if (scan) {
    s.scan = ScanSummary(date: _now, prediction: 'benign', title: 'Likely Benign', confidence: 0.88, probabilities: const {'normal': 0.05, 'benign': 0.88, 'malignant': 0.07}, modelAccuracy: 0.718);
  }
  if (risk) {
    s.breastRisk = BreastRiskSummary(date: _now, probability: 0.0062, average: 0.0042, relativeRisk: 1.66, level: 'medium', ageGroup: '50-54', factors: const [], redFlags: const []);
  }
  if (cycle) s.periods = [PeriodEntry(start: _now.subtract(const Duration(days: 8)), end: _now.subtract(const Duration(days: 4)))];
  s.logs = logs;
  return s;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a new user sees their own name and an empty snapshot, not made-up data', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_home(_storeWith(), AppState()..now = () => _now));
    expect(find.text('Good morning, Ayesha'), findsOneWidget);
    expect(find.text('No checks yet. Tap a row to start.'), findsOneWidget);
    expect(find.text('Not checked yet'), findsNWidgets(2));
    expect(find.text('Not scanned yet'), findsOneWidget);
    expect(find.textContaining('Cycle Day 12'), findsNothing);
    expect(find.textContaining('Ayesha'), findsOneWidget);
  });

  testWidgets('results the user has produced show up on Home', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_home(_storeWith(pcos: true, scan: true, risk: true), AppState()..now = () => _now));
    expect(find.text('High · 71%'), findsOneWidget);
    expect(find.text('2 days ago'), findsOneWidget);
    expect(find.text('Likely Benign · 88%'), findsOneWidget);
    expect(find.text('Medium · 1.66× average'), findsOneWidget);
    expect(find.text('3 of 3 checks done'), findsOneWidget);
  });

  testWidgets('tapping a row opens the matching tab', (tester) async {
    _tallScreen(tester);
    final app = AppState()..now = () => _now;
    await tester.pumpWidget(_home(_storeWith(pcos: true), app));
    await tester.tap(find.byKey(const Key('home_pcos')));
    expect(app.currentTabIndex, 2);
    await tester.tap(find.byKey(const Key('home_scan')));
    expect(app.currentTabIndex, 3);
    await tester.tap(find.byKey(const Key('home_next_step')));
    expect(app.currentTabIndex, 4);
  });

  testWidgets('with no periods logged Home invites her to start tracking, and tapping opens the Cycle tab', (tester) async {
    _tallScreen(tester);
    final app = AppState()..now = () => _now;
    await tester.pumpWidget(_home(_storeWith(), app));
    expect(find.byKey(const Key('home_cycle_empty')), findsOneWidget);
    expect(find.textContaining('Cycle day'), findsNothing); // nothing made up
    await tester.tap(find.byKey(const Key('home_cycle')));
    expect(app.currentTabIndex, 1);
  });

  testWidgets('with periods logged Home shows the real cycle day and the next period', (tester) async {
    _tallScreen(tester);
    final store = _storeWith();
    store.periods = [for (final ago in [92, 64, 36, 8]) PeriodEntry(start: _now.subtract(Duration(days: ago)), end: _now.subtract(Duration(days: ago - 4)))];
    await tester.pumpWidget(_home(store, AppState()..now = () => _now));
    expect(find.text('Cycle day 9'), findsOneWidget);
    expect(find.text('Next period 10 Oct'), findsOneWidget);
    expect(find.textContaining('Fertile window'), findsOneWidget);
    expect(find.text('DAYS TO GO'), findsOneWidget);
    // the body clock and the typical hormone waves draw in, then settle
    expect(find.byKey(const Key('home_body_clock')), findsOneWidget);
    expect(find.byKey(const Key('home_hormone_waves')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Typical pattern, not measured'), findsOneWidget);
    expect(find.text('Progesterone'), findsOneWidget);
  });

  test('the body clock places the phases in order and covers the whole cycle', () {
    final s = phaseSegments(28, 5);
    expect(s.map((x) => x.$1), [CyclePhase.menstrual, CyclePhase.follicular, CyclePhase.ovulation, CyclePhase.luteal]);
    expect(s.first.$2, 0);
    expect(s.last.$3, 28);
    for (var i = 1; i < s.length; i++) {
      expect(s[i].$2, s[i - 1].$3); // no gaps or overlaps
    }
    expect(s[2].$2, 14); // ovulation on day index 15 of a 28-day cycle (13-day luteal phase), window from the day before
    // a very long period can't push the follicular phase past ovulation
    final long = phaseSegments(21, 12);
    expect(long[1].$3 >= long[1].$2, isTrue);
  });

  testWidgets('a late period is shown as late, with no predictions', (tester) async {
    _tallScreen(tester);
    final store = _storeWith();
    store.periods = [for (final ago in [100, 72, 44]) PeriodEntry(start: _now.subtract(Duration(days: ago)), end: _now.subtract(Duration(days: ago - 4)))];
    await tester.pumpWidget(_home(store, AppState()..now = () => _now));
    expect(find.text('DAYS LATE'), findsOneWidget);
    expect(find.textContaining('Fertile window'), findsNothing);
    expect(find.textContaining('expected'), findsWidgets);
  });

  testWidgets('the trends card shows how much was logged this week and opens the charts', (tester) async {
    _tallScreen(tester);
    final store = _storeWith(logs: [for (var i = 0; i < 3; i++) SymptomLog(date: _now.subtract(Duration(days: i)), symptoms: const [], mood: 'good')]);
    await tester.pumpWidget(_home(store, AppState()..now = () => _now));
    expect(find.textContaining('3 of the last 7 days logged'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('home_trends')));
    await tester.tap(find.byKey(const Key('home_trends')));
    await tester.pumpAndSettle();
    expect(find.text('My trends'), findsOneWidget);
  });

  testWidgets('the dashboard card opens the health dashboard', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: AppState()..now = (() => _now)),
        ChangeNotifierProvider.value(value: _storeWith(cycle: true)),
        ChangeNotifierProvider.value(value: SelfExamState(reminders: _NoReminders())),
        ChangeNotifierProvider.value(value: RemindersState(service: _NoReminders())),
      ],
      child: const MaterialApp(home: HomeDashboardScreen()),
    ));
    await tester.ensureVisible(find.byKey(const Key('home_dashboard')));
    await tester.tap(find.byKey(const Key('home_dashboard')));
    await tester.pumpAndSettle();
    expect(find.text('Health dashboard'), findsWidgets);
    expect(find.byKey(const Key('dash_glance')), findsOneWidget);
  });

  testWidgets('greeting follows the time of day and an unnamed user is not given a name', (tester) async {
    _tallScreen(tester);
    final store = HealthStore()..profile = HealthProfile(onboarded: true);
    await tester.pumpWidget(_home(store, AppState()..now = () => DateTime(2026, 9, 20, 19, 0)));
    expect(find.text('Good evening'), findsOneWidget);
  });

  test('the next step puts a doctor visit first, then logging, then the self-exam', () {
    final today = [SymptomLog(date: _now, symptoms: const [], mood: null, notes: '')];
    final exam = _now.subtract(const Duration(days: 5));

    final flagged = _storeWith(risk: true, logs: today);
    flagged.breastRisk = BreastRiskSummary(date: _now, probability: 0.006, average: 0.004, relativeRisk: 1.5, level: 'medium', ageGroup: '50-54', factors: const [], redFlags: const ['Breast Lump (urgent)']);
    expect(HomeDashboardScreen.nextStep(flagged, exam, _now), contains('see a doctor'));

    expect(HomeDashboardScreen.nextStep(_storeWith(pcos: true, logs: today), exam, _now), contains('gynaecologist'));
    expect(HomeDashboardScreen.nextStep(_storeWith(scan: true), exam, _now), contains('Log how you feel'));
    expect(HomeDashboardScreen.nextStep(_storeWith(scan: true, logs: today), null, _now), contains('self-exam'));
    expect(HomeDashboardScreen.nextStep(_storeWith(scan: true, logs: today), exam, _now), contains('first day of your last period'));
    expect(HomeDashboardScreen.nextStep(_storeWith(logs: today, cycle: true), exam, _now), contains('first check'));
    expect(HomeDashboardScreen.nextStep(_storeWith(scan: true, logs: today, cycle: true), exam, _now), contains('all caught up'));

    // a period more than two weeks late outranks a high PCOS result
    final late = _storeWith(pcos: true, logs: today);
    late.periods = [for (final ago in [100, 72, 44]) PeriodEntry(start: _now.subtract(Duration(days: ago)), end: _now.subtract(Duration(days: ago - 4)))];
    expect(HomeDashboardScreen.nextStep(late, exam, _now), contains('later than expected'));

    final suspicious = _storeWith(logs: today);
    suspicious.scan = ScanSummary(date: _now, prediction: 'malignant', title: 'Suspicious Finding', confidence: 0.9, probabilities: const {'normal': 0.0, 'benign': 0.1, 'malignant': 0.9}, modelAccuracy: 0.718);
    expect(HomeDashboardScreen.nextStep(suspicious, exam, _now), contains('breast specialist'));
  });

  test('relative dates read naturally', () {
    expect(HomeDashboardScreen.ago(_now, _now), 'today');
    expect(HomeDashboardScreen.ago(_now.subtract(const Duration(days: 1)), _now), 'yesterday');
    expect(HomeDashboardScreen.ago(_now.subtract(const Duration(days: 12)), _now), '12 days ago');
  });
}
