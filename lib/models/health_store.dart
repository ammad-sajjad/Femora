import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'breast.dart';
import 'cycle_engine.dart';
import 'pcos.dart';

/// Everything Femora knows about the user, stored on the phone only.
/// The AI companion and the health report both read from here, which is what makes the app feel like one product.
class HealthProfile {
  String name;
  int? age;
  double? heightCm;
  double? weightKg;
  Set<String> concerns; // pcos, cycle, pregnancy, breast
  String language; // en | ur
  bool personalize; // share a name-free summary with the AI companion
  bool onboarded;

  HealthProfile({
    this.name = '',
    this.age,
    this.heightCm,
    this.weightKg,
    Set<String>? concerns,
    this.language = 'en',
    this.personalize = true,
    this.onboarded = false,
  }) : concerns = concerns ?? <String>{};

  double? get bmi => (heightCm != null && weightKg != null && heightCm! > 0) ? weightKg! / ((heightCm! / 100) * (heightCm! / 100)) : null;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'concerns': concerns.toList(),
        'language': language,
        'personalize': personalize,
        'onboarded': onboarded,
      };

  factory HealthProfile.fromJson(Map<String, dynamic> j) => HealthProfile(
        name: (j['name'] as String?) ?? '',
        age: (j['age'] as num?)?.toInt(),
        heightCm: (j['heightCm'] as num?)?.toDouble(),
        weightKg: (j['weightKg'] as num?)?.toDouble(),
        concerns: ((j['concerns'] as List?) ?? const []).cast<String>().toSet(),
        language: (j['language'] as String?) ?? 'en',
        personalize: (j['personalize'] as bool?) ?? true,
        onboarded: (j['onboarded'] as bool?) ?? false,
      );
}

class PcosSummary {
  final DateTime date;
  final int percent;
  final String level; // low | medium | high
  final double bmi;
  final List<String> factors;

  const PcosSummary({required this.date, required this.percent, required this.level, required this.bmi, required this.factors});

  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'percent': percent, 'level': level, 'bmi': bmi, 'factors': factors};

  factory PcosSummary.fromJson(Map<String, dynamic> j) => PcosSummary(
        date: DateTime.parse(j['date'] as String),
        percent: (j['percent'] as num).toInt(),
        level: j['level'] as String,
        bmi: (j['bmi'] as num).toDouble(),
        factors: (j['factors'] as List).cast<String>(),
      );
}

class BreastRiskSummary {
  final DateTime date;
  final double probability;
  final double average;
  final double relativeRisk;
  final String level;
  final String ageGroup;
  final List<String> factors;
  final List<String> redFlags; // "Breast Lump (urgent)"

  const BreastRiskSummary({
    required this.date,
    required this.probability,
    required this.average,
    required this.relativeRisk,
    required this.level,
    required this.ageGroup,
    required this.factors,
    required this.redFlags,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'probability': probability,
        'average': average,
        'relativeRisk': relativeRisk,
        'level': level,
        'ageGroup': ageGroup,
        'factors': factors,
        'redFlags': redFlags,
      };

  factory BreastRiskSummary.fromJson(Map<String, dynamic> j) => BreastRiskSummary(
        date: DateTime.parse(j['date'] as String),
        probability: (j['probability'] as num).toDouble(),
        average: (j['average'] as num).toDouble(),
        relativeRisk: (j['relativeRisk'] as num).toDouble(),
        level: j['level'] as String,
        ageGroup: j['ageGroup'] as String,
        factors: (j['factors'] as List).cast<String>(),
        redFlags: (j['redFlags'] as List).cast<String>(),
      );
}

class ScanSummary {
  final DateTime date;
  final String prediction; // normal | benign | malignant
  final String title;
  final double confidence;
  final Map<String, double> probabilities;
  final double modelAccuracy;

  const ScanSummary({
    required this.date,
    required this.prediction,
    required this.title,
    required this.confidence,
    required this.probabilities,
    required this.modelAccuracy,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'prediction': prediction,
        'title': title,
        'confidence': confidence,
        'probabilities': probabilities,
        'modelAccuracy': modelAccuracy,
      };

  factory ScanSummary.fromJson(Map<String, dynamic> j) => ScanSummary(
        date: DateTime.parse(j['date'] as String),
        prediction: j['prediction'] as String,
        title: j['title'] as String,
        confidence: (j['confidence'] as num).toDouble(),
        probabilities: (j['probabilities'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
        modelAccuracy: (j['modelAccuracy'] as num).toDouble(),
      );
}

class SymptomLog {
  final DateTime date; // the day, without time
  final List<String> symptoms;
  final String? mood; // great | good | okay | low | bad
  final String notes;

  const SymptomLog({required this.date, required this.symptoms, this.mood, this.notes = ''});

  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'symptoms': symptoms, 'mood': mood, 'notes': notes};

  factory SymptomLog.fromJson(Map<String, dynamic> j) => SymptomLog(
        date: DateTime.parse(j['date'] as String),
        symptoms: (j['symptoms'] as List).cast<String>(),
        mood: j['mood'] as String?,
        notes: (j['notes'] as String?) ?? '',
      );
}

class HealthStore extends ChangeNotifier {
  static const _legacyKey = 'health_store_v1'; // written before accounts existed
  static const _legacyHeatKey = 'health_scan_heatmap_v1';
  static const maxLogs = 60;

  /// Whose data this is. Results, logs and the scan heatmap are stored under this account's own keys, so
  /// signing in as someone else on a shared phone never shows her the previous woman's results.
  String _account = 'guest';
  String get account => _account;

  String get _key => 'health_store_v1_$_account';
  String get _heatKey => 'health_scan_heatmap_v1_$_account';

  bool _loaded = false;
  bool get loaded => _loaded;

  HealthProfile profile = HealthProfile();
  PcosSummary? pcos;
  BreastRiskSummary? breastRisk;
  ScanSummary? scan;
  Uint8List? scanHeatmap; // heatmap image of the latest scan (for the report)
  List<SymptomLog> logs = [];
  List<PeriodEntry> periods = []; // every period the user logged, oldest first

  /// Injectable clock, so tests can pin "today".
  DateTime Function() now = DateTime.now;

  /// Switches to another signed-in account and loads that account's data.
  Future<void> useAccount(String id) async {
    if (id == _account && _loaded) return;
    _account = id;
    _loaded = false;
    profile = HealthProfile();
    pcos = null;
    breastRisk = null;
    scan = null;
    scanHeatmap = null;
    logs = [];
    periods = [];
    notifyListeners();
    await load();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Anything saved before accounts existed belongs to whoever is signing in first on this phone.
      if (!prefs.containsKey(_key) && prefs.containsKey(_legacyKey)) {
        await prefs.setString(_key, prefs.getString(_legacyKey)!);
        final heat = prefs.getString(_legacyHeatKey);
        if (heat != null) await prefs.setString(_heatKey, heat);
        await prefs.remove(_legacyKey);
        await prefs.remove(_legacyHeatKey);
      }
      final raw = prefs.getString(_key);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        profile = HealthProfile.fromJson(j['profile'] as Map<String, dynamic>);
        pcos = j['pcos'] == null ? null : PcosSummary.fromJson(j['pcos'] as Map<String, dynamic>);
        breastRisk = j['breastRisk'] == null ? null : BreastRiskSummary.fromJson(j['breastRisk'] as Map<String, dynamic>);
        scan = j['scan'] == null ? null : ScanSummary.fromJson(j['scan'] as Map<String, dynamic>);
        logs = ((j['logs'] as List?) ?? const []).map((e) => SymptomLog.fromJson(e as Map<String, dynamic>)).toList();
        periods = ((j['periods'] as List?) ?? const []).map((e) => PeriodEntry.fromJson(e as Map<String, dynamic>)).toList();
      }
      final heat = prefs.getString(_heatKey);
      scanHeatmap = heat == null ? null : base64Decode(heat);
    } catch (_) {
      // A damaged file must never block the app: start clean
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'profile': profile.toJson(),
          'pcos': pcos?.toJson(),
          'breastRisk': breastRisk?.toJson(),
          'scan': scan?.toJson(),
          'logs': logs.map((l) => l.toJson()).toList(),
          'periods': periods.map((e) => e.toJson()).toList(),
        }),
      );
      if (scanHeatmap == null) {
        await prefs.remove(_heatKey);
      } else {
        await prefs.setString(_heatKey, base64Encode(scanHeatmap!));
      }
    } catch (_) {}
  }

  Future<void> saveProfile(HealthProfile p) async {
    profile = p;
    notifyListeners();
    await _save();
  }

  void recordPcos(PcosResult r) {
    pcos = PcosSummary(date: now(), percent: r.percent, level: r.riskLevel.name, bmi: r.bmi, factors: r.factors.map((f) => f.label).toList());
    notifyListeners();
    _save();
  }

  void recordBreastRisk(BreastRiskResult r) {
    breastRisk = BreastRiskSummary(
      date: now(),
      probability: r.probability,
      average: r.averageProbability,
      relativeRisk: r.relativeRisk,
      level: r.riskLevel.name,
      ageGroup: r.ageGroup,
      factors: r.factors.map((f) => f.label).toList(),
      redFlags: r.redFlags.map((f) => '${f.label} (${f.urgent ? 'urgent' : 'soon'})').toList(),
    );
    notifyListeners();
    _save();
  }

  void recordScan(BreastScanResult r) {
    scan = ScanSummary(
      date: now(),
      prediction: r.prediction.name,
      title: r.title,
      confidence: r.confidence,
      probabilities: {for (final p in r.probabilities) p.key.name: p.probability},
      modelAccuracy: r.modelAccuracy,
    );
    scanHeatmap = r.heatmap;
    notifyListeners();
    _save();
  }

  /// Saves today's symptoms, mood and notes (one entry per day: a second save replaces the first).
  Future<void> addLog(SymptomLog log) async {
    final day = DateTime(log.date.year, log.date.month, log.date.day);
    logs.removeWhere((l) => l.date.year == day.year && l.date.month == day.month && l.date.day == day.day);
    logs.add(SymptomLog(date: day, symptoms: log.symptoms, mood: log.mood, notes: log.notes));
    logs.sort((a, b) => a.date.compareTo(b.date));
    if (logs.length > maxLogs) logs = logs.sublist(logs.length - maxLogs);
    notifyListeners();
    await _save();
  }

  static const maxPeriods = 48;

  /// The engine's view of the logged periods as of today.
  CycleEngine get cycle => CycleEngine(periods, now());

  /// Logs the first day of a period. Returns a message when it cannot be saved, otherwise null.
  Future<String?> logPeriodStart(DateTime day) async {
    final d = dayOf(day);
    final today = dayOf(now());
    if (d.isAfter(today)) return 'You can only log a period that has already started.';
    for (final e in periods) {
      final gap = daysBetween(e.start, d).abs();
      if (gap == 0) return 'That day is already logged as a period start.';
      if (gap < CycleEngine.minCycle) {
        return 'A period was already logged on ${_short(e.start)}. Periods normally start at least ${CycleEngine.minCycle} days apart; edit or remove that one first.';
      }
    }
    periods = [...periods, PeriodEntry(start: d)]..sort((a, b) => a.start.compareTo(b.start));
    if (periods.length > maxPeriods) periods = periods.sublist(periods.length - maxPeriods);
    notifyListeners();
    await _save();
    return null;
  }

  /// Logs the last day of bleeding for the period that contains [day]. Returns a message when it cannot be saved.
  Future<String?> logPeriodEnd(DateTime day) async {
    final d = dayOf(day);
    if (d.isAfter(dayOf(now()))) return 'You can only end a period on a day that has already happened.';
    final i = periods.lastIndexWhere((e) => !e.start.isAfter(d));
    if (i < 0) return 'Log when the period started first.';
    final e = periods[i];
    final len = daysBetween(e.start, d) + 1;
    if (len > 15) return 'That is more than 15 days after the period started. Check the date, or log a new period start.';
    if (i + 1 < periods.length && !d.isBefore(periods[i + 1].start)) return 'That day is after the next period started.';
    periods = [...periods]..[i] = e.withEnd(d);
    notifyListeners();
    await _save();
    return null;
  }

  Future<void> removePeriod(DateTime start) async {
    final d = dayOf(start);
    periods = periods.where((e) => e.start != d).toList();
    notifyListeners();
    await _save();
  }

  static String _short(DateTime d) => '${d.day}/${d.month}/${d.year}';

  /// Deletes everything Femora stored about the user (privacy).
  Future<void> clearAll() async {
    profile = HealthProfile();
    pcos = null;
    breastRisk = null;
    scan = null;
    scanHeatmap = null;
    logs = [];
    periods = [];
    notifyListeners();
    await _save();
  }

  bool get hasAnyResult => pcos != null || breastRisk != null || scan != null;

  static String ago(DateTime then, DateTime now) {
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(then.year, then.month, then.day)).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    return '$days days ago';
  }

  /// The name-free summary sent with each companion message (only when the user allows personalisation).
  /// Plain lines "Label: facts" so the server's offline fallback can also read it.
  String companionContext({DateTime? lastSelfExam}) {
    final n = now();
    final lines = <String>[];
    final p = profile;
    final basics = <String>[
      if (p.age != null) 'age ${p.age}',
      if (p.heightCm != null) 'height ${p.heightCm!.round()} cm',
      if (p.weightKg != null) 'weight ${p.weightKg!.round()} kg',
      if (p.bmi != null) 'BMI ${p.bmi!.toStringAsFixed(1)}',
    ];
    if (basics.isNotEmpty) lines.add('Profile: ${basics.join(', ')}.');
    if (p.concerns.isNotEmpty) lines.add('Interests: ${p.concerns.join(', ')}.');
    final pc = pcos;
    if (pc != null) {
      lines.add('PCOS screening (${ago(pc.date, n)}): ${pc.percent}% = ${pc.level} risk'
          '${pc.factors.isEmpty ? '' : '; main factors: ${pc.factors.join(', ')}'}. Screening estimate only.');
    }
    final br = breastRisk;
    if (br != null) {
      lines.add('Breast cancer risk questionnaire (${ago(br.date, n)}): ${(br.probability * 100).toStringAsFixed(2)}% one-year risk vs '
          '${(br.average * 100).toStringAsFixed(2)}% average for age ${br.ageGroup} = ${br.relativeRisk.toStringAsFixed(2)}x, ${br.level} risk'
          '${br.factors.isEmpty ? '' : '; factors: ${br.factors.join(', ')}'}'
          '${br.redFlags.isEmpty ? '' : '; reported symptoms: ${br.redFlags.join(', ')}'}.');
    }
    final sc = scan;
    if (sc != null) {
      lines.add('Breast ultrasound screening (${ago(sc.date, n)}): ${sc.title}, ${(sc.confidence * 100).round()}% confidence. '
          'A screening estimate, not a diagnosis.');
    }
    if (lastSelfExam != null) lines.add('Last breast self-exam: ${ago(lastSelfExam, n)}.');
    final cyc = CycleEngine(periods, n).companionSummary();
    if (cyc != null) lines.add(cyc);
    final recent = logs.where((l) => n.difference(l.date).inDays < 7).toList();
    if (recent.isNotEmpty) {
      final sy = <String>{for (final l in recent) ...l.symptoms};
      final moods = <String>[for (final l in recent) if (l.mood != null) l.mood!];
      lines.add('Recent log (last 7 days, ${recent.length} entries)'
          '${sy.isEmpty ? '' : ': symptoms ${sy.join(', ')}'}${moods.isEmpty ? '' : '; mood ${moods.last}'}.');
    }
    final text = lines.join('\n');
    return text.length > 3400 ? text.substring(0, 3400) : text;
  }
}
