import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';
import 'admin_config.dart';
import 'admin_dashboard.dart';

/// The web-only super-admin app. `main.dart` runs this instead of `YnoApp` when
/// `kIsWeb`. It shows an email + password login ([_AdminLogin]); only the
/// super-admin account (see [kSuperAdmins]) may sign in, after which the
/// dashboard appears.
class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YNO Super Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _AdminGate(),
    );
  }
}

/// Shows the dashboard when a super-admin is signed in, otherwise the login.
class _AdminGate extends StatelessWidget {
  const _AdminGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user != null && kSuperAdmins.contains(user.email)) {
          return const AdminDashboard();
        }
        return const _AdminLogin();
      },
    );
  }
}

/// Email + password login for the super-admin panel.
///
/// Sign-in only. It used to create the super-admin account on the first login
/// that matched a password compiled into `kSuperAdminPassword` — which meant
/// the panel's password sat in a public repository, and anyone who reached the
/// page before the real admin did could claim the account. The account is now
/// made by hand in the Firebase console and this screen only authenticates
/// against it. Anyone who isn't in [kSuperAdmins] is signed straight back out.
class _AdminLogin extends StatefulWidget {
  const _AdminLogin();

  @override
  State<_AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<_AdminLogin> {
  final _email = TextEditingController(text: kSuperAdminEmail);
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter both email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = FirebaseAuth.instance;
    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
      // Signed in — but only the allowlisted account may use the panel.
      if (!kSuperAdmins.contains(auth.currentUser?.email)) {
        await auth.signOut();
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = 'This account is not authorised for the admin panel.';
        });
        return;
      }
      // The auth stream in [_AdminGate] now swaps in the dashboard.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _messageFor(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not sign in.\n$e';
      });
    }
  }

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        // Also what a never-created account looks like: Firebase deliberately
        // does not distinguish "no such user" from "wrong password".
        return 'Wrong email or password. If this is a new project, create the '
            'admin account in Firebase console → Authentication → Users.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is disabled for this Firebase project. '
            'Enable it in Authentication → Sign-in method.';
      case 'network-request-failed':
        return 'Network error — check your connection and retry.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a moment and try again.';
      default:
        return e.message ?? 'Could not sign in.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.shield_outlined,
                      color: AppColors.primary, size: 48),
                  const SizedBox(height: 16),
                  Text('YNO Super Admin',
                      textAlign: TextAlign.center,
                      style:
                          AppText.condensed(size: 28, weight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Sign in to manage the database.',
                      textAlign: TextAlign.center,
                      style: AppText.barlow(size: 14, color: AppColors.dim)),
                  const SizedBox(height: 24),
                  _label('Email'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    style: AppText.barlow(size: 15),
                    decoration: _fieldDecoration('you@admin.com'),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  _label('Password'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    style: AppText.barlow(size: 15),
                    decoration: _fieldDecoration('••••••').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.dim,
                            size: 20),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: AppText.barlow(
                            size: 13, color: AppColors.loss, height: 1.4)),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.ink,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4, color: AppColors.ink),
                            )
                          : Text('Sign In',
                              style: AppText.condensed(
                                  size: 18, weight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text.toUpperCase(),
      style: AppText.barlow(
          size: 11,
          weight: FontWeight.w700,
          color: AppColors.dim,
          letterSpacing: 1.2));

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: AppText.barlow(size: 15, color: AppColors.dim2),
        filled: true,
        fillColor: AppColors.surface2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
      );
}
