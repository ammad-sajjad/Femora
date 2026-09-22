import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/lang.dart';
import '../models/cycle_engine.dart';
import '../models/health_store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/cycle_widgets.dart';
import '../widgets/femora_header.dart';
import 'hormone_insights_screen.dart';
import 'reminders_screen.dart';
import 'trends_screen.dart';

class CycleCalendarScreen extends StatefulWidget {
  const CycleCalendarScreen({super.key});

  @override
  State<CycleCalendarScreen> createState() => _CycleCalendarScreenState();
}

class _CycleCalendarScreenState extends State<CycleCalendarScreen> {
  final TextEditingController _notesController = TextEditingController();
  DateTime? _month; // month shown in the calendar; today's month until she browses
  String? _synced; // which account / load state the log form was last filled for

  /// Fills the log form from what is saved for the chosen day, once the store has loaded or the account changed.
  void _sync(AppState app, HealthStore store) {
    final key = '${store.account}|${store.loaded}';
    if (key == _synced) return;
    _synced = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      app.selectLogDay(app.logDay, store.logOn(app.logDay));
      _notesController.text = app.userNotes;
    });
  }

  void _chooseDay(AppState app, HealthStore store, DateTime day) {
    app.selectLogDay(day, store.logOn(day));
    _notesController.text = app.userNotes;
  }

  Future<void> _pickDay(AppState app, HealthStore store, String language) async {
    final today = dayOf(store.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: app.logDay,
      firstDate: addDays(today, -60),
      lastDate: today,
      helpText: t(language, 'Which day do you want to log?', 'آپ کس دن کا اندراج کرنا چاہتی ہیں؟'),
    );
    if (picked != null && mounted) _chooseDay(app, store, picked);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final store = context.watch<HealthStore>();
    final engine = store.cycle;
    final language = store.profile.language;
    _sync(appState, store);
    final month = _month ?? DateTime(engine.today.year, engine.today.month);

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

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  t(language, 'My Cycle', 'میرا سائیکل'),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
              ),
              const SizedBox(height: 14),
              CycleSummaryCard(engine: engine),
              const SizedBox(height: 10),
              PeriodLogRow(engine: engine),
              const SizedBox(height: 4),
              MonthCalendar(
                engine: engine,
                month: month,
                onMonth: (m) => setState(() => _month = DateTime(m.year, m.month)),
                onDay: (d) => showDayActions(context, d),
              ),
              CycleFlagsCard(engine: engine),
              CycleHistory(engine: engine),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: OutlinedButton.icon(
                  key: const Key('open_trends'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBerry,
                    side: const BorderSide(color: AppColors.primaryBerry),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TrendsScreen())),
                  icon: const Icon(Icons.show_chart_rounded),
                  label: Text(t(language, 'See my trends', 'میرے رجحانات دیکھیں'), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: OutlinedButton.icon(
                  key: const Key('open_insights'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBerry,
                    side: const BorderSide(color: AppColors.primaryBerry),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HormoneInsightsScreen())),
                  icon: const Icon(Icons.bubble_chart_outlined),
                  label: Text(t(language, 'Hormonal insights', 'ہارمونل بصیرت'), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: OutlinedButton.icon(
                  key: const Key('open_reminders'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBerry,
                    side: const BorderSide(color: AppColors.primaryBerry),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RemindersScreen())),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(t(language, 'Reminders', 'یاد دہانیاں'), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
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
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          key: const Key('log_day_today'),
                          label: Text(t(language, 'Today', 'آج')),
                          selected: appState.loggingToday,
                          selectedColor: const Color(0xFFFFDFE8),
                          onSelected: (_) => _chooseDay(appState, store, dayOf(store.now())),
                        ),
                        ChoiceChip(
                          key: const Key('log_day_yesterday'),
                          label: Text(t(language, 'Yesterday', 'کل')),
                          selected: appState.logDay == addDays(dayOf(store.now()), -1),
                          selectedColor: const Color(0xFFFFDFE8),
                          onSelected: (_) => _chooseDay(appState, store, addDays(dayOf(store.now()), -1)),
                        ),
                        ChoiceChip(
                          key: const Key('log_day_pick'),
                          label: Text(appState.loggingToday || appState.logDay == addDays(dayOf(store.now()), -1) ? t(language, 'Another day', 'کوئی اور دن') : fmtDay(appState.logDay, language: language)),
                          selected: !appState.loggingToday && appState.logDay != addDays(dayOf(store.now()), -1),
                          selectedColor: const Color(0xFFFFDFE8),
                          onSelected: (_) => _pickDay(appState, store, language),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Header Info
                    Text(
                      !appState.loggingToday
                          ? t(language, 'Logging for ${fmtDay(appState.logDay)}', 'اندراج برائے ${fmtDay(appState.logDay, language: 'ur')}')
                          : engine.hasHistory
                              ? t(language, 'Today • ${engine.periodOngoing ? 'Period day' : 'Cycle day'} ${engine.cycleDay}',
                                  'آج • ${engine.periodOngoing ? 'پیریڈ کا دن' : 'سائیکل کا دن'} ${engine.cycleDay}')
                              : t(language, 'Today', 'آج'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      engine.phase?.tipIn(language) ??
                          t(language, 'Log how you feel today. Your symptoms and mood are shared with your AI companion and your report.',
                              'آج آپ کیسا محسوس کر رہی ہیں یہ درج کریں۔ آپ کی علامات اور موڈ آپ کے AI کمپینین اور رپورٹ کے ساتھ شیئر کی جاتی ہیں۔'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Symptoms Header
                    Text(
                      t(language, 'Log Symptoms', 'علامات درج کریں'),
                      style: const TextStyle(
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
                          language,
                          onTap: () => appState.toggleSymptom(symptom.id),
                        );
                      },
                    ),
                    const SizedBox(height: 22),

                    // Mood
                    Text(
                      t(language, 'Mood', 'موڈ'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final (id, emoji, label) in moodOptions)
                          GestureDetector(
                            key: Key('mood_$id'),
                            onTap: () => appState.setMood(id),
                            child: Container(
                              width: 58,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: appState.mood == id ? const Color(0xFFFFDFE8) : AppColors.cardWhite,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: appState.mood == id ? AppColors.primaryBerry : const Color(0xFFE8E4EE),
                                  width: appState.mood == id ? 1.6 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(emoji, style: const TextStyle(fontSize: 22)),
                                  const SizedBox(height: 2),
                                  Text(t(language, label, _moodLabelsUr[id] ?? label), style: const TextStyle(fontFamily: 'Inter', fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Sleep
                    Row(
                      children: [
                        Expanded(child: Text(t(language, 'Sleep', 'نیند'), style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark))),
                        Text(
                          appState.sleepHours == null ? t(language, 'Not set', 'سیٹ نہیں') : t(language, '${appState.sleepHours!.toStringAsFixed(1)} hours', '${appState.sleepHours!.toStringAsFixed(1)} گھنٹے'),
                          key: const Key('sleep_value'),
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryBerry),
                        ),
                        if (appState.sleepHours != null)
                          IconButton(key: const Key('sleep_clear'), visualDensity: VisualDensity.compact, icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => appState.setSleep(null)),
                      ],
                    ),
                    Slider(
                      key: const Key('sleep_slider'),
                      value: appState.sleepHours ?? 7,
                      min: 0,
                      max: 14,
                      divisions: 28,
                      activeColor: appState.sleepHours == null ? const Color(0xFFCFC7D8) : AppColors.primaryBerry,
                      onChanged: appState.setSleep,
                    ),
                    const SizedBox(height: 10),
                    _levelRow(
                        t(language, 'Stress', 'تناؤ'),
                        language == 'ur' ? const ['پرسکون', 'ہلکا', 'درمیانہ', 'زیادہ', 'بہت زیادہ'] : const ['Calm', 'Mild', 'Medium', 'High', 'Very high'],
                        appState.stress,
                        'stress',
                        appState.setStress),
                    const SizedBox(height: 16),
                    _levelRow(
                        t(language, 'Energy', 'توانائی'),
                        language == 'ur' ? const ['بہت کم', 'کم', 'ٹھیک', 'اچھا', 'بہت اچھا'] : const ['Very low', 'Low', 'Okay', 'Good', 'Great'],
                        appState.energy,
                        'energy',
                        appState.setEnergy),
                    const SizedBox(height: 22),

                    // Notes Section
                    Text(
                      t(language, 'Notes', 'نوٹس'),
                      style: const TextStyle(
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
                        decoration: InputDecoration(
                          hintText: t(language, 'How are you feeling today?', 'آج آپ کیسا محسوس کر رہی ہیں؟'),
                          hintStyle: const TextStyle(
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
                      key: const Key('save_log'),
                      onTap: () {
                        appState.saveDailyLog();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(appState.loggingToday
                                ? t(language, 'Today\'s health log saved successfully!', 'آج کا ہیلتھ لاگ کامیابی سے محفوظ ہو گیا!')
                                : t(language, 'Health log for ${fmtDay(appState.logDay)} saved.', '${fmtDay(appState.logDay, language: 'ur')} کا ہیلتھ لاگ محفوظ ہو گیا۔')),
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
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              appState.loggingToday
                                  ? t(language, 'Save Today\'s Log', 'آج کا لاگ محفوظ کریں')
                                  : t(language, 'Save log for ${fmtDay(appState.logDay)}', '${fmtDay(appState.logDay, language: 'ur')} کا لاگ محفوظ کریں'),
                              style: const TextStyle(
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

  /// A 1 to 5 scale as five tappable pills with a caption each. Tapping the chosen one clears it.
  Widget _levelRow(String title, List<String> captions, int? selected, String keyPrefix, void Function(int?) onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              Expanded(
                child: GestureDetector(
                  key: Key('${keyPrefix}_$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected == i ? AppColors.primaryBerry : const Color(0xFFF3EFF7),
                          border: Border.all(color: selected == i ? AppColors.primaryBerry : const Color(0xFFE2DCEA)),
                        ),
                        child: Text('$i', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 14, color: selected == i ? Colors.white : AppColors.textDark)),
                      ),
                      const SizedBox(height: 3),
                      Text(captions[i - 1], textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter', fontSize: 9.5, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSymptomCard(SymptomItem symptom, String language, {required VoidCallback onTap}) {
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
              symptom.nameIn(language),
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

const _moodLabelsUr = {'great': 'بہت اچھا', 'good': 'اچھا', 'okay': 'ٹھیک', 'low': 'کم', 'bad': 'خراب'};
