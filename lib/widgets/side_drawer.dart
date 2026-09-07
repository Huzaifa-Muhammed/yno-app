import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/app_version.dart';
import '../services/auth_repository.dart';
import '../services/match_repository.dart';
import '../services/models.dart';
import '../services/user_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'common.dart';
import 'confirm.dart';
import 'match_actions.dart';

/// Right-hand slide-out drawer (hamburger menu, Section 11). Holds all the
/// secondary navigation the bottom bar does not surface.
class YnoDrawer extends StatelessWidget {
  const YnoDrawer({super.key});

  void _go(BuildContext context, String route) {
    Navigator.of(context).pop(); // close drawer
    Navigator.of(context).pushNamed(route);
  }

  /// Sign out, behind the app's shared confirmation (see `showConfirm`). This
  /// used to be a bespoke dialog here — it had drifted into the old wireframe
  /// styling (square corners) and had no counterpart on the settings screen,
  /// which signed out on a single tap. Not danger-red: signing out loses
  /// nothing (§20).
  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showConfirm(
      context,
      title: tr('home.logoutTitle'),
      message: tr('home.logoutBody'),
      confirmLabel: tr('drawer.logout'),
    );
    if (!confirmed || !context.mounted) return;
    Navigator.of(context).pop(); // close drawer
    await AuthRepository.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(Routes.welcome, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthRepository.instance.uid;
    return Drawer(
      width: 306,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: StreamBuilder<AppUser?>(
          stream: uid == null
              ? const Stream.empty()
              : UserRepository.instance.watchUser(uid),
          builder: (context, snap) {
            final user = snap.data;
            return ListView(
              padding: const EdgeInsets.only(top: 10, bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 6, 16, 18),
                  child: Row(
                    children: [
                      InitialsAvatar(
                        initials: user?.initials ?? '··',
                        size: 50,
                        fontSize: 20,
                        photoUrl: user?.photoUrl,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.name ?? tr('common.loading'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.condensed(
                                    size: 20,
                                    weight: FontWeight.w800,
                                    height: 1)),
                            Text('@${user?.handle ?? '…'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.barlow(
                                    size: 13, color: AppColors.dim)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.line),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.close,
                              size: 18, color: AppColors.dim),
                        ),
                      ),
                    ],
                  ),
                ),
                // NOTE: the points balance card that used to sit here was
                // removed — points already have a home on the Home top bar
                // (which opens Refer & Earn) and on the profile.
                _group(tr('home.sectionProfile')),
                _item(context, '👤', tr('drawer.myProfile'), Routes.profile),
                // My Teams and Friends are deliberately absent: Home has a My
                // Teams button, and friends live on the Community page.
                // `Routes.friends` still exists and is still reached by tapping
                // a friend-request notification — but requests can now be
                // answered on the bell itself, so nothing depends on finding it.
                _group(tr('home.sectionPlay')),
                _action(context, '➕', tr('drawer.createMatch'), () {
                  Navigator.of(context).pop(); // close drawer
                  openCreateMatch(context);
                }),
                _matchesItem(context, uid),
                // Joining a club by code. It used to be a tab inside the Let's
                // Play sheet's join step, which made every player on their way
                // into a game answer "match or team?" first. It is a once-ever
                // errand, so it lives here instead.
                _item(context, '🛡️', tr('drawer.joinTeam'), Routes.joinTeam),
                _group(tr('home.sectionMore')),
                _item(context, '🎁', tr('drawer.referral'), Routes.referral),
                _item(context, '⚙️', tr('drawer.settings'), Routes.settings),
                _item(context, '❓', tr('drawer.help'), Routes.help),
                // Sit directly under Help on purpose: someone who opened Help
                // and did not find their answer is exactly who needs these,
                // and this is the point where they are looking.
                _item(context, '🐞', tr('drawer.reportBug'), Routes.reportBug),
                _item(context, '💡', tr('drawer.suggestion'), Routes.suggestion),
                _item(context, 'ℹ️', tr('drawer.about'), Routes.about),
                _action(context, '🌐', tr('drawer.language'),
                    () => showLanguagePicker(context)),
                const SizedBox(height: 8),
                _action(context, '↩︎', tr('drawer.logout'),
                    () => _confirmLogout(context)),
                const SizedBox(height: 20),
                Center(
                  // Brand + real build version. Not translated: it is a name
                  // and a number, identical in both languages.
                  child: Text(
                      AppVersion.current.isEmpty
                          ? 'YNO'
                          : 'YNO v${AppVersion.current}',
                      style: AppText.barlow(size: 11, color: AppColors.dim2)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _group(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
        child: Text(title.toUpperCase(),
            style: AppText.barlow(
                size: 11,
                weight: FontWeight.w700,
                color: AppColors.dim2,
                letterSpacing: 1.4)),
      );

  /// "Draft Matches" — the one unstarted draft, plus the ongoing match and
  /// played history.
  ///
  /// Wears a **red dot** (deliberately not a count — client decision,
  /// 2026-08-18) while a draft is waiting, because a draft self-deletes after
  /// 2 days; the same dot is mirrored on the home hamburger so it is visible
  /// before opening the drawer.
  Widget _matchesItem(BuildContext context, String? uid) {
    return StreamBuilder<MatchModel?>(
      stream: uid == null
          ? const Stream.empty()
          : MatchRepository.instance.watchMyDraft(uid),
      builder: (context, snap) => _action(
        context,
        '📝',
        tr('drawer.draftMatches'),
        () => _go(context, Routes.matches),
        dot: snap.data == null ? null : AppColors.loss,
      ),
    );
  }

  Widget _item(BuildContext context, String emoji, String label, String route,
          {Color color = AppColors.txt}) =>
      _action(context, emoji, label, () => _go(context, route), color: color);

  Widget _action(BuildContext context, String emoji, String label,
      VoidCallback onTap,
      {Color color = AppColors.txt, Color? dot}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
        child: Row(
          children: [
            SizedBox(
                width: 22,
                child: Text(emoji, style: const TextStyle(fontSize: 18))),
            const SizedBox(width: 14),
            Text(label,
                style: AppText.barlow(
                    size: 16, weight: FontWeight.w600, color: color)),
            if (dot != null) ...[
              const SizedBox(width: 9),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

