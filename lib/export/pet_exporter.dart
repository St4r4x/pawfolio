import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models/pet.dart';
import '../providers/treatments_provider.dart';
import '../providers/vaccinations_provider.dart';
import '../providers/vet_visits_provider.dart';
import '../providers/weight_entries_provider.dart';
import 'pet_csv_export.dart';
import 'pet_export_data.dart';
import 'pet_json_export.dart';
import 'pet_pdf_export.dart';

/// Fetches one pet's records, builds the requested format ('pdf'/'csv', else
/// json), and hands it to the platform's share sheet.
typedef PetExporter = Future<void> Function(Pet pet, String format);

final petExporterProvider = Provider<PetExporter>((ref) => (pet, format) => _exportPet(ref, pet, format));

Future<void> _exportPet(Ref ref, Pet pet, String format) async {
  final data = await _fetchExportData(ref, pet);
  final XFile file;
  switch (format) {
    case 'pdf':
      file = XFile.fromData(await buildPetExportPdf(data), mimeType: 'application/pdf', name: '${pet.name}.pdf');
    case 'csv':
      file = _textFile(buildPetExportCsv(data), 'text/csv', '${pet.name}.csv');
    default:
      file = _textFile(buildPetExportJson(data), 'application/json', '${pet.name}.json');
  }
  await SharePlus.instance.share(ShareParams(files: [file]));
}

XFile _textFile(String content, String mimeType, String name) =>
    XFile.fromData(Uint8List.fromList(utf8.encode(content)), mimeType: mimeType, name: name);

Future<PetExportData> _fetchExportData(Ref ref, Pet pet) async {
  final vaccinations = ref.read(vaccinationsProvider(pet.id).future);
  final treatments = ref.read(treatmentsProvider(pet.id).future);
  final weightEntries = ref.read(weightEntriesProvider(pet.id).future);
  final vetVisits = ref.read(vetVisitsProvider(pet.id).future);
  return PetExportData(
    pet: pet,
    vaccinations: await vaccinations,
    treatments: await treatments,
    weightEntries: await weightEntries,
    vetVisits: await vetVisits,
  );
}
