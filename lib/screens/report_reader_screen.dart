import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../models/health_store.dart';
import '../models/report_reader.dart';
import '../services/api_service.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';

/// Gets photos of a report: from the camera (one page) or the gallery (up to [ReportReaderScreen.maxPages]).
typedef ReportPhotoPicker = Future<List<Uint8List>> Function(bool camera);

Future<List<Uint8List>> _pickWithDevice(bool camera) async {
  final picker = ImagePicker();
  if (camera) {
    final f = await picker.pickImage(source: ImageSource.camera, maxWidth: 2400, imageQuality: 90);
    return f == null ? [] : [await f.readAsBytes()];
  }
  final files = await picker.pickMultiImage(maxWidth: 2400, imageQuality: 90, limit: ReportReaderScreen.maxPages);
  return [for (final f in files.take(ReportReaderScreen.maxPages)) await f.readAsBytes()];
}

final _urduChars = RegExp(r'[؀-ۿ]');
TextDirection _dir(String text) => _urduChars.hasMatch(text) ? TextDirection.rtl : TextDirection.ltr;

TextStyle _s(double size, {FontWeight w = FontWeight.w400, Color c = AppColors.textDark, double? h}) => TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: w, color: c, height: h);

/// Photograph a lab or ultrasound report and get it explained in plain Urdu or English.
/// Pops with a question for the companion when she taps "Ask Femora about this".
class ReportReaderScreen extends StatelessWidget {
  static const maxPages = 3;
  final ApiService? api; // tests pass their own
  final ReportPhotoPicker? picker;

  const ReportReaderScreen({super.key, this.api, this.picker});

  @override
  Widget build(BuildContext context) {
    final store = context.read<HealthStore>();
    return ChangeNotifierProvider(
      create: (_) => ReportReaderState(api: api, onReport: store.recordReport),
      child: _Body(picker: picker ?? _pickWithDevice),
    );
  }
}

class _Body extends StatefulWidget {
  final ReportPhotoPicker picker;
  const _Body({required this.picker});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  final List<Uint8List> _pages = [];

  Future<void> _pick(bool camera) async {
    final got = await widget.picker(camera);
    if (got.isEmpty || !mounted) return;
    setState(() {
      _pages.addAll(got);
      if (_pages.length > ReportReaderScreen.maxPages) _pages.removeRange(ReportReaderScreen.maxPages, _pages.length);
    });
  }

  Future<bool> _consent(HealthStore store) async {
    if (store.profile.reportReaderConsent) return true;
    final language = store.profile.language;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        key: const Key('reader_consent'),
        title: Text(t(language, 'Before you send a photo', 'تصویر بھیجنے سے پہلے')),
        content: Text(
          t(language,
              'To read the report, the photo is sent through the Femora server to Google\'s Gemini AI. Femora does not keep the photo, and only the explanation is saved on this phone.\n\n'
              'Google may keep what it receives for a while, and on its free service it may use it to improve its products. '
              'Hide or cover your name, ID number, phone number and address before you take the photo, and do not send anything you are not comfortable sharing.',
              'رپورٹ پڑھنے کے لیے، تصویر Femora سرور کے ذریعے Google کے Gemini AI کو بھیجی جاتی ہے۔ Femora تصویر محفوظ نہیں رکھتا، اور صرف وضاحت اس فون پر محفوظ ہوتی ہے۔\n\n'
              'Google اسے کچھ عرصے کے لیے رکھ سکتا ہے، اور اپنی مفت سروس پر یہ اسے اپنی مصنوعات بہتر بنانے کے لیے استعمال کر سکتا ہے۔ '
              'تصویر لینے سے پہلے اپنا نام، شناختی نمبر، فون نمبر اور پتہ چھپا دیں یا ڈھانپ دیں، اور ایسی کوئی چیز نہ بھیجیں جو آپ شیئر کرنے میں آرام دہ نہیں ہیں۔'),
        ),
        actions: [
          TextButton(key: const Key('consent_no'), onPressed: () => Navigator.pop(d, false), child: Text(t(language, 'Not now', 'ابھی نہیں'))),
          TextButton(key: const Key('consent_agree'), onPressed: () => Navigator.pop(d, true), child: Text(t(language, 'I understand, continue', 'میں سمجھ گئی، جاری رکھیں'))),
        ],
      ),
    );
    if (ok != true) return false;
    await store.setReportReaderConsent(true);
    return true;
  }

  Future<void> _explain() async {
    final store = context.read<HealthStore>();
    final state = context.read<ReportReaderState>();
    if (!await _consent(store) || !mounted) return;
    final ok = await state.explain(List.of(_pages), language: store.profile.language, now: store.now);
    if (ok && mounted) setState(_pages.clear); // the photos are dropped as soon as they were read
  }

  void _startOver() {
    context.read<ReportReaderState>().reset();
    setState(_pages.clear);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<ReportReaderState>();
    final r = st.current;
    final language = context.watch<HealthStore>().profile.language;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        leading: IconButton(key: const Key('reader_back'), icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.maybePop(context)),
        title: Text(t(language, 'Explain my report', 'میری رپورٹ سمجھائیں'), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: st.busy
            ? _working(language)
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
                children: [
                  if (st.error != null) _errorBox(st.error!),
                  if (r != null) ..._result(r) else ..._start(st, language),
                ],
              ),
      ),
    );
  }

  Widget _working(String language) => Center(
        key: const Key('reader_working'),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: AppColors.primaryBerry),
            const SizedBox(height: 18),
            Text(t(language, 'Reading your report…', 'آپ کی رپورٹ پڑھی جا رہی ہے…'), style: _s(16, w: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(t(language, 'This can take up to a minute. Please keep the app open.', 'اس میں ایک منٹ تک لگ سکتا ہے۔ براہِ کرم ایپ کھلی رکھیں۔'), textAlign: TextAlign.center, style: _s(12.5, c: AppColors.textMuted, h: 1.4)),
          ]),
        ),
      );

  Widget _errorBox(String message) => Container(
        key: const Key('reader_error'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFDEEF2), borderRadius: BorderRadius.circular(16)),
        child: Text(message, style: _s(13, c: const Color(0xFF7A2E3E), h: 1.4)),
      );

  // ------------------------------------------------------------------ before reading

  List<Widget> _start(ReportReaderState st, String language) {
    final store = context.watch<HealthStore>();
    return [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(24), boxShadow: AppTheme.softShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.document_scanner_outlined, color: AppColors.primaryBerry),
            const SizedBox(width: 8),
            Expanded(child: Text(t(language, 'Understand a medical report', 'میڈیکل رپورٹ سمجھیں'), style: _s(17, w: FontWeight.w700))),
          ]),
          const SizedBox(height: 8),
          Text(
            t(language, 'Take a clear photo of a blood test, hormone test, ultrasound report or prescription. I will explain it in ${language == 'ur' ? 'Urdu' : 'simple English'} and suggest questions for your doctor.',
                'خون کے ٹیسٹ، ہارمون ٹیسٹ، الٹراساؤنڈ رپورٹ یا نسخے کی واضح تصویر لیں۔ میں اسے اردو میں سمجھاؤں گی اور آپ کے ڈاکٹر کے لیے سوالات تجویز کروں گی۔'),
            style: _s(13, c: AppColors.textMuted, h: 1.45),
          ),
          const SizedBox(height: 10),
          Text(t(language, 'Tip: lay the page flat in good light, and cover your name and ID number first.', 'تجویز: صفحے کو اچھی روشنی میں سیدھا رکھیں، اور پہلے اپنا نام اور شناختی نمبر چھپائیں۔'), style: _s(12, c: AppColors.textLight, h: 1.4)),
          const SizedBox(height: 14),
          if (_pages.isEmpty)
            Row(children: [
              if (!kIsWeb) Expanded(child: _pickButton('reader_camera', Icons.photo_camera_outlined, t(language, 'Take a photo', 'تصویر لیں'), () => _pick(true))),
              if (!kIsWeb) const SizedBox(width: 10),
              Expanded(child: _pickButton('reader_gallery', Icons.photo_library_outlined, t(language, 'Choose photos', 'تصاویر منتخب کریں'), () => _pick(false))),
            ])
          else ...[
            SizedBox(
              height: 110,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (var i = 0; i < _pages.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Stack(children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(_pages[i],
                              key: Key('reader_page_$i'), width: 84, height: 110, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 84, height: 110, color: AppColors.lightGrayBg))),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          key: Key('reader_remove_$i'),
                          onTap: () => setState(() => _pages.removeAt(i)),
                          child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close_rounded, size: 14, color: Colors.white)),
                        ),
                      ),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 6),
            Text(t(language, '${_pages.length} page${_pages.length == 1 ? '' : 's'} ready (up to ${ReportReaderScreen.maxPages})', '${_pages.length} صفح(ات) تیار (${ReportReaderScreen.maxPages} تک)'),
                key: const Key('reader_count'), style: _s(12, c: AppColors.textMuted)),
            const SizedBox(height: 10),
            if (_pages.length < ReportReaderScreen.maxPages)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _pickButton('reader_add', Icons.add_photo_alternate_outlined, t(language, 'Add another page', 'مزید صفحہ شامل کریں'), () => _pick(!kIsWeb)),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('reader_explain'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBerry,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                onPressed: _explain,
                child: Text(t(language, 'Explain this report', 'یہ رپورٹ سمجھائیں'), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ]),
      ),
      if (store.reports.isNotEmpty) ...[
        const SizedBox(height: 22),
        Text(t(language, 'Reports I explained before', 'پہلے سمجھائی گئی رپورٹس'), style: _s(14, w: FontWeight.w700)),
        const SizedBox(height: 8),
        for (var i = 0; i < store.reports.length; i++) _pastTile(i, store.reports[i], store, language),
      ],
      const SizedBox(height: 16),
      Text(t(language, 'Femora is not a laboratory or a doctor. It can misread a photo, so always check the values against your report.',
          'Femora کوئی لیبارٹری یا ڈاکٹر نہیں ہے۔ یہ تصویر غلط پڑھ سکتا ہے، اس لیے ہمیشہ اپنی رپورٹ سے اقدار کی تصدیق کریں۔'), style: _s(11.5, c: AppColors.textLight, h: 1.4)),
    ];
  }

  Widget _pickButton(String key, IconData icon, String label, VoidCallback onTap) => OutlinedButton.icon(
        key: Key(key),
        style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryBerry,
            side: const BorderSide(color: AppColors.primaryBerry),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        label: Text(label),
      );

  Widget _pastTile(int i, ExplainedReport r, HealthStore store, String language) => Container(
        key: Key('reader_past_$i'),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceBorder)),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            onTap: () => context.read<ReportReaderState>().show(r),
            leading: Icon(r.urgency == 'urgent' ? Icons.priority_high_rounded : Icons.description_outlined, color: r.urgency == 'urgent' ? const Color(0xFFC62828) : AppColors.primaryBerry),
            title: Text(r.titleIn(language), style: _s(14, w: FontWeight.w600)),
            subtitle: Text(
                t(language, '${HealthStore.ago(r.date, store.now())} · ${r.outOfRange.length} outside range', '${HealthStore.ago(r.date, store.now(), language: 'ur')} · ${r.outOfRange.length} حد سے باہر'),
                style: _s(12, c: AppColors.textMuted)),
            trailing: IconButton(key: Key('reader_delete_$i'), icon: const Icon(Icons.delete_outline_rounded, size: 20), onPressed: () => store.removeReport(r)),
          ),
        ),
      );

  // ------------------------------------------------------------------ the explanation

  static const _statusColors = {
    'normal': Color(0xFF2E9E68),
    'low': Color(0xFFE08A1E),
    'high': Color(0xFFE08A1E),
    'abnormal': Color(0xFFE08A1E),
    'critical': Color(0xFFC62828),
    'unknown': AppColors.textMuted,
  };

  List<Widget> _result(ExplainedReport r) {
    final voice = context.read<VoiceController>();
    final language = r.language; // the report's own language, so its chrome always matches its content
    return [
      if (r.urgency != 'none') _urgencyBanner(r.urgency, language),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(24), boxShadow: AppTheme.softShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(r.titleIn(language), key: const Key('reader_kind'), style: _s(18, w: FontWeight.w700))),
            if (r.readable)
              IconButton(
                key: const Key('reader_speak'),
                tooltip: t(language, 'Read aloud', 'بلند آواز سے پڑھیں'),
                icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryBerry),
                onPressed: () => voice.speak(r.summary, language: r.language),
              ),
          ]),
          const SizedBox(height: 4),
          Directionality(
            textDirection: _dir(r.summary),
            child: Text(r.summary, key: const Key('reader_summary'), style: _s(14, h: 1.55)),
          ),
        ]),
      ),
      if (r.findings.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text(r.kind == 'prescription' ? t(language, 'Medicines on the prescription', 'نسخے پر موجود دوائیں') : t(language, 'What the report shows', 'رپورٹ کیا ظاہر کرتی ہے'), style: _s(15, w: FontWeight.w700)),
        const SizedBox(height: 8),
        for (var i = 0; i < r.findings.length; i++) _findingTile(i, r.findings[i], r.kind == 'prescription', language),
      ],
      if (r.questions.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text(t(language, 'Questions to ask your doctor', 'ڈاکٹر سے پوچھنے کے سوالات'), style: _s(15, w: FontWeight.w700)),
        const SizedBox(height: 6),
        for (final q in r.questions)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Directionality(
              textDirection: _dir(q),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.help_outline_rounded, size: 17, color: AppColors.primaryBerry)),
                const SizedBox(width: 8),
                Expanded(child: Text(q, style: _s(13.5, h: 1.45))),
              ]),
            ),
          ),
      ],
      const SizedBox(height: 16),
      Directionality(textDirection: _dir(r.disclaimer), child: Text(r.disclaimer, key: const Key('reader_disclaimer'), style: _s(11.5, c: AppColors.textLight, h: 1.45))),
      const SizedBox(height: 16),
      if (r.readable)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const Key('reader_ask'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBerry,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            onPressed: () => Navigator.pop(
                context,
                t(language, 'Please explain my ${r.title.toLowerCase()} in simple words, and tell me what I should ask my doctor.',
                    'براہِ کرم میری ${r.titleIn(language)} آسان الفاظ میں سمجھائیں، اور بتائیں کہ مجھے اپنے ڈاکٹر سے کیا پوچھنا چاہیے۔')),
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(t(language, 'Ask Femora about this', 'اس بارے میں Femora سے پوچھیں'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          key: const Key('reader_again'),
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryBerry,
              side: const BorderSide(color: AppColors.primaryBerry),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
          onPressed: _startOver,
          child: Text(t(language, 'Read another report', 'دوسری رپورٹ پڑھیں')),
        ),
      ),
    ];
  }

  Widget _urgencyBanner(String urgency, String language) {
    final urgent = urgency == 'urgent';
    final color = urgent ? const Color(0xFFC62828) : const Color(0xFFE08A1E);
    return Container(
      key: Key('reader_$urgency'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(urgent ? Icons.warning_amber_rounded : Icons.info_outline_rounded, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            t(
                language,
                urgent
                    ? 'This report has a value that may need a doctor today. Please contact your doctor or go to a hospital, and do not wait for the app.'
                    : 'Some values are outside their range. Please book a visit with your doctor soon to talk about them.',
                urgent
                    ? 'اس رپورٹ میں ایک قدر ایسی ہے جس کے لیے آج ہی ڈاکٹر کی ضرورت ہو سکتی ہے۔ براہِ کرم اپنے ڈاکٹر سے رابطہ کریں یا ہسپتال جائیں، اور ایپ کا انتظار نہ کریں۔'
                    : 'کچھ اقدار اپنی حد سے باہر ہیں۔ براہِ کرم جلد اپنے ڈاکٹر سے ملاقات کریں اور ان کے بارے میں بات کریں۔'),
            style: _s(13, w: FontWeight.w600, c: color, h: 1.45),
          ),
        ),
      ]),
    );
  }

  Widget _findingTile(int i, ReportFinding f, bool prescription, String language) {
    final color = _statusColors[f.status] ?? AppColors.textMuted;
    final measured = [f.value, f.unit].where((t) => t.isNotEmpty).join(' ');
    return Container(
      key: Key('finding_$i'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: f.outOfRange ? color.withValues(alpha: 0.5) : AppColors.surfaceBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(f.name, style: _s(14, w: FontWeight.w700))),
          if (!prescription)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Text(f.statusIn(language), key: Key('finding_status_$i'), style: _s(11.5, w: FontWeight.w700, c: color)),
            ),
        ]),
        if (measured.isNotEmpty || (f.reference.isNotEmpty && !prescription)) ...[
          const SizedBox(height: 3),
          Text(
            [if (measured.isNotEmpty) measured, if (f.reference.isNotEmpty && !prescription) t(language, 'printed range ${f.reference}', 'رینج ${f.reference}')].join('  ·  '),
            style: _s(12.5, w: FontWeight.w600, c: AppColors.textMuted),
          ),
        ],
        if (f.explanation.isNotEmpty) ...[
          const SizedBox(height: 5),
          Directionality(textDirection: _dir(f.explanation), child: Text(f.explanation, style: _s(12.5, h: 1.45))),
        ],
      ]),
    );
  }
}
