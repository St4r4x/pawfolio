import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/export/pet_csv_export.dart';
import 'package:pawfolio/export/pet_export_data.dart';
import 'package:pawfolio/models/pet.dart';
import 'package:pawfolio/models/treatment.dart';
import 'package:pawfolio/models/vaccination.dart';
import 'package:pawfolio/models/vet_visit.dart';
import 'package:pawfolio/models/weight_entry.dart';

void main() {
  test('buildPetExportCsv combines every category into one flat table', () {
    final data = PetExportData(
      pet: const Pet(id: 'p1', ownerId: 'u1', name: 'Rex', species: 'dog'),
      vaccinations: [
        Vaccination(id: 'v1', petId: 'p1', name: 'Rage', dateAdministered: DateTime(2024, 4, 10)),
      ],
      treatments: [
        Treatment(id: 't1', petId: 'p1', type: 'dewormer', name: 'Vermifuge', dateGiven: DateTime(2024, 5, 1)),
      ],
      weightEntries: [WeightEntry(id: 'w1', petId: 'p1', weightKg: 12.5, recordedAt: DateTime(2024, 6, 1))],
      vetVisits: [
        VetVisit(
          id: 'vv1',
          petId: 'p1',
          visitDate: DateTime(2024, 7, 1),
          reason: 'Contrôle, annuel',
          notes: 'Tout va bien',
        ),
      ],
    );

    final rows = Csv().decode(buildPetExportCsv(data));

    expect(rows, hasLength(5));
    expect(rows[0], equals(['catégorie', 'libellé', 'date', 'rappel', 'notes']));
    expect(rows[1], equals(['Vaccin', 'Rage', '2024-04-10', '', '']));
    expect(rows[2], equals(['Traitement', 'Vermifuge', '2024-05-01', '', '']));
    expect(rows[3], equals(['Poids', '12.5 kg', '2024-06-01', '', '']));
    // A value containing a comma round-trips correctly through CSV escaping.
    expect(rows[4], equals(['RDV vétérinaire', 'Contrôle, annuel', '2024-07-01', '', 'Tout va bien']));
  });
}
