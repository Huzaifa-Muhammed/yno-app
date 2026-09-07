import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
import '../services/match_repository.dart';
import '../services/models.dart';
import '../services/notification_repository.dart';
import '../services/referral_link_service.dart';
import '../services/user_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/header.dart';
import '../widgets/match_actions.dart';
import '../widgets/motion.dart';
import '../widgets/side_drawer.dart';
import '../widgets/yno_scaffold.dart';

/// Home (Section 2) — the app's single landing surface, rebuilt from
/// `.claude/design/design.html`.
///
/// There is no bottom navigation any more: everything is reachable from this
/// screen's top bar (profile · points · notifications · drawer), its centre
/// "يلا نلعب" action, and the two shortcuts under it (Friends → Community,
/// My Teams → Teams). Secondary destinations live in the side drawer.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Ensures the "pick your position" prompt fires at most once per mount.
  bool _promptedPosition = false;

  /// A referral link tapped by somebody who is already signed in.
  StreamSubscription<String>? _referralSub;
  bool _referralNoticeShown = false;

  @override
  void initState() {
    super.initState();
    // Reaching Home means an account already exists, so any referral code
    // sitting in the service can never be spent — `referredBy` is written at
    // signup and only at signup. Say so plainly instead of leaving the code to
    // rot silently, which is how the user finds out days later that their
    // friend's invite "didn't work".
    _maybeShowReferralNotice(ReferralLinkService.instance.pendingCode);
    _referralSub =
        ReferralLinkService.instance.onCode.listen(_maybeShowReferralNotice);
  }

  @override
  void dispose() {
    _referralSub?.cancel();
    super.dispose();
  }

  /// Tell a signed-in user that a referral only counts at sign-up, once.
  ///
  /// The code is cleared as it is shown: it has been surfaced and refused, and
  /// leaving it pending would re-raise this on every launch forever. It also
  /// must not survive to a future signup on this device — that would credit a
  /// second account to a link this person already spent by not using.
  void _maybeShowReferralNotice(String? code) {
    if (code == null || code.isEmpty || _referralNoticeShown) return;
    _referralNoticeShown = true;
    ReferralLinkService.instance.clearPending();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Deferred behind the position picker and the challenge/invite dialogs —
      // this is the least urgent of the four and must not steal their frame.
      if (_positionRouteOpen || _challengeDialogOpen || _inviteDialogOpen) {
        return;
      }
      _showReferralNotice(code);
    });
  }

  Future<void> _showReferralNotice(String code) async {
    await showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            side: const BorderSide(color: AppColors.line2),
            borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎁', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 10),
            Text(tr('misc.referralTooLateTitle'),
                textAlign: TextAlign.center,
                style: AppText.condensed(size: 22, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(code,
                style: AppText.condensed(
                    size: 24,
                    weight: FontWeight.w800,
                    letterSpacing: 3,
                    color: AppColors.primary)),
            const SizedBox(height: 10),
            Text(tr('misc.referralTooLateBody'),
                textAlign: TextAlign.center,
                style: AppText.barlow(
                    size: 13.5, color: AppColors.dim, height: 1.45)),
          ],
        ),
        actions: [
          // Their own code is the useful thing to offer here: they can't take
          // a referral, but they can send one.
          GhostButton(
            label: tr('misc.referEarn'),
            onTap: () {
              Navigator.pop(dCtx);
              Navigator.pushNamed(context, Routes.referral);
            },
          ),
          PrimaryButton(
            label: tr('common.gotIt'),
            height: 46,
            onTap: () => Navigator.pop(dCtx),
          ),
        ],
      ),
    );
  }

  // True only while the position picker is actually on screen. The popups below
  // defer to it so two dialogs never fight for the same frame.
  //
  // ⚠️ This used to be `_promptedPosition && !user.sportProfileDone`, which was
  // a permanent mute: `sportProfileDone` only ever flips true in
  // `completeSportProfile`, so anyone who backed out of the picker without
  // choosing a position never saw a challenge or invite popup again — on any
  // device, forever. Gate on what is on screen NOW, never on a flag that has no
  // path back to false.
  bool _positionRouteOpen = false;

  // Challenges already auto-popped this mount. Dismissing with "Later" leaves
  // the banner in place rather than re-opening the dialog on every rebuild.
  final _poppedChallenges = <String>{};
  bool _challengeDialogOpen = false;

  // Match invites (individual "come play this match" invites) auto-popped this
  // mount. Same one-popup-per-open, persistent-banner behaviour as challenges.
  final _poppedInvites = <String>{};
  bool _inviteDialogOpen = false;

  /// Right after sign up the profile has no position yet — prompt for it once.
  void _maybePromptPosition(AppUser user) {
    if (_promptedPosition) return;
    if (user.position != null && user.position!.isNotEmpty) return;
    if (user.sportProfileDone) return;
    _promptedPosition = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _positionRouteOpen = true;
      await Navigator.of(context).pushNamed(Routes.footballProfile);
      // Rebuild on the way back so a challenge/invite that arrived (or was
      // waiting) behind the picker pops now.
      if (mounted) setState(() => _positionRouteOpen = false);
    });
  }

  /// Auto-open the newest unanswered challenge once per mount. The position
  /// prompt owns the screen right after sign-up, so it wins if both are due.
  void _maybePopChallenge(List<MatchModel> pending, AppUser? user) {
    if (_positionRouteOpen) return;
    final next = pending.where((m) => !_poppedChallenges.contains(m.id)).toList();
    if (next.isEmpty || _challengeDialogOpen || _inviteDialogOpen) return;
    final match = next.first;
    _poppedChallenges.add(match.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showChallengeDialog(match, user);
    });
  }

  Future<void> _showChallengeDialog(MatchModel match, AppUser? user) async {
    if (_challengeDialogOpen || _inviteDialogOpen) return;
    _challengeDialogOpen = true;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.line2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('⚡', style: TextStyle(fontSize: 30)),
              const SizedBox(height: 10),
              Text(tr('match.challengeDialogTitle'),
                  style: AppText.condensed(size: 24, weight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                '${match.teamAName} ${tr('match.challengeNotifBody')} '
                '"${match.challengedTeamName ?? match.teamBName}".',
                style:
                    AppText.barlow(size: 14, color: AppColors.dim, height: 1.45),
              ),
              const SizedBox(height: 4),
              Text(
                // Surface and location are only on older matches now — skip
                // whichever is missing so the line has no dangling separator.
                [
                  if (match.hasFixedFormat) match.format,
                  if (match.surface.isNotEmpty) match.surface,
                  if (match.location.isNotEmpty) match.location,
                ].join(' · '),
                style: AppText.barlow(size: 12, color: AppColors.dim2),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: tr('match.challengeAccept'),
                height: 50,
                fontSize: 18,
                onTap: () {
                  Navigator.pop(dialogCtx);
                  _answerChallenge(match, user, accept: true);
                },
              ),
              const SizedBox(height: 9),
              SecondaryButton(
                label: tr('match.challengeDecline'),
                height: 50,
                fontSize: 18,
                onTap: () {
                  Navigator.pop(dialogCtx);
                  _answerChallenge(match, user, accept: false);
                },
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(tr('match.challengeLater'),
                    style: AppText.barlow(size: 13, color: AppColors.dim)),
              ),
            ],
          ),
        ),
      ),
    );
    _challengeDialogOpen = false;
  }

  Future<void> _answerChallenge(
    MatchModel match,
    AppUser? user, {
    required bool accept,
  }) async {
    final uid = AuthRepository.instance.uid;
    if (uid == null) return;
    try {
      if (accept) {
        await MatchRepository.instance.acceptChallenge(
          match.id,
          uid: uid,
          name: user?.name ?? 'Captain',
          position: user?.position,
        );
        if (!mounted) return;
        Navigator.of(context).pushNamed(Routes.lobby, arguments: match.id);
      } else {
        await MatchRepository.instance.declineChallenge(match.id, uid: uid);
        if (!mounted) return;
        showYnoToast(context, tr('match.challengeDeclined'));
      }
    } catch (_) {
      if (mounted) showYnoToast(context, tr('match.challengeAnswerFailed'));
    }
  }

  /// Persistent reminder for challenges dismissed with "Later".
  Widget _challengeBanner(List<MatchModel> pending, AppUser? user) {
    if (pending.isEmpty) return const SizedBox.shrink();
    final label = pending.length == 1
        ? '"${pending.first.teamAName}" ${tr('match.challengeBannerOne')}'
        : '${pending.length} ${tr('match.challengeBannerMany')}';
    return _banner(
      emoji: '⚡',
      label: label,
      onTap: () => _showChallengeDialog(pending.first, user),
    );
  }

  // ---- Match invites (individual player invites) --------------------------

  /// Auto-open the newest unanswered match invite once per mount. Defers to the
  /// position prompt and to a challenge dialog if one is up.
  void _maybePopInvite(List<MatchModel> pending, AppUser? user) {
    if (_positionRouteOpen) return;
    if (_challengeDialogOpen || _inviteDialogOpen) return;
    final next = pending.where((m) => !_poppedInvites.contains(m.id)).toList();
    if (next.isEmpty) return;
    final match = next.first;
    _poppedInvites.add(match.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showInviteDialog(match, user);
    });
  }

  Future<void> _showInviteDialog(MatchModel match, AppUser? user) async {
    if (_challengeDialogOpen || _inviteDialogOpen) return;
    final uid = AuthRepository.instance.uid;
    if (uid == null) return;
    final by = match.inviterName(uid);
    final side = match.invitedTeam(uid);
    _inviteDialogOpen = true;
    await showDialog<void>(
      context: context,
      // A match invite has no "later": it must be answered, so the barrier is
      // sealed too — an accidental tap outside can't act as a silent dismissal.
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.line2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('📩', style: TextStyle(fontSize: 30)),
              const SizedBox(height: 10),
              Text(tr('match.inviteDialogTitle'),
                  style: AppText.condensed(size: 24, weight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                '${by.isEmpty ? match.teamAName : by} '
                '${tr('match.inviteNotifBody')} '
                '"${match.name.isEmpty ? '${match.teamAName} ${tr('match.vs')} ${match.teamBName}' : match.name}".',
                style:
                    AppText.barlow(size: 14, color: AppColors.dim, height: 1.45),
              ),
              if (side != null) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    '${tr('match.joiningSide')} ${match.teamName(side)}',
                    if (match.hasFixedFormat) match.format,
                    if (match.surface.isNotEmpty) match.surface,
                  ].join(' · '),
                  style: AppText.barlow(size: 12, color: AppColors.dim2),
                ),
              ],
              const SizedBox(height: 18),
              PrimaryButton(
                label: tr('match.inviteAcceptJoin'),
                height: 50,
                fontSize: 18,
                onTap: () {
                  Navigator.pop(dialogCtx);
                  _answerInvite(match, user, accept: true);
                },
              ),
              const SizedBox(height: 9),
              SecondaryButton(
                label: tr('match.challengeDecline'),
                height: 50,
                fontSize: 18,
                onTap: () {
                  Navigator.pop(dialogCtx);
                  _answerInvite(match, user, accept: false);
                },
              ),
            ],
          ),
        ),
      ),
    );
    _inviteDialogOpen = false;
  }

  Future<void> _answerInvite(
    MatchModel match,
    AppUser? user, {
    required bool accept,
  }) async {
    final uid = AuthRepository.instance.uid;
    if (uid == null) return;
    try {
      if (accept) {
        await MatchRepository.instance.acceptMatchInvite(
          match.id,
          uid: uid,
          name: user?.name ?? 'Player',
          position: user?.position,
        );
        if (!mounted) return;
        final route =
            match.status == MatchStatus.live ? Routes.live : Routes.lobby;
        Navigator.of(context).pushNamed(route, arguments: match.id);
      } else {
        await MatchRepository.instance.declineMatchInvite(match.id, uid);
        if (!mounted) return;
        showYnoToast(context, tr('match.inviteDeclined'));
      }
    } catch (_) {
      if (mounted) showYnoToast(context, tr('match.challengeAnswerFailed'));
    }
  }

  /// Persistent reminder for invites still unanswered — a second invite that
  /// arrived while the first dialog was up, or one that landed on a rebuild
  /// after this mount had already popped its one dialog.
  Widget _inviteBanner(List<MatchModel> pending, AppUser? user) {
    if (pending.isEmpty) return const SizedBox.shrink();
    final uid = AuthRepository.instance.uid;
    final by = uid == null ? '' : pending.first.inviterName(uid);
    final label = pending.length == 1
        ? '${by.isEmpty ? pending.first.teamAName : by} ${tr('match.inviteBannerOne')}'
        : '${pending.length} ${tr('match.inviteBannerMany')}';
    return _banner(
      emoji: '📩',
      label: label,
      onTap: () => _showInviteDialog(pending.first, user),
    );
  }

  /// Shared volt-outlined "you have something to answer" row.
  Widget _banner({
    required String emoji,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primaryGlow(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.barlow(
                        size: 13,
                        weight: FontWeight.w700,
                        color: AppColors.txt)),
              ),
              const Text('›',
                  style: TextStyle(fontSize: 20, color: AppColors.dim)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthRepository.instance.uid;
    return YnoScaffold(
      endDrawer: const YnoDrawer(),
      child: Stack(
        children: [
          // Ambient pitch markings + drifting footballs, behind everything.
          const Positioned.fill(child: IgnorePointer(child: _PitchLines())),
          const Positioned.fill(child: IgnorePointer(child: _FloatingIcons())),
          SafeArea(
            bottom: false,
            child: Builder(
              builder: (context) => StreamBuilder<AppUser?>(
                stream: uid == null
                    ? const Stream.empty()
                    : UserRepository.instance.watchUser(uid),
                builder: (context, snap) {
                  final user = snap.data;
                  if (user != null) _maybePromptPosition(user);
                  return StreamBuilder<List<MatchModel>>(
                    stream: uid == null
                        ? const Stream.empty()
                        : MatchRepository.instance.watchPendingChallenges(uid),
                    builder: (context, challengeSnap) {
                      final pending =
                          challengeSnap.data ?? const <MatchModel>[];
                      _maybePopChallenge(pending, user);
                      return StreamBuilder<List<MatchModel>>(
                        stream: uid == null
                            ? const Stream.empty()
                            : MatchRepository.instance
                                .watchPendingMatchInvites(uid),
                        builder: (context, inviteSnap) {
                          final invites =
                              inviteSnap.data ?? const <MatchModel>[];
                          _maybePopInvite(invites, user);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FadeSlideIn(child: _topBar(context, uid, user)),
                              const SizedBox(height: 10),
                              _challengeBanner(pending, user),
                              _inviteBanner(invites, user),
                              // Centred in whatever space is left, and
                              // scrollable when the phone is too short for it.
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, box) =>
                                      SingleChildScrollView(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                          minHeight: box.maxHeight),
                                      child: Center(
                                          child: _centreStage(box.maxHeight)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Top bar ------------------------------------------------------------

  Widget _topBar(BuildContext context, String? uid, AppUser? user) {
    final unreadStream = uid == null
        ? const Stream<int>.empty()
        : NotificationRepository.instance.watchUnread(uid);
    return StreamBuilder<int>(
      stream: unreadStream,
      builder: (context, unreadSnap) {
        final unread = unreadSnap.data ?? 0;
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: Row(
            children: [
              // Profile — the "YY" square in the design.
              _ProfileSquare(
                initials: user?.initials ?? '··',
                photoUrl: user?.photoUrl,
                onTap: () => Navigator.pushNamed(context, Routes.profile),
              ),
              const Spacer(),
              // Points — tapping opens Refer & Earn, where points come from.
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, Routes.referral),
                child: _PointsBadge(points: user?.points ?? 0),
              ),
              const SizedBox(width: 10),
              _IconSquare(
                onTap: () => Navigator.pushNamed(context, Routes.notifications),
                dotColor: unread > 0 ? AppColors.primary : null,
                child: const Text('🔔', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              // Hamburger — side drawer. Carries a RED dot while the user is
              // holding an unstarted draft match (it self-deletes in 2 days).
              StreamBuilder<MatchModel?>(
                stream: uid == null
                    ? const Stream.empty()
                    : MatchRepository.instance.watchMyDraft(uid),
                builder: (context, draftSnap) => _IconSquare(
                  onTap: () => Scaffold.of(context).openEndDrawer(),
                  dotColor: draftSnap.data == null ? null : AppColors.loss,
                  child: const _BurgerLines(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---- Centre stage -------------------------------------------------------

  /// [available] is the height left under the top bar and any banners.
  ///
  /// The three blocks are separated by gaps that **scale with that height**
  /// rather than fixed spacers: a compact block centred on a tall phone leaves
  /// a dead zone under the shortcuts, so on a big screen the gaps open up and
  /// the stage fills the space. They clamp to a comfortable minimum, and on a
  /// screen too short even for that the whole stage scrolls.
  ///
  /// The circle→play gap is the smaller of the two: the wordmark's box IS the
  /// centre circle, so it already carries a ring of whitespace under the text.
  Widget _centreStage(double available) {
    final narrow = MediaQuery.sizeOf(context).width <= 420;
    final logoGap = (available * 0.04).clamp(16.0, 44.0);
    final playGap = (available * 0.075).clamp(18.0, 72.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        narrow ? 18 : 26,
        24,
        narrow ? 18 : 26,
        // Sit clear of the system navigation bar — the stage is laid out into
        // the full height (SafeArea bottom is off so the background bleeds
        // behind it), so without this it would centre a little too high.
        30 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeSlideIn(
            delay: const Duration(milliseconds: 50),
            child: _logo(narrow),
          ),
          SizedBox(height: logoGap),
          FadeSlideIn(
            delay: const Duration(milliseconds: 180),
            child: _playButton(narrow),
          ),
          SizedBox(height: playGap),
          FadeSlideIn(
            delay: const Duration(milliseconds: 260),
            child: _actionRow(),
          ),
        ],
      ),
    );
  }

  /// The wordmark, sat dead centre of the pitch's centre circle.
  ///
  /// The circle is painted HERE rather than in the full-screen [_PitchLines] so
  /// the two can never drift apart — the ring is sized to this box, so the logo
  /// is centred in it by construction on every screen, and everything after it
  /// in the column necessarily lands below the circle.
  Widget _logo(bool narrow) {
    final pad = narrow ? 36.0 : 52.0; // the stage's own horizontal padding
    final diameter =
        (MediaQuery.sizeOf(context).width - pad).clamp(180.0, 238.0);
    return SizedBox(
      width: diameter,
      height: diameter,
      child: CustomPaint(
        painter: _CentreCirclePainter(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'YN'),
                    TextSpan(
                        text: 'O',
                        style: TextStyle(color: AppColors.primary)),
                  ],
                ),
                style: AppText.condensed(
                  size: narrow ? 64 : 84,
                  weight: FontWeight.w900,
                  letterSpacing: narrow ? 4 : 6,
                  height: 1,
                ).copyWith(
                  shadows: [
                    Shadow(color: AppColors.primaryGlow(0.35), blurRadius: 30),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'YALLA NELLAB',
                style: AppText.barlow(
                  size: 12,
                  weight: FontWeight.w600,
                  color: AppColors.txt.withValues(alpha: 0.45),
                  letterSpacing: 7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The headline action. Opens the Let's Play sheet (create · join by code).
  Widget _playButton(bool narrow) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: _PulseGlow(
            radius: 22,
            child: Pressable(
              onTap: () => showLetsPlaySheet(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.primary, width: 3),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('يلا نلعب',
                        style: AppText.condensed(
                            size: narrow ? 28 : 34,
                            weight: FontWeight.w900,
                            color: AppColors.ink,
                            height: 1.05)),
                    const SizedBox(height: 3),
                    Text(tr('home.letsPlay').toUpperCase(),
                        style: AppText.condensed(
                            size: narrow ? 11 : 13,
                            weight: FontWeight.w800,
                            color: AppColors.ink.withValues(alpha: 0.85),
                            letterSpacing: narrow ? 3 : 4)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _actionRow() => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Row(
            children: [
              Expanded(
                child: _ActionTile(
                  emoji: '👥',
                  label: tr('drawer.friends'),
                  onTap: () =>
                      Navigator.pushNamed(context, Routes.community),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionTile(
                  emoji: '🛡️',
                  label: tr('drawer.myTeams'),
                  onTap: () => Navigator.pushNamed(context, Routes.teams),
                ),
              ),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Ambient background
// ---------------------------------------------------------------------------

/// Faint pitch markings — the halfway lines — painted at 5% opacity behind the
/// whole screen (the design's `.pitch-lines`). The centre circle is NOT drawn
/// here: it belongs to the wordmark and is painted with it (`_CentreCircle
/// Painter`) so the two stay locked together.
class _PitchLines extends StatelessWidget {
  const _PitchLines();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _PitchLinesPainter(), size: Size.infinite);
}

class _PitchLinesPainter extends CustomPainter {
  static const _spacing = 90.0; // one horizontal line every 90px

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryGlow(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var y = _spacing; y < size.height; y += _spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PitchLinesPainter oldDelegate) => false;
}

/// The pitch's centre circle, inscribed in whatever box it is given — which is
/// the wordmark's box, so the logo always sits at its centre.
class _CentreCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2,
      Paint()
        ..color = AppColors.primaryGlow(0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _CentreCirclePainter oldDelegate) => false;
}

/// The drifting footballs / goal / boot from the design. Purely decorative —
/// each bobs on its own duration so they never move in lockstep.
class _FloatingIcons extends StatelessWidget {
  const _FloatingIcons();

  @override
  Widget build(BuildContext context) => const Stack(
        children: [
          _FloatIcon(
              emoji: '⚽',
              align: Alignment(-0.86, -0.68),
              size: 34,
              opacity: 0.9,
              seconds: 2.6),
          _FloatIcon(
              emoji: '⚽',
              align: Alignment(0.80, -0.78),
              size: 22,
              opacity: 0.55,
              seconds: 3.1),
          _FloatIcon(
              emoji: '⚽',
              align: Alignment(-0.90, 0.16),
              size: 20,
              opacity: 0.4,
              seconds: 2.9),
          _FloatIcon(
              emoji: '🥅',
              align: Alignment(0.88, 0.04),
              size: 30,
              opacity: 0.75,
              seconds: 2.4),
          _FloatIcon(
              emoji: '👟',
              align: Alignment(0.72, 0.52),
              size: 18,
              opacity: 0.45,
              seconds: 3.3),
        ],
      );
}

class _FloatIcon extends StatefulWidget {
  const _FloatIcon({
    required this.emoji,
    required this.align,
    required this.size,
    required this.opacity,
    required this.seconds,
  });

  final String emoji;
  final Alignment align;
  final double size;
  final double opacity;
  final double seconds;

  @override
  State<_FloatIcon> createState() => _FloatIconState();
}

class _FloatIconState extends State<_FloatIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.seconds * 1000).round()),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.align,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_c.value); // 0 → 1 → 0
          return Transform.translate(
            offset: Offset(0, -14 * t),
            child: Transform.rotate(
              angle: (-4 + 9 * t) * 3.1415926535 / 180,
              child: child,
            ),
          );
        },
        child: Opacity(
          opacity: widget.opacity,
          child: Text(widget.emoji,
              style: TextStyle(fontSize: widget.size)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top-bar pieces
// ---------------------------------------------------------------------------

/// The rounded-square profile avatar in the top-left ("YY" in the design).
/// Square rather than the app's usual circular [InitialsAvatar], per the design.
class _ProfileSquare extends StatelessWidget {
  const _ProfileSquare({
    required this.initials,
    required this.onTap,
    this.photoUrl,
  });

  final String initials;
  final String? photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width <= 420;
    final side = narrow ? 44.0 : 52.0;
    return Pressable(
      onTap: onTap,
      child: Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: photoUrl == null || photoUrl!.isEmpty
            ? Text(initials.toUpperCase(),
                style: AppText.barlow(
                    size: narrow ? 15 : 18,
                    weight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 1))
            : Image.network(
                photoUrl!,
                width: side,
                height: side,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Text(initials.toUpperCase(),
                    style: AppText.barlow(
                        size: narrow ? 15 : 18,
                        weight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 1)),
              ),
      ),
    );
  }
}

/// A 46×46 rounded-square icon button with an optional status dot — volt for
/// unread notifications, red for "you have a draft match waiting".
class _IconSquare extends StatelessWidget {
  const _IconSquare({
    required this.child,
    required this.onTap,
    this.dotColor,
  });

  final Widget child;
  final VoidCallback onTap;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width <= 420;
    final side = narrow ? 40.0 : 46.0;
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: side,
        height: side,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: side,
              height: side,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line, width: 1.5),
              ),
              alignment: Alignment.center,
              child: child,
            ),
            if (dotColor != null)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bg, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The three-bar hamburger glyph from the design (16 · 11 · 16 wide).
class _BurgerLines extends StatelessWidget {
  const _BurgerLines();

  Widget _bar(double width) => Container(
        width: width,
        height: 2.5,
        decoration: BoxDecoration(
          color: AppColors.txt,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _bar(16),
          const SizedBox(height: 4),
          _bar(11),
          const SizedBox(height: 4),
          _bar(16),
        ],
      );
}

// ---------------------------------------------------------------------------
// Centre-stage pieces
// ---------------------------------------------------------------------------

/// One of the two shortcuts under the play button (Friends · My Teams).
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    AppText.barlow(size: 15.5, weight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

/// Wraps a child in a slowly breathing volt-green halo (the design's
/// `pulseGlow`). The glow is painted behind the child so it never tints it.
class _PulseGlow extends StatefulWidget {
  const _PulseGlow({required this.child, required this.radius});

  final Widget child;
  final double radius;

  @override
  State<_PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<_PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGlow(0.25 + 0.25 * t),
                blurRadius: 24 + 20 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Points balance pill. Always breathes a soft volt-green glow so it feels
/// alive, and flashes green when the value actually increases.
class _PointsBadge extends StatefulWidget {
  const _PointsBadge({required this.points});

  final int points;

  @override
  State<_PointsBadge> createState() => _PointsBadgeState();
}

class _PointsBadgeState extends State<_PointsBadge>
    with SingleTickerProviderStateMixin {
  // Continuous breathing pulse (always running while Home is open).
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  int? _prev;
  bool _flash = false;

  @override
  void initState() {
    super.initState();
    _prev = widget.points;
  }

  @override
  void didUpdateWidget(covariant _PointsBadge old) {
    super.didUpdateWidget(old);
    if (_prev != null && widget.points > _prev!) {
      _triggerFlash();
    }
    _prev = widget.points;
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _triggerFlash() async {
    setState(() => _flash = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _flash = false);
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width <= 420;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_pulse.value); // 0..1 breathing
        final glowOpacity = _flash ? 0.55 : (0.10 + 0.14 * t);
        final blur = _flash ? 22.0 : (8.0 + 8.0 * t);
        final borderColor = _flash
            ? AppColors.win
            : Color.lerp(AppColors.line, AppColors.line2, 0.3 + 0.4 * t)!;
        // Resting colour is the brand volt; a genuine increase flashes green.
        final textColor = _flash ? AppColors.win : AppColors.primary;
        final glowColor = _flash ? AppColors.win : AppColors.primary;
        return Container(
          height: narrow ? 40 : 46,
          padding: EdgeInsets.symmetric(horizontal: narrow ? 10 : 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: glowOpacity),
                blurRadius: blur,
                spreadRadius: _flash ? 1 : 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 17)),
              const SizedBox(width: 6),
              Text('${widget.points}',
                  style: AppText.barlow(
                      size: narrow ? 13 : 15,
                      weight: FontWeight.w800,
                      color: textColor)),
            ],
          ),
        );
      },
    );
  }
}
