import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Icon for a guidance `key` returned by the backend.
IconData guidanceIcon(String key) => switch (key) {
      'specialist' => Icons.medical_services_outlined,
      'urgent' => Icons.priority_high_rounded,
      'monitor' => Icons.visibility_outlined,
      'nutrition' => Icons.restaurant_rounded,
      'exercise' => Icons.fitness_center_rounded,
      'tracking' => Icons.calendar_month_rounded,
      'screening' => Icons.document_scanner_outlined,
      'self_exam' => Icons.front_hand_outlined,
      'report' => Icons.description_outlined,
      'hrt' => Icons.medication_outlined,
      'info' => Icons.info_outline_rounded,
      _ => Icons.favorite_border_rounded,
    };

class GuidanceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const GuidanceCard({super.key, required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    final (iconBg, iconColor) = _iconTheme(icon);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFFDA4AF),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _iconTheme(IconData icon) {
    if (icon == Icons.visibility_outlined) {
      return (const Color(0xFFF5F3FF), const Color(0xFF7C3AED));
    }
    if (icon == Icons.front_hand_outlined || icon == Icons.pan_tool_outlined) {
      return (const Color(0xFFEFF6FF), const Color(0xFF2563EB));
    }
    if (icon == Icons.document_scanner_outlined || icon == Icons.fullscreen_rounded) {
      return (const Color(0xFFEFF6FF), const Color(0xFF2563EB));
    }
    if (icon == Icons.priority_high_rounded || icon == Icons.medical_services_outlined || icon == Icons.local_hospital_outlined || icon == Icons.add_box_outlined) {
      return (const Color(0xFFEFF6FF), const Color(0xFF2563EB));
    }
    if (icon == Icons.restaurant_rounded || icon == Icons.restaurant_outlined) {
      return (const Color(0xFFFAF5FF), const Color(0xFF8B5CF6));
    }
    if (icon == Icons.fitness_center_rounded) {
      return (const Color(0xFFFEF3C7), const Color(0xFFD97706));
    }
    if (icon == Icons.calendar_month_rounded || icon == Icons.calendar_month_outlined) {
      return (const Color(0xFFFCE7F3), const Color(0xFFEC4899));
    }
    return (const Color(0xFFFDF2F8), const Color(0xFFBE185D));
  }
}


/// Small coloured pill, e.g. a contributing risk factor.
class InfoTag extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;

  const InfoTag({super.key, required this.label, required this.bgColor, required this.textColor});

  static const palette = [
    (AppColors.orangeTagBg, AppColors.orangeTagText),
    (AppColors.pinkTagBg, AppColors.pinkTagText),
    (AppColors.blueTagBg, AppColors.blueTagText),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
