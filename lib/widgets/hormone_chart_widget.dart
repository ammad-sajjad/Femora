import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../models/health_store.dart';
import '../theme/app_theme.dart';

class HormoneChartWidget extends StatelessWidget {
  final bool isAssessed;
  const HormoneChartWidget({super.key, this.isAssessed = false});

  @override
  Widget build(BuildContext context) {
    final language = Provider.of<HealthStore?>(context)?.profile.language ?? 'en';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF2F8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.show_chart_rounded,
                      color: Color(0xFFBE185D),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    t(language, 'Hormonal Trends', 'ہارمونل رجحانات'),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE7F3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  t(language, '28 DAY CYCLE', '28 دن کا سائیکل'),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9D174D),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isAssessed
                ? t(language,
                    'PCOS phenotypes commonly exhibit inverted LH-to-FSH ratios with a flattened follicular surge.',
                    'PCOS کے نمونے عام طور پر الٹ LH-to-FSH تناسب اور دبی ہوئی لہر ظاہر کرتے ہیں۔')
                : t(language,
                    'How these hormones typically rise and fall in a cycle (textbook shapes, not your measured levels). In PCOS, LH is often high relative to FSH.',
                    'ایک سائیکل میں یہ ہارمون عموماً کیسے بڑھتے اور گھٹتے ہیں (نصابی شکلیں، آپ کی ناپی ہوئی سطحیں نہیں)۔ PCOS میں LH اکثر FSH کے مقابلے میں زیادہ ہوتا ہے۔'),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.42,
            ),
          ),
          const SizedBox(height: 16),

          // Chart Display Area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFCF9FA),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF3E8EE), width: 1),
            ),
            child: Column(
              children: [
                // Top Day 14 Surge Pill (unassessed view)
                if (!isAssessed) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFBE185D).withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFBE185D),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              t(language, 'Day 14 Surge', '14ویں دن لہر'),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9D174D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],

                // Curves Canvas
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: HormoneSplinePainter(isAssessed: isAssessed),
                  ),
                ),
                const SizedBox(height: 10),

                // X-Axis Day Numbers
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _axisLabel('Day 1'),
                      _axisLabel('5'),
                      _axisLabel('9'),
                      _axisLabel('13', isHighlight: !isAssessed),
                      _axisLabel('17'),
                      _axisLabel('21'),
                      _axisLabel('Day 25'),
                    ],
                  ),
                ),

                // Sub-labels when assessed: Day 1 (Follicular), Day 14 (Mid-Cycle), Day 28 (Luteal)
                if (isAssessed) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Expanded(
                          child: Text(
                            'Day 1 (Follicular)',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Day 14 (Mid-Cycle)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Day 28 (Luteal)',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Legend Capsule
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF5F8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(const Color(0xFFBE185D), 'LH'),
                const SizedBox(width: 22),
                _buildLegendItem(const Color(0xFF8B5CF6), 'FSH'),
                const SizedBox(width: 22),
                _buildLegendItem(const Color(0xFF0D9488), t(language, 'Estrogen', 'ایسٹروجن')),
              ],
            ),
          ),

          // Bottom CTA Banner inside card (unassessed view)
          if (!isAssessed) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF2F8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFCE7F3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.analytics_outlined, color: Color(0xFFBE185D), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t(language, 'Take assessment to compare your personal...', 'اپنے ذاتی رجحان کے موازنے کیلئے جائزہ لیں...'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9D174D),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFFBE185D), size: 18),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _axisLabel(String text, {bool isHighlight = false}) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Inter',
        color: isHighlight ? const Color(0xFFBE185D) : const Color(0xFF94A3B8),
        fontSize: 11,
        fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
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
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

class HormoneSplinePainter extends CustomPainter {
  final bool isAssessed;
  HormoneSplinePainter({this.isAssessed = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Horizontal dashed grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFF1E4EC)
      ..strokeWidth = 1.0;
    for (var f in [0.25, 0.50, 0.75]) {
      _drawDashedHorizontal(canvas, Offset(0, h * f), w, gridPaint, dash: 4, gap: 4);
    }

    if (!isAssessed) {
      // UNASSESSED TEXTBOOK CYCLIC SHAPES

      // A. Estrogen (Dashed teal with early peak around day 12 and luteal swell)
      final estPath = Path();
      estPath.moveTo(0, h * 0.82);
      estPath.cubicTo(w * 0.15, h * 0.80, w * 0.25, h * 0.65, w * 0.35, h * 0.28);
      estPath.cubicTo(w * 0.38, h * 0.16, w * 0.42, h * 0.22, w * 0.45, h * 0.45);
      estPath.cubicTo(w * 0.50, h * 0.75, w * 0.60, h * 0.65, w * 0.72, h * 0.58);
      estPath.cubicTo(w * 0.82, h * 0.52, w * 0.90, h * 0.75, w, h * 0.84);

      // Soft teal fill under estrogen peak
      final estFill = Path.from(estPath)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      final estFillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0D9488).withOpacity(0.12),
            const Color(0xFF0D9488).withOpacity(0.01),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(estFill, estFillPaint);

      _drawDashedPath(
        canvas,
        estPath,
        Paint()
          ..color = const Color(0xFF0D9488)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
        dashLength: 4.5,
        gapLength: 3.5,
      );

      // Peak circle on Estrogen
      canvas.drawCircle(Offset(w * 0.38, h * 0.16), 3.5, Paint()..color = const Color(0xFF0D9488));
      canvas.drawCircle(Offset(w * 0.38, h * 0.16), 1.8, Paint()..color = Colors.white);

      // B. FSH Curve (Smooth Violet)
      final fshPath = Path();
      fshPath.moveTo(0, h * 0.74);
      fshPath.cubicTo(w * 0.20, h * 0.68, w * 0.35, h * 0.60, w * 0.46, h * 0.42);
      fshPath.cubicTo(w * 0.52, h * 0.50, w * 0.65, h * 0.72, w * 0.80, h * 0.76);
      fshPath.cubicTo(w * 0.90, h * 0.78, w * 0.96, h * 0.80, w, h * 0.82);

      final fshPaint = Paint()
        ..color = const Color(0xFF8B5CF6)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(fshPath, fshPaint);

      // C. LH Curve (Deep Magenta surge at Day 14)
      final lhPath = Path();
      lhPath.moveTo(0, h * 0.88);
      lhPath.cubicTo(w * 0.25, h * 0.87, w * 0.38, h * 0.82, w * 0.44, h * 0.50);
      lhPath.cubicTo(w * 0.47, h * 0.15, w * 0.50, h * 0.12, w * 0.52, h * 0.45);
      lhPath.cubicTo(w * 0.56, h * 0.85, w * 0.75, h * 0.87, w, h * 0.88);

      // Gradient fill under LH surge
      final lhFill = Path.from(lhPath)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      final lhFillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFBE185D).withOpacity(0.30),
            const Color(0xFFBE185D).withOpacity(0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(lhFill, lhFillPaint);

      final lhPaint = Paint()
        ..color = const Color(0xFFBE185D)
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(lhPath, lhPaint);
    } else {
      // ASSESSED PCOS PHENOTYPE: FLATTENED SURGE & ELEVATED BASELINE

      // A. Estrogen (Dashed teal)
      final estPath = Path();
      estPath.moveTo(0, h * 0.85);
      estPath.cubicTo(w * 0.20, h * 0.80, w * 0.35, h * 0.60, w * 0.44, h * 0.38);
      estPath.cubicTo(w * 0.48, h * 0.45, w * 0.55, h * 0.70, w * 0.65, h * 0.60);
      estPath.cubicTo(w * 0.75, h * 0.52, w * 0.88, h * 0.78, w, h * 0.85);

      _drawDashedPath(
        canvas,
        estPath,
        Paint()
          ..color = const Color(0xFF0D9488)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
        dashLength: 4.5,
        gapLength: 3.5,
      );

      // B. FSH Curve (Purple lower swell)
      final fshPath = Path();
      fshPath.moveTo(0, h * 0.82);
      fshPath.cubicTo(w * 0.25, h * 0.80, w * 0.40, h * 0.74, w * 0.50, h * 0.62);
      fshPath.cubicTo(w * 0.60, h * 0.72, w * 0.80, h * 0.82, w, h * 0.84);

      final fshPaint = Paint()
        ..color = const Color(0xFF8B5CF6)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(fshPath, fshPaint);

      // C. LH Curve (PCOS phenotype: higher baseline, blunted surge)
      final lhPath = Path();
      lhPath.moveTo(0, h * 0.80);
      lhPath.cubicTo(w * 0.22, h * 0.78, w * 0.38, h * 0.65, w * 0.48, h * 0.48);
      lhPath.cubicTo(w * 0.52, h * 0.52, w * 0.68, h * 0.76, w, h * 0.82);

      final lhFill = Path.from(lhPath)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      final lhFillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFBE185D).withOpacity(0.22),
            const Color(0xFFBE185D).withOpacity(0.01),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(lhFill, lhFillPaint);

      final lhPaint = Paint()
        ..color = const Color(0xFFBE185D)
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(lhPath, lhPaint);
    }
  }

  void _drawDashedHorizontal(Canvas canvas, Offset p1, double width, Paint paint, {required double dash, required double gap}) {
    double x = p1.dx;
    while (x < p1.dx + width) {
      final len = (x + dash <= p1.dx + width) ? dash : (p1.dx + width - x);
      canvas.drawLine(Offset(x, p1.dy), Offset(x + len, p1.dy), paint);
      x += dash + gap;
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, {required double dashLength, required double gapLength}) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final len = (distance + dashLength < metric.length) ? dashLength : metric.length - distance;
        final extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant HormoneSplinePainter oldDelegate) => oldDelegate.isAssessed != isAssessed;
}
