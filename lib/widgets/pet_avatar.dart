import 'package:flutter/material.dart';

import '../theme.dart';

class PetAvatar extends StatelessWidget {
  const PetAvatar({required this.species, this.radius = 20, this.photoUrl, super.key});

  final String species;
  final double radius;
  final String? photoUrl;

  static const _backgroundBySpecies = {
    'dog': AppColors.primary,
    'cat': AppColors.accentPositive,
  };

  @override
  Widget build(BuildContext context) {
    final background = _backgroundBySpecies[species] ?? AppColors.muted;
    final onBackground = background == AppColors.muted ? AppColors.background : Colors.white;
    final hasPhoto = photoUrl != null;
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      backgroundImage: hasPhoto ? ResizeImage(NetworkImage(photoUrl!), width: (radius * 2).round()) : null,
      onBackgroundImageError: hasPhoto ? (_, _) {} : null,
      child: hasPhoto ? null : Icon(Icons.pets, color: onBackground, size: radius),
    );
  }
}
