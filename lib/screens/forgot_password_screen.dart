import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/header.dart';
import '../widgets/inputs.dart';
import '../widgets/yno_scaffold.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      showYnoToast(context, tr('auth.invalidEmail'));
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthRepository.instance.sendPasswordReset(email);
      if (!mounted) return;
      setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showYnoToast(context, authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _backToLogin() =>
      Navigator.of(context).pushReplacementNamed(Routes.login);

  @override
  Widget build(BuildContext context) {
    return YnoScaffold(
      appBarTitle: tr('auth.resetPasswordTitle'),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: _sent ? _confirmation() : _form(),
        ),
      ),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('auth.resetPasswordHeading'),
            style: AppText.condensed(
                size: 42, weight: FontWeight.w800, height: 0.95)),
        const SizedBox(height: 8),
        Text(tr('auth.resetPasswordSub'),
            style: AppText.barlow(size: 15, color: AppColors.dim)),
        const SizedBox(height: 28),
        FieldLabel(tr('auth.emailLabel')),
        YnoTextField(
          controller: _email,
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _send(),
        ),
        const SizedBox(height: 18),
        _InfoBox(
          text: tr('auth.recoveryInfo'),
        ),
        const Spacer(),
        PrimaryButton(
          label: _busy ? tr('auth.sending') : tr('auth.sendResetLink'),
          onTap: _send,
        ),
      ],
    );
  }

  Widget _confirmation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line2, width: 1.5),
          ),
          alignment: Alignment.center,
          child: const Text('✉️', style: TextStyle(fontSize: 30)),
        ),
        const SizedBox(height: 24),
        Text(tr('auth.checkEmailHeading'),
            style: AppText.condensed(
                size: 42, weight: FontWeight.w800, height: 0.95)),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            style: AppText.barlow(size: 15, color: AppColors.dim, height: 1.5),
            children: [
              TextSpan(text: tr('auth.resetSentPrefix')),
              TextSpan(
                text: _email.text.trim(),
                style: const TextStyle(
                    color: AppColors.txt, fontWeight: FontWeight.w700),
              ),
              TextSpan(text: tr('auth.resetSentSuffix')),
            ],
          ),
        ),
        const Spacer(),
        PrimaryButton(label: tr('auth.backToLogin'), onTap: _backToLogin),
        const SizedBox(height: 8),
        GhostButton(
          label: tr('auth.sendAgain'),
          onTap: () => setState(() => _sent = false),
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ℹ️', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: AppText.barlow(
                    size: 13, color: AppColors.dim, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
