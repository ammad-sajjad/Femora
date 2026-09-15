import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/models.dart';
import 'models/pcos.dart';
import 'theme/app_theme.dart';
import 'screens/main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
