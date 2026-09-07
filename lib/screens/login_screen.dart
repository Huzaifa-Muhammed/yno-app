import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
import '../services/user_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/header.dart';
import '../widgets/inputs.dart';
import '../widgets/yno_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Optional prefill passed from the sign-up "we already have your data"
    // flow: {'email': ...}. Only apply once.
    //
    // A 'password' key used to be honoured here too, carrying the shared
    // default so an auto-created account arrived pre-filled. Nothing passes it
    // any more — those accounts go through the claim flow — and it is not read
    // back on purpose, so no caller can silently reintroduce a typed-in
    // password.
    if (_prefilled) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final email = args['email'];
      if (email is String) _email.text = email;
      _prefilled = true;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(Routes.home, (r) => false);
  }

  /// After a successful sign-in, honour a temporary deactivation: auto-reactivate
  /// once the window has passed, otherwise offer to reactivate early.
  Future<void> _proceedAfterLogin() async {
    final uid = AuthRepository.instance.uid;
    if (uid == null) {
      _goHome();
      return;
    }
    final user = await UserRepository.instance.getUser(uid);
    if (!mounted) return;
    if (user == null || !user.deactivated) {
      _goHome();
      return;
    }

    final until = user.reactivateAt;
    final windowPassed = until == null || until.isBefore(DateTime.now());
    if (windowPassed) {
      await UserRepository.instance.reactivate(uid);
      if (!mounted) return;
      _goHome();
      return;
    }

    final reactivate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            side: BorderSide(color: AppColors.line2)),
        title: Text(tr('auth.accountDeactivatedTitle'),
            style: AppText.condensed(size: 20, weight: FontWeight.w800)),
        content: Text(
            '${tr('auth.deactivatedBody1')}'
            '${DateFormat('d MMM yyyy').format(until)}'
            '${tr('auth.deactivatedBody2')}',
            style: AppText.barlow(size: 14, color: AppColors.dim, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('auth.notYet'),
                style: AppText.barlow(
                    size: 14, weight: FontWeight.w700, color: AppColors.dim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('auth.reactivate'),
                style: AppText.barlow(
                    size: 14, weight: FontWeight.w800, color: AppColors.txt)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (reactivate == true) {
      await UserRepository.instance.reactivate(uid);
      if (!mounted) return;
      _goHome();
    } else {
      await AuthRepository.instance.signOut();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    if (_busy) return;
    final email = _email.text.trim();
    final pass = _password.text;
    if (email.isEmpty || pass.isEmpty) {
      showYnoToast(context, tr('auth.enterEmailPassword'));
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthRepository.instance.signIn(email: email, password: pass);
      if (!mounted) return;
      await _proceedAfterLogin();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showYnoToast(context, authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await AuthRepository.instance.signInWithGoogle();
      if (!mounted) return;
      if (result == null) {
        // Cancelled by the user.
        setState(() => _busy = false);
        return;
      }
      if (result.isNew) {
        // A brand-new Google account still needs the onboarding profile.
        Navigator.of(context).pushNamedAndRemoveUntil(
            Routes.signup, (r) => false);
      } else {
        await _proceedAfterLogin();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showYnoToast(context, authErrorMessage(e));
      setState(() => _busy = false);
    } catch (_) {
      if (!mounted) return;
      showYnoToast(context, tr('auth.googleFailed'));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // No app bar: its title only repeated the big heading below it, and moving
    // between login and sign-up is done with the link at the bottom.
    //
    // ⚠️ Two things travelled with it. `SafeArea(top: false)` was only correct
    // while the AppBar ate the status-bar inset — without it the heading runs
    // under the notch. And the AppBar carried the only back button: welcome
    // pushes this route, and `post_match_screen` pushes sign-up from a guest's
    // scorecard, so with nothing to go back to on screen a visitor is stranded
    // on a login form. Hence the BackChip — the app's own back affordance from
    // `ScreenHeader`, shown only when there IS something to pop.
    return YnoScaffold(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (Navigator.of(context).canPop()) ...[
                const BackChip(),
                const SizedBox(height: 18),
              ],
              Text(tr('auth.welcomeBackHeading'),
                  style: AppText.condensed(
                      size: 46, weight: FontWeight.w800, height: 0.95)),
              const SizedBox(height: 6),
              Text(tr('auth.loginSub'),
                  style: AppText.barlow(size: 15, color: AppColors.dim)),
              const SizedBox(height: 28),
              SecondaryButton(
                label: tr('auth.continueWithGoogle'),
                icon: const Text('G',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.txt)),
                condensed: false,
                fontSize: 16,
                onTap: _google,
              ),
              const SizedBox(height: 20),
              const _OrDivider(),
              const SizedBox(height: 20),
              FieldLabel(tr('auth.emailLabel')),
              YnoTextField(
                controller: _email,
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              FieldLabel(tr('auth.passwordLabel')),
              YnoTextField(
                controller: _password,
                hint: tr('auth.passwordHint'),
                obscure: true,
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed(Routes.forgot),
                  child: Text(tr('auth.forgotPassword'),
                      style: AppText.barlow(
                          size: 14,
                          weight: FontWeight.w600,
                          color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                  label: _busy ? tr('auth.loggingIn') : tr('auth.login'),
                  onTap: _login),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () =>
                      Navigator.of(context).pushReplacementNamed(Routes.signup),
                  child: RichText(
                    text: TextSpan(
                      style: AppText.barlow(size: 14, color: AppColors.dim),
                      children: [
                        TextSpan(text: tr('auth.newHere')),
                        TextSpan(
                            text: tr('auth.createAnAccount'),
                            style: const TextStyle(
                                color: AppColors.txt,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // A player whose account a host created has no password to type
              // here — they take it over with an emailed code instead. The
              // email box is passed along so they don't retype it.
              ClaimAccountLink(email: _email.text),
            ],
          ),
        ),
      ),
    );
  }
}

/// "OR" separator between the Google button and the email form.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.line, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(tr('auth.or'),
              style: AppText.label(color: AppColors.dim2)),
        ),
        const Expanded(child: Divider(color: AppColors.line, height: 1)),
      ],
    );
  }
}
