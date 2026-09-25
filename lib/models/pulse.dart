import 'dart:math' as math;

import 'cycle_engine.dart';

/// One camera frame reduced to the numbers the pulse needs: the average red and green of the fingertip.
class PulseSample {
  final double t; // seconds since the measurement started
  final double red;
  final double green;
  const PulseSample(this.t, this.red, this.green);
}

/// The result of a measurement.
class PulseResult {
  final int bpm;
  final double quality; // 0 to 1: how clean and regular the beats were
  final int beats;
  const PulseResult(this.bpm, this.quality, this.beats);
}

/// Heart rate from a fingertip over the camera and flash (photoplethysmography).
///
/// Each heartbeat pushes a little more blood into the fingertip, which absorbs a little more light, so the red level of the
/// frames rises and falls with the pulse. The red signal is detrended (a 1-second moving average removed), smoothed, and
/// the peaks are found with a refractory gap (no two beats closer than 0.33 s, i.e. at most 180 bpm). The rate is taken from
/// the median beat-to-beat interval, which ignores the odd missed or extra peak. A measurement is only accepted when the
/// finger covers the lens, enough beats were seen and the intervals are consistent; otherwise she is asked to try again.
class PulseAnalyzer {
  static const minBpm = 40, maxBpm = 180;
  static const minSeconds = 10.0;

  /// Whether the frame looks like a fingertip lit from behind: strongly red, little green.
  static bool fingerCovering(PulseSample s) => s.red > 90 && s.red > 1.8 * math.max(s.green, 1);

  static List<double> _movingAverage(List<double> x, int w) {
    final out = List<double>.filled(x.length, 0);
    var sum = 0.0;
    final q = <double>[];
    for (var i = 0; i < x.length; i++) {
      q.add(x[i]);
      sum += x[i];
      if (q.length > w) sum -= q.removeAt(0);
      out[i] = sum / q.length;
    }
    return out;
  }

  /// The pulse wave (detrended and smoothed red level), for drawing and for peak finding.
  static List<double> wave(List<PulseSample> samples) {
    if (samples.length < 8) return const [];
    final dur = samples.last.t - samples.first.t;
    final fps = dur > 0 ? (samples.length - 1) / dur : 30.0;
    final red = [for (final s in samples) s.red];
    final trend = _movingAverage(red, math.max(3, fps.round()));
    // centre the trend window: shift by half a window so the dip and peak are not delayed
    final half = math.max(1, fps.round() ~/ 2);
    final detrended = [for (var i = 0; i < red.length; i++) red[i] - trend[math.min(red.length - 1, i + half)]];
    final smooth = _movingAverage(detrended, math.max(2, (fps / 8).round()));
    return smooth;
  }

  /// Peak times (seconds) in the pulse wave.
  static List<double> beats(List<PulseSample> samples) {
    final w = wave(samples);
    if (w.length < 8) return const [];
    final mean = w.reduce((a, b) => a + b) / w.length;
    final sd = math.sqrt(w.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / w.length);
    // with the smoothing window, the detrended signal lags; blood volume peaks show as red minima (more absorption),
    // so the wave is inverted before looking for peaks
    final inv = [for (final v in w) -(v - mean)];
    final peaks = <int>[];
    for (var i = 1; i < inv.length - 1; i++) {
      if (inv[i] > inv[i - 1] && inv[i] >= inv[i + 1] && inv[i] > 0.3 * sd) {
        if (peaks.isEmpty || samples[i].t - samples[peaks.last].t >= 60 / maxBpm) {
          peaks.add(i);
        } else if (inv[i] > inv[peaks.last]) {
          peaks[peaks.length - 1] = i; // keep the taller of two close peaks
        }
      }
    }
    return [for (final i in peaks) samples[i].t];
  }

  /// The heart rate, or null when the recording is too short, the finger slipped, or the beats are too irregular to trust.
  static PulseResult? analyze(List<PulseSample> samples) {
    if (samples.length < 20 || samples.last.t - samples.first.t < minSeconds) return null;
    final covered = samples.where(fingerCovering).length / samples.length;
    if (covered < 0.9) return null;
    final b = beats(samples);
    if (b.length < 6) return null;
    final ibi = [for (var i = 1; i < b.length; i++) b[i] - b[i - 1]]..sort();
    final median = ibi[ibi.length ~/ 2];
    final bpm = (60 / median).round();
    if (bpm < minBpm || bpm > maxBpm) return null;
    // regularity: share of intervals within 20% of the median
    final consistent = ibi.where((x) => (x - median).abs() <= 0.2 * median).length / ibi.length;
    if (consistent < 0.6) return null;
    return PulseResult(bpm, consistent, b.length);
  }
}

/// One saved heart rate reading.
class HeartReading {
  final DateTime date;
  final int bpm;
  final bool resting; // taken in the morning before getting up (the comparable kind)

  const HeartReading({required this.date, required this.bpm, required this.resting});

  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'bpm': bpm, 'resting': resting};

  factory HeartReading.fromJson(Map<String, dynamic> j) =>
      HeartReading(date: DateTime.parse(j['date'] as String), bpm: (j['bpm'] as num).toInt(), resting: (j['resting'] as bool?) ?? true);
}

/// What the resting readings say, linked to the cycle.
class HeartInsights {
  static const minPerPhase = 3; // resting readings needed in each half of the cycle before comparing them
  static const anaemiaRise = 10; // bpm above her own usual level

  final List<HeartReading> readings; // oldest first
  final CycleEngine cycle;
  final DateTime today;

  HeartInsights(this.readings, this.cycle, this.today);

  List<HeartReading> get resting => [for (final r in readings) if (r.resting) r];

  double? _avg(Iterable<int> xs) => xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;

  /// Her usual resting rate: the median of her resting readings.
  int? get usual {
    final r = resting.map((x) => x.bpm).toList()..sort();
    return r.isEmpty ? null : r[r.length ~/ 2];
  }

  /// Average resting rate before ovulation (menstrual + follicular) and after it (luteal), when there are enough of each.
  ({double before, double after})? get phaseAverages {
    final before = <int>[], after = <int>[];
    for (final r in resting) {
      final p = cycle.phaseOn(r.date);
      if (p == null || p == CyclePhase.ovulation) continue;
      (p == CyclePhase.luteal ? after : before).add(r.bpm);
    }
    if (before.length < minPerPhase || after.length < minPerPhase) return null;
    return (before: _avg(before)!, after: _avg(after)!);
  }

  /// The resting rate usually rises by a few beats after ovulation; seeing it supports that ovulation happened.
  String? get cycleNote {
    final p = phaseAverages;
    if (p == null) return null;
    final d = p.after - p.before;
    if (d >= 1.5) {
      return 'Your resting heart rate is about ${d.round()} beats higher after ovulation than before it. A rise of 2 to 5 beats is the '
          'usual pattern and is one sign that ovulation happened.';
    }
    return 'Your resting heart rate is about the same before and after ovulation. That is common and not a problem on its own; '
        'the rise is small and easily hidden by sleep, stress or illness.';
  }

  /// A gentle hint to check haemoglobin: the last three resting readings are well above her usual level, and she recently
  /// logged tiredness or her last period was long (over 7 days). Needs at least 7 readings to know her usual level.
  bool anaemiaHint(Iterable<({DateTime date, List<String> symptoms})> logs) {
    final r = resting;
    if (r.length < 7) return false;
    final u = usual!;
    final last3 = r.sublist(r.length - 3);
    if (last3.any((x) => x.bpm < u + anaemiaRise)) return false;
    final tired = logs.any((l) => today.difference(l.date).inDays <= 21 && l.symptoms.contains('fatigue'));
    final longPeriod = cycle.flags.any((f) => f.id == 'longperiod');
    return tired || longPeriod;
  }
}
