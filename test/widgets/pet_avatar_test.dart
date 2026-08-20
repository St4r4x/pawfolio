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

  testWidgets('with no photoUrl, shows the species icon', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PetAvatar(species: 'dog')));

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isNull);
    expect(find.byIcon(Icons.pets), findsOneWidget);
  });

  testWidgets('with a photoUrl, shows the photo instead of the icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PetAvatar(species: 'dog', photoUrl: 'https://example.com/rex.jpg')),
    );

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    final resized = avatar.backgroundImage as ResizeImage;
    expect(resized.imageProvider, isA<NetworkImage>().having((i) => i.url, 'url', 'https://example.com/rex.jpg'));
    expect(find.byIcon(Icons.pets), findsNothing);
  });
}
