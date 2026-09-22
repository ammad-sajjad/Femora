import 'package:flutter/material.dart';

/// The two languages Femora supports. [HealthProfile.language] stores 'en' or 'ur'; this file is the one
/// place that turns that code into a font, a text direction or a locale, so every screen agrees.
const String kUrduFontFamily = 'NotoNastaliqUrdu';

/// Added as a *fallback* to the app's default text style (see [FemoraApp] in main.dart), so any Urdu
/// character drawn anywhere in the app — even inside an English-only widget that never checked the
/// language — is drawn in this Nastaliq font instead of whatever the phone would otherwise substitute.
const List<String> kUrduFontFallback = [kUrduFontFamily];

/// Picks [en] or [ur] for a profile language code ('en' or anything else defaults to English). Written as a
/// short top-level function so a translated screen can put the English and Urdu text side by side, e.g.
/// `t(language, 'Save', 'محفوظ کریں')`, instead of a long inline ternary at every call site.
String t(String language, String en, String ur) => language == 'ur' ? ur : en;

/// Same as [t], for a list of options (e.g. a [ChoiceRow]'s labels) rather than a single string.
List<String> tList(String language, List<String> en, List<String> ur) => language == 'ur' ? ur : en;

final _urduChars = RegExp(r'[؀-ۿݐ-ݿ]');

/// True if [text] contains an Urdu (or other Arabic-script) character. Useful when a piece of text's
/// language is not known ahead of time, such as something the AI companion generated.
bool looksUrdu(String text) => _urduChars.hasMatch(text);

/// Right to left for Urdu, left to right otherwise.
TextDirection directionOf(String languageCode) => languageCode == 'ur' ? TextDirection.rtl : TextDirection.ltr;

/// The direction to draw [text] in, guessed from its own characters rather than the profile language: use
/// this for a value that can be a mix, such as a name or an AI-written sentence.
TextDirection directionOfText(String text) => looksUrdu(text) ? TextDirection.rtl : TextDirection.ltr;

/// Wraps [child] so [text] reads correctly whichever script it turns out to be in. Most screens already
/// know the profile language and can use [directionOf] directly; this is for text whose script is not
/// known ahead of time.
class AutoDirection extends StatelessWidget {
  final String text;
  final Widget child;
  const AutoDirection({super.key, required this.text, required this.child});

  @override
  Widget build(BuildContext context) => Directionality(textDirection: directionOfText(text), child: child);
}
