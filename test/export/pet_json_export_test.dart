import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/export/pet_export_data.dart';
import 'package:pawfolio/export/pet_json_export.dart';
import 'package:pawfolio/models/pet.dart';
import 'package:pawfolio/models/treatment.dart';
import 'package:pawfolio/models/vaccination.dart';
import 'package:pawfolio/models/vet_visit.dart';
import 'package:pawfolio/models/weight_entry.dart';

void main() {
  test('buildPetExportJson serializes every section', () {
    final data = PetExportData(
      pet: Pet(
        id: 'p1',
        ownerId: 'u1',
        name: 'Rex',
        species: 'dog',
        breed: 'Labrador',
        birthDate: DateTime(2020, 5, 1),
      ),
      vaccinations: [
        Vaccination(id: 'v1', petId: 'p1', name: 'Rage', dateAdministered: DateTime(2024, 4, 10)),
      ],
      treatments: [
        Treatment(id: 't1', petId: 'p1', type: 'dewormer', name: 'Vermifuge', dateGiven: DateTime(2024, 5, 1)),
      ],
      weightEntries: [WeightEntry(id: 'w1', petId: 'p1', weightKg: 12.5, recordedAt: DateTime(2024, 6, 1))],
      vetVisits: [VetVisit(id: 'vv1', petId: 'p1', visitDate: DateTime(2024, 7, 1), reason: 'Contrôle annuel')],
    );

    final json = jsonDecode(buildPetExportJson(data)) as Map<String, dynamic>;

    expect(json['pet']['name'], 'Rex');
    expect(json['pet']['breed'], 'Labrador');
    expect(json['pet']['birthDate'], '2020-05-01');
    expect(json['vaccinations'], hasLength(1));
    expect(json['vaccinations'][0]['name'], 'Rage');
    expect(json['treatments'][0]['name'], 'Vermifuge');
    expect(json['weightEntries'][0]['weightKg'], 12.5);
    expect(json['vetVisits'][0]['reason'], 'Contrôle annuel');
  });

  test('buildPetExportJson omits null optional pet fields', () {
    final data = PetExportData(
      pet: const Pet(id: 'p1', ownerId: 'u1', name: 'Mia', species: 'cat'),
      vaccinations: const [],
      treatments: const [],
      weightEntries: const [],
      vetVisits: const [],
    );

    final json = jsonDecode(buildPetExportJson(data)) as Map<String, dynamic>;

    expect(json['pet'].containsKey('breed'), isFalse);
    expect(json['pet'].containsKey('birthDate'), isFalse);
  });
}
