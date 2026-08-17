import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/auth_redirect.dart';

void main() {
  test('redirects to login when logged out and not already on an auth screen', () {
    expect(authRedirect(loggedIn: false, location: '/'), '/login');
  });

  test('redirects to home when logged in and on the login screen', () {
    expect(authRedirect(loggedIn: true, location: '/login'), '/');
  });

  test('no redirect when logged in and on a normal screen', () {
    expect(authRedirect(loggedIn: true, location: '/pets/123'), isNull);
  });

  test('no redirect when logged out and already on the signup screen', () {
    expect(authRedirect(loggedIn: false, location: '/signup'), isNull);
  });
}
