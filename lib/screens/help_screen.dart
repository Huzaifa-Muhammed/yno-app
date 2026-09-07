import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../links.dart';
import '../routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/header.dart';
import '../widgets/yno_scaffold.dart';

/// Help & Support (Section 11) — FAQ, how-to and a contact stub.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  List<List<String>> get _faqs => <List<String>>[
        [tr('home.faqStartQ'), tr('home.faqStartA')],
        [tr('home.faqJoinQ'), tr('home.faqJoinA')],
        [tr('home.faqPointsQ'), tr('home.faqPointsA')],
        [tr('home.faqTeamQ'), tr('home.faqTeamA')],
      ];

  @override
  Widget build(BuildContext context) {
    return YnoScaffold(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
          children: [
            ScreenHeader(
              title: tr('drawer.help'),
              onBack: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: 12),
            _label(tr('home.frequentlyAsked')),
            ..._faqs.map((f) => _FaqTile(question: f[0], answer: f[1])),
            const SizedBox(height: 22),
            _label(tr('home.stillNeedHelp')),
            _contactCard(context),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('home.contactYnoTeam'),
                style: AppText.barlow(size: 15, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(tr('home.contactBlurb'),
                style: AppText.barlow(size: 13, color: AppColors.dim)),
            const SizedBox(height: 14),
            // The two working routes out of here, added 2026-09-07 with the
            // feedback feature. Before this, "Still Need Help?" led only to the
            // rows below — which display an address and do nothing else, so a
            // user who got here with a problem had no way to report it from
            // inside the app.
            SecondaryButton(
              label: '🐞 ${tr('drawer.reportBug')}',
              fontSize: 15,
              height: 48,
              onTap: () => Navigator.pushNamed(context, Routes.reportBug),
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: '💡 ${tr('drawer.suggestion')}',
              fontSize: 15,
              height: 48,
              onTap: () => Navigator.pushNamed(context, Routes.suggestion),
            ),
            const SizedBox(height: 14),
            _contactRow(context, '✉️', kSupportEmail),
          ],
        ),
      );

  Widget _contactRow(BuildContext context, String emoji, String value) =>
      GestureDetector(
        onTap: () => showYnoToast(context, value),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Text(value,
                style: AppText.barlow(size: 14, weight: FontWeight.w600)),
          ],
        ),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(t.toUpperCase(),
            style: AppText.barlow(
                size: 11,
                weight: FontWeight.w700,
                color: AppColors.dim2,
                letterSpacing: 1.1)),
      );
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.question,
                        style: AppText.barlow(
                            size: 15, weight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Icon(_open ? Icons.remove : Icons.add,
                      size: 18, color: AppColors.dim),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(widget.answer,
                  style: AppText.barlow(
                      size: 13, color: AppColors.dim, height: 1.5)),
            ),
        ],
      ),
    );
  }
}
