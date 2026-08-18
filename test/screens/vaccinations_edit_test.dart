import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/vaccination.dart';
import 'package:pawfolio/providers/vaccinations_provider.dart';
import 'package:pawfolio/repositories/vaccinations_repository.dart';
import 'package:pawfolio/screens/pet_detail/widgets/vaccinations_tab.dart';

class _FakeVaccinationsRepository implements VaccinationsRepository {
  _FakeVaccinationsRepository(this.vaccinations);

  final List<Vaccination> vaccinations;
  Vaccination? updated;

  @override
  Future<List<Vaccination>> fetchForPet(String petId) async => vaccinations;

  @override
  Future<void> create(Vaccination vaccination) async {}

  @override
  Future<void> update(Vaccination vaccination) async => updated = vaccination;
}

void main() {
  testWidgets('editing a vaccination pre-fills the sheet and calls update', (tester) async {
    final vaccination = Vaccination(
      id: 'v1',
      petId: 'p1',
      name: 'Rage',
      dateAdministered: DateTime(2024, 1, 1),
    );
    final repo = _FakeVaccinationsRepository([vaccination]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [vaccinationsRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: VaccinationsTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(find.text('Rage'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'Rage (rappel)');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(repo.updated?.name, 'Rage (rappel)');
  });
}
