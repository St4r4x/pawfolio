import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/pet.dart';
import 'package:pawfolio/providers/current_user_id_provider.dart';
import 'package:pawfolio/providers/pets_provider.dart';
import 'package:pawfolio/providers/reminders_provider.dart';
import 'package:pawfolio/reminders.dart';
import 'package:pawfolio/repositories/pets_repository.dart';
import 'package:pawfolio/screens/home/home_screen.dart';
import 'package:pawfolio/widgets/empty_state.dart';
import 'package:pawfolio/widgets/pet_avatar.dart';

class _SwitchingPetsRepository implements PetsRepository {
  _SwitchingPetsRepository(this.petsPerCall);

  final List<List<Pet>> petsPerCall;
  int _calls = 0;

  @override
  Future<List<Pet>> fetchAll() async {
    final pets = petsPerCall[_calls];
    if (_calls < petsPerCall.length - 1) _calls++;
    return pets;
  }

  @override
  Future<Pet> create(Pet pet) async => pet;

  @override
  Future<Pet> update(Pet pet) async => pet;
}

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

  testWidgets('shows the new account\'s pets after switching accounts, not the previous one\'s',
      (tester) async {
    final userIdController = StreamController<String?>();
    addTearDown(userIdController.close);
    final repo = _SwitchingPetsRepository([
      [], // fetched once on first build, before currentUserIdProvider knows any user
      [const Pet(id: '1', ownerId: 'u1', name: 'Rex', species: 'dog')],
      [const Pet(id: '2', ownerId: 'u2', name: 'Mia', species: 'cat')],
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => userIdController.stream),
          petsRepositoryProvider.overrideWithValue(repo),
          upcomingRemindersProvider.overrideWith((ref) async => <DueItem>[]),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    userIdController.add('user-a');
    await tester.pumpAndSettle();

    expect(find.text('Rex'), findsOneWidget);
    expect(find.text('Mia'), findsNothing);

    userIdController.add('user-b');
    await tester.pumpAndSettle();

    expect(find.text('Mia'), findsOneWidget);
    expect(find.text('Rex'), findsNothing);
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
