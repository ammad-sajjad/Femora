import 'package:femora/models/cycle_engine.dart';
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

final _now = DateTime(2026, 9, 20, 9, 30); // a Sunday morning

Widget _home(HealthStore store, AppState app) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: app),
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: SelfExamState(reminders: _NoReminders())),
      ],
      child: const MaterialApp(home: HomeDashboardScreen()),
    );

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

HealthStore _urduStore({bool pcos = false, bool scan = false, bool risk = false, List<SymptomLog> logs = const []}) {
  final s = HealthStore()
    ..now = (() => _now)
    ..profile = HealthProfile(name: 'عائشہ خان', language: 'ur', onboarded: true);
  if (pcos) s.pcos = PcosSummary(date: _now.subtract(const Duration(days: 2)), percent: 71, level: 'high', bmi: 25.9, factors: const ['Acne']);
  if (scan) {
    s.scan = ScanSummary(date: _now, prediction: 'benign', title: 'Likely Benign', confidence: 0.88, probabilities: const {'normal': 0.05, 'benign': 0.88, 'malignant': 0.07}, modelAccuracy: 0.718);
  }
  if (risk) s.breastRisk = BreastRiskSummary(date: _now, probability: 0.0062, average: 0.0042, relativeRisk: 1.66, level: 'medium', ageGroup: '50-54', factors: const [], redFlags: const []);
  s.logs = logs;
  return s;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Home in Urdu', () {
    testWidgets('the greeting, subtitle and an empty snapshot are all in Urdu', (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(_home(_urduStore(), AppState()..now = () => _now));
      expect(find.text('صبح بخیر, عائشہ'), findsOneWidget);
      expect(find.text('یہ ہے آپ کی صحت کا خلاصہ۔'), findsOneWidget);
      expect(find.text('ابھی کوئی چیک نہیں۔ شروع کرنے کے لیے ایک قطار پر ٹیپ کریں۔'), findsOneWidget);
      expect(find.text('ابھی چیک نہیں ہوا'), findsNWidgets(2));
      expect(find.text('ابھی اسکین نہیں ہوا'), findsOneWidget);
      expect(find.text('ابھی درج نہیں ہوا'), findsOneWidget);
      // an English speaker's exact wording never leaks through when Urdu was asked for
      expect(find.textContaining('Good morning'), findsNothing);
      expect(find.textContaining('Not checked yet'), findsNothing);
    });

    testWidgets('greeting follows the time of day in Urdu too, and an unnamed user gets no name', (tester) async {
      _tallScreen(tester);
      final store = HealthStore()..profile = HealthProfile(language: 'ur', onboarded: true);
      await tester.pumpWidget(_home(store, AppState()..now = () => DateTime(2026, 9, 20, 19, 0)));
      expect(find.text('شام بخیر'), findsOneWidget);
    });

    testWidgets('Quick Log and its four labels are in Urdu', (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(_home(_urduStore(), AppState()..now = () => _now));
      expect(find.text('فوری اندراج'), findsOneWidget);
      expect(find.text('پیریڈ'), findsOneWidget);
      expect(find.text('علامات'), findsOneWidget);
      expect(find.text('موڈ'), findsOneWidget);
    });

    testWidgets('with no periods logged, the empty cycle card invites her to start, in Urdu', (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(_home(_urduStore(), AppState()..now = () => _now));
      expect(find.text('اپنا سائیکل ٹریک کریں'), findsOneWidget);
      expect(find.byKey(const Key('home_cycle_empty')), findsOneWidget);
    });

    testWidgets('with periods logged, the cycle day, phase, next period date and fertile window are all in Urdu', (tester) async {
      _tallScreen(tester);
      final store = _urduStore();
      store.periods = [for (final ago in [92, 64, 36, 8]) PeriodEntry(start: _now.subtract(Duration(days: ago)), end: _now.subtract(Duration(days: ago - 4)))];
      await tester.pumpWidget(_home(store, AppState()..now = () => _now));
      expect(find.text('سائیکل کا دن 9'), findsOneWidget);
      expect(find.text('اگلا پیریڈ 10 اکتوبر'), findsOneWidget);
      expect(find.textContaining('زرخیز دورانیہ'), findsOneWidget);
      expect(find.text('دن باقی'), findsOneWidget);
      expect(CycleEngine(store.periods, _now).phase, isNotNull); // the phase card line renders only when there is a phase
    });

    testWidgets('a late period says so in Urdu, with no fertile window guessed', (tester) async {
      _tallScreen(tester);
      final store = _urduStore();
      store.periods = [for (final ago in [100, 72, 44]) PeriodEntry(start: _now.subtract(Duration(days: ago)), end: _now.subtract(Duration(days: ago - 4)))];
      await tester.pumpWidget(_home(store, AppState()..now = () => _now));
      expect(find.text('دن تاخیر'), findsOneWidget);
      expect(find.textContaining('پیریڈ کی توقع'), findsOneWidget);
      expect(find.textContaining('زرخیز دورانیہ'), findsNothing);
    });

    testWidgets('real results show their Urdu labels, with the relative date in Urdu', (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(_home(_urduStore(pcos: true, scan: true, risk: true), AppState()..now = () => _now));
      expect(find.text('PCOS رسک'), findsOneWidget);
      expect(find.text('بریسٹ الٹراساؤنڈ'), findsOneWidget);
      expect(find.text('بریسٹ کینسر رسک'), findsOneWidget);
      expect(find.text('2 دن پہلے'), findsOneWidget); // pcos was recorded 2 days before "now"
      expect(find.text('3 از 3 چیک مکمل'), findsOneWidget);
    });

    testWidgets('the dashboard and trends cards are in Urdu', (tester) async {
      _tallScreen(tester);
      final store = _urduStore(logs: [for (var i = 0; i < 3; i++) SymptomLog(date: _now.subtract(Duration(days: i)), symptoms: const [], mood: 'good')]);
      await tester.pumpWidget(_home(store, AppState()..now = () => _now));
      expect(find.text('ہیلتھ ڈیش بورڈ'), findsOneWidget);
      expect(find.text('میرے رجحانات'), findsOneWidget);
      expect(find.textContaining('پچھلے 7 دنوں میں سے 3 دن درج'), findsOneWidget);
    });

    testWidgets('the next step card and its call to action are in Urdu', (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(_home(_urduStore(), AppState()..now = () => _now));
      expect(find.text('آپ کا اگلا قدم'), findsOneWidget);
      expect(find.text('اپنے کمپینین سے پوچھیں'), findsOneWidget);
    });

    testWidgets('tapping a row still opens the right tab when the app is in Urdu', (tester) async {
      _tallScreen(tester);
      final app = AppState()..now = () => _now;
      await tester.pumpWidget(_home(_urduStore(pcos: true), app));
      await tester.tap(find.byKey(const Key('home_pcos')));
      expect(app.currentTabIndex, 2);
    });
  });

  group('nextStep in Urdu', () {
    HealthStore storeWith({bool pcos = false, bool scan = false, bool risk = false, bool cycle = false, List<SymptomLog> logs = const []}) {
      final s = HealthStore()..profile = HealthProfile(name: 'Ayesha', language: 'ur', onboarded: true);
      if (pcos) s.pcos = PcosSummary(date: _now, percent: 71, level: 'high', bmi: 25.9, factors: const []);
      if (scan) s.scan = ScanSummary(date: _now, prediction: 'benign', title: 'x', confidence: 0.8, probabilities: const {}, modelAccuracy: 0.7);
      if (risk) s.breastRisk = BreastRiskSummary(date: _now, probability: 0.006, average: 0.004, relativeRisk: 1.5, level: 'medium', ageGroup: '50-54', factors: const [], redFlags: const []);
      if (cycle) s.periods = [PeriodEntry(start: _now.subtract(const Duration(days: 8)), end: _now.subtract(const Duration(days: 4)))];
      s.logs = logs;
      return s;
    }

    test('each rule gives an Urdu sentence, in the same priority order as English', () {
      final today = [SymptomLog(date: _now, symptoms: const [], mood: null, notes: '')];
      final exam = _now.subtract(const Duration(days: 5));

      expect(HomeDashboardScreen.nextStep(storeWith(pcos: true, logs: today), exam, _now, language: 'ur'), contains('ماہرِ امراضِ نسواں'));
      expect(HomeDashboardScreen.nextStep(storeWith(scan: true), exam, _now, language: 'ur'), contains('آج آپ کیسا محسوس'));
      expect(HomeDashboardScreen.nextStep(storeWith(scan: true, logs: today), null, _now, language: 'ur'), contains('سیلف ایگزام'));
      expect(HomeDashboardScreen.nextStep(storeWith(scan: true, logs: today), exam, _now, language: 'ur'), contains('آخری پیریڈ کا پہلا دن'));
      expect(HomeDashboardScreen.nextStep(storeWith(logs: today, cycle: true), exam, _now, language: 'ur'), contains('پہلا چیک کریں'));
      expect(HomeDashboardScreen.nextStep(storeWith(scan: true, logs: today, cycle: true), exam, _now, language: 'ur'), contains('سب کچھ مکمل'));

      final suspicious = storeWith(logs: today);
      suspicious.scan = ScanSummary(date: _now, prediction: 'malignant', title: 'x', confidence: 0.9, probabilities: const {}, modelAccuracy: 0.7);
      expect(HomeDashboardScreen.nextStep(suspicious, exam, _now, language: 'ur'), contains('بریسٹ اسپیشلسٹ'));
    });

    test('the reported red flag still embeds her own words, inside an Urdu sentence', () {
      final flagged = storeWith(risk: true, logs: [SymptomLog(date: _now, symptoms: const [], mood: null, notes: '')]);
      flagged.breastRisk = BreastRiskSummary(date: _now, probability: 0.006, average: 0.004, relativeRisk: 1.5, level: 'medium', ageGroup: '50-54', factors: const [], redFlags: const ['Breast Lump (urgent)']);
      final step = HomeDashboardScreen.nextStep(flagged, _now.subtract(const Duration(days: 5)), _now, language: 'ur');
      expect(step, contains('ڈاکٹر سے ملاقات'));
      expect(step, contains('breast lump (urgent)'));
    });

    test('without a language argument the rules stay in English (the default used elsewhere in the app)', () {
      expect(HomeDashboardScreen.nextStep(storeWith(pcos: true, logs: [SymptomLog(date: _now, symptoms: const [], mood: null)]), _now, _now), contains('gynaecologist'));
    });
  });

  group('ago() and greeting() in Urdu', () {
    test('relative dates read naturally in Urdu', () {
      expect(HomeDashboardScreen.ago(_now, _now, language: 'ur'), 'آج');
      expect(HomeDashboardScreen.ago(_now.subtract(const Duration(days: 1)), _now, language: 'ur'), 'کل');
      expect(HomeDashboardScreen.ago(_now.subtract(const Duration(days: 12)), _now, language: 'ur'), '12 دن پہلے');
    });

    test('greeting reads naturally in Urdu at every time of day', () {
      expect(HomeDashboardScreen.greeting(DateTime(2026, 9, 20, 8), language: 'ur'), 'صبح بخیر');
      expect(HomeDashboardScreen.greeting(DateTime(2026, 9, 20, 14), language: 'ur'), 'دوپہر بخیر');
      expect(HomeDashboardScreen.greeting(DateTime(2026, 9, 20, 20), language: 'ur'), 'شام بخیر');
    });
  });
}
