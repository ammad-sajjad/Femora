import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/femora_header.dart';
import '../widgets/cycle_ring_widget.dart';
import '../widgets/metric_cards.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

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

              // Greeting
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Good morning, Ayesha',
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
                      'Here is your daily wellness overview.',
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

              // Hero Gradient Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBerry.withOpacity(0.35),
                        blurRadius: 24,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Cycle Day 12 • Follicular\nPhase 🌸',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.24),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Ovulation in 5 days • High Fertility Window 💖',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const CycleRingWidget(days: '18', label: 'DAYS'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Metrics Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    Row(
                      children: const [
                        Expanded(child: StressMetricCard()),
                        SizedBox(width: 14),
                        Expanded(child: SleepMetricCard()),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const EnergyMetricCard(),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Quick Log Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: const Text(
                  'Quick Log',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickLogItem(
                      context,
                      icon: Icons.water_drop_rounded,
                      iconColor: const Color(0xFFE53935),
                      bgColor: AppColors.quickLogPeriod,
                      label: 'PERIOD',
                      onTap: () {
                        context.read<AppState>().setTab(1); // switch to logger
                      },
                    ),
                    _buildQuickLogItem(
                      context,
                      icon: Icons.medical_services_outlined,
                      iconColor: const Color(0xFF6B58A8),
                      bgColor: AppColors.quickLogSymptoms,
                      label: 'SYMPTOMS',
                      onTap: () {
                        context.read<AppState>().setTab(1); // switch to logger
                      },
                    ),
                    _buildQuickLogItem(
                      context,
                      icon: Icons.sentiment_satisfied_alt_rounded,
                      iconColor: const Color(0xFF9E47BA),
                      bgColor: AppColors.quickLogMood,
                      label: 'MOOD',
                      onTap: () {
                        context.read<AppState>().setTab(1);
                      },
                    ),
                    _buildQuickLogItem(
                      context,
                      icon: Icons.science_outlined,
                      iconColor: const Color(0xFF2E9E68),
                      bgColor: AppColors.quickLogHormones,
                      label: 'HORMONES',
                      onTap: () {
                        context.read<AppState>().setTab(2); // switch to PCOS/hormone trends
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Daily AI Insight Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.aiInsightBg,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFB7CB),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.primaryBerry,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Daily AI Insight',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Your estrogen is rising. Great time for exercise and focus.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13.5,
                                color: Color(0xFF423B4E),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildQuickLogItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
