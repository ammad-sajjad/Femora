import 'package:flutter/material.dart';

import '../models/trends.dart';
import '../theme/app_theme.dart';
import 'cycle_widgets.dart' show fmtDay;
import 'mini_charts.dart';

const moodColor = AppColors.primaryBerry;
const sleepColor = Color(0xFF6B58A8);
const stressColor = Color(0xFFE08A1E);
const energyColor = Color(0xFF2E9E68);

TextStyle _s(double size, {FontWeight w = FontWeight.w400, Color c = AppColors.textDark, double? h}) =>
    TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: w, color: c, height: h);

/// Labels under a chart: the first day, the middle and today.
List<AxisLabel> dayLabels(TrendStats t) {
  final n = t.days;
  if (n <= 1) return [(0, fmtDay(t.start))];
  DateTime at(int i) => DateTime(t.start.year, t.start.month, t.start.day + i);
  return [(0, fmtDay(t.start)), (n ~/ 2, fmtDay(at(n ~/ 2))), (n - 1, 'Today')];
}

/// White card with a title, used by every chart.
class TrendCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const TrendCard({super.key, required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(22), boxShadow: AppTheme.softShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _s(15, w: FontWeight.w700)),
            if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: _s(11.5, c: AppColors.textMuted))),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}

/// The headline numbers for the period.
class TrendSummaryTiles extends StatelessWidget {
  final TrendStats stats;
  const TrendSummaryTiles({super.key, required this.stats});

  Widget _tile(String label, String value, Color color, {Key? key}) => Container(
        key: key,
        width: 104,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _s(11, c: AppColors.textMuted)),
            const SizedBox(height: 3),
            Text(value, style: _s(16, w: FontWeight.w700, c: color)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = stats;
    return Padding(
      key: const Key('trend_tiles'),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _tile('Days logged', '${t.logged} of ${t.days}', AppColors.primaryBerry, key: const Key('tile_logged')),
          _tile('Mood', t.avgMood == null ? '-' : TrendStats.moodLabel(t.avgMood!), moodColor, key: const Key('tile_mood')),
          _tile('Sleep', t.avgSleep == null ? '-' : '${t.avgSleep!.toStringAsFixed(1)} h', sleepColor, key: const Key('tile_sleep')),
          _tile('Stress', t.avgStress == null ? '-' : '${t.avgStress!.toStringAsFixed(1)} / 5', stressColor, key: const Key('tile_stress')),
          _tile('Energy', t.avgEnergy == null ? '-' : '${t.avgEnergy!.toStringAsFixed(1)} / 5', energyColor, key: const Key('tile_energy')),
        ],
      ),
    );
  }
}

class MoodTrendCard extends StatelessWidget {
  final TrendStats stats;
  const MoodTrendCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) => TrendCard(
        key: const Key('trend_mood'),
        title: 'Mood',
        subtitle: 'From bad to great, on the days you logged it',
        child: stats.moodLogged == 0
            ? Text('No mood logged in this period.', style: _s(12.5, c: AppColors.textMuted))
            : LineChart(
                series: [stats.moodSeries],
                colors: const [moodColor],
                minY: 1,
                maxY: 5,
                yTicks: const [(1, 'Bad'), (2, 'Low'), (3, 'Okay'), (4, 'Good'), (5, 'Great')],
                xLabels: dayLabels(stats),
                semantics: 'Mood over the last ${stats.days} days, average ${stats.avgMood == null ? 'not logged' : TrendStats.moodLabel(stats.avgMood!)}',
              ),
      );
}

class SleepTrendCard extends StatelessWidget {
  final TrendStats stats;
  const SleepTrendCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) => TrendCard(
        key: const Key('trend_sleep'),
        title: 'Sleep',
        subtitle: 'Hours a night. The shaded band is the usual 7 to 9 hours',
        child: stats.sleepLogged == 0
            ? Text('No sleep logged in this period.', style: _s(12.5, c: AppColors.textMuted))
            : BarChart(
                values: stats.sleepSeries,
                maxY: 12,
                yTicks: const [(0, '0 h'), (4, '4 h'), (8, '8 h'), (12, '12 h')],
                band: (TrendStats.sleepLow, TrendStats.sleepHigh),
                barColor: sleepColor,
                xLabels: dayLabels(stats),
                semantics: 'Sleep over the last ${stats.days} days, average ${stats.avgSleep?.toStringAsFixed(1) ?? 'not logged'} hours',
              ),
      );
}

class StressEnergyCard extends StatelessWidget {
  final TrendStats stats;
  const StressEnergyCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) => TrendCard(
        key: const Key('trend_stress'),
        title: 'Stress and energy',
        subtitle: '1 is lowest, 5 is highest',
        child: (stats.stressLogged == 0 && stats.avgEnergy == null)
            ? Text('No stress or energy logged in this period.', style: _s(12.5, c: AppColors.textMuted))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LineChart(
                    series: [stats.stressSeries, stats.energySeries],
                    colors: const [stressColor, energyColor],
                    minY: 1,
                    maxY: 5,
                    yTicks: const [(1, '1'), (2, '2'), (3, '3'), (4, '4'), (5, '5')],
                    xLabels: dayLabels(stats),
                    semantics: 'Stress and energy over the last ${stats.days} days',
                  ),
                  const SizedBox(height: 8),
                  const ChartLegend(items: [(stressColor, 'Stress'), (energyColor, 'Energy')]),
                ],
              ),
      );
}

class SymptomFrequencyCard extends StatelessWidget {
  final TrendStats stats;
  const SymptomFrequencyCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) => TrendCard(
        key: const Key('trend_symptoms'),
        title: 'Symptoms',
        subtitle: 'Number of days each one was logged',
        child: stats.topSymptoms.isEmpty
            ? Text('No symptoms logged in this period.', style: _s(12.5, c: AppColors.textMuted))
            : HBarList(items: stats.topSymptoms.take(6).toList(), total: stats.logged),
      );
}

class TrendInsightsCard extends StatelessWidget {
  final TrendStats stats;
  const TrendInsightsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('trend_insights'),
        margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.aiInsightBg, borderRadius: BorderRadius.circular(22)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What this shows', style: _s(15, w: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final line in stats.insights)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.auto_awesome_rounded, size: 15, color: AppColors.primaryBerry)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(line, style: _s(12.8, h: 1.4))),
                  ],
                ),
              ),
          ],
        ),
      );
}
