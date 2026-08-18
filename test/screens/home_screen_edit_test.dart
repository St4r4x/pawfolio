import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/pet.dart';
import 'package:pawfolio/providers/pets_provider.dart';
import 'package:pawfolio/providers/reminders_provider.dart';
import 'package:pawfolio/reminders.dart';
import 'package:pawfolio/repositories/pets_repository.dart';
import 'package:pawfolio/screens/home/home_screen.dart';

const _localNotificationsChannel = MethodChannel('dexterous.com/flutter/local_notifications');

class _FakePetsRepository implements PetsRepository {
  _FakePetsRepository(this.pets);

  final List<Pet> pets;
  Pet? updated;

  @override
  Future<List<Pet>> fetchAll() async => pets;

  @override
  Future<Pet> create(Pet pet) async => pet;

  @override
  Future<Pet> update(Pet pet) async {
    updated = pet;
    return pet;
  }
}

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

  testWidgets('editing a pet pre-fills the sheet and calls update', (tester) async {
    final pet = const Pet(id: 'p1', ownerId: 'u1', name: 'Rex', species: 'dog');
    final repo = _FakePetsRepository([pet]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petsRepositoryProvider.overrideWithValue(repo),
          upcomingRemindersProvider.overrideWith((ref) async => <DueItem>[]),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(find.text('Rex'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'Rex Junior');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(repo.updated?.name, 'Rex Junior');
  });
}
