import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/insights.dart';
import '../models/pcos.dart';
import '../theme/app_theme.dart';
import '../widgets/femora_header.dart';
import '../widgets/gauge_meter_widget.dart';
import '../widgets/guidance_card.dart';
import '../widgets/hormone_chart_widget.dart';
import 'pcos_questionnaire_screen.dart';

class PCOSAssessmentScreen extends StatelessWidget {
  const PCOSAssessmentScreen({super.key});

  void _openQuestionnaire(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PCOSQuestionnaireScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = context.watch<PcosState>().result;

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
                  children: const [
                    Text(
                      'PCOS Risk Assessment',
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
                      'Hormonal trends and lifestyle insights.',
                      style: TextStyle(
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
                    ? _buildStartCard(context)
                    : _buildResultCard(context, result),
              ),
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
                  child: _buildGuidanceSection(result),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartCard(BuildContext context) {
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
          const Text(
            'Check Your PCOS Risk',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Answer a few quick questions about your cycle, symptoms and lifestyle. '
            'Our AI model, trained on 541 clinical records, estimates your risk in seconds.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              color: AppColors.textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          _buildPrimaryButton(
            label: 'Start Assessment',
            onTap: () => _openQuestionnaire(context),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, PcosResult result) {
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
          const Text(
            'Risk Assessment',
            style: TextStyle(
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
            label: const Text(
              'Retake Assessment',
              style: TextStyle(
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

  Widget _buildGuidanceSection(PcosResult result) {
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
              const Text(
                'Actionable Guidance',
                style: TextStyle(
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
