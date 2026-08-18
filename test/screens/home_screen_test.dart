import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/pet.dart';
import 'package:pawfolio/providers/pets_provider.dart';
import 'package:pawfolio/providers/reminders_provider.dart';
import 'package:pawfolio/reminders.dart';
import 'package:pawfolio/screens/home/home_screen.dart';
import 'package:pawfolio/widgets/empty_state.dart';
import 'package:pawfolio/widgets/pet_avatar.dart';

const _localNotificationsChannel = MethodChannel('dexterous.com/flutter/local_notifications');

void main() {
  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_localNotificationsChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_localNotificationsChannel, null);
  });

  testWidgets('shows pets returned by petsProvider with an avatar each', (tester) async {
    final pets = [
      const Pet(id: '1', ownerId: 'u1', name: 'Rex', species: 'dog'),
      const Pet(id: '2', ownerId: 'u1', name: 'Mia', species: 'cat'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [petsProvider.overrideWith((ref) async => pets)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rex'), findsOneWidget);
    expect(find.text('Mia'), findsOneWidget);
    expect(find.byType(PetAvatar), findsNWidgets(2));
  });

  testWidgets('shows an illustrated empty state when there are no pets', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [petsProvider.overrideWith((ref) async => <Pet>[])],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun animal pour le moment'), findsOneWidget);
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('shows the soonest reminder as a badge on the matching pet card', (tester) async {
    final pets = [const Pet(id: '1', ownerId: 'u1', name: 'Rex', species: 'dog')];
    final reminders = [
      DueItem(petId: '1', petName: 'Rex', label: 'Vaccin', dueDate: DateTime.now()),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petsProvider.overrideWith((ref) async => pets),
          upcomingRemindersProvider.overrideWith((ref) async => reminders),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vaccin'), findsOneWidget);
  });
}
