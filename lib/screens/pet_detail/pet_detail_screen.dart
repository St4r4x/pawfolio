import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../date_only.dart';
import '../../models/pet.dart';
import '../../providers/pets_provider.dart';
import '../../theme.dart';
import '../../widgets/pet_avatar.dart';
import 'widgets/treatments_tab.dart';
import 'widgets/vaccinations_tab.dart';
import 'widgets/vet_visits_tab.dart';
import 'widgets/weight_tab.dart';

const _speciesLabels = {'dog': 'Chien', 'cat': 'Chat', 'other': 'Autre'};

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
                PetAvatar(species: pet.species, radius: 16),
                const SizedBox(width: 8),
              ],
              Text(pet?.name ?? 'Animal'),
            ],
          ),
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
                    Text(_speciesLabels[pet.species] ?? pet.species),
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
