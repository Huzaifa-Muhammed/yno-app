import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
import '../services/match_repository.dart';
import '../services/models.dart';
import '../services/user_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'buttons.dart';
import 'confirm.dart';
import 'header.dart';
import 'inputs.dart';
import 'motion.dart';

/// Open the match-creation flow. Football is the only live sport, so this goes
/// straight into match creation — gating first on the one-time football profile
/// (Section 2 / 5), then on the **one-draft-at-a-time** rule. Shared by Home,
/// the Draft page and the side drawer so there is a single entry point.
Future<void> openCreateMatch(BuildContext context) async {
  final uid = AuthRepository.instance.uid;
  var needsProfile = false;
  if (uid != null) {
    final user = await UserRepository.instance.getUser(uid);
    needsProfile = user != null && !user.sportProfileDone;
  }
  if (!context.mounted) return;
  if (needsProfile) {
    await Navigator.pushNamed(context, Routes.footballProfile);
    if (!context.mounted) return;
  }

  // A user may hold only ONE draft (a created-but-never-started match). If one
  // already exists, creating another would silently strand it, so make them
  // deal with it first. `getMyDraft` already ignores drafts past their TTL, so
  // the sweep is fired off for cleanup only — not awaited, since making the
  // user wait on a delete just to open the create screen is a bad trade.
  if (uid != null) {
    unawaited(MatchRepository.instance.sweepStaleDrafts(uid));
    final draft = await MatchRepository.instance.getMyDraft(uid);
    if (!context.mounted) return;
    if (draft != null) {
      await _showDraftExistsSheet(context, draft);
      return;
    }
  }

  if (!context.mounted) return;
  Navigator.pushNamed(context, Routes.matchCreate);
}

/// Blocks a second draft: offers to resume the existing one or throw it away.
Future<void> _showDraftExistsSheet(
    BuildContext context, MatchModel draft) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      side: BorderSide(color: AppColors.line2),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('📝', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 10),
            Text(tr('draft.existsTitle'),
                style: AppText.condensed(size: 24, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              '${tr('draft.existsBody')} '
              '"${draft.teamAName} ${tr('match.vs')} ${draft.teamBName}".',
              style:
                  AppText.barlow(size: 14, color: AppColors.dim, height: 1.45),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: tr('draft.resume'),
              onTap: () {
                Navigator.pop(sheetCtx);
                Navigator.pushNamed(context, Routes.lobby,
                    arguments: draft.id);
              },
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: tr('draft.deleteAndCreate'),
              danger: true,
              onTap: () async {
                Navigator.pop(sheetCtx);
                final ok = await showConfirm(
                  context,
                  title: tr('draft.deleteTitle'),
                  message: '${tr('draft.deleteBody')} '
                      '"${draft.teamAName} ${tr('match.vs')} ${draft.teamBName}"',
                  confirmLabel: tr('draft.delete'),
                  danger: true,
                );
                if (!ok || !context.mounted) return;
                try {
                  await MatchRepository.instance.quitDiscard(draft.id);
                } catch (_) {
                  if (context.mounted) {
                    showYnoToast(context, tr('draft.deleteFailed'));
                  }
                  return;
                }
                if (!context.mounted) return;
                Navigator.pushNamed(context, Routes.matchCreate);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// The Home "يلا نلعب" action: create a match, or join one with a code.
Future<void> showLetsPlaySheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      side: BorderSide(color: AppColors.line2),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('home.letsPlay').toUpperCase(),
                textAlign: TextAlign.center,
                style: AppText.condensed(
                    size: 22, weight: FontWeight.w800, letterSpacing: 2)),
            const SizedBox(height: 16),
            _PlayOption(
              emoji: '⚽',
              label: tr('draft.createMatch'),
              sub: tr('home.createMatchSub'),
              onTap: () {
                Navigator.pop(sheetCtx);
                openCreateMatch(context);
              },
            ),
            const SizedBox(height: 10),
            // "Join" means join a MATCH, and nothing else — it goes straight to
            // one code field. Joining a team lives in the side drawer
            // (`Routes.joinTeam`), because asking "match or team?" here made
            // every player answer a question that only mattered to someone who
            // was not trying to play right now.
            _PlayOption(
              emoji: '🔑',
              label: tr('home.joinMatch'),
              sub: tr('home.joinWithCodeSub'),
              onTap: () {
                Navigator.pop(sheetCtx);
                showJoinByCodeSheet(context);
              },
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(sheetCtx),
              child: Text(tr('common.cancel'),
                  style: AppText.barlow(size: 14, color: AppColors.dim)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// One row of the Let's Play sheet — emoji, label, subtitle, chevron.
class _PlayOption extends StatelessWidget {
  const _PlayOption({
    required this.emoji,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line2, width: 1.5),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppText.barlow(
                          size: 16.5, weight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style:
                          AppText.barlow(size: 12.5, color: AppColors.dim2)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 22, color: AppColors.dim),
          ],
        ),
      ),
    );
  }
}

/// Prompt for a code and join by it. When [allowTeam] (the default), the sheet
/// first asks whether the code is for a Match or a Team, then joins accordingly:
/// a match code joins the code's side; a team code adds the user to the team.
/// Pass `allowTeam: false` for a match-only prompt.
/// Join a **match** by code. Matches only.
///
/// This used to carry a Match / Team tab pair, so "Join" from the Let's Play
/// sheet asked a second question before it could do anything. Joining a team is
/// a different errand — you do it once, not before a game — so it moved to its
/// own page in the side drawer (`Routes.joinTeam`, `join_team_screen.dart`).
/// See the sheet's `_PlayOption` above.
Future<void> showJoinByCodeSheet(BuildContext context) async {
  // 🔑 The sheet owns its own controller and this function does the navigating
  // *after* the sheet is gone. Both halves matter, and both were bugs:
  //
  //  1. `showModalBottomSheet` completes its future the moment the route is
  //     popped, NOT when the exit animation ends — the subtree keeps rebuilding
  //     through it. Disposing a controller here therefore disposed one the
  //     TextField was still rebuilding with ('A TextEditingController was used
  //     after being disposed'). A State's dispose() runs when the route is
  //     actually gone, which is the only correct moment.
  //  2. Pushing the lobby route while the sheet was still closing forced
  //     exactly that rebuild, so the two faults triggered each other.
  final result = await showModalBottomSheet<(String, String)?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      side: BorderSide(color: AppColors.line2),
    ),
    builder: (_) => const _JoinByCodeSheet(),
  );
  if (result == null || !context.mounted) return;
  final (route, matchId) = result;
  Navigator.pushNamed(context, route, arguments: matchId);
}

/// The body of [showJoinByCodeSheet]. Stateful purely so the
/// [TextEditingController] dies with the route rather than with the future.
class _JoinByCodeSheet extends StatefulWidget {
  const _JoinByCodeSheet();

  @override
  State<_JoinByCodeSheet> createState() => _JoinByCodeSheetState();
}

class _JoinByCodeSheetState extends State<_JoinByCodeSheet> {
  final _code = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final uid = AuthRepository.instance.uid;
    final entered = _code.text.trim().toUpperCase();
    if (entered.isEmpty || uid == null || _busy) return;
    setState(() => _busy = true);
    final found = await MatchRepository.instance.findByCode(entered);
    if (found == null) {
      if (!mounted) return;
      setState(() => _busy = false);
      showYnoToast(context, tr('home.noMatchFound'));
      return;
    }
    final (match, side) = found;
    final me = await UserRepository.instance.getUser(uid);
    await MatchRepository.instance.joinMatch(
      matchId: match.id,
      uid: uid,
      name: me?.name ?? 'Player',
      team: side,
      position: me?.position,
      joinedVia: 'code',
    );
    if (!mounted) return;
    // Hand the destination back; the caller navigates once this route is gone.
    final route =
        match.status == MatchStatus.live ? Routes.live : Routes.lobby;
    Navigator.pop(context, (route, match.id));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('home.joinAMatch'),
                style: AppText.condensed(size: 24, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(tr('home.joinCodePrompt'),
                style: AppText.barlow(size: 13, color: AppColors.dim)),
            const SizedBox(height: 16),
            YnoTextField(
              controller: _code,
              hint: tr('home.matchCodeHint'),
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _join(),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: _busy ? tr('home.joining') : tr('home.joinMatch'),
              onTap: _join,
            ),
          ],
        ),
      ),
    );
  }
}
