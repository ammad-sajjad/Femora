import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../models/auth_state.dart';
import '../models/chat_state.dart';
import '../models/health_store.dart';
import '../screens/dashboard_screen.dart';
import '../screens/doctor_qr_screen.dart';
import '../screens/heart_rate_screen.dart';
import '../screens/find_doctor_screen.dart';
import '../screens/nearby_care_screen.dart';
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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFF3366), Color(0xFF881337)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF881337).withOpacity(0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: i.isEmpty
          ? Icon(Icons.person_rounded, color: Colors.white, size: size * 0.54)
          : Text(
              i,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: size * 0.38,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
    );
  }
}

/// Opens the profile panel, sliding in from the start edge (left in English, right in Urdu).
Future<void> showProfilePanel(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, __, ___) => const Align(alignment: AlignmentDirectional.centerStart, child: ProfilePanel()),
    transitionBuilder: (context, anim, _, child) {
      final rtl = Directionality.of(context) == TextDirection.rtl;
      return SlideTransition(
        position: Tween(begin: Offset(rtl ? 1 : -1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
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
    final width = (MediaQuery.of(context).size.width * 0.86).clamp(280.0, 360.0);

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
      color: Colors.transparent,
      child: Container(
        width: width,
        height: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFFCF9FB),
          borderRadius: const BorderRadiusDirectional.horizontal(end: Radius.circular(32))
              .resolve(Directionality.of(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 28,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              // User Card with Avatar, Info, and Edit Profile
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF0F5), Color(0xFFFFFFFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFFCE7F3), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF881337).withOpacity(0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ProfileAvatar(name: p.name, size: 54),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name.trim().isEmpty ? t(language, 'Welcome', 'خوش آمدید') : p.name.trim(),
                                key: const Key('profile_name'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E1B2E),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                account,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              if (facts.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  facts.join('  ·  '),
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF9D174D),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Edit Profile Pill
                    InkWell(
                      key: const Key('profile_edit'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => open(const OnboardingScreen(editing: true)),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 9.5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFBCFE8)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF881337).withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF9D174D)),
                            const SizedBox(width: 7),
                            Text(
                              t(language, 'Edit profile', 'پروفائل میں ترمیم'),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9D174D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // LANGUAGE SECTION
              _section(t(language, 'Language', 'زبان')),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: SegmentedButton<String>(
                  key: const Key('profile_language'),
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                      if (states.contains(MaterialState.selected)) {
                        return const Color(0xFF881337);
                      }
                      return Colors.transparent;
                    }),
                    foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                      if (states.contains(MaterialState.selected)) {
                        return Colors.white;
                      }
                      return const Color(0xFF475569);
                    }),
                    textStyle: MaterialStateProperty.all(
                      const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    side: MaterialStateProperty.all(BorderSide.none),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    elevation: MaterialStateProperty.resolveWith<double>((states) {
                      return states.contains(MaterialState.selected) ? 2 : 0;
                    }),
                  ),
                  segments: const [
                    ButtonSegment(value: 'en', label: Text('English')),
                    ButtonSegment(value: 'ur', label: Text('اردو')),
                  ],
                  selected: {language},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => store.saveProfile(p..language = v.first),
                ),
              ),

              // MY HEALTH SECTION
              _section(t(language, 'My health', 'میری صحت')),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.025),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _item(context, const Key('profile_dashboard'), Icons.dashboard_customize_outlined,
                        t(language, 'Health dashboard', 'ہیلتھ ڈیش بورڈ'), () => open(const DashboardScreen())),
                    _divider(),
                    _item(context, const Key('profile_doctor'), Icons.qr_code_2_rounded,
                        t(language, 'Show my doctor (QR)', 'ڈاکٹر کو دکھائیں (QR)'), () => open(const DoctorQrScreen())),
                    _divider(),
                    _item(context, const Key('profile_report'), Icons.picture_as_pdf_outlined,
                        t(language, 'Health report (PDF)', 'ہیلتھ رپورٹ (PDF)'), () => open(const ReportScreen())),
                    _divider(),
                    _item(context, const Key('profile_reader'), Icons.document_scanner_outlined,
                        t(language, 'Explain a medical report', 'میڈیکل رپورٹ سمجھائیں'), () => open(const ReportReaderScreen())),
                    _divider(),
                    _item(context, const Key('profile_heart'), Icons.monitor_heart_outlined,
                        t(language, 'Morning heart check', 'صبح کی دھڑکن کا چیک'), () => open(const HeartRateScreen())),
                    _divider(),
                    _item(context, const Key('profile_doctors'), Icons.person_search_outlined,
                        t(language, 'Find a doctor', 'ڈاکٹر تلاش کریں'), () => open(const FindDoctorScreen())),
                    _divider(),
                    _item(context, const Key('profile_nearby'), Icons.local_hospital_outlined,
                        t(language, 'Nearby care', 'قریبی طبی سہولیات'), () => open(const NearbyCareScreen())),
                    _divider(),
                    _item(context, const Key('profile_reminders'), Icons.notifications_active_outlined,
                        t(language, 'Reminders', 'یاد دہانیاں'), () => open(const RemindersScreen())),
                  ],
                ),
              ),

              // PRIVACY SECTION
              _section(t(language, 'Privacy', 'رازداری')),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.025),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDF2F8),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.psychology_outlined, color: Color(0xFF881337), size: 19),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t(language, 'Personalise the companion', 'کمپینین کو ذاتی بنائیں'),
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t(language, 'Shares a short summary of your results, never your name',
                                      'آپ کے نتائج کا مختصر خلاصہ، کبھی نام نہیں'),
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            key: const Key('profile_personalize'),
                            value: p.personalize,
                            onChanged: (v) => store.saveProfile(p..personalize = v),
                            activeColor: const Color(0xFF881337),
                            activeTrackColor: const Color(0xFFFBCFE8),
                          ),
                        ],
                      ),
                    ),
                    _divider(),
                    _item(
                      context,
                      const Key('profile_delete'),
                      Icons.lock_reset_rounded,
                      t(language, 'Delete all my data on this phone', 'اس فون پر میرا تمام ڈیٹا حذف کریں'),
                      () => _confirmDelete(context, store, language),
                      colour: AppColors.accentPink,
                    ),
                  ],
                ),
              ),

              // APP SECTION
              _section(t(language, 'App', 'ایپ')),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.025),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _item(
                      context,
                      const Key('profile_server'),
                      Icons.cloud_sync_outlined,
                      t(language, 'Server address', 'سرور کا پتہ'),
                      () {
                        Navigator.pop(context);
                        showServerAddressDialog(context);
                      },
                    ),
                    _divider(),
                    _item(
                      context,
                      const Key('profile_about'),
                      Icons.info_outline_rounded,
                      t(language, 'About Femora', 'Femora کے بارے میں'),
                      () => _about(context, language),
                    ),
                    if (user != null) ...[
                      _divider(),
                      _item(
                        context,
                        const Key('profile_sign_out'),
                        Icons.logout_rounded,
                        t(language, 'Sign out', 'سائن آؤٹ'),
                        () async {
                          Navigator.pop(context);
                          await auth!.signOut();
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(left: 4, right: 4, top: 16, bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Color(0xFF94A3B8),
          ),
        ),
      );

  Widget _divider() => const Divider(height: 1, thickness: 1, color: Color(0xFFF8FAFC), indent: 56);

  Widget _item(
    BuildContext context,
    Key key,
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color colour = AppColors.primaryBerry,
  }) {
    final isDanger = colour == AppColors.accentPink || colour == const Color(0xFFE11D48);
    final iconBg = isDanger ? const Color(0xFFFFF1F2) : const Color(0xFFFDF2F8);
    final textColor = isDanger ? const Color(0xFFE11D48) : const Color(0xFF1E293B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10.5),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: colour, size: 19),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: const Color(0xFFCBD5E1),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

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
