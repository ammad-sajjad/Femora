import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../widgets/custom_bottom_nav.dart';
import 'home_dashboard_screen.dart';
import 'cycle_calendar_screen.dart';
import 'pcos_assessment_screen.dart';
import 'breast_health_screen.dart';
import 'ai_companion_screen.dart';

class MainShellScreen extends StatelessWidget {
  const MainShellScreen({super.key});

  final List<Widget> _screens = const [
    HomeDashboardScreen(),
    CycleCalendarScreen(),
    PCOSAssessmentScreen(),
    BreastHealthScreen(),
    AICompanionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: appState.currentTabIndex,
            children: _screens,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: CustomBottomNav(
              currentIndex: appState.currentTabIndex,
              onTap: (index) {
                appState.setTab(index);
              },
            ),
          ),
        ],
      ),
    );
  }
}
