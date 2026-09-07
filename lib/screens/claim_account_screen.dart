import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
import '../services/otp_service.dart';
import '../services/user_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/header.dart';
import '../widgets/inputs.dart';
import '../widgets/yno_scaffold.dart';

/// Claim an account a host created for you.
///
/// Enter your email → we confirm a host-created account exists and mail a
/// 6-digit code → the code signs you in silently → you are offered the chance
/// to set your own password.
///
/// Reached from **both** the login and sign-up screens, and from
/// `showAccountExistsDialog` when someone tries to sign up with an address a
/// host already used (that path passes the email as the route argument).
///
/// All steps live in ONE route on purpose: the sign-in happens between step two
/// and step three, so splitting them would leave a signed-in-but-unclaimed
/// account sitting on a screen it can navigate away from.
class ClaimAccountScreen extends StatefulWidget {
  const ClaimAccountScreen({super.key});

  @override
  State<ClaimAccountScreen> createState() => _ClaimAccountScreenState();
}

enum _Step { email, code, password }

class _ClaimAccountScreenState extends State<ClaimAccountScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _Step _step = _Step.email;
  bool _busy = false;
  bool _argsRead = false;

  /// Seconds until another code may be requested. Drives the resend label.
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    // Pre-filled when we already know the address (the sign-up dialog); empty
    // when the user tapped "Claim account" on login or sign-up.
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) _email.text = args.trim();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _emailOk {
    final e = _email.text.trim();
    return e.length > 3 && e.contains('@') && e.contains('.');
  }

  bool get _pwOk => _password.text.length >= 8;
  bool get _pwMatches => _password.text == _confirm.text;

  void _startResendCountdown(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendIn = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  void _goHome() =>
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.home, (r) => false);

  // ---- Actions ----------------------------------------------------------
  Future<void> _sendCode() async {
    if (_busy) return;
    if (!_emailOk) {
      showYnoToast(context, tr('auth.invalidEmail'));
      return;
    }
    setState(() => _busy = true);
    try {
      await OtpService.instance.requestOtp(_email.text.trim());
      if (!mounted) return;
      setState(() => _step = _Step.code);
      _startResendCountdown(60);
    } on OtpException catch (e) {
      if (!mounted) return;
      showYnoToast(context, e.message);
      // A cooldown means a code is already in flight — let them type it rather
      // than stranding them on the email step with no way forward.
      if (e.code == 'rate_limited') {
        setState(() => _step = _Step.code);
        _startResendCountdown(e.retryAfter ?? 60);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy) return;
    final code = _code.text.trim();
    if (code.length != 6) {
      showYnoToast(context, tr('auth.otpSixDigits'));
      return;
    }
    setState(() => _busy = true);
    try {
      // Signs in silently on success — the player never sees a password.
      await OtpService.instance.verifyAndSignIn(_email.text.trim(), code);
      if (!mounted) return;
      setState(() => _step = _Step.password);
    } on OtpException catch (e) {
      if (!mounted) return;
      showYnoToast(context, e.message);
      _code.clear();
      // The code is burned after too many wrong guesses or once expired —
      // send them back to request a fresh one instead of retrying a dead code.
      if (e.code == 'too_many_attempts' || e.code == 'code_expired') {
        setState(() => _step = _Step.email);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showYnoToast(context, authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setPassword() async {
    if (_busy) return;
    if (!_pwOk) {
      showYnoToast(context, tr('auth.pwMin8'));
      return;
    }
    if (!_pwMatches) {
      showYnoToast(context, tr('auth.pwMismatch'));
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // The session went away — start over rather than pretending.
      showYnoToast(context, tr('auth.otpErrGeneric'));
      setState(() => _step = _Step.email);
      return;
    }
    setState(() => _busy = true);
    try {
      // No reauthentication needed: the sign-in above is seconds old, which is
      // exactly the "recent login" updatePassword requires.
      await user.updatePassword(_password.text);
      // Only now is the account genuinely owned by this person. Cleared HERE
      // rather than after the OTP on purpose: someone who skips the password
      // step still has the shared one, so they must be able to claim again.
      await UserRepository.instance.updateProfile(user.uid, autoCreated: false);
      if (!mounted) return;
      showYnoToast(context, tr('auth.claimDone'));
      _goHome();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showYnoToast(context, authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- Build ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // The password step is reached already signed in, so backing out of it
    // would drop the user behind the login screen while logged in. Skipping is
    // offered as an explicit action instead.
    final onPasswordStep = _step == _Step.password;
    return PopScope(
      canPop: !onPasswordStep,
      child: YnoScaffold(
        appBarTitle: tr('auth.claimTitle'),
        showBackButton: !onPasswordStep,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: switch (_step) {
              _Step.email => _emailStep(),
              _Step.code => _codeStep(),
              _Step.password => _passwordStep(),
            },
          ),
        ),
      ),
    );
  }

  Widget _heading(String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: AppText.condensed(
                size: 42, weight: FontWeight.w800, height: 0.95)),
        const SizedBox(height: 8),
        Text(sub,
            style: AppText.barlow(size: 15, color: AppColors.dim, height: 1.5)),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _emailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(tr('auth.claimHeading'), tr('auth.claimSub')),
        FieldLabel(tr('auth.emailLabel')),
        const SizedBox(height: 8),
        YnoTextField(
          controller: _email,
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          autofocus: _email.text.isEmpty,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _sendCode(),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: _busy ? tr('auth.sending') : tr('auth.claimAction'),
          onTap: _busy || !_emailOk ? null : _sendCode,
        ),
      ],
    );
  }

  Widget _codeStep() {
    final canResend = _resendIn <= 0 && !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(tr('auth.otpHeading'),
            '${tr('auth.otpSentTo')} ${_email.text.trim()}'),
        FieldLabel(tr('auth.otpCodeLabel')),
        const SizedBox(height: 8),
        YnoTextField(
          controller: _code,
          hint: '000000',
          keyboardType: TextInputType.number,
          autofocus: true,
          fontSize: 24,
          onChanged: (v) {
            // Six digits is the whole code — submit on the last one so the
            // keyboard's return key is never the only way forward.
            if (v.trim().length == 6 && !_busy) _verify();
          },
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: _busy ? tr('auth.otpVerifying') : tr('auth.otpVerify'),
          onTap: _busy ? null : _verify,
        ),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: canResend ? _sendCode : null,
            child: Text(
              canResend
                  ? tr('auth.otpResend')
                  : '${tr('auth.otpResendIn')} ${_resendIn}s',
              style: AppText.barlow(
                  size: 14,
                  weight: FontWeight.w700,
                  color: canResend ? AppColors.primary : AppColors.dim),
            ),
          ),
        ),
      ],
    );
  }

  Widget _passwordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(tr('auth.setPwHeading'), tr('auth.setPwSub')),
        FieldLabel(tr('auth.newPasswordLabel')),
        const SizedBox(height: 8),
        YnoTextField(
          controller: _password,
          hint: tr('auth.passwordHint'),
          obscure: true,
          autofocus: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        FieldLabel(tr('auth.confirmPasswordLabel')),
        const SizedBox(height: 8),
        YnoTextField(
          controller: _confirm,
          hint: tr('auth.passwordHint'),
          obscure: true,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _setPassword(),
        ),
        const SizedBox(height: 12),
        Text(
          !_pwOk
              ? tr('auth.pwMin8')
              : (!_pwMatches ? tr('auth.pwMismatch') : tr('auth.pwLooksGood')),
          style: AppText.barlow(
              size: 13,
              color: _pwOk && _pwMatches ? AppColors.win : AppColors.dim),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: _busy ? tr('auth.setPwSaving') : tr('auth.setPwAction'),
          onTap: _busy || !_pwOk || !_pwMatches ? null : _setPassword,
        ),
        const SizedBox(height: 12),
        // Setting a password is offered, not forced — they are already signed
        // in by this point. It can be done later in Edit Profile.
        Center(
          child: GestureDetector(
            onTap: _busy ? null : _goHome,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(tr('auth.setPwLater'),
                  style: AppText.barlow(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppColors.dim)),
            ),
          ),
        ),
      ],
    );
  }
}
