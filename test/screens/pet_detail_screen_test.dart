import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/pet.dart';
import 'package:pawfolio/providers/pets_provider.dart';
import 'package:pawfolio/providers/vaccinations_provider.dart';
import 'package:pawfolio/providers/weight_entries_provider.dart';
import 'package:pawfolio/providers/treatments_provider.dart';
import 'package:pawfolio/providers/vet_visits_provider.dart';
import 'package:pawfolio/screens/pet_detail/pet_detail_screen.dart';

void main() {
  testWidgets("shows the pet's name, species, and breed in the header", (tester) async {
    final pets = [
      const Pet(id: 'p1', ownerId: 'u1', name: 'Rex', species: 'dog', breed: 'Labrador'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petsProvider.overrideWith((ref) async => pets),
          vaccinationsProvider('p1').overrideWith((ref) async => []),
          weightEntriesProvider('p1').overrideWith((ref) async => []),
          treatmentsProvider('p1').overrideWith((ref) async => []),
          vetVisitsProvider('p1').overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: PetDetailScreen(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rex'), findsOneWidget);
    expect(find.text('Chien'), findsOneWidget);
    expect(find.text('Labrador'), findsOneWidget);
  });
}
