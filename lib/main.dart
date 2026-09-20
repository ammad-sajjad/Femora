import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/breast.dart';
import 'models/models.dart';
import 'models/pcos.dart';
import 'models/self_exam.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'screens/main_shell.dart';

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

class FemoraApp extends StatelessWidget {
  const FemoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => PcosState()),
        ChangeNotifierProvider(create: (_) => BreastState()),
        ChangeNotifierProvider(create: (_) => SelfExamState()..load()),
      ],
      child: MaterialApp(
        title: 'Femora',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const MainShellScreen(),
      ),
    );
  }
}
