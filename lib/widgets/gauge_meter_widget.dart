import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GaugeMeterWidget extends StatefulWidget {
  final double percentage; // 0.0 to 1.0 (e.g. 0.79 for 79%)

  const GaugeMeterWidget({
    super.key,
    this.percentage = 0.62,
  });

  @override
  State<GaugeMeterWidget> createState() => _GaugeMeterWidgetState();
}

class _GaugeMeterWidgetState extends State<GaugeMeterWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0.0, end: widget.percentage).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant GaugeMeterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percentage != widget.percentage) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.percentage,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(250, 130),
          painter: GaugePainter(progress: _animation.value),
        );
      },
    );
  }
}

class GaugePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0

  GaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 4);
    final radius = size.width / 2 - 16;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // 1. Background Track (soft pastel blush track with round caps)
    final bgPaint = Paint()
      ..color = const Color(0xFFF7E6EC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      arcRect,
      math.pi,
      math.pi,
      false,
      bgPaint,
    );

    // 2. Active Gradient Arc (Emerald Green -> Amber -> Berry Magenta)
    final clampedProgress = progress.clamp(0.01, 1.0);
    final activePaint = Paint()
      ..shader = const SweepGradient(
        startAngle: math.pi,
        endAngle: 2 * math.pi,
        colors: [
          Color(0xFF10B981), // Emerald green (Low)
          Color(0xFF84CC16), // Lime green
          Color(0xFFF59E0B), // Warm amber (Medium)
          Color(0xFFF97316), // Orange
          Color(0xFFBE185D), // Deep berry magenta (High)
        ],
        stops: [0.0, 0.25, 0.50, 0.75, 1.0],
      ).createShader(arcRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      arcRect,
      math.pi,
      math.pi * clampedProgress,
      false,
      activePaint,
    );

    // 3. Dot Markers along the gauge (0%, 50%, 100%)
    final dotPaint = Paint()..style = PaintingStyle.fill;

    // 0% marker dot (teal/green)
    dotPaint.color = const Color(0xFF059669);
    canvas.drawCircle(Offset(center.dx - radius, center.dy), 2.8, dotPaint);

    // 50% marker dot (amber)
    dotPaint.color = const Color(0xFFD97706);
    canvas.drawCircle(Offset(center.dx, center.dy - radius), 2.8, dotPaint);

    // 100% marker dot (pink/berry)
    dotPaint.color = const Color(0xFFFDA4AF);
    canvas.drawCircle(Offset(center.dx + radius, center.dy), 2.8, dotPaint);

    // 4. Indicator Needle
    final angle = math.pi + (clampedProgress * math.pi);
    final needleLength = radius - 8;
    final needleEnd = Offset(
      center.dx + needleLength * math.cos(angle),
      center.dy + needleLength * math.sin(angle),
    );

    // Gradient Needle Stroke (Amber at root to Berry at tip)
    final needlePaint = Paint()
      ..shader = LinearGradient(
        colors: const [
          Color(0xFFF59E0B),
          Color(0xFFBE185D),
        ],
        begin: Alignment(-math.cos(angle), -math.sin(angle)),
        end: Alignment(math.cos(angle), math.sin(angle)),
      ).createShader(Rect.fromPoints(center, needleEnd))
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, needleEnd, needlePaint);

    // 5. Dual-Ring Pivot at Center
    // Outer berry circle
    final pivotOuter = Paint()
      ..color = const Color(0xFF9D174D)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 12, pivotOuter);

    // Inner white ring
    final pivotWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 7.5, pivotWhite);

    // Center core dot
    final pivotCore = Paint()
      ..color = const Color(0xFF9D174D)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4.2, pivotCore);
  }

  @override
  bool shouldRepaint(covariant GaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
