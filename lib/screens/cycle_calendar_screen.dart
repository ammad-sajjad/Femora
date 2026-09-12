import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/femora_header.dart';

class CycleCalendarScreen extends StatefulWidget {
  const CycleCalendarScreen({super.key});

  @override
  State<CycleCalendarScreen> createState() => _CycleCalendarScreenState();
}

class _CycleCalendarScreenState extends State<CycleCalendarScreen> {
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FemoraHeader(isCalendarStyle: true),
              const SizedBox(height: 8),

              // Calendar Title and Month
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Calendar',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'May 2024',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6E5970),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Weekly Day Strip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDayItem('MON', 6, isSelected: appState.selectedCalendarDay == 6),
                    _buildDayItem('TUE', 7, isSelected: appState.selectedCalendarDay == 7),
                    _buildDayItem('WED', 8, isSelected: appState.selectedCalendarDay == 8),
                    _buildDayItem('THU', 9, isSelected: appState.selectedCalendarDay == 9),
                    _buildDayItem('FRI', 10, isSelected: appState.selectedCalendarDay == 10),
                    _buildDayItem('SAT', 11, isSelected: appState.selectedCalendarDay == 11),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Logger Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 18.0),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: AppTheme.softShadow,
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDED9E6),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Header Info
                    const Text(
                      'Today • Cycle Day 12',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Follicular Phase - Estrogen is rising. You might feel more energetic.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Symptoms Header
                    const Text(
                      'Log Symptoms',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2-Column Grid of Symptoms
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.85,
                      ),
                      itemCount: appState.symptoms.length,
                      itemBuilder: (context, index) {
                        final symptom = appState.symptoms[index];
                        return _buildSymptomCard(
                          symptom,
                          onTap: () => appState.toggleSymptom(symptom.id),
                        );
                      },
                    ),
                    const SizedBox(height: 22),

                    // Notes Section
                    const Text(
                      'Notes',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 86,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4E2F7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _notesController,
                        onChanged: appState.updateNotes,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'How are you feeling today?',
                          hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Color(0xFF5E6D84),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Save Today's Log Button
                    GestureDetector(
                      onTap: () {
                        appState.saveDailyLog();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Today\'s health log saved successfully!'),
                            backgroundColor: AppColors.primaryBerry,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF9E1B46),
                              Color(0xFFFF487E),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBerry.withOpacity(0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Save Today\'s Log',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayItem(String dayName, int dayNumber, {required bool isSelected}) {
    return GestureDetector(
      onTap: () {
        context.read<AppState>().selectCalendarDay(dayNumber);
      },
      child: Column(
        children: [
          Text(
            dayName,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6E5970),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryBerry : const Color(0xFFDCEBFF),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$dayNumber',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF334E68),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 24,
            height: 3,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFF487E) : const Color(0xFFE4C9E8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomCard(SymptomItem symptom, {required VoidCallback onTap}) {
    final bool isSelected = symptom.isSelected;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBerry : const Color(0xFFEBF1FA),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryBerry.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              symptom.icon,
              color: isSelected ? Colors.white : const Color(0xFF7C5A87),
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              symptom.name,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
