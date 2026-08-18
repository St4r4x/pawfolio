import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/widgets/empty_state.dart';

void main() {
  testWidgets('renders the illustration, title, and subtitle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EmptyState(
          illustration: Icon(Icons.pets),
          title: 'Aucun animal pour le moment',
          subtitle: 'Ajoute ton premier animal avec le bouton + ci-dessous.',
        ),
      ),
    );

    expect(find.byIcon(Icons.pets), findsOneWidget);
    expect(find.text('Aucun animal pour le moment'), findsOneWidget);
    expect(find.text('Ajoute ton premier animal avec le bouton + ci-dessous.'), findsOneWidget);
  });

  testWidgets('renders with no subtitle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EmptyState(illustration: Icon(Icons.pets), title: 'Titre seul'),
      ),
    );

    expect(find.text('Titre seul'), findsOneWidget);
  });
}
