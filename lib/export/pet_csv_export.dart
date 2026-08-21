import 'package:csv/csv.dart';

import '../date_only.dart';
import 'pet_export_data.dart';

/// One flat table combining every category, since a pet's records don't
/// share a single column shape.
String buildPetExportCsv(PetExportData data) {
  final rows = <List<String>>[
    ['catégorie', 'libellé', 'date', 'rappel', 'notes'],
    for (final v in data.vaccinations) ['Vaccin', ...vaccinationFields(v)],
    for (final t in data.treatments) ['Traitement', ...treatmentFields(t)],
    for (final w in data.weightEntries) ['Poids', '${w.weightKg} kg', dateOnly(w.recordedAt), '', ''],
    for (final v in data.vetVisits) ['RDV vétérinaire', v.reason, dateOnly(v.visitDate), '', v.notes ?? ''],
  ];
  return Csv().encode(rows);
}
