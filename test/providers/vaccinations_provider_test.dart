import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/vaccination.dart';
import 'package:pawfolio/providers/current_user_id_provider.dart';
import 'package:pawfolio/providers/vaccinations_provider.dart';
import 'package:pawfolio/repositories/vaccinations_repository.dart';

class _CountingVaccinationsRepository implements VaccinationsRepository {
  int fetchForPetCallCount = 0;

  @override
  Future<List<Vaccination>> fetchForPet(String petId) async {
    fetchForPetCallCount++;
    return [];
  }

  @override
  Future<void> create(Vaccination vaccination) async {}

  @override
  Future<void> update(Vaccination vaccination) async {}
}

void main() {
  test('vaccinationsProvider(petId) refetches whenever the current user id changes', () async {
    final userIdController = StreamController<String?>();
    addTearDown(userIdController.close);
    final repo = _CountingVaccinationsRepository();

    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => userIdController.stream),
        vaccinationsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    container.listen(vaccinationsProvider('p1'), (previous, next) {});

    await container.read(vaccinationsProvider('p1').future);
    expect(repo.fetchForPetCallCount, 1);

    userIdController.add('user-a');
    await pumpEventQueue();
    await container.read(vaccinationsProvider('p1').future);
    expect(repo.fetchForPetCallCount, 2);
  });
}
