import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Icon for a guidance `key` returned by the backend.
IconData guidanceIcon(String key) => switch (key) {
      'specialist' => Icons.local_hospital_outlined,
      'urgent' => Icons.priority_high_rounded,
      'monitor' => Icons.visibility_outlined,
      'nutrition' => Icons.restaurant_outlined,
      'exercise' => Icons.fitness_center_rounded,
      'tracking' => Icons.calendar_month_outlined,
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF7A4F84), size: 20),
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
