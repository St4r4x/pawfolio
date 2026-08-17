import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/pet.dart';
import '../../providers/pets_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        onRefresh: () => ref.refresh(petsProvider.future),
        child: petsAsync.when(
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
              ? ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Aucun animal pour le moment')),
                    ),
                  ],
                )
              : ListView.builder(
                  itemCount: pets.length,
                  itemBuilder: (context, index) {
                    final pet = pets[index];
                    return ListTile(
                      title: Text(pet.name),
                      subtitle: Text(pet.species),
                      onTap: () => context.push('/pets/${pet.id}'),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPetSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddPetSheet(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String species = 'dog';
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
                    await ref.read(petsRepositoryProvider).create(
                          Pet(id: '', ownerId: '', name: nameController.text.trim(), species: species),
                        );
                    ref.invalidate(petsProvider);
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
