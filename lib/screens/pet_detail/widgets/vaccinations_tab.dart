import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../date_only.dart';
import '../../../models/vaccination.dart';
import '../../../providers/vaccinations_provider.dart';

class VaccinationsTab extends ConsumerWidget {
  const VaccinationsTab({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaccinationsAsync = ref.watch(vaccinationsProvider(petId));

    return Scaffold(
      body: vaccinationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur: $error'),
              TextButton(
                onPressed: () => ref.invalidate(vaccinationsProvider(petId)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (vaccinations) => vaccinations.isEmpty
            ? const Center(child: Text('Aucun vaccin enregistré'))
            : ListView.builder(
                itemCount: vaccinations.length,
                itemBuilder: (context, index) {
                  final vaccination = vaccinations[index];
                  final nextDue = vaccination.nextDueDate;
                  return ListTile(
                    title: Text(vaccination.name),
                    subtitle: Text(
                      'Fait le ${dateOnly(vaccination.dateAdministered)}'
                      '${nextDue != null ? ' · rappel le ${dateOnly(nextDue)}' : ''}',
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddVaccinationSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddVaccinationSheet(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    DateTime dateAdministered = DateTime.now();
    DateTime? nextDueDate;

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
                decoration: const InputDecoration(labelText: 'Nom du vaccin'),
              ),
              ListTile(
                title: Text('Administré le ${dateOnly(dateAdministered)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: dateAdministered,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => dateAdministered = picked);
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
                    await ref.read(vaccinationsRepositoryProvider).create(Vaccination(
                          id: '',
                          petId: petId,
                          name: nameController.text.trim(),
                          dateAdministered: dateAdministered,
                          nextDueDate: nextDueDate,
                        ));
                    ref.invalidate(vaccinationsProvider(petId));
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
                child: const Text('Ajouter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
