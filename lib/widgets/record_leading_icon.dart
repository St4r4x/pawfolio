import 'package:flutter/material.dart';

/// Colored leading icon used on record list tiles (vaccinations, treatments,
/// vet visits, weight entries).
class RecordLeadingIcon extends StatelessWidget {
  const RecordLeadingIcon({required this.icon, required this.color, super.key});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: color,
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}
