import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/treatment.dart';
import 'package:pawfolio/providers/treatments_provider.dart';
import 'package:pawfolio/screens/pet_detail/widgets/treatments_tab.dart';
import 'package:pawfolio/widgets/empty_state.dart';

void main() {
  testWidgets('shows treatments for the given pet', (tester) async {
    final treatments = [
      Treatment(id: 't1', petId: 'p1', type: 'dewormer', name: 'Milbemax', dateGiven: DateTime(2024, 2, 1)),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [treatmentsProvider('p1').overrideWith((ref) async => treatments)],
        child: const MaterialApp(home: TreatmentsTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Milbemax'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no treatments', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [treatmentsProvider('p1').overrideWith((ref) async => <Treatment>[])],
        child: const MaterialApp(home: TreatmentsTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun traitement enregistré'), findsOneWidget);
    expect(find.byType(EmptyState), findsOneWidget);
  });
}
