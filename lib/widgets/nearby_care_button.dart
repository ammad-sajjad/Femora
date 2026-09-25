import 'package:flutter/material.dart';

import '../models/places.dart';
import '../screens/nearby_care_screen.dart';
import '../theme/app_theme.dart';

/// "Find a ... near you": opens the nearby care map on the right kind of place.
class NearbyCareButton extends StatelessWidget {
  final CareKind kind;
  final String label;
  const NearbyCareButton({super.key, required this.kind, required this.label});

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
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => NearbyCareScreen(initialKind: kind))),
          icon: const Icon(Icons.location_on_outlined, size: 18),
          label: Text(label, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
        ),
      );
}
