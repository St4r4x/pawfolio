import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth_error_message.dart';
import '../../email_validation.dart';
import '../../widgets/auth_brand_header.dart';
import '../../widgets/auth_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  String? _emailError;
  String? _passwordError;
  String? _error;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) _validateEmail();
    });
    _passwordFocus.addListener(() {
      if (!_passwordFocus.hasFocus) _validatePassword();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool _validateEmail() {
    final valid = isValidEmail(_emailController.text);
    setState(
      () => _emailError = valid ? null : 'Entre une adresse email valide.',
    );
    return valid;
  }

  bool _validatePassword() {
    final valid = _passwordController.text.length >= 6;
    setState(
      () => _passwordError = valid
          ? null
          : 'Le mot de passe doit contenir au moins 6 caractères.',
    );
    return valid;
  }

  Future<void> _submit() async {
    final emailValid = _validateEmail();
    final passwordValid = _validatePassword();
    if (!emailValid || !passwordValid) return;

    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (e) {
      // authErrorMessage (lib/auth_error_message.dart) already handles the
      // AuthRetryableFetchException-before-AuthException ordering fix from
      // live device testing (MVP final-review-fixes plan, commit d1e7306) —
      // don't reintroduce separate catch clauses here, keep this one call.
      setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: AuthCard(child: _buildForm(context)),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AuthBrandHeader(),
        const SizedBox(height: 32),
        TextField(
          controller: _emailController,
          focusNode: _emailFocus,
          decoration: InputDecoration(
            labelText: 'Email',
            errorText: _emailError,
          ),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          decoration: InputDecoration(
            labelText: 'Mot de passe',
            errorText: _passwordError,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          obscureText: _obscurePassword,
          autofillHints: const [AutofillHints.password],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Se connecter'),
        ),
        TextButton(
          onPressed: () => context.push('/forgot-password'),
          child: const Text('Mot de passe oublié ?'),
        ),
        TextButton(
          onPressed: () => context.push('/signup'),
          child: const Text('Créer un compte'),
        ),
      ],
    );
  }
}
