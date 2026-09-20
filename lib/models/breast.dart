import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import 'insights.dart';

// ---------------------------------------------------------------- Ultrasound scan (Module A)

enum ScanPrediction { normal, benign, malignant }

class ScanProbability {
  final ScanPrediction key;
  final String label;
  final double probability;

  const ScanProbability({required this.key, required this.label, required this.probability});

  factory ScanProbability.fromJson(Map<String, dynamic> json) => ScanProbability(
        key: ScanPrediction.values.byName(json['key'] as String),
        label: json['label'] as String,
        probability: (json['probability'] as num).toDouble(),
      );
}

class BreastScanResult {
  final ScanPrediction prediction;
  final String title;
  final double confidence; // calibrated probability of the predicted class
  final List<ScanProbability> probabilities;
  final Uint8List? heatmap; // JPEG: the scan with the model's focus overlaid
  final String summary;
  final List<Guidance> guidance;
  final double modelAccuracy;
  final String disclaimer;

  const BreastScanResult({
    required this.prediction,
    required this.title,
    required this.confidence,
    required this.probabilities,
    required this.heatmap,
    required this.summary,
    required this.guidance,
    required this.modelAccuracy,
    required this.disclaimer,
  });

  factory BreastScanResult.fromJson(Map<String, dynamic> json) => BreastScanResult(
        prediction: ScanPrediction.values.byName(json['prediction'] as String),
        title: json['title'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        probabilities: (json['probabilities'] as List)
            .map((p) => ScanProbability.fromJson(p as Map<String, dynamic>))
            .toList(),
        heatmap: json['heatmap_jpeg'] == null ? null : base64Decode(json['heatmap_jpeg'] as String),
        summary: json['summary'] as String,
        guidance: (json['guidance'] as List).map((g) => Guidance.fromJson(g as Map<String, dynamic>)).toList(),
        modelAccuracy: (json['model_accuracy'] as num).toDouble(),
        disclaimer: json['disclaimer'] as String,
      );

  int get percent => (confidence * 100).round();
}

// ---------------------------------------------------------------- Risk questionnaire (Module B)

enum Menopause { pre, post, unknown }

enum FirstBirth { under30, thirtyOrOlder, never, unknown }

enum BreastDensity { a, b, c, d }

enum LastMammogram { normal, falsePositive }

/// Symptom keys understood by the backend, with the text shown in the questionnaire.
const breastSymptoms = {
  'breast_lump': 'A new lump or thickening in the breast',
  'armpit_lump': 'A lump in the armpit',
  'nipple_discharge': 'Fluid or blood from a nipple (not breast milk)',
  'nipple_change': 'A nipple that has turned inward or changed',
  'skin_change': 'Skin dimpling, redness or orange-peel texture',
  'shape_change': 'A change in breast size or shape',
  'breast_pain': 'Breast pain',
};

class BreastRiskAnswers {
  final int age;
  final double heightCm;
  final double weightKg;
  final Menopause menopause;
  final bool? hormoneTherapy; // null = not sure / not asked
  final bool? surgicalMenopause;
  final FirstBirth firstBirth;
  final int? relatives; // mother, sisters, daughters with breast cancer; 2 = two or more; null = not sure
  final bool? breastBiopsy;
  final BreastDensity? density;
  final LastMammogram? lastMammogram; // null = never had one / don't know
  final Set<String> symptoms;

  const BreastRiskAnswers({
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.menopause,
    this.hormoneTherapy,
    this.surgicalMenopause,
    required this.firstBirth,
    this.relatives,
    this.breastBiopsy,
    this.density,
    this.lastMammogram,
    this.symptoms = const {},
  });

  Map<String, dynamic> toJson() => {
        'age': age,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'menopause': menopause.name,
        'hormone_therapy': hormoneTherapy,
        'surgical_menopause': surgicalMenopause,
        'first_birth': switch (firstBirth) {
          FirstBirth.under30 => 'under_30',
          FirstBirth.thirtyOrOlder => '30_or_older',
          FirstBirth.never => 'never',
          FirstBirth.unknown => 'unknown',
        },
        'relatives_with_breast_cancer': relatives,
        'breast_biopsy': breastBiopsy,
        'breast_density': density?.name,
        'last_mammogram': switch (lastMammogram) {
          LastMammogram.normal => 'normal',
          LastMammogram.falsePositive => 'false_positive',
          null => null,
        },
        'symptoms': symptoms.toList(),
      };
}

class RedFlag {
  final String key;
  final String label;
  final bool urgent; // false = see a doctor, but not within 2 weeks

  const RedFlag({required this.key, required this.label, required this.urgent});

  factory RedFlag.fromJson(Map<String, dynamic> json) => RedFlag(
        key: json['key'] as String,
        label: json['label'] as String,
        urgent: json['urgency'] == 'urgent',
      );
}

class BreastRiskResult {
  final double probability; // estimated chance of a diagnosis in the next year
  final double averageProbability; // same, for the average woman in the age group
  final double relativeRisk;
  final RiskLevel riskLevel;
  final String ageGroup;
  final List<RiskFactor> factors;
  final List<RedFlag> redFlags;
  final List<Guidance> guidance;
  final List<String> notes;
  final String summary;
  final String disclaimer;

  const BreastRiskResult({
    required this.probability,
    required this.averageProbability,
    required this.relativeRisk,
    required this.riskLevel,
    required this.ageGroup,
    required this.factors,
    required this.redFlags,
    required this.guidance,
    required this.notes,
    required this.summary,
    required this.disclaimer,
  });

  factory BreastRiskResult.fromJson(Map<String, dynamic> json) => BreastRiskResult(
        probability: (json['probability'] as num).toDouble(),
        averageProbability: (json['average_probability'] as num).toDouble(),
        relativeRisk: (json['relative_risk'] as num).toDouble(),
        riskLevel: RiskLevel.values.byName(json['risk_level'] as String),
        ageGroup: json['age_group'] as String,
        factors: (json['factors'] as List).map((f) => RiskFactor.fromJson(f as Map<String, dynamic>)).toList(),
        redFlags: (json['red_flags'] as List).map((f) => RedFlag.fromJson(f as Map<String, dynamic>)).toList(),
        guidance: (json['guidance'] as List).map((g) => Guidance.fromJson(g as Map<String, dynamic>)).toList(),
        notes: (json['notes'] as List).cast<String>(),
        summary: json['summary'] as String,
        disclaimer: json['disclaimer'] as String,
      );

  bool get needsUrgentVisit => redFlags.any((f) => f.urgent);

  String get riskLabel => switch (riskLevel) {
        RiskLevel.low => 'Low Risk',
        RiskLevel.medium => 'Moderate Risk',
        RiskLevel.high => 'High Risk',
      };
}

// ---------------------------------------------------------------- State

class BreastState extends ChangeNotifier {
  final ApiService _api;

  /// Called after each successful scan or risk assessment (the health store records them).
  final void Function(BreastScanResult result)? onScan;
  final void Function(BreastRiskResult result)? onRisk;

  BreastState({ApiService? api, this.onScan, this.onRisk}) : _api = api ?? ApiService();

  BreastScanResult? _scanResult;
  BreastScanResult? get scanResult => _scanResult;

  Uint8List? _scanImage;
  Uint8List? get scanImage => _scanImage;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  BreastRiskResult? _riskResult;
  BreastRiskResult? get riskResult => _riskResult;

  BreastRiskAnswers? _lastRiskAnswers;
  BreastRiskAnswers? get lastRiskAnswers => _lastRiskAnswers;

  bool _isAssessing = false;
  bool get isAssessing => _isAssessing;

  /// Sends an ultrasound image to the CNN. Returns null on success, or an error message.
  Future<String?> analyzeScan(Uint8List bytes, String filename) async {
    _isScanning = true;
    notifyListeners();
    try {
      _scanResult = await _api.predictBreastScan(bytes, filename);
      _scanImage = bytes;
      onScan?.call(_scanResult!);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  void clearScan() {
    _scanResult = null;
    _scanImage = null;
    notifyListeners();
  }

  /// Sends the questionnaire to the risk model. Returns null on success, or an error message.
  Future<String?> submitRisk(BreastRiskAnswers answers) async {
    _isAssessing = true;
    notifyListeners();
    try {
      _riskResult = await _api.predictBreastRisk(answers);
      _lastRiskAnswers = answers;
      onRisk?.call(_riskResult!);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } finally {
      _isAssessing = false;
      notifyListeners();
    }
  }
}
