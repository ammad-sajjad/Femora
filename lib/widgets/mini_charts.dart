import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _axis = Color(0xFF8A8497);
const _grid = Color(0xFFEDE8F1);

/// A label at a position along the horizontal axis.
typedef AxisLabel = (int index, String text);

TextPainter _text(String s, {double size = 9, Color color = _axis, FontWeight w = FontWeight.w500}) =>
    TextPainter(text: TextSpan(text: s, style: TextStyle(fontFamily: 'Inter', fontSize: size, color: color, fontWeight: w)), textDirection: TextDirection.ltr)..layout();

/// One or more lines over the same days; gaps where a value is missing. Values run from [minY] to [maxY].
class LineChart extends StatelessWidget {
  final List<List<double?>> series;
  final List<Color> colors;
  final double minY;
  final double maxY;
  final List<(double value, String label)> yTicks;
  final List<AxisLabel> xLabels;
  final double height;
  final String semantics;

  const LineChart({
    super.key,
    required this.series,
    required this.colors,
    required this.minY,
    required this.maxY,
    required this.yTicks,
    this.xLabels = const [],
    this.height = 130,
    this.semantics = 'Line chart',
  });

  @override
  Widget build(BuildContext context) => Semantics(
        label: semantics,
        child: SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _LinePainter(this))),
      );
}

class _LinePainter extends CustomPainter {
  final LineChart c;
  _LinePainter(this.c);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 46.0, right = 6.0, top = 6.0, bottom = 18.0;
    final plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final n = c.series.isEmpty ? 0 : c.series.first.length;
    double x(int i) => n <= 1 ? plot.center.dx : plot.left + plot.width * i / (n - 1);
    double y(double v) => plot.bottom - (v - c.minY) / (c.maxY - c.minY) * plot.height;

    final grid = Paint()..color = _grid..strokeWidth = 1;
    for (final (v, label) in c.yTicks) {
      canvas.drawLine(Offset(plot.left, y(v)), Offset(plot.right, y(v)), grid);
      final tp = _text(label);
      tp.paint(canvas, Offset(plot.left - 6 - tp.width, y(v) - tp.height / 2));
    }
    for (final (i, label) in c.xLabels) {
      final tp = _text(label);
      final dx = (x(i) - tp.width / 2).clamp(plot.left - 4, size.width - tp.width);
      tp.paint(canvas, Offset(dx, plot.bottom + 4));
    }
    for (var s = 0; s < c.series.length; s++) {
      final color = c.colors[s % c.colors.length];
      final line = Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      final dot = Paint()..color = color;
      final path = Path();
      var open = false;
      for (var i = 0; i < c.series[s].length; i++) {
        final v = c.series[s][i];
        if (v == null) {
          open = false;
          continue;
        }
        final p = Offset(x(i), y(v.clamp(c.minY, c.maxY)));
        if (open) {
          path.lineTo(p.dx, p.dy);
        } else {
          path.moveTo(p.dx, p.dy);
          open = true;
        }
      }
      canvas.drawPath(path, line);
      for (var i = 0; i < c.series[s].length; i++) {
        final v = c.series[s][i];
        if (v != null) canvas.drawCircle(Offset(x(i), y(v.clamp(c.minY, c.maxY))), n > 40 ? 1.8 : 3, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => true;
}

/// Bars per day; an optional shaded healthy band.
class BarChart extends StatelessWidget {
  final List<double?> values;
  final double maxY;
  final List<(double value, String label)> yTicks;
  final List<AxisLabel> xLabels;
  final (double low, double high)? band;
  final Color barColor;
  final Color outsideBandColor;
  final double height;
  final String semantics;

  const BarChart({
    super.key,
    required this.values,
    required this.maxY,
    required this.yTicks,
    this.xLabels = const [],
    this.band,
    this.barColor = AppColors.primaryBerry,
    this.outsideBandColor = const Color(0xFFE0A03A),
    this.height = 130,
    this.semantics = 'Bar chart',
  });

  @override
  Widget build(BuildContext context) => Semantics(label: semantics, child: SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _BarPainter(this))));
}

class _BarPainter extends CustomPainter {
  final BarChart c;
  _BarPainter(this.c);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 46.0, right = 6.0, top = 6.0, bottom = 18.0;
    final plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final n = c.values.length;
    double y(double v) => plot.bottom - (v / c.maxY).clamp(0, 1) * plot.height;
    if (c.band != null) {
      canvas.drawRect(Rect.fromLTRB(plot.left, y(c.band!.$2), plot.right, y(c.band!.$1)), Paint()..color = const Color(0xFF2E9E68).withValues(alpha: 0.10));
    }
    final grid = Paint()..color = _grid..strokeWidth = 1;
    for (final (v, label) in c.yTicks) {
      canvas.drawLine(Offset(plot.left, y(v)), Offset(plot.right, y(v)), grid);
      final tp = _text(label);
      tp.paint(canvas, Offset(plot.left - 6 - tp.width, y(v) - tp.height / 2));
    }
    final slot = n == 0 ? 0.0 : plot.width / n;
    final barW = (slot * 0.68).clamp(1.5, 18.0);
    for (var i = 0; i < n; i++) {
      final v = c.values[i];
      if (v == null || v <= 0) continue;
      final inBand = c.band == null || (v >= c.band!.$1 && v <= c.band!.$2);
      final r = RRect.fromRectAndRadius(Rect.fromLTRB(plot.left + slot * i + (slot - barW) / 2, y(v), plot.left + slot * i + (slot + barW) / 2, plot.bottom), const Radius.circular(2));
      canvas.drawRRect(r, Paint()..color = inBand ? c.barColor : c.outsideBandColor);
    }
    for (final (i, label) in c.xLabels) {
      final tp = _text(label);
      final cx = plot.left + slot * (i + 0.5);
      tp.paint(canvas, Offset((cx - tp.width / 2).clamp(plot.left - 4, size.width - tp.width), plot.bottom + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => true;
}

/// A small legend row: coloured dot and text.
class ChartLegend extends StatelessWidget {
  final List<(Color, String)> items;
  const ChartLegend({super.key, required this.items});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          for (final (c, t) in items)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(t, style: const TextStyle(fontFamily: 'Inter', fontSize: 10.5, color: AppColors.textMuted)),
            ]),
        ],
      );
}

/// Horizontal bars with a label and a count, for things like the most frequent symptoms.
class HBarList extends StatelessWidget {
  final List<(String label, int count)> items;
  final int total; // what a full bar stands for
  final Color color;
  const HBarList({super.key, required this.items, required this.total, this.color = AppColors.primaryBerry});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final (label, count) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 78, child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textDark))),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => Stack(children: [
                        Container(height: 10, decoration: BoxDecoration(color: _grid, borderRadius: BorderRadius.circular(5))),
                        Container(height: 10, width: box.maxWidth * (count / (total <= 0 ? 1 : total)).clamp(0.04, 1.0), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5))),
                      ]),
                    ),
                  ),
                  SizedBox(width: 34, child: Text('$count', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark))),
                ],
              ),
            ),
        ],
      );
}
