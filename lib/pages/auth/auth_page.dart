import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
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
    setState(() => _busy = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
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
      _showError(error);
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

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sign in failed: $error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.large),
        children: <Widget>[
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: !_passwordVisible,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                tooltip: _passwordVisible ? 'Hide password' : 'Show password',
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
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _submitEmail(signUp: false),
                  child: Text(_busy ? 'Please wait...' : 'Login'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _submitEmail(signUp: true),
                  child: const Text('Sign up'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
