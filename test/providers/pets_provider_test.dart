import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/pet.dart';
import 'package:pawfolio/providers/current_user_id_provider.dart';
import 'package:pawfolio/providers/pets_provider.dart';
import 'package:pawfolio/repositories/pets_repository.dart';

class _CountingPetsRepository implements PetsRepository {
  int fetchAllCallCount = 0;

  @override
  Future<List<Pet>> fetchAll() async {
    fetchAllCallCount++;
    return [];
  }

  @override
  Future<Pet> create(Pet pet) async => pet;

  @override
  Future<Pet> update(Pet pet) async => pet;
}

void main() {
  test('petsProvider refetches whenever the current user id changes', () async {
    final userIdController = StreamController<String?>();
    addTearDown(userIdController.close);
    final repo = _CountingPetsRepository();

    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => userIdController.stream),
        petsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    // Mirrors HomeScreen's ref.watch(petsProvider) in build(): an active
    // listener is what makes Riverpod eagerly refetch on invalidation,
    // same as it would for a real mounted widget.
    container.listen(petsProvider, (previous, next) {});

    await container.read(petsProvider.future);
    expect(repo.fetchAllCallCount, 1);

    userIdController.add('user-a');
    await pumpEventQueue();
    await container.read(petsProvider.future);
    expect(repo.fetchAllCallCount, 2);

    userIdController.add('user-b');
    await pumpEventQueue();
    await container.read(petsProvider.future);
    expect(repo.fetchAllCallCount, 3);
  });
}
