import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/reminder_service.dart';

/// Monthly breast self-exam log and reminder setting, stored on the device.
class SelfExamState extends ChangeNotifier {
  static const _lastExamKey = 'self_exam_last';
  static const _reminderKey = 'self_exam_reminder';
  static const intervalDays = 30;

  final ReminderService _reminders;

  SelfExamState({ReminderService? reminders}) : _reminders = reminders ?? ReminderService();

  DateTime? _lastExam;
  DateTime? get lastExam => _lastExam;

  bool _reminderOn = false;
  bool get reminderOn => _reminderOn;

  bool get remindersSupported => _reminders.isSupported;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_lastExamKey);
    _lastExam = last == null ? null : DateTime.tryParse(last);
    _reminderOn = prefs.getBool(_reminderKey) ?? false;
    notifyListeners();
  }

  /// Days until the next exam is due (negative = overdue), or null if none has been logged.
  int? daysUntilDue(DateTime now) {
    if (_lastExam == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    return intervalDays - today.difference(_lastExam!).inDays;
  }

  Future<void> logExam([DateTime? when]) async {
    final d = when ?? DateTime.now();
    _lastExam = DateTime(d.year, d.month, d.day);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastExamKey, _lastExam!.toIso8601String());
    if (_reminderOn) await _reminders.scheduleMonthly(day: _reminderDay); // re-anchor to the exam date
    notifyListeners();
  }

  /// Turns the monthly reminder on or off. Returns null on success, or why it couldn't be turned on.
  Future<String?> setReminder(bool on) async {
    if (on) {
      if (!_reminders.isSupported) return 'Reminders are available in the Femora mobile app.';
      if (!await _reminders.scheduleMonthly(day: _reminderDay)) {
        return 'Allow notifications for Femora in your phone settings to get reminders.';
      }
    } else {
      await _reminders.cancel();
    }
    _reminderOn = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reminderKey, on);
    notifyListeners();
    return null;
  }

  // Remind on the same day of the month as the last exam (capped at 28 so short months aren't skipped)
  int get _reminderDay => math.min((_lastExam ?? DateTime.now()).day, 28);
}
