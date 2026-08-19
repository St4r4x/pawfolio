import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vet_visit.dart';
import '../repositories/vet_visits_repository.dart';
import 'current_user_id_provider.dart';

final vetVisitsRepositoryProvider = Provider(
  (ref) => VetVisitsRepository(Supabase.instance.client),
);

final vetVisitsProvider = FutureProvider.family<List<VetVisit>, String>((
  ref,
  petId,
) {
  // Watched only to invalidate this cache when the signed-in user changes;
  // the id itself isn't used (see current_user_id_provider.dart).
  ref.watch(currentUserIdProvider);
  return ref.watch(vetVisitsRepositoryProvider).fetchForPet(petId);
});
