import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/breed_predispositions.dart';
import '../../date_only.dart';
import '../../export/pet_exporter.dart';
import '../../models/pet.dart';
import '../../providers/pets_provider.dart';
import '../../theme.dart';
import '../../widgets/pet_avatar.dart';
import '../../widgets/record_leading_icon.dart';
import 'widgets/treatments_tab.dart';
import 'widgets/vaccinations_tab.dart';
import 'widgets/vet_visits_tab.dart';
import 'widgets/weight_tab.dart';

const _exportOptions = [
  (icon: Icons.picture_as_pdf, label: 'Exporter en PDF', format: 'pdf'),
  (icon: Icons.table_chart, label: 'Exporter en CSV', format: 'csv'),
  (icon: Icons.data_object, label: 'Exporter en JSON', format: 'json'),
];

const _predispositionsDisclaimer =
    'Informations générales sur la race, à titre indicatif — '
    'ne remplacent pas l\'avis d\'un vétérinaire.';

Pet? _findPet(List<Pet> pets, String petId) {
  for (final pet in pets) {
    if (pet.id == petId) return pet;
  }
  return null;
}

class PetDetailScreen extends ConsumerWidget {
  const PetDetailScreen({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petsAsync = ref.watch(petsProvider);
    final pet = petsAsync.when(
      loading: () => null,
      error: (_, __) => null,
      data: (pets) => _findPet(pets, petId),
    );

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pet != null) ...[
                PetAvatar(species: pet.species, radius: 16, photoUrl: pet.photoUrl),
                const SizedBox(width: 8),
              ],
              Text(pet?.name ?? 'Animal'),
            ],
          ),
          actions: [
            if (pet != null)
              IconButton(
                icon: const Icon(Icons.ios_share),
                tooltip: 'Exporter',
                onPressed: () => _showExportSheet(context, ref, pet),
              ),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Vaccins'),
              Tab(text: 'Poids'),
              Tab(text: 'Traitements'),
              Tab(text: 'RDV'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (pet != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(speciesLabel(pet.species)),
                    if (pet.breed != null) _BreedRow(breed: pet.breed!),
                    if (pet.birthDate != null) Text('Né(e) le ${dateOnly(pet.birthDate!)}'),
                  ],
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  VaccinationsTab(petId: petId),
                  WeightTab(petId: petId),
                  TreatmentsTab(petId: petId),
                  VetVisitsTab(petId: petId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreedRow extends StatelessWidget {
  const _BreedRow({required this.breed});

  final String breed;

  @override
  Widget build(BuildContext context) {
    final predispositions = predispositionsForBreed(breed);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(breed),
        if (predispositions.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Prédispositions de la race',
            visualDensity: VisualDensity.compact,
            onPressed: () => _showPredispositionsSheet(context, breed, predispositions),
          ),
      ],
    );
  }
}

void _showPredispositionsSheet(BuildContext context, String breed, List<BreedPredisposition> predispositions) {
  showModalBottomSheet(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Text(breed, style: Theme.of(sheetContext).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final predisposition in predispositions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const RecordLeadingIcon(
                icon: Icons.health_and_safety_outlined,
                color: AppColors.warningDueSoon,
              ),
              title: Text(predisposition.condition),
              subtitle: Text(predisposition.note),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _predispositionsDisclaimer,
              style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showExportSheet(BuildContext context, WidgetRef ref, Pet pet) {
  showModalBottomSheet(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in _exportOptions)
            ListTile(
              leading: Icon(option.icon),
              title: Text(option.label),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                try {
                  await ref.read(petExporterProvider)(pet, option.format);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur export: $error')));
                  }
                }
              },
            ),
        ],
      ),
    ),
  );
}
