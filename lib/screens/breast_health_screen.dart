import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/lang.dart';
import '../models/breast.dart';
import '../models/chat_state.dart';
import '../models/health_store.dart';
import '../models/insights.dart';
import '../models/models.dart';
import '../models/self_exam.dart';
import '../theme/app_theme.dart';
import '../widgets/circular_risk_widget.dart';
import '../widgets/femora_header.dart';
import '../widgets/guidance_card.dart';
import 'breast_risk_questionnaire_screen.dart';
import 'self_exam_guide_screen.dart';

/// Held-out test scans from the BrEaST-Lesions-USG dataset (CC BY 4.0), for demos.
const _sampleScans = [
  ('assets/images/breast_sample_benign.png', 'Sample scan: benign lesion'),
  ('assets/images/breast_sample_malignant.png', 'Sample scan: malignant lesion'),
];
const _sampleScanLabelsUr = {
  'assets/images/breast_sample_benign.png': 'نمونہ اسکین: benign رسولی',
  'assets/images/breast_sample_malignant.png': 'نمونہ اسکین: malignant رسولی',
};

/// The screen's own chrome (headers, buttons, dialogs, the self-exam card) is bilingual; the risk and scan
/// result cards' own text (labels, guidance, disclaimers) is still English-only pending a native speaker's
/// review of that clinical wording.
class BreastHealthScreen extends StatefulWidget {
  const BreastHealthScreen({super.key});

  @override
  State<BreastHealthScreen> createState() => _BreastHealthScreenState();
}

enum _ScanView { original, focus, outline }

class _BreastHealthScreenState extends State<BreastHealthScreen> {
  final _resultKey = GlobalKey();
  _ScanView _view = _ScanView.outline; // falls back to the heatmap, then the scan, when a view isn't available
  double? _scanDepthCm; // read by the user off the scan's ruler, to turn the outline's relative size into cm

  // ---------------------------------------------------------------- actions

  Future<void> _chooseScan() async {
    final language = context.read<HealthStore>().profile.language;
    final source = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFDED9E6), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t(language, 'Upload an Ultrasound Scan', 'الٹراساؤنڈ اسکین اپ لوڈ کریں'),
                style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              const SizedBox(height: 4),
              Text(
                t(language, 'Use the grayscale ultrasound image itself (PNG or JPG), cropped to the scan if possible.',
                    'گرے اسکیل الٹراساؤنڈ تصویر خود استعمال کریں (PNG یا JPG)، ممکن ہو تو اسکین تک کراپ کی ہوئی۔'),
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 10),
              _sheetOption(Icons.photo_library_outlined, t(language, 'Choose from Gallery', 'گیلری سے منتخب کریں'), ImageSource.gallery),
              if (!kIsWeb) _sheetOption(Icons.photo_camera_outlined, t(language, 'Take a Photo of the Scan', 'اسکین کی تصویر لیں'), ImageSource.camera),
              const Divider(height: 20),
              for (final (asset, label) in _sampleScans) _sheetOption(Icons.science_outlined, t(language, label, _sampleScanLabelsUr[asset] ?? label), asset),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;

    final Uint8List bytes;
    final String filename;
    if (source is String) {
      bytes = (await rootBundle.load(source)).buffer.asUint8List();
      filename = source.split('/').last;
    } else {
      final file = await ImagePicker().pickImage(source: source as ImageSource, maxWidth: 2048, imageQuality: 95);
      if (file == null) return;
      bytes = await file.readAsBytes();
      filename = file.name;
    }
    if (!mounted) return;

    final error = await context.read<BreastState>().analyzeScan(bytes, filename);
    if (!mounted) return;
    if (error != null) {
      _showSnack(error);
      return;
    }
    setState(() {
      _view = _ScanView.outline;
      _scanDepthCm = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _resultKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 400), alignment: 0.05);
      }
    });
  }

  Widget _sheetOption(IconData icon, String label, Object value) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(color: Color(0xFFFFDFE8), shape: BoxShape.circle),
          child: Icon(icon, color: AppColors.primaryBerry, size: 20),
        ),
        title: Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 14.5, fontWeight: FontWeight.w600)),
        onTap: () => Navigator.pop(context, value),
      );

  void _openQuestionnaire() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BreastRiskQuestionnaireScreen()),
      );

  void _openGuide() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SelfExamGuideScreen()),
      );

  /// Opens the AI companion and asks it about the result just shown (its context already includes that result).
  void _askAi(String question, String summary) {
    final chat = context.read<ChatState>();
    final store = context.read<HealthStore>();
    final lastExam = context.read<SelfExamState>().lastExam;
    context.read<AppState>().setTab(4); // AI companion tab
    chat.send(question, store: store, lastSelfExam: lastExam);
  }

  Future<void> _toggleReminder(bool on) async {
    final language = context.read<HealthStore>().profile.language;
    final error = await context.read<SelfExamState>().setReminder(on);
    if (!mounted) return;
    _showSnack(error ??
        t(language, on ? "Reminder set. We'll remind you once a month." : 'Monthly reminder turned off.',
            on ? 'یاد دہانی سیٹ ہو گئی۔ ہم آپ کو مہینے میں ایک بار یاد دلائیں گے۔' : 'ماہانہ یاد دہانی بند کر دی گئی۔'));
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  // ---------------------------------------------------------------- layout

  @override
  Widget build(BuildContext context) {
    final breast = context.watch<BreastState>();
    final language = context.watch<HealthStore>().profile.language;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FemoraHeader(showMenuIcon: true),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(language, 'AI Screening & Awareness', 'AI اسکریننگ اور آگاہی'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t(language, 'Empowering your health journey with advanced, compassionate AI analysis and guided self-care.',
                          'جدید اور ہمدرد AI تجزیے اور رہنمائی کے ساتھ آپ کے صحت کے سفر کو مضبوط بنانا۔'),
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, color: AppColors.textMuted, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _padded(_buildUploadCard(breast.isScanning, language)),
              const SizedBox(height: 18),
              _padded(breast.riskResult == null ? _buildRiskStartCard(language) : _buildRiskCard(breast.riskResult!, language)),
              const SizedBox(height: 18),
              if (breast.scanResult != null) ...[
                _padded(_buildScanResultCard(breast.scanResult!, breast.scanImage!, language), key: _resultKey),
                const SizedBox(height: 18),
              ],
              _padded(_buildSelfExamCard(language)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _padded(Widget child, {Key? key}) =>
      Padding(key: key, padding: const EdgeInsets.symmetric(horizontal: 20.0), child: child);

  BoxDecoration _card({Color? border}) => BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(24),
        border: border == null ? null : Border.all(color: border, width: 1.5),
        boxShadow: AppTheme.softShadow,
      );

  Widget _cardTitle(String text) => Text(
        text,
        style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
      );

  Widget _body(String text, {TextAlign align = TextAlign.start}) => Text(
        text,
        textAlign: align,
        style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textMuted, height: 1.4),
      );

  Widget _primaryButton(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primaryBerry,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: AppColors.primaryBerry.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      );

  Widget _outlineButton(String label, IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.primaryBerry, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primaryBerry, size: 17),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.primaryBerry),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _guidanceList(List<Guidance> guidance) => Column(
        children: [
          for (var i = 0; i < guidance.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            GuidanceCard(
              icon: guidanceIcon(guidance[i].key),
              title: guidance[i].title,
              description: guidance[i].description,
            ),
          ],
        ],
      );

  Widget _disclaimer(String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.textMuted, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Color(0xFF6E5970), height: 1.35),
            ),
          ),
        ],
      );

  // ---------------------------------------------------------------- Card 1: upload

  Widget _buildUploadCard(bool scanning, String language) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: _card(border: const Color(0xFFE8D7DF)),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: Color(0xFFFFDFE8), shape: BoxShape.circle),
            child: const Icon(Icons.cloud_upload_outlined, color: AppColors.primaryBerry, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            t(language, 'Upload Scan', 'اسکین اپ لوڈ کریں'),
            style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          _body(t(language, 'Upload Hospital Ultrasound Scan\n(PNG/JPG) for AI ResNet50 analysis', 'AI ResNet50 تجزیے کے لیے ہسپتال کا الٹراساؤنڈ اسکین\n(PNG/JPG) اپ لوڈ کریں'), align: TextAlign.center),
          const SizedBox(height: 18),
          if (scanning) ...[
            const CircularProgressIndicator(color: AppColors.primaryBerry),
            const SizedBox(height: 10),
            Text(
              t(language, 'ResNet50 Analyzing Ultrasound...', 'ResNet50 الٹراساؤنڈ کا تجزیہ کر رہا ہے...'),
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryBerry),
            ),
          ] else
            _primaryButton(t(language, 'Browse Files', 'فائلیں دیکھیں'), _chooseScan),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Card 2: risk profile

  Widget _buildRiskStartCard(String language) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: _card(),
      child: Column(
        children: [
          Row(children: [Expanded(child: _cardTitle(t(language, 'Risk Profile', 'رسک پروفائل'))), _riskInfoButton(language)]),
          const SizedBox(height: 16),
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: AppColors.purpleTagBg, shape: BoxShape.circle),
            child: const Icon(Icons.fact_check_outlined, color: AppColors.purpleTagText, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            t(language, 'No Scan? Check Your Risk', 'اسکین نہیں؟ اپنا رسک چیک کریں'),
            style: const TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          _body(
            t(language, 'Answer questions about your age, family history and symptoms. Our XGBoost model compares your risk with the average woman your age.',
                'اپنی عمر، خاندانی تاریخ اور علامات کے بارے میں سوالات کے جواب دیں۔ ہمارا XGBoost ماڈل آپ کے رسک کا موازنہ آپ کی عمر کی اوسط خاتون سے کرتا ہے۔'),
            align: TextAlign.center,
          ),
          const SizedBox(height: 18),
          _primaryButton(t(language, 'Start Questionnaire', 'سوالنامہ شروع کریں'), _openQuestionnaire),
        ],
      ),
    );
  }

  Widget _riskInfoButton(String language) => GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(t(language, 'How is this calculated?', 'یہ کیسے شمار کیا جاتا ہے؟'), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
            content: Text(
              t(language,
                  'An XGBoost model trained on screening records from the US Breast Cancer Surveillance Consortium estimates '
                  'your chance of a breast cancer diagnosis in the next year from your answers.\n\n'
                  'The number in the ring compares you with the average woman in your age group: 1.0× is average.\n'
                  '• Below 1.35×: low\n• 1.35× to 2.4×: moderate\n• 2.4× and above: high\n\n'
                  'Symptoms are checked separately, using the UK NICE guidelines for when to see a doctor.',
                  'ایک XGBoost ماڈل جو US Breast Cancer Surveillance Consortium کے اسکریننگ ریکارڈز پر تربیت یافتہ ہے، آپ کے جوابات سے اگلے سال میں بریسٹ کینسر کی تشخیص کا امکان بتاتا ہے۔\n\n'
                  'رنگ میں موجود نمبر آپ کا موازنہ آپ کی عمر کے گروپ کی اوسط خاتون سے کرتا ہے: 1.0× اوسط ہے۔\n'
                  '• 1.35× سے کم: کم\n• 1.35× سے 2.4×: درمیانہ\n• 2.4× اور اس سے زیادہ: زیادہ\n\n'
                  'علامات کو الگ سے، UK NICE رہنما اصولوں کے مطابق چیک کیا جاتا ہے کہ کب ڈاکٹر سے ملنا چاہیے۔'),
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, height: 1.45),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t(language, 'Got it', 'سمجھ گئی')))],
          ),
        ),
        child: const Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 20),
      );

  Widget _buildRiskCard(BreastRiskResult result, String language) {
    final (color, track) = switch (result.riskLevel) {
      RiskLevel.low => (AppColors.greenSuccess, const Color(0xFFE5F6EC)),
      RiskLevel.medium => (AppColors.orangeTagText, AppColors.orangeTagBg),
      RiskLevel.high => (AppColors.pinkTagText, AppColors.pinkTagBg),
    };
    String pct(double p) => '${(p * 100).toStringAsFixed(2)}%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _card(),
      child: Column(
        children: [
          Row(children: [Expanded(child: _cardTitle(t(language, 'Risk Profile', 'رسک پروفائل'))), _riskInfoButton(language)]),
          if (result.redFlags.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildRedFlagBanner(result, language),
          ],
          const SizedBox(height: 20),
          CircularRiskWidget(
            percentage: (result.relativeRisk / 3).clamp(0.02, 1.0),
            centerText: '${result.relativeRisk.toStringAsFixed(1)}×',
            riskLabel: result.riskLabel,
            color: color,
            trackColor: track,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFEBF1FA), borderRadius: BorderRadius.circular(14)),
            child: Text(
              t(language, 'Compared with the average woman aged ${result.ageGroup}', 'عمر ${result.ageGroup} کی اوسط خاتون کے مقابلے میں'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF4A5568)),
            ),
          ),
          const SizedBox(height: 12),
          _body(
            t(language, 'Estimated chance of a diagnosis in the next year: ${pct(result.probability)} (average ${pct(result.averageProbability)}).',
                'اگلے سال تشخیص کا تخمینی امکان: ${pct(result.probability)} (اوسط ${pct(result.averageProbability)})۔'),
            align: TextAlign.center,
          ),
          if (result.factors.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < result.factors.length; i++)
                  InfoTag(
                    label: result.factors[i].label,
                    bgColor: InfoTag.palette[i % InfoTag.palette.length].$1,
                    textColor: InfoTag.palette[i % InfoTag.palette.length].$2,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          _guidanceList(result.guidance),
          for (final note in result.notes) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.textLight, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(note, style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: AppColors.textMuted, height: 1.35)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _disclaimer(result.disclaimer),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _outlineButton(t(language, 'Ask Femora AI', 'Femora AI سے پوچھیں'), Icons.auto_awesome_rounded,
                    () => _askAi('Can you explain my breast cancer risk result?', result.summary)),
              ),
              const SizedBox(width: 10),
              Expanded(child: _outlineButton(t(language, 'Retake', 'دوبارہ کریں'), Icons.refresh_rounded, _openQuestionnaire)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRedFlagBanner(BreastRiskResult result, String language) {
    final urgent = result.needsUrgentVisit;
    final fg = urgent ? AppColors.pinkTagText : AppColors.orangeTagText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: urgent ? AppColors.pinkTagBg : AppColors.orangeTagBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(urgent ? Icons.error_outline_rounded : Icons.warning_amber_rounded, color: fg, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(language, urgent ? 'See a doctor within 2 weeks' : 'Book a check-up with your doctor', urgent ? '2 ہفتوں کے اندر ڈاکٹر سے ملیں' : 'اپنے ڈاکٹر کے ساتھ چیک اپ بک کریں'),
                  style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: fg),
                ),
                const SizedBox(height: 3),
                Text(
                  t(language, 'Because you reported: ${result.redFlags.map((f) => f.label.toLowerCase()).join(', ')}.',
                      'کیونکہ آپ نے یہ بتایا: ${result.redFlags.map((f) => f.label.toLowerCase()).join('، ')}۔'),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textDark, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Card 3: scan analysis

  Widget _buildScanResultCard(BreastScanResult result, Uint8List scan, String language) {
    final suspicious = result.prediction == ScanPrediction.malignant;
    final color = suspicious ? AppColors.pinkTagText : AppColors.greenSuccess;
    final heatmap = result.heatmap;
    final outline = result.outline;
    final view = switch (_view) {
      _ScanView.outline when outline != null => _ScanView.outline,
      _ScanView.original => _ScanView.original,
      _ when heatmap != null => _ScanView.focus,
      _ when outline != null => _ScanView.outline,
      _ => _ScanView.original,
    };
    final shown = switch (view) {
      _ScanView.outline => outline!.image,
      _ScanView.focus => heatmap!,
      _ScanView.original => scan,
    };
    final caption = switch (view) {
      _ScanView.outline => t(language, 'Pink line = the area the result is about', 'گلابی لکیر = وہ حصہ جس کے بارے میں نتیجہ ہے'),
      _ScanView.focus => t(language, 'Red = where the model looked most', 'سرخ = جہاں ماڈل نے سب سے زیادہ دیکھا'),
      _ScanView.original => t(language, 'Your scan as uploaded', 'آپ کا اسکین، جیسا اپ لوڈ کیا'),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _card(border: color.withValues(alpha: 0.35)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(suspicious ? Icons.error_outline_rounded : Icons.verified_rounded, color: color, size: 24),
              const SizedBox(width: 10),
              Expanded(child: _cardTitle(t(language, 'Analysis Complete', 'تجزیہ مکمل'))),
            ],
          ),
          const SizedBox(height: 14),

          // Scan preview, with the model's focus area when it found a lesion
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: Colors.black,
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 260),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Image.memory(shown, key: ValueKey(view), fit: BoxFit.contain, gaplessPlayback: true),
              ),
            ),
          ),
          if (heatmap != null || outline != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _viewToggle(t(language, 'Original', 'اصل'), view == _ScanView.original, () => setState(() => _view = _ScanView.original)),
                if (heatmap != null)
                  _viewToggle(t(language, 'AI Focus', 'AI فوکس'), view == _ScanView.focus, () => setState(() => _view = _ScanView.focus)),
                if (outline != null)
                  _viewToggle(t(language, 'Outline', 'خاکہ'), view == _ScanView.outline, () => setState(() => _view = _ScanView.outline)),
              ],
            ),
            const SizedBox(height: 6),
            Text(caption, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textLight)),
          ],
          if (outline != null) ...[
            const SizedBox(height: 12),
            _outlinePanel(outline, language),
          ],
          const SizedBox(height: 16),

          // Result box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: suspicious ? AppColors.pinkTagBg : const Color(0xFFEFF4FC),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        result.title,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                    Text(
                      t(language, suspicious ? '${result.percent}% Malignancy Score' : '${result.percent}% Confidence', suspicious ? '${result.percent}% میلیگننسی سکور' : '${result.percent}% اعتماد'),
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: result.confidence,
                    minHeight: 7,
                    backgroundColor: suspicious ? Colors.white : const Color(0xFFD6E3F7),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final p in result.probabilities) _probabilityRow(p),
          const SizedBox(height: 10),
          Text(
            t(language, 'What this means', 'اس کا مطلب'),
            style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          Text(result.summary, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF4A5568), height: 1.45)),
          const SizedBox(height: 14),
          _guidanceList(result.guidance),
          const SizedBox(height: 16),
          _disclaimer(result.disclaimer),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _outlineButton(t(language, 'Ask Femora AI', 'Femora AI سے پوچھیں'), Icons.auto_awesome_rounded,
                    () => _askAi('Can you explain my breast ultrasound result?', result.summary)),
              ),
              const SizedBox(width: 10),
              Expanded(child: _outlineButton(t(language, 'New Scan', 'نیا اسکین'), Icons.add_photo_alternate_outlined, _chooseScan)),
            ],
          ),
        ],
      ),
    );
  }

  /// Shape and approximate size of the outlined area. Size needs the scan's depth, which only the scan's ruler shows.
  Widget _outlinePanel(LesionOutline outline, String language) {
    final depth = _scanDepthCm;
    final size = depth == null ? null : outline.sizeCm(depth);
    final shape = outline.tallerThanWide
        ? t(language, 'Taller than wide', 'چوڑائی سے زیادہ اونچا')
        : t(language, 'Wider than tall', 'اونچائی سے زیادہ چوڑا');
    final covers = '${(outline.areaShare * 100).clamp(1, 100).round()}%';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFDF1F8), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gesture_rounded, size: 18, color: Color(0xFFD4147A)),
              const SizedBox(width: 8),
              Text(t(language, 'Outlined area', 'خاکہ شدہ حصہ'),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 10),
          _outlineFact(t(language, 'Shape', 'شکل'), shape),
          _outlineFact(t(language, 'Covers', 'حصہ'), t(language, '$covers of the scan', 'اسکین کا $covers')),
          _outlineFact(
            t(language, 'Approx. size', 'اندازاً سائز'),
            size == null
                ? t(language, 'Add the scan depth to estimate', 'اندازے کے لیے اسکین کی گہرائی درج کریں')
                : '${size.$1.toStringAsFixed(1)} × ${size.$2.toStringAsFixed(1)} cm',
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: const Color(0xFFD4147A)),
            onPressed: () => _askScanDepth(language),
            icon: const Icon(Icons.straighten_rounded, size: 18),
            label: Text(depth == null
                ? t(language, 'Estimate size in cm', 'سائز سینٹی میٹر میں معلوم کریں')
                : t(language, 'Change scan depth (${depth.toStringAsFixed(1)} cm)', 'اسکین کی گہرائی بدلیں (${depth.toStringAsFixed(1)} cm)')),
          ),
          Text(outline.note, style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: AppColors.textMuted, height: 1.4)),
        ],
      ),
    );
  }

  Widget _outlineFact(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textMuted)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            ),
          ],
        ),
      );

  Future<void> _askScanDepth(String language) async {
    final value = await showDialog<double>(
      context: context,
      builder: (context) => _ScanDepthDialog(language: language, initial: _scanDepthCm),
    );
    if (value != null && mounted) setState(() => _scanDepthCm = value);
  }

  Widget _viewToggle(String label, bool selected, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryBerry : AppColors.lightGrayBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textDark,
            ),
          ),
        ),
      );

  Widget _probabilityRow(ScanProbability p) {
    final color = switch (p.key) {
      ScanPrediction.normal => AppColors.blueTagText,
      ScanPrediction.benign => AppColors.greenSuccess,
      ScanPrediction.malignant => AppColors.pinkTagText,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(p.label, style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textDark)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: p.probability,
                minHeight: 6,
                backgroundColor: AppColors.lightGrayBg,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${(p.probability * 100).round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Card 4: self-exam

  Widget _buildSelfExamCard(String language) {
    final exam = context.watch<SelfExamState>();
    final due = exam.daysUntilDue(DateTime.now());
    final String status;
    if (exam.lastExam == null) {
      status = t(language, 'No self-exam logged yet', 'ابھی تک کوئی سیلف ایگزام درج نہیں ہوا');
    } else {
      final last = DateFormat('d MMM').format(exam.lastExam!);
      status = due! > 0
          ? t(language, 'Last: $last  •  Next due in $due ${due == 1 ? 'day' : 'days'}', 'آخری: $last  •  اگلا $due دن میں')
          : t(language, 'Last: $last  •  Due now', 'آخری: $last  •  اب واجب ہے');
    }
    final overdue = exam.lastExam != null && due! <= 0;

    return Container(
      width: double.infinity,
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Image.asset('assets/images/self_exam_guide.png', width: double.infinity, height: 160, fit: BoxFit.cover),
              ),
              Positioned(
                left: 14,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        t(language, '3 Min Guide', '3 منٹ کی رہنمائی'),
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(language, 'Self-Exam Guide', 'سیلف ایگزام گائیڈ'),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                const SizedBox(height: 6),
                _body(t(language, 'Learn the proper technique for monthly self-examinations with our illustrated step-by-step tutorial.',
                    'ہماری مصور مرحلہ وار گائیڈ کے ساتھ ماہانہ سیلف ایگزام کا درست طریقہ سیکھیں۔')),
                const SizedBox(height: 14),

                // Log status + monthly reminder
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                  decoration: BoxDecoration(color: AppColors.lightGrayBg, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event_available_outlined,
                              size: 18, color: overdue ? AppColors.orangeTagText : AppColors.primaryBerry),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              status,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: overdue ? AppColors.orangeTagText : AppColors.textDark,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await context.read<SelfExamState>().logExam();
                              if (mounted) _showSnack(t(language, 'Self-exam logged for today.', 'آج کے لیے سیلف ایگزام درج ہو گیا۔'));
                            },
                            child: Text(t(language, 'Log today', 'آج درج کریں'), style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.notifications_none_rounded, size: 18, color: AppColors.primaryBerry),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t(language, 'Monthly reminder', 'ماہانہ یاد دہانی'),
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
                            ),
                          ),
                          Switch(
                            value: exam.reminderOn,
                            activeTrackColor: AppColors.primaryBerry,
                            onChanged: _toggleReminder,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _openGuide,
                  child: Container(
                    width: double.infinity,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(23),
                      border: Border.all(color: AppColors.primaryBerry, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          t(language, 'Start Tutorial', 'ٹیوٹوریل شروع کریں'),
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryBerry),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, color: AppColors.primaryBerry, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks for the depth the scan's ruler shows, to turn the outline's relative size into centimetres.
class _ScanDepthDialog extends StatefulWidget {
  final String language;
  final double? initial;

  const _ScanDepthDialog({required this.language, this.initial});

  @override
  State<_ScanDepthDialog> createState() => _ScanDepthDialogState();
}

class _ScanDepthDialogState extends State<_ScanDepthDialog> {
  late final _controller = TextEditingController(text: widget.initial?.toStringAsFixed(1) ?? '');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final v = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    if (v == null || v < 1 || v > 15) {
      setState(() => _error = t(widget.language, 'Enter a depth between 1 and 15 cm', '1 سے 15 سینٹی میٹر کے درمیان گہرائی درج کریں'));
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return AlertDialog(
      title: Text(t(language, 'Scan depth', 'اسکین کی گہرائی')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(language,
                'Ultrasound images show a centimetre ruler along one side, and the depth is often printed on the screen '
                    '(for example "4.0 cm"). Enter the depth shown from the top to the bottom of the image.',
                'الٹراساؤنڈ تصویر کے ایک طرف سینٹی میٹر کا پیمانہ ہوتا ہے، اور گہرائی اکثر اسکرین پر لکھی ہوتی ہے '
                    '(مثلاً "4.0 cm")۔ تصویر کے اوپر سے نیچے تک کی گہرائی درج کریں۔'),
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(suffixText: 'cm', hintText: '4.0', errorText: _error),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t(language, 'Cancel', 'منسوخ'))),
        FilledButton(onPressed: _submit, child: Text(t(language, 'Estimate', 'اندازہ لگائیں'))),
      ],
    );
  }
}
