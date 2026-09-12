import 'package:flutter/material.dart';

class AppColors {
  // Brand Primary
  static const Color primaryBerry = Color(0xFF9E1B46);
  static const Color primaryDeep = Color(0xFF831438);
  static const Color accentRose = Color(0xFFFF4D79);
  static const Color accentPink = Color(0xFFF03D68);

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF487E),
      Color(0xFF6C2D7E),
    ],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF9E1B46),
      Color(0xFFFF4D79),
    ],
  );

  static const LinearGradient buttonGradientReverse = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFFF4D79),
      Color(0xFF9E1B46),
    ],
  );

  // Background & Surfaces
  static const Color background = Color(0xFFF9F9FC);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color surfaceBorder = Color(0xFFF0EDF5);
  static const Color lightGrayBg = Color(0xFFF4F4F8);

  // Text Colors
  static const Color textDark = Color(0xFF1E1B2E);
  static const Color textMuted = Color(0xFF7A7886);
  static const Color textLight = Color(0xFF9E9CA8);

  // Status & Feature Colors
  static const Color greenSuccess = Color(0xFF2EAA68);
  static const Color greenMint = Color(0xFF6FE7A8);
  static const Color stressPurple = Color(0xFF985B9E);
  static const Color energyCoral = Color(0xFFFF5277);

  // Pastel Pill & Tag Backgrounds
  static const Color purpleTagBg = Color(0xFFECCFF8);
  static const Color purpleTagText = Color(0xFF8B2FC9);
  static const Color orangeTagBg = Color(0xFFFFE8DC);
  static const Color orangeTagText = Color(0xFFD9531E);
  static const Color pinkTagBg = Color(0xFFFFE1EA);
  static const Color pinkTagText = Color(0xFFB5234A);
  static const Color blueTagBg = Color(0xFFDCEBFF);
  static const Color blueTagText = Color(0xFF2563EB);
  static const Color aiInsightBg = Color(0xFFEBD4E1);

  // Chart Curve Colors
  static const Color chartLH = Color(0xFFA81D52);
  static const Color chartFSH = Color(0xFF7D4386);
  static const Color chartEstrogen = Color(0xFF38B273);

  // Quick Log Icons Backgrounds
  static const Color quickLogPeriod = Color(0xFFFFDFE6);
  static const Color quickLogSymptoms = Color(0xFFDFE9FF);
  static const Color quickLogMood = Color(0xFFF2DEFF);
  static const Color quickLogHormones = Color(0xFFD4F8E5);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Inter',
      colorScheme: ColorScheme.light(
        primary: AppColors.primaryBerry,
        secondary: AppColors.accentRose,
        surface: AppColors.cardWhite,
        onSurface: AppColors.textDark,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );
  }

  // Common Box Shadows matching Figma soft ambient dropshadows
  static List<BoxShadow> get softShadow => [
        const BoxShadow(
          color: Color(0x08000000),
          blurRadius: 20,
          spreadRadius: 0,
          offset: Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get buttonShadow => [
        BoxShadow(
          color: AppColors.primaryBerry.withOpacity(0.28),
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get floatingNavShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 30,
          spreadRadius: 2,
          offset: const Offset(0, 10),
        ),
      ];
}
