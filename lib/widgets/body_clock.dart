import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../models/cycle_engine.dart';
import '../models/cycle_params.dart';
import '../models/hormone_insights.dart';

/// Phase colours, chosen to read on the berry hero gradient.
const phaseColours = {
  CyclePhase.menstrual: Color(0xFFFF8FA3),
  CyclePhase.follicular: Color(0xFFFFE0EE),
  CyclePhase.ovulation: Color(0xFFFFD166),
  CyclePhase.luteal: Color(0xFFC8B5FF),
};

/// Whether the Home card may keep moving after its intro. Off when the phone asks for less motion, and in widget
/// tests (a never-ending animation would stop `pumpAndSettle` from ever settling).
bool ambientMotion(BuildContext context) =>
    !MediaQuery.of(context).disableAnimations && !WidgetsBinding.instance.runtimeType.toString().contains('Test');

/// A controller that loops for as long as the widget is on screen, if [ambientMotion] allows it.
mixin _Ambient<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  Duration get ambientPeriod;
  late final ambient = AnimationController(vsync: this, duration: ambientPeriod);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ambientMotion(context)) {
      if (!ambient.isAnimating) ambient.repeat();
    } else {
      ambient.stop();
    }
  }

  @override
  void dispose() {
    ambient.dispose();
    super.dispose();
  }
}

/// Where the phases fall in a cycle of [length] days: (phase, first day index, day after the last), in order.
List<(CyclePhase, int, int)> phaseSegments(int length, int periodDays, {int lutealDays = 13}) {
  final o = length - lutealDays;
  final p = periodDays.clamp(1, math.max(1, o - 2)).toInt();
  return [
    (CyclePhase.menstrual, 0, p),
    (CyclePhase.follicular, p, math.max(p, o - 1)),
    (CyclePhase.ovulation, math.max(p, o - 1), o + 2),
    (CyclePhase.luteal, o + 2, length),
  ];
}

/// The Home screen's "body clock": the cycle as a ring of phases with today's position, and the typical hormone
/// waves underneath. It draws itself in when it appears (the number counting up), then keeps living: a glint of
/// light circles the ring, today's marker breathes and an inner ring of dots turns slowly.
class BodyClock extends StatefulWidget {
  final CycleEngine engine;
  final String language;
  final String centreValue;
  final String centreLabel;

  const BodyClock({super.key, required this.engine, required this.language, required this.centreValue, required this.centreLabel});

  @override
  State<BodyClock> createState() => _BodyClockState();
}

class _BodyClockState extends State<BodyClock> with TickerProviderStateMixin, _Ambient {
  @override
  Duration get ambientPeriod => const Duration(seconds: 6);

  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  var _pulsesLeft = 3; // a finite pulse: the screen settles, which also keeps widget tests deterministic

  @override
  void initState() {
    super.initState();
    _pulse.addStatusListener((s) {
      if (s == AnimationStatus.completed && --_pulsesLeft > 0) _pulse.forward(from: 0);
    });
    _intro.forward().whenComplete(() {
      if (mounted) _pulse.forward();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.engine;
    return Semantics(
      label: '${widget.centreValue} ${widget.centreLabel}',
      child: AnimatedBuilder(
        animation: Listenable.merge([_intro, _pulse, ambient]),
        builder: (context, _) => SizedBox(
          width: 132,
          height: 132,
          child: CustomPaint(
            painter: _RingPainter(
              length: e.lengthDays,
              periodDays: e.periodDays,
              day: e.cycleDay,
              late: e.isLate,
              progress: Curves.easeOutCubic.transform(_intro.value),
              pulse: _pulse.isAnimating ? math.sin(_pulse.value * math.pi) : 0,
              ambient: ambient.isAnimating ? ambient.value : null,
            ),
            child: Center(
              child: Opacity(
                opacity: Curves.easeIn.transform(_intro.value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_counted(widget.centreValue, Curves.easeOutCubic.transform(_intro.value)),
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white, height: 1.0)),
                    const SizedBox(height: 3),
                    Text(widget.centreLabel,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1.4)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "29" counts up from 0 during the intro; anything that is not a whole number is shown as it is.
String _counted(String value, double t) {
  final n = int.tryParse(value);
  return n == null || t >= 1 ? value : '${(n * t).round()}';
}

class _RingPainter extends CustomPainter {
  final int length, periodDays, day;
  final bool late;
  final double progress; // 0 to 1: how much of the ring has been drawn in
  final double pulse; // 0 to 1: the marker's glow
  final double? ambient; // 0 to 1 round a loop, or null when the card stays still

  _RingPainter(
      {required this.length, required this.periodDays, required this.day, required this.late, required this.progress, required this.pulse, this.ambient});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - stroke / 2 - 3;
    final rect = Rect.fromCircle(center: c, radius: r);
    const start = -math.pi / 2;
    const gap = 0.05; // radians between phases

    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = Colors.white.withValues(alpha: 0.16));

    final sweepLimit = 2 * math.pi * progress;
    for (final (phase, from, to) in phaseSegments(length, periodDays, lutealDays: kCycleParams.lutealDays)) {
      if (to <= from) continue;
      final a0 = 2 * math.pi * from / length + gap / 2;
      final a1 = math.min(2 * math.pi * to / length - gap / 2, sweepLimit);
      if (a1 <= a0) continue;
      canvas.drawArc(
          rect,
          start + a0,
          a1 - a0,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = phaseColours[phase]!);
    }

    final a = ambient;
    if (a != null && progress >= 1) {
      // a glint of light travelling round the ring
      final head = start + 2 * math.pi * a;
      const tail = 0.9;
      canvas.drawArc(
          rect,
          head - tail,
          tail,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..shader = SweepGradient(
              startAngle: 0,
              endAngle: tail,
              colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.55)],
              transform: GradientRotation(head - tail),
            ).createShader(rect));
      // an inner ring of dots, turning slowly the other way
      final ri = r - stroke - 5;
      for (var i = 0; i < 36; i++) {
        final ang = -2 * math.pi * a / 3 + 2 * math.pi * i / 36;
        final twinkle = 0.5 + 0.5 * math.sin(2 * math.pi * (a * 2 + i / 9));
        canvas.drawCircle(c + Offset(math.cos(ang), math.sin(ang)) * ri, i % 3 == 0 ? 1.3 : 0.8,
            Paint()..color = Colors.white.withValues(alpha: 0.12 + 0.28 * twinkle));
      }
    }

    // Today's marker travels round with the intro; a late period parks it at the end of the ring
    final f = late ? 1.0 : ((day - 0.5) / length).clamp(0.0, 1.0);
    final angle = start + 2 * math.pi * f * progress;
    final m = c + Offset(math.cos(angle), math.sin(angle)) * r;
    if (pulse > 0) {
      canvas.drawCircle(m, 9 + 7 * pulse, Paint()..color = Colors.white.withValues(alpha: 0.35 * (1 - pulse * 0.5)));
    } else if (a != null && progress >= 1) {
      // breathing, twice per loop
      final b = (a * 2) % 1;
      canvas.drawCircle(m, 9 + 10 * b, Paint()..color = Colors.white.withValues(alpha: 0.4 * (1 - b)));
    }
    canvas.drawCircle(m, 9, Paint()..color = Colors.white);
    canvas.drawCircle(m, 4.5, Paint()..color = late ? const Color(0xFFFF5A7A) : const Color(0xFFE0457B));
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.pulse != pulse || old.ambient != ambient || old.day != day || old.length != length || old.late != late;
}

/// The typical estrogen, progesterone and LH waves across her cycle, with a line at today. Illustrative, not measured.
/// After drawing in, the waves keep gently rising and falling and a spark runs along the estrogen curve up to today.
class HormoneWaves extends StatefulWidget {
  final CycleEngine engine;
  final String language;

  const HormoneWaves({super.key, required this.engine, required this.language});

  @override
  State<HormoneWaves> createState() => _HormoneWavesState();
}

class _HormoneWavesState extends State<HormoneWaves> with TickerProviderStateMixin, _Ambient {
  @override
  Duration get ambientPeriod => const Duration(seconds: 4);

  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.engine;
    final language = widget.language;
    final curves = typicalHormoneCurves(e.lengthDays, lutealDays: kCycleParams.lutealDays);
    Widget legend(Color colour, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 3, decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 10.5, color: Colors.white.withValues(alpha: 0.9))),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 52,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: Listenable.merge([_intro, ambient]),
            builder: (context, _) => CustomPaint(
              painter: _WavesPainter(
                estrogen: curves.estrogen,
                progesterone: curves.progesterone,
                lh: curves.lh,
                today: e.isLate ? null : e.cycleDay - 1,
                progress: Curves.easeInOutCubic.transform(_intro.value),
                ambient: ambient.isAnimating ? ambient.value : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            legend(Colors.white, t(language, 'Estrogen', 'ایسٹروجن')),
            legend(phaseColours[CyclePhase.luteal]!, t(language, 'Progesterone', 'پروجیسٹرون')),
            legend(phaseColours[CyclePhase.ovulation]!, 'LH'),
            Text(t(language, 'Typical pattern, not measured', 'عام نمونہ، ناپا ہوا نہیں'),
                style: TextStyle(fontFamily: 'Inter', fontSize: 10.5, fontStyle: FontStyle.italic, color: Colors.white.withValues(alpha: 0.75))),
          ],
        ),
      ],
    );
  }
}

class _WavesPainter extends CustomPainter {
  final List<double> estrogen, progesterone, lh;
  final int? today; // day index, or null when the period is late (today is beyond the drawn cycle)
  final double progress;
  final double? ambient;

  _WavesPainter({required this.estrogen, required this.progesterone, required this.lh, required this.today, required this.progress, this.ambient});

  /// While the card is alive each wave breathes a little, each on its own beat.
  List<double> _breathe(List<double> ys, double phase) {
    final a = ambient;
    if (a == null || progress < 1) return ys;
    final k = 1 + 0.06 * math.sin(2 * math.pi * (a + phase));
    return [for (var i = 0; i < ys.length; i++) (ys[i] * (k + 0.02 * math.sin(2 * math.pi * (a * 2 + i / ys.length)))).clamp(0.0, 1.0)];
  }

  double _y(List<double> ys, double i, Size size) {
    final lo = i.floor().clamp(0, ys.length - 1), hi = i.ceil().clamp(0, ys.length - 1);
    final v = ys[lo] + (ys[hi] - ys[lo]) * (i - lo);
    return size.height - 4 - v * (size.height - 8);
  }

  Path _path(List<double> ys, Size size) {
    final n = ys.length;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final x = size.width * i / (n - 1);
      final y = size.height - 4 - ys[i] * (size.height - 8);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // smooth: quadratic curve through midpoints
        final px = size.width * (i - 1) / (n - 1);
        final py = size.height - 4 - ys[i - 1] * (size.height - 8);
        path.quadraticBezierTo(px, py, (px + x) / 2, (py + y) / 2);
        if (i == n - 1) path.lineTo(x, y);
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height)); // drawn in from left to right

    final estrogen = _breathe(this.estrogen, 0);
    final progesterone = _breathe(this.progesterone, 0.33);
    final lh = _breathe(this.lh, 0.66);
    final progesteronePath = _path(progesterone, size);
    final fill = Path.from(progesteronePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = phaseColours[CyclePhase.luteal]!.withValues(alpha: 0.22));
    canvas.drawPath(
        progesteronePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = phaseColours[CyclePhase.luteal]!);
    canvas.drawPath(
        _path(lh, size),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = phaseColours[CyclePhase.ovulation]!);
    canvas.drawPath(
        _path(estrogen, size),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = Colors.white);
    canvas.restore();

    final t = today;
    if (t != null && progress > 0.98) {
      final x = size.width * t / (estrogen.length - 1).clamp(1, 1000);
      final line = Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..strokeWidth = 1.2;
      for (var y = 0.0; y < size.height; y += 6) {
        canvas.drawLine(Offset(x, y), Offset(x, math.min(y + 3, size.height)), line);
      }
      final ey = size.height - 4 - estrogen[t.clamp(0, estrogen.length - 1)] * (size.height - 8);
      final a = ambient;
      if (a != null) {
        final b = (a * 2) % 1;
        canvas.drawCircle(Offset(x, ey), 4 + 7 * b, Paint()..color = Colors.white.withValues(alpha: 0.45 * (1 - b)));
      }
      canvas.drawCircle(Offset(x, ey), 4, Paint()..color = Colors.white);
    }

    // a spark running along the estrogen curve from the start of the cycle up to today
    final a = ambient;
    if (a != null && progress >= 1) {
      final end = (t ?? estrogen.length - 1).toDouble();
      final i = end * Curves.easeInOut.transform(a);
      final pos = Offset(size.width * i / (estrogen.length - 1), _y(estrogen, i, size));
      final fade = math.sin(math.pi * a);
      canvas.drawCircle(
          pos,
          7,
          Paint()
            ..color = const Color(0xFFFFE0EE).withValues(alpha: 0.35 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(pos, 2.4, Paint()..color = Colors.white.withValues(alpha: 0.95 * fade));
    }
  }

  @override
  bool shouldRepaint(_WavesPainter old) => old.progress != progress || old.ambient != ambient || old.today != today || old.estrogen != estrogen;
}

/// Soft lights drifting slowly behind the Home cycle card, so the card itself feels alive.
class AmbientGlow extends StatefulWidget {
  const AmbientGlow({super.key});

  @override
  State<AmbientGlow> createState() => _AmbientGlowState();
}

class _AmbientGlowState extends State<AmbientGlow> with TickerProviderStateMixin, _Ambient {
  @override
  Duration get ambientPeriod => const Duration(seconds: 16);

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: ambient,
            builder: (context, _) => CustomPaint(painter: _GlowPainter(ambient.value), size: Size.infinite),
          ),
        ),
      );
}

class _GlowPainter extends CustomPainter {
  final double t;
  _GlowPainter(this.t);

  // (x, y, radius as a share of the card, colour, how far it drifts, its own beat)
  static const _lights = [
    (0.88, 0.10, 0.55, Color(0xFFFFD1E0), 0.06, 0.0),
    (0.08, 0.95, 0.50, Color(0xFFC8B5FF), 0.07, 0.35),
    (0.55, 0.45, 0.28, Color(0xFFFFD166), 0.09, 0.7),
    (0.25, 0.20, 0.22, Color(0xFFFFFFFF), 0.08, 0.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    for (final (x, y, rad, colour, drift, beat) in _lights) {
      final a = 2 * math.pi * (t + beat);
      final c = Offset((x + drift * math.cos(a)) * w, (y + drift * 1.4 * math.sin(a)) * h);
      final r = rad * math.min(w, h) * (1 + 0.1 * math.sin(a * 2));
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = RadialGradient(colors: [colour.withValues(alpha: 0.22), colour.withValues(alpha: 0)])
                .createShader(Rect.fromCircle(center: c, radius: r)));
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.t != t;
}
