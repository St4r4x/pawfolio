import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawfolio/app_shell.dart';

void main() {
  GoRouter buildTestRouter() => GoRouter(
        initialLocation: '/',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) =>
                AppShell(navigationShell: navigationShell),
            branches: [
              StatefulShellBranch(
                routes: [GoRoute(path: '/', builder: (context, state) => const Text('Home body'))],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(path: '/reminders', builder: (context, state) => const Text('Reminders body')),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(path: '/vets', builder: (context, state) => const Text('Vets body')),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(path: '/profile', builder: (context, state) => const Text('Profile body')),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/pets/:id',
            builder: (context, state) => Text('Detail: ${state.pathParameters['id']}'),
          ),
        ],
      );

  testWidgets('switches branches when tapping nav destinations', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: buildTestRouter()));
    await tester.pumpAndSettle();

    expect(find.text('Home body'), findsOneWidget);

    await tester.tap(find.text('Rappels'));
    await tester.pumpAndSettle();
    expect(find.text('Reminders body'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Profile body'), findsOneWidget);
  });

  testWidgets('pushing a pet detail route covers the bottom nav', (tester) async {
    final router = buildTestRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.push('/pets/1');
    await tester.pumpAndSettle();

    expect(find.text('Detail: 1'), findsOneWidget);
    expect(find.text('Rappels'), findsNothing);
  });
}
