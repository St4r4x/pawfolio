import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/screens/auth/login_screen.dart';

void main() {
  testWidgets('shows the slogan and wraps the form in a centered card', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Le carnet de santé de vos compagnons poilus.'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('toggles password visibility', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    TextField passwordField() => tester.widget<TextField>(find.byType(TextField).at(1));

    expect(passwordField().obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();

    expect(passwordField().obscureText, isFalse);
  });

  testWidgets('shows inline error and blocks submit on invalid email', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.enterText(find.byType(TextField).at(0), 'not-an-email');
    await tester.tap(find.byType(TextField).at(1));
    await tester.pump();
    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    expect(find.text('Entre une adresse email valide.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
