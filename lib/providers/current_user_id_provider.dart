import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Emits the current user id whenever Supabase's auth state changes (login,
/// logout, or switching accounts). Other providers watch this to invalidate
/// their cached data when the signed-in user changes.
final currentUserIdProvider = StreamProvider<String?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map(
    (event) => event.session?.user.id,
  );
});
