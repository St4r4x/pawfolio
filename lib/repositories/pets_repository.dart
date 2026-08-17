import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pet.dart';

abstract class PetsRepository {
  Future<List<Pet>> fetchAll();
  Future<Pet> create(Pet pet);
}

class SupabasePetsRepository implements PetsRepository {
  SupabasePetsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Pet>> fetchAll() async {
    final rows = await _client.from('pets').select().order('created_at');
    return rows.map((row) => Pet.fromJson(row)).toList();
  }

  @override
  Future<Pet> create(Pet pet) async {
    final ownerId = _client.auth.currentUser!.id;
    final row = await _client.from('pets').insert(pet.toInsertJson(ownerId: ownerId)).select().single();
    return Pet.fromJson(row);
  }
}
