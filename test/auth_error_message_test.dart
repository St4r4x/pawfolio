import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/auth_error_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('returns a friendly message for AuthRetryableFetchException', () {
    final error = AuthRetryableFetchException(message: 'ClientException with SocketException');
    expect(authErrorMessage(error), 'Impossible de contacter le serveur. Vérifie ta connexion.');
  });

  test('returns the raw message for a plain AuthException', () {
    const error = AuthException('Invalid login credentials');
    expect(authErrorMessage(error), 'Email ou mot de passe incorrect.');
  });

  test('returns a friendly message for any other error type', () {
    expect(authErrorMessage(Exception('boom')), 'Impossible de contacter le serveur. Vérifie ta connexion.');
  });
}
