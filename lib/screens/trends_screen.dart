import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/health_store.dart';
import '../models/models.dart';
import '../models/trends.dart';
import '../theme/app_theme.dart';
import '../widgets/trend_cards.dart';

/// Charts and plain-language notes built from the daily log: mood, sleep, stress, energy and symptoms.
class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final stats = TrendStats.compute(store.logs, store.now(), _days);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        leading: IconButton(key: const Key('trends_back'), icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.maybePop(context)),
        title: const Text('My trends', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final d in const [7, 30, 90])
                    ChoiceChip(
                      key: Key('trend_range_$d'),
                      label: Text('$d days'),
                      selected: _days == d,
                      selectedColor: const Color(0xFFFFDFE8),
                      onSelected: (_) => setState(() => _days = d),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (stats.logged == 0) _empty(context) else ...[
              TrendSummaryTiles(stats: stats),
              MoodTrendCard(stats: stats),
              SleepTrendCard(stats: stats),
              StressEnergyCard(stats: stats),
              SymptomFrequencyCard(stats: stats),
              TrendInsightsCard(stats: stats),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Text('These patterns come only from what you logged. They are not a diagnosis; talk to a doctor about anything that worries you.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textLight, height: 1.4)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) => Container(
        key: const Key('trend_empty'),
        margin: const EdgeInsets.symmetric(horizontal: 18),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(22), boxShadow: AppTheme.softShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nothing to show yet', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 6),
            const Text('Log your symptoms, mood, sleep, stress and energy for a few days in the Cycle tab and your trends will appear here.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textMuted, height: 1.4)),
            const SizedBox(height: 14),
            FilledButton(
              key: const Key('trend_log_today'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBerry),
              onPressed: () {
                context.read<AppState>().setTab(1);
                Navigator.maybePop(context);
              },
              child: const Text('Log today'),
            ),
          ],
        ),
      );
}
