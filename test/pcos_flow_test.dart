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
    {'key': 'irregular_cycle', 'label': 'Irregular Cycles'},
  ],
  'guidance': [
    {'key': 'specialist', 'title': 'See a Specialist', 'description': 'Consult a gynecologist.'},
  ],
  'disclaimer': 'Not a medical diagnosis.',
};

Widget _app(PcosState state) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider.value(value: HealthStore()),
      ],
      child: const MaterialApp(home: PCOSAssessmentScreen()),
    );

Future<void> _fillQuestionnaire(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '27');
  await tester.enterText(find.widgetWithText(TextFormField, 'Height'), '155');
  await tester.enterText(find.widgetWithText(TextFormField, 'Weight'), '70');
  final choices = [
    find.text('Irregular'),
    find.text('Acne / Pimples'),
    find.text('Yes').at(0), // fast food: yes
    find.text('No').at(1), // regular exercise: no
  ];
  for (final target in choices) {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pump();
  }
  final submit = find.text('Calculate My Risk');
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('questionnaire sends answers and shows the model result', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 2; // wider logical width: the test font renders much wider than Inter
    addTearDown(tester.view.reset);

    Map<String, dynamic>? sentBody;
    final client = MockClient((request) async {
      if (request.url.path == '/predict/pcos/whatif') {
        // the what-if card asks for its quick wins once the result is showing
        return http.Response(jsonEncode({'baseline_probability': 0.81, 'baseline_risk_level': 'high', 'outcomes': [], 'note': 'n'}), 200);
      }
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(jsonEncode(_fakeResponse), 200);
    });

    await tester.pumpWidget(_app(PcosState(api: ApiService(client: client))));
    expect(find.text('Check Your PCOS Risk'), findsOneWidget);

    await tester.tap(find.text('Start Assessment'));
    await tester.pumpAndSettle();
    await _fillQuestionnaire(tester);

    expect(sentBody, isNotNull);
    expect(sentBody!['age'], 27);
    expect(sentBody!['irregular_cycle'], true);
    expect(sentBody!['pimples'], true);
    expect(sentBody!['fast_food'], true);
    expect(sentBody!['regular_exercise'], false);
    expect(sentBody!['waist_in'], isNull);

    expect(find.text('81% • High Risk'), findsOneWidget);
    expect(find.text('Irregular Cycles'), findsOneWidget);
    expect(find.text('See a Specialist'), findsOneWidget);
    expect(find.text('Retake Assessment'), findsOneWidget);
  });

  testWidgets('shows an error and stays on the form when the server is unreachable', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 2; // wider logical width: the test font renders much wider than Inter
    addTearDown(tester.view.reset);

    final client = MockClient((_) async => throw Exception('offline'));
    await tester.pumpWidget(_app(PcosState(api: ApiService(client: client))));

    await tester.tap(find.text('Start Assessment'));
    await tester.pumpAndSettle();
    await _fillQuestionnaire(tester);

    expect(find.textContaining('Could not reach the Femora server'), findsOneWidget);
    expect(find.text('Calculate My Risk'), findsOneWidget);
  });
}
