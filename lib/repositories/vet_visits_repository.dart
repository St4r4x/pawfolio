import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vet_visit.dart';

class VetVisitsRepository {
  VetVisitsRepository(this._client);

  final SupabaseClient _client;

  Future<List<VetVisit>> fetchForPet(String petId) async {
    final rows = await _client
        .from('vet_visits')
        .select()
        .eq('pet_id', petId)
        .order('visit_date', ascending: false);
    return rows.map((row) => VetVisit.fromJson(row)).toList();
  }

  Future<void> create(VetVisit visit) async {
    await _client.from('vet_visits').insert(visit.toInsertJson());
  }

  Future<void> update(VetVisit visit) async {
    await _client.from('vet_visits').update(visit.toInsertJson()).eq('id', visit.id);
  }
}
