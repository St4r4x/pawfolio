import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/vet_visit.dart';
import 'package:pawfolio/providers/vet_visits_provider.dart';
import 'package:pawfolio/repositories/vet_visits_repository.dart';
import 'package:pawfolio/screens/pet_detail/widgets/vet_visits_tab.dart';

void main() {
  testWidgets('editing a vet visit pre-fills the sheet and calls update', (tester) async {
    final visit = VetVisit(
      id: 'vv1',
      petId: 'p1',
      visitDate: DateTime(2024, 4, 10),
      reason: 'Contrôle annuel',
    );
    VetVisit? updated;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vetVisitsRepositoryProvider.overrideWithValue(
            _FakeVetVisitsRepository([visit], onUpdate: (v) => updated = v),
          ),
        ],
        child: const MaterialApp(home: VetVisitsTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(find.text('Contrôle annuel'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'Contrôle annuel + vaccin');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(updated?.reason, 'Contrôle annuel + vaccin');
  });
}

class _FakeVetVisitsRepository implements VetVisitsRepository {
  _FakeVetVisitsRepository(this.visits, {required this.onUpdate});

  final List<VetVisit> visits;
  final void Function(VetVisit) onUpdate;

  @override
  Future<List<VetVisit>> fetchForPet(String petId) async => visits;

  @override
  Future<void> create(VetVisit visit) async {}

  @override
  Future<void> update(VetVisit visit) async => onUpdate(visit);
}
