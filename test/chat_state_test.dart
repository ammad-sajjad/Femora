import 'dart:convert';

import 'package:femora/models/chat_state.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _reply(String text, {String urgency = 'none', String source = 'gemini'}) =>
    {'reply': text, 'source': source, 'urgency': urgency, 'language': 'en'};

HealthStore _storeWithData({bool personalize = true}) {
  final s = HealthStore()..profile = HealthProfile(name: 'Ayesha', age: 27, personalize: personalize, onboarded: true);
  return s;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sends the question, history and a name-free context, and keeps the answer', () async {
    final bodies = <Map<String, dynamic>>[];
    final chat = ChatState(api: ApiService(client: MockClient((r) async {
      bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
      return http.Response(jsonEncode(_reply('Answer ${bodies.length}')), 200);
    })));
    final store = _storeWithData();

    expect(await chat.send('  What is PCOS? ', store: store), 'Answer 1');
    expect(await chat.send('And how is it treated?', store: store), 'Answer 2');

    expect(bodies[0]['messages'], [
      {'role': 'user', 'text': 'What is PCOS?'}
    ]);
    expect(bodies[0]['language'], 'auto');
    expect(bodies[0]['context'], contains('age 27'));
    expect(bodies[0]['context'], isNot(contains('Ayesha')));
    expect(bodies[1]['messages'], [
      {'role': 'user', 'text': 'What is PCOS?'},
      {'role': 'assistant', 'text': 'Answer 1'},
      {'role': 'user', 'text': 'And how is it treated?'},
    ]);
    expect(chat.messages.map((m) => m.isUser), [true, false, true, false]);
    expect(chat.sending, isFalse);
    expect(chat.error, isNull);
  });

  test('no context is sent when personalisation is off', () async {
    Map<String, dynamic>? body;
    final chat = ChatState(api: ApiService(client: MockClient((r) async {
      body = jsonDecode(r.body) as Map<String, dynamic>;
      return http.Response(jsonEncode(_reply('ok')), 200);
    })));
    await chat.send('hello', store: _storeWithData(personalize: false));
    expect(body!['context'], isNull);
  });

  test('a failure keeps the question, reports the reason, and can be retried', () async {
    var fail = true;
    final chat = ChatState(api: ApiService(client: MockClient((r) async {
      if (fail) return http.Response(jsonEncode({'detail': 'You are sending messages too quickly.'}), 429);
      return http.Response(jsonEncode(_reply('Now it works')), 200);
    })));
    final store = _storeWithData();

    expect(await chat.send('Hello', store: store), isNull);
    expect(chat.error, 'You are sending messages too quickly.');
    expect(chat.messages.single.isUser, isTrue);

    fail = false;
    final q = chat.takeLastUnanswered();
    expect(q, 'Hello');
    expect(chat.messages, isEmpty);
    expect(chat.error, isNull);
    expect(await chat.send(q!, store: store), 'Now it works');
  });

  test('urgent and offline answers are marked', () async {
    final chat = ChatState(api: ApiService(client: MockClient((r) async => http.Response(jsonEncode(_reply('Go now', urgency: 'urgent', source: 'fallback')), 200))));
    await chat.send('I have heavy bleeding', store: _storeWithData());
    expect(chat.messages.last.urgent, isTrue);
    expect(chat.messages.last.offline, isTrue);
  });

  test('only the last few turns are sent, and they always start with a user message', () async {
    Map<String, dynamic>? body;
    final chat = ChatState(api: ApiService(client: MockClient((r) async {
      body = jsonDecode(r.body) as Map<String, dynamic>;
      return http.Response(jsonEncode(_reply('r')), 200);
    })));
    final store = _storeWithData();
    for (var i = 0; i < 8; i++) {
      await chat.send('question $i', store: store);
    }
    final wire = (body!['messages'] as List).cast<Map<String, dynamic>>();
    expect(wire.length, lessThanOrEqualTo(10)); // the server accepts 12 in total
    expect(wire.first['role'], 'user');
    expect(wire.last, {'role': 'user', 'text': 'question 7'});
  });

  test('history survives a restart, and can be cleared', () async {
    final api = ApiService(client: MockClient((r) async => http.Response(jsonEncode(_reply('kept')), 200)));
    final a = ChatState(api: api);
    await a.send('remember me', store: _storeWithData());
    final b = ChatState(api: api);
    await b.load();
    expect(b.messages.map((m) => m.text), ['remember me', 'kept']);
    await b.clear();
    final c = ChatState(api: api);
    await c.load();
    expect(c.messages, isEmpty);
  });

  test('empty text and overlapping sends are ignored', () async {
    var calls = 0;
    final chat = ChatState(api: ApiService(client: MockClient((r) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return http.Response(jsonEncode(_reply('ok')), 200);
    })));
    final store = _storeWithData();
    expect(await chat.send('   ', store: store), isNull);
    final first = chat.send('one', store: store);
    expect(await chat.send('two', store: store), isNull); // still busy
    await first;
    expect(calls, 1);
  });

  test('an unexpected server answer becomes a friendly error', () async {
    final chat = ChatState(api: ApiService(client: MockClient((r) async => http.Response('{"oops": 1}', 200))));
    expect(await chat.send('hi', store: _storeWithData()), isNull);
    expect(chat.error, contains('unexpected response'));
  });
}
