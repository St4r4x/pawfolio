import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/screens/auth/login_screen.dart';
import 'package:pawfolio/screens/auth/signup_screen.dart';

void main() {
  testWidgets('login shows a generic error for non-auth exceptions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    expect(find.text('Impossible de contacter le serveur. Vérifie ta connexion.'), findsOneWidget);
  });

  testWidgets('signup shows a generic error for non-auth exceptions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text("S'inscrire"));
    await tester.pump();

    expect(find.text('Impossible de contacter le serveur. Vérifie ta connexion.'), findsOneWidget);
  });
}
