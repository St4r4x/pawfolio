import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/weight_entry.dart';
import 'package:pawfolio/providers/weight_entries_provider.dart';
import 'package:pawfolio/repositories/weight_entries_repository.dart';
import 'package:pawfolio/screens/pet_detail/widgets/weight_tab.dart';

void main() {
  testWidgets('editing a weight entry pre-fills the sheet and calls update', (tester) async {
    final entry = WeightEntry(id: 'w1', petId: 'p1', weightKg: 12.5, recordedAt: DateTime(2024, 3, 1));
    WeightEntry? updated;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weightEntriesRepositoryProvider.overrideWithValue(_FakeWeightEntriesRepository(
            [entry],
            onUpdate: (e) => updated = e,
          )),
        ],
        child: const MaterialApp(home: WeightTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(find.textContaining('12.5'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, '13.0');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(updated?.weightKg, 13.0);
  });
}

class _FakeWeightEntriesRepository implements WeightEntriesRepository {
  _FakeWeightEntriesRepository(this.entries, {required this.onUpdate});

  final List<WeightEntry> entries;
  final void Function(WeightEntry) onUpdate;

  @override
  Future<List<WeightEntry>> fetchForPet(String petId) async => entries;

  @override
  Future<void> create(WeightEntry entry) async {}

  @override
  Future<void> update(WeightEntry entry) async => onUpdate(entry);
}
