import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/femora_header.dart';
import '../widgets/gauge_meter_widget.dart';
import '../widgets/hormone_chart_widget.dart';

class PCOSAssessmentScreen extends StatelessWidget {
  const PCOSAssessmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
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

              // Card 1: Risk Assessment Gauge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
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
                      const GaugeMeterWidget(percentage: 0.62),
                      const SizedBox(height: 18),

                      // Risk Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.purpleTagBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.purpleTagText,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '62% • Moderate Risk',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.purpleTagText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Tags Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildDiagnosticTag(
                            icon: '⚠️',
                            label: 'Irregular Cycles',
                            bgColor: AppColors.orangeTagBg,
                            textColor: AppColors.orangeTagText,
                          ),
                          const SizedBox(width: 8),
                          _buildDiagnosticTag(
                            icon: '⚖️',
                            label: 'BMI 26.4',
                            bgColor: AppColors.pinkTagBg,
                            textColor: AppColors.pinkTagText,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildDiagnosticTag(
                        icon: '✨',
                        label: 'Acne/Symptoms',
                        bgColor: AppColors.blueTagBg,
                        textColor: AppColors.blueTagText,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Card 2: Hormonal Trends
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: HormoneChartWidget(),
              ),
              const SizedBox(height: 18),

              // Card 3: Actionable Guidance
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
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
                      const SizedBox(height: 12),
                      const Text(
                        'Your LH levels show a prolonged elevation, which is common in PCOS and can indicate anovulation. Combined with your symptoms, it\'s recommended to focus on insulin sensitivity.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.5,
                          color: Color(0xFF4A4555),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Nested item: Nutrition Adjustments
                      _buildGuidanceCard(
                        icon: Icons.restaurant_outlined,
                        title: 'Nutrition Adjustments',
                        description:
                            'Incorporate more fiber and healthy fats to stabilize blood sugar spikes.',
                      ),
                      const SizedBox(height: 12),

                      // Nested item: Lifestyle Focus
                      _buildGuidanceCard(
                        icon: Icons.fitness_center_rounded,
                        title: 'Lifestyle Focus',
                        description:
                            'Moderate strength training 3x a week can significantly improve insulin resistance.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosticTag({
    required String icon,
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$icon $label',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildGuidanceCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFF7A4F84),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    color: Color(0xFF4A5568),
                    height: 1.35,
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
