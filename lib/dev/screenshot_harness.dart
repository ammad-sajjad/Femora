// Screenshot harness for marketing material only. NOT part of the shipped app: it drives the real
// screens through their real, public APIs (the local backend for PCOS and the breast ultrasound model),
// seeded with a realistic demo profile, and boots straight into the main shell, bypassing sign-in.
// Run with: flutter run -d chrome -t lib/dev/screenshot_harness.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../models/breast.dart';
import '../models/chat_state.dart';
import '../models/cycle_engine.dart';
import '../models/health_store.dart';
import '../models/models.dart';
import '../models/pcos.dart';
import '../models/reminders.dart';
import '../models/report_reader.dart';
import '../models/self_exam.dart';
import '../screens/dashboard_screen.dart';
import '../screens/doctor_qr_screen.dart';
import '../screens/hormone_insights_screen.dart';
import '../screens/main_shell.dart';
import '../screens/reminders_screen.dart';
import '../screens/report_screen.dart';
import '../screens/trends_screen.dart';
import '../services/api_service.dart';
import '../services/reminder_service.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';

final _now = DateTime(2026, 9, 21, 9, 15);
DateTime _d(int daysAgo) => _now.subtract(Duration(days: daysAgo));

class _NoReminders extends ReminderService {
  @override
  bool get isSupported => false;
}

const _disclaimer = {
  'en': 'This is an AI reading of a photo, not medical advice. Please check it against the original and talk to your doctor.',
  'ur': 'یہ تصویر کی مصنوعی ذہانت سے پڑھائی ہے، طبی مشورہ نہیں۔ براہِ کرم اصل رپورٹ سے ملائیں اور اپنے ڈاکٹر سے بات کریں۔',
};

void main() {
  runApp(const _HarnessRoot());
}

class _HarnessRoot extends StatefulWidget {
  const _HarnessRoot();
  @override
  State<_HarnessRoot> createState() => _HarnessRootState();
}

// Optional URL parameters, so a headless browser can take each screenshot without clicking:
// ?tab=0..4&lang=ur&w=360&h=780 (tab = bottom-navigation index, w/h = the phone's logical size).
final _query = Uri.base.queryParameters;

// ?screen=<name> opens one screen on its own instead of the main shell.
const _screens = <String, Widget>{
  'doctor': DoctorQrScreen(),
  'dashboard': DashboardScreen(),
  'report': ReportScreen(),
  'trends': TrendsScreen(),
  'insights': HormoneInsightsScreen(),
  'reminders': RemindersScreen(),
};

class _HarnessRootState extends State<_HarnessRoot> {
  String _language = _query['lang'] == 'ur' ? 'ur' : 'en';
  bool _ready = false;

  late final HealthStore store = HealthStore()..now = () => _now;
  late final AppState app = AppState()..now = () => _now;
  late final ChatState chat = ChatState(api: ApiService());
  late final PcosState pcos = PcosState(api: ApiService(), onResult: store.recordPcos);
  late final BreastState breast = BreastState(api: ApiService(), onScan: store.recordScan, onRisk: store.recordBreastRisk);
  late final SelfExamState selfExam = SelfExamState(reminders: _NoReminders());
  late final RemindersState reminders = RemindersState(service: _NoReminders());
  late final VoiceController voice = VoiceController(api: ApiService());

  @override
  void initState() {
    super.initState();
    _seed();
  }

  Future<void> _seed() async {
    store.profile = HealthProfile(
      name: 'Ayesha Khan',
      age: 27,
      heightCm: 162,
      weightKg: 68,
      concerns: {'pcos', 'cycle'},
      language: _language,
      personalize: true,
      onboarded: true,
    );
    // Four real, regular cycles so Home / Cycle / Dashboard / Hormonal insights all have real history.
    store.periods = [
      PeriodEntry(start: _d(112), end: _d(108)),
      PeriodEntry(start: _d(84), end: _d(80)),
      PeriodEntry(start: _d(56), end: _d(52)),
      PeriodEntry(start: _d(6), end: _d(2)),
    ];
    const moods = ['good', 'okay', 'great', 'good', 'low', 'okay', 'good', 'great', 'good', 'okay', 'good', 'great', 'good', 'okay'];
    for (var i = 0; i < 14; i++) {
      await store.addLog(SymptomLog(
        date: _d(i),
        symptoms: i % 4 == 0 ? const ['cramps', 'bloating'] : (i % 5 == 0 ? const ['headache'] : const []),
        mood: moods[i],
        sleepHours: 6.5 + (i % 3) * 0.6,
        stress: 1 + (i % 5),
        energy: 1 + ((i + 2) % 5),
      ));
    }
    await selfExam.load();
    await selfExam.logExam(_d(6));

    // Real model calls against the local backend (no fabricated numbers): PCOS questionnaire, the bundled
    // sample ultrasound scan, and a breast-risk questionnaire.
    await pcos.submit(const PcosAnswers(
      age: 27, heightCm: 162, weightKg: 68, irregularCycle: true, periodDays: 4,
      weightGain: true, hairGrowth: true, skinDarkening: false, hairLoss: false, pimples: true,
      fastFood: true, regularExercise: false,
    ));
    await breast.submitRisk(const BreastRiskAnswers(
      age: 27, heightCm: 162, weightKg: 68, menopause: Menopause.pre, firstBirth: FirstBirth.never,
      relatives: 1, breastBiopsy: false, symptoms: {},
    ));
    try {
      final bytes = (await rootBundle.load('assets/images/breast_sample_benign.png')).buffer.asUint8List();
      await breast.analyzeScan(bytes, 'sample_benign.png');
    } catch (_) {
      // If the model server is unreachable the screen still renders; the scan card just stays empty.
    }

    store.recordReport(ExplainedReport(
      date: _d(1),
      kind: 'blood_test',
      summary: _language == 'ur'
          ? 'یہ ایک خون کا معمول کا ٹیسٹ ہے۔ آپ کا ہیموگلوبن حد سے تھوڑا کم ہے اور باقی سب نارمل ہے۔'
          : 'This is a routine blood test. Your haemoglobin is a little below the printed range; everything else is normal.',
      findings: [
        const ReportFinding(name: 'Hemoglobin', value: '10.8', unit: 'g/dL', reference: '12.0 - 15.5', status: 'low', explanation: 'Slightly below the printed range.'),
        const ReportFinding(name: 'TSH', value: '2.1', unit: 'mIU/L', reference: '0.4 - 4.0', status: 'normal', explanation: 'Inside the printed range.'),
        const ReportFinding(name: 'Fasting glucose', value: '88', unit: 'mg/dL', reference: '70 - 100', status: 'normal', explanation: 'Inside the printed range.'),
      ],
      questions: const ['Should I take an iron supplement?', 'Do I need a repeat test in a few months?'],
      urgency: 'none',
      language: _language,
      disclaimer: _disclaimer[_language]!,
    ));

    final tab = int.tryParse(_query['tab'] ?? '');
    if (tab != null) app.setTab(tab);
    if (mounted) setState(() => _ready = true);
  }

  void _setLanguage(String lang) {
    setState(() => _language = lang);
    store.saveProfile(store.profile..language = lang);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<HealthStore>.value(value: store),
        ChangeNotifierProvider<AppState>.value(value: app),
        ChangeNotifierProvider<ChatState>.value(value: chat),
        ChangeNotifierProvider<PcosState>.value(value: pcos),
        ChangeNotifierProvider<BreastState>.value(value: breast),
        ChangeNotifierProvider<SelfExamState>.value(value: selfExam),
        ChangeNotifierProvider<RemindersState>.value(value: reminders),
        ChangeNotifierProvider<VoiceController>.value(value: voice),
      ],
      child: MaterialApp(
        title: 'Femora',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        locale: Locale(_language),
        supportedLocales: const [Locale('en'), Locale('ur')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          // Forces a real phone's logical size regardless of the actual (desktop) browser window, and
          // clips to it, so a screenshot of this page is a real phone screenshot, not a stretched layout.
          final phone = Size(double.tryParse(_query['w'] ?? '') ?? 320, double.tryParse(_query['h'] ?? '') ?? 540);
          return ColoredBox(
            color: const Color(0xFF12181F),
            child: Center(
              child: SizedBox(
                width: phone.width,
                height: phone.height,
                child: ClipRect(
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(size: phone, devicePixelRatio: 2, padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero),
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(fontFamilyFallback: kUrduFontFallback),
                      child: Stack(children: [
                        child!,
                        // A tiny toggle lets the same running app switch language for the Urdu screenshots.
                        Positioned(
                          top: 4,
                          right: 4,
                          child: SafeArea(
                            child: Material(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _setLanguage(_language == 'en' ? 'ur' : 'en'),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  child: Icon(Icons.translate_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        home: _screens[_query['screen']] ?? const MainShellScreen(),
      ),
    );
  }
}
