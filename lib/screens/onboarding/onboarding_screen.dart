import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth_error_message.dart';
import '../../models/pet.dart';
import '../../providers/pets_provider.dart';
import '../../widgets/species_dropdown.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  final _nameController = TextEditingController();
  final _petNameController = TextEditingController();
  String _species = 'dog';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _petNameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final firstName = _nameController.text.trim();
    if (firstName.isNotEmpty) {
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'first_name': firstName}),
        );
      } catch (_) {
        // ponytail: first name is a nice-to-have, not worth blocking onboarding over.
      }
    }
    if (mounted) setState(() => _step = 1);
  }

  Future<void> _createPet() async {
    final name = _petNameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await ref
          .read(petsRepositoryProvider)
          .create(Pet(id: '', ownerId: '', name: name, species: _species));
      ref.invalidate(petsProvider);
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _step == 0
                  ? _buildNameStep(context)
                  : _buildPetStep(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameStep(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Comment tu t'appelles ?",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text('Facultatif — tu peux le renseigner plus tard.'),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Prénom'),
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _continue, child: const Text('Continuer')),
      ],
    );
  }

  Widget _buildPetStep(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Ajoute ton premier animal',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _petNameController,
          decoration: const InputDecoration(labelText: 'Nom'),
        ),
        const SizedBox(height: 12),
        SpeciesDropdown(
          value: _species,
          onChanged: (value) => setState(() => _species = value),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _loading ? null : _createPet,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Ajouter'),
        ),
        TextButton(
          onPressed: () => context.go('/'),
          child: const Text('Plus tard'),
        ),
      ],
    );
  }
}
