import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import 'insights.dart';

class PcosAnswers {
  final int age;
  final double heightCm;
  final double weightKg;
  final double? waistIn;
  final double? hipIn;
  final bool irregularCycle;
  final int periodDays;
  final bool weightGain;
  final bool hairGrowth;
  final bool skinDarkening;
  final bool hairLoss;
  final bool pimples;
  final bool fastFood;
  final bool regularExercise;

  const PcosAnswers({
    required this.age,
    required this.heightCm,
    required this.weightKg,
    this.waistIn,
    this.hipIn,
    required this.irregularCycle,
    required this.periodDays,
    required this.weightGain,
    required this.hairGrowth,
    required this.skinDarkening,
    required this.hairLoss,
    required this.pimples,
    required this.fastFood,
    required this.regularExercise,
  });

  Map<String, dynamic> toJson() => {
        'age': age,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'waist_in': waistIn,
        'hip_in': hipIn,
        'irregular_cycle': irregularCycle,
        'period_days': periodDays,
        'weight_gain': weightGain,
        'hair_growth': hairGrowth,
        'skin_darkening': skinDarkening,
        'hair_loss': hairLoss,
        'pimples': pimples,
        'fast_food': fastFood,
        'regular_exercise': regularExercise,
      };
}

class PcosResult {
  final double probability; // 0.0 to 1.0
  final RiskLevel riskLevel;
  final double bmi;
  final List<RiskFactor> factors;
  final List<Guidance> guidance;
  final String disclaimer;

  const PcosResult({
    required this.probability,
    required this.riskLevel,
    required this.bmi,
    required this.factors,
    required this.guidance,
    required this.disclaimer,
  });

  factory PcosResult.fromJson(Map<String, dynamic> json) => PcosResult(
        probability: (json['probability'] as num).toDouble(),
        riskLevel: RiskLevel.values.byName(json['risk_level'] as String),
        bmi: (json['bmi'] as num).toDouble(),
        factors: (json['factors'] as List)
            .map((f) => RiskFactor.fromJson(f as Map<String, dynamic>))
            .toList(),
        guidance: (json['guidance'] as List)
            .map((g) => Guidance.fromJson(g as Map<String, dynamic>))
            .toList(),
        disclaimer: json['disclaimer'] as String,
      );

  int get percent => (probability * 100).round();

  String get riskLabel => switch (riskLevel) {
        RiskLevel.low => 'Low Risk',
        RiskLevel.medium => 'Moderate Risk',
        RiskLevel.high => 'High Risk',
      };
}

class PcosState extends ChangeNotifier {
  final ApiService _api;

  PcosState({ApiService? api}) : _api = api ?? ApiService();

  PcosResult? _result;
  PcosResult? get result => _result;

  PcosAnswers? _lastAnswers;
  PcosAnswers? get lastAnswers => _lastAnswers;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Sends the questionnaire to the model. Returns null on success, or an error message.
  Future<String?> submit(PcosAnswers answers) async {
    _isLoading = true;
    notifyListeners();
    try {
      _result = await _api.predictPcos(answers);
      _lastAnswers = answers;
      return null;
    } on ApiException catch (e) {
      return e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
