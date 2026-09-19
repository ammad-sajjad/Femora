import 'dart:convert';

import 'package:femora/models/breast.dart';
import 'package:femora/models/models.dart';
import 'package:femora/models/self_exam.dart';
import 'package:femora/screens/breast_health_screen.dart';
import 'package:femora/services/api_service.dart';
import 'package:femora/services/reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1x1 PNG standing in for the heatmap
const _pixel = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

const _riskResponse = {
  'probability': 0.0046,
  'average_probability': 0.0033,
  'relative_risk': 1.41,
  'risk_level': 'medium',
  'age_group': '40-44',
  'factors': [
    {'key': 'nrelbc', 'label': 'Family History'},
  ],
  'red_flags': [
    {'key': 'breast_lump', 'label': 'Breast Lump', 'urgency': 'urgent'},
  ],
  'urgency': 'urgent',
  'guidance': [
    {'key': 'urgent', 'title': 'See a Doctor Within 2 Weeks', 'description': 'You reported: breast lump.'},
  ],
  'notes': <String>[],
  'summary': 'Your estimated risk is 1.4 times the average.',
  'disclaimer': 'Not a medical diagnosis.',
};

const _scanResponse = {
  'prediction': 'benign',
  'title': 'Likely Benign',
  'confidence': 0.87,
  'probabilities': [
    {'key': 'normal', 'label': 'Normal', 'probability': 0.05},
    {'key': 'benign', 'label': 'Benign', 'probability': 0.87},
    {'key': 'malignant', 'label': 'Malignant', 'probability': 0.08},
  ],
  'heatmap_jpeg': _pixel,
  'summary': 'The AI rated the area it found as most likely benign.',
  'guidance': [
    {'key': 'monitor', 'title': 'Follow Up With Your Doctor', 'description': 'Benign findings are common.'},
  ],
  'model_accuracy': 0.88,
  'disclaimer': 'This AI screening is an assistive tool.',
};

class _FakeReminders extends ReminderService {
  int? scheduledDay;
  bool cancelled = false;

  @override
  bool get isSupported => true;

  @override
  Future<bool> scheduleMonthly({required int day}) async {
    scheduledDay = day;
    return true;
  }

  @override
  Future<void> cancel() async => cancelled = true;
}

class _Harness {
  final AppState app = AppState();
  final BreastState breast;
  final SelfExamState selfExam;
  final _FakeReminders reminders;

  _Harness._(this.breast, this.selfExam, this.reminders);

  factory _Harness(MockClient client) {
    final reminders = _FakeReminders();
    return _Harness._(BreastState(api: ApiService(client: client)), SelfExamState(reminders: reminders), reminders);
  }

  Widget get widget => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: app),
          ChangeNotifierProvider.value(value: breast),
          ChangeNotifierProvider.value(value: selfExam),
        ],
        child: const MaterialApp(home: BreastHealthScreen()),
      );
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    // Lazily built list items (the questionnaire is a ListView) only exist once scrolled near
    await tester.scrollUntilVisible(target, 300, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 2; // wider logical width: the test font renders much wider than Inter
    addTearDown(tester.view.reset);
  }

  testWidgets('risk questionnaire sends answers and shows the risk profile', (tester) async {
    useTallScreen(tester);
    Map<String, dynamic>? sent;
    final h = _Harness(MockClient((request) async {
      expect(request.url.path, '/predict/breast/risk');
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(jsonEncode(_riskResponse), 200);
    }));
    await tester.pumpWidget(h.widget);

    await _tap(tester, find.text('Start Questionnaire'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '42');
    await tester.enterText(find.widgetWithText(TextFormField, 'Height'), '160');
    await tester.enterText(find.widgetWithText(TextFormField, 'Weight'), '62');
    for (final answer in ['Not yet', 'Before age 30', 'One', 'No', 'A new lump or thickening in the breast']) {
      await _tap(tester, find.text(answer));
    }
    await _tap(tester, find.text('Calculate My Risk'));

    expect(sent, isNotNull);
    expect(sent!['age'], 42);
    expect(sent!['menopause'], 'pre');
    expect(sent!['first_birth'], 'under_30');
    expect(sent!['relatives_with_breast_cancer'], 1);
    expect(sent!['breast_biopsy'], false);
    expect(sent!['breast_density'], isNull);
    expect(sent!['symptoms'], ['breast_lump']);

    expect(find.text('1.4×'), findsOneWidget);
    expect(find.text('Moderate Risk'), findsOneWidget);
    expect(find.text('See a doctor within 2 weeks'), findsOneWidget);
    expect(find.text('Family History'), findsOneWidget);
    expect(find.text('Retake'), findsOneWidget);
  });

  testWidgets('questionnaire blocks submission until required choices are answered', (tester) async {
    useTallScreen(tester);
    var calls = 0;
    final h = _Harness(MockClient((_) async {
      calls++;
      return http.Response(jsonEncode(_riskResponse), 200);
    }));
    await tester.pumpWidget(h.widget);

    await _tap(tester, find.text('Start Questionnaire'));
    await _tap(tester, find.text('Calculate My Risk'));

    expect(calls, 0);
    expect(find.text('Please answer all required questions.'), findsOneWidget);
    expect(find.textContaining('•  Required'), findsWidgets);
  });

  testWidgets('sample scan is analysed and the result can be discussed with the AI companion', (tester) async {
    useTallScreen(tester);
    http.Request? sent;
    final h = _Harness(MockClient((request) async {
      sent = request;
      return http.Response(jsonEncode(_scanResponse), 200);
    }));
    await tester.pumpWidget(h.widget);

    await _tap(tester, find.text('Browse Files'));
    await _tap(tester, find.text('Sample scan: benign lesion'));

    expect(sent!.url.path, '/predict/breast/scan');
    expect(sent!.headers['content-type'], startsWith('multipart/form-data'));
    expect(find.text('Analysis Complete'), findsOneWidget);
    expect(find.text('Likely Benign'), findsOneWidget);
    expect(find.text('87% Confidence'), findsOneWidget);
    expect(find.text('AI Focus'), findsOneWidget);
    expect(find.text('Follow Up With Your Doctor'), findsOneWidget);

    await _tap(tester, find.text('Ask Femora AI'));
    expect(h.app.currentTabIndex, 4);
    expect(h.app.chatMessages.last.isUser, isFalse);
    expect(h.app.chatMessages.last.text, startsWith(_scanResponse['summary'] as String));
  });

  testWidgets('shows the server explanation when an upload is rejected', (tester) async {
    useTallScreen(tester);
    const reason = "This doesn't look like a breast ultrasound scan.";
    final h = _Harness(MockClient((_) async => http.Response(jsonEncode({'detail': reason}), 422)));
    await tester.pumpWidget(h.widget);

    await _tap(tester, find.text('Browse Files'));
    await _tap(tester, find.text('Sample scan: malignant lesion'));

    expect(find.text(reason), findsOneWidget);
    expect(find.text('Analysis Complete'), findsNothing);
    expect(find.text('Browse Files'), findsOneWidget);
  });

  testWidgets('self-exam can be logged and the monthly reminder toggled', (tester) async {
    useTallScreen(tester);
    final h = _Harness(MockClient((_) async => http.Response('{}', 500)));
    await h.selfExam.load();
    await tester.pumpWidget(h.widget);

    expect(find.text('No self-exam logged yet'), findsOneWidget);
    await _tap(tester, find.text('Log today'));
    expect(find.textContaining('Next due in 30 days'), findsOneWidget);

    await _tap(tester, find.byType(Switch));
    expect(h.selfExam.reminderOn, isTrue);
    expect(h.reminders.scheduledDay, inInclusiveRange(1, 28));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('self_exam_reminder'), isTrue);
    expect(prefs.getString('self_exam_last'), isNotNull);

    await _tap(tester, find.byType(Switch));
    expect(h.reminders.cancelled, isTrue);
  });
}
