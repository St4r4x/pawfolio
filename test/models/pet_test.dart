import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/pet.dart';

void main() {
  test('Pet.fromJson parses a full record', () {
    final pet = Pet.fromJson({
      'id': 'p1',
      'owner_id': 'u1',
      'name': 'Rex',
      'species': 'dog',
      'breed': 'Labrador',
      'birth_date': '2020-05-01',
    });
    expect(pet.name, 'Rex');
    expect(pet.species, 'dog');
    expect(pet.breed, 'Labrador');
    expect(pet.birthDate, DateTime(2020, 5, 1));
  });

  test('Pet.fromJson handles null optional fields', () {
    final pet = Pet.fromJson({
      'id': 'p1',
      'owner_id': 'u1',
      'name': 'Mia',
      'species': 'cat',
      'breed': null,
      'birth_date': null,
    });
    expect(pet.breed, isNull);
    expect(pet.birthDate, isNull);
  });

  test('toInsertJson omits null optional fields', () {
    const pet = Pet(id: '', ownerId: '', name: 'Mia', species: 'cat');
    final json = pet.toInsertJson(ownerId: 'u1');
    expect(json.containsKey('breed'), isFalse);
    expect(json.containsKey('birth_date'), isFalse);
    expect(json['name'], 'Mia');
  });
}
