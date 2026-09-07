import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/auth_repository.dart';
import '../services/user_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/header.dart';
import '../widgets/yno_scaffold.dart';

/// Position picker — the single piece of sport-profile data collected during
/// onboarding. Shown on Home right after sign up (and as a gate before the
/// first match if still unset). Preferred foot defaults to Right and skill is
/// no longer collected here; both are editable later in Edit Profile.
///
/// Saves via [UserRepository.completeSportProfile], then pops with `true` so the
/// caller can proceed.
class FootballProfileScreen extends StatefulWidget {
  const FootballProfileScreen({super.key});

  @override
  State<FootballProfileScreen> createState() => _FootballProfileScreenState();
}

class _FootballProfileScreenState extends State<FootballProfileScreen> {
  String? _position;
  bool _busy = false;

  Future<void> _finish() async {
    if (_busy) return;
    if (_position == null) {
      showYnoToast(context, tr('auth.pickOptionToContinue'));
      return;
    }
    setState(() => _busy = true);
    final uid = AuthRepository.instance.uid;
    try {
      if (uid != null) {
        await UserRepository.instance
            .completeSportProfile(uid, position: _position!);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      showYnoToast(context, tr('auth.saveProfileFailed'));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return YnoScaffold(
      appBarTitle: tr('auth.sportProfileTitle'),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: SingleChildScrollView(child: _body())),
              const SizedBox(height: 8),
              PrimaryButton(
                label: _busy ? tr('common.saving') : tr('auth.finishSetup'),
                onTap: _finish,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String title, String sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: AppText.condensed(
                  size: 34, weight: FontWeight.w800, height: 1.02)),
          const SizedBox(height: 8),
          Text(sub, style: AppText.barlow(size: 15, color: AppColors.dim)),
          const SizedBox(height: 26),
        ],
      );

  Widget _body() {
    final opts = [
      ('🧤', 'Goalkeeper', tr('auth.posGoalkeeper')),
      ('🛡️', 'Defender', tr('auth.posDefender')),
      ('🎯', 'Midfielder', tr('auth.posMidfielder')),
      ('⚡', 'Forward', tr('auth.posForward')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(tr('auth.positionTitle'), tr('auth.positionSub')),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            for (final o in opts)
              GestureDetector(
                onTap: () => setState(() => _position = o.$2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    color: _position == o.$2
                        ? AppColors.primaryGlow(0.10)
                        : AppColors.surface2,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: _position == o.$2
                            ? AppColors.primary
                            : AppColors.line,
                        width: _position == o.$2 ? 2 : 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(o.$1, style: const TextStyle(fontSize: 30)),
                      const SizedBox(height: 8),
                      Text(o.$3,
                          style: AppText.barlow(
                              size: 16,
                              weight: FontWeight.w700,
                              color: _position == o.$2
                                  ? AppColors.txt
                                  : AppColors.dim)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
