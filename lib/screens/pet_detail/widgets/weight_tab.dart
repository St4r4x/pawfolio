import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../date_only.dart';
import '../../../models/weight_entry.dart';
import '../../../providers/weight_entries_provider.dart' show weightEntriesRepositoryProvider, weightEntriesProvider;

class WeightTab extends ConsumerWidget {
  const WeightTab({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(weightEntriesProvider(petId));

    return Scaffold(
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur: $error'),
              TextButton(
                onPressed: () => ref.invalidate(weightEntriesProvider(petId)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (entries) => entries.isEmpty
            ? const Center(child: Text('Aucune pesée enregistrée'))
            : ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    title: Text('${entry.weightKg} kg'),
                    subtitle: Text(dateOnly(entry.recordedAt)),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showAddWeightSheet(context, ref, existing: entry),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddWeightSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddWeightSheet(BuildContext context, WidgetRef ref, {WeightEntry? existing}) {
    final weightController = TextEditingController(text: existing?.weightKg.toString() ?? '');
    DateTime recordedAt = existing?.recordedAt ?? DateTime.now();

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
                controller: weightController,
                decoration: const InputDecoration(labelText: 'Poids (kg)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              ListTile(
                title: Text('Pesée le ${dateOnly(recordedAt)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: recordedAt,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => recordedAt = picked);
                },
              ),
              FilledButton(
                onPressed: () async {
                  final weight = double.tryParse(weightController.text.replaceAll(',', '.'));
                  if (weight == null) return;
                  try {
                    if (existing == null) {
                      await ref.read(weightEntriesRepositoryProvider).create(WeightEntry(
                            id: '',
                            petId: petId,
                            weightKg: weight,
                            recordedAt: recordedAt,
                          ));
                    } else {
                      await ref.read(weightEntriesRepositoryProvider).update(WeightEntry(
                            id: existing.id,
                            petId: petId,
                            weightKg: weight,
                            recordedAt: recordedAt,
                          ));
                    }
                    ref.invalidate(weightEntriesProvider(petId));
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
