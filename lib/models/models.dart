import 'package:flutter/material.dart';

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

  /// Saves today's symptoms, mood and notes to the health store (so the companion and the report can use them).
  Future<void> saveDailyLog() async {
    final log = SymptomLog(
      date: now(),
      symptoms: [for (final s in _symptoms) if (s.isSelected) s.name.toLowerCase()],
      mood: _mood,
      notes: _userNotes.trim(),
    );
    await onSaveLog?.call(log);
    notifyListeners();
  }
}
