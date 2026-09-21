import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/analytics.dart';
import '../models/cycle_engine.dart';
import '../models/health_store.dart';
import '../models/hormone_insights.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'cycle_widgets.dart' show fmtDay, plural;
import 'mini_charts.dart';
import 'trend_cards.dart';

TextStyle _s(double size, {FontWeight w = FontWeight.w400, Color c = AppColors.textDark, double? h}) =>
    TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: w, color: c, height: h);

class DashboardSectionTitle extends StatelessWidget {
  final String text;
  const DashboardSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 0), child: Text(text, style: _s(18, w: FontWeight.w700)));
}

/// The four headline cycle numbers.
class CycleAtAGlance extends StatelessWidget {
  final CycleEngine engine;
  final CycleHistory history;
  const CycleAtAGlance({super.key, required this.engine, required this.history});

  Widget _tile(String label, String value, Color color, Key key) => Container(
        key: key,
        width: 156,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _s(11.5, c: AppColors.textMuted)),
            const SizedBox(height: 3),
            Text(value, style: _s(17, w: FontWeight.w700, c: color)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final e = engine;
    final until = e.daysUntilNext;
    final next = !e.hasHistory
        ? '-'
        : e.isLate
            ? '${plural(-until!, 'day')} late'
            : (until == 0 ? 'Today' : 'In ${plural(until!, 'day')}');
    return Padding(
      key: const Key('dash_glance'),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _tile('Cycle day', e.hasHistory ? '${e.cycleDay}${e.phase == null ? '' : ' · ${e.phase!.label.split(' ').first}'}' : '-', AppColors.primaryBerry, const Key('glance_day')),
          _tile('Next period', next, const Color(0xFF6B58A8), const Key('glance_next')),
          _tile('Average cycle', history.average == null ? '-' : '${history.average!.toStringAsFixed(1)} days', const Color(0xFFE08A1E), const Key('glance_avg')),
          _tile('Regularity', e.regularity == 'not enough cycles yet' ? 'Needs 3 cycles' : e.regularity, const Color(0xFF2E9E68), const Key('glance_regularity')),
        ],
      ),
    );
  }
}

/// Bars of the last cycle lengths, with the usual 21 to 35 day band.
class CycleHistoryChartCard extends StatelessWidget {
  final CycleHistory history;
  const CycleHistoryChartCard({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final ls = history.lastLengths(12);
    final st = history.lastStarts(12);
    final maxY = math.max(42.0, ((ls.isEmpty ? 0 : ls.reduce(math.max)) + 4).toDouble());
    return TrendCard(
      key: const Key('dash_cycle_history'),
      title: 'Cycle history',
      subtitle: 'Length of your last ${ls.length} cycles in days. The shaded band is the usual 21 to 35.',
      child: ls.isEmpty
          ? Text('Log at least two periods to see how long your cycles are.', key: const Key('dash_no_history'), style: _s(12.5, c: AppColors.textMuted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BarChart(
                  values: [for (final l in ls) l.toDouble()],
                  maxY: maxY,
                  yTicks: [(0, '0'), (14, '14'), (28, '28'), (maxY >= 42 ? 42 : maxY, maxY >= 42 ? '42' : '${maxY.round()}')],
                  band: (21, 35),
                  barColor: AppColors.primaryBerry,
                  xLabels: [(0, fmtDay(st.first)), if (ls.length > 2) (ls.length - 1, fmtDay(st.last))],
                  semantics: 'Bars of your last ${ls.length} cycle lengths, average ${history.average?.toStringAsFixed(1)} days',
                ),
                const SizedBox(height: 8),
                Text(
                  'Average ${history.average!.toStringAsFixed(1)} days, shortest ${history.shortest}, longest ${history.longest}. '
                  '${history.outsideNormal == 0 ? 'All within 21 to 35 days.' : '${history.outsideNormal} of ${history.lengths.length} outside 21 to 35 days.'}',
                  key: const Key('dash_history_text'),
                  style: _s(12, c: AppColors.textMuted, h: 1.4),
                ),
              ],
            ),
    );
  }
}

/// How the prediction would have done on her own past cycles.
class PredictionAnalyticsCard extends StatelessWidget {
  final CycleBacktest backtest;
  const PredictionAnalyticsCard({super.key, required this.backtest});

  @override
  Widget build(BuildContext context) {
    final b = backtest;
    final maxErr = b.points.isEmpty ? 5 : math.max(b.points.map((p) => math.max(p.error, p.populationError)).reduce(math.max), 4);
    return TrendCard(
      key: const Key('dash_analytics'),
      title: 'Prediction check',
      subtitle: 'How far off the predicted cycle length was, cycle by cycle, using only what was logged before it',
      child: !b.enough
          ? Text(
              b.n == 0 ? 'Log at least four periods and Femora will show how well it predicted your cycles.' : 'Only ${plural(b.n, 'cycle')} to check so far. Three are needed.',
              key: const Key('dash_analytics_empty'),
              style: _s(12.5, c: AppColors.textMuted, h: 1.4),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LineChart(
                  series: [
                    [for (final p in b.points) p.error.toDouble()],
                    [for (final p in b.points) p.populationError.toDouble()],
                  ],
                  colors: const [AppColors.primaryBerry, Color(0xFFB9B2C6)],
                  minY: 0,
                  maxY: maxErr + 1.0,
                  yTicks: [for (var v = 0; v <= maxErr; v += math.max(1, (maxErr / 4).ceil())) (v.toDouble(), '$v d')],
                  xLabels: [(0, fmtDay(b.points.first.start)), if (b.n > 2) (b.n - 1, fmtDay(b.points.last.start))],
                  semantics: 'Error in days of the predicted cycle length for each of your ${b.n} cycles',
                ),
                const SizedBox(height: 8),
                const ChartLegend(items: [(AppColors.primaryBerry, 'Femora prediction'), (Color(0xFFB9B2C6), 'Average woman (29 days)')]),
                const SizedBox(height: 8),
                Text(b.summary!, key: const Key('dash_analytics_text'), style: _s(12.5, h: 1.4)),
              ],
            ),
    );
  }
}

/// Average mood and energy in each phase of the cycle.
class PhaseAveragesCard extends StatelessWidget {
  final HormoneInsights insights;
  const PhaseAveragesCard({super.key, required this.insights});

  Widget _bar(double? value, Color color) => Expanded(
        child: LayoutBuilder(
          builder: (context, box) => Stack(children: [
            Container(height: 9, decoration: BoxDecoration(color: const Color(0xFFEDE8F1), borderRadius: BorderRadius.circular(5))),
            if (value != null) Container(height: 9, width: box.maxWidth * ((value - 1) / 4).clamp(0.04, 1.0), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5))),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final phases = [for (final p in CyclePhase.values) if (insights.byPhase[p]!.days >= HormoneInsights.minPhaseDays) insights.byPhase[p]!];
    return TrendCard(
      key: const Key('dash_phase_avgs'),
      title: 'Mood and energy through your cycle',
      subtitle: 'Average of the days you logged in each phase (5 days needed)',
      child: phases.isEmpty
          ? Text('Log your mood and energy through a cycle to see how they follow it.', key: const Key('dash_phase_empty'), style: _s(12.5, c: AppColors.textMuted))
          : Column(
              children: [
                for (final st in phases)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        SizedBox(width: 82, child: Text(st.phase.label.split(' ').first, style: _s(12.5))),
                        _bar(st.avgMood, moodColor),
                        const SizedBox(width: 6),
                        SizedBox(width: 26, child: Text(st.avgMood?.toStringAsFixed(1) ?? '-', style: _s(11.5, w: FontWeight.w700, c: moodColor))),
                        _bar(st.avgEnergy, energyColor),
                        const SizedBox(width: 6),
                        SizedBox(width: 26, child: Text(st.avgEnergy?.toStringAsFixed(1) ?? '-', style: _s(11.5, w: FontWeight.w700, c: energyColor))),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                const Align(alignment: Alignment.centerLeft, child: ChartLegend(items: [(moodColor, 'Mood (1 to 5)'), (energyColor, 'Energy (1 to 5)')])),
              ],
            ),
    );
  }
}

/// The latest result of each check, and a way back to it.
class LatestResultsCard extends StatelessWidget {
  final HealthStore store;
  const LatestResultsCard({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final now = store.now();
    Widget row(Key key, String label, String value, int tab) => InkWell(
          key: key,
          onTap: () {
            context.read<AppState>().setTab(tab);
            Navigator.maybePop(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(child: Text(label, style: _s(13, c: AppColors.textMuted))),
              Text(value, style: _s(13, w: FontWeight.w700)),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
            ]),
          ),
        );
    final p = store.pcos;
    final sc = store.scan;
    final r = store.breastRisk;
    return TrendCard(
      key: const Key('dash_results'),
      title: 'Latest results',
      child: Column(
        children: [
          row(const Key('dash_pcos'), 'PCOS risk', p == null ? 'Not checked yet' : '${p.level[0].toUpperCase()}${p.level.substring(1)} · ${p.percent}% · ${HealthStore.ago(p.date, now)}', 2),
          row(const Key('dash_scan'), 'Breast ultrasound', sc == null ? 'Not scanned yet' : '${sc.title} · ${HealthStore.ago(sc.date, now)}', 3),
          row(const Key('dash_risk'), 'Breast cancer risk', r == null ? 'Not checked yet' : '${r.level[0].toUpperCase()}${r.level.substring(1)} · ${r.relativeRisk.toStringAsFixed(2)}× average', 3),
        ],
      ),
    );
  }
}
