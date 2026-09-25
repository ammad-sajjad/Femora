import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/lang.dart';
import '../models/doctor_summary.dart';
import '../models/health_store.dart';
import '../models/self_exam.dart';
import '../theme/app_theme.dart';
import 'report_screen.dart';

/// "Show my doctor": the summary inside a QR code. The doctor scans it with any phone camera; the text is in the
/// code itself, so nothing is uploaded and no internet is needed.
class DoctorQrScreen extends StatelessWidget {
  const DoctorQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final language = store.profile.language;
    final summary = DoctorSummary.build(store, lastSelfExam: context.watch<SelfExamState>().lastExam);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        title: Text(t(language, 'Show my doctor', 'ڈاکٹر کو دکھائیں'), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AppTheme.softShadow),
            child: Column(
              children: [
                Text(
                  store.profile.name.trim().isEmpty ? t(language, 'Health summary', 'صحت کا خلاصہ') : store.profile.name.trim(),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                const SizedBox(height: 14),
                Center(
                  child: QrImageView(
                    key: const Key('doctor_qr'),
                    data: summary,
                    version: QrVersions.auto,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    size: 260,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF3B1030)),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF3B1030)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.photo_camera_outlined, size: 18, color: AppColors.primaryBerry),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t(language, 'Your doctor scans this with their phone camera. Turn your screen brightness up.',
                            'آپ کا ڈاکٹر اسے اپنے فون کے کیمرے سے اسکین کرے۔ اپنی اسکرین کی روشنی بڑھا دیں۔'),
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textMuted, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFEFF6F1), borderRadius: BorderRadius.circular(16)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF2E7D57)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t(language, 'Private: the summary is inside the code itself. Nothing is uploaded and no internet is needed.',
                        'نجی: خلاصہ کوڈ کے اندر ہی ہے۔ کچھ بھی اپ لوڈ نہیں ہوتا اور انٹرنیٹ کی ضرورت نہیں۔'),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF24533B), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Material(
              color: Colors.white,
              elevation: 1,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                key: const Key('doctor_qr_text'),
                title: Text(t(language, 'What the doctor will see', 'ڈاکٹر کیا دیکھے گا'),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  SelectableText(summary,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.45, color: AppColors.textDark)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: summary));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(language, 'Summary copied', 'خلاصہ کاپی ہو گیا'))));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(t(language, 'Copy text', 'متن کاپی کریں')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBerry),
                  onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ReportScreen())),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: Text(t(language, 'Full PDF report', 'مکمل PDF رپورٹ')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
