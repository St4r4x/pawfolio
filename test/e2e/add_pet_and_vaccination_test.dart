import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/pet.dart';
import 'package:pawfolio/models/vaccination.dart';
import 'package:pawfolio/providers/pets_provider.dart';
import 'package:pawfolio/providers/reminders_provider.dart';
import 'package:pawfolio/providers/vaccinations_provider.dart';
import 'package:pawfolio/reminders.dart';
import 'package:pawfolio/repositories/pets_repository.dart';
import 'package:pawfolio/repositories/vaccinations_repository.dart';
import 'package:pawfolio/screens/home/home_screen.dart';
import 'package:pawfolio/screens/pet_detail/pet_detail_screen.dart';

const _localNotificationsChannel = MethodChannel('dexterous.com/flutter/local_notifications');

class FakePetsRepository implements PetsRepository {
  final List<Pet> pets = [];

  @override
  Future<List<Pet>> fetchAll() async => pets;

  @override
  Future<Pet> create(Pet pet) async {
    final created = Pet(id: 'p1', ownerId: 'u1', name: pet.name, species: pet.species);
    pets.add(created);
    return created;
  }
}

class FakeVaccinationsRepository implements VaccinationsRepository {
  final List<Vaccination> vaccinations = [];

  @override
  Future<List<Vaccination>> fetchForPet(String petId) async =>
      vaccinations.where((v) => v.petId == petId).toList();

  @override
  Future<void> create(Vaccination vaccination) async => vaccinations.add(vaccination);
}

void main() {
  setUp(() {
    // flutter_local_notifications 22.x resolves FlutterLocalNotificationsPlatform.instance
    // via plugin registration, which only happens through GeneratedPluginRegistrant on a
    // real device/platform channel setup — never in a plain widget test. Without this,
    // ReminderScheduler.scheduleAll's cancelAll() throws a LateInitializationError before
    // ever reaching the mocked channel below. Registering the method-channel-backed Android
    // implementation directly routes calls through the channel we mock.
    // ponytail: package's own registerWith(), not a hand-rolled fake platform impl.
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_localNotificationsChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_localNotificationsChannel, null);
  });

  testWidgets('add a pet, then add a vaccination, and see it in the list', (tester) async {
    final petsRepo = FakePetsRepository();
    final vaccinationsRepo = FakeVaccinationsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petsRepositoryProvider.overrideWithValue(petsRepo),
          vaccinationsRepositoryProvider.overrideWithValue(vaccinationsRepo),
          upcomingRemindersProvider.overrideWith((ref) async => <DueItem>[]),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Add a pet via the FAB bottom sheet.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Rex');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(find.text('Rex'), findsOneWidget);

    // Navigate to the pet's detail screen directly (go_router isn't in this
    // test's widget tree — HomeScreen's onTap calls context.push, which
    // needs a real router. Pumping PetDetailScreen directly keeps this test
    // focused on data flow rather than navigation.)
    //
    // Riverpod's ProviderScope disallows changing the number of overrides
    // between pumps of what it sees as the same widget subtree — pump a
    // blank widget first to force a full unmount, since the next
    // ProviderScope below has one fewer override (no upcomingRemindersProvider).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petsRepositoryProvider.overrideWithValue(petsRepo),
          vaccinationsRepositoryProvider.overrideWithValue(vaccinationsRepo),
        ],
        child: const MaterialApp(home: PetDetailScreen(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    // Add a vaccination via the Vaccins tab's FAB.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Rage');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(find.text('Rage'), findsOneWidget);
  });
}
