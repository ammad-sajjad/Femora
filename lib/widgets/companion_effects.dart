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
        children: List.generate(3, (i) {
          // Each orb runs the same curve a third of a cycle behind the one before it.
          final t = (_c.value - i * 0.18) % 1.0;
          final swell = math.sin(t * math.pi).clamp(0.0, 1.0);
          return Padding(
            padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
            child: Container(
              width: 7 + swell * 3,
              height: 7 + swell * 3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(const Color(0xFFFFC3D5), AppColors.primaryBerry, swell),
              ),
            ),
          );
        }),
      ),
    );
  }
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
