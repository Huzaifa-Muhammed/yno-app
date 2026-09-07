import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
import '../services/referral_link_service.dart';
import '../services/user_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/header.dart';
import '../widgets/inputs.dart';
import '../widgets/yno_scaffold.dart';

enum _RefStatus { idle, checking, valid, invalid }

/// Single-page sign up. Collects only name, email, password and an optional
/// referral code, then creates the account and drops the user on Home (where
/// they pick a position). Google sign-in is one tap and shares the same
/// referral field.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _referral = TextEditingController();

  bool _busy = false;
  _RefStatus _refStatus = _RefStatus.idle;
  Timer? _refTimer;

  /// True when the code in the field arrived from a referral link rather than
  /// being typed. Drives the "applied from your invite" note — without it a
  /// prefilled field looks like a bug, or like something the user typed and
  /// forgot.
  bool _refFromLink = false;

  /// A link that arrives while this screen is already open.
  StreamSubscription<String>? _linkSub;

  @override
  void initState() {
    super.initState();
    _name.addListener(_rebuild);
    _email.addListener(_rebuild);
    _password.addListener(_rebuild);
    _referral.addListener(_onReferralChanged);
    // The common case: the code was resolved in `main()` before the first
    // frame, either from the tapped link or from the Play Store referrer.
    _applyLinkCode(ReferralLinkService.instance.pendingCode);
    // The rarer one: the app was already open on this screen when the link was
    // tapped. Worth handling — a friend who sends the link while you are
    // mid-signup is exactly the flow the feature is for.
    _linkSub = ReferralLinkService.instance.onCode.listen(_applyLinkCode);
  }

  /// Fill the referral field from a link, but never overwrite something the
  /// user has typed themselves — their own code wins over one we found.
  void _applyLinkCode(String? code) {
    if (code == null || code.isEmpty) return;
    if (!mounted) return;
    if (_referral.text.trim().isNotEmpty && !_refFromLink) return;
    setState(() => _refFromLink = true);
    // Assigning fires `_onReferralChanged`, so the code is validated against a
    // real user exactly as a typed one is — a stale or made-up link still gets
    // rejected rather than silently accepted.
    _referral.text = code;
  }

  @override
  void dispose() {
    _refTimer?.cancel();
    _linkSub?.cancel();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _referral.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  // ---- Derived ----------------------------------------------------------
  String get _fullName => _name.text.trim();
  bool get _pwOk => _password.text.length >= 8;
  bool get _emailOk =>
      _email.text.contains('@') && _email.text.contains('.');

  (String, String) get _nameParts {
    final parts = _fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return ('', '');
    if (parts.length == 1) return (parts.first, '');
    return (parts.first, parts.sublist(1).join(' '));
  }

  /// The referral code to apply, only if it validated as a real code.
  String? get _validReferral {
    final c = _referral.text.trim();
    return (c.isNotEmpty && _refStatus == _RefStatus.valid) ? c : null;
  }

  // ---- Referral validation ----------------------------------------------
  void _onReferralChanged() {
    _refTimer?.cancel();
    final c = _referral.text.trim();
    if (c.isEmpty) {
      setState(() => _refStatus = _RefStatus.idle);
      return;
    }
    setState(() => _refStatus = _RefStatus.checking);
    _refTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final user = await UserRepository.instance.findByReferralCode(c);
        if (!mounted || _referral.text.trim() != c) return;
        setState(() => _refStatus =
            user != null ? _RefStatus.valid : _RefStatus.invalid);
      } catch (_) {
        if (!mounted || _referral.text.trim() != c) return;
        setState(() => _refStatus = _RefStatus.invalid);
      }
    });
  }

  // ---- Actions ----------------------------------------------------------
  bool _referralBlocks() {
    // A non-empty code must resolve to a real user before we let them proceed.
    return _referral.text.trim().isNotEmpty && _refStatus != _RefStatus.valid;
  }

  Future<void> _createAccount() async {
    if (_busy) return;
    if (_fullName.isEmpty) {
      showYnoToast(context, tr('auth.nameRequired'));
      return;
    }
    if (!_emailOk) {
      showYnoToast(context, tr('auth.invalidEmail'));
      return;
    }
    if (!_pwOk) {
      showYnoToast(context, tr('auth.pwMin8'));
      return;
    }
    if (_referralBlocks()) {
      showYnoToast(context, tr('auth.referralInvalid'));
      return;
    }
    setState(() => _busy = true);
    // If an account already exists for this email — often one auto-created when
    // a host added this person to a match or team — offer to log in instead of
    // failing with a bare error.
    final email = _email.text.trim();
    try {
      final existing = await UserRepository.instance.findByEmail(email);
      if (!mounted) return;
      if (existing != null) {
        setState(() => _busy = false);
        await showAccountExistsDialog(context,
            email: email, autoCreated: existing.autoCreated);
        return;
      }
    } catch (_) {
      // Lookup failed (offline, etc.) — fall through; signUp will surface any
      // genuine "email already in use" error.
    }
    if (!mounted) return;
    try {
      final (first, last) = _nameParts;
      await AuthRepository.instance.signUp(
        email: _email.text.trim(),
        password: _password.text,
        firstName: first,
        lastName: last,
        language: L.isAr ? 'Arabic' : 'English',
        referralCode: _validReferral,
      );
      if (!mounted) return;
      _enterApp();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showYnoToast(context, authErrorMessage(e));
      setState(() => _busy = false);
    } catch (_) {
      if (!mounted) return;
      showYnoToast(context, tr('auth.signupFailed'));
      setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    if (_busy) return;
    if (_referralBlocks()) {
      showYnoToast(context, tr('auth.referralInvalid'));
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await AuthRepository.instance
          .signInWithGoogle(
              referralCode: _validReferral,
              // Sign-up always asks which Google account to use — see
              // AuthRepository.signInWithGoogle.
              forceAccountPicker: true);
      if (!mounted) return;
      if (res == null) {
        setState(() => _busy = false); // cancelled
        return;
      }
      _enterApp();
    } catch (_) {
      if (!mounted) return;
      showYnoToast(context, tr('auth.googleFailed'));
      setState(() => _busy = false);
    }
  }

  /// Both signup paths end here, which is the only safe place to spend the
  /// stored referral code: the account now exists and `referredBy` is written.
  /// Clearing any earlier — on arrival, or when the field is filled — would
  /// lose the referral for anyone who backs out of signup and comes back, and
  /// there is no second link to recover it from.
  void _enterApp() {
    ReferralLinkService.instance.clearPending();
    Navigator.of(context).pushNamedAndRemoveUntil(Routes.home, (r) => false);
  }

  // ---- Build ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // No app bar — see the note in login_screen. Its title said CREATE ACCOUNT
    // directly above a heading that says it again, `SafeArea(top: false)` only
    // worked while the AppBar absorbed the status-bar inset, and its back button
    // was the sole way out for a guest sent here from `post_match_screen`.
    return YnoScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (Navigator.of(context).canPop()) ...[
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: BackChip(),
                ),
                const SizedBox(height: 14),
              ],
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('auth.createAccount').toUpperCase(),
                          style: AppText.condensed(
                              size: 32, weight: FontWeight.w800, height: 1.02)),
                      const SizedBox(height: 8),
                      Text(tr('auth.signupSub'),
                          style: AppText.barlow(
                              size: 15, color: AppColors.dim, height: 1.4)),
                      const SizedBox(height: 22),

                      // Google — one tap.
                      SecondaryButton(
                        label: _busy
                            ? tr('auth.pleaseWait')
                            : tr('auth.continueWithGoogle'),
                        condensed: false,
                        fontSize: 16,
                        icon: const Text('G',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.txt)),
                        onTap: _google,
                      ),
                      const SizedBox(height: 18),
                      _orDivider(),
                      const SizedBox(height: 18),

                      // Name.
                      FieldLabel(tr('auth.fullNameLabel')),
                      YnoTextField(
                        controller: _name,
                        hint: tr('auth.fullNameHint'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),

                      // Email.
                      FieldLabel(tr('auth.emailLabel')),
                      YnoTextField(
                        controller: _email,
                        hint: 'you@example.com',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),

                      // Password.
                      FieldLabel(tr('auth.passwordLabel')),
                      YnoTextField(
                        controller: _password,
                        hint: tr('auth.passwordHint8'),
                        obscure: true,
                      ),
                      const SizedBox(height: 8),
                      _pwHint(),
                      const SizedBox(height: 16),

                      // Referral (optional).
                      FieldLabel(tr('auth.referralLabel'), optional: true),
                      YnoTextField(
                        controller: _referral,
                        hint: 'e.g. AB12CD',
                        textCapitalization: TextCapitalization.characters,
                      ),
                      _refNote(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(tr('auth.consent'),
                  textAlign: TextAlign.center,
                  style: AppText.barlow(
                      size: 11, color: AppColors.dim2, height: 1.4)),
              const SizedBox(height: 10),
              PrimaryButton(
                label: _busy
                    ? tr('auth.creatingAccount')
                    : tr('auth.createAccount'),
                onTap: _busy ? null : _createAccount,
              ),
              const SizedBox(height: 16),
              // Someone a host already added doesn't need to sign up at all —
              // they claim the account that exists. Without this the only way
              // in is to attempt a sign-up and be caught by
              // showAccountExistsDialog.
              ClaimAccountLink(email: _email.text),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orDivider() => Row(
        children: [
          const Expanded(child: Divider(color: AppColors.line, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(tr('auth.or').toUpperCase(),
                style: AppText.label(color: AppColors.dim2)),
          ),
          const Expanded(child: Divider(color: AppColors.line, height: 1)),
        ],
      );

  Widget _pwHint() {
    final ok = _pwOk;
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: ok ? AppColors.primary : AppColors.surface2,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ok ? AppColors.primary : AppColors.line),
          ),
          alignment: Alignment.center,
          child: ok
              ? const Icon(Icons.check, size: 12, color: AppColors.ink)
              : null,
        ),
        const SizedBox(width: 8),
        Text(tr('auth.passwordHint8'),
            style: AppText.barlow(
                size: 12, color: ok ? AppColors.txt : AppColors.dim)),
      ],
    );
  }

  Widget _refNote() {
    String? note;
    switch (_refStatus) {
      case _RefStatus.idle:
        return const SizedBox.shrink();
      case _RefStatus.checking:
        note = tr('auth.referralChecking');
      case _RefStatus.valid:
        // A code that filled itself in needs to say so, or it reads as a bug.
        note = _refFromLink
            ? tr('auth.referralFromLink')
            : tr('auth.referralValid');
      case _RefStatus.invalid:
        // A dead link is a different failure from a mistyped code: there is
        // nothing for the user to correct, so don't tell them to check it.
        note = _refFromLink
            ? tr('auth.referralLinkExpired')
            : tr('auth.referralInvalid');
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(note,
          style: AppText.barlow(
              size: 12.5,
              weight: FontWeight.w600,
              color: _refStatus == _RefStatus.valid
                  ? AppColors.txt
                  : AppColors.dim)),
    );
  }
}

/// An account already exists for [email]. If it was [autoCreated] (a host set it
/// up for this person when adding them to a match/team), offer to **claim** it
/// with an emailed code; otherwise just point them to the login screen.
///
/// This dialog used to print the shared default password on screen for any
/// auto-created account, which meant knowing someone's email address was enough
/// to sign in as them. The claim flow ([Routes.claim]) replaced that: the code
/// goes to the address, and the server hands back a credential only on proof of
/// it. Never reintroduce a password here.
///
/// Kept a top-level function (not a State method) so the "an auto-created
/// account is claimed, a real one is not" contract is unit-testable.
Future<void> showAccountExistsDialog(
  BuildContext context, {
  required String email,
  required bool autoCreated,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.line2)),
      title: Text(tr('auth.accountExistsTitle'),
          style: AppText.condensed(size: 20, weight: FontWeight.w800)),
      content: Text(
          autoCreated
              ? tr('auth.accountExistsAutoBody')
              : tr('auth.accountExistsRealBody'),
          style: AppText.barlow(size: 14, color: AppColors.dim, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: Text(tr('auth.useAnotherEmail'),
              style: AppText.barlow(
                  size: 14, weight: FontWeight.w700, color: AppColors.dim)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(dialogCtx);
            if (autoCreated) {
              // The claim flow proves the address before handing over the
              // account — see ClaimAccountScreen.
              Navigator.of(context)
                  .pushReplacementNamed(Routes.claim, arguments: email);
            } else {
              Navigator.of(context).pushReplacementNamed(
                Routes.login,
                arguments: {'email': email},
              );
            }
          },
          child: Text(
              autoCreated ? tr('auth.claimAction') : tr('auth.logInAction'),
              style: AppText.barlow(
                  size: 14, weight: FontWeight.w800, color: AppColors.txt)),
        ),
      ],
    ),
  );
}
