import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/auth_redirect.dart';

void main() {
  test(
    'redirects to login when logged out and not already on an auth screen',
    () {
      expect(authRedirect(loggedIn: false, location: '/'), '/login');
    },
  );

  test('redirects to home when logged in and on the login screen', () {
    expect(authRedirect(loggedIn: true, location: '/login'), '/');
  });

  test('no redirect when logged in and on a normal screen', () {
    expect(authRedirect(loggedIn: true, location: '/pets/123'), isNull);
  });

  test('no redirect when logged out and already on the signup screen', () {
    expect(authRedirect(loggedIn: false, location: '/signup'), isNull);
  });

  test(
    'no redirect when logged out and already on the forgot-password screen',
    () {
      expect(
        authRedirect(loggedIn: false, location: '/forgot-password'),
        isNull,
      );
    },
  );

  test(
    'redirects to home when logged in and on the forgot-password screen',
    () {
      expect(authRedirect(loggedIn: true, location: '/forgot-password'), '/');
    },
  );

  test('redirects to reset-password when a recovery session is active', () {
    expect(
      authRedirect(loggedIn: true, location: '/', isPasswordRecovery: true),
      '/reset-password',
    );
  });

  test('no redirect when a recovery session is active and already on reset-password', () {
    expect(
      authRedirect(
        loggedIn: true,
        location: '/reset-password',
        isPasswordRecovery: true,
      ),
      isNull,
    );
  });

  test('does not loop when the recovery flag outlives the session', () {
    // Simulates go_router repeatedly following redirect() until it settles,
    // the same way it would after a background token refresh signs the user
    // out mid-recovery (isPasswordRecovery stays true, loggedIn flips false).
    var location = '/';
    final visited = <String>{location};
    for (var i = 0; i < 5; i++) {
      final next = authRedirect(
        loggedIn: false,
        location: location,
        isPasswordRecovery: true,
      );
      if (next == null) return;
      expect(
        visited.contains(next),
        isFalse,
        reason: 'redirect loop: $visited -> $next',
      );
      visited.add(next);
      location = next;
    }
    fail('redirect chain did not settle within 5 hops: $visited');
  });
}
