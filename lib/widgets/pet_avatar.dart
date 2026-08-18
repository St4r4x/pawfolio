import 'package:flutter/material.dart';

import '../theme.dart';

class PetAvatar extends StatelessWidget {
  const PetAvatar({required this.species, this.radius = 20, super.key});

  final String species;
  final double radius;

  static const _backgroundBySpecies = {
    'dog': AppColors.primary,
    'cat': AppColors.accentPositive,
  };

  @override
  Widget build(BuildContext context) {
    final background = _backgroundBySpecies[species] ?? AppColors.muted;
    final onBackground = background == AppColors.muted ? AppColors.background : Colors.white;
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: Icon(Icons.pets, color: onBackground, size: radius),
    );
  }
}
