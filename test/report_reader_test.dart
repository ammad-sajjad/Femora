import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:femora/models/chat_state.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/models/report_reader.dart';
import 'package:femora/models/self_exam.dart';
import 'package:femora/screens/ai_companion_screen.dart';
import 'package:femora/screens/report_reader_screen.dart';
import 'package:femora/services/api_service.dart';
import 'package:femora/services/voice_service.dart';
import 'package:femora/widgets/companion_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_reminders.dart';

// A valid 1x1 PNG, so Image.memory has something to draw.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

Map<String, dynamic> reportJson({
  String kind = 'blood_test',
  String urgency = 'soon',
  String language = 'en',
  String summary = 'This is a blood test. Your haemoglobin is low.',
  List<Map<String, dynamic>>? findings,
  List<String>? questions,
}) =>
    {
      'kind': kind,
      'summary': summary,
      'findings': findings ??
          [
            {'name': 'Hemoglobin', 'value': '10.1', 'unit': 'g/dL', 'reference': '12.0 - 15.5', 'status': 'low', 'explanation': 'Lower than the printed range.'},
            {'name': 'TSH', 'value': '6.2', 'unit': 'mIU/L', 'reference': '0.4 - 4.0', 'status': 'high', 'explanation': 'Higher than the printed range.'},
            {'name': 'Glucose', 'value': '88', 'unit': 'mg/dL', 'reference': '70 - 100', 'status': 'normal', 'explanation': 'Inside the printed range.'},
          ],
      'questions_for_doctor': questions ?? ['Should my thyroid be checked again?'],
      'urgency': urgency,
      'language': language,
      'disclaimer': 'AI reading, not medical advice.',
      'source': 'gemini',
    };

class _Server {
  final requests = <http.Request>[];
  http.Response Function(http.Request)? handler;
  Map<String, dynamic> report = reportJson();

  ApiService get api => ApiService(
        client: MockClient((request) async {
          requests.add(request);
          if (handler != null) return handler!(request);
          if (request.url.path == '/report/explain') return http.Response.bytes(utf8.encode(jsonEncode(report)), 200, headers: {'content-type': 'application/json; charset=utf-8'});
          if (request.url.path == '/chat') {
            return http.Response(jsonEncode({'reply': 'Here is a careful answer.', 'source': 'gemini', 'urgency': 'none', 'language': 'en'}), 200);
          }
          return http.Response('{}', 404);
        }),
      );

  List<http.Request> get reads => requests.where((r) => r.url.path == '/report/explain').toList();
}

class _Device implements VoiceDevice {
  final spoken = <String>[];
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
  Future<bool> speakLocal(String text, {required bool urdu}) async {
    spoken.add('${urdu ? 'ur' : 'en'}: $text');
    return true;
  }

  @override
  Future<void> stopPlayback() async {}
  @override
  Stream<void> get playbackComplete => const Stream.empty();
  @override
  void dispose() {}
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 3400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

class _Rig {
  final store = HealthStore();
  final server = _Server();
  final device = _Device();
  late final VoiceController voice = VoiceController(api: server.api, device: device);
  final picked = <bool>[]; // true = camera
  List<Uint8List> Function(bool camera) photos = (_) => [Uint8List.fromList(_png)];

  Widget get screen => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: voice),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open'),
                  onPressed: () async => opened = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportReaderScreen(
                          api: server.api,
                          picker: (camera) async {
                            picked.add(camera);
                            return photos(camera);
                          },
                        ),
                      )),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

  String? opened;

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(screen);
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }
}

Future<void> _pickAndExplain(WidgetTester tester, {bool agree = true}) async {
  await tester.tap(find.byKey(const Key('reader_gallery')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('reader_explain')));
  await tester.pumpAndSettle();
  if (agree && find.byKey(const Key('consent_agree')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('consent_agree')));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ------------------------------------------------------------------ the model

  group('ExplainedReport', () {
    final now = DateTime(2026, 9, 21);

    test('reads the server answer, keeps only what it needs and round-trips', () {
      final r = ExplainedReport.fromJson(reportJson(), date: now);
      expect(r.title, 'Blood test');
      expect(r.findings.length, 3);
      expect(r.outOfRange.map((f) => f.name), ['Hemoglobin', 'TSH']);
      expect(r.readable, isTrue);
      final back = ExplainedReport.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
      expect(back.summary, r.summary);
      expect(back.date, now);
      expect(back.questions, r.questions);
      expect(back.findings.last.status, 'normal');
    });

    test('a photo that was not a report, or was unreadable, is not "readable"', () {
      expect(ExplainedReport.fromJson(reportJson(kind: 'not_medical', findings: [], questions: [], urgency: 'none'), date: now).readable, isFalse);
      expect(ExplainedReport.fromJson(reportJson(kind: 'unreadable', findings: [], questions: [], urgency: 'none'), date: now).readable, isFalse);
    });

    test('the companion line names what is out of range, has no name, and says it may be wrong', () {
      final line = ExplainedReport.fromJson(reportJson(), date: now).companionLine(now);
      expect(line, contains('Blood test read from a photo (today)'));
      expect(line, contains('Hemoglobin 10.1 g/dL (low)'));
      expect(line, contains('TSH 6.2 mIU/L (high)'));
      expect(line, isNot(contains('Glucose')));
      expect(line, contains('urgency soon'));
      expect(line, contains('may contain errors'));
    });

    test('a prescription never puts medicines or doses into the companion context', () {
      final r = ExplainedReport.fromJson(
          reportJson(kind: 'prescription', urgency: 'none', findings: [
            {'name': 'Metformin', 'value': '500 mg twice daily', 'status': 'unknown', 'explanation': 'Copied from your prescription.'}
          ]),
          date: now);
      final line = r.companionLine(now);
      expect(line, contains('1 medicine listed'));
      expect(line, isNot(contains('Metformin')));
      expect(line, isNot(contains('500')));
    });

    test('a report with nothing out of range says so', () {
      final r = ExplainedReport.fromJson(
          reportJson(urgency: 'none', findings: [
            {'name': 'Glucose', 'value': '88', 'status': 'normal', 'explanation': 'ok'}
          ]),
          date: now);
      expect(r.companionLine(now), contains('no values outside the printed ranges'));
    });
  });

  // ------------------------------------------------------------------ the API call

  group('ApiService.explainReport', () {
    test('sends every page as an "images" file and the language as a field', () async {
      final s = _Server();
      final r = await s.api.explainReport([Uint8List.fromList(_png), Uint8List.fromList(_png)], language: 'ur', date: DateTime(2026, 9, 21));
      final req = s.reads.single;
      expect(req.headers['content-type'], startsWith('multipart/form-data'));
      final body = utf8.decode(req.bodyBytes, allowMalformed: true);
      expect('name="images"'.allMatches(body).length, 2);
      expect(body, contains('name="language"'));
      expect(body, contains('\r\n\r\nur\r\n'));
      expect(r.title, 'Blood test');
      expect(r.date, DateTime(2026, 9, 21));
    });

    test('the server\'s own explanation is shown for a refused photo', () async {
      final s = _Server()..handler = (_) => http.Response(jsonEncode({'detail': 'The photo is too small to read. Please move closer and take it again.'}), 422);
      await expectLater(s.api.explainReport([Uint8List.fromList(_png)], language: 'en'), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('too small'))));
    });

    test('a busy reader (429) and a server failure (502) come through with their messages', () async {
      for (final code in [429, 502, 503]) {
        final s = _Server()..handler = (_) => http.Response(jsonEncode({'detail': 'reader said $code'}), code);
        await expectLater(s.api.explainReport([Uint8List.fromList(_png)], language: 'en'), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'reader said $code')));
      }
    });

    test('a broken answer asks the user to update the app instead of crashing', () async {
      final s = _Server()..handler = (_) => http.Response(jsonEncode({'nonsense': true}), 200);
      await expectLater(s.api.explainReport([Uint8List.fromList(_png)], language: 'en'), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('update the app'))));
    });
  });

  // ------------------------------------------------------------------ the state

  group('ReportReaderState', () {
    test('a good reading is shown and handed to be saved', () async {
      final s = _Server();
      final saved = <ExplainedReport>[];
      final st = ReportReaderState(api: s.api, onReport: saved.add);
      final ok = await st.explain([Uint8List.fromList(_png)], language: 'en');
      expect(ok, isTrue);
      expect(st.current!.title, 'Blood test');
      expect(saved.length, 1);
      expect(st.busy, isFalse);
    });

    test('a not-a-report answer is shown but never saved', () async {
      final s = _Server()..report = reportJson(kind: 'not_medical', findings: [], questions: [], urgency: 'none', summary: 'This is not a medical document.');
      final saved = <ExplainedReport>[];
      final st = ReportReaderState(api: s.api, onReport: saved.add);
      expect(await st.explain([Uint8List.fromList(_png)], language: 'en'), isTrue);
      expect(st.current!.readable, isFalse);
      expect(saved, isEmpty);
    });

    test('a failure sets the error and keeps nothing', () async {
      final s = _Server()..handler = (_) => http.Response(jsonEncode({'detail': 'busy'}), 429);
      final st = ReportReaderState(api: s.api);
      expect(await st.explain([Uint8List.fromList(_png)], language: 'en'), isFalse);
      expect(st.error, 'busy');
      expect(st.current, isNull);
    });

    test('a second tap while reading does nothing, and no photos means no request', () async {
      final s = _Server();
      final gate = Completer<http.Response>();
      s.handler = (_) => throw StateError('unused');
      final slow = ApiService(client: MockClient((r) => gate.future));
      final st = ReportReaderState(api: slow);
      final first = st.explain([Uint8List.fromList(_png)], language: 'en');
      expect(st.busy, isTrue);
      expect(await st.explain([Uint8List.fromList(_png)], language: 'en'), isFalse);
      gate.complete(http.Response(jsonEncode(reportJson()), 200));
      await first;
      expect(await st.explain([], language: 'en'), isFalse);
      expect(s.requests, isEmpty);
    });

    test('reset clears the reading and any error', () async {
      final s = _Server();
      final st = ReportReaderState(api: s.api);
      await st.explain([Uint8List.fromList(_png)], language: 'en');
      st.reset();
      expect(st.current, isNull);
      expect(st.error, isNull);
    });
  });

  // ------------------------------------------------------------------ the store

  group('HealthStore and reports', () {
    ExplainedReport rep(int day, {String kind = 'blood_test'}) => ExplainedReport.fromJson(reportJson(kind: kind), date: DateTime(2026, 9, day));

    test('keeps the newest five, newest first, and survives a restart', () async {
      final a = HealthStore();
      await a.load();
      for (var d = 1; d <= 7; d++) {
        a.recordReport(rep(d));
      }
      expect(a.reports.length, HealthStore.maxReports);
      expect(a.reports.first.date, DateTime(2026, 9, 7));
      expect(a.reports.last.date, DateTime(2026, 9, 3));
      await Future<void>.delayed(Duration.zero);

      final b = HealthStore();
      await b.load();
      expect(b.reports.length, 5);
      expect(b.reports.first.findings.first.name, 'Hemoglobin');
    });

    test('a report can be removed', () async {
      final s = HealthStore();
      await s.load();
      s.recordReport(rep(1));
      s.recordReport(rep(2));
      s.removeReport(s.reports.first);
      expect(s.reports.map((r) => r.date.day), [1]);
    });

    test('the companion hears about the newest report without the name or the photo', () async {
      final s = HealthStore()..now = () => DateTime(2026, 9, 21);
      await s.load();
      s.profile.name = 'Ayesha Khan';
      s.recordReport(rep(20));
      final ctx = s.companionContext();
      expect(ctx, contains('Blood test read from a photo (yesterday)'));
      expect(ctx, isNot(contains('Ayesha')));
    });

    test('Delete all my data removes reports and the consent', () async {
      final s = HealthStore();
      await s.load();
      await s.setReportReaderConsent(true);
      s.recordReport(rep(1));
      await s.clearAll();
      expect(s.reports, isEmpty);
      expect(s.profile.reportReaderConsent, isFalse);
      final again = HealthStore();
      await again.load();
      expect(again.reports, isEmpty);
    });

    test('each account has its own reports', () async {
      final s = HealthStore();
      await s.useAccount('one');
      s.recordReport(rep(1));
      await Future<void>.delayed(Duration.zero);
      await s.useAccount('two');
      expect(s.reports, isEmpty);
      await s.useAccount('one');
      expect(s.reports.length, 1);
    });

    test('consent is remembered', () async {
      final a = HealthStore();
      await a.load();
      expect(a.profile.reportReaderConsent, isFalse);
      await a.setReportReaderConsent(true);
      final b = HealthStore();
      await b.load();
      expect(b.profile.reportReaderConsent, isTrue);
    });
  });

  // ------------------------------------------------------------------ the screen

  group('report reader screen', () {
    testWidgets('first use asks for consent; agreeing reads the report and shows everything', (tester) async {
      _tall(tester);
      final rig = _Rig();
      await rig.open(tester);
      expect(find.text('Understand a medical report'), findsOneWidget);

      await tester.tap(find.byKey(const Key('reader_gallery')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reader_count')), findsOneWidget);
      expect(find.text('1 page ready (up to 3)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('reader_explain')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reader_consent')), findsOneWidget);
      expect(find.textContaining('Google'), findsWidgets);
      expect(rig.server.reads, isEmpty); // nothing is sent before she agrees

      await tester.tap(find.byKey(const Key('consent_agree')));
      await tester.pumpAndSettle();

      expect(rig.server.reads.length, 1);
      expect(find.byKey(const Key('reader_kind')), findsOneWidget);
      expect(find.text('Blood test'), findsOneWidget);
      expect(find.byKey(const Key('reader_summary')), findsOneWidget);
      expect(find.text('Hemoglobin'), findsOneWidget);
      expect(find.text('low'), findsOneWidget);
      expect(find.text('high'), findsOneWidget);
      expect(find.text('normal'), findsOneWidget);
      expect(find.textContaining('printed range 12.0 - 15.5'), findsOneWidget);
      expect(find.text('Should my thyroid be checked again?'), findsOneWidget);
      expect(find.byKey(const Key('reader_soon')), findsOneWidget);
      expect(find.byKey(const Key('reader_urgent')), findsNothing);
      expect(find.byKey(const Key('reader_disclaimer')), findsOneWidget);
      expect(rig.store.reports.length, 1);
      expect(rig.store.profile.reportReaderConsent, isTrue);
    });

    testWidgets('saying "Not now" sends nothing and the photo stays ready', (tester) async {
      _tall(tester);
      final rig = _Rig();
      await rig.open(tester);
      await tester.tap(find.byKey(const Key('reader_gallery')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reader_explain')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('consent_no')));
      await tester.pumpAndSettle();
      expect(rig.server.requests, isEmpty);
      expect(rig.store.profile.reportReaderConsent, isFalse);
      expect(find.byKey(const Key('reader_explain')), findsOneWidget);
    });

    testWidgets('after consent the dialog is not shown again', (tester) async {
      _tall(tester);
      final rig = _Rig();
      rig.store.profile.reportReaderConsent = true;
      await rig.open(tester);
      await _pickAndExplain(tester);
      expect(find.byKey(const Key('reader_consent')), findsNothing);
      expect(rig.server.reads.length, 1);
    });

    testWidgets('the language sent is the one in her profile', (tester) async {
      _tall(tester);
      final rig = _Rig();
      rig.store.profile.reportReaderConsent = true;
      rig.store.profile.language = 'ur';
      rig.server.report = reportJson(language: 'ur', summary: 'یہ خون کا ٹیسٹ ہے۔');
      await rig.open(tester);
      expect(find.textContaining('Urdu'), findsWidgets);
      await _pickAndExplain(tester);
      expect(utf8.decode(rig.server.reads.single.bodyBytes, allowMalformed: true), contains('\r\n\r\nur\r\n'));
      expect(find.text('یہ خون کا ٹیسٹ ہے۔'), findsOneWidget);
      final dir = tester.widget<Directionality>(find.ancestor(of: find.byKey(const Key('reader_summary')), matching: find.byType(Directionality)).first);
      expect(dir.textDirection, TextDirection.rtl);
    });

    testWidgets('up to three pages can be added and any one removed before reading', (tester) async {
      _tall(tester);
      final rig = _Rig();
      rig.store.profile.reportReaderConsent = true;
      await rig.open(tester);
      await tester.tap(find.byKey(const Key('reader_gallery')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reader_add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reader_add')));
      await tester.pumpAndSettle();
      expect(find.text('3 pages ready (up to 3)'), findsOneWidget);
      expect(find.byKey(const Key('reader_add')), findsNothing); // full

      await tester.tap(find.byKey(const Key('reader_remove_1')));
      await tester.pumpAndSettle();
      expect(find.text('2 pages ready (up to 3)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('reader_explain')));
      await tester.pumpAndSettle();
      final body = utf8.decode(rig.server.reads.single.bodyBytes, allowMalformed: true);
      expect('name="images"'.allMatches(body).length, 2);
    });

    testWidgets('picking more than three at once keeps only three', (tester) async {
      _tall(tester);
      final rig = _Rig()..photos = (_) => [for (var i = 0; i < 5; i++) Uint8List.fromList(_png)];
      await rig.open(tester);
      await tester.tap(find.byKey(const Key('reader_gallery')));
      await tester.pumpAndSettle();
      expect(find.text('3 pages ready (up to 3)'), findsOneWidget);
    });

    testWidgets('cancelling the picker changes nothing', (tester) async {
      _tall(tester);
      final rig = _Rig()..photos = (_) => [];
      await rig.open(tester);
      await tester.tap(find.byKey(const Key('reader_gallery')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reader_count')), findsNothing);
      expect(find.byKey(const Key('reader_gallery')), findsOneWidget);
    });

    testWidgets('a critical value shows the urgent banner, and a critical chip', (tester) async {
      _tall(tester);
      final rig = _Rig();
      rig.store.profile.reportReaderConsent = true;
      rig.server.report = reportJson(urgency: 'urgent', findings: [
        {'name': 'Potassium', 'value': '7.1', 'unit': 'mmol/L', 'reference': '3.5 - 5.1', 'status': 'critical', 'explanation': 'Far above the printed range.'}
      ]);
      await rig.open(tester);
      await _pickAndExplain(tester);
      expect(find.byKey(const Key('reader_urgent')), findsOneWidget);
      expect(find.textContaining('may need a doctor today'), findsOneWidget);
      expect(find.text('critical'), findsOneWidget);
    });

    testWidgets('a prescription lists the medicines without status chips or ranges', (tester) async {
      _tall(tester);
      final rig = _Rig();
      rig.store.profile.reportReaderConsent = true;
      rig.server.report = reportJson(kind: 'prescription', urgency: 'none', questions: [], findings: [
        {'name': 'Metformin', 'value': '500 mg', 'unit': '', 'reference': 'not printed', 'status': 'unknown', 'explanation': 'Copied from your prescription. Ask your doctor or pharmacist how to take it.'}
      ]);
      await rig.open(tester);
      await _pickAndExplain(tester);
      expect(find.text('Medicines on the prescription'), findsOneWidget);
      expect(find.text('Metformin'), findsOneWidget);
      expect(find.byKey(const Key('finding_status_0')), findsNothing);
      expect(find.textContaining('printed range'), findsNothing);
      expect(find.textContaining('Ask your doctor or pharmacist'), findsOneWidget);
    });

    testWidgets('not a report: says so, offers no companion button, and is not saved', (tester) async {
      _tall(tester);
      final rig = _Rig();
      rig.store.profile.reportReaderConsent = true;
      rig.server.report = reportJson(kind: 'not_medical', urgency: 'none', findings: [], questions: [], summary: 'This is not a medical document.');
      await rig.open(tester);
      await _pickAndExplain(tester);
      expect(find.text('Not a medical report'), findsOneWidget);
      expect(find.text('This is not a medical document.'), findsOneWidget);
      expect(find.byKey(const Key('reader_ask')), findsNothing);
      expect(find.byKey(const Key('reader_speak')), findsNothing);
      expect(rig.store.reports, isEmpty);
    });

    testWidgets('an error is shown on the start page and the photos are kept so she can try again', (tester) async {
      _tall(tester);
      final rig = _Rig();
      rig.store.profile.reportReaderConsent = true;
      rig.server.handler = (_) => http.Response(jsonEncode({'detail': 'The AI reader is busy right now. Please try again in a minute.'}), 429);
      await rig.open(tester);
      await _pickAndExplain(tester);
      expect(find.byKey(const Key('reader_error')), findsOneWidget);
      expect(find.textContaining('busy right now'), findsOneWidget);
      expect(find.byKey(const Key('reader_explain')), findsOneWidget);

      rig.server.handler = null;
      await tester.tap(find.byKey(const Key('reader_explain')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reader_error')), findsNothing);
      expect(find.byKey(const Key('reader_kind')), findsOneWidget);
    });

    testWidgets('a "working" screen shows while the report is read', (tester) async {
      _tall(tester);
      final rig = _Rig();
      rig.store.profile.reportReaderConsent = true;
      final gate = Completer<http.Response>();
      rig.server.handler = (_) => throw StateError('unused');
      final slow = ApiService(client: MockClient((r) => gate.future));
      await tester.pumpWidget(MultiProvider(
        providers: [ChangeNotifierProvider.value(value: rig.store), ChangeNotifierProvider.value(value: rig.voice)],
        child: MaterialApp(home: ReportReaderScreen(api: slow, picker: (_) async => [Uint8List.fromList(_png)])),
      ));
      await tester.tap(find.byKey(const Key('reader_gallery')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reader_explain')));
      await tester.pump();
      expect(find.byKey(const Key('reader_working')), findsOneWidget);
      gate.complete(http.Response(jsonEncode(reportJson()), 200));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reader_working')), findsNothing);
      expect(find.byKey(const Key('reader_kind')), findsOneWidget);
    });

    testWidgets('the speaker reads the summary in the report language', (tester) async {
      _tall(tester);
      final rig = _Rig();
      rig.store.profile.reportReaderConsent = true;
      rig.server.report = reportJson(language: 'ur', summary: 'یہ خون کا ٹیسٹ ہے۔');
      await rig.open(tester);
      await _pickAndExplain(tester);
      await tester.tap(find.byKey(const Key('reader_speak')));
      await tester.pumpAndSettle();
      expect(rig.device.spoken, ['ur: یہ خون کا ٹیسٹ ہے۔']);
    });

    testWidgets('"Read another report" returns to the start with the earlier one listed, and it can be reopened or deleted', (tester) async {
      _tall(tester);
      final rig = _Rig();
      rig.store.profile.reportReaderConsent = true;
      await rig.open(tester);
      await _pickAndExplain(tester);
      await tester.tap(find.byKey(const Key('reader_again')));
      await tester.pumpAndSettle();
      expect(find.text('Reports I explained before'), findsOneWidget);
      expect(find.byKey(const Key('reader_past_0')), findsOneWidget);

      await tester.tap(find.byKey(const Key('reader_past_0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reader_kind')), findsOneWidget);
      expect(rig.server.reads.length, 1); // reopening does not read again

      await tester.tap(find.byKey(const Key('reader_again')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reader_delete_0')));
      await tester.pumpAndSettle();
      expect(find.text('Reports I explained before'), findsNothing);
      expect(rig.store.reports, isEmpty);
    });

    testWidgets('Ask Femora hands a question back to whoever opened the reader', (tester) async {
      _tall(tester);
      final rig = _Rig();
      rig.store.profile.reportReaderConsent = true;
      await rig.open(tester);
      await _pickAndExplain(tester);
      await tester.tap(find.byKey(const Key('reader_ask')));
      await tester.pumpAndSettle();
      expect(rig.opened, contains('blood test'));
      expect(find.byKey(const Key('open')), findsOneWidget);
    });
  });

  // ------------------------------------------------------------------ from the companion

  group('from the companion', () {
    Future<(_Rig, Widget)> companion() async {
      final rig = _Rig();
      rig.store.profile.reportReaderConsent = true;
      rig.store.profile.name = 'Ayesha';
      final chat = ChatState(api: rig.server.api);
      final widget = MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: rig.store),
          ChangeNotifierProvider.value(value: chat),
          ChangeNotifierProvider.value(value: rig.voice),
          ChangeNotifierProvider(create: (_) => SelfExamState(reminders: Recorder())),
        ],
        child: MaterialApp(
          home: AICompanionScreen(
            readerBuilder: () => ReportReaderScreen(api: rig.server.api, picker: (_) async => [Uint8List.fromList(_png)]),
          ),
        ),
      );
      return (rig, widget);
    }

    testWidgets('the card on the empty companion opens the reader, and Ask Femora sends the question with the report in the context', (tester) async {
      _tall(tester);
      companionAnimations = false;
      addTearDown(() => companionAnimations = true);
      final (rig, widget) = await companion();
      await tester.pumpWidget(widget);

      await tester.tap(find.byKey(const Key('empty_report_reader')));
      await tester.pumpAndSettle();
      await _pickAndExplain(tester);
      await tester.tap(find.byKey(const Key('reader_ask')));
      await tester.pumpAndSettle();

      final chat = rig.server.requests.firstWhere((r) => r.url.path == '/chat');
      final body = jsonDecode(chat.body) as Map<String, dynamic>;
      expect((body['messages'] as List).last['text'], contains('blood test'));
      expect(body['context'], contains('Blood test read from a photo'));
      expect(body['context'], isNot(contains('Ayesha')));
      expect(find.text('Here is a careful answer.'), findsOneWidget);
    });

    testWidgets('the companion menu has the reader too', (tester) async {
      _tall(tester);
      companionAnimations = false;
      addTearDown(() => companionAnimations = true);
      final (_, widget) = await companion();
      await tester.pumpWidget(widget);
      await tester.tap(find.byKey(const Key('companion_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open_report_reader')));
      await tester.pumpAndSettle();
      expect(find.text('Understand a medical report'), findsOneWidget);
    });

    testWidgets('going back from the reader without asking sends nothing', (tester) async {
      _tall(tester);
      companionAnimations = false;
      addTearDown(() => companionAnimations = true);
      final (rig, widget) = await companion();
      await tester.pumpWidget(widget);
      await tester.tap(find.byKey(const Key('empty_report_reader')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reader_back')));
      await tester.pumpAndSettle();
      expect(rig.server.requests, isEmpty);
    });
  });
}
