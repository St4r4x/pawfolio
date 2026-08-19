import 'dart:async';

import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_shell.dart';
import 'auth_redirect.dart';
import 'motion.dart';
import 'providers/password_recovery_provider.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/pet_detail/pet_detail_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/reminders/reminders_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshStream = GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  );
  // refreshStream's own subscription (above) is registered on the raw auth
  // stream before authEventProvider's, so on a real passwordRecovery event
  // it can fire redirect() before isPasswordRecoveryProvider flips to true,
  // missing that pass. This re-triggers redirect once the flag actually
  // updates. (Also fires on clear(), though that path already re-triggers
  // via ResetPasswordScreen's explicit context.go('/').)
  ref.listen(
    isPasswordRecoveryProvider,
    (previous, next) => refreshStream.refresh(),
  );

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshStream,
    redirect: (context, state) => authRedirect(
      loggedIn: Supabase.instance.client.auth.currentSession != null,
      location: state.matchedLocation,
      isPasswordRecovery: ref.read(isPasswordRecoveryProvider),
    ),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reminders',
                builder: (context, state) => const RemindersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/pets/:id',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: PetDetailScreen(petId: state.pathParameters['id']!),
          transitionDuration: AppMotion.durationOrInstant(
            context,
            AppMotion.transitionDuration,
          ),
          reverseTransitionDuration: AppMotion.durationOrInstant(
            context,
            AppMotion.transitionDuration,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              SharedAxisTransition(
                animation: animation,
                secondaryAnimation: secondaryAnimation,
                transitionType: SharedAxisTransitionType.horizontal,
                child: child,
              ),
        ),
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  void refresh() => notifyListeners();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
