import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_controller.dart';

/// Email/password sign-in and sign-up gate shown before the home screen.
///
/// Users create an account (or sign into an existing one) so their tasks sync
/// across devices. On success, the app switches to the home screen.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final coordinator = ref.read(syncCoordinatorProvider);
    try {
      if (coordinator == null) {
        // The cloud backend is not configured.
        setState(() => _error = 'Sync isn\'t configured yet.');
        return;
      }
      if (_registering) {
        await coordinator.signUp(email: _email.text, password: _password.text);
      } else {
        await coordinator.signIn(email: _email.text, password: _password.text);
      }
      // Success: auth state stream will flip the app to the home screen.
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter your email address first.');
      return;
    }

    final coordinator = ref.read(syncCoordinatorProvider);
    if (coordinator == null) {
      setState(() => _error = 'Sync isn\'t configured yet.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await coordinator.resetPassword(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    final coordinator = ref.read(syncCoordinatorProvider);
    if (coordinator == null) {
      setState(() => _error = 'Sync isn\'t configured yet.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await coordinator.signInWithGoogle();
      // Success: auth state stream will flip the app to the home screen.
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(String raw) {
    if (raw.contains('EMAIL_EXISTS')) {
      return 'That email is already registered.';
    }
    if (raw.contains('INVALID_LOGIN_CREDENTIALS') ||
        raw.contains('INVALID_PASSWORD') ||
        raw.contains('EMAIL_NOT_FOUND')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('WEAK_PASSWORD')) {
      return 'Use at least 6 characters for your password.';
    }
    if (raw.contains('INVALID_EMAIL')) return 'Enter a valid email address.';
    if (raw.contains('USER_DISABLED')) return 'This account has been disabled.';
    if (raw.contains('OPERATION_NOT_ALLOWED') ||
        raw.contains('CONFIGURATION_NOT_FOUND')) {
      return 'This sign-in method needs to be enabled in Firebase Authentication.';
    }
    if (raw.contains('SocketException') || raw.contains('ClientException')) {
      return 'Could not connect. Check your internet connection and try again.';
    }
    if (raw.contains('already registered')) {
      return 'That email is already registered.';
    }
    if (raw.contains('Invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('Email not confirmed') ||
        raw.contains('not been confirmed')) {
      return 'Please confirm your email (check your inbox), then sign in.';
    }
    if (raw.contains('Password should contain')) return 'Password is too weak.';
    if (raw.contains('TimeoutException')) {
      return 'Google sign-in timed out. Please try again.';
    }
    if (raw.contains('Could not open the browser')) {
      return 'Could not open a browser for Google sign-in.';
    }
    return raw
        .replaceAll(RegExp(r'^.*?(Exception|error):', caseSensitive: false), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.local_fire_department,
                        size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 12),
                    Text(
                      'Daily Focus',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _registering
                          ? 'Create an account to sync your tasks across devices'
                          : 'Sign in to sync your tasks across devices',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final value = v ?? '';
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if ((v ?? '').length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _busy ? null : _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_registering ? 'Create account' : 'Sign in'),
                    ),
                    if (!_registering) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'or',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: const Text('Continue with Google'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _registering = !_registering;
                                _error = null;
                              }),
                      child: Text(_registering
                          ? 'Already have an account? Sign in'
                          : 'New here? Create an account'),
                    ),
                    if (!_registering)
                      TextButton(
                        onPressed: _busy ? null : _forgotPassword,
                        child: const Text('Forgot password?'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
