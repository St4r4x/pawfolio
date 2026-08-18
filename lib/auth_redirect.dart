String? authRedirect({required bool loggedIn, required String location}) {
  final publicAuthRoute =
      location == '/login' ||
      location == '/signup' ||
      location == '/forgot-password';
  if (!loggedIn && !publicAuthRoute) return '/login';
  if (loggedIn && publicAuthRoute) return '/';
  return null;
}
