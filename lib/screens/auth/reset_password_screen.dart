import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth_error_message.dart';
import '../../password_validation.dart';
import '../../providers/password_recovery_provider.dart';
import '../../widgets/auth_card.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _passwordError;
  String? _confirmError;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _validate() {
    final passwordValid = isValidPassword(_passwordController.text);
    final confirmValid = _confirmController.text == _passwordController.text;
    setState(() {
      _passwordError = passwordValid
          ? null
          : 'Le mot de passe doit contenir au moins 6 caractères.';
      _confirmError = confirmValid
          ? null
          : 'Les mots de passe ne correspondent pas.';
    });
    return passwordValid && confirmValid;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      ref.read(isPasswordRecoveryProvider.notifier).clear();
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau mot de passe')),
      body: AuthCard(child: _buildForm(context)),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Choisis un nouveau mot de passe.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: 'Nouveau mot de passe',
            errorText: _passwordError,
          ),
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmController,
          decoration: InputDecoration(
            labelText: 'Confirmer le mot de passe',
            errorText: _confirmError,
          ),
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
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
              : const Text('Changer le mot de passe'),
        ),
      ],
    );
  }
}
