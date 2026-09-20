import 'package:femora/models/breast.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/models/insights.dart';
import 'package:femora/models/models.dart';
import 'package:femora/models/pcos.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _today = DateTime(2026, 9, 20, 10);

PcosResult _pcos() => PcosResult(
      probability: 0.71,
      riskLevel: RiskLevel.high,
      bmi: 25.9,
      factors: const [RiskFactor(key: 'irregular_cycle', label: 'Irregular Cycles'), RiskFactor(key: 'weight_gain', label: 'Weight Gain')],
      guidance: const [],
      disclaimer: 'x',
    );

BreastRiskResult _risk({bool lump = false}) => BreastRiskResult(
      probability: 0.0033,
      averageProbability: 0.0034,
      relativeRisk: 0.99,
      riskLevel: RiskLevel.low,
      ageGroup: '45-49',
      factors: const [],
      redFlags: lump ? const [RedFlag(key: 'breast_lump', label: 'Breast Lump', urgent: true)] : const [],
      guidance: const [],
      notes: const [],
      summary: 's',
      disclaimer: 'd',
    );

BreastScanResult _scan() => BreastScanResult(
      prediction: ScanPrediction.benign,
      title: 'Likely Benign',
      confidence: 0.88,
      probabilities: const [
        ScanProbability(key: ScanPrediction.normal, label: 'Normal', probability: 0.05),
        ScanProbability(key: ScanPrediction.benign, label: 'Benign', probability: 0.88),
        ScanProbability(key: ScanPrediction.malignant, label: 'Malignant', probability: 0.07),
      ],
      heatmap: Uint8List.fromList([1, 2, 3]),
      summary: 'sum',
      guidance: const [],
      modelAccuracy: 0.718,
      disclaimer: 'd',
    );

HealthStore _store() => HealthStore()..now = () => _today;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('everything is saved on the phone and loaded again', () async {
    final a = _store();
    await a.saveProfile(HealthProfile(name: 'Ayesha Khan', age: 27, heightCm: 162, weightKg: 68, concerns: {'pcos'}, language: 'ur', onboarded: true));
    a.recordPcos(_pcos());
    a.recordBreastRisk(_risk(lump: true));
    a.recordScan(_scan());
    await a.addLog(SymptomLog(date: _today, symptoms: const ['fatigue'], mood: 'low', notes: 'tired'));
    await Future<void>.delayed(Duration.zero);

    final b = _store();
    await b.load();
    expect(b.loaded, isTrue);
    expect(b.profile.name, 'Ayesha Khan');
    expect(b.profile.language, 'ur');
    expect(b.profile.onboarded, isTrue);
    expect(b.pcos?.percent, 71);
    expect(b.pcos?.factors, ['Irregular Cycles', 'Weight Gain']);
    expect(b.breastRisk?.redFlags, ['Breast Lump (urgent)']);
    expect(b.scan?.title, 'Likely Benign');
    expect(b.scan?.probabilities['benign'], 0.88);
    expect(b.scanHeatmap, [1, 2, 3]);
    expect(b.logs.single.mood, 'low');
  });

  test('a damaged saved file never blocks the app', () async {
    SharedPreferences.setMockInitialValues({'health_store_v1': '{not json'});
    final s = _store();
    await s.load();
    expect(s.loaded, isTrue);
    expect(s.profile.onboarded, isFalse);
    expect(s.pcos, isNull);
  });

  test('a second log on the same day replaces the first, and old logs are trimmed', () async {
    final s = _store();
    await s.addLog(SymptomLog(date: _today, symptoms: const ['cramps']));
    await s.addLog(SymptomLog(date: _today.add(const Duration(hours: 5)), symptoms: const ['acne'], mood: 'good'));
    expect(s.logs, hasLength(1));
    expect(s.logs.single.symptoms, ['acne']);
    for (var i = 1; i <= 70; i++) {
      await s.addLog(SymptomLog(date: _today.subtract(Duration(days: i)), symptoms: const ['x']));
    }
    expect(s.logs.length, HealthStore.maxLogs);
    expect(s.logs.last.date.day, _today.day); // the newest is kept
  });

  test('the companion context is name-free, complete and readable by the offline fallback', () async {
    final s = _store();
    await s.saveProfile(HealthProfile(name: 'Ayesha Khan', age: 27, heightCm: 162, weightKg: 68, concerns: {'pcos', 'breast'}, onboarded: true));
    s.recordPcos(_pcos());
    s.recordBreastRisk(_risk(lump: true));
    s.recordScan(_scan());
    await s.addLog(SymptomLog(date: _today, symptoms: const ['fatigue', 'cramps'], mood: 'low'));
    final ctx = s.companionContext(lastSelfExam: _today.subtract(const Duration(days: 12)));

    expect(ctx, isNot(contains('Ayesha')));
    expect(ctx, isNot(contains('Khan')));
    expect(ctx, contains('age 27'));
    expect(ctx, contains('BMI 25.9'));
    expect(ctx, contains('PCOS screening (today): 71% = high risk; main factors: Irregular Cycles, Weight Gain'));
    expect(ctx, contains('0.33% one-year risk vs 0.34% average for age 45-49 = 0.99x, low risk'));
    expect(ctx, contains('reported symptoms: Breast Lump (urgent)'));
    expect(ctx, contains('Breast ultrasound screening (today): Likely Benign, 88% confidence'));
    expect(ctx, contains('Last breast self-exam: 12 days ago.'));
    expect(ctx, contains('symptoms fatigue, cramps'));
    expect(ctx, contains('mood low'));
    expect(ctx.length, lessThan(3500));
    // every line is "label: facts", which the server's fallback needs
    for (final line in ctx.split('\n')) {
      expect(line, contains(':'));
    }
  });

  test('an empty store gives an empty context', () {
    expect(_store().companionContext(), '');
  });

  test('old logs are left out of the seven-day summary', () async {
    final s = _store();
    await s.addLog(SymptomLog(date: _today.subtract(const Duration(days: 20)), symptoms: const ['nausea']));
    expect(s.companionContext(), isNot(contains('nausea')));
  });

  test('ago() words', () {
    expect(HealthStore.ago(_today, _today), 'today');
    expect(HealthStore.ago(_today.subtract(const Duration(days: 1)), _today), 'yesterday');
    expect(HealthStore.ago(_today.subtract(const Duration(days: 9)), _today), '9 days ago');
  });

  test('delete all my data clears memory and storage', () async {
    final s = _store();
    await s.saveProfile(HealthProfile(name: 'A', onboarded: true));
    s.recordPcos(_pcos());
    await s.clearAll();
    expect(s.pcos, isNull);
    expect(s.profile.onboarded, isFalse);
    final again = _store();
    await again.load();
    expect(again.pcos, isNull);
    expect(again.profile.name, '');
  });

  test('saving the daily log in AppState stores symptoms, mood and notes', () async {
    final app = AppState()..now = () => _today;
    final saved = <SymptomLog>[];
    app.onSaveLog = (log) async => saved.add(log);
    app.toggleSymptom('cramps');
    app.toggleSymptom('acne');
    app.setMood('low');
    app.updateNotes('  rough day ');
    await app.saveDailyLog();
    expect(saved.single.symptoms, ['cramps', 'acne']);
    expect(saved.single.mood, 'low');
    expect(saved.single.notes, 'rough day');
    app.setMood('low'); // tapping the chosen mood again clears it
    expect(app.mood, isNull);
  });

  test('results reach the store through the state classes', () {
    final s = _store();
    final pcos = PcosState(onResult: s.recordPcos);
    pcos.onResult!(_pcos());
    expect(s.pcos?.level, 'high');
  });
}
