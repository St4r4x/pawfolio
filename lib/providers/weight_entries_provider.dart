import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/weight_entry.dart';
import '../repositories/weight_entries_repository.dart';
import 'current_user_id_provider.dart';

final weightEntriesRepositoryProvider = Provider(
  (ref) => WeightEntriesRepository(Supabase.instance.client),
);

final weightEntriesProvider = FutureProvider.family<List<WeightEntry>, String>((
  ref,
  petId,
) {
  // Watched only to invalidate this cache when the signed-in user changes;
  // the id itself isn't used (see current_user_id_provider.dart).
  ref.watch(currentUserIdProvider);
  return ref.watch(weightEntriesRepositoryProvider).fetchForPet(petId);
});
