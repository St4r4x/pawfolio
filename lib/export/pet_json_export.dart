import 'dart:convert';

import '../date_only.dart';
import 'pet_export_data.dart';

String buildPetExportJson(PetExportData data) {
  final pet = data.pet;
  final json = {
    'pet': {
      'name': pet.name,
      'species': pet.species,
      if (pet.breed != null) 'breed': pet.breed,
      if (pet.birthDate != null) 'birthDate': dateOnly(pet.birthDate!),
    },
    'vaccinations': [
      for (final v in data.vaccinations)
        {
          'name': v.name,
          'dateAdministered': dateOnly(v.dateAdministered),
          if (v.nextDueDate != null) 'nextDueDate': dateOnly(v.nextDueDate!),
          if (v.notes != null) 'notes': v.notes,
        },
    ],
    'treatments': [
      for (final t in data.treatments)
        {
          'type': t.type,
          'name': t.name,
          'dateGiven': dateOnly(t.dateGiven),
          if (t.nextDueDate != null) 'nextDueDate': dateOnly(t.nextDueDate!),
          if (t.notes != null) 'notes': t.notes,
        },
    ],
    'weightEntries': [
      for (final w in data.weightEntries) {'weightKg': w.weightKg, 'recordedAt': dateOnly(w.recordedAt)},
    ],
    'vetVisits': [
      for (final v in data.vetVisits)
        {
          'reason': v.reason,
          'visitDate': dateOnly(v.visitDate),
          if (v.notes != null) 'notes': v.notes,
        },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(json);
}
