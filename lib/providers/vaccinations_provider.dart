import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vaccination.dart';
import '../repositories/vaccinations_repository.dart';
import 'current_user_id_provider.dart';

final vaccinationsRepositoryProvider = Provider<VaccinationsRepository>(
  (ref) => SupabaseVaccinationsRepository(Supabase.instance.client),
);

final vaccinationsProvider = FutureProvider.family<List<Vaccination>, String>((
  ref,
  petId,
) {
  // Watched only to invalidate this cache when the signed-in user changes;
  // the id itself isn't used (see current_user_id_provider.dart).
  ref.watch(currentUserIdProvider);
  return ref.watch(vaccinationsRepositoryProvider).fetchForPet(petId);
});
