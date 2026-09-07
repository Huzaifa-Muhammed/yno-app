import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
import '../services/otp_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/header.dart';
import '../widgets/inputs.dart';
import '../widgets/yno_scaffold.dart';

/// Permanent account deletion, in two deliberate steps.
///
/// Reached from **Settings**, not the drawer — a destructive, irreversible
/// action does not belong one tap from the hamburger, next to navigation.
///
/// The two gates are different on purpose and neither replaces the other:
///
///  1. **A 10-second countdown** on the warning. Not theatre: the whole point is
///     that the confirm button is *not there to be hit* while the warning is
///     still being read. It defeats muscle memory and mis-taps, which is what
///     accidental deletion actually is.
///  2. **An emailed one-time code.** That proves the person holding the phone
///     also holds the mailbox, so a borrowed or stolen unlocked handset cannot
///     wipe the account.
///
/// The deletion itself happens on the server (see [OtpService.verifyAndDeleteAccount]).
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

enum _Step { warning, code }

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  static const _holdSeconds = 10;

  final _code = TextEditingController();

  _Step _step = _Step.warning;
  int _remaining = _holdSeconds;
  Timer? _ticker;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _ticker?.cancel();
    setState(() => _remaining = _holdSeconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) t.cancel();
    });
  }

  /// The address the code will be sent to, shown so the user can check it.
  ///
  /// Guarded because this is read during `build`: if the auth layer is not
  /// ready the screen must still render its warning rather than throw. An empty
  /// string just omits the address — the request itself re-checks and fails
  /// cleanly with `unauthorised`.
  String get _email {
    try {
      return AuthRepository.instance.currentUser?.email ?? '';
    } catch (_) {
      return '';
    }
  }

  // ---- step 1 -> 2 --------------------------------------------------------
  Future<void> _sendCode() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await OtpService.instance.requestDeletionOtp();
      if (!mounted) return;
      setState(() {
        _step = _Step.code;
        _busy = false;
      });
    } on OtpException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = tr('auth.otpErrGeneric');
        _busy = false;
      });
    }
  }

  // ---- step 2: the point of no return ------------------------------------
  Future<void> _confirmDelete() async {
    if (_busy) return;
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = tr('auth.otpEnterCode'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await OtpService.instance.verifyAndDeleteAccount(code);
      if (!mounted) return;
      // The account is gone and OtpService has signed out. Clear the stack so
      // Back cannot walk into a screen that expects a signed-in user.
      Navigator.of(context)
          .pushNamedAndRemoveUntil(Routes.welcome, (_) => false);
      showYnoToast(context, tr('auth.deleteDone'));
    } on OtpException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
        // A burned code sends them back to the start — there is nothing left to
        // type, and the countdown should be served again before a fresh one.
        if (e.code == 'too_many_attempts' || e.code == 'code_expired') {
          _step = _Step.warning;
          _code.clear();
          _startCountdown();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = tr('auth.otpErrGeneric');
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return YnoScaffold(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            ScreenHeader(
              title: tr('auth.deleteTitle'),
              onBack: _busy ? null : () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: 14),
            if (_step == _Step.warning) ..._warningStep() else ..._codeStep(),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: AppText.barlow(
                    size: 13.5, weight: FontWeight.w600, color: AppColors.loss),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---- step 1 -------------------------------------------------------------
  List<Widget> _warningStep() {
    final ready = _remaining <= 0;
    return [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.loss.withValues(alpha: 0.08),
          border: Border.all(color: AppColors.loss.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('auth.deleteWarnTitle'),
                    style: AppText.condensed(
                        size: 20, weight: FontWeight.w800, color: AppColors.loss),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tr('auth.deleteWarnBody'),
              style: AppText.barlow(size: 14, height: 1.5, color: AppColors.txt),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text(tr('auth.deleteLosesTitle'),
          style: AppText.barlow(
              size: 11,
              weight: FontWeight.w800,
              color: AppColors.dim2,
              letterSpacing: 1.4)),
      const SizedBox(height: 8),
      _bullet(tr('auth.deleteLoses1')),
      _bullet(tr('auth.deleteLoses2')),
      _bullet(tr('auth.deleteLoses3')),
      const SizedBox(height: 14),
      Text(
        tr('auth.deleteKeepsBody'),
        style: AppText.barlow(size: 13, height: 1.5, color: AppColors.dim),
      ),
      const SizedBox(height: 20),
      Text(
        '${tr('auth.deleteCodeToPre')} $_email',
        style: AppText.barlow(size: 13.5, height: 1.5, color: AppColors.dim),
      ),
      const SizedBox(height: 18),

      // The confirm button stays disabled — and says why — until the hold is up.
      PrimaryButton(
        danger: true,
        label: _busy
            ? tr('auth.otpSending')
            : (ready
                ? tr('auth.deleteContinue')
                : '${tr('auth.deleteWait')} $_remaining'),
        onTap: (ready && !_busy) ? _sendCode : null,
      ),
      const SizedBox(height: 10),
      SecondaryButton(
        label: tr('common.cancel'),
        onTap: _busy ? null : () => Navigator.of(context).maybePop(),
      ),
    ];
  }

  // ---- step 2 -------------------------------------------------------------
  List<Widget> _codeStep() {
    return [
      Text(tr('auth.deleteCodeSentTitle'),
          style: AppText.condensed(size: 22, weight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(
        '${tr('auth.deleteCodeSentBody')} $_email',
        style: AppText.barlow(size: 14, height: 1.5, color: AppColors.dim),
      ),
      const SizedBox(height: 18),
      FieldLabel(tr('auth.otpCodeLabel')),
      YnoTextField(
        controller: _code,
        hint: '••••••',
        keyboardType: TextInputType.number,
        onSubmitted: (_) => _confirmDelete(),
      ),
      const SizedBox(height: 20),
      PrimaryButton(
        danger: true,
        label: _busy ? tr('auth.deleteDeleting') : tr('auth.deleteConfirmFinal'),
        onTap: _busy ? null : _confirmDelete,
      ),
      const SizedBox(height: 10),
      SecondaryButton(
        label: tr('common.cancel'),
        onTap: _busy ? null : () => Navigator.of(context).maybePop(),
      ),
    ];
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•',
                style: AppText.barlow(size: 14, color: AppColors.loss)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: AppText.barlow(
                      size: 14, height: 1.45, color: AppColors.txt)),
            ),
          ],
        ),
      );
}
