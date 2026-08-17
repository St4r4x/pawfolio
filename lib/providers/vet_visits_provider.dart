import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vet_visit.dart';
import '../repositories/vet_visits_repository.dart';

final vetVisitsRepositoryProvider =
    Provider((ref) => VetVisitsRepository(Supabase.instance.client));

final vetVisitsProvider = FutureProvider.family<List<VetVisit>, String>((ref, petId) {
  return ref.watch(vetVisitsRepositoryProvider).fetchForPet(petId);
});
