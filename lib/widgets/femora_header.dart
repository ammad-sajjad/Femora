import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../models/health_store.dart';
import '../screens/reminders_screen.dart';
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE11D48), width: 1.8),
                ),
                child: ProfileAvatar(name: name, size: 34),
              ),
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981), // active online dot
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  static const _logo = Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'femora',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: Color(0xFF4A0E2E), // deep plum
          letterSpacing: -0.9,
        ),
      ),
      SizedBox(width: 4),
      Icon(Icons.circle, size: 6, color: Color(0xFFE11D48)),
    ],
  );

  Widget _layout(BuildContext context) {
    final profile = Provider.of<HealthStore?>(context)?.profile;
    final name = profile?.name ?? '';
    final language = profile?.language ?? 'en';

    if (isCalendarStyle) {
      // Calendar screen: logo on the start side, avatar on the end side
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [_logo, _avatar(context, name, language)],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _avatar(context, name, language),
          _logo,
          Semantics(
            button: true,
            label: t(language, 'Reminders', 'یاد دہانیاں'),
            child: InkWell(
              key: const Key('header_reminders'),
              customBorder: const CircleBorder(),
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const RemindersScreen())),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.notifications_none_rounded, color: Color(0xFF332B30), size: 22),
                    Positioned(
                      top: 9,
                      right: 10,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48), // red notification dot
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
