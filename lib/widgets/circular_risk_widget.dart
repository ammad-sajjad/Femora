import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CircularRiskWidget extends StatelessWidget {
  final double percentage; // ring fill, e.g. 0.38 for 38%
  final String riskLabel;
  final String? centerText; // defaults to the fill as a percentage
  final Color color;
  final Color trackColor;
  final Color? textColor;

  const CircularRiskWidget({
    super.key,
    this.percentage = 0.38,
    this.riskLabel = 'Low Risk',
    this.centerText,
    this.color = AppColors.greenSuccess,
    this.trackColor = const Color(0xFFE5F6EC),
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 146,
      height: 146,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(146, 146),
            painter: CircularRiskPainter(percentage: percentage, color: color, trackColor: trackColor),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                centerText ?? '${(percentage * 100).toInt()}%',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: textColor ?? AppColors.textDark,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                riskLabel,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
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
  final Color color;
  final Color trackColor;

  CircularRiskPainter({required this.percentage, required this.color, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Track Paint
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc Paint
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw arc from top (-pi / 2)
    final sweepAngle = 2 * math.pi * percentage.clamp(0.0, 1.0);
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
    return oldDelegate.percentage != percentage || oldDelegate.color != color || oldDelegate.trackColor != trackColor;
  }
}
