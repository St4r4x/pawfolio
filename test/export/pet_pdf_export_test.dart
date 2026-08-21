import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/export/pet_export_data.dart';
import 'package:pawfolio/export/pet_pdf_export.dart';
import 'package:pawfolio/models/pet.dart';
import 'package:pawfolio/models/vaccination.dart';

void main() {
  test('buildPetExportPdf produces a non-empty PDF for a pet with and without records', () async {
    final withRecords = PetExportData(
      pet: const Pet(id: 'p1', ownerId: 'u1', name: 'Rex', species: 'dog', breed: 'Labrador'),
      vaccinations: [
        Vaccination(id: 'v1', petId: 'p1', name: 'Rage', dateAdministered: DateTime(2024, 4, 10)),
      ],
      treatments: const [],
      weightEntries: const [],
      vetVisits: const [],
    );
    final empty = PetExportData(
      pet: const Pet(id: 'p2', ownerId: 'u1', name: 'Mia', species: 'cat'),
      vaccinations: const [],
      treatments: const [],
      weightEntries: const [],
      vetVisits: const [],
    );

    final withRecordsBytes = await buildPetExportPdf(withRecords);
    final emptyBytes = await buildPetExportPdf(empty);

    // %PDF is the standard file signature for a valid PDF document.
    expect(String.fromCharCodes(withRecordsBytes.take(4)), '%PDF');
    expect(String.fromCharCodes(emptyBytes.take(4)), '%PDF');
  });
}
