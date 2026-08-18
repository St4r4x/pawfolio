import 'package:flutter/material.dart';

import '../theme.dart';

/// Paw icon, wordmark, and slogan shown above the login and signup forms.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.pets, size: 48, color: AppColors.primary),
        const SizedBox(height: 8),
        Text('Pawfolio', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Le carnet de santé de vos compagnons poilus.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
