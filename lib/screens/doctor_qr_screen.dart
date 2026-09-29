import 'dart:async';
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

/// Interactive touch spring compression
class _FluidPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _FluidPress({required this.child, this.onTap});

  @override
  State<_FluidPress> createState() => _FluidPressState();
}

class _FluidPressState extends State<_FluidPress> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 180),
    lowerBound: 0.96,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) => _ctrl.forward(),
      onTapCancel: () => _ctrl.forward(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.scale(scale: _ctrl.value, child: child),
        child: widget.child,
      ),
    );
  }
}

/// "Show my doctor": the whole report inside a QR code with laser beam sweep.
class DoctorQrScreen extends StatefulWidget {
  const DoctorQrScreen({super.key});

  @override
  State<DoctorQrScreen> createState() => _DoctorQrScreenState();
}

class _DoctorQrScreenState extends State<DoctorQrScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _laserCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    _laserCtrl.forward();
  }

  @override
  void dispose() {
    _laserCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final language = store.profile.language;
    final lastExam = context.watch<SelfExamState>().lastExam;
    final summary = DoctorSummary.build(store, lastSelfExam: lastExam);
    final link = DoctorLink.build(store, lastSelfExam: lastExam);
    final patientName = store.profile.name.trim().isEmpty ? 'Health summary' : store.profile.name.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFFCF9FB),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFCF9FB),
              Color(0xFFFFF7FA),
              Color(0xFFFFFFFF),
              Color(0xFFFFF9FB),
            ],
            stops: [0.0, 0.25, 0.65, 1.0],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              // Top Bar with back button, badge, and title
              _buildTopBar(context, language),
              const SizedBox(height: 18),

              // Main QR Card
              _buildQrCard(context, link, patientName, language),
              const SizedBox(height: 12),

              // Privacy Banner
              _buildPrivacyBanner(language),
              const SizedBox(height: 12),

              // Interactive Preview Card
              _buildPreviewCard(context, link, language),
              const SizedBox(height: 18),

              // Action Buttons Row
              _buildActionButtons(context, summary, language),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, String language) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _FluidPress(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF1E1B2E),
                size: 16,
              ),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFCE7F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'CLINICAL SYNC',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9D174D),
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t(language, 'Show my doctor', 'ڈاکٹر کو دکھائیں'),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E1B2E),
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQrCard(BuildContext context, String link, String patientName, String language) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFCE7F3), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9D174D).withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Inner White Container holding the QR Code with Animated Scan Beam
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFF8E7EE), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                QrImageView(
                  key: const Key('doctor_qr'),
                  data: link,
                  version: QrVersions.auto,
                  errorCorrectionLevel: QrErrorCorrectLevel.L,
                  size: 210,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF881337)),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF881337)),
                ),
                // Glowing Horizontal Laser Beam
                AnimatedBuilder(
                  animation: _laserCtrl,
                  builder: (context, _) {
                    if (_laserCtrl.isCompleted) return const SizedBox.shrink();
                    final opacity = (1.0 - (_laserCtrl.value - 0.85).clamp(0.0, 0.15) / 0.15);
                    return Positioned(
                      top: 15 + _laserCtrl.value * 180,
                      left: 0,
                      right: 0,
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0xFFFF487E),
                              Color(0xFFFFB3C6),
                              Color(0xFFFF487E),
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.2, 0.5, 0.8, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE11D48).withOpacity(0.65),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Timer Validity Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFBE185D)),
                const SizedBox(width: 6),
                Text(
                  t(language, 'Secure Instant Sync Valid for 15:00', 'محفوظ فوری ہم آہنگی 15:00 تک مؤثر'),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9D174D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Patient Name and Panel title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                patientName,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1B2E),
                ),
              ),
              const Text(
                ' • Endocrine Panel',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1B2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Subtitle instruction
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              t(language,
                  'Hold in front of your clinician\'s device or scan to instantly import your 30-day symptom telemetry.',
                  'ڈاکٹر کی ڈیوائس کے سامنے رکھیں یا 30 دن کی علامات کا ڈیٹا فوری درآمد کرنے کے لیے اسکین کریں۔'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context, String link, String language) {
    return _FluidPress(
      onTap: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication).catchError((_) => false),
      child: Container(
        key: const Key('doctor_qr_preview'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFFCE7F3), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFCE7F3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.visibility_outlined,
                color: Color(0xFFBE185D),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INTERACTIVE PREVIEW',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFBE185D),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t(language, 'See what the doctor will see', 'دیکھیں ڈاکٹر کیا دیکھے گا'),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E1B2E),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF1F4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFBE185D),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyBanner(String language) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF059669)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t(language,
                  "Private: your results are inside the code itself. The page only draws them on the doctor's phone; nothing is uploaded or stored.",
                  'نجی: آپ کے نتائج کوڈ کے اندر ہی ہیں۔ صفحہ انہیں صرف ڈاکٹر کے فون پر دکھاتا ہے؛ کچھ بھی اپ لوڈ یا محفوظ نہیں ہوتا۔'),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                color: Color(0xFF065F46),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String summary, String language) {
    return Row(
      children: [
        // Full PDF Report (Gradient button)
        Expanded(
          child: _FluidPress(
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ReportScreen())),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF9D174D),
                    Color(0xFFBE185D),
                    Color(0xFFE11D48),
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFBE185D).withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.description_outlined, color: Colors.white, size: 19),
                  const SizedBox(width: 8),
                  Text(
                    t(language, 'Full PDF report', 'مکمل PDF رپورٹ'),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Copy Text (White button with soft pink border)
        Expanded(
          child: _FluidPress(
            onTap: () {
              Clipboard.setData(ClipboardData(text: summary));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t(language, 'Summary copied', 'خلاصہ کاپی ہو گیا'))),
              );
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.copy_rounded, color: Color(0xFFBE185D), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    t(language, 'Copy text', 'متن کاپی کریں'),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E1B2E),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
