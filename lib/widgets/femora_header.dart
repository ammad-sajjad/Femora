import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../models/health_store.dart';
import '../screens/reminders_screen.dart';
import '../theme/app_theme.dart';
import 'profile_panel.dart';
import 'server_address_dialog.dart';

/// The top bar of every tab: her avatar (opens the profile panel), the logo, and the reminders bell.
class FemoraHeader extends StatelessWidget {
  final bool isCalendarStyle;

  const FemoraHeader({super.key, this.isCalendarStyle = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: () => showServerAddressDialog(context), // hidden demo setting (also in the profile panel)
        child: _layout(context),
      );

  Widget _avatar(BuildContext context, String name, String language) => Semantics(
        button: true,
        label: t(language, 'Open profile', 'پروفائل کھولیں'),
        child: InkWell(
          key: const Key('header_avatar'),
          customBorder: const CircleBorder(),
          onTap: () => showProfilePanel(context),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primaryBerry.withValues(alpha: 0.3), width: 1.6)),
            child: ProfileAvatar(name: name, size: 34),
          ),
        ),
      );

  static const _logo = Text(
    'femora',
    style: TextStyle(fontFamily: 'Inter', fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primaryBerry, letterSpacing: -0.8),
  );

  Widget _layout(BuildContext context) {
    final profile = Provider.of<HealthStore?>(context)?.profile;
    final name = profile?.name ?? '';
    final language = profile?.language ?? 'en';

    if (isCalendarStyle) {
      // Calendar screen: logo on the start side, avatar on the end side
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [_logo, _avatar(context, name, language)],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _avatar(context, name, language),
          _logo,
          IconButton(
            key: const Key('header_reminders'),
            tooltip: t(language, 'Reminders', 'یاد دہانیاں'),
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const RemindersScreen())),
            icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textDark, size: 24),
          ),
        ],
      ),
    );
  }
}
