import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/screens/auth/reset_password_screen.dart';

void main() {
  testWidgets('shows inline error and blocks submit on a short password', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ResetPasswordScreen())),
    );

    await tester.enterText(find.byType(TextField).at(0), '123');
    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.tap(find.text('Changer le mot de passe'));
    await tester.pump();

    expect(
      find.text('Le mot de passe doit contenir au moins 6 caractères.'),
      findsOneWidget,
    );
  });

  testWidgets('shows an error when the passwords do not match', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ResetPasswordScreen())),
    );

    await tester.enterText(find.byType(TextField).at(0), 'abcdef');
    await tester.enterText(find.byType(TextField).at(1), 'ghijkl');
    await tester.tap(find.text('Changer le mot de passe'));
    await tester.pump();

    expect(
      find.text('Les mots de passe ne correspondent pas.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a generic error when the update fails', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ResetPasswordScreen())),
    );

    await tester.enterText(find.byType(TextField).at(0), 'abcdef');
    await tester.enterText(find.byType(TextField).at(1), 'abcdef');
    await tester.tap(find.text('Changer le mot de passe'));
    await tester.pump();

    expect(
      find.text('Impossible de contacter le serveur. Vérifie ta connexion.'),
      findsOneWidget,
    );
  });
}
