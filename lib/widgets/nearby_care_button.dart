import 'package:flutter/material.dart';

import '../models/doctors.dart';
import '../models/places.dart';
import '../screens/find_doctor_screen.dart';
import '../screens/nearby_care_screen.dart';
import '../theme/app_theme.dart';

/// "Find a ... near you": opens the nearby care map on the right kind of place, or, with [doctor], the doctor search.
class NearbyCareButton extends StatelessWidget {
  final CareKind kind;
  final String label;
  final DoctorSpecialty? doctor;
  final bool outline;
  const NearbyCareButton({
    super.key,
    required this.kind,
    required this.label,
    this.doctor,
    this.outline = false,
  });

  @override
  Widget build(BuildContext context) {
    final isImaging = kind == CareKind.imaging;
    final primaryColor = const Color(0xFFBE185D);

    return GestureDetector(
      key: Key('nearby_${kind.name}'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => doctor == null ? NearbyCareScreen(initialKind: kind) : FindDoctorScreen(initialSpecialty: doctor!),
        ),
      ),
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: outline
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: const Color(0xFFFDA4AF), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              )
            : BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE11D48),
                    Color(0xFFBE185D),
                    Color(0xFF9D174D),
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFBE185D).withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isImaging)
              Icon(
                Icons.location_on_outlined,
                color: outline ? primaryColor : Colors.white,
                size: 19,
              )
            else
              CustomPaint(
                size: const Size(20, 20),
                painter: _StethoscopePainter(color: outline ? primaryColor : Colors.white),
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: outline ? primaryColor : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StethoscopePainter extends CustomPainter {
  final Color color;
  const _StethoscopePainter({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Ear tubes (top U)
    final uPath = Path();
    uPath.moveTo(w * 0.28, h * 0.16);
    uPath.lineTo(w * 0.28, h * 0.36);
    uPath.quadraticBezierTo(w * 0.28, h * 0.54, w * 0.50, h * 0.54);
    uPath.quadraticBezierTo(w * 0.72, h * 0.54, w * 0.72, h * 0.36);
    uPath.lineTo(w * 0.72, h * 0.16);
    canvas.drawPath(uPath, strokePaint);

    // Eartips
    canvas.drawCircle(Offset(w * 0.28, h * 0.16), 1.6, fillPaint);
    canvas.drawCircle(Offset(w * 0.72, h * 0.16), 1.6, fillPaint);

    // Main tube from bottom of U loop down, curving to left
    final tubePath = Path();
    tubePath.moveTo(w * 0.50, h * 0.54);
    tubePath.lineTo(w * 0.50, h * 0.68);
    tubePath.quadraticBezierTo(w * 0.50, h * 0.88, w * 0.32, h * 0.88);
    tubePath.quadraticBezierTo(w * 0.12, h * 0.88, w * 0.12, h * 0.70);
    tubePath.quadraticBezierTo(w * 0.12, h * 0.56, w * 0.22, h * 0.56);
    canvas.drawPath(tubePath, strokePaint);

    // Chestpiece disc
    canvas.drawCircle(Offset(w * 0.22, h * 0.56), 2.8, strokePaint);
    canvas.drawCircle(Offset(w * 0.22, h * 0.56), 1.2, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
