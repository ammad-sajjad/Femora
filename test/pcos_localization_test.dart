import 'dart:convert';

import 'package:femora/models/health_store.dart';
import 'package:femora/models/pcos.dart';
import 'package:femora/screens/pcos_assessment_screen.dart';
import 'package:femora/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fakeResponse = {
  'probability': 0.8123,
  'risk_level': 'high',
  'bmi': 29.1,
  'factors': [
    {'key': 'bmi', 'label': 'BMI 29.1'},
  ],
  'guidance': [
    {'key': 'specialist', 'title': 'See a Specialist', 'description': 'Consult a gynecologist.'},
  ],
  'disclaimer': 'Not a medical diagnosis.',
};

Widget _app(PcosState state, {String language = 'ur'}) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider.value(value: HealthStore()..profile = HealthProfile(language: language, onboarded: true)),
      ],
      child: const MaterialApp(home: PCOSAssessmentScreen()),
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// Scrolls the (lazily built) form until [target] exists, then makes it fully visible.
Future<void> _show(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 300, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the start card is in Urdu', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(PcosState(api: ApiService(client: MockClient((r) async => http.Response('{}', 500))))));
    expect(find.text('PCOS رسک جائزہ'), findsOneWidget);
    expect(find.text('اپنا PCOS رسک چیک کریں'), findsOneWidget);
    expect(find.text('جائزہ شروع کریں'), findsOneWidget);
  });

  testWidgets('the questionnaire (title, sections, questions, options, submit) is in Urdu', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(PcosState(api: ApiService(client: MockClient((r) async => http.Response('{}', 500))))));
    await tester.tap(find.text('جائزہ شروع کریں'));
    await tester.pumpAndSettle();

    expect(find.text('PCOS رسک چیک'), findsOneWidget);
    expect(find.text('آپ کے بارے میں'), findsOneWidget);
    expect(find.text('آپ کا سائیکل'), findsOneWidget);
    expect(find.text('آپ کے پیریڈز کتنے باقاعدہ ہیں؟'), findsOneWidget);
    expect(find.text('باقاعدہ'), findsOneWidget);
    expect(find.text('بے قاعدہ'), findsOneWidget);
    await _show(tester, find.text('علامات'));
    expect(find.text('کیل مہاسے'), findsOneWidget);
    await _show(tester, find.text('طرزِ زندگی'));
    expect(find.text('کیا آپ اکثر فاسٹ فوڈ کھاتی ہیں؟'), findsOneWidget);
    expect(find.text('جی ہاں'), findsWidgets);
    await _show(tester, find.text('میرا رسک معلوم کریں'));
    expect(find.text('میرا رسک معلوم کریں'), findsOneWidget);
  });

  testWidgets('submitting without the required choices shows the Urdu error', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(PcosState(api: ApiService(client: MockClient((r) async => http.Response('{}', 500))))));
    await tester.tap(find.text('جائزہ شروع کریں'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'عمر'), '27');
    await tester.enterText(find.widgetWithText(TextFormField, 'قد'), '155');
    await tester.enterText(find.widgetWithText(TextFormField, 'وزن'), '60');
    await _show(tester, find.text('میرا رسک معلوم کریں'));
    await tester.tap(find.text('میرا رسک معلوم کریں'));
    await tester.pumpAndSettle();
    expect(find.text('براہِ کرم تمام ضروری سوالات کے جواب دیں۔'), findsOneWidget);
  });

  testWidgets('the result card (labels and Retake button) is in Urdu', (tester) async {
    _tall(tester);
    final client = MockClient((request) async {
      if (request.url.path == '/predict/pcos/whatif') return http.Response(jsonEncode({'baseline_probability': 0.81, 'baseline_risk_level': 'high', 'outcomes': [], 'note': 'n'}), 200);
      return http.Response(jsonEncode(_fakeResponse), 200);
    });
    await tester.pumpWidget(_app(PcosState(api: ApiService(client: client))));
    await tester.tap(find.text('جائزہ شروع کریں'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'عمر'), '27');
    await tester.enterText(find.widgetWithText(TextFormField, 'قد'), '155');
    await tester.enterText(find.widgetWithText(TextFormField, 'وزن'), '70');
    for (final target in [find.text('بے قاعدہ'), find.text('کیل مہاسے'), find.text('جی ہاں').at(0), find.text('نہیں').at(1)]) {
      await _show(tester, target);
      await tester.tap(target);
      await tester.pump();
    }
    final submit = find.text('میرا رسک معلوم کریں');
    await _show(tester, submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('رسک جائزہ'), findsOneWidget);
    expect(find.text('دوبارہ جائزہ لیں'), findsOneWidget);
    expect(find.text('قابلِ عمل رہنمائی'), findsOneWidget);
  });
}
