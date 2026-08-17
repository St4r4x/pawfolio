import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    // ponytail: supabase_flutter persists the session via shared_preferences,
    // whose platform channel isn't mocked by default under flutter_test.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:54321',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('app boots with no session and shows the login screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PawfolioApp()));
    await tester.pumpAndSettle();
    expect(find.text('Connexion'), findsOneWidget);
  });
}
