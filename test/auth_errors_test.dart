import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/auth_errors.dart';

void main() {
  test('maps known Supabase error messages to French', () {
    expect(mapAuthError('Invalid login credentials'), 'Email ou mot de passe incorrect.');
    expect(mapAuthError('User already registered'), 'Un compte existe déjà avec cet email.');
  });

  test('falls back to a generic message for unknown errors', () {
    expect(mapAuthError('Some new Supabase error string'), 'Une erreur est survenue, réessaie.');
  });
}
