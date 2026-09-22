import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:femora/models/chat_state.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/models/models.dart';
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
  @override
  Future<bool> ensureMicPermission() async => true;
  @override
  Future<void> startRecording() async {}
  @override
  Future<Uint8List?> stopRecording() async => null;
  @override
  Future<void> cancelRecording() async {}
  @override
  Future<void> play(Uint8List wav) async {}
  @override
  Future<bool> speakLocal(String text, {required bool urdu}) async => false;
  @override
  Future<void> stopPlayback() async {}
  @override
  Stream<void> get playbackComplete => const Stream.empty();
  @override
  void dispose() {}
}

class _NoReminders extends ReminderService {
  @override
  bool get isSupported => false;
}

Map<String, dynamic> _chat(String reply, {String urgency = 'none', String language = 'ur'}) => {'reply': reply, 'source': 'gemini', 'urgency': urgency, 'language': language};

class _Harness {
  final HealthStore store = HealthStore()..profile = HealthProfile(name: 'عائشہ', language: 'ur', onboarded: true);
  final requests = <http.Request>[];
  late final ChatState chat;
  late final VoiceController voice;
  Future<http.Response> Function(http.Request request)? chatHandler;

  _Harness() {
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/chat') {
        return chatHandler != null ? await chatHandler!(request) : http.Response.bytes(utf8.encode(jsonEncode(_chat('یہ ایک محتاط جواب ہے۔'))), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response('{}', 404);
    });
    final api = ApiService(client: client);
    chat = ChatState(api: api);
    voice = VoiceController(api: api, device: _FakeDevice());
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    companionAnimations = false;
  });
  tearDown(() => companionAnimations = true);

  testWidgets('the empty state, disclaimer and report-reader card are in Urdu', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_Harness().widget);
    expect(find.textContaining('آج آپ کیسا محسوس کر رہی ہیں'), findsOneWidget);
    expect(find.text('یا مجھ سے پوچھیں'), findsOneWidget);
    expect(find.textContaining('لیب یا الٹراساؤنڈ رپورٹ ہے؟'), findsOneWidget);
    expect(find.textContaining('Femora AI عمومی معلومات دیتا ہے'), findsOneWidget);
  });

  testWidgets('the companion settings menu is in Urdu', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    await tester.pumpWidget(h.widget);
    await tester.tap(find.byKey(const Key('companion_menu')));
    await tester.pumpAndSettle();
    expect(find.text('کمپینین کی سیٹنگز'), findsOneWidget);
    expect(find.text('میری پروفائل تبدیل کریں'), findsOneWidget);
    expect(find.text('میڈیکل رپورٹ سمجھائیں'), findsOneWidget);
    expect(find.text('ہیلتھ رپورٹ (PDF)'), findsOneWidget);
    expect(find.text('یہ گفتگو صاف کریں'), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete_my_data')));
    await tester.pumpAndSettle();
    expect(find.text('سب کچھ حذف کریں؟'), findsOneWidget);
    expect(find.text('منسوخ کریں'), findsOneWidget);
    await tester.tap(find.text('منسوخ کریں'));
    await tester.pumpAndSettle();
  });

  testWidgets('a reply flagged urgent shows the Urdu warning label', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.chatHandler = (_) async => http.Response.bytes(utf8.encode(jsonEncode(_chat('یہ فوری ہے۔', urgency: 'urgent'))), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    await tester.pumpWidget(h.widget);
    await tester.enterText(find.byKey(const Key('chat_input')), 'مدد');
    await tester.tap(find.byKey(const Key('send_button')));
    await tester.pumpAndSettle();
    expect(find.text('براہِ کرم طبی مدد حاصل کریں'), findsOneWidget);
  });

  testWidgets('a failed message shows the Urdu retry button', (tester) async {
    _tallScreen(tester);
    final h = _Harness();
    h.chatHandler = (_) async => http.Response('{}', 500);
    await tester.pumpWidget(h.widget);
    await tester.enterText(find.byKey(const Key('chat_input')), 'سوال');
    await tester.tap(find.byKey(const Key('send_button')));
    await tester.pumpAndSettle();
    expect(find.text('دوبارہ کوشش کریں'), findsOneWidget);
  });
}
