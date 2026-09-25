import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../models/chat_state.dart';
import '../models/health_store.dart';
import '../models/places.dart';
import '../models/self_exam.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';
import '../widgets/companion_effects.dart';
import '../widgets/femora_header.dart';
import '../widgets/mood_picker.dart';
import '../widgets/nearby_care_button.dart';
import '../widgets/reply_text.dart';
import 'onboarding_screen.dart';
import 'report_reader_screen.dart';
import 'report_screen.dart';

final _urduChars = RegExp(r'[؀-ۿ]');
bool _isUrdu(String text) => _urduChars.hasMatch(text);

/// The personal AI companion: chat, voice in and out, and a summary of what it knows about the user.
class AICompanionScreen extends StatefulWidget {
  /// Tests pass a reader wired to a fake server and photo picker.
  final Widget Function()? readerBuilder;

  const AICompanionScreen({super.key, this.readerBuilder});

  @override
  State<AICompanionScreen> createState() => _AICompanionScreenState();
}

class _AICompanionScreenState extends State<AICompanionScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  int _shownCount = -1;
  bool _wasSending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(String text, {bool spoken = false}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final chat = context.read<ChatState>();
    final store = context.read<HealthStore>();
    final voice = context.read<VoiceController>();
    final lastExam = context.read<SelfExamState>().lastExam;
    _controller.clear();
    if (spoken) voice.readAloud = true; // a spoken question gets a spoken answer
    final willSpeak = voice.readAloud || spoken;
    final reply = await chat.send(t, store: store, lastSelfExam: lastExam, willBeSpoken: willSpeak);
    if (reply != null && voice.readAloud) {
      // The natural voice takes about 2 seconds; the phone's own voice takes over if it cannot be reached.
      await voice.speak(plainForSpeech(reply), language: 'auto');
    }
  }

  Future<void> _toggleMic() async {
    final voice = context.read<VoiceController>();
    switch (voice.phase) {
      case VoicePhase.recording:
        final text = await voice.stopAndTranscribe(language: 'auto');
        if (text != null && mounted) await _send(text, spoken: true);
      case VoicePhase.speaking:
        await voice.stopSpeaking();
      case VoicePhase.transcribing:
        break;
      case VoicePhase.idle:
        await voice.startListening();
    }
  }

  /// A tapped feeling becomes an ordinary message, so the companion comforts her exactly as it would
  /// if she had typed the words herself.
  void _pickMood(Mood mood) {
    final urdu = context.read<HealthStore>().profile.language == 'ur';
    _send(mood.message(urdu));
  }

  /// Opens the report reader; if she taps "Ask Femora about this" the question is sent to the companion.
  Future<void> _openReader() async {
    final question = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => widget.readerBuilder?.call() ?? const ReportReaderScreen()));
    if (question != null && mounted) await _send(question);
  }

  List<String> _suggestions(HealthStore store) {
    final ur = store.profile.language == 'ur';
    return [
      if (store.pcos != null) ur ? 'میرے PCOS کے نتیجے کا کیا مطلب ہے؟' : 'What does my PCOS result mean?',
      if (store.scan != null) ur ? 'میرے الٹراساؤنڈ کا نتیجہ سمجھائیں' : 'Explain my ultrasound result',
      if (store.breastRisk != null) ur ? 'میرے بریسٹ رسک کا کیا مطلب ہے؟' : 'What does my breast risk mean?',
      if (store.periods.isNotEmpty) ur ? 'میرا اگلا پیریڈ کب آئے گا؟' : 'When is my next period, and how sure is that?',
      ur ? 'میرے پیریڈز بے قاعدہ کیوں ہیں؟' : 'Why might my periods be irregular?',
      ur ? 'بریسٹ سیلف ایگزام کیسے کریں؟' : 'How do I do a breast self-exam?',
      ur ? 'PCOS میں کیا کھانا چاہیے؟' : 'What foods help with PCOS?',
    ].take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatState>();
    final store = context.watch<HealthStore>();
    final voice = context.watch<VoiceController>();
    final messages = chat.messages;

    if (messages.length != _shownCount || chat.sending != _wasSending) {
      _shownCount = messages.length;
      _wasSending = chat.sending;
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const FemoraHeader(),
            _companionCard(context, store, voice),
            Expanded(
              child: messages.isEmpty && !chat.sending
                  ? _emptyState(store)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      itemCount: messages.length + (chat.sending ? 1 : 0),
                      itemBuilder: (context, i) => i == messages.length ? _typing() : _bubble(messages[i], voice, store.profile.language),
                    ),
            ),
            if (chat.error != null) _errorBanner(chat.error!, store.profile.language),
            if (voice.error != null) _voiceError(voice),
            // Once the conversation has started the big circles are gone, so a slim strip keeps a feeling one tap away.
            if (messages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MoodStrip(urdu: store.profile.language == 'ur', onPick: _pickMood),
              ),
            _inputBar(context, voice, chat),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ what the companion knows

  Widget _companionCard(BuildContext context, HealthStore store, VoiceController voice) {
    final p = store.profile;
    final chips = <String>[
      if (store.pcos != null) 'PCOS ${store.pcos!.level} ${store.pcos!.percent}%',
      if (store.scan != null) store.scan!.title,
      if (store.breastRisk != null) 'Breast risk ${store.breastRisk!.level}',
      if (store.logs.isNotEmpty) '${store.logs.length} daily log${store.logs.length == 1 ? '' : 's'}',
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(22), boxShadow: AppTheme.softShadow),
      child: Row(
        children: [
          GlowRing(
            size: 50,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(gradient: AppColors.buttonGradient, shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.firstName.isEmpty ? 'Your Femora companion' : 'Hi ${p.firstName}, I\'m your companion',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                const SizedBox(height: 3),
                Text(
                  !p.personalize
                      ? 'Personalisation is off: I answer generally.'
                      : chips.isEmpty
                          ? 'Do a PCOS check or scan and I will get to know you.'
                          : 'I know: ${chips.join('  •  ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textMuted, height: 1.3),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('companion_menu'),
            icon: const Icon(Icons.tune_rounded, color: AppColors.primaryBerry),
            onPressed: () => _openMenu(context),
          ),
        ],
      ),
    );
  }

  void _openMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => Consumer3<HealthStore, VoiceController, ChatState>(
        builder: (sheet, store, voice, chat, _) {
          final language = store.profile.language;
          return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t(language, 'Companion settings', 'کمپینین کی سیٹنگز'), style: const TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w700)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primaryBerry,
                  title: Text(t(language, 'Personalise with my results', 'میرے نتائج کے ساتھ ذاتی بنائیں')),
                  subtitle: Text(t(language, 'Shares a short summary, never your name.', 'ایک مختصر خلاصہ شیئر کرتا ہے، کبھی آپ کا نام نہیں۔')),
                  value: store.profile.personalize,
                  onChanged: (v) {
                    store.profile.personalize = v;
                    store.saveProfile(store.profile);
                  },
                ),
                SwitchListTile(
                  key: const Key('read_aloud_switch'),
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primaryBerry,
                  title: Text(t(language, 'Read answers aloud', 'جوابات بلند آواز سے پڑھیں')),
                  subtitle: Text(t(language, 'Answers in a natural voice. Tap the speaker on any message to hear it again.',
                      'قدرتی آواز میں جواب دیتا ہے۔ کوئی پیغام دوبارہ سننے کے لیے اس پر اسپیکر آئیکن دبائیں۔')),
                  value: voice.readAloud,
                  onChanged: voice.setReadAloud,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline_rounded, color: AppColors.primaryBerry),
                  title: Text(t(language, 'Edit my profile', 'میری پروفائل تبدیل کریں')),
                  onTap: () {
                    Navigator.pop(sheet);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingScreen(editing: true)));
                  },
                ),
                ListTile(
                  key: const Key('open_report_reader'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.document_scanner_outlined, color: AppColors.primaryBerry),
                  title: Text(t(language, 'Explain a medical report', 'میڈیکل رپورٹ سمجھائیں')),
                  subtitle: Text(t(language, 'Photo of a lab test or ultrasound report', 'لیب ٹیسٹ یا الٹراساؤنڈ رپورٹ کی تصویر')),
                  onTap: () {
                    Navigator.pop(sheet);
                    _openReader();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined, color: AppColors.primaryBerry),
                  title: Text(t(language, 'Health report (PDF)', 'ہیلتھ رپورٹ (PDF)')),
                  onTap: () {
                    Navigator.pop(sheet);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen()));
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_sweep_outlined, color: AppColors.primaryBerry),
                  title: Text(t(language, 'Clear this conversation', 'یہ گفتگو صاف کریں')),
                  onTap: () {
                    chat.clear();
                    Navigator.pop(sheet);
                  },
                ),
                ListTile(
                  key: const Key('delete_my_data'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_reset_rounded, color: AppColors.accentPink),
                  title: Text(t(language, 'Delete all my data on this phone', 'اس فون پر میرا تمام ڈیٹا حذف کریں'), style: const TextStyle(color: AppColors.accentPink)),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: sheet,
                      builder: (d) => AlertDialog(
                        title: Text(t(language, 'Delete everything?', 'سب کچھ حذف کریں؟')),
                        content: Text(t(language, 'This removes your profile, results, logs and chat from this phone. It cannot be undone.',
                            'یہ آپ کی پروفائل، نتائج، اندراجات اور گفتگو اس فون سے ہٹا دے گا۔ اسے واپس نہیں لایا جا سکتا۔')),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(t(language, 'Cancel', 'منسوخ کریں'))),
                          TextButton(onPressed: () => Navigator.pop(d, true), child: Text(t(language, 'Delete', 'حذف کریں'))),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await store.clearAll();
                      await chat.clear();
                      if (sheet.mounted) Navigator.pop(sheet);
                    }
                  },
                ),
              ],
            ),
          ),
        );
        },
      ),
    );
  }

  // ------------------------------------------------------------------ conversation

  Widget _emptyState(HealthStore store) {
    final name = store.profile.firstName;
    final language = store.profile.language;
    final urdu = language == 'ur';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      children: [
        Text(
          name.isEmpty ? t(language, 'How are you feeling today?', 'آج آپ کیسا محسوس کر رہی ہیں؟') : t(language, 'How are you feeling today, $name?', 'آج آپ کیسا محسوس کر رہی ہیں، $name؟'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        const SizedBox(height: 5),
        Text(
          t(language, 'Tap how you feel, or just tell me. Nothing you ask is silly, and this stays between us.',
              'آپ جیسا محسوس کریں اس پر ٹیپ کریں، یا مجھے بتائیں۔ آپ کا کوئی بھی سوال بیوقوفانہ نہیں، اور یہ ہمارے درمیان رہے گا۔'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
        ),
        const SizedBox(height: 18),
        MoodGrid(urdu: urdu, onPick: _pickMood),
        const SizedBox(height: 22),
        GestureDetector(
          key: const Key('empty_report_reader'),
          onTap: _openReader,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(gradient: AppColors.buttonGradient, borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              const Icon(Icons.document_scanner_outlined, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(t(language, 'Have a lab or ultrasound report? Take a photo and I will explain it in Urdu or English.', 'لیب یا الٹراساؤنڈ رپورٹ ہے؟ تصویر لیں اور میں اسے اردو یا انگریزی میں سمجھاؤں گی۔'),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white, height: 1.35)),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ]),
          ),
        ),
        const SizedBox(height: 22),
        Text(t(language, 'Or ask me about', 'یا مجھ سے پوچھیں'), style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        const SizedBox(height: 4),
        Text(t(language, 'You can type, or tap the microphone and speak in Urdu or English.', 'آپ ٹائپ کر سکتی ہیں، یا مائیکروفون پر ٹیپ کر کے اردو یا انگریزی میں بول سکتی ہیں۔'),
            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textLight, height: 1.4)),
        const SizedBox(height: 10),
        for (final s in _suggestions(store))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              key: Key('suggestion_$s'),
              onTap: () => _send(s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF0B3C4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.primaryBerry),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(s,
                          textDirection: _isUrdu(s) ? TextDirection.rtl : TextDirection.ltr,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        _disclaimer(language),
      ],
    );
  }

  Widget _disclaimer(String language) => Text(
        t(language, 'Femora AI gives general information, not medical advice or a diagnosis. For anything that worries you, see a doctor.',
            'Femora AI عمومی معلومات دیتا ہے، طبی مشورہ یا تشخیص نہیں۔ جو بھی بات آپ کو پریشان کرے اس کے لیے ڈاکٹر سے ملیں۔'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: AppColors.textLight, height: 1.35),
      );

  Widget _typing() => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            _avatar(),
            const SizedBox(width: 10),
            Container(
              key: const Key('typing_indicator'),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(18), boxShadow: AppTheme.softShadow),
              child: const ThinkingOrbs(),
            ),
          ],
        ),
      );

  Widget _avatar() => GlowRing(
        size: 34,
        thickness: 1.8,
        child: Container(
          width: 27,
          height: 27,
          decoration: const BoxDecoration(color: Color(0xFFFFDFE8), shape: BoxShape.circle),
          child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryBerry, size: 15),
        ),
      );

  Widget _bubble(ChatMsg m, VoiceController voice, String language) {
    final dir = _isUrdu(m.text) ? TextDirection.rtl : TextDirection.ltr;
    if (m.isUser) {
      return SoftArrival(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFE3EC), Color(0xFFFFD2E1)],
                    ),
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(4)),
                  ),
                  child: Text(m.text,
                      textDirection: dir, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF3A1F2B), height: 1.4)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: Color(0xFFFF487E), shape: BoxShape.circle),
                child: const Icon(Icons.person, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      );
    }
    return SoftArrival(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(),
            const SizedBox(width: 10),
            Flexible(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4), topRight: Radius.circular(20), bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                  border: m.urgent ? Border.all(color: AppColors.accentPink, width: 1.5) : null,
                  boxShadow: AppTheme.softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (m.urgent)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.accentPink, size: 18),
                          const SizedBox(width: 6),
                          Text(t(language, 'Please get medical help', 'براہِ کرم طبی مدد حاصل کریں'),
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentPink)),
                        ]),
                      ),
                    ReplyText(m.text,
                        direction: dir, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF2C2538), height: 1.45)),
                    if (m.urgent) ...[
                      const SizedBox(height: 10),
                      NearbyCareButton(kind: CareKind.hospital, label: t(language, 'Nearest hospitals', 'قریب ترین ہسپتال')),
                    ],
                    if (m.sources.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        key: Key('sources_${m.id}'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(Icons.menu_book_rounded, size: 14, color: AppColors.textLight),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${t(language, 'Based on', 'ماخذ')}: ${m.sources.join(' · ')}',
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textLight, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (m.offline)
                          Expanded(
                              child: Text(t(language, 'Offline answer', 'آف لائن جواب'), style: const TextStyle(fontFamily: 'Inter', fontSize: 10.5, color: AppColors.textLight))),
                        IconButton(
                          key: Key('speak_${m.id}'),
                          visualDensity: VisualDensity.compact,
                          icon: Icon(voice.phase == VoicePhase.speaking ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
                              size: 20, color: AppColors.primaryBerry),
                          onPressed: () => voice.phase == VoicePhase.speaking ? voice.stopSpeaking() : voice.speak(plainForSpeech(m.text), language: 'auto'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBanner(String message, String language) => Container(
        key: const Key('chat_error'),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFFDEEF2), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.accentPink),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textDark))),
            TextButton(
              key: const Key('chat_retry'),
              onPressed: () {
                final q = context.read<ChatState>().takeLastUnanswered();
                if (q != null) _send(q);
              },
              child: Text(t(language, 'Try again', 'دوبارہ کوشش کریں'), style: const TextStyle(color: AppColors.primaryBerry, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

  Widget _voiceError(VoiceController voice) => Container(
        key: const Key('voice_error'),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFFDEEF2), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            const Icon(Icons.mic_off_rounded, size: 18, color: AppColors.accentPink),
            const SizedBox(width: 8),
            Expanded(child: Text(voice.error!, style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textDark))),
            IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.close_rounded, size: 18), onPressed: voice.clearError),
          ],
        ),
      );

  // ------------------------------------------------------------------ input

  Widget _inputBar(BuildContext context, VoiceController voice, ChatState chat) {
    final phase = voice.phase;
    final recording = phase == VoicePhase.recording;
    final busy = phase == VoicePhase.transcribing;
    final hint = recording
        ? 'Listening… tap the mic to send'
        : busy
            ? 'Understanding your voice…'
            : phase == VoicePhase.speaking
                ? 'Speaking… tap to stop'
                : 'Ask anything…';
    // The box shows what it is doing: colour rises from the bottom while she speaks, sweeps while the
    // answer is prepared, and a beam rides the border whenever the companion is busy with her.
    final working = recording || busy || chat.sending;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 96),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), boxShadow: AppTheme.softShadow),
      child: BorderBeam(
        radius: 30,
        active: working,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: recording ? const Color(0xFFFDEEF2) : AppColors.cardWhite),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Opacity(
                  opacity: 0.30,
                  child: VoiceGlow(height: 34, rising: recording, sweeping: busy || chat.sending),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
                child: Row(
                  children: [
                    GestureDetector(
                      key: const Key('mic_button'),
                      onTap: busy ? null : _toggleMic,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: recording ? AppColors.accentPink : const Color(0xFFFFDFE8), shape: BoxShape.circle),
                        child: busy
                            ? const Padding(
                                padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primaryBerry))
                            : Icon(
                                recording
                                    ? Icons.stop_rounded
                                    : phase == VoicePhase.speaking
                                        ? Icons.volume_off_rounded
                                        : Icons.mic_rounded,
                                color: recording ? Colors.white : AppColors.primaryBerry,
                                size: 24,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const Key('chat_input'),
                        controller: _controller,
                        enabled: !recording && !busy,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 1000,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (v) => _send(v),
                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                        decoration: InputDecoration(
                          hintText: hint,
                          hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF9E9CA8)),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    GestureDetector(
                      key: const Key('send_button'),
                      onTap: chat.sending ? null : () => _send(_controller.text),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: chat.sending ? const Color(0xFFD9C3CC) : AppColors.primaryBerry, shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 21),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
