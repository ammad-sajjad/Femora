import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/breast.dart';
import 'models/chat_state.dart';
import 'models/health_store.dart';
import 'models/models.dart';
import 'models/pcos.dart';
import 'models/self_exam.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/api_service.dart';
import 'services/voice_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.loadServerOverride();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const FemoraApp());
}

class FemoraApp extends StatefulWidget {
  const FemoraApp({super.key});

  @override
  State<FemoraApp> createState() => _FemoraAppState();
}

class _FemoraAppState extends State<FemoraApp> {
  // The on-device health store connects every part of the app: results, logs, the companion and the report
  late final HealthStore _store = HealthStore()..load();
  late final AppState _app = AppState()..onSaveLog = _store.addLog;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<HealthStore>.value(value: _store),
        ChangeNotifierProvider<AppState>.value(value: _app),
        ChangeNotifierProvider(create: (_) => PcosState(onResult: _store.recordPcos)),
        ChangeNotifierProvider(create: (_) => BreastState(onScan: _store.recordScan, onRisk: _store.recordBreastRisk)),
        ChangeNotifierProvider(create: (_) => SelfExamState()..load()),
        ChangeNotifierProvider(create: (_) => ChatState()..load()),
        ChangeNotifierProvider(create: (_) => VoiceController()),
      ],
      child: MaterialApp(
        title: 'Femora',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const _Root(),
      ),
    );
  }
}

/// Splash while the saved data loads, the welcome/profile screen on first launch, then the app.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    if (!store.loaded) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text('femora', style: TextStyle(fontFamily: 'Inter', fontSize: 38, fontWeight: FontWeight.w800, color: AppColors.primaryBerry, letterSpacing: -1)),
        ),
      );
    }
    return store.profile.onboarded ? const MainShellScreen() : const OnboardingScreen();
  }
}
