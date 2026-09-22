import 'package:flutter/material.dart';

import 'cycle_engine.dart';
import 'health_store.dart';

class SymptomItem {
  final String id;
  final String name;
  final IconData icon;
  bool isSelected;

  SymptomItem({
    required this.id,
    required this.name,
    required this.icon,
    this.isSelected = false,
  });

  static const _namesUr = {
    'cramps': 'درد',
    'bloating': 'پھولنا',
    'headache': 'سر درد',
    'fatigue': 'تھکاوٹ',
    'acne': 'کیل مہاسے',
    'backache': 'کمر درد',
    'tender': 'حساسیت',
    'nausea': 'متلی',
    'hairloss': 'بالوں کا گرنا',
    'excesshair': 'زائد بال',
  };

  /// [name], but in Urdu when asked: for on-screen display only. The stored log always keeps the English
  /// [name] (lower-cased), since it is matched by id elsewhere (hormonal insights, the companion context).
  String nameIn(String language) => language == 'ur' ? (_namesUr[id] ?? name) : name;
}

/// The moods a user can log (stored as the id).
const moodOptions = <(String id, String emoji, String label)>[
  ('great', '😄', 'Great'),
  ('good', '🙂', 'Good'),
  ('okay', '😐', 'Okay'),
  ('low', '😔', 'Low'),
  ('bad', '😣', 'Bad'),
];

class AppState extends ChangeNotifier {
  int _currentTabIndex = 0;
  int get currentTabIndex => _currentTabIndex;

  int _selectedCalendarDay = 10;
  int get selectedCalendarDay => _selectedCalendarDay;

  String _userNotes = "";
  String get userNotes => _userNotes;

  String? _mood;
  String? get mood => _mood;

  double? _sleepHours;
  double? get sleepHours => _sleepHours;

  int? _stress;
  int? get stress => _stress;

  int? _energy;
  int? get energy => _energy;

  DateTime? _logDay;

  /// The day the log form is for (today unless she picked another day).
  DateTime get logDay => _logDay ?? dayOf(now());
  bool get loggingToday => logDay == dayOf(now());

  /// Where saved daily logs go (the on-device health store). Null in tests that do not need it.
  Future<void> Function(SymptomLog log)? onSaveLog;

  /// Clock, injectable for tests.
  DateTime Function() now = DateTime.now;

  final List<SymptomItem> _symptoms = [
    SymptomItem(id: 'cramps', name: 'Cramps', icon: Icons.water_drop_outlined),
    SymptomItem(id: 'bloating', name: 'Bloating', icon: Icons.bubble_chart_outlined),
    SymptomItem(id: 'headache', name: 'Headache', icon: Icons.sentiment_dissatisfied_outlined),
    SymptomItem(id: 'fatigue', name: 'Fatigue', icon: Icons.battery_alert_outlined),
    SymptomItem(id: 'acne', name: 'Acne', icon: Icons.auto_awesome_outlined),
    SymptomItem(id: 'backache', name: 'Backache', icon: Icons.accessibility_new_outlined),
    SymptomItem(id: 'tender', name: 'Tender', icon: Icons.spa_outlined),
    SymptomItem(id: 'nausea', name: 'Nausea', icon: Icons.sick_outlined),
    SymptomItem(id: 'hairloss', name: 'Hair loss', icon: Icons.content_cut_outlined),
    SymptomItem(id: 'excesshair', name: 'Excess hair', icon: Icons.waves_outlined),
  ];

  List<SymptomItem> get symptoms => _symptoms;

  void setTab(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  void selectCalendarDay(int day) {
    _selectedCalendarDay = day;
    notifyListeners();
  }

  void toggleSymptom(String id) {
    final index = _symptoms.indexWhere((s) => s.id == id);
    if (index != -1) {
      _symptoms[index].isSelected = !_symptoms[index].isSelected;
      notifyListeners();
    }
  }

  void setMood(String? id) {
    _mood = (_mood == id) ? null : id; // tapping the chosen mood again clears it
    notifyListeners();
  }

  void updateNotes(String notes) {
    _userNotes = notes;
  }

  void setSleep(double? hours) {
    _sleepHours = hours == null ? null : hours.clamp(0, 14).toDouble();
    notifyListeners();
  }

  void setStress(int? level) {
    _stress = _stress == level ? null : level; // tapping the chosen level again clears it
    notifyListeners();
  }

  void setEnergy(int? level) {
    _energy = _energy == level ? null : level;
    notifyListeners();
  }

  /// Chooses which day the form is for and fills it with whatever was saved for that day.
  void selectLogDay(DateTime day, SymptomLog? saved) {
    _logDay = dayOf(day);
    fillFrom(saved);
  }

  /// Fills the form from a saved entry (or clears it when there is none).
  void fillFrom(SymptomLog? l) {
    final have = {for (final x in l?.symptoms ?? const <String>[]) x};
    for (final sy in _symptoms) {
      sy.isSelected = have.contains(sy.name.toLowerCase());
    }
    _mood = l?.mood;
    _sleepHours = l?.sleepHours;
    _stress = l?.stress;
    _energy = l?.energy;
    _userNotes = l?.notes ?? '';
    notifyListeners();
  }

  /// Saves today's symptoms, mood and notes to the health store (so the companion and the report can use them).
  Future<void> saveDailyLog() async {
    final log = SymptomLog(
      date: logDay,
      symptoms: [for (final s in _symptoms) if (s.isSelected) s.name.toLowerCase()],
      mood: _mood,
      notes: _userNotes.trim(),
      sleepHours: _sleepHours,
      stress: _stress,
      energy: _energy,
    );
    await onSaveLog?.call(log);
    notifyListeners();
  }
}
