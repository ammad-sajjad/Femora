import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Small, soft animations for the AI companion screen.
///
/// libraries.dev sells these effects as React components, which a Flutter app cannot use, so the two the
/// companion needed (a beam travelling around a border, and orbs that pulse while something is thinking)
/// are drawn here with Flutter's own animation classes. Everything is deliberately gentle: slow curves and
/// low-contrast pinks, so the screen feels calm rather than busy.

/// Turned off by widget tests, where `pumpAndSettle` would otherwise wait for ever on an animation that repeats.
bool companionAnimations = true;

/// A soft pink beam that travels around a circle, wrapped around [child].
///
/// Used behind the companion avatar so it looks awake and friendly without demanding attention.
class GlowRing extends StatefulWidget {
  const GlowRing(
      {super.key, required this.child, this.size = 46, this.thickness = 2.4, this.duration = const Duration(seconds: 4), this.animate = true});

  final Widget child;
  final double size;
  final double thickness;
  final Duration duration;

  /// Off in tests and wherever a still frame is wanted.
  final bool animate;

  @override
  State<GlowRing> createState() => _GlowRingState();
}

class _GlowRingState extends State<GlowRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    if (widget.animate && companionAnimations) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              size: Size.square(widget.size),
              painter: _BeamPainter(turn: _c.value, thickness: widget.thickness),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _BeamPainter extends CustomPainter {
  _BeamPainter({required this.turn, required this.thickness});

  final double turn;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = (size.shortestSide - thickness) / 2;
    final start = turn * 2 * math.pi;

    // The faint full ring keeps the circle readable when the bright part is on the far side.
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = const Color(0xFFFFD9E4),
    );

    final beam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: start,
        endAngle: start + math.pi,
        colors: const [Color(0x00FF4D79), AppColors.accentRose, AppColors.primaryBerry, Color(0x00FF4D79)],
        stops: const [0.0, 0.45, 0.75, 1.0],
        transform: GradientRotation(start),
      ).createShader(Rect.fromCircle(center: centre, radius: radius));
    canvas.drawArc(Rect.fromCircle(center: centre, radius: radius), start, math.pi * 0.9, false, beam);
  }

  @override
  bool shouldRepaint(_BeamPainter old) => old.turn != turn || old.thickness != thickness;
}

/// Three orbs that swell and fade in turn: the companion is thinking.
///
/// Replaces the old progress bar, which read as "loading a file" rather than "she is writing back".
class ThinkingOrbs extends StatefulWidget {
  const ThinkingOrbs({super.key, this.animate = true});

  final bool animate;

  @override
  State<ThinkingOrbs> createState() => _ThinkingOrbsState();
}

class _ThinkingOrbsState extends State<ThinkingOrbs> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (widget.animate && companionAnimations) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(size: const Size.square(18), painter: _OrbPainter(turn: _c.value)),
          const SizedBox(width: 9),
          Text(
            'Thinking…',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              // The word breathes with the orb rather than sitting flat next to it.
              color: Color.lerp(const Color(0xFFC98BA1), AppColors.primaryBerry, math.sin(_c.value * 2 * math.pi).abs()),
            ),
          ),
        ],
      ),
    );
  }
}

/// A ball of fine stripes that turns: the companion's "thinking" mark (libraries.dev "Thinking orbs").
class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.turn});

  final double turn;
  static const _stripes = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: centre, radius: radius)));
    canvas.drawCircle(centre, radius, Paint()..color = const Color(0xFFFFF0F5));

    // Vertical stripes whose spacing follows a turning sphere, so a flat circle reads as rotating.
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.primaryBerry;
    for (var i = 0; i < _stripes; i++) {
      final angle = (i / _stripes) * 2 * math.pi + turn * 2 * math.pi;
      final x = centre.dx + math.sin(angle) * radius;
      // Stripes on the far side of the sphere are fainter, which gives the turn its depth.
      final facing = math.cos(angle);
      if (facing <= 0) continue;
      paint.color = AppColors.primaryBerry.withValues(alpha: 0.18 + facing * 0.62);
      final half = math.sqrt(math.max(0, radius * radius - (x - centre.dx) * (x - centre.dx)));
      canvas.drawLine(Offset(x, centre.dy - half), Offset(x, centre.dy + half), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.turn != turn;
}

/// Fades and lifts [child] into place once, when it first appears.
///
/// Chat bubbles use it so a new message arrives softly instead of snapping in.
class SoftArrival extends StatelessWidget {
  const SoftArrival({super.key, required this.child, this.offset = 12, this.duration = const Duration(milliseconds: 320)});

  final Widget child;
  final double offset;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * offset), child: child),
      ),
      child: child,
    );
  }
}

/// Scales [child] up and down forever, like a slow breath.
///
/// The mood circles use it so the row looks alive and invites a tap.
class Breathing extends StatefulWidget {
  const Breathing(
      {super.key,
      required this.child,
      this.amount = 0.04,
      this.period = const Duration(milliseconds: 2600),
      this.delay = Duration.zero,
      this.animate = true});

  final Widget child;
  final double amount;
  final Duration period;
  final Duration delay;
  final bool animate;

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void initState() {
    super.initState();
    if (!widget.animate || !companionAnimations) return;
    // Staggering the start stops a row of circles from pulsing in lockstep.
    Future<void>.delayed(widget.delay, () {
      if (mounted) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.scale(
        scale: 1 + Curves.easeInOut.transform(_c.value) * widget.amount,
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// The warm palette the three libraries.dev effects share. Their originals are a cold rainbow on black;
/// Femora is a light, pink app, so the same motion is drawn in berry, rose and peach instead.
const _beamColours = <Color>[
  Color(0xFFFF8FB1),
  Color(0xFFFF4D79),
  AppColors.primaryBerry,
  Color(0xFFC77DFF),
  Color(0xFFFFB38A),
  Color(0xFFFF8FB1),
];

/// A glow that rides the border of a rounded rectangle (libraries.dev "Border beam").
///
/// Wrapped around the message box, so the place she types looks alive while the companion listens or thinks.
class BorderBeam extends StatefulWidget {
  const BorderBeam({
    super.key,
    required this.child,
    required this.radius,
    this.thickness = 2.0,
    this.duration = const Duration(seconds: 5),
    this.active = true,
  });

  final Widget child;
  final double radius;
  final double thickness;
  final Duration duration;

  /// When false the border is not drawn at all, so the box is plain while nothing is happening.
  final bool active;

  @override
  State<BorderBeam> createState() => _BorderBeamState();
}

class _BorderBeamState extends State<BorderBeam> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(BorderBeam old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync() {
    if (widget.active && companionAnimations) {
      _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => CustomPaint(
        foregroundPainter: _BorderBeamPainter(t: _c.value, radius: widget.radius, thickness: widget.thickness),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _BorderBeamPainter extends CustomPainter {
  _BorderBeamPainter({required this.t, required this.radius, required this.thickness});

  final double t;
  final double radius;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(thickness / 2);
    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;
    final length = metric.length;

    // A short lit segment slides around the outline; the rest of the border stays a faint pink line.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = const Color(0x33FF8FB1),
    );

    final start = t * length;
    final segment = length * 0.28;
    final lit = Path();
    if (start + segment <= length) {
      lit.addPath(metric.extractPath(start, start + segment), Offset.zero);
    } else {
      lit.addPath(metric.extractPath(start, length), Offset.zero);
      lit.addPath(metric.extractPath(0, start + segment - length), Offset.zero);
    }

    final bounds = Offset.zero & size;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(colors: _beamColours, transform: GradientRotation(t * 2 * math.pi)).createShader(bounds)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);
    canvas.drawPath(lit, glow);
  }

  @override
  bool shouldRepaint(_BorderBeamPainter old) => old.t != t || old.radius != radius || old.thickness != thickness;
}

/// A colour glow that rises from the bottom of the message box while she speaks, then sweeps side to side
/// while the answer is being thought through (libraries.dev "Voice").
class VoiceGlow extends StatefulWidget {
  const VoiceGlow({super.key, required this.height, this.rising = false, this.sweeping = false});

  /// How tall the glow may grow, in logical pixels.
  final double height;

  /// She is speaking: the glow rises and breathes.
  final bool rising;

  /// The companion is working: the glow sweeps from side to side.
  final bool sweeping;

  @override
  State<VoiceGlow> createState() => _VoiceGlowState();
}

class _VoiceGlowState extends State<VoiceGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(VoiceGlow old) {
    super.didUpdateWidget(old);
    if (old.rising != widget.rising || old.sweeping != widget.sweeping) _sync();
  }

  void _sync() {
    if ((widget.rising || widget.sweeping) && companionAnimations) {
      _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.rising || widget.sweeping;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: on ? 1 : 0,
        duration: const Duration(milliseconds: 260),
        child: SizedBox(
          height: widget.height,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final phase = math.sin(_c.value * 2 * math.pi);
              // Speaking makes it rise and fall; thinking slides the same colours from left to right.
              final grow = widget.rising ? 0.68 + phase * 0.3 : 0.55;
              final slide = widget.sweeping ? phase * 0.7 : phase * 0.12;
              return Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: grow.clamp(0.1, 1.0),
                  widthFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.4 + slide, 0),
                        end: Alignment(1.4 + slide, 0),
                        colors: _beamColours,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
