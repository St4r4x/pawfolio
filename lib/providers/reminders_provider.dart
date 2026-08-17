import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../reminders.dart';
import '../repositories/reminders_repository.dart';
import 'pets_provider.dart';

final remindersRepositoryProvider =
    Provider((ref) => RemindersRepository(Supabase.instance.client));

final upcomingRemindersProvider = FutureProvider<List<DueItem>>((ref) async {
  final pets = await ref.watch(petsProvider.future);
  final petNamesById = {for (final pet in pets) pet.id: pet.name};
  final items = await ref.watch(remindersRepositoryProvider).fetchUpcoming(petNamesById);
  return sortUpcoming(items);
});
