String? authRedirect({
  required bool loggedIn,
  required String location,
  bool isPasswordRecovery = false,
}) {
  // Gated on loggedIn: the sticky recovery flag can outlive the session
  // (e.g. a failed background token refresh signs the user out), and
  // without this gate a signed-out recovery session would ping-pong
  // between here and the logged-out redirect below forever.
  if (isPasswordRecovery && loggedIn && location != '/reset-password') {
    return '/reset-password';
  }
  final publicAuthRoute =
      location == '/login' ||
      location == '/signup' ||
      location == '/forgot-password';
  if (!loggedIn && !publicAuthRoute) return '/login';
  if (loggedIn && publicAuthRoute) return '/';
  return null;
}
