import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GaugeMeterWidget extends StatefulWidget {
  final double percentage; // 0.0 to 1.0 (e.g. 0.62 for 62%)

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
          size: const Size(220, 115),
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
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 14;

    // Arc Background
    final arcPaint = Paint()
      ..color = AppColors.greenMint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    // 180 degree semi-circle from math.pi (left) to 0 (right)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      arcPaint,
    );

    // Calculate needle angle
    // 0.0 => math.pi (180 deg, pointing left)
    // 0.5 => math.pi * 1.5 (90 deg, pointing up)
    // 1.0 => math.pi * 2.0 (0 deg, pointing right)
    final angle = math.pi + (progress * math.pi);
    final needleLength = radius - 8;

    final needleEnd = Offset(
      center.dx + needleLength * math.cos(angle),
      center.dy + needleLength * math.sin(angle),
    );

    // Pivot Circle
    final pivotPaint = Paint()
      ..color = AppColors.primaryBerry
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 7, pivotPaint);

    // Needle Line
    final needlePaint = Paint()
      ..color = AppColors.primaryBerry
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);
  }

  @override
  bool shouldRepaint(covariant GaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
