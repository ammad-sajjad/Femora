import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../models/auth_state.dart';
import '../models/chat_state.dart';
import '../models/health_store.dart';
import '../screens/dashboard_screen.dart';
import '../screens/doctor_qr_screen.dart';
import '../screens/heart_rate_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/reminders_screen.dart';
import '../screens/report_reader_screen.dart';
import '../screens/report_screen.dart';
import '../theme/app_theme.dart';
import 'server_address_dialog.dart';

/// Her initials on a soft circle (never a stock photo, which would look like someone else's account).
class ProfileAvatar extends StatelessWidget {
  final String name;
  final double size;
  const ProfileAvatar({super.key, required this.name, this.size = 38});

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    return (parts.first.characters.first + (parts.length > 1 ? parts.last.characters.first : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final i = initials(name);
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(0xFFFF7FA3), Color(0xFFB0124F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      alignment: Alignment.center,
      child: i.isEmpty
          ? Icon(Icons.person_rounded, color: Colors.white, size: size * 0.58)
          : Text(i, style: TextStyle(fontFamily: 'Inter', fontSize: size * 0.38, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}

/// Opens the profile panel, sliding in from the start edge (left in English, right in Urdu).
Future<void> showProfilePanel(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => const Align(alignment: AlignmentDirectional.centerStart, child: ProfilePanel()),
    transitionBuilder: (context, anim, _, child) {
      final rtl = Directionality.of(context) == TextDirection.rtl;
      return SlideTransition(
        position: Tween(begin: Offset(rtl ? 1 : -1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
  );
}

class ProfilePanel extends StatelessWidget {
  const ProfilePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final auth = Provider.of<AuthState?>(context);
    final p = store.profile;
    final language = p.language;
    final user = auth?.user;
    final width = (MediaQuery.of(context).size.width * 0.86).clamp(260.0, 340.0);

    void open(Widget screen) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
    }

    final account = user == null
        ? t(language, 'On this phone only', 'صرف اس فون پر')
        : user.isGuest
            ? t(language, 'Guest (not signed in)', 'مہمان (سائن اِن نہیں)')
            : (user.email ?? user.phone ?? t(language, 'Signed in', 'سائن اِن'));
    final facts = [
      if (p.age != null) t(language, '${p.age} years', '${p.age} سال'),
      if (p.bmi != null) 'BMI ${p.bmi!.toStringAsFixed(1)}',
    ];

    return Material(
      key: const Key('profile_panel'),
      color: AppColors.background,
      borderRadius: const BorderRadiusDirectional.horizontal(end: Radius.circular(28)).resolve(Directionality.of(context)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            children: [
              Row(
                children: [
                  ProfileAvatar(name: p.name, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name.trim().isEmpty ? t(language, 'Welcome', 'خوش آمدید') : p.name.trim(),
                            key: const Key('profile_name'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                        const SizedBox(height: 2),
                        Text(account, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textMuted)),
                        if (facts.isNotEmpty)
                          Text(facts.join('  ·  '), style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                key: const Key('profile_edit'),
                onPressed: () => open(const OnboardingScreen(editing: true)),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(t(language, 'Edit profile', 'پروفائل میں ترمیم')),
              ),
              const SizedBox(height: 16),
              _section(t(language, 'Language', 'زبان')),
              SegmentedButton<String>(
                key: const Key('profile_language'),
                segments: const [
                  ButtonSegment(value: 'en', label: Text('English')),
                  ButtonSegment(value: 'ur', label: Text('اردو')),
                ],
                selected: {language},
                showSelectedIcon: false,
                onSelectionChanged: (v) => store.saveProfile(p..language = v.first),
              ),
              const SizedBox(height: 16),
              _section(t(language, 'My health', 'میری صحت')),
              _item(const Key('profile_dashboard'), Icons.dashboard_customize_outlined, t(language, 'Health dashboard', 'ہیلتھ ڈیش بورڈ'),
                  () => open(const DashboardScreen())),
              _item(const Key('profile_doctor'), Icons.qr_code_2_rounded, t(language, 'Show my doctor (QR)', 'ڈاکٹر کو دکھائیں (QR)'),
                  () => open(const DoctorQrScreen())),
              _item(const Key('profile_report'), Icons.picture_as_pdf_outlined, t(language, 'Health report (PDF)', 'ہیلتھ رپورٹ (PDF)'),
                  () => open(const ReportScreen())),
              _item(const Key('profile_reader'), Icons.document_scanner_outlined, t(language, 'Explain a medical report', 'میڈیکل رپورٹ سمجھائیں'),
                  () => open(const ReportReaderScreen())),
              _item(const Key('profile_heart'), Icons.monitor_heart_outlined, t(language, 'Morning heart check', 'صبح کی دھڑکن کا چیک'),
                  () => open(const HeartRateScreen())),
              _item(const Key('profile_reminders'), Icons.notifications_active_outlined, t(language, 'Reminders', 'یاد دہانیاں'),
                  () => open(const RemindersScreen())),
              const SizedBox(height: 16),
              _section(t(language, 'Privacy', 'رازداری')),
              SwitchListTile(
                key: const Key('profile_personalize'),
                contentPadding: EdgeInsets.zero,
                value: p.personalize,
                onChanged: (v) => store.saveProfile(p..personalize = v),
                title: Text(t(language, 'Personalise the companion', 'کمپینین کو ذاتی بنائیں'), style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
                subtitle: Text(t(language, 'Shares a short summary of your results, never your name', 'آپ کے نتائج کا مختصر خلاصہ، کبھی نام نہیں'),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12)),
              ),
              _item(const Key('profile_delete'), Icons.lock_reset_rounded, t(language, 'Delete all my data on this phone', 'اس فون پر میرا تمام ڈیٹا حذف کریں'),
                  () => _confirmDelete(context, store, language),
                  colour: AppColors.accentPink),
              const SizedBox(height: 16),
              _section(t(language, 'App', 'ایپ')),
              _item(const Key('profile_server'), Icons.dns_outlined, t(language, 'Server address', 'سرور کا پتہ'), () {
                Navigator.pop(context);
                showServerAddressDialog(context);
              }),
              _item(const Key('profile_about'), Icons.info_outline_rounded, t(language, 'About Femora', 'Femora کے بارے میں'), () => _about(context, language)),
              if (user != null)
                _item(const Key('profile_sign_out'), Icons.logout_rounded, t(language, 'Sign out', 'سائن آؤٹ'), () async {
                  Navigator.pop(context);
                  await auth!.signOut();
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(title.toUpperCase(),
            style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.textLight)),
      );

  Widget _item(Key key, IconData icon, String label, VoidCallback onTap, {Color colour = AppColors.primaryBerry}) => ListTile(
        key: key,
        dense: true,
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        leading: Icon(icon, color: colour, size: 22),
        title: Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: colour == AppColors.primaryBerry ? AppColors.textDark : colour)),
        onTap: onTap,
      );

  Future<void> _confirmDelete(BuildContext context, HealthStore store, String language) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t(language, 'Delete everything?', 'سب کچھ حذف کریں؟')),
        content: Text(t(language, 'This removes your profile, results, logs and chat from this phone. It cannot be undone.',
            'یہ آپ کی پروفائل، نتائج، اندراجات اور گفتگو اس فون سے ہٹا دے گا۔ اسے واپس نہیں لایا جا سکتا۔')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(t(language, 'Cancel', 'منسوخ کریں'))),
          TextButton(key: const Key('profile_delete_confirm'), onPressed: () => Navigator.pop(d, true), child: Text(t(language, 'Delete', 'حذف کریں'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final chat = Provider.of<ChatState?>(context, listen: false);
    await store.clearAll();
    await chat?.clear();
    if (context.mounted) Navigator.pop(context);
  }

  void _about(BuildContext context, String language) => showAboutDialog(
        context: context,
        applicationName: 'Femora',
        applicationVersion: 'FYP 2026 · Air University Islamabad',
        applicationLegalese: t(language,
            'Awareness and screening support only, not a medical diagnosis. Your health data stays on this phone.',
            'صرف آگاہی اور ابتدائی جانچ میں مدد، طبی تشخیص نہیں۔ آپ کا صحت کا ڈیٹا اسی فون پر رہتا ہے۔'),
      );
}
