import 'package:flutter/material.dart';

import 'widgets/treatments_tab.dart';
import 'widgets/vaccinations_tab.dart';
import 'widgets/vet_visits_tab.dart';
import 'widgets/weight_tab.dart';

class PetDetailScreen extends StatelessWidget {
  const PetDetailScreen({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Animal'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Vaccins'),
              Tab(text: 'Poids'),
              Tab(text: 'Traitements'),
              Tab(text: 'RDV'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            VaccinationsTab(petId: petId),
            WeightTab(petId: petId),
            TreatmentsTab(petId: petId),
            VetVisitsTab(petId: petId),
          ],
        ),
      ),
    );
  }
}
