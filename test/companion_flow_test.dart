import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:femora/models/chat_state.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/models/models.dart';
import 'package:femora/models/pcos.dart';
import 'package:femora/models/insights.dart';
import 'package:femora/models/self_exam.dart';
import 'package:femora/screens/ai_companion_screen.dart';
import 'package:femora/services/api_service.dart';
import 'package:femora/services/reminder_service.dart';
import 'package:femora/services/voice_service.dart';
import 'package:femora/widgets/companion_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDevice implements VoiceDevice {
  bool permission = true;
  bool recording = false;
  final played = <Uint8List>[];
  final spokenLocally = <String>[];
  bool phoneVoiceAvailable = false;
  bool failPlayback = false;
  final _done = StreamController<void>.broadcast();

  void finishSpeaking() => _done.add(null);

  @override
  Future<bool> ensureMicPermission() async => permission;
  @override
  Future<void> startRecording() async => recording = true;
  @override
  Future<Uint8List?> stopRecording() async {
    recording = false;
    return Uint8List(4000);
  }

  @override
  Future<void> cancelRecording() async => recording = false;
  @override
  Future<void> play(Uint8List wav) async {
    if (failPlayback) throw StateError('cannot play');
    played.add(wav);
  }

  @override
  Future<bool> speakLocal(String text, {required bool urdu}) async {
    if (!phoneVoiceAvailable) return false;
    spokenLocally.add('${urdu ? 'ur' : 'en'}: $text');
    return true;
  }
  @override
  Future<void> stopPlayback() async {}
  @override
  Stream<void> get playbackComplete => _done.stream;
  @override
  void dispose() => _done.close();
}

class _NoReminders extends ReminderService {
  @override
  bool get isSupported => false;
}

Map<String, dynamic> _chat(String reply, {String urgency = 'none'}) => {'reply': reply, 'source': 'gemini', 'urgency': urgency, 'language': 'en'};

class _Harness {
  final HealthStore store = HealthStore();
  final _FakeDevice device = _FakeDevice();
  final requests = <http.Request>[];
  late final ChatState chat;
  late final VoiceController voice;
  Future<http.Response> Function(http.Request request)? chatHandler;
  http.Response Function()? speakHandler;

  _Harness() {
    final client = MockClient((request) async {
      requests.add(request);
      switch (request.url.path) {
        case '/chat':
          return chatHandler != null ? await chatHandler!(request) : http.Response(jsonEncode(_chat('Here is a careful answer.')), 200);
        case '/voice/transcribe':
          return http.Response(jsonEncode({'text': 'What is PCOS?'}), 200);
        case '/voice/speak':
          if (speakHandler != null) return speakHandler!();
          return http.Response.bytes(Uint8List.fromList(utf8.encode('RIFFxxxxWAVE')), 200, headers: {'content-type': 'audio/wav'});
      }
      return http.Response('{}', 404);
    });
    final api = ApiService(client: client);
    chat = ChatState(api: api);
    voice = VoiceController(api: api, device: device);
  }

  Widget get widget => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: AppState()),
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: chat),
          ChangeNotifierProvider.value(value: voice),
          ChangeNotifierProvider(create: (_) => SelfExamState(reminders: _NoReminders())),
        ],
        child: const MaterialApp(home: AICompanionScreen()),
      );
}

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('chat_input')), text);
  await tester.tap(find.byKey(const Key('send_button')));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // The companion's glow, breathing moods and thinking orbs repeat for ever, which pumpAndSettle would wait on.
    companionAnimations = false;
  });
  tearDown(() => companionAnimations = true);

  testWidgets('a typed question shows a typing indicator, then the answer, and sends the personal context', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.profile = HealthProfile(name: 'Ayesha', age: 27, onboarded: true);
    h.store.recordPcos(PcosResult(probability: 0.71, riskLevel: RiskLevel.high, bmi: 25.9, factors: const [], guidance: const [], disclaimer: 'x'));
    final gate = Completer<http.Response>();
    h.chatHandler = (_) => gate.future;
    await tester.pumpWidget(h.widget);

    expect(find.textContaining('Hi Ayesha'), findsOneWidget);
    expect(find.textContaining('I know: PCOS high 71%'), findsOneWidget);

    await _type(tester, 'Why are my periods irregular?');
    await tester.pump();
    expect(find.text('Why are my periods irregular?'), findsOneWidget);
    expect(find.byKey(const Key('typing_indicator')), findsOneWidget);

    gate.complete(http.Response(jsonEncode(_chat('Hormones can play a part.')), 200));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('typing_indicator')), findsNothing);
    expect(find.text('Hormones can play a part.'), findsOneWidget);

    final body = jsonDecode(h.requests.firstWhere((r) => r.url.path == '/chat').body) as Map<String, dynamic>;
    expect(body['context'], contains('PCOS screening'));
    expect(body['context'], isNot(contains('Ayesha')));
  });

  testWidgets('suggestion chips start a conversation and follow the health store', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.recordPcos(PcosResult(probability: 0.4, riskLevel: RiskLevel.medium, bmi: 24, factors: const [], guidance: const [], disclaimer: 'x'));
    await tester.pumpWidget(h.widget);

    expect(find.byKey(const Key('suggestion_What does my PCOS result mean?')), findsOneWidget); // only offered once there is a result
    expect(find.byKey(const Key('suggestion_Explain my ultrasound result')), findsNothing);
    await tester.tap(find.byKey(const Key('suggestion_What does my PCOS result mean?')));
    await tester.pumpAndSettle();
    expect(find.text('Here is a careful answer.'), findsOneWidget);
  });

  testWidgets('tapping a feeling says it for her, and the strip keeps it reachable afterwards', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.profile = HealthProfile(name: 'Ayesha', onboarded: true);
    await tester.pumpWidget(h.widget);

    expect(find.textContaining('How are you feeling today, Ayesha?'), findsOneWidget);
    expect(find.byKey(const Key('mood_sad')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mood_sad')));
    await tester.pumpAndSettle();

    final sent = jsonDecode(h.requests.firstWhere((r) => r.url.path == '/chat').body) as Map<String, dynamic>;
    expect((sent['messages'] as List).last['text'], contains('sad'));
    expect(find.text('Here is a careful answer.'), findsOneWidget);

    // The big circles give way to the slim strip once she is in a conversation.
    expect(find.byKey(const Key('mood_sad')), findsNothing);
    expect(find.byKey(const Key('mood_strip_happy')), findsOneWidget); // the strip scrolls, so only the first pills are built
  });

  testWidgets('an Urdu user is offered the feelings in Urdu and sends Urdu', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.profile = HealthProfile(name: 'Ayesha', language: 'ur', onboarded: true);
    await tester.pumpWidget(h.widget);

    expect(find.text('درد'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mood_pain')));
    await tester.pumpAndSettle();

    final sent = jsonDecode(h.requests.firstWhere((r) => r.url.path == '/chat').body) as Map<String, dynamic>;
    expect((sent['messages'] as List).last['text'], contains('درد'));
  });

  testWidgets('personalisation off is stated and sends no context', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.profile = HealthProfile(personalize: false, onboarded: true);
    await tester.pumpWidget(h.widget);
    expect(find.textContaining('Personalisation is off'), findsOneWidget);
    await _type(tester, 'hello');
    await tester.pumpAndSettle();
    final body = jsonDecode(h.requests.firstWhere((r) => r.url.path == '/chat').body) as Map<String, dynamic>;
    expect(body['context'], isNull);
  });

  testWidgets('a failed message shows the reason and "Try again" sends it again', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    var fail = true;
    h.chatHandler = (_) async => fail ? http.Response(jsonEncode({'detail': 'You are sending messages too quickly. Please wait a moment.'}), 429) : http.Response(jsonEncode(_chat('Back again.')), 200);
    await tester.pumpWidget(h.widget);

    await _type(tester, 'Hello');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat_error')), findsOneWidget);
    expect(find.textContaining('too quickly'), findsOneWidget);

    fail = false;
    await tester.tap(find.byKey(const Key('chat_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat_error')), findsNothing);
    expect(find.text('Back again.'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget); // the question is shown once, not twice
  });

  testWidgets('an urgent answer is highlighted', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.chatHandler = (_) async => http.Response(jsonEncode(_chat('This may be an emergency. Please contact a doctor now.', urgency: 'urgent')), 200);
    await tester.pumpWidget(h.widget);
    await _type(tester, 'I have heavy bleeding');
    await tester.pumpAndSettle();
    expect(find.text('Please get medical help'), findsOneWidget);
  });

  testWidgets('talk to it: tap the mic, tap again, the question is transcribed, answered and read aloud', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget);

    await tester.tap(find.byKey(const Key('mic_button')));
    await tester.pump();
    expect(h.voice.phase, VoicePhase.recording);
    expect(h.device.recording, isTrue);
    expect(find.text('Listening… tap the mic to send'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mic_button')));
    await tester.pumpAndSettle();

    final paths = h.requests.map((r) => r.url.path).toList();
    expect(paths, containsAllInOrder(['/voice/transcribe', '/chat', '/voice/speak'])); // this fake phone has no voice of its own
    expect(find.text('What is PCOS?'), findsOneWidget); // the transcript became the user's message
    expect(find.text('Here is a careful answer.'), findsOneWidget);
    expect(h.device.played, hasLength(1)); // the answer was spoken
    expect(h.voice.readAloud, isTrue);
    expect(h.voice.phase, VoicePhase.speaking);
  });

  testWidgets('a spoken answer uses the phone voice and asks the server to keep it short', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.device.phoneVoiceAvailable = true;
    h.voice.setReadAloud(true);
    await tester.pumpWidget(h.widget);

    await _type(tester, 'Why are my periods irregular?');
    await tester.pumpAndSettle();

    // The AI voice takes 5 to 16 seconds to generate, so an answer read out automatically never asks for it.
    expect(h.requests.map((r) => r.url.path), isNot(contains('/voice/speak')));
    expect(h.device.spokenLocally, hasLength(1));
    expect(h.device.played, isEmpty);

    final body = jsonDecode(h.requests.firstWhere((r) => r.url.path == '/chat').body) as Map<String, dynamic>;
    expect(body['brief'], isTrue); // a shorter answer is quicker to speak

    // The speaker button is the deliberate way to hear the nicer AI voice (once the phone voice has finished,
    // while it is still speaking the same button stops it).
    h.device.finishSpeaking();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('speak_${h.chat.messages.last.id}')));
    await tester.pumpAndSettle();
    expect(h.requests.map((r) => r.url.path), contains('/voice/speak'));
    expect(h.device.played, hasLength(1));
  });

  testWidgets('a typed answer that will not be spoken asks for the full-length reply', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget);

    await _type(tester, 'What foods help with PCOS?');
    await tester.pumpAndSettle();

    final body = jsonDecode(h.requests.firstWhere((r) => r.url.path == '/chat').body) as Map<String, dynamic>;
    expect(body['brief'], isFalse);
  });

  testWidgets('without microphone permission the app explains and keeps typing available', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.device.permission = false;
    await tester.pumpWidget(h.widget);

    await tester.tap(find.byKey(const Key('mic_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('voice_error')), findsOneWidget);
    expect(find.textContaining('Allow the microphone'), findsOneWidget);
    expect(h.voice.phase, VoicePhase.idle);

    await _type(tester, 'typing still works');
    await tester.pumpAndSettle();
    expect(find.text('Here is a careful answer.'), findsOneWidget);
  });

  testWidgets('the speaker button reads an answer aloud on demand', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget);
    await _type(tester, 'hello');
    await tester.pumpAndSettle();
    expect(h.device.played, isEmpty);
    await tester.tap(find.byKey(Key('speak_${h.chat.messages.last.id}')));
    await tester.pumpAndSettle();
    expect(h.device.played, hasLength(1));
  });

  testWidgets('when the AI voice is over its daily limit the phone voice reads the answer instead', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.speakHandler = () => http.Response(jsonEncode({'detail': 'The AI voice has reached its daily limit. Please read the text instead.'}), 429);
    h.device.phoneVoiceAvailable = true;
    await tester.pumpWidget(h.widget);
    await _type(tester, 'hello');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('speak_${h.chat.messages.last.id}')));
    await tester.pumpAndSettle();
    expect(h.device.played, isEmpty);
    expect(h.device.spokenLocally, ['en: Here is a careful answer.']);
    expect(find.byKey(const Key('voice_error')), findsNothing); // it worked, so no error is shown
    expect(h.voice.phase, VoicePhase.speaking);
    h.device.finishSpeaking();
    await tester.pump();
    expect(h.voice.phase, VoicePhase.idle);
  });

  testWidgets('if the AI voice audio cannot be played the phone voice takes over', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.device.failPlayback = true;
    h.device.phoneVoiceAvailable = true;
    await tester.pumpWidget(h.widget);
    await _type(tester, 'hello');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('speak_${h.chat.messages.last.id}')));
    await tester.pumpAndSettle();
    expect(h.device.spokenLocally, hasLength(1));
    expect(find.byKey(const Key('voice_error')), findsNothing);
  });

  testWidgets('with no AI voice and no phone voice the reason is shown and typing keeps working', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.speakHandler = () => http.Response(jsonEncode({'detail': 'The AI voice has reached its daily limit. Please read the text instead.'}), 429);
    await tester.pumpWidget(h.widget);
    await _type(tester, 'hello');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('speak_${h.chat.messages.last.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('voice_error')), findsOneWidget);
    expect(find.textContaining('daily limit'), findsOneWidget);
    expect(h.voice.phase, VoicePhase.idle);
    await _type(tester, 'still works');
    await tester.pumpAndSettle();
    expect(find.text('Here is a careful answer.'), findsWidgets);
  });

  testWidgets('an Urdu answer falls back to the Urdu phone voice, and says so when there is none', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.chatHandler = (_) async => http.Response(jsonEncode({'reply': 'آپ کو ڈاکٹر سے ملنا چاہیے۔', 'source': 'gemini', 'urgency': 'none', 'language': 'ur'}), 200);
    h.speakHandler = () => http.Response(jsonEncode({'detail': 'The AI voice has reached its daily limit. Please read the text instead.'}), 429);
    await tester.pumpWidget(h.widget);
    await _type(tester, 'hello');
    await tester.pumpAndSettle();

    await h.voice.speak('آپ کو ڈاکٹر سے ملنا چاہیے۔', language: 'auto'); // no Urdu voice on the phone
    expect(h.voice.error, contains('no Urdu voice'));

    h.device.phoneVoiceAvailable = true;
    await h.voice.speak('آپ کو ڈاکٹر سے ملنا چاہیے۔', language: 'auto');
    expect(h.device.spokenLocally.single, startsWith('ur:'));
  });

  testWidgets('delete all my data clears the profile, results and conversation', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.store.profile = HealthProfile(name: 'Ayesha', onboarded: true);
    h.store.recordPcos(PcosResult(probability: 0.71, riskLevel: RiskLevel.high, bmi: 25.9, factors: const [], guidance: const [], disclaimer: 'x'));
    await tester.pumpWidget(h.widget);
    await _type(tester, 'hello');
    await tester.pumpAndSettle();
    expect(h.chat.messages, isNotEmpty);

    await tester.tap(find.byKey(const Key('companion_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete_my_data')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(h.store.pcos, isNull);
    expect(h.store.profile.name, '');
    expect(h.chat.messages, isEmpty);
  });
}
