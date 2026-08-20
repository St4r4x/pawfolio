import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/pet.dart';
import 'package:pawfolio/providers/pet_photo_uploader_provider.dart';
import 'package:pawfolio/providers/pets_provider.dart';
import 'package:pawfolio/providers/reminders_provider.dart';
import 'package:pawfolio/reminders.dart';
import 'package:pawfolio/repositories/pets_repository.dart';
import 'package:pawfolio/screens/home/home_screen.dart';

const _localNotificationsChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

class _FakePetsRepository implements PetsRepository {
  _FakePetsRepository(this.pets);

  final List<Pet> pets;
  Pet? updated;
  Pet? created;

  @override
  Future<List<Pet>> fetchAll() async => pets;

  @override
  Future<Pet> create(Pet pet) async {
    created = pet;
    return pet;
  }

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
        .setMockMethodCallHandler(
          _localNotificationsChannel,
          (call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_localNotificationsChannel, null);
  });

  testWidgets('editing a pet pre-fills the sheet and calls update', (
    tester,
  ) async {
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

  testWidgets(
    'editing a pet lets you change the breed field and keeps the birth date',
    (tester) async {
      final pet = Pet(
        id: 'p1',
        ownerId: 'u1',
        name: 'Rex',
        species: 'dog',
        breed: 'Labrador',
        birthDate: DateTime(2020, 5, 1),
      );
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

      expect(find.text('Labrador'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(1), 'Golden Retriever');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(repo.updated?.breed, 'Golden Retriever');
      expect(repo.updated?.birthDate, DateTime(2020, 5, 1));
    },
  );

  testWidgets('adding a pet with a breed calls create with that breed', (
    tester,
  ) async {
    final repo = _FakePetsRepository([]);

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

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Mia');
    await tester.enterText(find.byType(TextField).at(1), 'Siamois');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(repo.created?.breed, 'Siamois');
  });

  testWidgets('the delete-photo option only appears when the pet already has a photo', (tester) async {
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

    await tester.tap(find.byIcon(Icons.camera_alt).last);
    await tester.pumpAndSettle();

    expect(find.text('Supprimer la photo'), findsNothing);
  });

  testWidgets('deleting the photo clears photoUrl on save', (tester) async {
    final pet = const Pet(
      id: 'p1',
      ownerId: 'u1',
      name: 'Rex',
      species: 'dog',
      photoUrl: 'https://example.com/rex.jpg',
    );
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

    await tester.tap(find.byIcon(Icons.camera_alt).last);
    await tester.pumpAndSettle();

    expect(find.text('Supprimer la photo'), findsOneWidget);
    await tester.tap(find.text('Supprimer la photo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(repo.updated?.photoUrl, isNull);
  });

  testWidgets('choosing a gallery photo uploads it and saves the returned URL', (tester) async {
    final repo = _FakePetsRepository([]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petsRepositoryProvider.overrideWithValue(repo),
          upcomingRemindersProvider.overrideWith((ref) async => <DueItem>[]),
          petPhotoUploaderProvider.overrideWithValue((source) async => 'https://example.com/mia.jpg'),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.camera_alt).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choisir dans la galerie'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Mia');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(repo.created?.photoUrl, 'https://example.com/mia.jpg');
  });
}
