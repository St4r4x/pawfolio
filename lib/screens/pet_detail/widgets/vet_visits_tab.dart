import 'package:flutter/material.dart';

class VetVisitsTab extends StatelessWidget {
  const VetVisitsTab({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context) => const Center(child: Text('RDV'));
}
