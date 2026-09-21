import 'dart:async';
import 'dart:convert';

import 'package:femora/models/chat_state.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/models/insights.dart';
import 'package:femora/models/models.dart';
import 'package:femora/models/pcos.dart';
import 'package:femora/models/self_exam.dart';
import 'package:femora/models/what_if.dart';
import 'package:femora/screens/pcos_assessment_screen.dart';
import 'package:femora/services/api_service.dart';
import 'package:femora/widgets/what_if_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_reminders.dart';

PcosAnswers answers({double weight = 70, double height = 165, bool exercise = false, bool fastFood = true}) => PcosAnswers(
      age: 24, heightCm: height, weightKg: weight, irregularCycle: true, periodDays: 5, weightGain: true, hairGrowth: true,
      skinDarkening: true, hairLoss: false, pimples: true, fastFood: fastFood, regularExercise: exercise,
    );

PcosResult pcosResult([double p = 0.71]) => PcosResult(probability: p, riskLevel: RiskLevel.high, bmi: 25.7, factors: const [], guidance: const [], disclaimer: 'x');

/// A stand-in for the server: each improvement lowers the estimate by 5 points.
class _Server {
  final requests = <Map<String, dynamic>>[];
  http.Response Function(http.Request)? override;
  double baseline = 0.71;

  MockClient get client => MockClient((request) async {
        if (override != null) return override!(request);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(body);
        if (request.url.path == '/predict/pcos/whatif') return http.Response(jsonEncode(_whatIf(body)), 200);
        return http.Response(jsonEncode({
          'probability': baseline, 'risk_level': 'high', 'bmi': 25.7, 'factors': [], 'guidance': [], 'disclaimer': 'x',
        }), 200);
      });

  Map<String, dynamic> _whatIf(Map<String, dynamic> body) {
    final a = body['answers'] as Map<String, dynamic>;
    final outcomes = <Map<String, dynamic>>[];
    for (final sc in body['scenarios'] as List) {
      final s = sc as Map<String, dynamic>;
      var steps = 0;
      if (s['regular_exercise'] == true && a['regular_exercise'] == false) steps++;
      if (s['fast_food'] == false && a['fast_food'] == true) steps++;
      if (s['weight_kg'] != null && (s['weight_kg'] as num) < (a['weight_kg'] as num)) steps++;
      if (s['regular_exercise'] == false && a['regular_exercise'] == true) steps--;
      if (s['fast_food'] == true && a['fast_food'] == false) steps--;
      final p = (baseline - 0.05 * steps).clamp(0.0, 1.0);
      outcomes.add({
        'label': s['label'], 'probability': p, 'risk_level': p < 0.3 ? 'low' : (p < 0.6 ? 'medium' : 'high'),
        'bmi': 25.0, 'change_points': (p - baseline) * 100,
      });
    }
    return {'baseline_probability': baseline, 'baseline_risk_level': 'high', 'outcomes': outcomes, 'note': 'Server note: a small study.'};
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the requests and answers', () {
    test('a scenario sends only what it changes', () {
      expect(const WhatIfScenario(label: 'x').toJson(), {'label': 'x'});
      expect(const WhatIfScenario(label: 'x', weightKg: 60, regularExercise: true, fastFood: false).toJson(),
          {'label': 'x', 'weight_kg': 60.0, 'regular_exercise': true, 'fast_food': false});
    });

    test('a server answer is read into outcomes with the risk level', () {
      final r = WhatIfResult.fromJson({
        'baseline_probability': 0.71, 'baseline_risk_level': 'high', 'note': 'n',
        'outcomes': [{'label': 'A', 'probability': 0.55, 'risk_level': 'medium', 'bmi': 24.1, 'change_points': -16.0}],
      });
      expect(r.baselinePercent, 71);
      expect(r.outcomes.single.riskLevel, RiskLevel.medium);
      expect(r.outcomes.single.percent, 55);
      expect(r.outcomes.single.changePoints, -16.0);
    });

    test('the API client posts the answers and the scenarios', () async {
      final server = _Server();
      final r = await ApiService(client: server.client).whatIfPcos(answers(), [const WhatIfScenario(label: 'Ex', regularExercise: true)]);
      expect(r.outcomes.single.label, 'Ex');
      final sent = server.requests.single;
      expect((sent['answers'] as Map)['weight_kg'], 70.0);
      expect((sent['scenarios'] as List).single, {'label': 'Ex', 'regular_exercise': true});
    });
  });

  group('which changes are offered', () {
    test('a typical heavier user with poor habits gets each habit, two weight steps and the combination', () {
      final s = WhatIfPlanner.quickWins(answers());
      expect(s.map((x) => x.label), ['Exercise regularly', 'Eat less fast food', 'About 5% lighter (66.5 kg)', 'About 10% lighter (63.0 kg)', 'All of these together']);
      final all = s.last;
      expect((all.weightKg, all.regularExercise, all.fastFood), (66.5, true, false));
    });

    test('with a BMI under 25 no weight loss is suggested', () {
      final s = WhatIfPlanner.quickWins(answers(weight: 60));
      expect(s.map((x) => x.label), ['Exercise regularly', 'Eat less fast food', 'All of these together']);
      expect(s.every((x) => x.weightKg == null), isTrue);
    });

    test('a single available change is offered on its own, without a combination', () {
      final s = WhatIfPlanner.quickWins(answers(weight: 60, fastFood: false));
      expect(s.map((x) => x.label), ['Exercise regularly']);
    });

    test('someone who already exercises, avoids fast food and has a BMI under 25 has nothing to try', () {
      expect(WhatIfPlanner.quickWins(answers(weight: 60, exercise: true, fastFood: false)), isEmpty);
    });

    test('an underweight user is never offered weight loss and the slider cannot go down', () {
      final a = answers(weight: 45); // BMI 16.5 at 165 cm
      expect(WhatIfPlanner.weightAtFloor(a), isTrue);
      expect(WhatIfPlanner.sliderMin(a), 45);
      expect(WhatIfPlanner.quickWins(a).every((x) => x.weightKg == null), isTrue);
    });

    test('the slider stops at a BMI of 18.5 and allows up to 10 kg more', () {
      final a = answers();
      expect(WhatIfPlanner.healthyMinWeight(165), 50.5);
      expect((WhatIfPlanner.sliderMin(a), WhatIfPlanner.sliderMax(a)), (50.5, 80.0));
      expect(WhatIfPlanner.weightAtFloor(a), isFalse);
      expect(WhatIfPlanner.sliderMax(answers(weight: 195)), 200.0);
    });

    test('no suggested weight ever gives a BMI below 18.5', () {
      for (final h in [145.0, 155.0, 165.0, 175.0, 185.0]) {
        for (var w = 40.0; w <= 130; w += 2.5) {
          final a = answers(weight: w, height: h);
          for (final s in WhatIfPlanner.quickWins(a)) {
            if (s.weightKg != null) expect(WhatIfPlanner.bmi(s.weightKg!, h), greaterThanOrEqualTo(18.5), reason: '$h cm $w kg ${s.label}');
          }
        }
      }
    });
  });

  group('the live estimate', () {
    late _Server server;
    WhatIfState make() => WhatIfState(api: ApiService(client: server.client), debounce: const Duration(milliseconds: 5));
    setUp(() => server = _Server());
    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 40));

    test('starting asks for the quick wins once', () async {
      final st = make();
      await st.start(answers());
      expect(server.requests, hasLength(1));
      expect((server.requests.single['scenarios'] as List).length, 5);
      expect(st.quick!.outcomes, hasLength(5));
      expect(st.hasChanges, isFalse);
      expect(st.live, isNull);
    });

    test('nothing is asked when there is nothing to try', () async {
      final st = make();
      await st.start(answers(weight: 60, exercise: true, fastFood: false));
      expect(server.requests, isEmpty);
      expect(st.quickScenarios, isEmpty);
    });

    test('a change is asked for after a short pause, and only what changed is sent', () async {
      final st = make();
      await st.start(answers());
      server.requests.clear();
      st.setFastFood(false);
      expect(st.hasChanges, isTrue);
      expect(st.loadingLive, isTrue);
      await settle();
      final sent = (server.requests.single['scenarios'] as List).single as Map;
      expect(sent, {'label': 'Your changes', 'fast_food': false});
      expect(st.live!.changePoints, closeTo(-5, 0.001));
      expect(st.loadingLive, isFalse);
    });

    test('several quick changes make a single request that carries all of them', () async {
      final st = make();
      await st.start(answers());
      server.requests.clear();
      st.setExercise(true);
      st.setFastFood(false);
      st.setWeight(63);
      await settle();
      expect(server.requests, hasLength(1));
      final sent = (server.requests.single['scenarios'] as List).single as Map;
      expect(sent, {'label': 'Your changes', 'weight_kg': 63.0, 'regular_exercise': true, 'fast_food': false});
      expect(st.live!.changePoints, closeTo(-15, 0.001));
    });

    test('putting a control back to the answered value clears the estimate without asking', () async {
      final st = make();
      await st.start(answers());
      server.requests.clear();
      st.setExercise(true);
      st.setExercise(false); // back to what she answered
      await settle();
      expect(server.requests, isEmpty);
      expect(st.hasChanges, isFalse);
      expect(st.live, isNull);
    });

    test('reset clears the changes and the estimate', () async {
      final st = make();
      await st.start(answers());
      st.setExercise(true);
      await settle();
      expect(st.live, isNotNull);
      st.reset();
      expect(st.hasChanges, isFalse);
      expect(st.live, isNull);
      expect((st.exercise, st.fastFood, st.weightKg), (false, true, 70.0));
    });

    test('the weight is held inside the slider range', () async {
      final st = make();
      await st.start(answers());
      st.setWeight(30);
      expect(st.weightKg, 50.5); // BMI 18.5
      st.setWeight(150);
      expect(st.weightKg, 80.0);
    });

    test('an answer that arrives late for an older change is ignored', () async {
      final first = Completer<http.Response>();
      var calls = 0;
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path == '/predict/pcos/whatif' && (body['scenarios'] as List).length == 1) {
          calls++;
          if (calls == 1) return first.future; // the first live request is held back
        }
        return http.Response(jsonEncode(_Server()._whatIf(body)), 200);
      });
      final st = WhatIfState(api: ApiService(client: client), debounce: const Duration(milliseconds: 5));
      await st.start(answers());
      st.setFastFood(false); // request 1 (held)
      await settle();
      st.setExercise(true); // request 2 (fast food off and exercise on)
      await settle();
      expect(st.live!.changePoints, closeTo(-10, 0.001));
      first.complete(http.Response(jsonEncode(_Server()._whatIf({'answers': answers().toJson(), 'scenarios': [{'label': 'old', 'fast_food': false}]})), 200));
      await settle();
      expect(st.live!.changePoints, closeTo(-10, 0.001)); // still the newer answer
    });

    test('a server problem is shown, and the next good answer replaces it', () async {
      final st = make();
      await st.start(answers());
      server.override = (_) => http.Response(jsonEncode({'detail': 'The server is busy.'}), 503);
      st.setExercise(true);
      await settle();
      expect(st.error, contains('busy'));
      expect(st.live, isNull);
      server.override = null;
      st.setFastFood(false);
      await settle();
      expect(st.error, isNull);
      expect(st.live, isNotNull);
    });
  });

  group('the card', () {
    late _Server server;
    setUp(() => server = _Server());

    Widget host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));
    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(1170, 4200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
    }

    WhatIfCard card({PcosAnswers? a, VoidCallback? onAsk}) => WhatIfCard(answers: a ?? answers(), result: pcosResult(), api: ApiService(client: server.client), onAsk: onAsk);

    testWidgets('it starts with a hint and the quick wins with their effect', (tester) async {
      tall(tester);
      await tester.pumpWidget(host(card()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('whatif_hint')), findsOneWidget);
      expect(find.text('Exercise regularly'), findsOneWidget);
      expect(find.text('All of these together'), findsOneWidget);
      expect(find.text('5 points lower'), findsWidgets);
      expect(find.text('Server note: a small study.'), findsOneWidget); // the server's own caution is shown
      expect(find.byKey(const Key('whatif_reset')), findsNothing);
    });

    testWidgets('switching fast food off shows the new estimate and the change, and Reset takes it back', (tester) async {
      tall(tester);
      await tester.pumpWidget(host(card()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('whatif_fastfood')));
      await tester.pump();
      expect(find.byKey(const Key('whatif_working')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('whatif_now')), findsOneWidget);
      expect(((tester.widget(find.byKey(const Key('whatif_now')))) as Text).data, '71%');
      expect(((tester.widget(find.byKey(const Key('whatif_live')))) as Text).data, '66%');
      expect(((tester.widget(find.byKey(const Key('whatif_delta')))) as Text).data, '5 points lower');

      await tester.tap(find.byKey(const Key('whatif_reset')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('whatif_hint')), findsOneWidget);
      expect(find.byKey(const Key('whatif_live')), findsNothing);
    });

    testWidgets('turning a good habit off raises the estimate and says so', (tester) async {
      tall(tester);
      await tester.pumpWidget(host(card(a: answers(exercise: true))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('whatif_exercise')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(((tester.widget(find.byKey(const Key('whatif_delta')))) as Text).data, '5 points higher');
    });

    testWidgets('the weight slider moves the estimate and shows the BMI', (tester) async {
      tall(tester);
      await tester.pumpWidget(host(card()));
      await tester.pumpAndSettle();
      expect(((tester.widget(find.byKey(const Key('whatif_weight_text')))) as Text).data, '70.0 kg · BMI 25.7');
      final slider = tester.widget<Slider>(find.byKey(const Key('whatif_weight')));
      expect((slider.min, slider.max), (50.5, 80.0));
      slider.onChanged!(64);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(((tester.widget(find.byKey(const Key('whatif_weight_text')))) as Text).data, contains('64.0 kg'));
      expect(find.byKey(const Key('whatif_live')), findsOneWidget);
    });

    testWidgets('an underweight user has no slider, only an explanation', (tester) async {
      tall(tester);
      await tester.pumpWidget(host(card(a: answers(weight: 45))));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('whatif_weight')), findsNothing);
      expect(find.byKey(const Key('whatif_weight_note')), findsOneWidget);
      expect(find.textContaining('lowering it is not offered'), findsOneWidget);
    });

    testWidgets('when nothing is left to try it says so, and never suggests changing symptoms', (tester) async {
      tall(tester);
      await tester.pumpWidget(host(card(a: answers(weight: 60, exercise: true, fastFood: false))));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('whatif_none')), findsOneWidget);
      expect(find.textContaining('talk to a doctor'), findsOneWidget);
      expect(server.requests, isEmpty);
    });

    testWidgets('a server problem while trying a change is shown in place of the number', (tester) async {
      tall(tester);
      await tester.pumpWidget(host(card()));
      await tester.pumpAndSettle();
      server.override = (_) => http.Response(jsonEncode({'detail': 'Could not reach the server.'}), 503);
      await tester.tap(find.byKey(const Key('whatif_exercise')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('whatif_error')), findsOneWidget);
    });

    testWidgets('the ask button hands over to the companion', (tester) async {
      tall(tester);
      var asked = 0;
      await tester.pumpWidget(host(card(onAsk: () => asked++)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('whatif_ask')));
      await tester.tap(find.byKey(const Key('whatif_ask')));
      expect(asked, 1);
    });

    testWidgets('the warning about not changing diet without a doctor is always visible', (tester) async {
      tall(tester);
      server.override = (_) => http.Response('{}', 500); // even if the server never answers
      await tester.pumpWidget(host(card()));
      await tester.pumpAndSettle();
      expect(find.textContaining('without asking your doctor'), findsOneWidget);
    });
  });

  group('on the PCOS tab', () {
    testWidgets('the card appears once there is a result and hands the question to the companion', (tester) async {
      tester.view.physicalSize = const Size(1170, 6000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final server = _Server();
      final pcos = PcosState(api: ApiService(client: server.client));
      final app = AppState();
      final store = HealthStore();
      final chat = ChatState(api: ApiService(client: MockClient((r) async => http.Response(jsonEncode({'reply': 'Here is how to read it.', 'source': 'gemini', 'urgency': 'none', 'language': 'en'}), 200))));
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: pcos),
          ChangeNotifierProvider.value(value: app),
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: chat),
          ChangeNotifierProvider.value(value: SelfExamState(reminders: Recorder())),
        ],
        child: const MaterialApp(home: PCOSAssessmentScreen()),
      ));
      expect(find.byKey(const Key('whatif_card')), findsNothing); // no result yet

      await pcos.submit(answers());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('whatif_card')), findsOneWidget);
      expect(server.requests.where((r) => r.containsKey('scenarios')), hasLength(1));

      await tester.ensureVisible(find.byKey(const Key('whatif_ask')));
      await tester.tap(find.byKey(const Key('whatif_ask')));
      await tester.pumpAndSettle();
      expect(app.currentTabIndex, 4);
      expect(chat.messages.first.text, contains('what-if'));
    });
  });
}
