import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vaccination.dart';

abstract class VaccinationsRepository {
  Future<List<Vaccination>> fetchForPet(String petId);
  Future<void> create(Vaccination vaccination);
}

class SupabaseVaccinationsRepository implements VaccinationsRepository {
  SupabaseVaccinationsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Vaccination>> fetchForPet(String petId) async {
    final rows = await _client
        .from('vaccinations')
        .select()
        .eq('pet_id', petId)
        .order('date_administered', ascending: false);
    return rows.map((row) => Vaccination.fromJson(row)).toList();
  }

  @override
  Future<void> create(Vaccination vaccination) async {
    await _client.from('vaccinations').insert(vaccination.toInsertJson());
  }
}
