import 'package:flutter/material.dart';

/// Centers form content in a max-400px card with a scrollable body, so it
/// never overflows when an inline error appears under a small test/device
/// viewport. Shared by the login, signup, and forgot-password screens.
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(padding: const EdgeInsets.all(24), child: child),
          ),
        ),
      ),
    );
  }
}
