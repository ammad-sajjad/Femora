import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/analytics.dart';
import '../models/health_store.dart';
import '../models/hormone_insights.dart';
import '../models/trends.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard_cards.dart';
import '../widgets/hormone_cards.dart';
import '../widgets/trend_cards.dart';
import 'hormone_insights_screen.dart';
import 'reminders_screen.dart';
import 'report_screen.dart';
import 'trends_screen.dart';

/// Scope 6.9: one place to see cycle history, symptom patterns, hormonal trends and how well the predictions did,
/// with a way to open the downloadable health report.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Widget _link(BuildContext context, Key key, IconData icon, String label, Widget screen) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
        child: OutlinedButton.icon(
          key: key,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryBerry,
            side: const BorderSide(color: AppColors.primaryBerry),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen)),
          icon: Icon(icon),
          label: Text(label, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final engine = store.cycle;
    final history = CycleHistory.of(engine);
    final backtest = CycleBacktest.compute(store.periods);
    final stats = TrendStats.compute(store.logs, store.now(), 30);
    final insights = HormoneInsights(engine, store.logs, store.now());
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        leading: IconButton(key: const Key('dashboard_back'), icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.maybePop(context)),
        title: const Text('Health dashboard', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            CycleAtAGlance(engine: engine, history: history),
            const DashboardSectionTitle('Your cycle'),
            CycleHistoryChartCard(history: history),
            PredictionAnalyticsCard(backtest: backtest),
            const DashboardSectionTitle('Symptoms and mood, last 30 days'),
            const SizedBox(height: 12),
            TrendSummaryTiles(stats: stats),
            MoodTrendCard(stats: stats),
            SleepTrendCard(stats: stats),
            StressEnergyCard(stats: stats),
            SymptomFrequencyCard(stats: stats),
            const DashboardSectionTitle('Hormonal trends'),
            HormoneCurveCard(engine: engine),
            PhaseAveragesCard(insights: insights),
            if (engine.hasHistory) PhaseSymptomTable(insights: insights),
            if (insights.flags.isNotEmpty || insights.patterns.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Text(
                  '${insights.flags.length} symptom${insights.flags.length == 1 ? '' : 's'} worth checking and ${insights.patterns.length} pattern${insights.patterns.length == 1 ? '' : 's'} found. Open Hormonal insights for the details.',
                  key: const Key('dash_insight_count'),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
                ),
              ),
            const DashboardSectionTitle('Results'),
            const SizedBox(height: 0),
            LatestResultsCard(store: store),
            const DashboardSectionTitle('More'),
            _link(context, const Key('dash_open_report'), Icons.description_outlined, 'Health report (PDF)', const ReportScreen()),
            _link(context, const Key('dash_open_trends'), Icons.show_chart_rounded, 'My trends (7, 30 or 90 days)', const TrendsScreen()),
            _link(context, const Key('dash_open_insights'), Icons.bubble_chart_outlined, 'Hormonal insights', const HormoneInsightsScreen()),
            _link(context, const Key('dash_open_reminders'), Icons.notifications_active_outlined, 'Reminders', const RemindersScreen()),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text('Everything here comes from what you logged and the checks you did. It is not a diagnosis; talk to a doctor about anything that worries you.',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textLight, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}
