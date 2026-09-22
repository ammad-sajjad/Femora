import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../models/health_store.dart';
import '../models/models.dart';
import '../models/trends.dart';
import '../theme/app_theme.dart';
import '../widgets/trend_cards.dart';

/// Charts and plain-language notes built from the daily log: mood, sleep, stress, energy and symptoms.
///
/// The layout is bilingual; the cards' own notes are still English-only pending a native speaker's review.
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
    final language = store.profile.language;
    final stats = TrendStats.compute(store.logs, store.now(), _days);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        leading: IconButton(key: const Key('trends_back'), icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.maybePop(context)),
        title: Text(t(language, 'My trends', 'میرے رجحانات'), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
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
                      label: Text(t(language, '$d days', '$d دن')),
                      selected: _days == d,
                      selectedColor: const Color(0xFFFFDFE8),
                      onSelected: (_) => setState(() => _days = d),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (stats.logged == 0) _empty(context, language) else ...[
              TrendSummaryTiles(stats: stats),
              MoodTrendCard(stats: stats),
              SleepTrendCard(stats: stats),
              StressEnergyCard(stats: stats),
              SymptomFrequencyCard(stats: stats),
              TrendInsightsCard(stats: stats),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Text(
                    t(language, 'These patterns come only from what you logged. They are not a diagnosis; talk to a doctor about anything that worries you.',
                        'یہ رجحانات صرف آپ کے درج کردہ اندراجات سے ہیں۔ یہ تشخیص نہیں ہیں؛ جو بھی بات آپ کو پریشان کرے اس کے بارے میں ڈاکٹر سے بات کریں۔'),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textLight, height: 1.4)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context, String language) => Container(
        key: const Key('trend_empty'),
        margin: const EdgeInsets.symmetric(horizontal: 18),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(22), boxShadow: AppTheme.softShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t(language, 'Nothing to show yet', 'ابھی دکھانے کے لیے کچھ نہیں'), style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 6),
            Text(
                t(language, 'Log your symptoms, mood, sleep, stress and energy for a few days in the Cycle tab and your trends will appear here.',
                    'سائیکل ٹیب میں چند دنوں کے لیے اپنی علامات، موڈ، نیند، تناؤ اور توانائی درج کریں اور آپ کے رجحانات یہاں ظاہر ہوں گے۔'),
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textMuted, height: 1.4)),
            const SizedBox(height: 14),
            FilledButton(
              key: const Key('trend_log_today'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBerry),
              onPressed: () {
                context.read<AppState>().setTab(1);
                Navigator.maybePop(context);
              },
              child: Text(t(language, 'Log today', 'آج درج کریں')),
            ),
          ],
        ),
      );
}
