import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CircularRiskWidget extends StatelessWidget {
  final double percentage; // e.g. 0.38 for 38%
  final String riskLabel;

  const CircularRiskWidget({
    super.key,
    this.percentage = 0.38,
    this.riskLabel = 'Low Risk',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 136,
      height: 136,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(136, 136),
            painter: CircularRiskPainter(percentage: percentage),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${(percentage * 100).toInt()}%',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.greenSuccess,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                riskLabel,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CircularRiskPainter extends CustomPainter {
  final double percentage;

  CircularRiskPainter({required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Track Paint
    final trackPaint = Paint()
      ..color = const Color(0xFFE5F6EC)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc Paint
    final progressPaint = Paint()
      ..color = AppColors.greenSuccess
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw arc from top (-pi / 2)
    final sweepAngle = 2 * math.pi * percentage;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CircularRiskPainter oldDelegate) {
    return oldDelegate.percentage != percentage;
  }
}
