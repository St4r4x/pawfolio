import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/treatment.dart';
import '../repositories/treatments_repository.dart';

final treatmentsRepositoryProvider =
    Provider((ref) => TreatmentsRepository(Supabase.instance.client));

final treatmentsProvider = FutureProvider.family<List<Treatment>, String>((ref, petId) {
  return ref.watch(treatmentsRepositoryProvider).fetchForPet(petId);
});
