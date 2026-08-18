import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawfolio/screens/auth/forgot_password_screen.dart';
import 'package:pawfolio/screens/auth/login_screen.dart';

void main() {
  testWidgets('shows inline error and blocks submit on invalid email', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));

    await tester.enterText(find.byType(TextField), 'not-an-email');
    await tester.tap(find.text('Envoyer le lien'));
    await tester.pump();

    expect(find.text('Entre une adresse email valide.'), findsOneWidget);
  });

  testWidgets('shows a generic error when the reset request fails', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));

    await tester.enterText(find.byType(TextField), 'test@example.com');
    await tester.tap(find.text('Envoyer le lien'));
    await tester.pump();

    expect(find.text('Impossible de contacter le serveur. Vérifie ta connexion.'), findsOneWidget);
  });

  testWidgets('"Mot de passe oublié ?" navigates from login to ForgotPasswordScreen', (tester) async {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mot de passe oublié ?'));
    await tester.pumpAndSettle();

    expect(find.text('Envoyer le lien'), findsOneWidget);
  });
}
