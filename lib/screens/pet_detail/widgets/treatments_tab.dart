import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../date_only.dart';
import '../../../models/treatment.dart';
import '../../../providers/treatments_provider.dart';
import '../../../theme.dart';
import '../../../widgets/empty_state.dart';

class TreatmentsTab extends ConsumerWidget {
  const TreatmentsTab({required this.petId, super.key});

  final String petId;

  static const _typeLabels = {
    'dewormer': 'Vermifuge',
    'antiparasitic': 'Antiparasitaire',
    'other': 'Autre',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treatmentsAsync = ref.watch(treatmentsProvider(petId));

    return Scaffold(
      body: treatmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur: $error'),
              TextButton(
                onPressed: () => ref.invalidate(treatmentsProvider(petId)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (treatments) => treatments.isEmpty
            ? EmptyState(
                illustration: SvgPicture.asset(
                  'assets/illustrations/no_treatments.svg',
                  colorFilter: const ColorFilter.mode(AppColors.muted, BlendMode.srcIn),
                ),
                title: 'Aucun traitement enregistré',
                subtitle: 'Ajoute le premier traitement avec le bouton + ci-dessous.',
              )
            : ListView.builder(
                itemCount: treatments.length,
                itemBuilder: (context, index) {
                  final treatment = treatments[index];
                  final nextDue = treatment.nextDueDate;
                  return ListTile(
                    title: Text(treatment.name),
                    subtitle: Text(
                      '${_typeLabels[treatment.type]} · fait le ${dateOnly(treatment.dateGiven)}'
                      '${nextDue != null ? ' · rappel le ${dateOnly(nextDue)}' : ''}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showAddTreatmentSheet(context, ref, existing: treatment),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTreatmentSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTreatmentSheet(BuildContext context, WidgetRef ref, {Treatment? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    String type = existing?.type ?? 'dewormer';
    DateTime dateGiven = existing?.dateGiven ?? DateTime.now();
    DateTime? nextDueDate = existing?.nextDueDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (sheetContext, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom du traitement'),
              ),
              DropdownButton<String>(
                value: type,
                items: _typeLabels.entries
                    .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                    .toList(),
                onChanged: (value) => setState(() => type = value!),
              ),
              ListTile(
                title: Text('Donné le ${dateOnly(dateGiven)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: dateGiven,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => dateGiven = picked);
                },
              ),
              ListTile(
                title: Text(nextDueDate == null ? 'Pas de rappel' : 'Rappel le ${dateOnly(nextDueDate!)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: nextDueDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => nextDueDate = picked);
                },
              ),
              FilledButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;
                  try {
                    if (existing == null) {
                      await ref.read(treatmentsRepositoryProvider).create(Treatment(
                            id: '',
                            petId: petId,
                            type: type,
                            name: nameController.text.trim(),
                            dateGiven: dateGiven,
                            nextDueDate: nextDueDate,
                          ));
                    } else {
                      await ref.read(treatmentsRepositoryProvider).update(Treatment(
                            id: existing.id,
                            petId: petId,
                            type: type,
                            name: nameController.text.trim(),
                            dateGiven: dateGiven,
                            nextDueDate: nextDueDate,
                            notes: existing.notes,
                          ));
                    }
                    ref.invalidate(treatmentsProvider(petId));
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
                child: Text(existing == null ? 'Ajouter' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
