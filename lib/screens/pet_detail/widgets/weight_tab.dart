import 'package:flutter/material.dart';

class WeightTab extends StatelessWidget {
  const WeightTab({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context) => const Center(child: Text('Poids'));
}
