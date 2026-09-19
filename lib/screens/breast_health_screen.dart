import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/breast.dart';
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

class BreastHealthScreen extends StatefulWidget {
  const BreastHealthScreen({super.key});

  @override
  State<BreastHealthScreen> createState() => _BreastHealthScreenState();
}

class _BreastHealthScreenState extends State<BreastHealthScreen> {
  final _resultKey = GlobalKey();
  bool _showHeatmap = true;

  // ---------------------------------------------------------------- actions

  Future<void> _chooseScan() async {
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
              const Text(
                'Upload an Ultrasound Scan',
                style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              const SizedBox(height: 4),
              const Text(
                'Use the grayscale ultrasound image itself (PNG or JPG), cropped to the scan if possible.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 10),
              _sheetOption(Icons.photo_library_outlined, 'Choose from Gallery', ImageSource.gallery),
              if (!kIsWeb) _sheetOption(Icons.photo_camera_outlined, 'Take a Photo of the Scan', ImageSource.camera),
              const Divider(height: 20),
              for (final (asset, label) in _sampleScans) _sheetOption(Icons.science_outlined, label, asset),
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
    setState(() => _showHeatmap = true);
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

  void _askAi(String question, String summary) {
    context.read<AppState>().discussResult(
          question: question,
          answer: '$summary\n\nYou can ask me what these results mean, what happens at a follow-up appointment, '
              'or how to do a self-exam.',
        );
  }

  Future<void> _toggleReminder(bool on) async {
    final error = await context.read<SelfExamState>().setReminder(on);
    if (!mounted) return;
    _showSnack(error ?? (on ? "Reminder set. We'll remind you once a month." : 'Monthly reminder turned off.'));
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Screening & Awareness',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Empowering your health journey with advanced, compassionate AI analysis and guided self-care.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13.5, color: AppColors.textMuted, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _padded(_buildUploadCard(breast.isScanning)),
              const SizedBox(height: 18),
              _padded(breast.riskResult == null ? _buildRiskStartCard() : _buildRiskCard(breast.riskResult!)),
              const SizedBox(height: 18),
              if (breast.scanResult != null) ...[
                _padded(_buildScanResultCard(breast.scanResult!, breast.scanImage!), key: _resultKey),
                const SizedBox(height: 18),
              ],
              _padded(_buildSelfExamCard()),
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

  Widget _buildUploadCard(bool scanning) {
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
          const Text(
            'Upload Scan',
            style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          _body('Upload Hospital Ultrasound Scan\n(PNG/JPG) for AI ResNet50 analysis', align: TextAlign.center),
          const SizedBox(height: 18),
          if (scanning) ...[
            const CircularProgressIndicator(color: AppColors.primaryBerry),
            const SizedBox(height: 10),
            const Text(
              'ResNet50 Analyzing Ultrasound...',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryBerry),
            ),
          ] else
            _primaryButton('Browse Files', _chooseScan),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Card 2: risk profile

  Widget _buildRiskStartCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: _card(),
      child: Column(
        children: [
          Row(children: [Expanded(child: _cardTitle('Risk Profile')), _riskInfoButton()]),
          const SizedBox(height: 16),
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: AppColors.purpleTagBg, shape: BoxShape.circle),
            child: const Icon(Icons.fact_check_outlined, color: AppColors.purpleTagText, size: 30),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Scan? Check Your Risk',
            style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          _body(
            'Answer questions about your age, family history and symptoms. Our XGBoost model compares your risk '
            'with the average woman your age.',
            align: TextAlign.center,
          ),
          const SizedBox(height: 18),
          _primaryButton('Start Questionnaire', _openQuestionnaire),
        ],
      ),
    );
  }

  Widget _riskInfoButton() => GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('How is this calculated?', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
            content: const Text(
              'An XGBoost model trained on screening records from the US Breast Cancer Surveillance Consortium estimates '
              'your chance of a breast cancer diagnosis in the next year from your answers.\n\n'
              'The number in the ring compares you with the average woman in your age group: 1.0× is average.\n'
              '• Below 1.35×: low\n• 1.35× to 2.4×: moderate\n• 2.4× and above: high\n\n'
              'Symptoms are checked separately, using the UK NICE guidelines for when to see a doctor.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13.5, height: 1.45),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
          ),
        ),
        child: const Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 20),
      );

  Widget _buildRiskCard(BreastRiskResult result) {
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
          Row(children: [Expanded(child: _cardTitle('Risk Profile')), _riskInfoButton()]),
          if (result.redFlags.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildRedFlagBanner(result),
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
              'Compared with the average woman aged ${result.ageGroup}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF4A5568)),
            ),
          ),
          const SizedBox(height: 12),
          _body(
            'Estimated chance of a diagnosis in the next year: ${pct(result.probability)} '
            '(average ${pct(result.averageProbability)}).',
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
                child: _outlineButton('Ask Femora AI', Icons.auto_awesome_rounded,
                    () => _askAi('Can you explain my breast cancer risk result?', result.summary)),
              ),
              const SizedBox(width: 10),
              Expanded(child: _outlineButton('Retake', Icons.refresh_rounded, _openQuestionnaire)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRedFlagBanner(BreastRiskResult result) {
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
                  urgent ? 'See a doctor within 2 weeks' : 'Book a check-up with your doctor',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: fg),
                ),
                const SizedBox(height: 3),
                Text(
                  'Because you reported: ${result.redFlags.map((f) => f.label.toLowerCase()).join(', ')}.',
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

  Widget _buildScanResultCard(BreastScanResult result, Uint8List scan) {
    final suspicious = result.prediction == ScanPrediction.malignant;
    final color = suspicious ? AppColors.pinkTagText : AppColors.greenSuccess;
    final heatmap = result.heatmap;

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
              Expanded(child: _cardTitle('Analysis Complete')),
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
              child: Image.memory(heatmap != null && _showHeatmap ? heatmap : scan, fit: BoxFit.contain, gaplessPlayback: true),
            ),
          ),
          if (heatmap != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _viewToggle('Original', !_showHeatmap, () => setState(() => _showHeatmap = false)),
                const SizedBox(width: 8),
                _viewToggle('AI Focus', _showHeatmap, () => setState(() => _showHeatmap = true)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Red = where the model looked most',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textLight),
                  ),
                ),
              ],
            ),
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
                      suspicious ? '${result.percent}% Malignancy Score' : '${result.percent}% Confidence',
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
          const Text(
            'What this means',
            style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
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
                child: _outlineButton('Ask Femora AI', Icons.auto_awesome_rounded,
                    () => _askAi('Can you explain my breast ultrasound result?', result.summary)),
              ),
              const SizedBox(width: 10),
              Expanded(child: _outlineButton('New Scan', Icons.add_photo_alternate_outlined, _chooseScan)),
            ],
          ),
        ],
      ),
    );
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

  Widget _buildSelfExamCard() {
    final exam = context.watch<SelfExamState>();
    final due = exam.daysUntilDue(DateTime.now());
    final String status;
    if (exam.lastExam == null) {
      status = 'No self-exam logged yet';
    } else {
      final last = DateFormat('d MMM').format(exam.lastExam!);
      status = due! > 0 ? 'Last: $last  •  Next due in $due ${due == 1 ? 'day' : 'days'}' : 'Last: $last  •  Due now';
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 5),
                      Text(
                        '3 Min Guide',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
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
                const Text(
                  'Self-Exam Guide',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                const SizedBox(height: 6),
                _body('Learn the proper technique for monthly self-examinations with our illustrated step-by-step tutorial.'),
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
                              if (mounted) _showSnack('Self-exam logged for today.');
                            },
                            child: const Text('Log today', style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.notifications_none_rounded, size: 18, color: AppColors.primaryBerry),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Monthly reminder',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
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
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Start Tutorial',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryBerry),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, color: AppColors.primaryBerry, size: 16),
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
