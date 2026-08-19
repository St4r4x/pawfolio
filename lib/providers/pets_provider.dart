import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pet.dart';
import '../repositories/pets_repository.dart';
import 'current_user_id_provider.dart';

final petsRepositoryProvider = Provider<PetsRepository>(
  (ref) => SupabasePetsRepository(Supabase.instance.client),
);

final petsProvider = FutureProvider<List<Pet>>((ref) {
  // Watched only to invalidate this cache when the signed-in user changes;
  // the id itself isn't used (see current_user_id_provider.dart).
  ref.watch(currentUserIdProvider);
  return ref.watch(petsRepositoryProvider).fetchAll();
});
