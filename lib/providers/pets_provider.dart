import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pet.dart';
import '../repositories/pets_repository.dart';

final petsRepositoryProvider =
    Provider<PetsRepository>((ref) => SupabasePetsRepository(Supabase.instance.client));

final petsProvider = FutureProvider<List<Pet>>((ref) {
  return ref.watch(petsRepositoryProvider).fetchAll();
});
