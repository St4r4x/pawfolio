import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/screens/auth/signup_screen.dart';

void main() {
  testWidgets('toggles password visibility', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    TextField passwordField() => tester.widget<TextField>(find.byType(TextField).at(1));

    expect(passwordField().obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();

    expect(passwordField().obscureText, isFalse);
  });

  testWidgets('shows inline error and blocks submit on short password', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.tap(find.byType(TextField).at(0));
    await tester.pump();
    await tester.tap(find.text("S'inscrire"));
    await tester.pump();

    expect(find.text('Le mot de passe doit contenir au moins 6 caractères.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
