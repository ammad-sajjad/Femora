import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import 'insights.dart';
import 'pcos.dart';

/// One scenario sent to the server: the things a person can influence. A null field stays as she answered.
class WhatIfScenario {
  final String label;
  final double? weightKg;
  final bool? regularExercise;
  final bool? fastFood;

  const WhatIfScenario({required this.label, this.weightKg, this.regularExercise, this.fastFood});

  Map<String, dynamic> toJson() => {
        'label': label,
        if (weightKg != null) 'weight_kg': weightKg,
        if (regularExercise != null) 'regular_exercise': regularExercise,
        if (fastFood != null) 'fast_food': fastFood,
      };
}

class WhatIfOutcome {
  final String label;
  final double probability;
  final RiskLevel riskLevel;
  final double bmi;
  final double changePoints; // percentage points against the answers as given

  const WhatIfOutcome({required this.label, required this.probability, required this.riskLevel, required this.bmi, required this.changePoints});

  factory WhatIfOutcome.fromJson(Map<String, dynamic> j) => WhatIfOutcome(
        label: j['label'] as String,
        probability: (j['probability'] as num).toDouble(),
        riskLevel: RiskLevel.values.byName(j['risk_level'] as String),
        bmi: (j['bmi'] as num).toDouble(),
        changePoints: (j['change_points'] as num).toDouble(),
      );

  int get percent => (probability * 100).round();
}

class WhatIfResult {
  final double baselineProbability;
  final RiskLevel baselineRiskLevel;
  final List<WhatIfOutcome> outcomes;
  final String note;

  const WhatIfResult({required this.baselineProbability, required this.baselineRiskLevel, required this.outcomes, required this.note});

  factory WhatIfResult.fromJson(Map<String, dynamic> j) => WhatIfResult(
        baselineProbability: (j['baseline_probability'] as num).toDouble(),
        baselineRiskLevel: RiskLevel.values.byName(j['baseline_risk_level'] as String),
        outcomes: (j['outcomes'] as List).map((o) => WhatIfOutcome.fromJson(o as Map<String, dynamic>)).toList(),
        note: j['note'] as String,
      );

  int get baselinePercent => (baselineProbability * 100).round();
}

/// Which changes are worth showing, and how far the weight slider may go. Weight loss is never offered below a healthy BMI.
class WhatIfPlanner {
  static const healthyBmi = 18.5;
  static const overweightBmi = 25.0;
  static const sliderRoomUp = 10.0; // kg above the current weight

  static double bmi(double weightKg, double heightCm) => weightKg / math.pow(heightCm / 100, 2);

  static double _half(double kg) => (kg * 2).round() / 2;

  /// The lowest weight that keeps a BMI of 18.5 for this height (rounded up to half a kilo).
  static double healthyMinWeight(double heightCm) => (healthyBmi * math.pow(heightCm / 100, 2) * 2).ceilToDouble() / 2;

  static double sliderMin(PcosAnswers a) => math.min(a.weightKg, healthyMinWeight(a.heightCm));
  static double sliderMax(PcosAnswers a) => math.min(200.0, a.weightKg + sliderRoomUp);

  /// True when the current weight is already at or below the healthy range, so lowering it is not offered.
  static bool weightAtFloor(PcosAnswers a) => a.weightKg <= healthyMinWeight(a.heightCm);

  static List<WhatIfScenario> quickWins(PcosAnswers a) {
    final singles = <WhatIfScenario>[];
    if (!a.regularExercise) singles.add(const WhatIfScenario(label: 'Exercise regularly', regularExercise: true));
    if (a.fastFood) singles.add(const WhatIfScenario(label: 'Eat less fast food', fastFood: false));

    WhatIfScenario? lighter(double share, String pct) {
      if (bmi(a.weightKg, a.heightCm) < overweightBmi) return null;
      final w = _half(a.weightKg * (1 - share));
      if (w < healthyMinWeight(a.heightCm) || a.weightKg - w < 1) return null;
      return WhatIfScenario(label: 'About $pct lighter (${w.toStringAsFixed(1)} kg)', weightKg: w);
    }

    final five = lighter(0.05, '5%');
    final ten = lighter(0.10, '10%');
    final out = <WhatIfScenario>[...singles, if (five != null) five, if (ten != null) ten];

    final together = [...singles, if (five != null) five];
    if (together.length >= 2) {
      out.add(WhatIfScenario(
        label: 'All of these together',
        weightKg: five?.weightKg,
        regularExercise: singles.any((s) => s.regularExercise != null) ? true : null,
        fastFood: singles.any((s) => s.fastFood != null) ? false : null,
      ));
    }
    return out;
  }
}

/// The "what if" card's state: the controls, the quick wins, and the live estimate for her own changes.
class WhatIfState extends ChangeNotifier {
  final ApiService _api;
  final Duration debounce;

  WhatIfState({ApiService? api, this.debounce = const Duration(milliseconds: 350)}) : _api = api ?? ApiService();

  PcosAnswers? _answers;
  PcosAnswers? get answers => _answers;

  double? _weight; // null = as answered
  bool? _exercise;
  bool? _fastFood;

  List<WhatIfScenario> quickScenarios = const [];
  WhatIfResult? quick;
  WhatIfOutcome? live;
  bool loadingQuick = false;
  bool loadingLive = false;
  String? error;

  Timer? _timer;
  int _seq = 0;

  double get weightKg => _weight ?? _answers?.weightKg ?? 0;
  bool get exercise => _exercise ?? _answers?.regularExercise ?? false;
  bool get fastFood => _fastFood ?? _answers?.fastFood ?? false;

  bool get hasChanges {
    final a = _answers;
    if (a == null) return false;
    return (_weight != null && (_weight! - a.weightKg).abs() >= 0.05) ||
        (_exercise != null && _exercise != a.regularExercise) ||
        (_fastFood != null && _fastFood != a.fastFood);
  }

  double get bmi => _answers == null ? 0 : WhatIfPlanner.bmi(weightKg, _answers!.heightCm);

  /// Begins with these answers: clears the controls and asks for the quick wins.
  Future<void> start(PcosAnswers a) async {
    _timer?.cancel();
    _seq++;
    _answers = a;
    _weight = _exercise = _fastFood = null;
    live = null;
    quick = null;
    error = null;
    loadingLive = false;
    quickScenarios = WhatIfPlanner.quickWins(a);
    if (quickScenarios.isEmpty) {
      notifyListeners();
      return;
    }
    loadingQuick = true;
    notifyListeners();
    final mine = _seq;
    try {
      final r = await _api.whatIfPcos(a, quickScenarios);
      if (mine != _seq) return;
      quick = r;
    } on ApiException catch (e) {
      if (mine != _seq) return;
      error = e.message;
    } finally {
      if (mine == _seq) {
        loadingQuick = false;
        notifyListeners();
      }
    }
  }

  void setWeight(double kg) {
    final a = _answers;
    if (a == null) return;
    _weight = kg.clamp(WhatIfPlanner.sliderMin(a), WhatIfPlanner.sliderMax(a)).toDouble();
    _changed();
  }

  void setExercise(bool on) {
    _exercise = on;
    _changed();
  }

  void setFastFood(bool on) {
    _fastFood = on;
    _changed();
  }

  void reset() {
    _weight = _exercise = _fastFood = null;
    _changed();
  }

  void _changed() {
    _timer?.cancel();
    error = null;
    if (!hasChanges) {
      _seq++;
      live = null;
      loadingLive = false;
      notifyListeners();
      return;
    }
    loadingLive = true;
    notifyListeners();
    _timer = Timer(debounce, _runLive);
  }

  Future<void> _runLive() async {
    final a = _answers;
    if (a == null) return;
    final mine = ++_seq;
    final scenario = WhatIfScenario(
      label: 'Your changes',
      weightKg: _weight != null && (_weight! - a.weightKg).abs() >= 0.05 ? _weight : null,
      regularExercise: _exercise != null && _exercise != a.regularExercise ? _exercise : null,
      fastFood: _fastFood != null && _fastFood != a.fastFood ? _fastFood : null,
    );
    try {
      final r = await _api.whatIfPcos(a, [scenario]);
      if (mine != _seq) return; // a newer change has already been asked for
      live = r.outcomes.first;
      error = null;
    } on ApiException catch (e) {
      if (mine != _seq) return;
      error = e.message;
      live = null;
    } finally {
      if (mine == _seq) {
        loadingLive = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
