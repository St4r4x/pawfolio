import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/vet_visit.dart';
import 'package:pawfolio/providers/vet_visits_provider.dart';
import 'package:pawfolio/screens/pet_detail/widgets/vet_visits_tab.dart';
import 'package:pawfolio/widgets/empty_state.dart';

void main() {
  testWidgets('shows vet visits for the given pet', (tester) async {
    final visits = [
      VetVisit(id: 'vv1', petId: 'p1', visitDate: DateTime(2024, 4, 10), reason: 'Contrôle annuel'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [vetVisitsProvider('p1').overrideWith((ref) async => visits)],
        child: const MaterialApp(home: VetVisitsTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Contrôle annuel'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no visits', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [vetVisitsProvider('p1').overrideWith((ref) async => <VetVisit>[])],
        child: const MaterialApp(home: VetVisitsTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun rendez-vous enregistré'), findsOneWidget);
    expect(find.byType(EmptyState), findsOneWidget);
  });
}
