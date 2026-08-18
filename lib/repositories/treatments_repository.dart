import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/treatment.dart';

class TreatmentsRepository {
  TreatmentsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Treatment>> fetchForPet(String petId) async {
    final rows = await _client
        .from('treatments')
        .select()
        .eq('pet_id', petId)
        .order('date_given', ascending: false);
    return rows.map((row) => Treatment.fromJson(row)).toList();
  }

  Future<void> create(Treatment treatment) async {
    await _client.from('treatments').insert(treatment.toInsertJson());
  }

  Future<void> update(Treatment treatment) async {
    await _client.from('treatments').update(treatment.toInsertJson()).eq('id', treatment.id);
  }
}
