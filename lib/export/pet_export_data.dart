import '../date_only.dart';
import '../models/pet.dart';
import '../models/treatment.dart';
import '../models/vaccination.dart';
import '../models/vet_visit.dart';
import '../models/weight_entry.dart';

/// Everything needed to export one pet's health record.
class PetExportData {
  const PetExportData({
    required this.pet,
    required this.vaccinations,
    required this.treatments,
    required this.weightEntries,
    required this.vetVisits,
  });

  final Pet pet;
  final List<Vaccination> vaccinations;
  final List<Treatment> treatments;
  final List<WeightEntry> weightEntries;
  final List<VetVisit> vetVisits;
}

/// Shared row shape ([name, date, nextDue, notes]) — vaccinations and
/// treatments look the same in both the CSV and PDF export.
List<String> vaccinationFields(Vaccination v) => [
      v.name,
      dateOnly(v.dateAdministered),
      v.nextDueDate == null ? '' : dateOnly(v.nextDueDate!),
      v.notes ?? '',
    ];

List<String> treatmentFields(Treatment t) => [
      t.name,
      dateOnly(t.dateGiven),
      t.nextDueDate == null ? '' : dateOnly(t.nextDueDate!),
      t.notes ?? '',
    ];
