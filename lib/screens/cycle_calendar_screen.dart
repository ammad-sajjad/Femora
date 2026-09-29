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

const moodOptions = [
  ('great', Icons.sentiment_very_satisfied_rounded, 'Great'),
  ('good', Icons.sentiment_satisfied_rounded, 'Good'),
  ('okay', Icons.sentiment_neutral_rounded, 'Okay'),
  ('low', Icons.sentiment_dissatisfied_rounded, 'Low'),
  ('bad', Icons.sentiment_very_dissatisfied_rounded, 'Bad'),
];

const _moodLabelsUr = {'great': 'بہت اچھا', 'good': 'اچھا', 'okay': 'ٹھیک', 'low': 'کم', 'bad': 'خراب'};

/// Spring interactive touch compression.
class _FluidPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _FluidPress({required this.child, this.onTap});

  @override
  State<_FluidPress> createState() => _FluidPressState();
}

class _FluidPressState extends State<_FluidPress> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 180),
    lowerBound: 0.965,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) => _ctrl.forward(),
      onTapCancel: () => _ctrl.forward(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.scale(scale: _ctrl.value, child: child),
        child: widget.child,
      ),
    );
  }
}

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
      backgroundColor: const Color(0xFFFCF9FB),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFCF9FB),
              Color(0xFFFFF7FA),
              Color(0xFFFFFFFF),
              Color(0xFFFFF9FB),
            ],
            stops: [0.0, 0.25, 0.65, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FemoraHeader(isCalendarStyle: true),
                const SizedBox(height: 6),

                // Screen Title Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        t(language, 'My Cycle', 'میرا سائیکل'),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E1B1E),
                          letterSpacing: -0.6,
                        ),
                      ),
                      Text(
                        fmtMonth(store.now(), language: language),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Hero Cycle Card
                CycleSummaryCard(engine: engine),
                const SizedBox(height: 2),

                // Monthly Calendar Card
                MonthCalendar(
                  engine: engine,
                  month: month,
                  onMonth: (m) => setState(() => _month = DateTime(m.year, m.month)),
                  onDay: (d) => showDayActions(context, d),
                ),

                // Flags Card (Irregular / Delayed warning)
                CycleFlagsCard(engine: engine),

                // Your Cycles Card
                CycleHistory(engine: engine),
                const SizedBox(height: 14),

                // 3 Feature Link Cards (Matching CALENDER.png)
                _buildFeatureCard(
                  key: const Key('open_trends'),
                  title: t(language, 'See my trends', 'میرے رجحانات دیکھیں'),
                  icon: Icons.trending_up_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TrendsScreen())),
                ),
                const SizedBox(height: 10),

                _buildFeatureCard(
                  key: const Key('open_insights'),
                  title: t(language, 'Hormonal insights', 'ہارمونل بصیرت'),
                  icon: Icons.science_outlined,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HormoneInsightsScreen())),
                ),
                const SizedBox(height: 10),

                _buildFeatureCard(
                  key: const Key('open_reminders'),
                  title: t(language, 'Reminders', 'یاد دہانیاں'),
                  icon: Icons.notifications_active_outlined,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RemindersScreen())),
                ),
                const SizedBox(height: 20),

                // Daily Logger Card
                _buildLoggerCard(context, appState, store, engine, language),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required Key key,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0),
      child: _FluidPress(
        onTap: onTap,
        child: Container(
          key: key,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4EC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFFE11D48), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1B1E),
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoggerCard(
    BuildContext context,
    AppState appState,
    HealthStore store,
    CycleEngine engine,
    String language,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle Bar
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
          const SizedBox(height: 16),

          // Day Selector Capsule Segment
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildDayChip(
                    key: const Key('log_day_today'),
                    title: t(language, 'Today', 'آج'),
                    isSelected: appState.loggingToday,
                    onTap: () => _chooseDay(appState, store, dayOf(store.now())),
                  ),
                ),
                Expanded(
                  child: _buildDayChip(
                    key: const Key('log_day_yesterday'),
                    title: t(language, 'Yesterday', 'کل'),
                    isSelected: appState.logDay == addDays(dayOf(store.now()), -1),
                    onTap: () => _chooseDay(appState, store, addDays(dayOf(store.now()), -1)),
                  ),
                ),
                Expanded(
                  child: _buildDayChip(
                    key: const Key('log_day_pick'),
                    title: appState.loggingToday || appState.logDay == addDays(dayOf(store.now()), -1)
                        ? t(language, 'Another day', 'کوئی اور دن')
                        : fmtDay(appState.logDay, language: language),
                    isSelected: !appState.loggingToday && appState.logDay != addDays(dayOf(store.now()), -1),
                    onTap: () => _pickDay(appState, store, language),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

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
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E1B1E),
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
              color: Color(0xFF64748B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),

          // Symptoms Header
          Text(
            t(language, 'Log Symptoms', 'علامات درج کریں'),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E1B1E),
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
          const SizedBox(height: 24),

          // Mood Section
          Text(
            t(language, 'Mood', 'موڈ'),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E1B1E),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (id, icon, label) in moodOptions)
                _FluidPress(
                  onTap: () => appState.setMood(id),
                  child: Container(
                    key: Key('mood_$id'),
                    width: 58,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: appState.mood == id ? const Color(0xFFFFF1F4) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: appState.mood == id ? const Color(0xFFFECDD3) : const Color(0xFFF1F5F9),
                        width: appState.mood == id ? 1.5 : 1,
                      ),
                      boxShadow: appState.mood == id
                          ? [
                              BoxShadow(
                                color: const Color(0xFFE11D48).withOpacity(0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Icon(icon, color: const Color(0xFFF59E0B), size: 24),
                        const SizedBox(height: 3),
                        Text(
                          t(language, label, _moodLabelsUr[id] ?? label),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            fontWeight: appState.mood == id ? FontWeight.w700 : FontWeight.w600,
                            color: appState.mood == id ? const Color(0xFF9F1239) : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Sleep Section
          Row(
            children: [
              Expanded(
                child: Text(
                  t(language, 'Sleep', 'نیند'),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1B1E),
                  ),
                ),
              ),
              Text(
                appState.sleepHours == null
                    ? t(language, 'Not set', 'سیٹ نہیں')
                    : t(language, '${appState.sleepHours!.toStringAsFixed(1)} hours', '${appState.sleepHours!.toStringAsFixed(1)} گھنٹے'),
                key: const Key('sleep_value'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFBE185D),
                ),
              ),
              if (appState.sleepHours != null)
                IconButton(
                  key: const Key('sleep_clear'),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                  onPressed: () => appState.setSleep(null),
                ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFFBE185D),
              inactiveTrackColor: const Color(0xFFF1F5F9),
              thumbColor: const Color(0xFFBE185D),
              overlayColor: const Color(0xFFBE185D).withOpacity(0.15),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              key: const Key('sleep_slider'),
              value: appState.sleepHours ?? 7,
              min: 0,
              max: 14,
              divisions: 28,
              onChanged: appState.setSleep,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('0h', style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF94A3B8))),
                Text('4h', style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF94A3B8))),
                Text('8h', style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF94A3B8))),
                Text('12h+', style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Stress Section
          _levelRow(
            t(language, 'Stress', 'تناؤ'),
            language == 'ur' ? const ['پرسکون', 'ہلکا', 'درمیانہ', 'زیادہ', 'بہت زیادہ'] : const ['Calm', 'Mild', 'Medium', 'High', 'Very high'],
            appState.stress,
            'stress',
            appState.setStress,
          ),
          const SizedBox(height: 20),

          // Energy Section
          _levelRow(
            t(language, 'Energy', 'توانائی'),
            language == 'ur' ? const ['بہت کم', 'کم', 'ٹھیک', 'اچھا', 'بہت اچھا'] : const ['Very low', 'Low', 'Okay', 'Good', 'Great'],
            appState.energy,
            'energy',
            appState.setEnergy,
          ),
          const SizedBox(height: 24),

          // Notes Section
          Text(
            t(language, 'Notes', 'نوٹس'),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E1B1E),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 90,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFED7DC), width: 1.2),
            ),
            child: TextField(
              controller: _notesController,
              onChanged: appState.updateNotes,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: t(language, 'How are you feeling today?', 'آج آپ کیسا محسوس کر رہی ہیں؟'),
                hintStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  color: Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Save Today's Log Button
          _FluidPress(
            onTap: () {
              appState.saveDailyLog();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(appState.loggingToday
                      ? t(language, 'Today\'s health log saved successfully!', 'آج کا ہیلتھ لاگ کامیابی سے محفوظ ہو گیا!')
                      : t(language, 'Health log for ${fmtDay(appState.logDay)} saved.', '${fmtDay(appState.logDay, language: 'ur')} کا ہیلتھ لاگ محفوظ ہو گیا۔')),
                  backgroundColor: const Color(0xFFBE185D),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: Container(
              key: const Key('save_log'),
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF9E1B46),
                    Color(0xFFE11D48),
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE11D48).withOpacity(0.35),
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
    );
  }

  Widget _buildDayChip({
    required Key key,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return _FluidPress(
      onTap: onTap,
      child: Container(
        key: key,
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_rounded, size: 15, color: Color(0xFF9F1239)),
              const SizedBox(width: 4),
            ],
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF9F1239) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelRow(String title, List<String> captions, int? selected, String keyPrefix, void Function(int?) onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: Color(0xFF1E1B1E),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              Expanded(
                child: _FluidPress(
                  onTap: () => onTap(selected == i ? null : i),
                  child: Column(
                    key: Key('${keyPrefix}_$i'),
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected == i ? const Color(0xFFBE185D) : const Color(0xFFF8FAFC),
                          border: Border.all(
                            color: selected == i ? const Color(0xFFBE185D) : const Color(0xFFF1F5F9),
                            width: 1.2,
                          ),
                          boxShadow: selected == i
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFBE185D).withOpacity(0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          '$i',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: selected == i ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        captions[i - 1],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9.5,
                          fontWeight: selected == i ? FontWeight.w700 : FontWeight.w500,
                          color: selected == i ? const Color(0xFFBE185D) : const Color(0xFF94A3B8),
                        ),
                      ),
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

    return _FluidPress(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF1F4) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFFFECDD3) : const Color(0xFFF1F5F9),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFE11D48).withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              symptom.icon,
              color: isSelected ? const Color(0xFF9F1239) : const Color(0xFF475569),
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              symptom.nameIn(language),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? const Color(0xFF9F1239) : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
