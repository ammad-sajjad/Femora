import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../models/health_store.dart';
import '../theme/app_theme.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final language = Provider.of<HealthStore?>(context)?.profile.language ?? 'en';
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(34),
        boxShadow: AppTheme.floatingNavShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_rounded, t(language, 'Home', 'ہوم')),
          _buildNavItem(1, Icons.calendar_today_outlined, t(language, 'Cycle', 'سائیکل')),
          _buildNavItem(2, Icons.show_chart_rounded, 'PCOS'),
          _buildNavItem(3, Icons.local_florist_outlined, t(language, 'Breast health', 'بریسٹ ہیلتھ')),
          // A chat bubble, not a person: the person is now her profile (the avatar at the top)
          _buildNavItem(4, Icons.chat_bubble_outline_rounded, t(language, 'AI companion', 'AI کمپینین')),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isActive = currentIndex == index;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: isActive,
        label: label,
        child: GestureDetector(
          onTap: () => onTap(index),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primaryBerry : Colors.transparent,
              shape: BoxShape.circle,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primaryBerry.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : const Color(0xFF6E5970),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
