import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/theme.dart';
import 'package:pawfolio/widgets/pet_avatar.dart';

void main() {
  testWidgets('dog gets the primary-colored disc', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PetAvatar(species: 'dog')));

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundColor, AppColors.primary);
  });

  testWidgets('cat gets the accentPositive-colored disc', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PetAvatar(species: 'cat')));

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundColor, AppColors.accentPositive);
  });

  testWidgets('any other species gets the muted-colored disc', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PetAvatar(species: 'other')));

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundColor, AppColors.muted);
  });
}
