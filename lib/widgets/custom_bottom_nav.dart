import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../models/health_store.dart';

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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_rounded, t(language, 'Home', 'ہوم')),
          _buildNavItem(1, Icons.calendar_today_outlined, t(language, 'Cycle', 'سائیکل')),
          _buildNavItem(2, Icons.show_chart_rounded, 'PCOS'),
          _buildNavItem(3, Icons.local_florist_outlined, t(language, 'Breast health', 'بریسٹ ہیلتھ')),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFE11D48) : Colors.transparent,
              shape: BoxShape.circle,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: const Color(0xFFE11D48).withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : const Color(0xFF64748B),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
