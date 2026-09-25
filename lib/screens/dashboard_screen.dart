import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../models/analytics.dart';
import '../models/health_store.dart';
import '../models/hormone_insights.dart';
import '../models/trends.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard_cards.dart';
import '../widgets/hormone_cards.dart';
import '../widgets/trend_cards.dart';
import 'doctor_qr_screen.dart';
import 'heart_rate_screen.dart';
import 'hormone_insights_screen.dart';
import 'find_doctor_screen.dart';
import 'nearby_care_screen.dart';
import 'reminders_screen.dart';
import 'report_screen.dart';
import 'trends_screen.dart';

/// Scope 6.9: one place to see cycle history, symptom patterns, hormonal trends and how well the predictions did,
/// with a way to open the downloadable health report.
///
/// The layout and headings here are bilingual; the cards themselves (charts, hormone patterns and flags) are
/// still English-only pending a native speaker's review of that clinical wording.
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
    final language = store.profile.language;
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
        title: Text(t(language, 'Health dashboard', 'ہیلتھ ڈیش بورڈ'), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            CycleAtAGlance(engine: engine, history: history),
            DashboardSectionTitle(t(language, 'Your cycle', 'آپ کا سائیکل')),
            CycleHistoryChartCard(history: history),
            PredictionAnalyticsCard(backtest: backtest),
            DashboardSectionTitle(t(language, 'Symptoms and mood, last 30 days', 'علامات اور موڈ، پچھلے 30 دن')),
            const SizedBox(height: 12),
            TrendSummaryTiles(stats: stats),
            MoodTrendCard(stats: stats),
            SleepTrendCard(stats: stats),
            StressEnergyCard(stats: stats),
            SymptomFrequencyCard(stats: stats),
            DashboardSectionTitle(t(language, 'Hormonal trends', 'ہارمونل رجحانات')),
            HormoneCurveCard(engine: engine),
            PhaseAveragesCard(insights: insights),
            if (engine.hasHistory) PhaseSymptomTable(insights: insights),
            if (insights.flags.isNotEmpty || insights.patterns.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Text(
                  t(language, '${insights.flags.length} symptom${insights.flags.length == 1 ? '' : 's'} worth checking and ${insights.patterns.length} pattern${insights.patterns.length == 1 ? '' : 's'} found. Open Hormonal insights for the details.',
                      '${insights.flags.length} قابلِ توجہ علامات اور ${insights.patterns.length} رجحانات ملے۔ تفصیلات کے لیے ہارمونل بصیرت کھولیں۔'),
                  key: const Key('dash_insight_count'),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
                ),
              ),
            DashboardSectionTitle(t(language, 'Results', 'نتائج')),
            const SizedBox(height: 0),
            LatestResultsCard(store: store),
            DashboardSectionTitle(t(language, 'More', 'مزید')),
            _link(context, const Key('dash_open_report'), Icons.description_outlined, t(language, 'Health report (PDF)', 'ہیلتھ رپورٹ (PDF)'), const ReportScreen()),
            _link(context, const Key('dash_open_doctors'), Icons.person_search_outlined, t(language, 'Find a doctor (ratings and reviews)', 'ڈاکٹر تلاش کریں (ریٹنگ اور ریویوز)'), const FindDoctorScreen()),
            _link(context, const Key('dash_open_nearby'), Icons.local_hospital_outlined, t(language, 'Nearby care (hospitals, gynaecologists, labs)', 'قریبی طبی سہولیات'), const NearbyCareScreen()),
            _link(context, const Key('dash_open_heart'), Icons.monitor_heart_outlined, t(language, 'Morning heart check', 'صبح کی دھڑکن کا چیک'), const HeartRateScreen()),
            _link(context, const Key('dash_open_doctor_qr'), Icons.qr_code_2_rounded, t(language, 'Show my doctor (QR code)', 'ڈاکٹر کو دکھائیں (QR کوڈ)'), const DoctorQrScreen()),
            _link(context, const Key('dash_open_trends'), Icons.show_chart_rounded, t(language, 'My trends (7, 30 or 90 days)', 'میرے رجحانات (7، 30 یا 90 دن)'), const TrendsScreen()),
            _link(context, const Key('dash_open_insights'), Icons.bubble_chart_outlined, t(language, 'Hormonal insights', 'ہارمونل بصیرت'), const HormoneInsightsScreen()),
            _link(context, const Key('dash_open_reminders'), Icons.notifications_active_outlined, t(language, 'Reminders', 'یاد دہانیاں'), const RemindersScreen()),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text(
                  t(language, 'Everything here comes from what you logged and the checks you did. It is not a diagnosis; talk to a doctor about anything that worries you.',
                      'یہاں سب کچھ آپ کے درج کردہ اندراجات اور آپ کے کیے گئے چیکس سے ہے۔ یہ تشخیص نہیں ہے؛ جو بھی بات آپ کو پریشان کرے اس کے بارے میں ڈاکٹر سے بات کریں۔'),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textLight, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}
