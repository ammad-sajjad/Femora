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
  const NearbyCareButton({super.key, required this.kind, required this.label, this.doctor});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: Key('nearby_${kind.name}'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryBerry,
            side: const BorderSide(color: AppColors.primaryBerry, width: 1.2),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => doctor == null ? NearbyCareScreen(initialKind: kind) : FindDoctorScreen(initialSpecialty: doctor!))),
          icon: Icon(doctor == null ? Icons.location_on_outlined : Icons.person_search_outlined, size: 18),
          label: Text(label, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
        ),
      );
}
