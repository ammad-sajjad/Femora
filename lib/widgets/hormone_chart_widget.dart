import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HormoneChartWidget extends StatelessWidget {
  const HormoneChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Hormonal Trends',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '28 DAY CYCLE',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5E546B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            width: double.infinity,
            child: CustomPaint(
              painter: HormoneSplinePainter(),
            ),
          ),
          const SizedBox(height: 12),
          // X-Axis Labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('1', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                Text('5', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                Text('9', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                Text('13', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                Text('17', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                Text('21', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                Text('25', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(AppColors.chartLH, 'LH'),
              const SizedBox(width: 18),
              _buildLegendItem(AppColors.chartFSH, 'FSH'),
              const SizedBox(width: 18),
              _buildLegendItem(AppColors.chartEstrogen, 'Estrogen'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class HormoneSplinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Base axis line
    final axisPaint = Paint()
      ..color = const Color(0xFFE5E2EC)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, h), Offset(w, h), axisPaint);

    // 1. LH Curve (Berry with peak around day 12 and shaded area)
    final lhPath = Path();
    lhPath.moveTo(0, h * 0.85);
    lhPath.cubicTo(w * 0.20, h * 0.82, w * 0.32, h * 0.75, w * 0.38, h * 0.58);
    lhPath.cubicTo(w * 0.42, h * 0.42, w * 0.46, h * 0.44, w * 0.52, h * 0.65);
    lhPath.cubicTo(w * 0.62, h * 0.82, w * 0.78, h * 0.85, w, h * 0.86);

    // Shaded fill for LH
    final lhFill = Path.from(lhPath);
    lhFill.lineTo(w, h);
    lhFill.lineTo(0, h);
    lhFill.close();

    final lhFillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.chartLH.withOpacity(0.25),
          AppColors.chartLH.withOpacity(0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(lhFill, lhFillPaint);

    final lhPaint = Paint()
      ..color = AppColors.chartLH
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(lhPath, lhPaint);

    // 2. FSH Curve (Purple lower swell)
    final fshPath = Path();
    fshPath.moveTo(0, h * 0.88);
    fshPath.cubicTo(w * 0.22, h * 0.85, w * 0.32, h * 0.80, w * 0.40, h * 0.70);
    fshPath.cubicTo(w * 0.45, h * 0.68, w * 0.52, h * 0.76, w * 0.60, h * 0.80);
    fshPath.cubicTo(w * 0.75, h * 0.84, w * 0.88, h * 0.86, w, h * 0.85);

    final fshPaint = Paint()
      ..color = AppColors.chartFSH
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(fshPath, fshPaint);

    // 3. Estrogen Curve (Green Dotted with highest peak at Day 10-11 and secondary rise at Day 18)
    final estPath = Path();
    estPath.moveTo(0, h * 0.89);
    estPath.cubicTo(w * 0.18, h * 0.80, w * 0.28, h * 0.55, w * 0.37, h * 0.15);
    estPath.cubicTo(w * 0.42, h * 0.22, w * 0.48, h * 0.68, w * 0.56, h * 0.75);
    estPath.cubicTo(w * 0.64, h * 0.55, w * 0.70, h * 0.62, w * 0.82, h * 0.78);
    estPath.cubicTo(w * 0.88, h * 0.82, w * 0.94, h * 0.86, w, h * 0.88);

    _drawDashedPath(
      canvas,
      estPath,
      Paint()
        ..color = AppColors.chartEstrogen
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
      dashLength: 4.0,
      gapLength: 3.5,
    );
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint,
      {required double dashLength, required double gapLength}) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final len = (distance + dashLength < metric.length)
            ? dashLength
            : metric.length - distance;
        final extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
