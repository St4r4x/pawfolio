import 'package:supabase_flutter/supabase_flutter.dart';

import '../reminders.dart';

class RemindersRepository {
  RemindersRepository(this._client);

  final SupabaseClient _client;

  Future<List<DueItem>> fetchUpcoming(Map<String, String> petNamesById) async {
    final rows = await _client.from('upcoming_reminders').select('pet_id, label, due_date');
    return rows.map((row) {
      final petId = row['pet_id'] as String;
      return DueItem(
        petId: petId,
        petName: petNamesById[petId] ?? '?',
        label: row['label'] as String,
        dueDate: DateTime.parse(row['due_date'] as String),
      );
    }).toList();
  }
}
