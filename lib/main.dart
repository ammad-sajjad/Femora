import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'l10n/lang.dart';
import 'models/auth_state.dart';
import 'models/breast.dart';
import 'models/chat_state.dart';
import 'models/health_store.dart';
import 'models/models.dart';
import 'models/pcos.dart';
import 'models/reminders.dart';
import 'models/self_exam.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/voice_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
  const FemoraApp({super.key, this.authService});

  /// Tests pass their own, so a widget test never needs a Firebase app to exist.
  final AuthService? authService;

  @override
  State<FemoraApp> createState() => _FemoraAppState();
}

class _FemoraAppState extends State<FemoraApp> {
  // The on-device health store connects every part of the app: results, logs, the companion and the report
  // The store is not loaded here any more: it is loaded for whichever account signs in.
  late final HealthStore _store = HealthStore();
  late final AppState _app = AppState()..onSaveLog = _store.addLog;
  late final ChatState _chat = ChatState();
  late final AuthState _auth = AuthState(service: widget.authService ?? FirebaseAuthService());
  late final RemindersState _reminders = RemindersState()..load();

  @override
  void initState() {
    super.initState();
    // Reminders follow the cycle: recalculated whenever periods are logged or an account's data loads
    _store.onCycleChanged = () => _reminders.apply(_store.cycle);
    _store.onCleared = _reminders.clearAll;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthState>.value(value: _auth),
        ChangeNotifierProvider<HealthStore>.value(value: _store),
        ChangeNotifierProvider<AppState>.value(value: _app),
        ChangeNotifierProvider<ChatState>.value(value: _chat),
        ChangeNotifierProvider<RemindersState>.value(value: _reminders),
        ChangeNotifierProvider(create: (_) => PcosState(onResult: _store.recordPcos)),
        ChangeNotifierProvider(create: (_) => BreastState(onScan: _store.recordScan, onRisk: _store.recordBreastRisk)),
        ChangeNotifierProvider(create: (_) => SelfExamState()..load()),
        ChangeNotifierProvider(create: (_) => VoiceController()),
      ],
      // Only the language code is watched, so the app (and its Navigator, which keeps its state) is not
      // rebuilt on every other change to the store.
      child: Selector<HealthStore, String>(
        selector: (_, store) => store.profile.language,
        builder: (_, language, __) => MaterialApp(
          title: 'Femora',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          locale: Locale(language),
          supportedLocales: const [Locale('en'), Locale('ur')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Urdu text drawn anywhere (even a widget that never checked the language) still gets the
          // bundled Urdu font, because it is only ever added as a *fallback*: an English TextStyle that
          // sets its own fontFamily is untouched, and only the glyphs it cannot draw (Urdu ones) borrow
          // this font instead of whatever the phone would otherwise substitute.
          builder: (context, child) => DefaultTextStyle.merge(style: const TextStyle(fontFamilyFallback: kUrduFontFallback), child: child!),
          home: const _Root(),
        ),
      ),
    );
  }
}

/// Sign-in, then a splash while that account's saved data loads, then the profile screen or the app.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  String? _loadedFor;

  /// Points the on-device stores at whoever is signed in. Results and conversations are kept per account,
  /// so a shared phone never shows one woman another's data.
  void _followAccount(String? id) {
    if (id == null || id == _loadedFor) return;
    _loadedFor = id;
    context.read<HealthStore>().useAccount(id);
    context.read<ChatState>().useAccount(id);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final store = context.watch<HealthStore>();

    if (!auth.ready) return const _Splash();
    if (!auth.signedIn) {
      _loadedFor = null;
      return const AuthScreen();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _followAccount(auth.user!.id));
    if (!store.loaded || store.account != auth.user!.id) return const _Splash();
    return store.profile.onboarded ? const MainShellScreen() : const OnboardingScreen();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text('femora',
            style: TextStyle(fontFamily: 'Inter', fontSize: 38, fontWeight: FontWeight.w800, color: AppColors.primaryBerry, letterSpacing: -1)),
      ),
    );
  }
}
