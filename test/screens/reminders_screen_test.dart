import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/providers/reminders_provider.dart';
import 'package:pawfolio/reminders.dart';
import 'package:pawfolio/screens/reminders/reminders_screen.dart';

void main() {
  testWidgets('groups reminders into Aujourd\'hui / Cette semaine / Plus tard', (tester) async {
    final now = DateTime.now();
    final items = [
      DueItem(petId: 'p1', petName: 'Rex', label: 'Vaccin', dueDate: now),
      DueItem(petId: 'p2', petName: 'Mia', label: 'Poids', dueDate: now.add(const Duration(days: 3))),
      DueItem(petId: 'p1', petName: 'Rex', label: 'RDV', dueDate: now.add(const Duration(days: 30))),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [upcomingRemindersProvider.overrideWith((ref) async => items)],
        child: const MaterialApp(home: RemindersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Aujourd'hui"), findsOneWidget);
    expect(find.text('Cette semaine'), findsOneWidget);
    expect(find.text('Plus tard'), findsOneWidget);
    expect(find.text('Rex · Vaccin'), findsOneWidget);
    expect(find.text('Mia · Poids'), findsOneWidget);
    expect(find.text('Rex · RDV'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no reminders', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [upcomingRemindersProvider.overrideWith((ref) async => <DueItem>[])],
        child: const MaterialApp(home: RemindersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun rappel à venir'), findsOneWidget);
  });
}
