import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/lang.dart';
import '../models/chat_state.dart';
import '../models/health_store.dart';
import '../models/insights.dart';
import '../models/models.dart';
import '../models/pcos.dart';
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

              // Title Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(language, 'PCOS Risk Assessment', 'PCOS رسک جائزہ'),
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
                      t(language, 'Hormonal trends and lifestyle insights.', 'ہارمونل رجحانات اور طرزِ زندگی کی بصیرت۔'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Card 1: Risk Assessment Gauge (or start prompt)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: result == null
                    ? _buildStartCard(context, language)
                    : _buildResultCard(context, result, language),
              ),
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
              const SizedBox(height: 18),

              // Card 2: Hormonal Trends
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: HormoneChartWidget(),
              ),

              // Card 3: Actionable Guidance
              if (result != null) ...[
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

  Widget _buildStartCard(BuildContext context, String language) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.purpleTagBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.health_and_safety_outlined,
              color: AppColors.purpleTagText,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t(language, 'Check Your PCOS Risk', 'اپنا PCOS رسک چیک کریں'),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t(language, 'Answer a few quick questions about your cycle, symptoms and lifestyle. Our AI model, trained on 541 clinical records, estimates your risk in seconds.',
                'اپنے سائیکل، علامات اور طرزِ زندگی کے بارے میں چند فوری سوالات کے جواب دیں۔ ہمارا AI ماڈل، جو 541 طبی ریکارڈز پر تربیت یافتہ ہے، سیکنڈوں میں آپ کا رسک بتاتا ہے۔'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              color: AppColors.textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          _buildPrimaryButton(
            label: t(language, 'Start Assessment', 'جائزہ شروع کریں'),
            onTap: () => _openQuestionnaire(context),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, PcosResult result, String language) {
    final (badgeBg, badgeText, badgeIcon) = switch (result.riskLevel) {
      RiskLevel.low => (const Color(0xFFD4F8E5), AppColors.greenSuccess, Icons.check_circle_outline_rounded),
      RiskLevel.medium => (AppColors.purpleTagBg, AppColors.purpleTagText, Icons.warning_amber_rounded),
      RiskLevel.high => (AppColors.pinkTagBg, AppColors.pinkTagText, Icons.error_outline_rounded),
    };
    const tagColors = InfoTag.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Text(
            t(language, 'Risk Assessment', 'رسک جائزہ'),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 20),
          GaugeMeterWidget(percentage: result.probability),
          const SizedBox(height: 18),

          // Risk Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, color: badgeText, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${result.percent}% • ${result.riskLabel}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: badgeText,
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
                  InfoTag(
                    label: result.factors[i].label,
                    bgColor: tagColors[i % tagColors.length].$1,
                    textColor: tagColors[i % tagColors.length].$2,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            result.disclaimer,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              color: AppColors.textLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _openQuestionnaire(context),
            icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primaryBerry),
            label: Text(
              t(language, 'Retake Assessment', 'دوبارہ جائزہ لیں'),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBerry,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceSection(PcosResult result, String language) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFDFE6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primaryBerry,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                t(language, 'Actionable Guidance', 'قابلِ عمل رہنمائی'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < result.guidance.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            GuidanceCard(
              icon: guidanceIcon(result.guidance[i].key),
              title: result.guidance[i].title,
              description: result.guidance[i].description,
            ),
          ],
          if (result.riskLevel != RiskLevel.low) ...[
            const SizedBox(height: 14),
            NearbyCareButton(kind: CareKind.gynae, label: t(language, 'Find a gynaecologist near you', 'قریب ترین گائناکالوجسٹ تلاش کریں')),
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(25),
          boxShadow: AppTheme.buttonShadow,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
