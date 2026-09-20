import 'package:femora/models/health_store.dart';
import 'package:femora/models/models.dart';
import 'package:femora/models/self_exam.dart';
import 'package:femora/screens/home_dashboard_screen.dart';
import 'package:femora/services/reminder_service.dart';
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

HealthStore _storeWith({bool pcos = false, bool scan = false, bool risk = false, List<SymptomLog> logs = const []}) {
  final s = HealthStore()..profile = HealthProfile(name: 'Ayesha Khan', onboarded: true);
  if (pcos) s.pcos = PcosSummary(date: _now.subtract(const Duration(days: 2)), percent: 71, level: 'high', bmi: 25.9, factors: const ['Acne']);
  if (scan) {
    s.scan = ScanSummary(date: _now, prediction: 'benign', title: 'Likely Benign', confidence: 0.88, probabilities: const {'normal': 0.05, 'benign': 0.88, 'malignant': 0.07}, modelAccuracy: 0.718);
  }
  if (risk) {
    s.breastRisk = BreastRiskSummary(date: _now, probability: 0.0062, average: 0.0042, relativeRisk: 1.66, level: 'medium', ageGroup: '50-54', factors: const [], redFlags: const []);
  }
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
    expect(HomeDashboardScreen.nextStep(_storeWith(logs: today), exam, _now), contains('first check'));
    expect(HomeDashboardScreen.nextStep(_storeWith(scan: true, logs: today), exam, _now), contains('all caught up'));

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
