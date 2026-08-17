import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/weight_entry.dart';
import '../repositories/weight_entries_repository.dart';

final weightEntriesRepositoryProvider =
    Provider((ref) => WeightEntriesRepository(Supabase.instance.client));

final weightEntriesProvider = FutureProvider.family<List<WeightEntry>, String>((ref, petId) {
  return ref.watch(weightEntriesRepositoryProvider).fetchForPet(petId);
});
