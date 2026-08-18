# Pawfolio MVP Final-Review Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Address the Important findings from the MVP's final whole-branch review: notification permissions never requested, the pet detail screen never shows the pet's own info, editing was never implemented anywhere, and auth screens swallow non-auth errors silently.

**Architecture:** No new architectural patterns. Editing follows the exact repository/bottom-sheet conventions already established by the "create" flows in Tasks 5-9 of the original MVP plan — each sheet function gains an optional `existing` parameter that pre-fills fields and switches the submit action from `create` to `update`.

**Tech Stack:** Same as the MVP (Flutter/Dart, Riverpod, Supabase). No new dependencies.

## Global Constraints

- RLS policies and `authenticated` GRANTs already cover `update` on all 5 tables (`for all` policies + `grant select, insert, update, delete` — verified directly against `supabase/migrations/`) — **no new SQL migration is needed for editing**.
- `flutter_local_notifications` is pinned at `^22.3.0` — its API uses named arguments (`initialize(settings: ...)`, `zonedSchedule(id: ..., title: ..., ...)`), confirmed from the actual current `lib/notifications/reminder_scheduler.dart`. Match that calling convention exactly; don't reintroduce positional-argument syntax from the original plan's brief text, which predates this adaptation.
- Every widget test that pumps `HomeScreen` must override `upcomingRemindersProvider` explicitly (to `(ref) async => <DueItem>[]` or similar) AND set up the local-notifications method-channel mock exactly as `test/e2e/add_pet_and_vaccination_test.dart` already does (`AndroidFlutterLocalNotificationsPlugin.registerWith()` + `setMockMethodCallHandler` on `MethodChannel('dexterous.com/flutter/local_notifications')`) — `HomeScreen` unconditionally calls `ReminderScheduler.scheduleAll` via `ref.listen` whenever `upcomingRemindersProvider` resolves to data, which touches the notifications platform channel.
- No new abstract `Repository` interfaces for `WeightEntriesRepository`, `TreatmentsRepository`, `VetVisitsRepository` — they stay concrete classes (existing convention, explicitly out of scope per the review's own triage).

---

## Task 12: Android notification permissions

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`, `lib/notifications/reminder_scheduler.dart`

**Interfaces:**
- No change to `ReminderScheduler`'s public API (`init()`, `scheduleAll(List<DueItem>)`).

- [ ] **Step 1: Add the notification permission to the manifest**

In `android/app/src/main/AndroidManifest.xml`, add this line immediately after the opening `<manifest ...>` tag (before `<application`):

```xml
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

- [ ] **Step 2: Request the permission at startup, and switch to inexact scheduling**

In `lib/notifications/reminder_scheduler.dart`, change `init()` from:

```dart
  Future<void> init() async {
    tzdata.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(settings: const InitializationSettings(android: androidInit));
  }
```

to:

```dart
  Future<void> init() async {
    tzdata.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(settings: const InitializationSettings(android: androidInit));
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }
```

Then change `scheduleAll`'s `androidScheduleMode` argument from:

```dart
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
```

to:

```dart
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
```

And update the `ponytail:` comment directly above `scheduleAll` (currently about UTC wall-clock time) to also note the scheduling-mode choice — replace the existing comment block:

```dart
  // ponytail: schedules against UTC wall-clock time instead of the device's
  // real timezone (that needs the flutter_timezone plugin to detect it).
  // A reminder may fire a few hours off from local midnight; acceptable for
  // a single-user MVP — revisit if multi-timezone usage makes this visible.
```

with:

```dart
  // ponytail: schedules against UTC wall-clock time instead of the device's
  // real timezone (that needs the flutter_timezone plugin to detect it).
  // A reminder may fire a few hours off from local midnight; acceptable for
  // a single-user MVP — revisit if multi-timezone usage makes this visible.
  // Also uses inexact scheduling (not "exact alarm") so no separate
  // SCHEDULE_EXACT_ALARM permission dance is needed — a health reminder a
  // few minutes/within a maintenance window off is fine; only
  // POST_NOTIFICATIONS (Android 13+) is actually required.
```

If `resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()` or `requestNotificationsPermission()` doesn't match the exact API surface of the installed `flutter_local_notifications` 22.3.0 (check `~/.pub-cache/hosted/pub.dev/flutter_local_notifications-22.3.0/lib/src/`), adjust the call to whatever the real method is called — the requirement is "request the POST_NOTIFICATIONS runtime permission during init", not this exact method name.

- [ ] **Step 3: Verify and commit**

```bash
cd /home/missia03/Projects/pawfolio
flutter analyze
flutter test > /tmp/task12_test_output.txt 2>&1
echo "exit code: $?"
cat /tmp/task12_test_output.txt
git add -A
git commit -m "fix: request notification permission and use inexact scheduling"
```

Expected: `flutter test` exits 0 with no regressions — no existing test exercises `ReminderScheduler` directly, so this is a pure regression check. The actual permission request will be confirmed manually in Task 18.

---

## Task 13: Pet detail header

**Files:**
- Modify: `lib/screens/pet_detail/pet_detail_screen.dart`
- Create: `test/screens/pet_detail_screen_test.dart`

**Interfaces:**
- Consumes: `petsProvider` (`FutureProvider<List<Pet>>`, from `lib/providers/pets_provider.dart`).
- No change to `PetDetailScreen`'s constructor (`{required String petId}`), so `lib/app_router.dart`'s route is unaffected.

- [ ] **Step 1: Write the failing test**

Create `test/screens/pet_detail_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/pet.dart';
import 'package:pawfolio/providers/pets_provider.dart';
import 'package:pawfolio/screens/pet_detail/pet_detail_screen.dart';

void main() {
  testWidgets("shows the pet's name, species, and breed in the header", (tester) async {
    final pets = [
      const Pet(id: 'p1', ownerId: 'u1', name: 'Rex', species: 'dog', breed: 'Labrador'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [petsProvider.overrideWith((ref) async => pets)],
        child: const MaterialApp(home: PetDetailScreen(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rex'), findsOneWidget);
    expect(find.text('Chien'), findsOneWidget);
    expect(find.text('Labrador'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
flutter test test/screens/pet_detail_screen_test.dart
```

Expected: FAIL — the current `PetDetailScreen` always shows the static title "Animal" and never renders species/breed.

- [ ] **Step 3: Replace `lib/screens/pet_detail/pet_detail_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../date_only.dart';
import '../../models/pet.dart';
import '../../providers/pets_provider.dart';
import 'widgets/treatments_tab.dart';
import 'widgets/vaccinations_tab.dart';
import 'widgets/vet_visits_tab.dart';
import 'widgets/weight_tab.dart';

const _speciesLabels = {'dog': 'Chien', 'cat': 'Chat', 'other': 'Autre'};

Pet? _findPet(List<Pet> pets, String petId) {
  for (final pet in pets) {
    if (pet.id == petId) return pet;
  }
  return null;
}

class PetDetailScreen extends ConsumerWidget {
  const PetDetailScreen({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petsAsync = ref.watch(petsProvider);
    final pet = petsAsync.when(
      loading: () => null,
      error: (_, __) => null,
      data: (pets) => _findPet(pets, petId),
    );

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(pet?.name ?? 'Animal'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Vaccins'),
              Tab(text: 'Poids'),
              Tab(text: 'Traitements'),
              Tab(text: 'RDV'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (pet != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_speciesLabels[pet.species] ?? pet.species),
                    if (pet.breed != null) Text(pet.breed!),
                    if (pet.birthDate != null) Text('Né(e) le ${dateOnly(pet.birthDate!)}'),
                  ],
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  VaccinationsTab(petId: petId),
                  WeightTab(petId: petId),
                  TreatmentsTab(petId: petId),
                  VetVisitsTab(petId: petId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test again**

```bash
flutter test test/screens/pet_detail_screen_test.dart
```

Expected: PASS.

- [ ] **Step 5: Run the full suite and commit**

```bash
flutter test > /tmp/task13_test_output.txt 2>&1
echo "exit code: $?"
cat /tmp/task13_test_output.txt
git add -A
git commit -m "feat: show pet name, species, and breed on the pet detail screen"
```

Expected: full suite passes, including `test/e2e/add_pet_and_vaccination_test.dart` — that test's assertions (`find.text('Rex')` before navigating away, `find.text('Rage')` after navigating to `PetDetailScreen`) don't collide with the new header, since neither assertion runs while both the header's "Rex" and any other "Rex" text would be on screen simultaneously.

---

## Task 14: Generic auth error handling

**Files:**
- Modify: `lib/screens/auth/login_screen.dart`, `lib/screens/auth/signup_screen.dart`
- Create: `test/screens/auth_error_handling_test.dart`

**Interfaces:**
- No change to either screen's public constructor.

- [ ] **Step 1: Write the failing tests**

Create `test/screens/auth_error_handling_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/screens/auth/login_screen.dart';
import 'package:pawfolio/screens/auth/signup_screen.dart';

void main() {
  testWidgets('login shows a generic error for non-auth exceptions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    expect(find.text('Impossible de contacter le serveur. Vérifie ta connexion.'), findsOneWidget);
  });

  testWidgets('signup shows a generic error for non-auth exceptions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text("S'inscrire"));
    await tester.pump();

    expect(find.text('Impossible de contacter le serveur. Vérifie ta connexion.'), findsOneWidget);
  });
}
```

These rely on `Supabase.instance` throwing (it's never initialized in this test file), which is not an `AuthException` — exactly the gap being fixed. If Task 3 of the design-polish plan has already run by the time this task executes, adapt the `TextField` lookups/button text to whatever that plan produced (inline validation + password toggle) rather than assuming the bare original screen shape — the point of the test is the error-handling behavior, not the exact field layout.

- [ ] **Step 2: Run it to confirm it fails**

```bash
flutter test test/screens/auth_error_handling_test.dart
```

Expected: FAIL — no error text appears at all today (neither screen's `catch` clause matches the actual thrown exception type, so `_error` never gets set).

- [ ] **Step 3: Add a catch-all to `lib/screens/auth/login_screen.dart`**

Change:

```dart
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
```

to:

```dart
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Impossible de contacter le serveur. Vérifie ta connexion.');
    } finally {
```

- [ ] **Step 4: Add the same catch-all to `lib/screens/auth/signup_screen.dart`**

Change:

```dart
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
```

to:

```dart
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Impossible de contacter le serveur. Vérifie ta connexion.');
    } finally {
```

- [ ] **Step 5: Run the test again**

```bash
flutter test test/screens/auth_error_handling_test.dart
```

Expected: PASS.

- [ ] **Step 6: Run the full suite and commit**

```bash
flutter test > /tmp/task14_test_output.txt 2>&1
echo "exit code: $?"
cat /tmp/task14_test_output.txt
git add -A
git commit -m "fix: show a generic error message for non-auth exceptions during sign-in/sign-up"
```

---

## Task 15: Editing — Pets

**Files:**
- Modify: `lib/repositories/pets_repository.dart`, `lib/screens/home/home_screen.dart`, `test/e2e/add_pet_and_vaccination_test.dart`
- Create: `test/screens/home_screen_edit_test.dart`

**Interfaces:**
- Produces: `PetsRepository.update(Pet pet) -> Future<Pet>`, added to the existing abstract interface and its `SupabasePetsRepository` implementation.

- [ ] **Step 1: Write the failing test**

Create `test/screens/home_screen_edit_test.dart`:

```dart
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
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
flutter test test/screens/home_screen_edit_test.dart
```

Expected: FAIL — no edit icon exists yet, and `PetsRepository` has no `update` method (this alone will also cause a compile error, which is an expected form of RED here).

- [ ] **Step 3: Add `update` to `lib/repositories/pets_repository.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pet.dart';

abstract class PetsRepository {
  Future<List<Pet>> fetchAll();
  Future<Pet> create(Pet pet);
  Future<Pet> update(Pet pet);
}

class SupabasePetsRepository implements PetsRepository {
  SupabasePetsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Pet>> fetchAll() async {
    final rows = await _client.from('pets').select().order('created_at');
    return rows.map((row) => Pet.fromJson(row)).toList();
  }

  @override
  Future<Pet> create(Pet pet) async {
    final ownerId = _client.auth.currentUser!.id;
    final row = await _client.from('pets').insert(pet.toInsertJson(ownerId: ownerId)).select().single();
    return Pet.fromJson(row);
  }

  @override
  Future<Pet> update(Pet pet) async {
    final row = await _client
        .from('pets')
        .update(pet.toInsertJson(ownerId: pet.ownerId))
        .eq('id', pet.id)
        .select()
        .single();
    return Pet.fromJson(row);
  }
}
```

- [ ] **Step 4: Add `update` to `FakePetsRepository` in `test/e2e/add_pet_and_vaccination_test.dart`**

`PetsRepository` now has a third method, so the existing fake (which `implements PetsRepository`) no longer compiles without it. Add, inside the existing `FakePetsRepository` class (after `create`):

```dart
  @override
  Future<Pet> update(Pet pet) async {
    final index = pets.indexWhere((p) => p.id == pet.id);
    if (index != -1) pets[index] = pet;
    return pet;
  }
```

- [ ] **Step 5: Update `lib/screens/home/home_screen.dart`**

Change `_showAddPetSheet`'s signature and body from:

```dart
  void _showAddPetSheet(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String species = 'dog';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (sheetContext, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom')),
              DropdownButton<String>(
                value: species,
                items: const [
                  DropdownMenuItem(value: 'dog', child: Text('Chien')),
                  DropdownMenuItem(value: 'cat', child: Text('Chat')),
                  DropdownMenuItem(value: 'other', child: Text('Autre')),
                ],
                onChanged: (value) => setState(() => species = value!),
              ),
              FilledButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;
                  try {
                    await ref.read(petsRepositoryProvider).create(
                          Pet(id: '', ownerId: '', name: nameController.text.trim(), species: species),
                        );
                    ref.invalidate(petsProvider);
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
                child: const Text('Ajouter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
```

to:

```dart
  void _showAddPetSheet(BuildContext context, WidgetRef ref, {Pet? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    String species = existing?.species ?? 'dog';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (sheetContext, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom')),
              DropdownButton<String>(
                value: species,
                items: const [
                  DropdownMenuItem(value: 'dog', child: Text('Chien')),
                  DropdownMenuItem(value: 'cat', child: Text('Chat')),
                  DropdownMenuItem(value: 'other', child: Text('Autre')),
                ],
                onChanged: (value) => setState(() => species = value!),
              ),
              FilledButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;
                  try {
                    if (existing == null) {
                      await ref.read(petsRepositoryProvider).create(
                            Pet(id: '', ownerId: '', name: nameController.text.trim(), species: species),
                          );
                    } else {
                      await ref.read(petsRepositoryProvider).update(
                            Pet(
                              id: existing.id,
                              ownerId: existing.ownerId,
                              name: nameController.text.trim(),
                              species: species,
                              breed: existing.breed,
                              birthDate: existing.birthDate,
                            ),
                          );
                    }
                    ref.invalidate(petsProvider);
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
                child: Text(existing == null ? 'Ajouter' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
```

Change the pet `ListTile` from:

```dart
                        for (final pet in pets)
                          ListTile(
                            title: Text(pet.name),
                            subtitle: Text(pet.species),
                            onTap: () => context.push('/pets/${pet.id}'),
                          ),
```

to:

```dart
                        for (final pet in pets)
                          ListTile(
                            title: Text(pet.name),
                            subtitle: Text(pet.species),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showAddPetSheet(context, ref, existing: pet),
                            ),
                            onTap: () => context.push('/pets/${pet.id}'),
                          ),
```

- [ ] **Step 6: Run the test again**

```bash
flutter test test/screens/home_screen_edit_test.dart
```

Expected: PASS.

- [ ] **Step 7: Run the full suite and commit**

```bash
flutter test > /tmp/task15_test_output.txt 2>&1
echo "exit code: $?"
cat /tmp/task15_test_output.txt
git add -A
git commit -m "feat: add pet editing"
```

---

## Task 16: Editing — Vaccinations & Weight

**Files:**
- Modify: `lib/repositories/vaccinations_repository.dart`, `lib/screens/pet_detail/widgets/vaccinations_tab.dart`, `lib/repositories/weight_entries_repository.dart`, `lib/screens/pet_detail/widgets/weight_tab.dart`, `test/e2e/add_pet_and_vaccination_test.dart`
- Create: `test/screens/vaccinations_edit_test.dart`, `test/screens/weight_edit_test.dart`

**Interfaces:**
- Produces: `VaccinationsRepository.update(Vaccination vaccination) -> Future<void>` (added to the abstract interface), and a new plain method `WeightEntriesRepository.update(WeightEntry entry) -> Future<void>` (no interface exists for this repository — matches its current concrete-class shape).

- [ ] **Step 1: Write the failing tests**

Create `test/screens/vaccinations_edit_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/vaccination.dart';
import 'package:pawfolio/providers/vaccinations_provider.dart';
import 'package:pawfolio/repositories/vaccinations_repository.dart';
import 'package:pawfolio/screens/pet_detail/widgets/vaccinations_tab.dart';

class _FakeVaccinationsRepository implements VaccinationsRepository {
  _FakeVaccinationsRepository(this.vaccinations);

  final List<Vaccination> vaccinations;
  Vaccination? updated;

  @override
  Future<List<Vaccination>> fetchForPet(String petId) async => vaccinations;

  @override
  Future<void> create(Vaccination vaccination) async {}

  @override
  Future<void> update(Vaccination vaccination) async => updated = vaccination;
}

void main() {
  testWidgets('editing a vaccination pre-fills the sheet and calls update', (tester) async {
    final vaccination = Vaccination(
      id: 'v1',
      petId: 'p1',
      name: 'Rage',
      dateAdministered: DateTime(2024, 1, 1),
    );
    final repo = _FakeVaccinationsRepository([vaccination]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [vaccinationsRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: VaccinationsTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(find.text('Rage'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'Rage (rappel)');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(repo.updated?.name, 'Rage (rappel)');
  });
}
```

Create `test/screens/weight_edit_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/weight_entry.dart';
import 'package:pawfolio/providers/weight_entries_provider.dart';
import 'package:pawfolio/screens/pet_detail/widgets/weight_tab.dart';

void main() {
  testWidgets('editing a weight entry pre-fills the sheet and calls update', (tester) async {
    final entry = WeightEntry(id: 'w1', petId: 'p1', weightKg: 12.5, recordedAt: DateTime(2024, 3, 1));
    WeightEntry? updated;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weightEntriesRepositoryProvider.overrideWithValue(_FakeWeightEntriesRepository(
            [entry],
            onUpdate: (e) => updated = e,
          )),
        ],
        child: const MaterialApp(home: WeightTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(find.textContaining('12.5'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, '13.0');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(updated?.weightKg, 13.0);
  });
}

class _FakeWeightEntriesRepository implements WeightEntriesRepository {
  _FakeWeightEntriesRepository(this.entries, {required this.onUpdate});

  final List<WeightEntry> entries;
  final void Function(WeightEntry) onUpdate;

  @override
  Future<List<WeightEntry>> fetchForPet(String petId) async => entries;

  @override
  Future<void> create(WeightEntry entry) async {}

  @override
  Future<void> update(WeightEntry entry) async => onUpdate(entry);
}
```

Note: `WeightEntriesRepository` is currently a concrete class, not an abstract interface — `implements WeightEntriesRepository` in the fake above works in Dart regardless (any concrete class can be `implements`-ed to build a structurally-compatible fake), so no interface needs to be introduced.

- [ ] **Step 2: Run both to confirm they fail**

```bash
flutter test test/screens/vaccinations_edit_test.dart test/screens/weight_edit_test.dart
```

Expected: FAIL — no edit icon or `update` method exists yet on either.

- [ ] **Step 3: Add `update` to `lib/repositories/vaccinations_repository.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vaccination.dart';

abstract class VaccinationsRepository {
  Future<List<Vaccination>> fetchForPet(String petId);
  Future<void> create(Vaccination vaccination);
  Future<void> update(Vaccination vaccination);
}

class SupabaseVaccinationsRepository implements VaccinationsRepository {
  SupabaseVaccinationsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Vaccination>> fetchForPet(String petId) async {
    final rows = await _client
        .from('vaccinations')
        .select()
        .eq('pet_id', petId)
        .order('date_administered', ascending: false);
    return rows.map((row) => Vaccination.fromJson(row)).toList();
  }

  @override
  Future<void> create(Vaccination vaccination) async {
    await _client.from('vaccinations').insert(vaccination.toInsertJson());
  }

  @override
  Future<void> update(Vaccination vaccination) async {
    await _client.from('vaccinations').update(vaccination.toInsertJson()).eq('id', vaccination.id);
  }
}
```

- [ ] **Step 4: Add `update` to `FakeVaccinationsRepository` in `test/e2e/add_pet_and_vaccination_test.dart`**

Add, inside the existing `FakeVaccinationsRepository` class (after `create`):

```dart
  @override
  Future<void> update(Vaccination vaccination) async {
    final index = vaccinations.indexWhere((v) => v.id == vaccination.id);
    if (index != -1) vaccinations[index] = vaccination;
  }
```

- [ ] **Step 5: Update `lib/screens/pet_detail/widgets/vaccinations_tab.dart`**

Change the vaccination `ListTile` from:

```dart
                  final vaccination = vaccinations[index];
                  final nextDue = vaccination.nextDueDate;
                  return ListTile(
                    title: Text(vaccination.name),
                    subtitle: Text(
                      'Fait le ${dateOnly(vaccination.dateAdministered)}'
                      '${nextDue != null ? ' · rappel le ${dateOnly(nextDue)}' : ''}',
                    ),
                  );
```

to:

```dart
                  final vaccination = vaccinations[index];
                  final nextDue = vaccination.nextDueDate;
                  return ListTile(
                    title: Text(vaccination.name),
                    subtitle: Text(
                      'Fait le ${dateOnly(vaccination.dateAdministered)}'
                      '${nextDue != null ? ' · rappel le ${dateOnly(nextDue)}' : ''}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showAddVaccinationSheet(context, ref, existing: vaccination),
                    ),
                  );
```

Change `_showAddVaccinationSheet`'s signature and body from:

```dart
  void _showAddVaccinationSheet(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    DateTime dateAdministered = DateTime.now();
    DateTime? nextDueDate;
```

to:

```dart
  void _showAddVaccinationSheet(BuildContext context, WidgetRef ref, {Vaccination? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    DateTime dateAdministered = existing?.dateAdministered ?? DateTime.now();
    DateTime? nextDueDate = existing?.nextDueDate;
```

Change the submit `FilledButton`'s `onPressed` from:

```dart
                  if (nameController.text.trim().isEmpty) return;
                  try {
                    await ref.read(vaccinationsRepositoryProvider).create(Vaccination(
                          id: '',
                          petId: petId,
                          name: nameController.text.trim(),
                          dateAdministered: dateAdministered,
                          nextDueDate: nextDueDate,
                        ));
                    ref.invalidate(vaccinationsProvider(petId));
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
                child: const Text('Ajouter'),
```

to:

```dart
                  if (nameController.text.trim().isEmpty) return;
                  try {
                    if (existing == null) {
                      await ref.read(vaccinationsRepositoryProvider).create(Vaccination(
                            id: '',
                            petId: petId,
                            name: nameController.text.trim(),
                            dateAdministered: dateAdministered,
                            nextDueDate: nextDueDate,
                          ));
                    } else {
                      await ref.read(vaccinationsRepositoryProvider).update(Vaccination(
                            id: existing.id,
                            petId: petId,
                            name: nameController.text.trim(),
                            dateAdministered: dateAdministered,
                            nextDueDate: nextDueDate,
                            notes: existing.notes,
                          ));
                    }
                    ref.invalidate(vaccinationsProvider(petId));
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
                child: Text(existing == null ? 'Ajouter' : 'Enregistrer'),
```

- [ ] **Step 6: Add `update` to `lib/repositories/weight_entries_repository.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/weight_entry.dart';

class WeightEntriesRepository {
  WeightEntriesRepository(this._client);

  final SupabaseClient _client;

  Future<List<WeightEntry>> fetchForPet(String petId) async {
    final rows = await _client
        .from('weight_entries')
        .select()
        .eq('pet_id', petId)
        .order('recorded_at', ascending: false);
    return rows.map((row) => WeightEntry.fromJson(row)).toList();
  }

  Future<void> create(WeightEntry entry) async {
    await _client.from('weight_entries').insert(entry.toInsertJson());
  }

  Future<void> update(WeightEntry entry) async {
    await _client.from('weight_entries').update(entry.toInsertJson()).eq('id', entry.id);
  }
}
```

- [ ] **Step 7: Update `lib/screens/pet_detail/widgets/weight_tab.dart`**

Change the entry `ListTile` from:

```dart
                  final entry = entries[index];
                  return ListTile(
                    title: Text('${entry.weightKg} kg'),
                    subtitle: Text(dateOnly(entry.recordedAt)),
                  );
```

to:

```dart
                  final entry = entries[index];
                  return ListTile(
                    title: Text('${entry.weightKg} kg'),
                    subtitle: Text(dateOnly(entry.recordedAt)),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showAddWeightSheet(context, ref, existing: entry),
                    ),
                  );
```

Change `_showAddWeightSheet`'s signature and body from:

```dart
  void _showAddWeightSheet(BuildContext context, WidgetRef ref) {
    final weightController = TextEditingController();
    DateTime recordedAt = DateTime.now();
```

to:

```dart
  void _showAddWeightSheet(BuildContext context, WidgetRef ref, {WeightEntry? existing}) {
    final weightController = TextEditingController(text: existing?.weightKg.toString() ?? '');
    DateTime recordedAt = existing?.recordedAt ?? DateTime.now();
```

Change the submit `FilledButton`'s `onPressed` from:

```dart
                  final weight = double.tryParse(weightController.text.replaceAll(',', '.'));
                  if (weight == null) return;
                  try {
                    await ref.read(weightEntriesRepositoryProvider).create(WeightEntry(
                          id: '',
                          petId: petId,
                          weightKg: weight,
                          recordedAt: recordedAt,
                        ));
                    ref.invalidate(weightEntriesProvider(petId));
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
                child: const Text('Ajouter'),
```

to:

```dart
                  final weight = double.tryParse(weightController.text.replaceAll(',', '.'));
                  if (weight == null) return;
                  try {
                    if (existing == null) {
                      await ref.read(weightEntriesRepositoryProvider).create(WeightEntry(
                            id: '',
                            petId: petId,
                            weightKg: weight,
                            recordedAt: recordedAt,
                          ));
                    } else {
                      await ref.read(weightEntriesRepositoryProvider).update(WeightEntry(
                            id: existing.id,
                            petId: petId,
                            weightKg: weight,
                            recordedAt: recordedAt,
                          ));
                    }
                    ref.invalidate(weightEntriesProvider(petId));
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
                child: Text(existing == null ? 'Ajouter' : 'Enregistrer'),
```

- [ ] **Step 8: Run both tests again**

```bash
flutter test test/screens/vaccinations_edit_test.dart test/screens/weight_edit_test.dart
```

Expected: PASS.

- [ ] **Step 9: Run the full suite and commit**

```bash
flutter test > /tmp/task16_test_output.txt 2>&1
echo "exit code: $?"
cat /tmp/task16_test_output.txt
git add -A
git commit -m "feat: add vaccination and weight-entry editing"
```

---

## Task 17: Editing — Treatments & Vet visits

**Files:**
- Modify: `lib/repositories/treatments_repository.dart`, `lib/screens/pet_detail/widgets/treatments_tab.dart`, `lib/repositories/vet_visits_repository.dart`, `lib/screens/pet_detail/widgets/vet_visits_tab.dart`
- Create: `test/screens/treatments_edit_test.dart`, `test/screens/vet_visits_edit_test.dart`

**Interfaces:**
- Produces: `TreatmentsRepository.update(Treatment treatment) -> Future<void>` and `VetVisitsRepository.update(VetVisit visit) -> Future<void>` (both plain concrete-class methods, matching their current shape — no abstract interface exists for either).

- [ ] **Step 1: Write the failing tests**

Create `test/screens/treatments_edit_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/treatment.dart';
import 'package:pawfolio/providers/treatments_provider.dart';
import 'package:pawfolio/repositories/treatments_repository.dart';
import 'package:pawfolio/screens/pet_detail/widgets/treatments_tab.dart';

void main() {
  testWidgets('editing a treatment pre-fills the sheet and calls update', (tester) async {
    final treatment = Treatment(
      id: 't1',
      petId: 'p1',
      type: 'dewormer',
      name: 'Milbemax',
      dateGiven: DateTime(2024, 2, 1),
    );
    Treatment? updated;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          treatmentsRepositoryProvider.overrideWithValue(
            _FakeTreatmentsRepository([treatment], onUpdate: (t) => updated = t),
          ),
        ],
        child: const MaterialApp(home: TreatmentsTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(find.text('Milbemax'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'Milbemax (rappel)');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(updated?.name, 'Milbemax (rappel)');
  });
}

class _FakeTreatmentsRepository implements TreatmentsRepository {
  _FakeTreatmentsRepository(this.treatments, {required this.onUpdate});

  final List<Treatment> treatments;
  final void Function(Treatment) onUpdate;

  @override
  Future<List<Treatment>> fetchForPet(String petId) async => treatments;

  @override
  Future<void> create(Treatment treatment) async {}

  @override
  Future<void> update(Treatment treatment) async => onUpdate(treatment);
}
```

Create `test/screens/vet_visits_edit_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/vet_visit.dart';
import 'package:pawfolio/providers/vet_visits_provider.dart';
import 'package:pawfolio/repositories/vet_visits_repository.dart';
import 'package:pawfolio/screens/pet_detail/widgets/vet_visits_tab.dart';

void main() {
  testWidgets('editing a vet visit pre-fills the sheet and calls update', (tester) async {
    final visit = VetVisit(
      id: 'vv1',
      petId: 'p1',
      visitDate: DateTime(2024, 4, 10),
      reason: 'Contrôle annuel',
    );
    VetVisit? updated;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vetVisitsRepositoryProvider.overrideWithValue(
            _FakeVetVisitsRepository([visit], onUpdate: (v) => updated = v),
          ),
        ],
        child: const MaterialApp(home: VetVisitsTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(find.text('Contrôle annuel'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'Contrôle annuel + vaccin');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(updated?.reason, 'Contrôle annuel + vaccin');
  });
}

class _FakeVetVisitsRepository implements VetVisitsRepository {
  _FakeVetVisitsRepository(this.visits, {required this.onUpdate});

  final List<VetVisit> visits;
  final void Function(VetVisit) onUpdate;

  @override
  Future<List<VetVisit>> fetchForPet(String petId) async => visits;

  @override
  Future<void> create(VetVisit visit) async {}

  @override
  Future<void> update(VetVisit visit) async => onUpdate(visit);
}
```

- [ ] **Step 2: Run both to confirm they fail**

```bash
flutter test test/screens/treatments_edit_test.dart test/screens/vet_visits_edit_test.dart
```

Expected: FAIL — no edit icon or `update` method exists yet on either.

- [ ] **Step 3: Add `update` to `lib/repositories/treatments_repository.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/treatment.dart';

class TreatmentsRepository {
  TreatmentsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Treatment>> fetchForPet(String petId) async {
    final rows = await _client
        .from('treatments')
        .select()
        .eq('pet_id', petId)
        .order('date_given', ascending: false);
    return rows.map((row) => Treatment.fromJson(row)).toList();
  }

  Future<void> create(Treatment treatment) async {
    await _client.from('treatments').insert(treatment.toInsertJson());
  }

  Future<void> update(Treatment treatment) async {
    await _client.from('treatments').update(treatment.toInsertJson()).eq('id', treatment.id);
  }
}
```

- [ ] **Step 4: Update `lib/screens/pet_detail/widgets/treatments_tab.dart`**

Change the treatment `ListTile` from:

```dart
                  final treatment = treatments[index];
                  final nextDue = treatment.nextDueDate;
                  return ListTile(
                    title: Text(treatment.name),
                    subtitle: Text(
                      '${_typeLabels[treatment.type]} · fait le ${dateOnly(treatment.dateGiven)}'
                      '${nextDue != null ? ' · rappel le ${dateOnly(nextDue)}' : ''}',
                    ),
                  );
```

to:

```dart
                  final treatment = treatments[index];
                  final nextDue = treatment.nextDueDate;
                  return ListTile(
                    title: Text(treatment.name),
                    subtitle: Text(
                      '${_typeLabels[treatment.type]} · fait le ${dateOnly(treatment.dateGiven)}'
                      '${nextDue != null ? ' · rappel le ${dateOnly(nextDue)}' : ''}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showAddTreatmentSheet(context, ref, existing: treatment),
                    ),
                  );
```

Change `_showAddTreatmentSheet`'s signature and body from:

```dart
  void _showAddTreatmentSheet(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String type = 'dewormer';
    DateTime dateGiven = DateTime.now();
    DateTime? nextDueDate;
```

to:

```dart
  void _showAddTreatmentSheet(BuildContext context, WidgetRef ref, {Treatment? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    String type = existing?.type ?? 'dewormer';
    DateTime dateGiven = existing?.dateGiven ?? DateTime.now();
    DateTime? nextDueDate = existing?.nextDueDate;
```

Change the submit `FilledButton`'s `onPressed` from:

```dart
                  if (nameController.text.trim().isEmpty) return;
                  try {
                    await ref.read(treatmentsRepositoryProvider).create(Treatment(
                          id: '',
                          petId: petId,
                          type: type,
                          name: nameController.text.trim(),
                          dateGiven: dateGiven,
                          nextDueDate: nextDueDate,
                        ));
                    ref.invalidate(treatmentsProvider(petId));
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
                child: const Text('Ajouter'),
```

to:

```dart
                  if (nameController.text.trim().isEmpty) return;
                  try {
                    if (existing == null) {
                      await ref.read(treatmentsRepositoryProvider).create(Treatment(
                            id: '',
                            petId: petId,
                            type: type,
                            name: nameController.text.trim(),
                            dateGiven: dateGiven,
                            nextDueDate: nextDueDate,
                          ));
                    } else {
                      await ref.read(treatmentsRepositoryProvider).update(Treatment(
                            id: existing.id,
                            petId: petId,
                            type: type,
                            name: nameController.text.trim(),
                            dateGiven: dateGiven,
                            nextDueDate: nextDueDate,
                            notes: existing.notes,
                          ));
                    }
                    ref.invalidate(treatmentsProvider(petId));
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
                child: Text(existing == null ? 'Ajouter' : 'Enregistrer'),
```

- [ ] **Step 5: Add `update` to `lib/repositories/vet_visits_repository.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vet_visit.dart';

class VetVisitsRepository {
  VetVisitsRepository(this._client);

  final SupabaseClient _client;

  Future<List<VetVisit>> fetchForPet(String petId) async {
    final rows = await _client
        .from('vet_visits')
        .select()
        .eq('pet_id', petId)
        .order('visit_date', ascending: false);
    return rows.map((row) => VetVisit.fromJson(row)).toList();
  }

  Future<void> create(VetVisit visit) async {
    await _client.from('vet_visits').insert(visit.toInsertJson());
  }

  Future<void> update(VetVisit visit) async {
    await _client.from('vet_visits').update(visit.toInsertJson()).eq('id', visit.id);
  }
}
```

- [ ] **Step 6: Update `lib/screens/pet_detail/widgets/vet_visits_tab.dart`**

Change the visit `ListTile` from:

```dart
                  final visit = visits[index];
                  final nextVisit = visit.nextVisitDate;
                  return ListTile(
                    title: Text(visit.reason),
                    subtitle: Text(
                      'Le ${dateOnly(visit.visitDate)}'
                      '${nextVisit != null ? ' · prochain RDV le ${dateOnly(nextVisit)}' : ''}',
                    ),
                  );
```

to:

```dart
                  final visit = visits[index];
                  final nextVisit = visit.nextVisitDate;
                  return ListTile(
                    title: Text(visit.reason),
                    subtitle: Text(
                      'Le ${dateOnly(visit.visitDate)}'
                      '${nextVisit != null ? ' · prochain RDV le ${dateOnly(nextVisit)}' : ''}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showAddVisitSheet(context, ref, existing: visit),
                    ),
                  );
```

Change `_showAddVisitSheet`'s signature and body from:

```dart
  void _showAddVisitSheet(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();
    DateTime visitDate = DateTime.now();
    DateTime? nextVisitDate;
```

to:

```dart
  void _showAddVisitSheet(BuildContext context, WidgetRef ref, {VetVisit? existing}) {
    final reasonController = TextEditingController(text: existing?.reason ?? '');
    DateTime visitDate = existing?.visitDate ?? DateTime.now();
    DateTime? nextVisitDate = existing?.nextVisitDate;
```

Change the submit `FilledButton`'s `onPressed` from:

```dart
                  if (reasonController.text.trim().isEmpty) return;
                  try {
                    await ref.read(vetVisitsRepositoryProvider).create(VetVisit(
                          id: '',
                          petId: petId,
                          visitDate: visitDate,
                          reason: reasonController.text.trim(),
                          nextVisitDate: nextVisitDate,
                        ));
                    ref.invalidate(vetVisitsProvider(petId));
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
                child: const Text('Ajouter'),
```

to:

```dart
                  if (reasonController.text.trim().isEmpty) return;
                  try {
                    if (existing == null) {
                      await ref.read(vetVisitsRepositoryProvider).create(VetVisit(
                            id: '',
                            petId: petId,
                            visitDate: visitDate,
                            reason: reasonController.text.trim(),
                            nextVisitDate: nextVisitDate,
                          ));
                    } else {
                      await ref.read(vetVisitsRepositoryProvider).update(VetVisit(
                            id: existing.id,
                            petId: petId,
                            visitDate: visitDate,
                            reason: reasonController.text.trim(),
                            nextVisitDate: nextVisitDate,
                            notes: existing.notes,
                          ));
                    }
                    ref.invalidate(vetVisitsProvider(petId));
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
                child: Text(existing == null ? 'Ajouter' : 'Enregistrer'),
```

- [ ] **Step 7: Run both tests again**

```bash
flutter test test/screens/treatments_edit_test.dart test/screens/vet_visits_edit_test.dart
```

Expected: PASS.

- [ ] **Step 8: Run the full suite and commit**

```bash
flutter test > /tmp/task17_test_output.txt 2>&1
echo "exit code: $?"
cat /tmp/task17_test_output.txt
git add -A
git commit -m "feat: add treatment and vet-visit editing"
```

---

## Task 18: Manual verification on the Android emulator

**Files:**
- None (verification task; only commit if this step surfaces something that needs fixing)

**Interfaces:**
- Consumes: everything from Tasks 12-17.

- [ ] **Step 1: Boot the emulator and run the app**

```bash
cd /home/missia03/Projects/pawfolio
supabase status || supabase start
emulator -avd pawfolio -no-snapshot-load &
adb wait-for-device
until [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = "1" ]; do sleep 2; done
./scripts/run_local.sh &
sleep 60
```

- [ ] **Step 2: Verify the notification permission prompt and a real scheduled notification**

Log in with the account created during the original MVP's Task 11 verification (or sign up a new one). Screenshot right after reaching the Home screen:

```bash
adb shell screencap -p /sdcard/pawfolio_perm.png
adb pull /sdcard/pawfolio_perm.png /tmp/pawfolio_perm.png
```

Read `/tmp/pawfolio_perm.png` — confirm a system notification-permission dialog appeared (Android's standard "Allow Pawfolio to send you notifications?" prompt) rather than nothing happening. Tap "Allow" (`adb shell input tap <x> <y>` at the dialog's allow-button coordinates). Add a vaccination or treatment with a due date of today (or check one already exists from earlier testing), pull-to-refresh the Home screen, wait a few seconds, then pull down the notification shade and screenshot again to confirm a real notification appears:

```bash
adb shell input swipe 500 0 500 800
adb shell screencap -p /sdcard/pawfolio_notif.png
adb pull /sdcard/pawfolio_notif.png /tmp/pawfolio_notif.png
```

- [ ] **Step 3: Verify the pet detail header**

Navigate into a pet's detail screen and screenshot:

```bash
adb shell screencap -p /sdcard/pawfolio_pet_header.png
adb pull /sdcard/pawfolio_pet_header.png /tmp/pawfolio_pet_header.png
```

Confirm the app bar shows the pet's actual name (not "Animal") and the header below it shows species (and breed/birth date if set).

- [ ] **Step 4: Verify editing end-to-end for at least two record types**

Tap the edit icon next to a pet on the Home screen, change its name, save, and confirm the change persists after a pull-to-refresh. Repeat for one record inside a pet's detail tabs (e.g. edit a vaccination's name). Screenshot each result:

```bash
adb shell screencap -p /sdcard/pawfolio_edit.png
adb pull /sdcard/pawfolio_edit.png /tmp/pawfolio_edit.png
```

- [ ] **Step 5: Verify the generic auth error message**

Sign out, then on the login screen, turn on the emulator's airplane mode (`adb shell settings put global airplane_mode_on 1 && adb shell am broadcast -a android.intent.action.AIRPLANE_MODE`) and attempt to log in. Confirm "Impossible de contacter le serveur. Vérifie ta connexion." appears instead of a blank/frozen form. Turn airplane mode back off afterward (`adb shell settings put global airplane_mode_on 0 && adb shell am broadcast -a android.intent.action.AIRPLANE_MODE`).

- [ ] **Step 6: Fix anything found, or confirm clean**

If any of the above didn't work as expected, fix it in the relevant file from Tasks 12-17 and re-verify. If everything matches, no code changes are needed.

- [ ] **Step 7: Final commit (only if Step 6 required changes)**

```bash
cd /home/missia03/Projects/pawfolio
git add -A
git commit -m "fix: address issues found during final-review-fixes verification"
```

If Step 6 required no changes, skip this commit.

---

## Task 19: Regression test for auth error classification

**Files:**
- Create: `lib/auth_error_message.dart`, `test/auth_error_message_test.dart`
- Modify: `lib/screens/auth/login_screen.dart`, `lib/screens/auth/signup_screen.dart`

**Interfaces:**
- Produces: `authErrorMessage(Object error) -> String`.

**Context:** Task 18's live device verification found that `AuthRetryableFetchException` (thrown by gotrue for raw network failures) is a *subtype* of `AuthException`, so it must be caught before the generic `AuthException` clause or its raw technical message leaks to the UI. That fix (commit `d1e7306`) is already live in both screens as three separate `catch` clauses in a specific required order — but nothing tests that ordering, so a future edit (e.g. reordering catches during a refactor) could silently reintroduce the bug with no test failure to catch it. This task collapses the three catch clauses into one, delegating the classification to a small pure function that's directly unit-testable without needing Supabase initialized, a real network call, or a widget at all — `AuthRetryableFetchException` has a public constructor (`AuthRetryableFetchException({String message, String? statusCode})`), so tests can construct one directly.

- [ ] **Step 1: Write the failing test**

Create `test/auth_error_message_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/auth_error_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('returns a friendly message for AuthRetryableFetchException', () {
    final error = AuthRetryableFetchException(message: 'ClientException with SocketException');
    expect(authErrorMessage(error), 'Impossible de contacter le serveur. Vérifie ta connexion.');
  });

  test('returns the raw message for a plain AuthException', () {
    const error = AuthException('Invalid login credentials');
    expect(authErrorMessage(error), 'Invalid login credentials');
  });

  test('returns a friendly message for any other error type', () {
    expect(authErrorMessage(Exception('boom')), 'Impossible de contacter le serveur. Vérifie ta connexion.');
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
flutter test test/auth_error_message_test.dart
```

Expected: FAIL — `lib/auth_error_message.dart` doesn't exist.

- [ ] **Step 3: Create `lib/auth_error_message.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

String authErrorMessage(Object error) {
  if (error is AuthRetryableFetchException) {
    return 'Impossible de contacter le serveur. Vérifie ta connexion.';
  }
  if (error is AuthException) {
    return error.message;
  }
  return 'Impossible de contacter le serveur. Vérifie ta connexion.';
}
```

- [ ] **Step 4: Run the test again**

```bash
flutter test test/auth_error_message_test.dart
```

Expected: PASS.

- [ ] **Step 5: Wire it into `lib/screens/auth/login_screen.dart`**

Add the import:

```dart
import '../../auth_error_message.dart';
```

Replace the current three-clause catch block:

```dart
    } on AuthRetryableFetchException {
      // gotrue wraps raw network failures (e.g. no connectivity) as a
      // *subtype* of AuthException with a raw technical message (see
      // gotrue's GotrueFetch._handleError) - it must be caught before the
      // generic `on AuthException` clause below or that clause swallows it
      // and shows the raw message instead of this friendly one.
      setState(() => _error = 'Impossible de contacter le serveur. Vérifie ta connexion.');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Impossible de contacter le serveur. Vérifie ta connexion.');
    } finally {
```

with:

```dart
    } catch (e) {
      setState(() => _error = authErrorMessage(e));
    } finally {
```

- [ ] **Step 6: Apply the identical change to `lib/screens/auth/signup_screen.dart`**

Same import addition, same catch-block replacement (the file has the identical three-clause structure).

- [ ] **Step 7: Run the full suite and commit**

```bash
flutter test > /tmp/task19_test_output.txt 2>&1
echo "exit code: $?"
cat /tmp/task19_test_output.txt
git add -A
git commit -m "refactor: extract testable auth error classification"
```

Expected: full suite passes, including the existing `test/screens/auth_error_handling_test.dart` (its assertions still hold — `authErrorMessage` produces the same output the inline catch logic did).

---
