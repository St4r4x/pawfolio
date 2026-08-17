import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/weight_entry.dart';

class WeightEntriesRepository {
  WeightEntriesRepository(this._client);

  final SupabaseClient _client;

  Future<List<WeightEntry>> fetchForPet(String petId) async {
    final rows = await _client
        .from('weight_entries')
        .select()
        .eq('pet_id', petId)
        .order('recorded_at', ascending: false);
    return rows.map((row) => WeightEntry.fromJson(row)).toList();
  }

  Future<void> create(WeightEntry entry) async {
    await _client.from('weight_entries').insert(entry.toInsertJson());
  }
}
