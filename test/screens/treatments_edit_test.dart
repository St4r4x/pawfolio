import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/treatment.dart';
import 'package:pawfolio/providers/treatments_provider.dart';
import 'package:pawfolio/repositories/treatments_repository.dart';
import 'package:pawfolio/screens/pet_detail/widgets/treatments_tab.dart';

void main() {
  testWidgets('editing a treatment pre-fills the sheet and calls update', (tester) async {
    final treatment = Treatment(
      id: 't1',
      petId: 'p1',
      type: 'dewormer',
      name: 'Milbemax',
      dateGiven: DateTime(2024, 2, 1),
    );
    Treatment? updated;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          treatmentsRepositoryProvider.overrideWithValue(
            _FakeTreatmentsRepository([treatment], onUpdate: (t) => updated = t),
          ),
        ],
        child: const MaterialApp(home: TreatmentsTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(find.text('Milbemax'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'Milbemax (rappel)');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(updated?.name, 'Milbemax (rappel)');
  });
}

class _FakeTreatmentsRepository implements TreatmentsRepository {
  _FakeTreatmentsRepository(this.treatments, {required this.onUpdate});

  final List<Treatment> treatments;
  final void Function(Treatment) onUpdate;

  @override
  Future<List<Treatment>> fetchForPet(String petId) async => treatments;

  @override
  Future<void> create(Treatment treatment) async {}

  @override
  Future<void> update(Treatment treatment) async => onUpdate(treatment);
}
