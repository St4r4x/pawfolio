import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/pet.dart';
import 'package:pawfolio/providers/pets_provider.dart';
import 'package:pawfolio/screens/home/home_screen.dart';

void main() {
  testWidgets('shows pets returned by petsProvider', (tester) async {
    final pets = [
      const Pet(id: '1', ownerId: 'u1', name: 'Rex', species: 'dog'),
      const Pet(id: '2', ownerId: 'u1', name: 'Mia', species: 'cat'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [petsProvider.overrideWith((ref) async => pets)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rex'), findsOneWidget);
    expect(find.text('Mia'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no pets', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [petsProvider.overrideWith((ref) async => <Pet>[])],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun animal pour le moment'), findsOneWidget);
  });
}
