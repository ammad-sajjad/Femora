import 'package:flutter/material.dart';

/// One block of a companion reply: a heading, a bullet point or a paragraph.
class ReplyBlock {
  final String kind; // heading | bullet | text
  final String text;
  const ReplyBlock(this.kind, this.text);
}

final _heading = RegExp(r'^(?:#{1,4}\s*)?\*\*(.+?)\*\*:?\s*$|^#{1,4}\s+(.+)$');
final _bullet = RegExp(r'^\s*(?:[-*•]|\d+[.)])\s+(.+)$');

/// Splits the reply into blocks. The companion is asked for short bold headings on their own line and "- " bullets;
/// "* " bullets and "## " headings are accepted too, since models are not always consistent.
List<ReplyBlock> parseReply(String reply) {
  final out = <ReplyBlock>[];
  for (final raw in reply.split('\n')) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) continue;
    final h = _heading.firstMatch(line.trim());
    if (h != null) {
      out.add(ReplyBlock('heading', (h.group(1) ?? h.group(2))!.trim()));
      continue;
    }
    final b = _bullet.firstMatch(line);
    if (b != null) {
      out.add(ReplyBlock('bullet', b.group(1)!.trim()));
      continue;
    }
    out.add(ReplyBlock('text', line.trim()));
  }
  return out;
}

/// The reply as plain sentences, for reading aloud: no stars, hashes or bullet marks.
String plainForSpeech(String reply) => parseReply(reply)
    .map((b) => b.text.replaceAll('**', '').replaceAll(RegExp(r'[*_`#]'), ''))
    .map((t) => RegExp(r'[.!?؟۔:]$').hasMatch(t) ? t : '$t.')
    .join(' ');

/// Renders a companion reply with its headings, bullet points and **bold** phrases.
class ReplyText extends StatelessWidget {
  final String text;
  final TextDirection direction;
  final TextStyle style;

  const ReplyText(this.text, {super.key, required this.direction, required this.style});

  List<TextSpan> _inline(String s, TextStyle base) {
    final spans = <TextSpan>[];
    final parts = s.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(text: parts[i], style: i.isOdd ? base.copyWith(fontWeight: FontWeight.w700) : base));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final blocks = parseReply(text);
    final heading = style.copyWith(fontWeight: FontWeight.w700, fontSize: (style.fontSize ?? 14) + 0.5, color: const Color(0xFFB0124F));
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      final gap = i == 0 ? 0.0 : (b.kind == 'heading' ? 12.0 : (b.kind == 'bullet' && blocks[i - 1].kind == 'bullet' ? 4.0 : 6.0));
      if (gap > 0) children.add(SizedBox(height: gap));
      switch (b.kind) {
        case 'heading':
          children.add(Text(b.text, textDirection: direction, style: heading));
        case 'bullet':
          children.add(Row(
            textDirection: direction,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: (style.fontSize ?? 14) * 0.55, left: 2, right: 8),
                child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFFE0457B), shape: BoxShape.circle)),
              ),
              Expanded(child: Text.rich(TextSpan(children: _inline(b.text, style)), textDirection: direction)),
            ],
          ));
        default:
          children.add(Text.rich(TextSpan(children: _inline(b.text, style)), textDirection: direction));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}
