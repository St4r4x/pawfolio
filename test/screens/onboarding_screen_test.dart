import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawfolio/models/pet.dart';
import 'package:pawfolio/providers/pets_provider.dart';
import 'package:pawfolio/repositories/pets_repository.dart';
import 'package:pawfolio/screens/onboarding/onboarding_screen.dart';

class _FakePetsRepository implements PetsRepository {
  _FakePetsRepository({this.createError});

  Pet? created;
  Object? createError;

  @override
  Future<List<Pet>> fetchAll() async => [];

  @override
  Future<Pet> create(Pet pet) async {
    if (createError != null) throw createError!;
    final withId = Pet(
      id: 'p1',
      ownerId: 'u1',
      name: pet.name,
      species: pet.species,
    );
    created = withId;
    return withId;
  }

  @override
  Future<Pet> update(Pet pet) async => pet;
}

GoRouter _buildTestRouter() => GoRouter(
  initialLocation: '/onboarding',
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(path: '/', builder: (context, state) => const Text('Home')),
  ],
);

void main() {
  testWidgets(
    'advances to the pet step after continuing, even if saving the name fails',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petsRepositoryProvider.overrideWithValue(_FakePetsRepository()),
          ],
          child: const MaterialApp(home: OnboardingScreen()),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'Arnaud');
      await tester.tap(find.text('Continuer'));
      await tester.pump();

      expect(find.text('Ajouter'), findsOneWidget);
    },
  );

  testWidgets(
    'creating a pet on the pet step calls create and navigates home',
    (tester) async {
      final repo = _FakePetsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [petsRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp.router(routerConfig: _buildTestRouter()),
        ),
      );

      await tester.tap(find.text('Continuer'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'Rex');
      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();

      expect(repo.created?.name, 'Rex');
      expect(find.text('Home'), findsOneWidget);
    },
  );

  testWidgets('skipping the pet step navigates home without creating a pet', (
    tester,
  ) async {
    final repo = _FakePetsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [petsRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: _buildTestRouter()),
      ),
    );

    await tester.tap(find.text('Continuer'));
    await tester.pump();
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();

    expect(repo.created, isNull);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets(
    'shows a generic error and stays on the pet step when creating the pet fails',
    (tester) async {
      final repo = _FakePetsRepository(createError: Exception('boom'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [petsRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp.router(routerConfig: _buildTestRouter()),
        ),
      );

      await tester.tap(find.text('Continuer'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'Rex');
      await tester.tap(find.text('Ajouter'));
      await tester.pump();

      expect(
        find.text('Impossible de contacter le serveur. Vérifie ta connexion.'),
        findsOneWidget,
      );
      expect(find.text('Ajouter'), findsOneWidget);
    },
  );
}
