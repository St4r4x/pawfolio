import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../date_only.dart';
import '../models/pet.dart';
import 'pet_export_data.dart';

// ponytail: default Helvetica (WinAnsi encoding) covers French accents fine;
// embed a Unicode TTF only if non-Latin-1 characters are ever needed.
Future<Uint8List> buildPetExportPdf(PetExportData data) {
  final pet = data.pet;
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Header(text: pet.name),
        pw.Text(speciesLabel(pet.species)),
        if (pet.breed != null) pw.Text(pet.breed!),
        if (pet.birthDate != null) pw.Text('Né(e) le ${dateOnly(pet.birthDate!)}'),
        _section(
          'Vaccinations',
          ['Nom', 'Fait le', 'Rappel', 'Notes'],
          [for (final v in data.vaccinations) vaccinationFields(v)],
        ),
        _section(
          'Traitements',
          ['Nom', 'Donné le', 'Rappel', 'Notes'],
          [for (final t in data.treatments) treatmentFields(t)],
        ),
        _section(
          'Poids',
          ['Poids', 'Le'],
          [for (final w in data.weightEntries) ['${w.weightKg} kg', dateOnly(w.recordedAt)]],
        ),
        _section(
          'Rendez-vous vétérinaires',
          ['Motif', 'Le', 'Notes'],
          [for (final v in data.vetVisits) [v.reason, dateOnly(v.visitDate), v.notes ?? '']],
        ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _section(String title, List<String> headers, List<List<String>> rows) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 16),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
        pw.SizedBox(height: 4),
        rows.isEmpty
            ? pw.Text('Aucune donnée.')
            : pw.TableHelper.fromTextArray(
                headers: headers,
                data: rows,
                cellStyle: const pw.TextStyle(fontSize: 10),
              ),
      ],
    ),
  );
}
