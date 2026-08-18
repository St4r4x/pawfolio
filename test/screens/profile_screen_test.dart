import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/providers/theme_mode_provider.dart';
import 'package:pawfolio/screens/profile/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    // ponytail: same pattern as test/app_smoke_test.dart — ProfileScreen reads
    // Supabase.instance.client.auth.currentUser during build, so the client
    // must be initialized before pumping it, same as the real app does in main().
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:54321',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('selecting Sombre updates themeModeProvider', (tester) async {
    late ProviderContainer container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(),
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sombre'));
    await tester.pumpAndSettle();

    expect(container.read(themeModeProvider), ThemeMode.dark);
  });
}
