String? authRedirect({required bool loggedIn, required String location}) {
  final loggingIn = location == '/login' || location == '/signup';
  if (!loggedIn && !loggingIn) return '/login';
  if (loggedIn && loggingIn) return '/';
  return null;
}
