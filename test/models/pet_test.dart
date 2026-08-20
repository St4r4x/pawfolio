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
      'photo_url': 'https://example.com/rex.jpg',
    });
    expect(pet.name, 'Rex');
    expect(pet.species, 'dog');
    expect(pet.breed, 'Labrador');
    expect(pet.birthDate, DateTime(2020, 5, 1));
    expect(pet.photoUrl, 'https://example.com/rex.jpg');
  });

  test('Pet.fromJson handles null optional fields', () {
    final pet = Pet.fromJson({
      'id': 'p1',
      'owner_id': 'u1',
      'name': 'Mia',
      'species': 'cat',
      'breed': null,
      'birth_date': null,
      'photo_url': null,
    });
    expect(pet.breed, isNull);
    expect(pet.birthDate, isNull);
    expect(pet.photoUrl, isNull);
  });

  test('toInsertJson always sends breed/birth_date/photo_url, even when null', () {
    const pet = Pet(id: '', ownerId: '', name: 'Mia', species: 'cat');
    final json = pet.toInsertJson(ownerId: 'u1');
    expect(json['breed'], isNull);
    expect(json['birth_date'], isNull);
    expect(json['photo_url'], isNull);
    expect(json['name'], 'Mia');
  });

  test('toInsertJson includes photo_url when set', () {
    const pet = Pet(id: '', ownerId: '', name: 'Mia', species: 'cat', photoUrl: 'https://example.com/mia.jpg');
    final json = pet.toInsertJson(ownerId: 'u1');
    expect(json['photo_url'], 'https://example.com/mia.jpg');
  });
}
