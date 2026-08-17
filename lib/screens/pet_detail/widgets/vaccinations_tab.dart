import 'package:flutter/material.dart';

class VaccinationsTab extends StatelessWidget {
  const VaccinationsTab({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context) => const Center(child: Text('Vaccins'));
}
