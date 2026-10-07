import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/daily_progress_sync_service.dart';
import '../../services/escore_reset_service.dart';
import '../../services/google_calendar_service.dart';
import '../profile/profile_store.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _busy = false;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail({required bool signUp}) async {
    if (_busy) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final validation = _credentialValidationMessage(email, password);
    if (validation != null) {
      _showMessage(validation);
      return;
    }
    setState(() => _busy = true);
    try {
      final credential = signUp
          ? await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: email,
              password: password,
            )
          : await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
      final display = credential.user?.displayName ?? email.split('@').first;
      if (display.trim().isNotEmpty) {
        await ProfileStore.instance.setName(display);
      }
      await EscoreResetService.instance.checkForRemoteReset();
      await DailyProgressSyncService.instance.syncToday();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      _showError(error, signUp: signUp);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await GoogleCalendarService.instance.signIn();
      final displayName = FirebaseAuth.instance.currentUser?.displayName;
      if (displayName != null && displayName.trim().isNotEmpty) {
        await ProfileStore.instance.setName(displayName);
      }
      await EscoreResetService.instance.checkForRemoteReset();
      await DailyProgressSyncService.instance.syncToday();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _credentialValidationMessage(String email, String password) {
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email address.';
    }
    if (password.length < 6) {
      return 'Use at least 6 characters for the password.';
    }
    return null;
  }

  String _authErrorMessage(Object error, {required bool signUp}) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'email-already-in-use' =>
          'This email is already registered. Try Login.',
        'invalid-email' => 'Enter a valid email address.',
        'weak-password' =>
          'Use a stronger password with at least 6 characters.',
        'wrong-password' => 'The password is not correct.',
        'user-not-found' => 'No account found for this email. Try Sign up.',
        'network-request-failed' =>
          'Network issue. Check internet and try again.',
        'operation-not-allowed' =>
          'Email login is not enabled for this Firebase project.',
        _ => signUp
            ? 'Could not create the account. Please try again.'
            : 'Could not sign in. Please try again.',
      };
    }
    return signUp
        ? 'Could not create the account. Please try again.'
        : 'Could not sign in. Please try again.';
  }

  void _showError(Object error, {bool signUp = false}) {
    _showMessage(_authErrorMessage(error, signUp: signUp));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        children: <Widget>[
          const Text(
            'Welcome back',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textStrong,
              fontSize: 34,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sync your goals, rank board, and shared plans.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface.withOpacity(0.58),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: colors.outline.withOpacity(0.74)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withOpacity(0.045),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_rounded),
                    suffixIcon: IconButton(
                      tooltip:
                          _passwordVisible ? 'Hide password' : 'Show password',
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() => _passwordVisible = !_passwordVisible);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            _busy ? null : () => _submitEmail(signUp: false),
                        child: Text(_busy ? 'Please wait...' : 'Login'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _busy ? null : () => _submitEmail(signUp: true),
                        child: const Text('Sign up'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _busy ? null : _signInWithGoogle,
            icon: Icon(Icons.g_mobiledata_rounded, color: colors.primary),
            label: const Text('Continue with Google'),
          ),
        ],
      ),
    );
  }
}
