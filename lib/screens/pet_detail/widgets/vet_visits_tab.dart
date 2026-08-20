import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../date_only.dart';
import '../../../models/vet_visit.dart';
import '../../../providers/vet_visits_provider.dart';
import '../../../theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/record_leading_icon.dart';

class VetVisitsTab extends ConsumerWidget {
  const VetVisitsTab({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(vetVisitsProvider(petId));

    return Scaffold(
      body: visitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur: $error'),
              TextButton(
                onPressed: () => ref.invalidate(vetVisitsProvider(petId)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (visits) => visits.isEmpty
            ? EmptyState(
                illustration: SvgPicture.asset(
                  'assets/illustrations/no_vet_visits.svg',
                  colorFilter: const ColorFilter.mode(
                    AppColors.muted,
                    BlendMode.srcIn,
                  ),
                ),
                title: 'Aucun rendez-vous enregistré',
                subtitle: 'Ajoute le premier rendez-vous avec le bouton + ci-dessous.',
              )
            : ListView.builder(
                itemCount: visits.length,
                itemBuilder: (context, index) {
                  final visit = visits[index];
                  final nextVisit = visit.nextVisitDate;
                  return ListTile(
                    leading: const RecordLeadingIcon(
                      icon: Icons.local_hospital,
                      color: AppColors.primary,
                    ),
                    title: Text(visit.reason),
                    subtitle: Text(
                      'Le ${dateOnly(visit.visitDate)}'
                      '${nextVisit != null ? ' · prochain RDV le ${dateOnly(nextVisit)}' : ''}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () =>
                          _showAddVisitSheet(context, ref, existing: visit),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddVisitSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddVisitSheet(
    BuildContext context,
    WidgetRef ref, {
    VetVisit? existing,
  }) {
    final reasonController = TextEditingController(
      text: existing?.reason ?? '',
    );
    DateTime visitDate = existing?.visitDate ?? DateTime.now();
    DateTime? nextVisitDate = existing?.nextVisitDate;

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
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Motif'),
              ),
              ListTile(
                title: Text('Le ${dateOnly(visitDate)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: visitDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => visitDate = picked);
                },
              ),
              ListTile(
                title: Text(
                  nextVisitDate == null
                      ? 'Pas de prochain RDV'
                      : 'Prochain RDV le ${dateOnly(nextVisitDate!)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: nextVisitDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => nextVisitDate = picked);
                },
              ),
              FilledButton(
                onPressed: () async {
                  if (reasonController.text.trim().isEmpty) return;
                  try {
                    if (existing == null) {
                      await ref
                          .read(vetVisitsRepositoryProvider)
                          .create(
                            VetVisit(
                              id: '',
                              petId: petId,
                              visitDate: visitDate,
                              reason: reasonController.text.trim(),
                              nextVisitDate: nextVisitDate,
                            ),
                          );
                    } else {
                      await ref
                          .read(vetVisitsRepositoryProvider)
                          .update(
                            VetVisit(
                              id: existing.id,
                              petId: petId,
                              visitDate: visitDate,
                              reason: reasonController.text.trim(),
                              nextVisitDate: nextVisitDate,
                              notes: existing.notes,
                            ),
                          );
                    }
                    ref.invalidate(vetVisitsProvider(petId));
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(
                        sheetContext,
                      ).showSnackBar(SnackBar(content: Text('Erreur: $error')));
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
