import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../date_only.dart';
import '../../export/pet_exporter.dart';
import '../../models/pet.dart';
import '../../providers/pets_provider.dart';
import '../../theme.dart';
import '../../widgets/pet_avatar.dart';
import 'widgets/treatments_tab.dart';
import 'widgets/vaccinations_tab.dart';
import 'widgets/vet_visits_tab.dart';
import 'widgets/weight_tab.dart';

const _exportOptions = [
  (icon: Icons.picture_as_pdf, label: 'Exporter en PDF', format: 'pdf'),
  (icon: Icons.table_chart, label: 'Exporter en CSV', format: 'csv'),
  (icon: Icons.data_object, label: 'Exporter en JSON', format: 'json'),
];

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
                    if (pet.breed != null) Text(pet.breed!),
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
