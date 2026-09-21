import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cycle_engine.dart';
import '../models/hormone_insights.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'mini_charts.dart';
import 'trend_cards.dart' show TrendCard;

const estrogenColor = Color(0xFFE0508A);
const progesteroneColor = Color(0xFF6B58A8);
const lhColor = Color(0xFF2E9E68);

TextStyle _s(double size, {FontWeight w = FontWeight.w400, Color c = AppColors.textDark, double? h}) =>
    TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: w, color: c, height: h);

String phaseShort(CyclePhase p) => switch (p) {
      CyclePhase.menstrual => 'Period',
      CyclePhase.follicular => 'Follicular',
      CyclePhase.ovulation => 'Ovulation',
      CyclePhase.luteal => 'Luteal',
    };

/// Where she is in her cycle, and what the hormones are typically doing.
class PhaseCard extends StatelessWidget {
  final HormoneInsights insights;
  const PhaseCard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final e = insights.engine;
    final phase = e.phase;
    final info = insights.currentInfo;
    return Container(
      key: const Key('hi_phase'),
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(24), boxShadow: AppTheme.softShadow),
      child: (phase == null || info == null)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hormonal insights', style: _s(20, w: FontWeight.w700, c: Colors.white)),
                const SizedBox(height: 6),
                Text('Log the first day of your last period in the Cycle tab and Femora will show what your hormones are typically doing today, and how your symptoms follow your cycle.',
                    key: const Key('hi_empty'), style: _s(13, c: Colors.white, h: 1.4)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(phase.label, key: const Key('hi_phase_title'), style: _s(20, w: FontWeight.w700, c: Colors.white)),
                Text(e.periodOngoing ? 'Period day ${e.cycleDay}' : 'Cycle day ${e.cycleDay}', style: _s(12.5, c: Colors.white.withValues(alpha: 0.85))),
                const SizedBox(height: 10),
                Text(info.hormones, style: _s(13, c: Colors.white, h: 1.4)),
                const SizedBox(height: 8),
                Text(info.feelings, style: _s(12.5, c: Colors.white.withValues(alpha: 0.92), h: 1.4)),
              ],
            ),
    );
  }
}

/// The textbook hormone curves for a cycle as long as hers, with a marker for today.
class HormoneCurveCard extends StatelessWidget {
  final CycleEngine engine;
  const HormoneCurveCard({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    final len = engine.hasHistory ? engine.lengthDays : kTypicalLength;
    final c = typicalHormoneCurves(len);
    final ov = len - 13;
    final today = engine.hasHistory && engine.cycleDay >= 1 && engine.cycleDay <= len ? engine.cycleDay - 1 : null;
    return TrendCard(
      key: const Key('hi_curves'),
      title: 'Hormones through your cycle',
      subtitle: 'The typical pattern for a cycle of $len days. These are textbook shapes, not your measured levels.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LineChart(
            series: [c.estrogen, c.progesterone, c.lh],
            colors: const [estrogenColor, progesteroneColor, lhColor],
            minY: 0,
            maxY: 1.05,
            yTicks: const [(0, 'Low'), (0.5, 'Mid'), (1, 'High')],
            xLabels: [(0, 'Day 1'), (ov, 'Ovulation'), (len - 1, 'Day $len')],
            marker: today,
            dots: false,
            height: 150,
            semantics: 'Typical estrogen, progesterone and LH levels across a $len day cycle${today == null ? '' : ', you are on day ${engine.cycleDay}'}',
          ),
          const SizedBox(height: 8),
          const ChartLegend(items: [(estrogenColor, 'Estrogen'), (progesteroneColor, 'Progesterone'), (lhColor, 'LH')]),
          if (today != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('The dashed line marks today (day ${engine.cycleDay}).', style: _s(11, c: AppColors.textMuted))),
        ],
      ),
    );
  }

  static const kTypicalLength = 29;
}

/// How often each symptom was logged in each phase (percent of the logged days in that phase).
class PhaseSymptomTable extends StatelessWidget {
  final HormoneInsights insights;
  const PhaseSymptomTable({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final totals = <String, int>{};
    for (final st in insights.byPhase.values) {
      st.symptomDays.forEach((k, v) => totals[k] = (totals[k] ?? 0) + v);
    }
    final names = (totals.keys.toList()..sort((a, b) => totals[b]! != totals[a]! ? totals[b]!.compareTo(totals[a]!) : a.compareTo(b))).take(6).toList();
    const phases = CyclePhase.values;
    Widget cell(String text, {Color? bg, bool dim = false, bool bold = false, Key? key}) => Expanded(
          child: Container(
            key: key,
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.symmetric(vertical: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Text(text, style: _s(11.5, w: bold ? FontWeight.w700 : FontWeight.w500, c: dim ? AppColors.textLight : AppColors.textDark)),
          ),
        );
    return TrendCard(
      key: const Key('hi_table'),
      title: 'Your symptoms by phase',
      subtitle: 'Share of the days you logged in each phase. Phases with under ${HormoneInsights.minPhaseDays} logged days are left blank.',
      child: names.isEmpty
          ? Text('No symptoms logged inside your cycles yet. Log symptoms through a full cycle to see them by phase.', style: _s(12.5, c: AppColors.textMuted))
          : Column(
              children: [
                Row(children: [
                  const SizedBox(width: 78),
                  for (final p in phases) cell(phaseShort(p), bold: true),
                ]),
                Row(children: [
                  const SizedBox(width: 78),
                  for (final p in phases) cell('${insights.byPhase[p]!.days} d', dim: true),
                ]),
                for (final s in names)
                  Row(children: [
                    SizedBox(width: 78, child: Text(s, style: _s(12), overflow: TextOverflow.ellipsis)),
                    for (final p in phases)
                      () {
                        final st = insights.byPhase[p]!;
                        if (st.days < HormoneInsights.minPhaseDays) return cell('·', dim: true, key: Key('hi_cell_${s}_${p.name}'));
                        final share = st.share(s);
                        return cell('${(share * 100).round()}%',
                            bg: AppColors.primaryBerry.withValues(alpha: (share * 0.7).clamp(0.0, 0.7)), bold: share >= 0.5, key: Key('hi_cell_${s}_${p.name}'));
                      }(),
                  ]),
              ],
            ),
    );
  }
}

/// A list of notes: patterns she may recognise, or things worth checking with a doctor.
class InsightNotesCard extends StatelessWidget {
  final String title;
  final List<InsightNote> notes;
  final Color background;
  final String? emptyText;
  const InsightNotesCard({super.key, required this.title, required this.notes, this.background = AppColors.aiInsightBg, this.emptyText});

  @override
  Widget build(BuildContext context) {
    final pcos = notes.any((n) => n.id == 'pcos_pattern' || n.id == 'acne' || n.id == 'hair');
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _s(15, w: FontWeight.w700)),
          const SizedBox(height: 8),
          if (notes.isEmpty && emptyText != null) Text(emptyText!, key: const Key('hi_need_data'), style: _s(12.5, c: AppColors.textMuted, h: 1.4)),
          for (final n in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(n.seeDoctor ? Icons.medical_services_outlined : Icons.auto_awesome_rounded, size: 17, color: n.seeDoctor ? const Color(0xFF9E1B46) : AppColors.primaryBerry),
                  const SizedBox(width: 8),
                  Expanded(child: Text(n.text, key: Key('note_${n.id}'), style: _s(12.8, h: 1.4))),
                ],
              ),
            ),
          if (pcos)
            TextButton.icon(
              key: const Key('hi_pcos'),
              onPressed: () {
                context.read<AppState>().setTab(2);
                Navigator.maybePop(context);
              },
              icon: const Icon(Icons.bubble_chart_outlined, size: 18),
              label: Text('Open the PCOS check', style: _s(12.5, w: FontWeight.w700, c: AppColors.primaryBerry)),
            ),
        ],
      ),
    );
  }
}

/// What tends to help in the current phase.
class PhaseTipsCard extends StatelessWidget {
  final HormoneInsights insights;
  const PhaseTipsCard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final info = insights.currentInfo;
    final phase = insights.engine.phase;
    if (info == null || phase == null) return const SizedBox.shrink();
    return TrendCard(
      key: const Key('hi_tips'),
      title: 'Looking after yourself: ${phase.label.toLowerCase()}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in info.tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF2E9E68))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t, style: _s(12.8, h: 1.4))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
