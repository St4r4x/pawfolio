import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/vaccination.dart';
import 'package:pawfolio/providers/vaccinations_provider.dart';
import 'package:pawfolio/screens/pet_detail/widgets/vaccinations_tab.dart';

void main() {
  testWidgets('shows vaccinations for the given pet', (tester) async {
    final vaccinations = [
      Vaccination(id: 'v1', petId: 'p1', name: 'Rage', dateAdministered: DateTime(2024, 1, 1)),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [vaccinationsProvider('p1').overrideWith((ref) async => vaccinations)],
        child: const MaterialApp(home: VaccinationsTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rage'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no vaccinations', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [vaccinationsProvider('p1').overrideWith((ref) async => <Vaccination>[])],
        child: const MaterialApp(home: VaccinationsTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun vaccin enregistré'), findsOneWidget);
  });
}
