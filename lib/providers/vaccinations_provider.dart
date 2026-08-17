import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vaccination.dart';
import '../repositories/vaccinations_repository.dart';

final vaccinationsRepositoryProvider =
    Provider<VaccinationsRepository>((ref) => SupabaseVaccinationsRepository(Supabase.instance.client));

final vaccinationsProvider = FutureProvider.family<List<Vaccination>, String>((ref, petId) {
  return ref.watch(vaccinationsRepositoryProvider).fetchForPet(petId);
});
