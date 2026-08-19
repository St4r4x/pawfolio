import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Raw auth event stream, overridable in tests the same way as
/// current_user_id_provider.dart.
final authEventProvider = StreamProvider<AuthChangeEvent>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map((state) => state.event);
});

/// True once a password-recovery link has been opened, until the reset
/// screen clears it after a successful password update. Sticky (not just a
/// reflection of the latest auth event) so the router keeps sending the
/// user to /reset-password across intermediate events.
class PasswordRecoveryNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(authEventProvider, (previous, next) {
      if (next.value == AuthChangeEvent.passwordRecovery) state = true;
    });
    return false;
  }

  void clear() => state = false;
}

final isPasswordRecoveryProvider = NotifierProvider<PasswordRecoveryNotifier, bool>(
  PasswordRecoveryNotifier.new,
);
