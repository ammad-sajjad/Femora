import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/lang.dart';
import '../models/doctor_link.dart';
import '../models/doctor_summary.dart';
import '../models/health_store.dart';
import '../models/self_exam.dart';
import '../theme/app_theme.dart';
import 'report_screen.dart';

/// "Show my doctor": the whole report inside a QR code. The doctor scans it with any phone camera and the report
/// opens as a page, drawn from the data inside the code itself (see [DoctorLink]); nothing is uploaded.
class DoctorQrScreen extends StatelessWidget {
  const DoctorQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final language = store.profile.language;
    final lastExam = context.watch<SelfExamState>().lastExam;
    final summary = DoctorSummary.build(store, lastSelfExam: lastExam);
    final link = DoctorLink.build(store, lastSelfExam: lastExam);

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
                    data: link,
                    version: QrVersions.auto,
                    errorCorrectionLevel: QrErrorCorrectLevel.L, // the least redundancy keeps a full report scannable
                    size: 280,
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
                        t(language, 'Your doctor scans this with their phone camera and your full report opens. Turn your screen brightness up.',
                            'آپ کا ڈاکٹر اسے اپنے فون کے کیمرے سے اسکین کرے تو آپ کی مکمل رپورٹ کھل جائے گی۔ اپنی اسکرین کی روشنی بڑھا دیں۔'),
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
                    t(language, "Private: your results are inside the code itself. The page only draws them on the doctor's phone; nothing is uploaded or stored.",
                        'نجی: آپ کے نتائج کوڈ کے اندر ہی ہیں۔ صفحہ انہیں صرف ڈاکٹر کے فون پر دکھاتا ہے؛ کچھ بھی اپ لوڈ یا محفوظ نہیں ہوتا۔'),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF24533B), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.white,
            elevation: 1,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              key: const Key('doctor_qr_preview'),
              leading: const Icon(Icons.visibility_outlined, color: AppColors.primaryBerry),
              title: Text(t(language, 'See what the doctor will see', 'دیکھیں ڈاکٹر کیا دیکھے گا'),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              subtitle: Text(t(language, 'Opens the report page, exactly as it looks after the scan', 'اسکین کے بعد والا رپورٹ صفحہ کھولتا ہے'),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textMuted)),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.textMuted),
              onTap: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication).catchError((_) => false),
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
