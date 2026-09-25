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
import 'trends_screen.dart';

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

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// One short, rule-based suggestion for what to do next. The most important thing comes first.
  ///
  /// The two branches that quote something she herself reported (a red flag, a cycle flag) embed that
  /// value as it was recorded, which is still English-only; the rest of the sentence still translates.
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FemoraHeader(),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? greeting(now, language: language) : '${greeting(now, language: language)}, $name',
                      key: const Key('home_greeting'),
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textDark, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(t(language, 'Here is your health overview.', 'یہ ہے آپ کی صحت کا خلاصہ۔'), style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _cycleCard(context, CycleEngine(store.periods, now), language),
              const SizedBox(height: 14),
              _snapshotCard(context, store, lastExam, now, done, language),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(t(language, 'Quick Log', 'فوری اندراج'), style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _quickLogItem(context, icon: Icons.water_drop_rounded, iconColor: const Color(0xFFE53935), bgColor: AppColors.quickLogPeriod, label: t(language, 'PERIOD', 'پیریڈ'), tab: 1),
                    _quickLogItem(context, icon: Icons.medical_services_outlined, iconColor: const Color(0xFF6B58A8), bgColor: AppColors.quickLogSymptoms, label: t(language, 'SYMPTOMS', 'علامات'), tab: 1),
                    _quickLogItem(context, icon: Icons.sentiment_satisfied_alt_rounded, iconColor: const Color(0xFF9E47BA), bgColor: AppColors.quickLogMood, label: t(language, 'MOOD', 'موڈ'), tab: 1),
                    _quickLogItem(context, icon: Icons.bubble_chart_outlined, iconColor: const Color(0xFF2E9E68), bgColor: AppColors.quickLogHormones, label: t(language, 'PCOS', 'PCOS'), tab: 2),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _nextStepCard(context, nextStep(store, lastExam, now, language: language), language),
              const SizedBox(height: 14),
              _dashboardCard(context, language),
              const SizedBox(height: 14),
              _trendsCard(context, store, language),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cycleCard(BuildContext context, CycleEngine e, String language) {
    const white = Colors.white;
    final until = e.daysUntilNext;
    final lateBy = e.isLate ? -until! : 0; // only read when isLate is true, i.e. only when until is set
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: InkWell(
        key: const Key('home_cycle'),
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.read<AppState>().setTab(1),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: AppColors.primaryBerry.withValues(alpha: 0.3), blurRadius: 22, offset: const Offset(0, 8))],
          ),
          child: e.hasHistory
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.periodOngoing ? t(language, 'Period day ${e.cycleDay}', 'پیریڈ کا دن ${e.cycleDay}') : t(language, 'Cycle day ${e.cycleDay}', 'سائیکل کا دن ${e.cycleDay}'),
                                key: const Key('home_cycle_title'),
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w700, color: white),
                              ),
                              const SizedBox(height: 4),
                              if (e.phase != null) Text(e.phase!.labelIn(language), style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: white.withValues(alpha: 0.9))),
                              const SizedBox(height: 10),
                              Text(
                                e.isLate
                                    ? t(language, 'Period expected ${plural(lateBy, 'day')} ago', 'پیریڈ کی توقع ${plural(lateBy, 'day', language: 'ur')} پہلے تھی')
                                    : t(language, 'Next period ${fmtDay(e.nextStart!)}', 'اگلا پیریڈ ${fmtDay(e.nextStart!, language: 'ur')}'),
                                key: const Key('home_cycle_next'),
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w700, color: white),
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
                          centreLabel: e.isLate ? t(language, 'DAYS LATE', 'دن تاخیر') : (until == 1 ? t(language, 'DAY TO GO', 'دن باقی') : t(language, 'DAYS TO GO', 'دن باقی')),
                        ),
                      ],
                    ),
                    if (!e.isLate) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.spa_outlined, size: 15, color: Color(0xFFFFD166)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              t(language, 'Fertile window ${fmtDay(e.fertileStart!)} to ${fmtDay(e.fertileEnd!)}',
                                  'زرخیز دورانیہ ${fmtDay(e.fertileStart!, language: 'ur')} سے ${fmtDay(e.fertileEnd!, language: 'ur')} تک'),
                              style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600, color: white.withValues(alpha: 0.92)),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    HormoneWaves(key: const Key('home_hormone_waves'), engine: e, language: language),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t(language, 'Track your cycle', 'اپنا سائیکل ٹریک کریں'), style: const TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w700, color: white)),
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
      ),
    );
  }

  Widget _snapshotCard(BuildContext context, HealthStore store, DateTime? lastExam, DateTime now, int done, String language) {
    final pcos = store.pcos;
    final scan = store.scan;
    final risk = store.breastRisk;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: AppColors.primaryBerry.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t(language, 'Your health snapshot', 'آپ کی صحت کا جائزہ'), style: const TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              done == 0 ? t(language, 'No checks yet. Tap a row to start.', 'ابھی کوئی چیک نہیں۔ شروع کرنے کے لیے ایک قطار پر ٹیپ کریں۔') : t(language, '$done of 3 checks done', '$done از 3 چیک مکمل'),
              key: const Key('home_progress'),
              style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 10),
            _row(context, const Key('home_pcos'), Icons.bubble_chart_outlined, t(language, 'PCOS risk', 'PCOS رسک'),
                pcos == null ? t(language, 'Not checked yet', 'ابھی چیک نہیں ہوا') : '${_cap(pcos.level)} · ${pcos.percent}%', pcos == null ? null : ago(pcos.date, now, language: language), 2),
            _row(context, const Key('home_scan'), Icons.monitor_heart_outlined, t(language, 'Breast ultrasound', 'بریسٹ الٹراساؤنڈ'),
                scan == null ? t(language, 'Not scanned yet', 'ابھی اسکین نہیں ہوا') : '${scan.title} · ${(scan.confidence * 100).round()}%', scan == null ? null : ago(scan.date, now, language: language), 3),
            _row(
                context,
                const Key('home_risk'),
                Icons.favorite_border_rounded,
                t(language, 'Breast cancer risk', 'بریسٹ کینسر رسک'),
                risk == null ? t(language, 'Not checked yet', 'ابھی چیک نہیں ہوا') : '${_cap(risk.level)} · ${risk.relativeRisk.toStringAsFixed(2)}× average',
                risk == null ? null : ago(risk.date, now, language: language),
                3),
            _row(context, const Key('home_exam'), Icons.self_improvement_rounded, t(language, 'Breast self-exam', 'بریسٹ سیلف ایگزام'),
                lastExam == null ? t(language, 'Not logged yet', 'ابھی درج نہیں ہوا') : _cap(ago(lastExam, now, language: language)), null, 3),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, Key key, IconData icon, String label, String value, String? when, int tab) {
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.read<AppState>().setTab(tab),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Colors.white.withValues(alpha: 0.8))),
                  const SizedBox(height: 1),
                  Text(value, style: const TextStyle(fontFamily: 'Inter', fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
            if (when != null) Text(when, style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Colors.white.withValues(alpha: 0.8))),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.8), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _dashboardCard(BuildContext context, String language) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: InkWell(
        key: const Key('home_dashboard'),
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DashboardScreen())),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(22), boxShadow: AppTheme.softShadow),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: Color(0xFFFFE1EA), shape: BoxShape.circle),
                child: const Icon(Icons.dashboard_customize_outlined, color: AppColors.primaryBerry, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t(language, 'Health dashboard', 'ہیلتھ ڈیش بورڈ'), style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const SizedBox(height: 3),
                    Text(
                      t(language, 'Cycle history, how well predictions did, symptom patterns and hormonal trends', 'سائیکل کی تاریخ، پیش گوئیوں کی درستگی، علامات کے رجحانات اور ہارمونل رجحانات'),
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textMuted, height: 1.35),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
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
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: InkWell(
        key: const Key('home_trends'),
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TrendsScreen())),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(22), boxShadow: AppTheme.softShadow),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: Color(0xFFE9E3F5), shape: BoxShape.circle),
                child: const Icon(Icons.show_chart_rounded, color: Color(0xFF6B58A8), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t(language, 'My trends', 'میرے رجحانات'), style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const SizedBox(height: 3),
                    Text(
                      week == 0
                          ? t(language, 'Mood, sleep, stress, energy and symptoms over time', 'وقت کے ساتھ موڈ، نیند، تناؤ، توانائی اور علامات')
                          : t(language, '$week of the last 7 days logged. See your mood, sleep and stress patterns', 'پچھلے 7 دنوں میں سے $week دن درج۔ اپنے موڈ، نیند اور تناؤ کے رجحانات دیکھیں'),
                      key: const Key('home_trends_text'),
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textMuted, height: 1.35),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nextStepCard(BuildContext context, String text, String language) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: InkWell(
        key: const Key('home_next_step'),
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.read<AppState>().setTab(4),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.aiInsightBg, borderRadius: BorderRadius.circular(22)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: Color(0xFFFFB7CB), shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryBerry, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t(language, 'Your next step', 'آپ کا اگلا قدم'), style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const SizedBox(height: 6),
                    Text(text, style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, color: Color(0xFF423B4E), height: 1.35)),
                    const SizedBox(height: 8),
                    Text(t(language, 'Ask your companion', 'اپنے کمپینین سے پوچھیں'), style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryBerry)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickLogItem(BuildContext context, {required IconData icon, required Color iconColor, required Color bgColor, required String label, required int tab}) {
    return GestureDetector(
      onTap: () => context.read<AppState>().setTab(tab),
      child: Column(
        children: [
          Container(width: 60, height: 60, decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 26)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDark, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}
