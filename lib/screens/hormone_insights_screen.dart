import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/health_store.dart';
import '../models/hormone_insights.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/hormone_cards.dart';

/// Scope 6.6: how symptoms follow the cycle, what the hormones are typically doing, and symptoms worth checking.
class HormoneInsightsScreen extends StatelessWidget {
  const HormoneInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final engine = store.cycle;
    final ins = HormoneInsights(engine, store.logs, store.now());
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        leading: IconButton(key: const Key('insights_back'), icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.maybePop(context)),
        title: const Text('Hormonal insights', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            PhaseCard(insights: ins),
            if (!engine.hasHistory)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                child: FilledButton(
                  key: const Key('hi_log_period'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBerry, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    context.read<AppState>().setTab(1);
                    Navigator.maybePop(context);
                  },
                  child: const Text('Log my period'),
                ),
              ),
            if (ins.flags.isNotEmpty)
              KeyedSubtree(
                key: const Key('hi_flags'),
                child: InsightNotesCard(title: 'Worth checking', notes: ins.flags, background: const Color(0xFFFCE4EC)),
              ),
            HormoneCurveCard(engine: engine),
            if (engine.hasHistory) ...[
              PhaseSymptomTable(insights: ins),
              KeyedSubtree(
                key: const Key('hi_patterns'),
                child: InsightNotesCard(
                  title: 'Patterns in your log',
                  notes: ins.patterns,
                  emptyText: ins.hasPatternData
                      ? 'No clear pattern across your phases yet. That is normal: many women do not have one.'
                      : 'Log your symptoms, mood and energy through at least two cycles (about ${HormoneInsights.minPhaseDays * 2} days inside them) and Femora will look for patterns.',
                ),
              ),
              PhaseTipsCard(insights: ins),
            ],
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text(
                'This is general information and your own logged patterns. It is not a diagnosis. If a symptom worries you, or keeps coming back, please talk to a doctor.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textLight, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
