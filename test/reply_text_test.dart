import 'package:femora/models/chat_state.dart';
import 'package:femora/services/api_service.dart';
import 'package:femora/widgets/reply_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _reply = '''I hear you, bad cramps are draining.

**Why period pain happens**
Your womb muscles tighten, driven by **prostaglandins**.

**What you can do today**
- Put a heat pad on your lower tummy.
* Gentle walking helps.
1. Ibuprofen (like Brufen): follow the directions on the packet.

## When to see a doctor
If painkillers do not help.''';

void main() {
  test('the reply is split into headings, bullets and paragraphs', () {
    final b = parseReply(_reply);
    expect(b.map((x) => x.kind).toList(), ['text', 'heading', 'text', 'heading', 'bullet', 'bullet', 'bullet', 'heading', 'text']);
    expect(b[1].text, 'Why period pain happens');
    expect(b[4].text, 'Put a heat pad on your lower tummy.');
    expect(b[6].text, startsWith('Ibuprofen'));
    expect(b[7].text, 'When to see a doctor');
  });

  test('the spoken version has no formatting marks and each part ends as a sentence', () {
    final s = plainForSpeech(_reply);
    expect(s, isNot(contains('*')));
    expect(s, isNot(contains('#')));
    expect(s, contains('Why period pain happens. Your womb muscles tighten, driven by prostaglandins.'));
  });

  test('an old plain reply still reads the same', () {
    expect(plainForSpeech('Drink water and rest.'), 'Drink water and rest.');
  });

  testWidgets('bold phrases and bullets render without the markdown marks', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ReplyText(_reply, direction: TextDirection.ltr, style: TextStyle(fontSize: 14))),
    ));
    expect(find.text('Why period pain happens'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('prostaglandins', findRichText: true), findsOneWidget);
  });

  test('sources travel from the server reply into the saved message', () {
    final r = ChatReply.fromJson({
      'reply': 'x',
      'source': 'gemini',
      'urgency': 'none',
      'language': 'en',
      'sources': [
        {'title': 'NHS: Period pain', 'url': 'https://www.nhs.uk/symptoms/period-pain/'},
      ],
    });
    expect(r.sources, ['NHS: Period pain']);
    final m = ChatMsg(id: '1', text: 'x', isUser: false, time: DateTime(2026), sources: r.sources);
    expect(ChatMsg.fromJson(m.toJson()).sources, ['NHS: Period pain']);
    // messages saved before sources existed still load
    expect(ChatMsg.fromJson({'id': '2', 'text': 'y', 'isUser': false, 'time': '2026-01-01T00:00:00.000'}).sources, isEmpty);
  });
}
