import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import 'health_store.dart';

/// One value read from the photographed report.
class ReportFinding {
  final String name;
  final String value;
  final String unit;
  final String reference;
  final String status; // normal | low | high | abnormal | critical | unknown
  final String explanation;

  const ReportFinding({required this.name, required this.value, this.unit = '', this.reference = '', required this.status, required this.explanation});

  bool get outOfRange => status == 'low' || status == 'high' || status == 'abnormal' || status == 'critical';

  static const _statusUr = {'normal': 'نارمل', 'low': 'کم', 'high': 'زیادہ', 'abnormal': 'غیر معمولی', 'critical': 'تشویشناک', 'unknown': 'نامعلوم'};

  /// [status], but in Urdu when asked: for on-screen display only.
  String statusIn(String language) => language == 'ur' ? (_statusUr[status] ?? status) : status;

  factory ReportFinding.fromJson(Map<String, dynamic> j) => ReportFinding(
        name: j['name'] as String,
        value: (j['value'] as String?) ?? '',
        unit: (j['unit'] as String?) ?? '',
        reference: (j['reference'] as String?) ?? '',
        status: j['status'] as String,
        explanation: (j['explanation'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {'name': name, 'value': value, 'unit': unit, 'reference': reference, 'status': status, 'explanation': explanation};
}

/// A medical report explained by the server. Only this text is kept on the phone, never the photo.
class ExplainedReport {
  final DateTime date;
  final String kind; // blood_test | urine_test | hormone_test | ultrasound_report | prescription | other_medical | not_medical | unreadable
  final String summary;
  final List<ReportFinding> findings;
  final List<String> questions;
  final String urgency; // none | soon | urgent
  final String language; // en | ur
  final String disclaimer;

  const ExplainedReport({
    required this.date,
    required this.kind,
    required this.summary,
    required this.findings,
    required this.questions,
    required this.urgency,
    required this.language,
    required this.disclaimer,
  });

  static const _titles = {
    'blood_test': 'Blood test',
    'urine_test': 'Urine test',
    'hormone_test': 'Hormone test',
    'ultrasound_report': 'Ultrasound report',
    'prescription': 'Prescription',
    'other_medical': 'Medical report',
    'not_medical': 'Not a medical report',
    'unreadable': 'Could not read',
  };

  static const _titlesUr = {
    'blood_test': 'خون کا ٹیسٹ',
    'urine_test': 'پیشاب کا ٹیسٹ',
    'hormone_test': 'ہارمون ٹیسٹ',
    'ultrasound_report': 'الٹراساؤنڈ رپورٹ',
    'prescription': 'نسخہ',
    'other_medical': 'میڈیکل رپورٹ',
    'not_medical': 'میڈیکل رپورٹ نہیں',
    'unreadable': 'پڑھی نہیں جا سکی',
  };

  String get title => _titles[kind] ?? 'Medical report';

  /// [title], but in Urdu when asked: for on-screen display only.
  String titleIn(String language) => language == 'ur' ? (_titlesUr[kind] ?? 'میڈیکل رپورٹ') : title;

  /// Something to read here: false for a photo that was not a report or was too unclear.
  bool get readable => kind != 'not_medical' && kind != 'unreadable';

  List<ReportFinding> get outOfRange => [
        for (final f in findings)
          if (f.outOfRange) f
      ];

  factory ExplainedReport.fromJson(Map<String, dynamic> j, {DateTime? date}) => ExplainedReport(
        date: date ?? DateTime.parse(j['date'] as String),
        kind: j['kind'] as String,
        summary: j['summary'] as String,
        findings: ((j['findings'] as List?) ?? const []).map((e) => ReportFinding.fromJson(e as Map<String, dynamic>)).toList(),
        questions: ((j['questions_for_doctor'] ?? j['questions']) as List? ?? const []).cast<String>(),
        urgency: (j['urgency'] as String?) ?? 'none',
        language: (j['language'] as String?) ?? 'en',
        disclaimer: (j['disclaimer'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'kind': kind,
        'summary': summary,
        'findings': findings.map((f) => f.toJson()).toList(),
        'questions': questions,
        'urgency': urgency,
        'language': language,
        'disclaimer': disclaimer,
      };

  /// One name-free line for the companion. Only what stands out, kept short.
  String companionLine(DateTime now) {
    final odd = outOfRange.take(6).map((f) => '${f.name} ${f.value}${f.unit.isEmpty ? '' : ' ${f.unit}'} (${f.status})').join(', ');
    final head = '$title read from a photo (${HealthStore.ago(date, now)})';
    if (!readable) return '$head: could not be read.';
    if (kind == 'prescription') return '$head: ${findings.length} medicine${findings.length == 1 ? '' : 's'} listed. Do not advise on doses.';
    return '$head: ${odd.isEmpty ? 'no values outside the printed ranges' : 'outside the printed range: $odd'}'
        '${urgency == 'none' ? '' : '; urgency $urgency'}. Read by AI, may contain errors.';
  }
}

/// Talks to the reader on the server and keeps the result on screen. The photo itself is never stored.
class ReportReaderState extends ChangeNotifier {
  final ApiService _api;
  final void Function(ExplainedReport)? onReport;

  ReportReaderState({ApiService? api, this.onReport}) : _api = api ?? ApiService();

  bool _busy = false;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  ExplainedReport? _current;
  ExplainedReport? get current => _current;

  /// Shows a report kept earlier (from the list of past ones).
  void show(ExplainedReport r) {
    _current = r;
    _error = null;
    notifyListeners();
  }

  void reset() {
    _current = null;
    _error = null;
    notifyListeners();
  }

  /// Reads [photos] (one per page). Returns true on success; otherwise [error] says why.
  Future<bool> explain(List<Uint8List> photos, {required String language, DateTime Function()? now}) async {
    if (_busy || photos.isEmpty) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final r = await _api.explainReport(photos, language: language, date: (now ?? DateTime.now)());
      _current = r;
      if (r.readable) onReport?.call(r);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
