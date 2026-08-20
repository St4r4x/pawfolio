import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/breeds.dart';
import '../../date_only.dart';
import '../../models/pet.dart';
import '../../motion.dart';
import '../../notifications/reminder_scheduler.dart';
import '../../providers/pet_photo_uploader_provider.dart';
import '../../providers/pets_provider.dart';
import '../../providers/reminders_provider.dart';
import '../../reminders.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pet_avatar.dart';
import '../../widgets/species_dropdown.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(upcomingRemindersProvider, (previous, next) {
      next.whenData(
        (items) => ref.read(reminderSchedulerProvider).scheduleAll(items),
      );
    });
    final upcomingAsync = ref.watch(upcomingRemindersProvider);
    final petsAsync = ref.watch(petsProvider);

    final earliestReminderByPet = <String, DueItem>{};
    upcomingAsync.whenData((items) {
      for (final item in items) {
        earliestReminderByPet.putIfAbsent(item.petId, () => item);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.pets),
            SizedBox(width: 8),
            Text('Pawfolio'),
          ],
        ),
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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'À venir',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextButton(
                                  onPressed: () => context.push('/reminders'),
                                  child: const Text('Voir tout'),
                                ),
                              ],
                            ),
                          ),
                          for (final item in items.take(3))
                            ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.circle,
                                size: 12,
                                color: urgencyColor(
                                  reminderUrgency(item.dueDate),
                                ),
                              ),
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
                    TextButton(
                      onPressed: () => ref.invalidate(petsProvider),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
              data: (pets) => pets.isEmpty
                  ? EmptyState(
                      illustration: SvgPicture.asset(
                        'assets/illustrations/no_pets.svg',
                        colorFilter: const ColorFilter.mode(
                          AppColors.muted,
                          BlendMode.srcIn,
                        ),
                      ),
                      title: 'Aucun animal pour le moment',
                      subtitle: 'Ajoute ton premier animal avec le bouton + ci-dessous.',
                    )
                  : Column(
                      children: AnimateList(
                        interval: AppMotion.durationOrInstant(
                          context,
                          AppMotion.staggerStep,
                        ),
                        effects: [
                          FadeEffect(
                            duration: AppMotion.durationOrInstant(
                              context,
                              AppMotion.microDuration,
                            ),
                            curve: AppMotion.entranceCurve,
                          ),
                          SlideEffect(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                            duration: AppMotion.durationOrInstant(
                              context,
                              AppMotion.microDuration,
                            ),
                            curve: AppMotion.entranceCurve,
                          ),
                        ],
                        children: [
                          for (final pet in pets)
                            Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              elevation: 2,
                              clipBehavior: Clip.antiAlias,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: speciesAccentColor(pet.species),
                                      width: 4,
                                    ),
                                  ),
                                ),
                                child: ListTile(
                                  leading: PetAvatar(
                                    species: pet.species,
                                    photoUrl: pet.photoUrl,
                                  ),
                                  title: Text(pet.name),
                                  subtitle: Text(pet.species),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (earliestReminderByPet[pet.id] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 4,
                                          ),
                                          child: Chip(
                                            label: Text(
                                              earliestReminderByPet[pet.id]!
                                                  .label,
                                            ),
                                            backgroundColor: urgencyColor(
                                              reminderUrgency(
                                                earliestReminderByPet[pet.id]!
                                                    .dueDate,
                                              ),
                                            ),
                                            labelStyle: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _showAddPetSheet(
                                          context,
                                          ref,
                                          existing: pet,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () => context.push('/pets/${pet.id}'),
                                ),
                              ),
                            ),
                        ],
                      ),
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

  Future<String?> _showPhotoSourceSheet(
    BuildContext context, {
    required bool hasPhoto,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.of(sheetContext).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.of(sheetContext).pop('gallery'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.pets, color: AppColors.muted),
                title: const Text('Icône par défaut'),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddPetSheet(BuildContext context, WidgetRef ref, {Pet? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final breedController = TextEditingController(text: existing?.breed ?? '');
    final breedFocusNode = FocusNode();
    String species = existing?.species ?? 'dog';
    DateTime? birthDate = existing?.birthDate;
    String? photoUrl = existing?.photoUrl;
    bool uploadingPhoto = false;
    const avatarRadius = 32.0;
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
          builder: (sheetContext, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PetAvatar(
                  species: species,
                  radius: avatarRadius,
                  photoUrl: photoUrl,
                ),
                TextButton.icon(
                  onPressed: uploadingPhoto
                      ? null
                      : () async {
                          final choice = await _showPhotoSourceSheet(
                            sheetContext,
                            hasPhoto: photoUrl != null,
                          );
                          if (choice == null) return;
                          if (choice == 'delete') {
                            setState(() => photoUrl = null);
                            return;
                          }
                          final source = choice == 'camera'
                              ? ImageSource.camera
                              : ImageSource.gallery;
                          setState(() => uploadingPhoto = true);
                          try {
                            final url = await ref.read(
                              petPhotoUploaderProvider,
                            )(source);
                            if (url != null) {
                              setState(() => photoUrl = url);
                            }
                          } catch (error) {
                            if (sheetContext.mounted) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(content: Text('Erreur photo: $error')),
                              );
                            }
                          } finally {
                            setState(() => uploadingPhoto = false);
                          }
                        },
                  icon: uploadingPhoto
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt, size: 18),
                  label: Text(
                    photoUrl == null ? 'Ajouter une photo' : 'Changer la photo',
                  ),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                SpeciesDropdown(
                  value: species,
                  onChanged: (value) => setState(() => species = value),
                ),
                Autocomplete<String>(
                  textEditingController: breedController,
                  focusNode: breedFocusNode,
                  optionsBuilder: (value) {
                    final options = breedsForSpecies(species);
                    final query = value.text.toLowerCase();
                    if (query.isEmpty) return options;
                    return options.where(
                      (breed) => breed.toLowerCase().contains(query),
                    );
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(labelText: 'Race'),
                        );
                      },
                ),
                ListTile(
                  title: Text(
                    birthDate == null
                        ? 'Date de naissance (facultatif)'
                        : 'Né(e) le ${dateOnly(birthDate!)}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: birthDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => birthDate = picked);
                  },
                ),
                FilledButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;
                    final trimmedBreed = breedController.text.trim();
                    final breed = trimmedBreed.isEmpty ? null : trimmedBreed;
                    try {
                      if (existing == null) {
                        await ref
                            .read(petsRepositoryProvider)
                            .create(
                              Pet(
                                id: '',
                                ownerId: '',
                                name: nameController.text.trim(),
                                species: species,
                                breed: breed,
                                birthDate: birthDate,
                                photoUrl: photoUrl,
                              ),
                            );
                      } else {
                        await ref
                            .read(petsRepositoryProvider)
                            .update(
                              Pet(
                                id: existing.id,
                                ownerId: existing.ownerId,
                                name: nameController.text.trim(),
                                species: species,
                                breed: breed,
                                birthDate: birthDate,
                                photoUrl: photoUrl,
                              ),
                            );
                      }
                      ref.invalidate(petsProvider);
                      if (sheetContext.mounted)
                        Navigator.of(sheetContext).pop();
                    } catch (error) {
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          SnackBar(content: Text('Erreur: $error')),
                        );
                      }
                    }
                  },
                  child: Text(existing == null ? 'Ajouter' : 'Enregistrer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
