import 'dart:convert';

import 'package:femora/models/breast.dart';
import 'package:femora/models/chat_state.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/models/models.dart';
import 'package:femora/models/self_exam.dart';
import 'package:femora/screens/breast_health_screen.dart';
import 'package:femora/screens/breast_risk_questionnaire_screen.dart';
import 'package:femora/services/api_service.dart';
import 'package:femora/services/reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _riskResponse = {
  'probability': 0.0046,
  'average_probability': 0.0033,
  'relative_risk': 1.41,
  'risk_level': 'medium',
  'age_group': '40-44',
  'factors': <Map<String, String>>[],
  'red_flags': <Map<String, String>>[],
  'urgency': 'none',
  'guidance': <Map<String, String>>[],
  'notes': <String>[],
  'summary': 'Your estimated risk is 1.4 times the average.',
  'disclaimer': 'Not a medical diagnosis.',
};

class _NoReminders extends ReminderService {
  @override
  bool get isSupported => false;
}

class _Harness {
  final HealthStore store;
  final BreastState breast;

  _Harness._(this.store, this.breast);

  factory _Harness(MockClient client) {
    final store = HealthStore()..profile = HealthProfile(language: 'ur', onboarded: true);
    final api = ApiService(client: client);
    return _Harness._(store, BreastState(api: api, onScan: store.recordScan, onRisk: store.recordBreastRisk));
  }

  Widget get widget => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: AppState()),
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: breast),
          ChangeNotifierProvider.value(value: ChatState()),
          ChangeNotifierProvider.value(value: SelfExamState(reminders: _NoReminders())),
        ],
        child: const MaterialApp(home: BreastHealthScreen()),
      );
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 3400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<void> _show(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 300, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the screen title, upload card and risk-start card are in Urdu', (tester) async {
    _tall(tester);
    final h = _Harness(MockClient((r) async => http.Response('{}', 500)));
    await tester.pumpWidget(h.widget);
    expect(find.text('AI اسکریننگ اور آگاہی'), findsOneWidget);
    expect(find.text('اسکین اپ لوڈ کریں'), findsOneWidget);
    expect(find.text('فائلیں دیکھیں'), findsOneWidget);
    await _show(tester, find.text('اسکین نہیں؟ اپنا رسک چیک کریں'));
    expect(find.text('سوالنامہ شروع کریں'), findsOneWidget);
  });

  testWidgets('the "how is this calculated" dialog is in Urdu', (tester) async {
    _tall(tester);
    final h = _Harness(MockClient((r) async => http.Response('{}', 500)));
    await tester.pumpWidget(h.widget);
    await _show(tester, find.byIcon(Icons.info_outline_rounded));
    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('یہ کیسے شمار کیا جاتا ہے؟'), findsOneWidget);
    await tester.tap(find.text('سمجھ گئی'));
    await tester.pumpAndSettle();
  });

  testWidgets('the self-exam card is in Urdu', (tester) async {
    _tall(tester);
    final h = _Harness(MockClient((r) async => http.Response('{}', 500)));
    await tester.pumpWidget(h.widget);
    await _show(tester, find.text('سیلف ایگزام گائیڈ'));
    expect(find.text('ابھی تک کوئی سیلف ایگزام درج نہیں ہوا'), findsOneWidget);
    expect(find.text('ماہانہ یاد دہانی'), findsOneWidget);
    expect(find.text('ٹیوٹوریل شروع کریں'), findsOneWidget);
    await tester.tap(find.text('آج درج کریں'));
    await tester.pumpAndSettle();
    expect(find.text('آج کے لیے سیلف ایگزام درج ہو گیا۔'), findsOneWidget);
  });

  testWidgets('the risk result card (labels and buttons) is in Urdu', (tester) async {
    _tall(tester);
    final h = _Harness(MockClient((request) async {
      if (request.url.path == '/predict/breast/risk') return http.Response(jsonEncode(_riskResponse), 200);
      return http.Response('{}', 404);
    }));
    await tester.pumpWidget(h.widget);
    await h.breast.submitRisk(BreastRiskAnswers(
      age: 42,
      heightCm: 160,
      weightKg: 65,
      menopause: Menopause.pre,
      firstBirth: FirstBirth.under30,
      relatives: 0,
      breastBiopsy: false,
      lastMammogram: null,
      density: null,
      symptoms: const {},
    ));
    await tester.pumpAndSettle();
    await _show(tester, find.text('رسک پروفائل'));
    expect(find.text('عمر 40-44 کی اوسط خاتون کے مقابلے میں'), findsOneWidget);
    expect(find.text('Femora AI سے پوچھیں'), findsOneWidget);
    expect(find.text('دوبارہ کریں'), findsOneWidget);
  });

  testWidgets('the breast questionnaire route from Start Questionnaire opens in Urdu', (tester) async {
    _tall(tester);
    final h = _Harness(MockClient((r) async => http.Response('{}', 500)));
    await tester.pumpWidget(h.widget);
    await _show(tester, find.text('سوالنامہ شروع کریں'));
    await tester.tap(find.text('سوالنامہ شروع کریں'));
    await tester.pumpAndSettle();
    expect(find.byType(BreastRiskQuestionnaireScreen), findsOneWidget);
    expect(find.text('بریسٹ ہیلتھ چیک'), findsOneWidget);
    expect(find.text('پیریڈز اور حمل'), findsOneWidget);
  });
}
