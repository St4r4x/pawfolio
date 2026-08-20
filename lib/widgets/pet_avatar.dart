import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

class PetAvatar extends StatelessWidget {
  const PetAvatar({
    required this.species,
    this.radius = 20,
    this.photoUrl,
    super.key,
  });

  final String species;
  final double radius;
  final String? photoUrl;

  static const _faceAssetBySpecies = {
    'dog': 'assets/icons/dog_face.svg',
    'cat': 'assets/icons/cat_face.svg',
  };

  @override
  Widget build(BuildContext context) {
    final background = speciesAccentColor(species);
    final onBackground = background == AppColors.muted
        ? AppColors.background
        : Colors.white;
    final hasPhoto = photoUrl != null;
    final faceAsset = _faceAssetBySpecies[species];
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      backgroundImage: hasPhoto
          ? ResizeImage(NetworkImage(photoUrl!), width: (radius * 2).round())
          : null,
      onBackgroundImageError: hasPhoto ? (_, _) {} : null,
      child: hasPhoto
          ? null
          : faceAsset != null
          ? SvgPicture.asset(
              faceAsset,
              width: radius * 1.3,
              height: radius * 1.3,
            )
          : Icon(Icons.pets, color: onBackground, size: radius),
    );
  }
}
