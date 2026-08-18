import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../date_only.dart';
import '../../models/pet.dart';
import '../../notifications/reminder_scheduler.dart';
import '../../providers/pets_provider.dart';
import '../../providers/reminders_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(upcomingRemindersProvider, (previous, next) {
      next.whenData((items) => ref.read(reminderSchedulerProvider).scheduleAll(items));
    });
    final upcomingAsync = ref.watch(upcomingRemindersProvider);
    final petsAsync = ref.watch(petsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pawfolio'),
        actions: [
          IconButton(
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(petsProvider);
          ref.invalidate(upcomingRemindersProvider);
        },
        child: ListView(
          children: [
            upcomingAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (items) => items.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('À venir', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          for (final item in items.take(3))
                            ListTile(
                              dense: true,
                              title: Text('${item.petName} · ${item.label}'),
                              subtitle: Text(dateOnly(item.dueDate)),
                            ),
                          const Divider(),
                        ],
                      ),
                    ),
            ),
            petsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Erreur: $error'),
                    TextButton(onPressed: () => ref.invalidate(petsProvider), child: const Text('Réessayer')),
                  ],
                ),
              ),
              data: (pets) => pets.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Aucun animal pour le moment')),
                    )
                  : Column(
                      children: [
                        for (final pet in pets)
                          ListTile(
                            title: Text(pet.name),
                            subtitle: Text(pet.species),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showAddPetSheet(context, ref, existing: pet),
                            ),
                            onTap: () => context.push('/pets/${pet.id}'),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPetSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddPetSheet(BuildContext context, WidgetRef ref, {Pet? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    String species = existing?.species ?? 'dog';
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
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom')),
              DropdownButton<String>(
                value: species,
                items: const [
                  DropdownMenuItem(value: 'dog', child: Text('Chien')),
                  DropdownMenuItem(value: 'cat', child: Text('Chat')),
                  DropdownMenuItem(value: 'other', child: Text('Autre')),
                ],
                onChanged: (value) => setState(() => species = value!),
              ),
              FilledButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;
                  try {
                    if (existing == null) {
                      await ref.read(petsRepositoryProvider).create(
                            Pet(id: '', ownerId: '', name: nameController.text.trim(), species: species),
                          );
                    } else {
                      await ref.read(petsRepositoryProvider).update(
                            Pet(
                              id: existing.id,
                              ownerId: existing.ownerId,
                              name: nameController.text.trim(),
                              species: species,
                              breed: existing.breed,
                              birthDate: existing.birthDate,
                            ),
                          );
                    }
                    ref.invalidate(petsProvider);
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
