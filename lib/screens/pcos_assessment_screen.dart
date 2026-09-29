import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/lang.dart';
import '../models/chat_state.dart';
import '../models/health_store.dart';
import '../models/insights.dart';
import '../models/models.dart';
import '../models/pcos.dart';
import '../models/doctors.dart';
import '../models/places.dart';
import '../models/self_exam.dart';
import '../theme/app_theme.dart';
import '../widgets/femora_header.dart';
import '../widgets/gauge_meter_widget.dart';
import '../widgets/guidance_card.dart';
import '../widgets/hormone_chart_widget.dart';
import '../widgets/nearby_care_button.dart';
import '../widgets/what_if_card.dart';
import 'pcos_questionnaire_screen.dart';

class PCOSAssessmentScreen extends StatelessWidget {
  const PCOSAssessmentScreen({super.key});

  void _openQuestionnaire(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PCOSQuestionnaireScreen()),
    );
  }

  /// Opens the AI companion and asks it about the what-if (its context already includes the PCOS result).
  void _askAi(BuildContext context, String question) {
    final chat = context.read<ChatState>();
    final store = context.read<HealthStore>();
    final lastExam = context.read<SelfExamState>().lastExam;
    context.read<AppState>().setTab(4); // AI companion tab
    chat.send(question, store: store, lastSelfExam: lastExam);
  }

  @override
  Widget build(BuildContext context) {
    final pcos = context.watch<PcosState>();
    final result = pcos.result;
    final answers = pcos.lastAnswers;
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
              const FemoraHeader(),
              const SizedBox(height: 6),

              // Top Intelligence Pill
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: result == null
                    ? _buildUnassessedPill()
                    : _buildAssessedPill(),
              ),
              const SizedBox(height: 10),

              // Title Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(language, 'PCOS Risk Assessment', 'PCOS رسک جائزہ'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result == null
                          ? t(language, 'Hormonal trends and lifestyle insights.', 'ہارمونل رجحانات اور طرزِ زندگی کی بصیرت۔')
                          : t(language, 'Hormonal trends and personalized lifestyle insights.', 'ہارمونل رجحانات اور ذاتی نوعیت کی طرزِ زندگی کی بصیرت۔'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Card 1: Risk Assessment Gauge (or start prompt)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: result == null
                    ? _buildStartCard(context, language)
                    : _buildResultCard(context, result, language),
              ),

              // Card 2: What If (only when result is available)
              if (result != null && answers != null) ...[
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: WhatIfCard(
                    key: ObjectKey(answers),
                    api: pcos.api,
                    answers: answers,
                    result: result,
                    onAsk: () => _askAi(context, 'If I exercised more, ate less fast food or lost a little weight, how could that change my PCOS risk? Please explain what the what-if estimate means.'),
                  ),
                ),
              ],

              // Card 3: Hormonal Trends
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: HormoneChartWidget(isAssessed: result != null),
              ),

              // Card 4: Cohort Dataset Card (when unassessed) OR Actionable Guidance (when assessed)
              if (result == null) ...[
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: _buildCohortDatasetCard(context),
                ),
              ] else ...[
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: _buildGuidanceSection(result, language),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnassessedPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE7F3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFBE185D),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'CLINICAL AI INTELLIGENCE',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9D174D),
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessedPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFCE7F3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFBE185D),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'ENDOCRINE DIAGNOSTIC INTELLIGENCE',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9D174D),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF059669),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Live Model',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartCard(BuildContext context, String language) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          // Circular Glowing Shield Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF5FF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFBE185D).withOpacity(0.18),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: Color(0xFF9D174D),
              size: 34,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            t(language, 'Check Your PCOS Risk', 'اپنا PCOS رسک چیک کریں'),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t(language,
                'Answer a few quick questions about your cycle, symptoms and lifestyle. Our AI model, trained on 541 clinical records, estimates your risk in seconds.',
                'اپنے سائیکل، علامات اور طرزِ زندگی کے بارے میں چند فوری سوالات کے جواب دیں۔ ہمارا AI ماڈل، جو 541 طبی ریکارڈز پر تربیت یافتہ ہے، سیکنڈوں میں آپ کا رسک بتاتا ہے۔'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: () => _openQuestionnaire(context),
            child: Container(
              height: 52,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF9D174D),
                    Color(0xFFBE185D),
                    Color(0xFFE11D48),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFBE185D).withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    t(language, 'Start Assessment', 'جائزہ شروع کریں'),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8), size: 13),
              SizedBox(width: 6),
              Text(
                'HIPAA-aligned • Encrypted • 2-3 mins',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCohortDatasetCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Mini preview thumbnail matching Figma document preview
          Container(
            width: 46,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 3, height: 3, decoration: const BoxDecoration(color: Color(0xFFBE185D), shape: BoxShape.circle)),
                    const SizedBox(width: 2),
                    Container(width: 14, height: 2.5, decoration: BoxDecoration(color: const Color(0xFF94A3B8), borderRadius: BorderRadius.circular(1))),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Container(width: 20, height: 2, decoration: BoxDecoration(color: const Color(0xFFBE185D), borderRadius: BorderRadius.circular(1))),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F8),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFDA4AF), width: 0.8),
                  ),
                  child: const Center(
                    child: Icon(Icons.shield_rounded, color: Color(0xFFBE185D), size: 7),
                  ),
                ),
                Column(
                  children: [
                    Container(width: 26, height: 2, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(1))),
                    const SizedBox(height: 2),
                    Container(width: 18, height: 2, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(1))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'COHORT DATASET • v2.4',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFBE185D),
                    letterSpacing: 0.6,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Rotterdam Diagnostics Alignment',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Cycle regularity, hyperandrogenism & ultrasound indicators',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFFDF2F8),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFBE185D),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, PcosResult result, String language) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          // Header Row with Bar Chart icon and Retake Pill Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF2F8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        color: Color(0xFFBE185D),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        t(language, 'Risk Assessment', 'رسک جائزہ'),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _openQuestionnaire(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFDA4AF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFFBE185D)),
                      const SizedBox(width: 4),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: 0.0,
                            child: Text(
                              t(language, 'Retake Assessment', 'دوبارہ جائزہ لیں'),
                              style: const TextStyle(fontSize: 0.1),
                            ),
                          ),
                          Text(
                            t(language, 'Retake', 'دوبارہ'),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFBE185D),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Custom Arc Gauge
          GaugeMeterWidget(percentage: result.probability),
          const SizedBox(height: 18),

          // Risk Score Badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFBE185D), size: 20),
                const SizedBox(width: 8),
                Text(
                  '${result.percent}% • ${result.riskLabel}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9D174D),
                  ),
                ),
              ],
            ),
          ),

          // Contributing factor tags
          if (result.factors.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < result.factors.length; i++)
                  _buildFactorPill(result.factors[i].label, i),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // Disclaimer Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBFD),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFCE7F3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFBE185D),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.disclaimer,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      height: 1.45,
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

  Widget _buildFactorPill(String label, int index) {
    final isBmi = label.toLowerCase().contains('bmi');
    final dotColor = isBmi ? const Color(0xFFF59E0B) : const Color(0xFFA855F7);
    final borderColor = isBmi ? const Color(0xFFFDE68A) : const Color(0xFFE9D5FF);
    final bgColor = isBmi ? const Color(0xFFFFFBEB) : const Color(0xFFFAF5FF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceSection(PcosResult result, String language) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFDF2F8),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.monitor_heart_outlined,
                color: Color(0xFFBE185D),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              t(language, 'Actionable Guidance', 'قابلِ عمل رہنمائی'),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Individual Guidance Cards
        for (var i = 0; i < result.guidance.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          GuidanceCard(
            icon: guidanceIcon(result.guidance[i].key),
            title: result.guidance[i].title,
            description: result.guidance[i].description,
          ),
        ],

        // Nearby Gynaecologist Action
        if (result.riskLevel != RiskLevel.low) ...[
          const SizedBox(height: 16),
          NearbyCareButton(
            kind: CareKind.gynae,
            doctor: DoctorSpecialty.gynae,
            label: t(language, 'Find a gynaecologist near you', 'قریب ترین گائناکالوجسٹ تلاش کریں'),
          ),
        ],
      ],
    );
  }
}
