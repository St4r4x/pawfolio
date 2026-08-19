import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/providers/password_recovery_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('becomes true when the auth stream emits a passwordRecovery event, and can be cleared',
      () async {
    final eventController = StreamController<AuthChangeEvent>();
    addTearDown(eventController.close);

    final container = ProviderContainer(
      overrides: [authEventProvider.overrideWith((ref) => eventController.stream)],
    );
    addTearDown(container.dispose);

    container.listen(isPasswordRecoveryProvider, (previous, next) {});

    expect(container.read(isPasswordRecoveryProvider), isFalse);

    eventController.add(AuthChangeEvent.passwordRecovery);
    await pumpEventQueue();
    expect(container.read(isPasswordRecoveryProvider), isTrue);

    container.read(isPasswordRecoveryProvider.notifier).clear();
    expect(container.read(isPasswordRecoveryProvider), isFalse);
  });

  test('stays false for a normal signedIn event', () async {
    final eventController = StreamController<AuthChangeEvent>();
    addTearDown(eventController.close);

    final container = ProviderContainer(
      overrides: [authEventProvider.overrideWith((ref) => eventController.stream)],
    );
    addTearDown(container.dispose);

    container.listen(isPasswordRecoveryProvider, (previous, next) {});

    eventController.add(AuthChangeEvent.signedIn);
    await pumpEventQueue();

    expect(container.read(isPasswordRecoveryProvider), isFalse);
  });
}
