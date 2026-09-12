import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
import '../services/match_repository.dart';
import '../services/models.dart';
import '../services/user_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/confirm.dart';
import '../widgets/header.dart';
import '../widgets/inputs.dart';
import '../widgets/motion.dart';
import '../widgets/yno_scaffold.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  bool _starting = false;
  bool _leaving = false;

  /// A player takes themselves out of the match and goes home.
  ///
  /// Confirmed and red: it drops them off the team sheet, and a captain who
  /// leaves takes the armband with them, which the host has to reassign before
  /// the match can start.
  Future<void> _leaveMatch(MatchModel match) async {
    final uid = AuthRepository.instance.uid;
    if (uid == null || _leaving) return;
    final ok = await showConfirm(
      context,
      title: tr('match.leaveMatchQ'),
      message: tr('match.leaveMatchBody'),
      confirmLabel: tr('match.leaveMatch'),
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _leaving = true);
    try {
      await MatchRepository.instance.leaveMatch(match.id, uid);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.home, (_) => false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _leaving = false);
      // The only failure that matters to a player: the host started the match
      // between opening the confirm and confirming it.
      showYnoToast(context, tr('match.leaveMatchFailed'));
    }
  }

  String get _matchId => ModalRoute.of(context)!.settings.arguments as String;

  /// Fixed roster size per side, or null for Custom/Unlimited.
  int? _teamSize(String format) {
    final m = RegExp(r'^(\d+)v').firstMatch(format);
    return m != null ? int.parse(m.group(1)!) : null;
  }

  /// Who may add/remove players on a side (see [MatchModel.canManageSide]).
  bool _canManage(MatchModel m, TeamSide side) =>
      m.canManageSide(AuthRepository.instance.uid, side);

  Future<void> _start(MatchModel match) async {
    if (_starting) return;
    final missing = <String>[];
    if (match.captainAUid == null) missing.add(match.teamAName);
    if (match.captainBUid == null) missing.add(match.teamBName);
    if (missing.isNotEmpty) {
      showYnoToast(context,
          '${tr('match.assignCaptainFor')} ${missing.join(' & ')} ${tr('match.firstSuffix')}');
      return;
    }
    setState(() => _starting = true);
    await MatchRepository.instance.startMatch(match.id);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, Routes.live, arguments: match.id);
  }

  @override
  Widget build(BuildContext context) {
    final id = _matchId;

    return YnoScaffold(
      appBarTitle: tr('match.lobbyTitle'),
      child: SafeArea(
        top: false,
        bottom: false,
        child: StreamBuilder<MatchModel?>(
          stream: MatchRepository.instance.watchMatch(id),
          builder: (context, matchSnap) {
            final match = matchSnap.data;
            if (match == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final amAdmin = match.adminUid == AuthRepository.instance.uid;
            final separate = match.joiningMethod == JoiningMethod.separateTeams;
            final manageA = _canManage(match, TeamSide.a);
            final manageB = _canManage(match, TeamSide.b);
            return Stack(
              children: [
                StreamBuilder<List<MatchPlayer>>(
                  stream: MatchRepository.instance.watchPlayers(id),
                  builder: (context, playerSnap) {
                    final players = playerSnap.data ?? const <MatchPlayer>[];
                    final teamA =
                        players.where((p) => p.team == TeamSide.a).toList();
                    final teamB =
                        players.where((p) => p.team == TeamSide.b).toList();
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 130),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (match.location.isNotEmpty) ...[
                            Text('📍 ${match.location}',
                                style: AppText.barlow(
                                    size: 13, color: AppColors.dim)),
                          ],
                          const SizedBox(height: 18),

                          // ---- Codes ---------------------------------------
                          if (separate) ...[
                            FadeSlideIn(
                              child: _codeCard(
                                  context, match, TeamSide.a, amAdmin),
                            ),
                            const SizedBox(height: 12),
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 50),
                              child: _codeCard(
                                  context, match, TeamSide.b, amAdmin),
                            ),
                          ] else
                            FadeSlideIn(
                              child: _codeCard(context, match, null, amAdmin),
                            ),

                          // ---- Pending area (admin) ------------------------
                          if (amAdmin) _pendingArea(context, match),

                          const SizedBox(height: 18),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 120),
                            child: _teamCard(
                                context, match, TeamSide.a, teamA, manageA),
                          ),
                          const SizedBox(height: 13),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 200),
                            child: _teamCard(
                                context, match, TeamSide.b, teamB, manageB),
                          ),

                          if (amAdmin) ...[
                            const SizedBox(height: 16),
                            // "＋ Invite a friend" used to sit here, opening a
                            // sheet that listed your friends and pushed a
                            // match-invite notification. Removed 2026-09-07 at
                            // the client's request: it overlapped the per-side
                            // Add Player flow (which invites registered players
                            // *onto a specific team*, so the invitee lands
                            // somewhere) and the share-code links, while this
                            // one dropped people into the match with no side.
                            //
                            // Step back to creation (page 1) to fix a setting.
                            // Only pre-kick-off: `updateMatchSettings` refuses
                            // once the match is live, and this vanishes anyway
                            // since the lobby is left behind at Start.
                            const SizedBox(height: 10),
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 320),
                              child: SecondaryButton(
                                label: '✎ ${tr('match.editMatchDetails')}',
                                fontSize: 16,
                                onTap: () => Navigator.pushNamed(
                                    context, Routes.matchCreate,
                                    arguments: match.id),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _startBar(context, match, amAdmin),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---- Code card -----------------------------------------------------------

  Widget _codeCard(
      BuildContext context, MatchModel match, TeamSide? side, bool amAdmin) {
    final code = side == null ? match.code : match.codeFor(side);
    final label = side == null
        ? tr('match.matchCodeLabel')
        : '${tr('match.codeLabel')} · ${match.teamName(side).toUpperCase()}';
    final hint = side == null
        ? tr('match.oneSharedCode')
        : '${tr('match.joinCodeLandPre')} ${match.teamName(side)}.';
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // A match code is issued once and never rotates (client decision,
              // 2026-08-18): a code that can change is a code a player cannot
              // trust. `MatchRepository.regenerateCode` is intentionally left
              // in place, uncalled, so restoring this is one widget.
              Expanded(child: Text(label, style: AppText.label())),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.condensed(
                        size: 32, weight: FontWeight.w800, letterSpacing: 3)),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  showYnoToast(context, tr('match.codeCopied'));
                },
                child: const Text('📋', style: TextStyle(fontSize: 20)),
              ),
              // A 🔗 share button used to sit here, pushing the code plus
              // `https://nellab.org/join?code=…` through the OS share sheet,
              // and a tappable link row sat below the hint. Both paused
              // 2026-09-12 at the client's request: nobody joins by link for
              // now — a captain or admin adds people from Add Player (a guest
              // by name, or a registered player by username search), and the
              // code above is still what the in-app Join screen takes.
              //
              // Restoring it is this button plus that row, `_linkFor`, the
              // `share_plus` / `links.dart` imports, and the two strings
              // archived in `.claude/l10n_removed_keys.md`.
            ],
          ),
          const SizedBox(height: 6),
          Text(hint, style: AppText.barlow(size: 12, color: AppColors.dim2)),
        ],
      ),
    );
  }

  // ---- Pending area --------------------------------------------------------

  Widget _pendingArea(BuildContext context, MatchModel match) {
    return StreamBuilder<List<PendingPlayer>>(
      stream: MatchRepository.instance.watchPending(match.id),
      builder: (context, snap) {
        final pending = snap.data ?? const <PendingPlayer>[];
        if (pending.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  color: AppColors.surface2,
                  child: Text('${tr('match.waitingToJoin')} · ${pending.length}',
                      style: AppText.label(color: AppColors.txt)),
                ),
                for (final p in pending)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 11),
                    decoration: const BoxDecoration(
                        border:
                            Border(top: BorderSide(color: AppColors.line))),
                    child: Row(
                      children: [
                        InitialsAvatar(initials: p.initials, size: 34, fontSize: 13),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.barlow(
                                      size: 15, weight: FontWeight.w700)),
                              Text(
                                  '${p.isGuest ? tr('match.guest') : tr('role.player')} · ${tr('match.wants')} ${match.teamName(p.team)}${p.midGame ? ' · ${tr('match.midGame')}' : ''}',
                                  style: AppText.barlow(
                                      size: 12, color: AppColors.dim2)),
                            ],
                          ),
                        ),
                        _miniBtn('✓', () async {
                          await MatchRepository.instance
                              .approvePending(match.id, p);
                          if (context.mounted) {
                            showYnoToast(context, '${p.name} ${tr('match.approved')}');
                          }
                        }),
                        const SizedBox(width: 8),
                        _miniBtn('✕', () async {
                          await MatchRepository.instance
                              .declinePending(match.id, p.uid);
                          if (context.mounted) {
                            showYnoToast(context, '${p.name} ${tr('match.declined')}');
                          }
                        }),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _miniBtn(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(12)),
          child: Text(label,
              style: AppText.barlow(size: 16, weight: FontWeight.w700)),
        ),
      );

  // ---- Team card -----------------------------------------------------------

  Widget _teamCard(BuildContext context, MatchModel match, TeamSide side,
      List<MatchPlayer> players, bool canManage) {
    final size = _teamSize(match.format);
    final emptySlots = size == null ? 0 : (size - players.length).clamp(0, size);
    final hasCaptain = match.captainUid(side) != null;
    final invited = match.invitedForSide(side);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            color: AppColors.surface2,
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Text(side.id,
                      style: AppText.condensed(
                          size: 16,
                          weight: FontWeight.w800,
                          color: AppColors.txt)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(match.teamName(side).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppText.condensed(size: 19, weight: FontWeight.w800)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(
                      hasCaptain
                          ? '✓ ${tr('role.captain').toUpperCase()}'
                          : tr('match.noCaptain').toUpperCase(),
                      style: AppText.barlow(
                          size: 10,
                          weight: FontWeight.w800,
                          color: hasCaptain ? AppColors.txt : AppColors.dim)),
                ),
                const SizedBox(width: 8),
                Text(size == null ? '${players.length}' : '${players.length}/$size',
                    style: AppText.barlow(size: 13, color: AppColors.dim)),
              ],
            ),
          ),
          for (final p in players)
            _playerRow(context, match, p, canManage),
          for (final uid in invited)
            _invitedRow(context, match, uid, canManage),
          for (int i = 0; i < emptySlots; i++) _emptySlot(),
          if (players.isEmpty && invited.isEmpty && emptySlots == 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              child: Text(tr('match.noPlayersYet'),
                  style: AppText.barlow(size: 13, color: AppColors.dim2)),
            ),
          if (canManage)
            GestureDetector(
              onTap: () => _addPlayer(context, match, side),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.line)),
                ),
                child: Text('＋ ${tr('match.addPlayer')}',
                    style: AppText.barlow(
                        size: 14,
                        weight: FontWeight.w700,
                        color: AppColors.txt)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptySlot() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.line))),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.line2),
                  borderRadius: BorderRadius.circular(12)),
              child: Text('+',
                  style: AppText.barlow(size: 18, color: AppColors.dim2)),
            ),
            const SizedBox(width: 11),
            Text(tr('match.emptySlot'),
                style: AppText.barlow(size: 14, color: AppColors.dim2)),
          ],
        ),
      );

  Widget _playerRow(BuildContext context, MatchModel match, MatchPlayer p,
      bool canManage) {
    final amAdmin = match.adminUid == AuthRepository.instance.uid;
    // A manager (the creator for their side, or the side's captain) can drop a
    // player from THIS match with the leading − button — the admin can't be
    // removed, and a captain can't remove themselves (that would strand the
    // team).
    final removable = canManage &&
        !p.isAdmin &&
        (amAdmin || p.uid != AuthRepository.instance.uid);
    return GestureDetector(
      onTap: canManage ? () => _playerActions(context, match, p) : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.line))),
        child: Row(
          children: [
            if (canManage && removable) ...[
              _minusButton(() => _confirmRemovePlayer(context, match, p)),
              const SizedBox(width: 10),
            ],
            InitialsAvatar(
                initials: p.initials,
                size: 36,
                fontSize: 14,
                ringColor: p.isAdmin ? AppColors.primary : AppColors.line2),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.barlow(
                                size: 15, weight: FontWeight.w700)),
                      ),
                      if (p.uid == AuthRepository.instance.uid) ...[
                        const SizedBox(width: 6),
                        _tag(tr('common.you')),
                      ],
                      if (p.isGuest) ...[
                        const SizedBox(width: 6),
                        _tag(tr('badge.guest')),
                      ],
                    ],
                  ),
                  Text(p.position ?? (p.isAdmin ? tr('match.admin') : tr('role.player')),
                      style: AppText.barlow(size: 12, color: AppColors.dim2)),
                ],
              ),
            ),
            if (p.isCaptain) ...[
              _badge('★ C'),
              const SizedBox(width: 6),
            ],
            if (p.isAdmin) _badge(tr('badge.admin')),
            if (canManage) ...[
              const SizedBox(width: 8),
              Text('⋮',
                  style: AppText.barlow(size: 20, color: AppColors.dim)),
            ],
          ],
        ),
      ),
    );
  }

  /// A registered player who's been invited but hasn't answered yet. Shown
  /// muted with an INVITED tag; a manager can cancel it with the − button.
  Widget _invitedRow(BuildContext context, MatchModel match, String uid,
      bool canManage) {
    final name = match.inviteeName(uid);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line))),
      child: Row(
        children: [
          if (canManage) ...[
            _minusButton(() => _cancelInvite(context, match, uid, name)),
            const SizedBox(width: 10),
          ],
          Opacity(
            opacity: 0.6,
            child: InitialsAvatar(
                initials: _initialsOf(name),
                size: 36,
                fontSize: 14,
                ringColor: AppColors.line2),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.barlow(
                    size: 15, weight: FontWeight.w700, color: AppColors.dim)),
          ),
          _tag(tr('match.invitedTag')),
        ],
      ),
    );
  }

  Future<void> _cancelInvite(BuildContext context, MatchModel match, String uid,
      String name) async {
    await MatchRepository.instance.declineMatchInvite(match.id, uid);
    if (context.mounted) {
      showYnoToast(context, '${tr('match.inviteCancelled')} $name');
    }
  }

  String _initialsOf(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Widget _badge(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(12)),
        child: Text(label,
            style: AppText.barlow(
                size: 11, weight: FontWeight.w800, color: AppColors.txt)),
      );

  Widget _tag(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.line2),
            borderRadius: BorderRadius.circular(100)),
        child:
            Text(label, style: AppText.barlow(size: 10, color: AppColors.dim)),
      );

  // ---- Start bar -----------------------------------------------------------

  Widget _startBar(BuildContext context, MatchModel match, bool amAdmin) {
    final missing = <String>[];
    if (match.captainAUid == null) missing.add(match.teamAName);
    if (match.captainBUid == null) missing.add(match.teamBName);
    final canStart = missing.isEmpty;
    // Only the creator sees the Start control; everyone else just waits.
    if (!amAdmin) {
      return Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('match.waitingAdminStart'),
                textAlign: TextAlign.center,
                style: AppText.barlow(size: 13, color: AppColors.dim)),
            const SizedBox(height: 12),
            // Nobody is trapped in a lobby they no longer want to be in.
            // Red: leaving drops you off the team sheet, and if you were the
            // captain it takes the armband with you.
            SecondaryButton(
              label: tr('match.leaveMatch'),
              height: 46,
              fontSize: 16,
              danger: true,
              onTap: _leaving ? null : () => _leaveMatch(match),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!canStart)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                  '${tr('match.assignCaptainFor')} ${missing.join(' & ')} ${tr('match.toStartSuffix')}',
                  textAlign: TextAlign.center,
                  style: AppText.barlow(size: 12, color: AppColors.dim)),
            ),
          Opacity(
            opacity: canStart ? 1 : 0.4,
            child: PrimaryButton(
              label: _starting ? tr('match.starting') : '▶ ${tr('match.startMatch')}',
              fontSize: 22,
              onTap: () => _start(match),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Player actions (admin: full; captain: remove-only) -----------------

  /// The leading − control on a player row.
  Widget _minusButton(VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: kDangerColor, width: 1.5),
          ),
          child: const Icon(Icons.remove, size: 16, color: kDangerColor),
        ),
      );

  /// Confirm, then drop [p] from this match only (their saved team is untouched).
  Future<void> _confirmRemovePlayer(
      BuildContext context, MatchModel match, MatchPlayer p) async {
    final ok = await showConfirm(
      context,
      title: tr('match.removePlayerQ'),
      message: '${p.name} ${tr('match.removePlayerBody')}',
      confirmLabel: tr('match.remove'),
      danger: true,
    );
    if (!ok || !context.mounted) return;
    await MatchRepository.instance.removePlayer(match.id, p.uid);
    if (context.mounted) {
      showYnoToast(context, '${p.name} ${tr('match.removed')}');
    }
  }

  Future<void> _playerActions(
      BuildContext context, MatchModel match, MatchPlayer p) async {
    final uid = AuthRepository.instance.uid;
    final amAdmin = match.adminUid == uid;
    final other = p.team == TeamSide.a ? TeamSide.b : TeamSide.a;
    // Assigning a captain is a setup power the creator holds over a side they
    // still control. Moving a player across teams touches BOTH rosters, so it's
    // only offered while the creator controls the whole match (no opposing
    // captain has claimed a side yet).
    final canMakeCaptain = amAdmin && _canManage(match, p.team);
    final canMove =
        amAdmin && _canManage(match, TeamSide.a) && _canManage(match, TeamSide.b);
    // Anyone managing this side may remove players from it, but not the admin,
    // and a captain can't remove themselves (that would strand the team).
    final canRemove = !p.isAdmin && (amAdmin || p.uid != uid);
    // Nothing to offer (e.g. tapping your own captain row) — explain briefly.
    if (!canMakeCaptain && !canMove && !canRemove) {
      showYnoToast(context,
          p.isAdmin ? tr('match.cantRemoveAdmin') : tr('match.thatsYou'));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(side: BorderSide(color: AppColors.line2)),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
              child: Row(
                children: [
                  Text(p.name.toUpperCase(),
                      style:
                          AppText.condensed(size: 20, weight: FontWeight.w800)),
                ],
              ),
            ),
            if (canMakeCaptain)
              _actionRow('★  ${tr('match.makeCaptainOf')} ${match.teamName(p.team)}',
                  () async {
                Navigator.pop(sheetCtx);
                await MatchRepository.instance
                    .assignMatchCaptain(match.id, p.team, p);
                if (context.mounted) {
                  showYnoToast(context, '${p.name} ${tr('match.isNowCaptain')}');
                }
              }),
            if (canMove)
              _actionRow('⇄  ${tr('match.moveTo')} ${match.teamName(other)}', () async {
                Navigator.pop(sheetCtx);
                await MatchRepository.instance.movePlayer(match.id, p, other);
                if (context.mounted) {
                  showYnoToast(context, '${tr('match.movedTo')} ${match.teamName(other)}');
                }
              }),
            if (canRemove)
              _actionRow('✕  ${tr('match.removeFromLobby')}', () async {
                Navigator.pop(sheetCtx);
                if (!context.mounted) return;
                final ok = await showConfirm(
                  context,
                  title: tr('match.removePlayerQ'),
                  message: '${p.name} ${tr('match.removePlayerBody')}',
                  confirmLabel: tr('match.remove'),
                  danger: true,
                );
                if (!ok || !context.mounted) return;
                await MatchRepository.instance.removePlayer(match.id, p.uid);
                if (context.mounted) {
                  showYnoToast(context, '${p.name} ${tr('match.removed')}');
                }
              }, danger: true),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _actionRow(String label, VoidCallback onTap, {bool danger = false}) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.line))),
          child: Text(label,
              style: AppText.barlow(
                  size: 15,
                  weight: FontWeight.w700,
                  color: danger ? kDangerColor : AppColors.txt)),
        ),
      );

  // ---- Add player (admin): guest or registered ----------------------------

  Future<void> _addPlayer(
      BuildContext context, MatchModel match, TeamSide side) async {
    // Inviter's display name — shown to the player in the invite popup.
    final inviterName = (await UserRepository.instance
                .getUser(AuthRepository.instance.uid ?? '__'))
            ?.name ??
        tr('match.admin');
    if (!context.mounted) return;

    // 🔑 The sheet owns its own controllers (see _AddPlayerSheet) and the toast
    // is raised here, once the sheet is gone. Both halves matter: this function
    // used to create three TextEditingControllers, await the sheet, then
    // dispose them on the next line — but showModalBottomSheet completes when
    // the route is POPPED, not when it has finished animating out. The keyboard
    // collapsing during that animation rebuilds the sheet through its
    // viewInsets padding, and by then the controllers were dead. Same fault as
    // the join sheet in match_actions.dart (SESSION_PROGRESS §72).
    final invited = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(side: BorderSide(color: AppColors.line2)),
      builder: (_) => _AddPlayerSheet(
        match: match,
        side: side,
        inviterName: inviterName,
      ),
    );
    if (invited != null && context.mounted) {
      showYnoToast(context, '${tr('match.inviteSentTo')} $invited');
    }
  }
}

/// The body of the lobby's Add Player sheet — guest or registered.
///
/// Stateful so the [TextEditingController]s die with the route rather than with
/// `showModalBottomSheet`'s future. See the note in `_addPlayer`.
///
/// Pops with the invited player's name when a registered player is invited, so
/// the caller can toast on a context that outlives this sheet; pops with null
/// otherwise.
class _AddPlayerSheet extends StatefulWidget {
  const _AddPlayerSheet({
    required this.match,
    required this.side,
    required this.inviterName,
  });

  final MatchModel match;
  final TeamSide side;
  final String inviterName;

  @override
  State<_AddPlayerSheet> createState() => _AddPlayerSheetState();
}

class _AddPlayerSheetState extends State<_AddPlayerSheet> {
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _search = TextEditingController();

  var _mode = 0; // 0 guest, 1 registered
  var _busy = false;
  var _results = <AppUser>[];
  var _searching = false;

  // Inline validation message for the guest tab. This used to be a toast on the
  // sheet's own context, which renders behind the sheet — so a missing email
  // looked like the button doing nothing at all.
  String? _guestError;

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _search.dispose();
    super.dispose();
  }

  // One submit path for the guest tab, shared by the button and the keyboard's
  // enter key. Without the keyboard route, typing a name and pressing enter
  // genuinely did nothing: nothing was listening.
  Future<void> _addGuest() async {
    if (_busy) return;
    final playerName = _name.text.trim();
    final email = _contact.text.trim();
    if (playerName.isEmpty) {
      setState(() => _guestError = tr('match.enterName'));
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _guestError = tr('match.guestEmailRequired'));
      return;
    }
    setState(() {
      _guestError = null;
      _busy = true;
    });
    try {
      // Create a real account (password 123456) and add the player, so they can
      // log in and claim their profile.
      await MatchRepository.instance.addNewPlayer(
        matchId: widget.match.id,
        name: playerName,
        email: email,
        team: widget.side,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _guestError = tr('match.couldNotAddPlayer');
      });
    }
  }

  Future<void> _invite(AppUser u) async {
    // Registered players are INVITED, not added — they get a popup and only
    // join if they accept.
    await MatchRepository.instance.invitePlayer(
      widget.match.id,
      uid: u.uid,
      name: u.name,
      team: widget.side,
      byName: widget.inviterName,
    );
    if (mounted) Navigator.pop(context, u.name);
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
            Text(
                '${tr('match.addPlayerLabel')} · '
                '${widget.match.teamName(widget.side).toUpperCase()}',
                style: AppText.condensed(size: 21, weight: FontWeight.w800)),
            const SizedBox(height: 12),
            SegmentedTabs(
              tabs: [tr('match.guest'), tr('match.registered')],
              index: _mode,
              onChanged: (i) => setState(() => _mode = i),
            ),
            const SizedBox(height: 16),
            if (_mode == 0) ...[
              Text(tr('match.guestAccountHint'),
                  style: AppText.barlow(
                      size: 12, color: AppColors.dim, height: 1.4)),
              const SizedBox(height: 14),
              FieldLabel(tr('match.name')),
              YnoTextField(
                  controller: _name,
                  hint: tr('match.playerNameHint'),
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _addGuest()),
              const SizedBox(height: 12),
              FieldLabel(tr('match.email')),
              YnoTextField(
                  controller: _contact,
                  hint: tr('match.guestEmailHint'),
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _addGuest()),
              if (_guestError != null) ...[
                const SizedBox(height: 9),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.error_outline,
                          size: 15, color: kDangerColor),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_guestError!,
                          style: AppText.barlow(
                              size: 12.5, color: kDangerColor, height: 1.35)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              PrimaryButton(
                label: _busy ? tr('match.adding') : tr('match.addGuest'),
                onTap: _addGuest,
              ),
            ] else ...[
              FieldLabel(tr('match.searchByNamePhone')),
              YnoTextField(
                controller: _search,
                hint: tr('match.startTyping'),
                onSubmitted: (q) async {
                  setState(() => _searching = true);
                  final r = await UserRepository.instance.search(q);
                  if (!mounted) return;
                  setState(() {
                    _results = r;
                    _searching = false;
                  });
                },
              ),
              const SizedBox(height: 12),
              if (_searching)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_results.isEmpty)
                Text(tr('match.typeToSearch'),
                    style: AppText.barlow(size: 12, color: AppColors.dim2))
              else
                ..._results.take(6).map((u) => GestureDetector(
                      onTap: () => _invite(u),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.line),
                            borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            InitialsAvatar(
                                initials: u.initials,
                                size: 32,
                                fontSize: 12,
                                photoUrl: u.photoUrl),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.barlow(
                                          size: 14, weight: FontWeight.w700)),
                                  Text('@${u.handle}',
                                      style: AppText.barlow(
                                          size: 12, color: AppColors.dim2)),
                                ],
                              ),
                            ),
                            Text(tr('match.inviteBtn'),
                                style: AppText.barlow(
                                    size: 13,
                                    weight: FontWeight.w700,
                                    color: AppColors.txt)),
                          ],
                        ),
                      ),
                    )),
            ],
          ],
        ),
      ),
    );
  }
}
