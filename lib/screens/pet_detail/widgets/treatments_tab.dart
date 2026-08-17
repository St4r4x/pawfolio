import 'package:flutter/material.dart';

class TreatmentsTab extends StatelessWidget {
  const TreatmentsTab({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context) => const Center(child: Text('Traitements'));
}
