import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/treatment.dart';
import '../repositories/treatments_repository.dart';
import 'current_user_id_provider.dart';

final treatmentsRepositoryProvider = Provider(
  (ref) => TreatmentsRepository(Supabase.instance.client),
);

final treatmentsProvider = FutureProvider.family<List<Treatment>, String>((
  ref,
  petId,
) {
  // Watched only to invalidate this cache when the signed-in user changes;
  // the id itself isn't used (see current_user_id_provider.dart).
  ref.watch(currentUserIdProvider);
  return ref.watch(treatmentsRepositoryProvider).fetchForPet(petId);
});
