import 'package:supabase_flutter/supabase_flutter.dart';

String authErrorMessage(Object error) {
  if (error is AuthRetryableFetchException) {
    return 'Impossible de contacter le serveur. Vérifie ta connexion.';
  }
  if (error is AuthException) {
    return error.message;
  }
  return 'Impossible de contacter le serveur. Vérifie ta connexion.';
}
