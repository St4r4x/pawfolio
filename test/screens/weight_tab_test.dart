import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/weight_entry.dart';
import 'package:pawfolio/providers/weight_entries_provider.dart';
import 'package:pawfolio/screens/pet_detail/widgets/weight_tab.dart';

void main() {
  testWidgets('shows weight entries for the given pet', (tester) async {
    final entries = [
      WeightEntry(id: 'w1', petId: 'p1', weightKg: 12.5, recordedAt: DateTime(2024, 3, 1)),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [weightEntriesProvider('p1').overrideWith((ref) async => entries)],
        child: const MaterialApp(home: WeightTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('12.5'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no entries', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [weightEntriesProvider('p1').overrideWith((ref) async => <WeightEntry>[])],
        child: const MaterialApp(home: WeightTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucune pesée enregistrée'), findsOneWidget);
  });
}
