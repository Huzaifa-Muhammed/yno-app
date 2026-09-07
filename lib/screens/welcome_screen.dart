import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../links.dart';
import '../routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/yno_scaffold.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  /// A tappable legal link inside the consent sentence.
  ///
  /// A WidgetSpan rather than a TapGestureRecognizer, so there is no
  /// recognizer to dispose — this screen is stateless, and a leaked
  /// recognizer is the usual cost of doing it the other way.
  ///
  /// These two words used to be plain grey text that merely LOOKED like
  /// links: styled as links, doing nothing. App review checks that the terms
  /// and privacy policy are actually reachable before you sign up.
  InlineSpan _legalSpan(String label, String url) => WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: () =>
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: Text(
            label,
            style: AppText.barlow(size: 12, color: AppColors.dim, height: 1.5)
                .copyWith(decoration: TextDecoration.underline),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return YnoScaffold(
      glow: const [
        ScreenGlow(color: Color(0x12D4FF00), center: Alignment(0, -1), radius: 0.8),
      ],
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: AppText.condensed(size: 84, weight: FontWeight.w800, height: 0.82),
                        children: const [
                          TextSpan(text: 'YN'),
                          TextSpan(text: 'O', style: TextStyle(color: AppColors.primary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: AppText.condensed(size: 26, weight: FontWeight.w700, height: 1.05),
                        children: [
                          TextSpan(text: tr('auth.taglinePlay')),
                          const TextSpan(text: '.', style: TextStyle(color: AppColors.dim2)),
                          TextSpan(text: ' ${tr('auth.taglineEarn')}'),
                          const TextSpan(text: '.', style: TextStyle(color: AppColors.dim2)),
                          TextSpan(text: ' ${tr('auth.taglineRecognised')}', style: const TextStyle(color: AppColors.primary)),
                          const TextSpan(text: '.', style: TextStyle(color: AppColors.dim2)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Text(
                        tr('auth.welcomeSubtitle'),
                        textAlign: TextAlign.center,
                        style: AppText.barlow(size: 15, color: AppColors.dim, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 46),
              child: Column(
                children: [
                  PrimaryButton(
                    label: tr('auth.createAccount'),
                    onTap: () => Navigator.of(context).pushNamed(Routes.signup),
                  ),
                  const SizedBox(height: 12),
                  SecondaryButton(
                    label: tr('auth.login'),
                    onTap: () => Navigator.of(context).pushNamed(Routes.login),
                  ),
                  const SizedBox(height: 16),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: AppText.barlow(size: 12, color: AppColors.dim2, height: 1.5),
                      children: [
                        TextSpan(text: '${tr('auth.agreePrefix')}\n'),
                        _legalSpan(tr('auth.terms'), kTermsUrl),
                        TextSpan(text: ' ${tr('auth.and')} '),
                        _legalSpan(tr('auth.privacyPolicy'), kPrivacyUrl),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
