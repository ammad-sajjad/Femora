import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cycle_engine.dart';
import '../models/health_store.dart';
import '../models/models.dart';
import '../models/self_exam.dart';
import '../theme/app_theme.dart';
import '../widgets/cycle_ring_widget.dart';
import '../widgets/cycle_widgets.dart';
import '../widgets/femora_header.dart';

/// Home: everything here comes from what the user has actually done in the app (the on-device [HealthStore]).
class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  static String greeting(DateTime now) => now.hour < 12 ? 'Good morning' : (now.hour < 17 ? 'Good afternoon' : 'Good evening');

  static String ago(DateTime date, DateTime now) {
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(date.year, date.month, date.day)).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    return '$days days ago';
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// One short, rule-based suggestion for what to do next. The most important thing comes first.
  static String nextStep(HealthStore store, DateTime? lastExam, DateTime now) {
    final risk = store.breastRisk;
    if (risk != null && risk.redFlags.isNotEmpty) {
      return 'You reported ${risk.redFlags.first.toLowerCase()}. Please arrange to see a doctor; your companion can help you prepare what to say.';
    }
    if (store.scan?.prediction == 'malignant') {
      return 'Your ultrasound screening was flagged as suspicious. This is not a diagnosis, but please book a breast specialist visit.';
    }
    final cycleFlag = CycleEngine(store.periods, now).flags.where((f) => f.seeDoctor).toList();
    if (cycleFlag.isNotEmpty) return cycleFlag.first.text;
    if (store.pcos?.level == 'high') {
      return 'Your PCOS screening was high. A gynaecologist can confirm it; ask your companion what tests to expect.';
    }
    final today = DateTime(now.year, now.month, now.day);
    final loggedToday = store.logs.any((l) => DateTime(l.date.year, l.date.month, l.date.day) == today);
    if (!loggedToday) return 'Log how you feel today (symptoms and mood) so your companion and your report stay up to date.';
    if (lastExam == null || now.difference(lastExam).inDays >= 30) return 'It is time for your monthly breast self-exam. The Breast tab has a step-by-step guide.';
    if (store.periods.isEmpty) return 'Log the first day of your last period in the Cycle tab so Femora can predict your next one.';
    if (store.pcos == null && store.breastRisk == null && store.scan == null) return 'Take a first check: PCOS risk or the breast questionnaire takes about two minutes.';
    return 'You are all caught up. Ask your companion anything about your results.';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final lastExam = context.watch<SelfExamState>().lastExam;
    final now = context.read<AppState>().now();
    final name = store.profile.firstName;
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
                      name.isEmpty ? greeting(now) : '${greeting(now)}, $name',
                      key: const Key('home_greeting'),
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textDark, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    const Text('Here is your health overview.', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _cycleCard(context, CycleEngine(store.periods, now)),
              const SizedBox(height: 14),
              _snapshotCard(context, store, lastExam, now, done),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text('Quick Log', style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _quickLogItem(context, icon: Icons.water_drop_rounded, iconColor: const Color(0xFFE53935), bgColor: AppColors.quickLogPeriod, label: 'PERIOD', tab: 1),
                    _quickLogItem(context, icon: Icons.medical_services_outlined, iconColor: const Color(0xFF6B58A8), bgColor: AppColors.quickLogSymptoms, label: 'SYMPTOMS', tab: 1),
                    _quickLogItem(context, icon: Icons.sentiment_satisfied_alt_rounded, iconColor: const Color(0xFF9E47BA), bgColor: AppColors.quickLogMood, label: 'MOOD', tab: 1),
                    _quickLogItem(context, icon: Icons.bubble_chart_outlined, iconColor: const Color(0xFF2E9E68), bgColor: AppColors.quickLogHormones, label: 'PCOS', tab: 2),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _nextStepCard(context, nextStep(store, lastExam, now)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cycleCard(BuildContext context, CycleEngine e) {
    const white = Colors.white;
    final until = e.daysUntilNext;
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
              ? Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.periodOngoing ? 'Period day ${e.cycleDay}' : 'Cycle day ${e.cycleDay}',
                            key: const Key('home_cycle_title'),
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w700, color: white),
                          ),
                          const SizedBox(height: 4),
                          if (e.phase != null) Text(e.phase!.label, style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: white.withValues(alpha: 0.9))),
                          const SizedBox(height: 10),
                          Text(
                            e.isLate ? 'Period expected ${plural(-until!, 'day')} ago' : 'Next period ${fmtDay(e.nextStart!)}',
                            key: const Key('home_cycle_next'),
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w700, color: white),
                          ),
                          if (!e.isLate)
                            Text('Fertile window ${fmtDay(e.fertileStart!)} to ${fmtDay(e.fertileEnd!)}', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: white.withValues(alpha: 0.85))),
                        ],
                      ),
                    ),
                    CycleRingWidget(days: e.isLate ? '${-until!}' : '$until', label: e.isLate ? 'DAYS LATE' : (until == 1 ? 'DAY TO GO' : 'DAYS TO GO')),
                  ],
                )
              : const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Track your cycle', style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w700, color: white)),
                    SizedBox(height: 6),
                    Text('Log the first day of your last period and Femora will predict your next one. Tap here to start.',
                        key: Key('home_cycle_empty'), style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: white, height: 1.4)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _snapshotCard(BuildContext context, HealthStore store, DateTime? lastExam, DateTime now, int done) {
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
            const Text('Your health snapshot', style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              done == 0 ? 'No checks yet. Tap a row to start.' : '$done of 3 checks done',
              key: const Key('home_progress'),
              style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 10),
            _row(context, const Key('home_pcos'), Icons.bubble_chart_outlined, 'PCOS risk', pcos == null ? 'Not checked yet' : '${_cap(pcos.level)} · ${pcos.percent}%', pcos == null ? null : ago(pcos.date, now), 2),
            _row(context, const Key('home_scan'), Icons.monitor_heart_outlined, 'Breast ultrasound', scan == null ? 'Not scanned yet' : '${scan.title} · ${(scan.confidence * 100).round()}%', scan == null ? null : ago(scan.date, now), 3),
            _row(context, const Key('home_risk'), Icons.favorite_border_rounded, 'Breast cancer risk', risk == null ? 'Not checked yet' : '${_cap(risk.level)} · ${risk.relativeRisk.toStringAsFixed(2)}× average', risk == null ? null : ago(risk.date, now), 3),
            _row(context, const Key('home_exam'), Icons.self_improvement_rounded, 'Breast self-exam', lastExam == null ? 'Not logged yet' : ago(lastExam, now)[0].toUpperCase() + ago(lastExam, now).substring(1), null, 3),
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

  Widget _nextStepCard(BuildContext context, String text) {
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
                    const Text('Your next step', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const SizedBox(height: 6),
                    Text(text, style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, color: Color(0xFF423B4E), height: 1.35)),
                    const SizedBox(height: 8),
                    const Text('Ask your companion', style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryBerry)),
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
