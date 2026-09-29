import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../models/cycle_engine.dart';
import '../models/health_store.dart';
import '../models/models.dart';
import '../models/self_exam.dart';
import '../theme/app_theme.dart';
import '../widgets/body_clock.dart';
import '../widgets/cycle_widgets.dart';
import '../widgets/femora_header.dart';
import 'dashboard_screen.dart';
import 'doctor_qr_screen.dart';
import 'heart_rate_screen.dart';
import 'trends_screen.dart';

/// Interactive fluid press animation wrapper
class _FluidPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const _FluidPress({required this.child, this.onTap, this.borderRadius});

  @override
  State<_FluidPress> createState() => _FluidPressState();
}

class _FluidPressState extends State<_FluidPress> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _scale = Tween<double>(begin: 1.0, end: 0.975).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad, reverseCurve: Curves.easeOutBack),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Home: everything here comes from what the user has actually done in the app (the on-device [HealthStore]).
class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  static String greeting(DateTime now, {String language = 'en'}) => now.hour < 12
      ? t(language, 'Good morning', 'صبح بخیر')
      : (now.hour < 17 ? t(language, 'Good afternoon', 'دوپہر بخیر') : t(language, 'Good evening', 'شام بخیر'));

  static String ago(DateTime date, DateTime now, {String language = 'en'}) {
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(date.year, date.month, date.day)).inDays;
    if (days <= 0) return t(language, 'today', 'آج');
    if (days == 1) return t(language, 'yesterday', 'کل');
    return t(language, '$days days ago', '$days دن پہلے');
  }

  // Result levels and scan titles in the app language (the server sends English)
  static String _levelIn(String level, String language) =>
      language == 'ur' ? const {'low': 'کم', 'medium': 'درمیانہ', 'high': 'زیادہ'}[level] ?? level : _cap(level);

  static String _scanTitleIn(String prediction, String title, String language) => language == 'ur'
      ? const {'normal': 'غالباً نارمل', 'benign': 'غالباً بے ضرر', 'malignant': 'مشکوک علامت'}[prediction] ?? title
      : title;

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// One short, rule-based suggestion for what to do next. The most important thing comes first.
  static String nextStep(HealthStore store, DateTime? lastExam, DateTime now, {String language = 'en'}) {
    final ur = language == 'ur';
    final risk = store.breastRisk;
    if (risk != null && risk.redFlags.isNotEmpty) {
      final flag = risk.redFlags.first.toLowerCase();
      return ur
          ? 'آپ نے $flag کی اطلاع دی۔ براہِ کرم ڈاکٹر سے ملاقات کا انتظام کریں؛ آپ کا کمپینین یہ بتانے میں مدد کر سکتا ہے کہ کیا کہنا ہے۔'
          : 'You reported $flag. Please arrange to see a doctor; your companion can help you prepare what to say.';
    }
    if (store.scan?.prediction == 'malignant') {
      return t(language, 'Your ultrasound screening was flagged as suspicious. This is not a diagnosis, but please book a breast specialist visit.',
          'آپ کی الٹراساؤنڈ اسکریننگ کو مشکوک نشان زد کیا گیا ہے۔ یہ تشخیص نہیں ہے، لیکن براہِ کرم بریسٹ اسپیشلسٹ سے ملاقات کریں۔');
    }
    final cycleFlag = CycleEngine(store.periods, now).flags.where((f) => f.seeDoctor).toList();
    if (cycleFlag.isNotEmpty) return cycleFlag.first.text;
    if (store.pcos?.level == 'high') {
      return t(language, 'Your PCOS screening was high. A gynaecologist can confirm it; ask your companion what tests to expect.',
          'آپ کی PCOS اسکریننگ زیادہ رہی۔ ایک ماہرِ امراضِ نسواں اس کی تصدیق کر سکتی ہیں؛ اپنے کمپینین سے پوچھیں کہ کون سے ٹیسٹ متوقع ہیں۔');
    }
    final today = DateTime(now.year, now.month, now.day);
    final loggedToday = store.logs.any((l) => DateTime(l.date.year, l.date.month, l.date.day) == today);
    if (!loggedToday) {
      return t(language, 'Log how you feel today (symptoms and mood) so your companion and your report stay up to date.',
          'آج آپ کیسا محسوس کر رہی ہیں یہ درج کریں (علامات اور موڈ) تاکہ آپ کا کمپینین اور رپورٹ اپ ڈیٹ رہیں۔');
    }
    if (lastExam == null || now.difference(lastExam).inDays >= 30) {
      return t(language, 'It is time for your monthly breast self-exam. The Breast tab has a step-by-step guide.',
          'آپ کے ماہانہ بریسٹ سیلف ایگزام کا وقت ہو گیا ہے۔ بریسٹ ٹیب میں مرحلہ وار رہنمائی موجود ہے۔');
    }
    if (store.periods.isEmpty) {
      return t(language, 'Log the first day of your last period in the Cycle tab so Femora can predict your next one.',
          'اپنے آخری پیریڈ کا پہلا دن سائیکل ٹیب میں درج کریں تاکہ Femora آپ کے اگلے پیریڈ کا اندازہ لگا سکے۔');
    }
    if (store.pcos == null && store.breastRisk == null && store.scan == null) {
      return t(language, 'Take a first check: PCOS risk or the breast questionnaire takes about two minutes.',
          'پہلا چیک کریں: PCOS رسک یا بریسٹ سوالنامہ صرف دو منٹ لیتا ہے۔');
    }
    return t(language, 'You are all caught up. Ask your companion anything about your results.', 'آپ نے سب کچھ مکمل کر لیا ہے۔ اپنے نتائج کے بارے میں کمپینین سے کچھ بھی پوچھیں۔');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final lastExam = context.watch<SelfExamState>().lastExam;
    final now = context.read<AppState>().now();
    final name = store.profile.firstName;
    final language = store.profile.language;
    final done = [store.pcos != null, store.scan != null, store.breastRisk != null].where((d) => d).length;
    final greetWord = greeting(now, language: language);

    return Scaffold(
      backgroundColor: const Color(0xFFFCF9FB),
      body: SafeArea(
        bottom: false,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFCF9FB),
                Color(0xFFFFF7FA),
                Color(0xFFFFFFFF),
                Color(0xFFFFF9FB),
              ],
              stops: [0.0, 0.25, 0.65, 1.0],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FemoraHeader(),
                const SizedBox(height: 8),

                // Greeting Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: name.isEmpty ? greetWord : '$greetWord, ',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  if (name.isNotEmpty)
                                    TextSpan(
                                      text: name,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFE11D48),
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                ],
                              ),
                              key: const Key('home_greeting'),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.auto_awesome_rounded, size: 20, color: Color(0xFFC084FC)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t(language, 'HERE IS YOUR DAILY HEALTH OVERVIEW.', 'یہ ہے آپ کی صحت کا خلاصہ۔'),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Hero Cycle Card
                _cycleCard(context, CycleEngine(store.periods, now), language),
                const SizedBox(height: 14),

                // Health Snapshot Card
                _snapshotCard(context, store, lastExam, now, done, language),
                const SizedBox(height: 24),

                // Quick Log Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            t(language, 'Quick Log', 'فوری اندراج'),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCE7F3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFBCFE8)),
                            ),
                            child: const Text(
                              '+ Instant',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFBE185D),
                              ),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => context.read<AppState>().setTab(1),
                            child: Text(
                              t(language, 'Daily habits →', 'روزمرہ عادات ←'),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE11D48),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        t(language, "Tap to log today's signals & symptoms", 'آج کی علامات اور کیفیات درج کرنے کے لیے ٹیپ کریں'),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4 Quick Log Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _quickLogItem(
                        context,
                        icon: Icons.water_drop_rounded,
                        iconColor: const Color(0xFFE11D48),
                        bgColor: const Color(0xFFFFEEF2),
                        borderColor: const Color(0xFFFECDD3),
                        shadowColor: const Color(0xFFE11D48).withOpacity(0.22),
                        label: t(language, 'PERIOD', 'پیریڈ'),
                        tab: 1,
                      ),
                      _quickLogItem(
                        context,
                        icon: Icons.medical_services_rounded,
                        iconColor: const Color(0xFF2563EB),
                        bgColor: const Color(0xFFEFF6FF),
                        borderColor: const Color(0xFFBFDBFE),
                        shadowColor: const Color(0xFF3B82F6).withOpacity(0.22),
                        label: t(language, 'SYMPTOMS', 'علامات'),
                        tab: 1,
                      ),
                      _quickLogItem(
                        context,
                        icon: Icons.sentiment_satisfied_alt_rounded,
                        iconColor: const Color(0xFF7C3AED),
                        bgColor: const Color(0xFFF5F3FF),
                        borderColor: const Color(0xFFDDD6FE),
                        shadowColor: const Color(0xFF8B5CF6).withOpacity(0.22),
                        label: t(language, 'MOOD', 'موڈ'),
                        tab: 1,
                      ),
                      _quickLogItem(
                        context,
                        icon: Icons.bubble_chart_rounded,
                        iconColor: const Color(0xFF059669),
                        bgColor: const Color(0xFFECFDF5),
                        borderColor: const Color(0xFFA7F3D0),
                        shadowColor: const Color(0xFF10B981).withOpacity(0.22),
                        label: t(language, 'PCOS', 'PCOS'),
                        tab: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Priority Next Step Card
                _nextStepCard(context, nextStep(store, lastExam, now, language: language), language),
                const SizedBox(height: 14),

                // 4 Feature Link Cards
                _dashboardCard(context, language),
                const SizedBox(height: 12),
                _doctorCard(context, language),
                const SizedBox(height: 12),
                _heartCard(context, store, language),
                const SizedBox(height: 12),
                _trendsCard(context, store, language),
                const SizedBox(height: 20),

                // Quick Daily Log Chips Row
                _quickDailyLogChips(context, language),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cycleCard(BuildContext context, CycleEngine e, String language) {
    const white = Colors.white;
    final until = e.daysUntilNext;
    final lateBy = e.isLate ? -until! : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: _FluidPress(
        onTap: () => context.read<AppState>().setTab(1),
        borderRadius: BorderRadius.circular(28),
        child: Container(
          key: const Key('home_cycle'),
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFE11D48),
                Color(0xFFBE185D),
                Color(0xFF881337),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE11D48).withOpacity(0.35),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: AmbientGlow()),
              Padding(
                padding: const EdgeInsets.all(18),
                child: e.hasHistory
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: Phase Badge & Cycle Title on left, Body Clock on right
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (e.phase != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.0),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: phaseColours[e.phase] ?? const Color(0xFFFF8FA3),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              e.phase!.labelIn(language),
                                              style: const TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    Text(
                                      e.periodOngoing
                                          ? t(language, 'Period day ${e.cycleDay}', 'پیریڈ کا دن ${e.cycleDay}')
                                          : t(language, 'Cycle day ${e.cycleDay}', 'سائیکل کا دن ${e.cycleDay}'),
                                      key: const Key('home_cycle_title'),
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: white,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        e.isLate
                                            ? t(language, 'Period expected ${plural(lateBy, 'day')} ago', 'پیریڈ کی توقع ${plural(lateBy, 'day', language: 'ur')} پہلے تھی')
                                            : t(language, 'Next period ${fmtDay(e.nextStart!)}', 'اگلا پیریڈ ${fmtDay(e.nextStart!, language: 'ur')}'),
                                        key: const Key('home_cycle_next'),
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              BodyClock(
                                key: const Key('home_body_clock'),
                                engine: e,
                                language: language,
                                centreValue: e.isLate ? '$lateBy' : '$until',
                                centreLabel: e.isLate
                                    ? t(language, 'DAYS LATE', 'دن تاخیر')
                                    : (until == 1 ? t(language, 'DAY TO GO', 'دن باقی') : t(language, 'DAYS TO GO', 'دن باقی')),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 0.8,
                            color: Colors.white.withOpacity(0.15),
                          ),
                          if (!e.isLate) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFFFD166)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    t(language, 'Fertile window ${fmtDay(e.fertileStart!)} to ${fmtDay(e.fertileEnd!)}',
                                        'زرخیز دورانیہ ${fmtDay(e.fertileStart!, language: 'ur')} سے ${fmtDay(e.fertileEnd!, language: 'ur')} تک'),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: white,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.8),
                                  ),
                                  child: const Text(
                                    'OVULATION EST.',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: white,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.8),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: HormoneWaves(key: const Key('home_hormone_waves'), engine: e, language: language),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t(language, 'Track your cycle', 'اپنا سائیکل ٹریک کریں'),
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w800, color: white),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t(language, 'Log the first day of your last period and Femora will predict your next one. Tap here to start.',
                                'اپنے آخری پیریڈ کا پہلا دن درج کریں اور Femora آپ کے اگلے پیریڈ کا اندازہ لگائے گا۔ شروع کرنے کے لیے یہاں ٹیپ کریں۔'),
                            key: const Key('home_cycle_empty'),
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: white, height: 1.4),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _snapshotCard(BuildContext context, HealthStore store, DateTime? lastExam, DateTime now, int done, String language) {
    final pcos = store.pcos;
    final scan = store.scan;
    final risk = store.breastRisk;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF881337),
              Color(0xFFB81D58),
              Color(0xFF6B1135),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF881337).withOpacity(0.35),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title & Subtitle on left, Progress Pill on right (if checks exist)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t(language, 'Your health snapshot', 'آپ کی صحت کا جائزہ'),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        done == 0
                            ? t(language, 'No checks yet. Tap a row to start.', 'ابھی کوئی چیک نہیں۔ شروع کرنے کے لیے ایک قطار پر ٹیپ کریں۔')
                            : t(language, 'Monthly screenings & risk index', 'ماہانہ اسکریننگ اور رسک انڈیکس'),
                        key: done == 0 ? const Key('home_progress') : null,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                if (done > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          t(language, '$done of 3 checks done', '$done از 3 چیک مکمل'),
                          key: const Key('home_progress'),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 58,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (done / 3).clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2DD4BF),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // 4 Screening Row Cards
            _screeningRowCard(
              context,
              key: const Key('home_pcos'),
              icon: Icons.bubble_chart_rounded,
              label: t(language, 'PCOS risk', 'PCOS رسک'),
              value: pcos == null ? t(language, 'Not checked yet', 'ابھی چیک نہیں ہوا') : '${_levelIn(pcos.level, language)} · ${pcos.percent}%',
              isElevated: pcos?.level == 'high',
              elevatedText: t(language, 'Elevated', 'زیادہ'),
              when: pcos == null ? null : ago(pcos.date, now, language: language),
              tab: 2,
            ),
            const SizedBox(height: 8),
            _screeningRowCard(
              context,
              key: const Key('home_scan'),
              icon: Icons.monitor_heart_rounded,
              label: t(language, 'Breast ultrasound', 'بریسٹ الٹراساؤنڈ'),
              value: scan == null
                  ? t(language, 'Not scanned yet', 'ابھی اسکین نہیں ہوا')
                  : '${_scanTitleIn(scan.prediction, scan.title, language)} · ${(scan.confidence * 100).round()}%',
              when: scan == null ? null : ago(scan.date, now, language: language),
              tab: 3,
            ),
            const SizedBox(height: 8),
            _screeningRowCard(
              context,
              key: const Key('home_risk'),
              icon: Icons.favorite_rounded,
              label: t(language, 'Breast cancer risk', 'بریسٹ کینسر رسک'),
              value: risk == null
                  ? t(language, 'Not checked yet', 'ابھی چیک نہیں ہوا')
                  : t(language, '${_cap(risk.level)} · ${risk.relativeRisk.toStringAsFixed(2)}× average',
                      '${_levelIn(risk.level, 'ur')} · اوسط کا ${risk.relativeRisk.toStringAsFixed(2)}×'),
              when: risk == null ? null : ago(risk.date, now, language: language),
              ctaLabel: risk == null ? t(language, 'Check now', 'چیک کریں') : null,
              tab: 3,
            ),
            const SizedBox(height: 8),
            _screeningRowCard(
              context,
              key: const Key('home_exam'),
              icon: Icons.self_improvement_rounded,
              label: t(language, 'Breast self-exam', 'بریسٹ سیلف ایگزام'),
              value: lastExam == null ? t(language, 'Not logged yet', 'ابھی درج نہیں ہوا') : _cap(ago(lastExam, now, language: language)),
              when: null,
              ctaLabel: lastExam == null ? t(language, 'Log', 'درج کریں') : null,
              tab: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _screeningRowCard(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
    required String value,
    String? when,
    bool isElevated = false,
    String? elevatedText,
    String? ctaLabel,
    required int tab,
  }) {
    return _FluidPress(
      onTap: () => context.read<AppState>().setTab(tab),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.09),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isElevated) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFBE185D),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.25), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF43F5E),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                elevatedText ?? 'Elevated',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (ctaLabel != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ctaLabel == 'Check now' || ctaLabel == 'چیک کریں' ? Colors.white : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: ctaLabel != 'Check now' && ctaLabel != 'چیک کریں' ? Border.all(color: Colors.white.withOpacity(0.25), width: 0.8) : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ctaLabel,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: ctaLabel == 'Check now' || ctaLabel == 'چیک کریں' ? const Color(0xFFBE185D) : Colors.white,
                      ),
                    ),
                    if (ctaLabel != 'Check now' && ctaLabel != 'چیک کریں') ...[
                      const SizedBox(width: 3),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 16),
                    ],
                  ],
                ),
              ),
            ] else ...[
              if (when != null)
                Text(
                  when,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.75), size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dashboardCard(BuildContext context, String language) => _linkCard(
        context,
        key: const Key('home_dashboard'),
        icon: Icons.grid_view_rounded,
        iconBg: const Color(0xFFFFF1F4),
        iconBorder: const Color(0xFFFFE4E8),
        iconColor: const Color(0xFFE11D48),
        title: t(language, 'Health dashboard', 'ہیلتھ ڈیش بورڈ'),
        subtitle: t(language, 'Cycle history, prediction accuracy, symptom patterns & trends',
            'سائیکل کی تاریخ، پیش گوئیوں کی درستگی، علامات کے رجحانات اور ہارمونل رجحانات'),
        screen: const DashboardScreen(),
      );

  Widget _doctorCard(BuildContext context, String language) => _linkCard(
        context,
        key: const Key('home_doctor_qr'),
        icon: Icons.qr_code_2_rounded,
        iconBg: const Color(0xFFECFDF5),
        iconBorder: const Color(0xFFA7F3D0),
        iconColor: const Color(0xFF059669),
        title: t(language, 'Show my doctor', 'ڈاکٹر کو دکھائیں'),
        subtitle: t(language, 'QR code health summary. Instantly scans without cloud upload',
            'آپ کے خلاصے والا QR کوڈ۔ ڈاکٹر اسے اسکین کرے، کچھ اپ لوڈ نہیں ہوتا'),
        screen: const DoctorQrScreen(),
      );

  Widget _heartCard(BuildContext context, HealthStore store, String language) {
    final last = store.heartReadings.isEmpty ? null : store.heartReadings.last;
    return _linkCard(
      context,
      key: const Key('home_heart'),
      icon: Icons.monitor_heart_rounded,
      iconBg: const Color(0xFFFFF1F2),
      iconBorder: const Color(0xFFFECDD3),
      iconColor: const Color(0xFFE11D48),
      title: t(language, 'Morning heart check', 'صبح کی دھڑکن کا چیک'),
      subtitle: last == null
          ? t(language, 'Measure pulse & HRV variability with camera fingertip test', 'کیمرے پر انگلی رکھ کر اپنی نبض ناپیں')
          : t(language, 'Last: ${last.bpm} bpm, ${HealthStore.ago(last.date, store.now())}',
              'آخری: ${last.bpm}، ${HealthStore.ago(last.date, store.now(), language: 'ur')}'),
      screen: const HeartRateScreen(),
    );
  }

  Widget _linkCard(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required Color iconBg,
    required Color iconBorder,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget screen,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: _FluidPress(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen)),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          key: key,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: iconBorder, width: 1.2),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                ),
                child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trendsCard(BuildContext context, HealthStore store, String language) {
    final n = store.now();
    final week = store.logs.where((l) => DateTime(n.year, n.month, n.day).difference(DateTime(l.date.year, l.date.month, l.date.day)).inDays < 7).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: _FluidPress(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TrendsScreen())),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          key: const Key('home_trends'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFFDDD6FE), width: 1.2),
                ),
                child: const Icon(Icons.show_chart_rounded, color: Color(0xFF7C3AED), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(language, 'My trends', 'میرے رجحانات'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      week == 0
                          ? t(language, 'Mood, sleep quality, stress levels & hormonal cycle trends', 'وقت کے ساتھ موڈ، نیند، تناؤ، توانائی اور علامات')
                          : t(language, '$week of the last 7 days logged. See your mood, sleep and stress patterns',
                              'پچھلے 7 دنوں میں سے $week دن درج۔ اپنے موڈ، نیند اور تناؤ کے رجحانات دیکھیں'),
                      key: const Key('home_trends_text'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                ),
                child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nextStepCard(BuildContext context, String text, String language) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: _FluidPress(
        onTap: () => context.read<AppState>().setTab(4),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          key: const Key('home_next_step'),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F4),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFFED7DC), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE11D48).withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECDD3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE11D48).withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFE11D48), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          t(language, 'Your next step', 'آپ کا اگلا قدم'),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE4E8),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECDD3), width: 0.8),
                          ),
                          child: const Text(
                            'PRIORITY',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFBE185D),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      text,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t(language, 'Ask your companion', 'اپنے کمپینین سے پوچھیں'),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFBE185D),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFFBE185D), size: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickLogItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required Color shadowColor,
    required String label,
    required int tab,
  }) {
    return _FluidPress(
      onTap: () => context.read<AppState>().setTab(tab),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickDailyLogChips(BuildContext context, String language) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                t(language, 'QUICK DAILY LOG', 'فوری روزانہ اندراج'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.read<AppState>().setTab(1),
                child: Text(
                  t(language, 'View all (12)', 'تمام دیکھیں (12)'),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFBE185D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(
                  context,
                  icon: Icons.water_drop_rounded,
                  iconColor: const Color(0xFFE11D48),
                  label: t(language, 'Cramps', 'درد'),
                  filled: false,
                ),
                const SizedBox(width: 8),
                _chip(
                  context,
                  icon: Icons.water_drop_rounded,
                  iconColor: Colors.white,
                  label: t(language, 'Medium flow', 'درمیانی روانی'),
                  filled: true,
                ),
                const SizedBox(width: 8),
                _chip(
                  context,
                  icon: Icons.auto_awesome_rounded,
                  iconColor: const Color(0xFFC084FC),
                  label: t(language, 'Calm', 'پرسکون'),
                  filled: false,
                ),
                const SizedBox(width: 8),
                _chip(
                  context,
                  icon: Icons.bolt_rounded,
                  iconColor: const Color(0xFFEAB308),
                  label: t(language, 'Low energy', 'کم توانائی'),
                  filled: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool filled,
  }) {
    return _FluidPress(
      onTap: () => context.read<AppState>().setTab(1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? const Color(0xFFE11D48) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: filled ? null : Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: const Color(0xFFE11D48).withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
                color: filled ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
