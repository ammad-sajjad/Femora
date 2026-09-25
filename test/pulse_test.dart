import 'dart:math' as math;

import 'package:femora/models/cycle_engine.dart';
import 'package:femora/models/pulse.dart';
import 'package:flutter_test/flutter_test.dart';

/// A synthetic fingertip recording: red around 180 with a pulse dip at [bpm], slow drift, and optional noise.
List<PulseSample> fingertip(int bpm, {double seconds = 20, double fps = 30, double noise = 0, double drift = 6, int seed = 1, double green = 40}) {
  final rnd = math.Random(seed);
  final f = bpm / 60;
  return [
    for (var i = 0; i < seconds * fps; i++)
      () {
        final t = i / fps;
        // a pulse wave shape: sharp rise, slower fall (sum of two harmonics)
        final phase = 2 * math.pi * f * t;
        final pulse = math.sin(phase) + 0.35 * math.sin(2 * phase + 0.6);
        final n = noise * (rnd.nextDouble() * 2 - 1);
        return PulseSample(t, 180 + drift * math.sin(2 * math.pi * 0.1 * t) - 2.5 * pulse + n, green);
      }(),
  ];
}

void main() {
  for (final bpm in [52, 64, 75, 88, 110, 140]) {
    test('a clean $bpm bpm recording is read within 3 bpm', () {
      final r = PulseAnalyzer.analyze(fingertip(bpm));
      expect(r, isNotNull);
      expect((r!.bpm - bpm).abs(), lessThanOrEqualTo(3));
    });
  }

  test('moderate camera noise still gives the right rate', () {
    for (final seed in [1, 2, 3, 4, 5]) {
      final r = PulseAnalyzer.analyze(fingertip(72, noise: 1.2, seed: seed));
      expect(r, isNotNull, reason: 'seed $seed');
      expect((r!.bpm - 72).abs(), lessThanOrEqualTo(4), reason: 'seed $seed');
    }
  });

  test('pure noise is rejected rather than turned into a number', () {
    final rnd = math.Random(9);
    final samples = [for (var i = 0; i < 600; i++) PulseSample(i / 30, 180 + 8 * (rnd.nextDouble() * 2 - 1), 40)];
    expect(PulseAnalyzer.analyze(samples), isNull);
  });

  test('without a finger over the lens nothing is measured', () {
    expect(PulseAnalyzer.analyze(fingertip(70, green: 150)), isNull); // an ordinary room: green is as bright as red
    expect(PulseAnalyzer.fingerCovering(const PulseSample(0, 200, 60)), isTrue);
    expect(PulseAnalyzer.fingerCovering(const PulseSample(0, 60, 50)), isFalse);
  });

  test('too short a recording is not trusted', () {
    expect(PulseAnalyzer.analyze(fingertip(70, seconds: 6)), isNull);
  });

  test('an uneven frame rate (phones drop frames) is handled', () {
    final even = fingertip(80, fps: 30);
    final uneven = [for (var i = 0; i < even.length; i++) if (i % 7 != 3) even[i]];
    expect((PulseAnalyzer.analyze(uneven)!.bpm - 80).abs(), lessThanOrEqualTo(3));
  });

  group('insights', () {
    final today = DateTime(2026, 9, 20);
    DateTime d(int ago) => today.subtract(Duration(days: ago));
    final periods = [for (final ago in [84, 56, 28, 0]) PeriodEntry(start: d(ago), end: d(ago - 4))];
    final cycle = CycleEngine(periods, today);

    test('the rise after ovulation is described once there are enough readings in both halves', () {
      final readings = [
        for (final ago in [26, 24, 22, 20]) HeartReading(date: d(ago), bpm: 62, resting: true), // follicular (cycle days 3 to 9)
        for (final ago in [10, 8, 6, 4]) HeartReading(date: d(ago), bpm: 66, resting: true), // luteal
      ];
      final h = HeartInsights(readings, cycle, today);
      expect(h.phaseAverages!.after - h.phaseAverages!.before, closeTo(4, 0.01));
      expect(h.cycleNote, contains('about 4 beats higher after ovulation'));
    });

    test('with too few readings nothing is concluded', () {
      final h = HeartInsights([HeartReading(date: d(3), bpm: 70, resting: true)], cycle, today);
      expect(h.phaseAverages, isNull);
      expect(h.cycleNote, isNull);
      expect(h.anaemiaHint(const []), isFalse);
    });

    test('a sustained rise plus tiredness suggests a haemoglobin check', () {
      final readings = [
        for (var i = 0; i < 7; i++) HeartReading(date: d(20 - i), bpm: 64, resting: true),
        for (var i = 0; i < 3; i++) HeartReading(date: d(3 - i), bpm: 78, resting: true),
      ];
      final h = HeartInsights(readings, cycle, today);
      expect(h.anaemiaHint([(date: d(2), symptoms: ['fatigue'])]), isTrue);
      expect(h.anaemiaHint([(date: d(2), symptoms: ['cramps'])]), isFalse);
      // one high reading is not a trend
      final once = HeartInsights([...readings.sublist(0, 9), HeartReading(date: d(0), bpm: 64, resting: true)], cycle, today);
      expect(once.anaemiaHint([(date: d(2), symptoms: ['fatigue'])]), isFalse);
    });

    test('readings taken later in the day are kept but not compared', () {
      final h = HeartInsights([HeartReading(date: d(1), bpm: 95, resting: false)], cycle, today);
      expect(h.resting, isEmpty);
      expect(h.usual, isNull);
    });
  });
}
