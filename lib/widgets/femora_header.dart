import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'server_address_dialog.dart';

class FemoraHeader extends StatelessWidget {
  final bool showMenuIcon;
  final bool isCalendarStyle;

  const FemoraHeader({
    super.key,
    this.showMenuIcon = false,
    this.isCalendarStyle = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: () => showServerAddressDialog(context), // hidden demo setting
        child: _layout(context),
      );

  Widget _layout(BuildContext context) {
    if (isCalendarStyle) {
      // Calendar screen header layout: "femora" logo on left, pink profile avatar on right
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'femora',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBerry,
                letterSpacing: -0.8,
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFFFFDDE6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: AppColors.primaryBerry,
                size: 22,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (showMenuIcon) ...[
                const Icon(
                  Icons.menu_rounded,
                  color: AppColors.textDark,
                  size: 24,
                ),
                const SizedBox(width: 12),
              ],
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryBerry.withOpacity(0.35),
                    width: 1.8,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/user_avatar.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.person,
                        color: AppColors.primaryBerry,
                        size: 22,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const Text(
            'femora',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryBerry,
              letterSpacing: -0.8,
            ),
          ),
          IconButton(
            onPressed: () {},
            splashRadius: 20,
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.textDark,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
