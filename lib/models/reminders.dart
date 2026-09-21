import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/reminder_service.dart';
import 'cycle_engine.dart';
import 'cycle_params.dart';

/// A medicine the user wants a daily reminder for. Femora only reminds; it never suggests medicines or doses.
class Medication {
  final int id; // 0 to 999, stable, becomes part of the notification id
  final String name;
  final int hour;
  final int minute;
  final bool enabled;

  const Medication({required this.id, required this.name, required this.hour, required this.minute, this.enabled = true});

  Medication copyWith({String? name, int? hour, int? minute, bool? enabled}) =>
      Medication(id: id, name: name ?? this.name, hour: hour ?? this.hour, minute: minute ?? this.minute, enabled: enabled ?? this.enabled);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'hour': hour, 'minute': minute, 'enabled': enabled};

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        hour: (j['hour'] as num).toInt(),
        minute: (j['minute'] as num).toInt(),
        enabled: (j['enabled'] as bool?) ?? true,
      );
}

class ReminderSettings {
  static const alertHour = 9; // period and fertile-window alerts arrive at 9:00
  static const maxMedications = 10;
  static const maxNameLength = 40;

  final bool period;
  final int periodDaysBefore; // 0 (on the day) to 3
  final bool fertile; // fertile window start and ovulation day
  final bool dailyLog;
  final int dailyHour;
  final int dailyMinute;
  final List<Medication> medications;

  const ReminderSettings({
    this.period = false,
    this.periodDaysBefore = 1,
    this.fertile = false,
    this.dailyLog = false,
    this.dailyHour = 20,
    this.dailyMinute = 0,
    this.medications = const [],
  });

  ReminderSettings copyWith({bool? period, int? periodDaysBefore, bool? fertile, bool? dailyLog, int? dailyHour, int? dailyMinute, List<Medication>? medications}) => ReminderSettings(
        period: period ?? this.period,
        periodDaysBefore: periodDaysBefore ?? this.periodDaysBefore,
        fertile: fertile ?? this.fertile,
        dailyLog: dailyLog ?? this.dailyLog,
        dailyHour: dailyHour ?? this.dailyHour,
        dailyMinute: dailyMinute ?? this.dailyMinute,
        medications: medications ?? this.medications,
      );

  bool get anyOn => period || fertile || dailyLog || medications.any((m) => m.enabled);

  Map<String, dynamic> toJson() => {
        'period': period,
        'periodDaysBefore': periodDaysBefore,
        'fertile': fertile,
        'dailyLog': dailyLog,
        'dailyHour': dailyHour,
        'dailyMinute': dailyMinute,
        'medications': medications.map((m) => m.toJson()).toList(),
      };

  factory ReminderSettings.fromJson(Map<String, dynamic> j) => ReminderSettings(
        period: (j['period'] as bool?) ?? false,
        periodDaysBefore: ((j['periodDaysBefore'] as num?)?.toInt() ?? 1).clamp(0, 3),
        fertile: (j['fertile'] as bool?) ?? false,
        dailyLog: (j['dailyLog'] as bool?) ?? false,
        dailyHour: ((j['dailyHour'] as num?)?.toInt() ?? 20).clamp(0, 23),
        dailyMinute: ((j['dailyMinute'] as num?)?.toInt() ?? 0).clamp(0, 59),
        medications: ((j['medications'] as List?) ?? const []).map((e) => Medication.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

enum ReminderKind { period, fertile, ovulation, dailyLog, medication }

/// One notification that should exist on the phone.
class PlannedReminder {
  final int id;
  final ReminderKind kind;
  final String title;
  final String body;
  final DateTime when; // local wall-clock time of the (first) delivery
  final bool repeatsDaily;

  const PlannedReminder({required this.id, required this.kind, required this.title, required this.body, required this.when, this.repeatsDaily = false});

  String get channel => switch (kind) {
        ReminderKind.period => 'period',
        ReminderKind.fertile || ReminderKind.ovulation => 'fertility',
        ReminderKind.dailyLog => 'daily_log',
        ReminderKind.medication => 'medication',
      };

  String get channelName => switch (kind) {
        ReminderKind.period => 'Period reminders',
        ReminderKind.fertile || ReminderKind.ovulation => 'Fertile window reminders',
        ReminderKind.dailyLog => 'Daily log reminder',
        ReminderKind.medication => 'Medication reminders',
      };
}

const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _day(DateTime d) => '${d.day} ${_mon[d.month - 1]}';

/// Works out which reminders should exist, from the settings and the cycle predictions. Pure, so it is easy to test.
class ReminderPlanner {
  // Notification ids
  static const periodBase = 3101; // + 0..1 : the next two periods
  static const fertileBase = 3111; // + 0..2 : the current and next two cycles
  static const ovulationBase = 3121;
  static const dailyLogId = 3201;
  static const medicationBase = 4000; // + medication id

  static DateTime _at(DateTime day, int h, int m) => DateTime(day.year, day.month, day.day, h, m);

  /// The next time [h]:[m] occurs after [now].
  static DateTime nextOccurrence(DateTime now, int h, int m) {
    var t = DateTime(now.year, now.month, now.day, h, m);
    if (!t.isAfter(now)) t = DateTime(now.year, now.month, now.day + 1, h, m);
    return t;
  }

  static List<PlannedReminder> plan(ReminderSettings s, CycleEngine e, DateTime now) {
    final out = <PlannedReminder>[];
    final canPredict = e.hasHistory && !e.isLate; // no predictions while a period is overdue

    if (s.period && canPredict) {
      for (var k = 0; k < 2; k++) {
        final start = addDays(e.nextStart!, k * e.lengthDays);
        final when = _at(addDays(start, -s.periodDaysBefore), ReminderSettings.alertHour, 0);
        if (!when.isAfter(now)) continue;
        final window = 'likely between ${_day(addDays(start, -e.windowHalf))} and ${_day(addDays(start, e.windowHalf))}';
        final body = s.periodDaysBefore == 0
            ? 'Your period is expected today ($window).'
            : 'Your period is expected in ${s.periodDaysBefore} day${s.periodDaysBefore == 1 ? '' : 's'}, around ${_day(start)} ($window).';
        out.add(PlannedReminder(id: periodBase + k, kind: ReminderKind.period, title: 'Period coming up', body: body, when: when));
      }
    }

    if (s.fertile && canPredict) {
      for (var j = 0; j < 3; j++) {
        final base = addDays(e.lastStart!, j * e.lengthDays);
        final ov = addDays(base, e.lengthDays - kCycleParams.lutealDays);
        final fStart = addDays(ov, -5);
        final fEnd = addDays(ov, 1);
        final fWhen = _at(fStart, ReminderSettings.alertHour, 0);
        if (fWhen.isAfter(now)) {
          out.add(PlannedReminder(
            id: fertileBase + j,
            kind: ReminderKind.fertile,
            title: 'Fertile window starts',
            body: 'Your estimated fertile window runs from ${_day(fStart)} to ${_day(fEnd)}. This is an estimate and not a way to prevent pregnancy.',
            when: fWhen,
          ));
        }
        final oWhen = _at(ov, ReminderSettings.alertHour, 0);
        if (oWhen.isAfter(now)) {
          out.add(PlannedReminder(
            id: ovulationBase + j,
            kind: ReminderKind.ovulation,
            title: 'Estimated ovulation day',
            body: 'Today is your estimated ovulation day. It can shift from cycle to cycle.',
            when: oWhen,
          ));
        }
      }
    }

    if (s.dailyLog) {
      out.add(PlannedReminder(
        id: dailyLogId,
        kind: ReminderKind.dailyLog,
        title: 'How are you feeling today?',
        body: 'Log your symptoms, mood and sleep in Femora. It takes a minute.',
        when: nextOccurrence(now, s.dailyHour, s.dailyMinute),
        repeatsDaily: true,
      ));
    }

    for (final m in s.medications) {
      if (!m.enabled) continue;
      out.add(PlannedReminder(
        id: medicationBase + m.id,
        kind: ReminderKind.medication,
        title: 'Medication reminder',
        body: m.name,
        when: nextOccurrence(now, m.hour, m.minute),
        repeatsDaily: true,
      ));
    }
    out.sort((a, b) => a.when.compareTo(b.when));
    return out;
  }
}

/// The user's reminder settings, kept on the phone, and the notifications scheduled from them.
class RemindersState extends ChangeNotifier {
  static const _settingsKey = 'reminders_v1';
  static const _idsKey = 'reminders_ids_v1';

  final ReminderService _service;
  final DateTime Function() clock;

  RemindersState({ReminderService? service, DateTime Function()? clock})
      : _service = service ?? ReminderService(),
        clock = clock ?? DateTime.now;

  ReminderSettings settings = const ReminderSettings();
  bool loaded = false;
  List<int> _scheduled = [];

  bool get supported => _service.isSupported;
  List<int> get scheduledIds => List.unmodifiable(_scheduled);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_settingsKey);
      if (raw != null) settings = ReminderSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _scheduled = (prefs.getStringList(_idsKey) ?? const []).map(int.parse).toList();
    } catch (_) {
      settings = const ReminderSettings(); // a damaged file must never block the app
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
      await prefs.setStringList(_idsKey, _scheduled.map((i) => '$i').toList());
    } catch (_) {}
  }

  /// What will be sent next, given the cycle predictions.
  List<PlannedReminder> upcoming(CycleEngine e) => ReminderPlanner.plan(settings, e, clock());

  /// Replaces the scheduled notifications with the ones the current settings and predictions call for.
  Future<void> apply(CycleEngine e) async {
    if (!_service.isSupported) {
      notifyListeners();
      return;
    }
    await _service.cancelIds(_scheduled);
    final ok = <int>[];
    for (final r in ReminderPlanner.plan(settings, e, clock())) {
      if (await _service.scheduleAt(id: r.id, channel: r.channel, channelName: r.channelName, title: r.title, body: r.body, when: r.when, repeatDaily: r.repeatsDaily)) {
        ok.add(r.id);
      }
    }
    _scheduled = ok;
    await _save();
    notifyListeners();
  }

  /// Changes the settings. Turning something on first asks for permission. Returns null on success, or why it could not be done.
  Future<String?> update(ReminderSettings next, CycleEngine e) async {
    final turningOn = (next.period && !settings.period) ||
        (next.fertile && !settings.fertile) ||
        (next.dailyLog && !settings.dailyLog) ||
        next.medications.any((m) => m.enabled && !settings.medications.any((o) => o.id == m.id && o.enabled));
    if (turningOn) {
      if (!_service.isSupported) return 'Reminders are available in the Femora mobile app.';
      if (!await _service.ensurePermission()) return 'Allow notifications for Femora in your phone settings to get reminders.';
    }
    settings = next;
    await _save();
    await apply(e);
    return null;
  }

  Future<String?> addMedication(String name, int hour, int minute, CycleEngine e) async {
    final n = name.trim();
    if (n.isEmpty) return 'Type the name of the medicine.';
    if (n.length > ReminderSettings.maxNameLength) return 'Please keep the name under ${ReminderSettings.maxNameLength} characters.';
    if (settings.medications.length >= ReminderSettings.maxMedications) return 'You can add up to ${ReminderSettings.maxMedications} medication reminders.';
    var id = 0;
    while (settings.medications.any((m) => m.id == id)) {
      id++;
    }
    return update(settings.copyWith(medications: [...settings.medications, Medication(id: id, name: n, hour: hour, minute: minute)]), e);
  }

  Future<String?> setMedicationEnabled(int id, bool on, CycleEngine e) =>
      update(settings.copyWith(medications: [for (final m in settings.medications) m.id == id ? m.copyWith(enabled: on) : m]), e);

  Future<String?> setMedicationTime(int id, int hour, int minute, CycleEngine e) =>
      update(settings.copyWith(medications: [for (final m in settings.medications) m.id == id ? m.copyWith(hour: hour, minute: minute) : m]), e);

  Future<String?> removeMedication(int id, CycleEngine e) => update(settings.copyWith(medications: [for (final m in settings.medications) if (m.id != id) m]), e);

  /// Erases every reminder and setting (part of Delete all my data).
  Future<void> clearAll() async {
    await _service.cancelIds(_scheduled);
    _scheduled = [];
    settings = const ReminderSettings();
    await _save();
    notifyListeners();
  }
}
