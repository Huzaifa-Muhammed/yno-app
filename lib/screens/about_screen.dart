import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../links.dart';
import '../services/app_version.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/header.dart';
import '../widgets/yno_scaffold.dart';

/// About YNO (Section 11) — version number, terms and privacy.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// The real build version (from pubspec via package_info), not a literal.
  String get _version => AppVersion.current;

  @override
  Widget build(BuildContext context) {
    return YnoScaffold(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
          children: [
            ScreenHeader(
              title: tr('drawer.about'),
              onBack: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: 12),
            _header(),
            const SizedBox(height: 24),
            _label(tr('home.termsTitle')),
            _paragraph(tr('home.termsBody')),
            _readFull(tr('home.readFullTerms'), kTermsUrl),
            const SizedBox(height: 18),
            _label(tr('home.privacyTitle')),
            _paragraph(tr('home.privacyBody')),
            _readFull(tr('home.readFullPrivacy'), kPrivacyUrl),
          ],
        ),
      ),
    );
  }

  /// Link out to the full document on the website.
  ///
  /// The paragraphs above are a plain-language summary and deliberately stay
  /// that way — the binding text is the hosted version, which is also the URL
  /// submitted to the app stores. Two copies of a legal document would drift.
  Widget _readFull(String label, String url) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: GestureDetector(
          onTap: () =>
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: Text(
            label,
            style: AppText.barlow(
                    size: 13,
                    weight: FontWeight.w700,
                    color: AppColors.primary)
                .copyWith(decoration: TextDecoration.underline),
          ),
        ),
      );

  Widget _header() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            Text('YNO',
                style: AppText.condensed(size: 44, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('يلا نلعب',
                style: AppText.condensed(
                    size: 20, weight: FontWeight.w700, color: AppColors.dim)),
            // Hidden rather than blank if package info was unavailable.
            if (_version.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text('${tr('home.version')} $_version',
                    style: AppText.barlow(
                        size: 12,
                        weight: FontWeight.w700,
                        letterSpacing: 1.2)),
              ),
            ],
          ],
        ),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t.toUpperCase(),
            style: AppText.barlow(
                size: 11,
                weight: FontWeight.w700,
                color: AppColors.dim2,
                letterSpacing: 1.1)),
      );

  Widget _paragraph(String text) => Text(text,
      style: AppText.barlow(size: 14, color: AppColors.dim, height: 1.6));
}
