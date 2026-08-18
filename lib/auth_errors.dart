String mapAuthError(String message) {
  const knownErrors = {
    'Invalid login credentials': 'Email ou mot de passe incorrect.',
    'User already registered': 'Un compte existe déjà avec cet email.',
    'Email not confirmed': "Confirme ton email avant de te connecter.",
    'Password should be at least 6 characters':
        'Le mot de passe doit contenir au moins 6 caractères.',
  };
  return knownErrors[message] ?? 'Une erreur est survenue, réessaie.';
}
