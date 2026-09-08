import 'package:flutter/material.dart';
import '../services/rewards_config.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
import '../services/friend_repository.dart';
import '../services/match_repository.dart';
import '../services/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/confirm.dart';
import '../widgets/header.dart';
import '../widgets/motion.dart';
import '../widgets/yno_scaffold.dart';

/// Section 7 — Post Match Results.
///
/// FIFA-style three-layer results screen: the result, your personal card, and
/// the full scorecard. Also drives the 24h community vote, friend requests from
/// the scorecard, guest→registered conversion and the admin 24h edit window.
class PostMatchScreen extends StatefulWidget {
  const PostMatchScreen({super.key});

  @override
  State<PostMatchScreen> createState() => _PostMatchScreenState();
}

class _PostMatchScreenState extends State<PostMatchScreen> {
  bool _kicked = false;
  bool _editMode = false;
  String? _voteFor; // player uid selected in the vote prompt
  bool _casting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_kicked) return;
    _kicked = true;
    final id = ModalRoute.of(context)?.settings.arguments as String?;
    if (id != null) _finalize(id);
  }

  /// Fold stats + compute algorithm MOTM + open windows (idempotent), then try
  /// to resolve the community award (no-op until the 24h window closes).
  Future<void> _finalize(String id) async {
    try {
      await MatchRepository.instance.finalizeMatch(id);
      await MatchRepository.instance.resolveCommunityAward(id);
    } catch (_) {/* best-effort; streams still render what exists */}
  }

  String get _matchId => ModalRoute.of(context)!.settings.arguments as String;

  MatchPlayer? _find(List<MatchPlayer> players, String? uid) {
    if (uid == null) return null;
    for (final p in players) {
      if (p.uid == uid) return p;
    }
    return null;
  }

  void _goHome() =>
      Navigator.pushNamedAndRemoveUntil(context, Routes.home, (_) => false);

  @override
  Widget build(BuildContext context) {
    final id = _matchId;
    final me = AuthRepository.instance.uid;
    return YnoScaffold(
      child: SafeArea(
        bottom: false,
        child: StreamBuilder<MatchModel?>(
          stream: MatchRepository.instance.watchMatch(id),
          builder: (context, matchSnap) {
            final match = matchSnap.data;
            if (match == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return StreamBuilder<List<MatchPlayer>>(
              stream: MatchRepository.instance.watchPlayers(id),
              builder: (context, playersSnap) {
                final players = playersSnap.data ?? const <MatchPlayer>[];
                final mine = _find(players, me);
                final isGuestViewer = me != null && me.startsWith('g_');
                final isParticipant = mine != null;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 44),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ScreenHeader(
                        title: tr('live.fullTime'),
                        subtitle: match.name,
                        titleSize: 24,
                        onBack: _goHome,
                      ),
                      const SizedBox(height: 18),

                      // Guest conversion prompt — the first thing a guest sees.
                      if (isGuestViewer) ...[
                        FadeSlideIn(child: _guestPrompt(mine)),
                        const SizedBox(height: 18),
                      ],

                      // LAYER 1 — the result.
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 80),
                        child: _resultLayer(match, mine),
                      ),
                      const SizedBox(height: 22),

                      // Community award (vote / count / winner).
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 160),
                        child: _communityLayer(match, players, me, isParticipant),
                      ),
                      const SizedBox(height: 22),

                      // LAYER 2 — your match.
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 240),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SectionLabel(tr('live.yourMatch')),
                            const SizedBox(height: 10),
                            _personalLayer(match, mine),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // LAYER 3 — full scorecard.
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 320),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SectionLabel(tr('live.fullScorecard')),
                            const SizedBox(height: 10),
                            _scorecard(
                                match, players, me, isGuestViewer, mine?.name),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Who converted from the spot. Only on matches settled by
                      // a shootout, and only those recorded since the takers
                      // started being captured (2026-09-07) — an older
                      // penalties result has the score but no names, so the
                      // list stays hidden rather than claiming nobody scored.
                      if (match.outcomeMethod == 'penalties') ...[
                        _shootoutTakers(match),
                        const SizedBox(height: 22),
                      ],

                      // Admin 24h edit window.
                      if (me != null &&
                          me == match.adminUid &&
                          _editableNow(match)) ...[
                        _editLayer(match, players),
                        const SizedBox(height: 22),
                      ],

                      PrimaryButton(
                        label: tr('common.done'),
                        height: 54,
                        fontSize: 20,
                        onTap: _goHome,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  bool _editableNow(MatchModel m) =>
      m.editableUntil != null && m.editableUntil!.isAfter(DateTime.now());

  // ---------------------------------------------------------------- helpers

  String _teamInitials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String _outcomeLabel(MatchModel m) {
    switch (m.outcomeMethod) {
      case 'fullTime':
        return tr('live.fullTime');
      case 'penalties':
        return tr('live.penalties');
      case 'goldenGoal':
        return tr('live.goldenGoal');
      case 'draw':
        return tr('result.draw');
      case 'abandoned':
        return tr('live.endedEarly');
      default:
        if (m.status == MatchStatus.abandoned) return tr('live.endedEarly');
        return m.isLevel ? tr('result.draw') : tr('live.fullTime');
    }
  }

  String _durationLabel(int? sec) {
    if (sec == null || sec <= 0) return '—';
    final m = sec ~/ 60;
    final s = sec % 60;
    if (m == 0) return '${s}s';
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }

  String _detailLine(MatchModel m) {
    final bits = <String>[if (m.hasFixedFormat) m.format];
    if (m.surface.trim().isNotEmpty) bits.add(m.surface.trim());
    if (m.location.trim().isNotEmpty) bits.add(m.location.trim());
    final when = m.endedAt ?? m.createdAt;
    if (when != null) bits.add(DateFormat('d MMM yyyy · HH:mm').format(when));
    bits.add(_durationLabel(m.actualDurationSec));
    return bits.join('  ·  ');
  }

  // ---------------------------------------------------------------- LAYER 1

  Widget _resultLayer(MatchModel match, MatchPlayer? mine) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _teamBlock(match, TeamSide.a, mine),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Text('${match.scoreA} – ${match.scoreB}',
                        style: AppText.condensed(
                            size: 44, weight: FontWeight.w800, height: 1)),
                    // A shootout score only exists on matches settled from the
                    // spot, and only since it started being captured — older
                    // penalties results still show the outcome label alone.
                    if (match.hasShootoutScore) ...[
                      const SizedBox(height: 2),
                      Text('(${match.penaltyA} – ${match.penaltyB})',
                          style: AppText.condensed(
                              size: 20,
                              weight: FontWeight.w800,
                              color: AppColors.primary,
                              height: 1)),
                    ],
                    const SizedBox(height: 6),
                    Text(_outcomeLabel(match).toUpperCase(),
                        style: AppText.label()),
                    // "90+10" under the result, so a scoreline that only makes
                    // sense with the added period explains itself. Matches that
                    // finished inside regulation carry `extraTimeMin == 0` and
                    // show nothing.
                    if (match.inExtraTime) ...[
                      const SizedBox(height: 3),
                      Text(
                          match.extraTimeLabel.isEmpty
                              ? tr('live.extraTimeOpt').toUpperCase()
                              : '${tr('live.extraTimeOpt').toUpperCase()} · ${match.extraTimeLabel}',
                          textAlign: TextAlign.center,
                          style: AppText.barlow(
                              size: 10,
                              weight: FontWeight.w700,
                              color: AppColors.dim,
                              letterSpacing: 0.8)),
                    ],
                  ],
                ),
              ),
              _teamBlock(match, TeamSide.b, mine),
            ],
          ),
          const SizedBox(height: 18),
          Text(_detailLine(match),
              textAlign: TextAlign.center,
              style:
                  AppText.barlow(size: 12, color: AppColors.dim, height: 1.5)),
        ],
      ),
    );
  }

  Widget _teamBlock(MatchModel match, TeamSide side, MatchPlayer? mine) {
    final name = match.teamName(side);
    final isMine = mine != null && mine.team == side;
    final result = match.resultFor(side); // win | loss | draw
    // In the monochrome wireframe, win/loss/draw all resolve to black; the
    // WIN / LOSS / DRAW label + outlined box carry the meaning.
    final resultColor = result == 'win'
        ? AppColors.win
        : (result == 'loss' ? AppColors.loss : AppColors.dim);
    return Expanded(
      child: Column(
        children: [
          InitialsAvatar(
              initials: _teamInitials(name), size: 54, fontSize: 18),
          const SizedBox(height: 8),
          Text(name.toUpperCase(),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppText.condensed(size: 14, weight: FontWeight.w700)),
          if (isMine) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: resultColor, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(tr('result.$result').toUpperCase(),
                  style: AppText.condensed(
                      size: 13, weight: FontWeight.w800, color: resultColor)),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------ COMMUNITY

  Widget _communityLayer(MatchModel match, List<MatchPlayer> players,
      String? me, bool isParticipant) {
    final closed = match.voteCloseAt == null ||
        !match.voteCloseAt!.isAfter(DateTime.now());

    // Voting already closed — announce the winner (or that none was given).
    if (closed) {
      final winner = _find(players, match.communityPlayerUid);
      return _communityCard(
        title: tr('live.communityAward'),
        child: winner == null
            ? Text(tr('live.noCommunityAward'),
                style: AppText.barlow(size: 13, color: AppColors.dim))
            : Row(
                children: [
                  InitialsAvatar(
                      initials: winner.initials, size: 40, fontSize: 15),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${tr('live.winner')} · +${RewardsRepository.current.communityPlayerPoints} ${tr('live.pts')}',
                            style: AppText.label()),
                        const SizedBox(height: 2),
                        Text(winner.name,
                            style: AppText.barlow(
                                size: 16, weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const Text('🤝', style: TextStyle(fontSize: 20)),
                ],
              ),
      );
    }

    // Window open. Only participants vote (V1: no fan voting).
    if (!isParticipant || me == null) {
      return _communityCard(
        title: tr('live.communityAward'),
        child: Text(
            '${tr('live.playersVoting')} ${_closesIn(match.voteCloseAt!)}.',
            style: AppText.barlow(size: 13, color: AppColors.dim, height: 1.4)),
      );
    }

    return StreamBuilder<bool>(
      stream: MatchRepository.instance.watchHasVoted(match.id, me),
      builder: (context, votedSnap) {
        final hasVoted = votedSnap.data ?? false;
        return StreamBuilder<int>(
          stream: MatchRepository.instance.watchVoteCount(match.id),
          builder: (context, countSnap) {
            final count = countSnap.data ?? 0;
            if (hasVoted) {
              return _communityCard(
                title: tr('live.communityAward'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('✓ ${tr('live.voteSubmitted')}',
                        style: AppText.barlow(
                            size: 14, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                        '$count ${count == 1 ? tr('live.voteWord') : tr('live.votesWord')} ${tr('live.winnerAnnounced')} ${_closesIn(match.voteCloseAt!)}.',
                        style: AppText.barlow(
                            size: 12, color: AppColors.dim, height: 1.4)),
                  ],
                ),
              );
            }
            return _voteCard(match, players, me, count);
          },
        );
      },
    );
  }

  Widget _voteCard(
      MatchModel match, List<MatchPlayer> players, String me, int count) {
    return _communityCard(
      title: '${tr('live.communityAward')} — ${tr('live.yourVote')}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              '${tr('live.pickBest')} · $count ${tr('live.soFar')} · ${tr('live.closesWord')} ${_closesIn(match.voteCloseAt!)}.',
              style: AppText.barlow(size: 12, color: AppColors.dim, height: 1.4)),
          const SizedBox(height: 12),
          ...players.map((p) {
            final selected = _voteFor == p.uid;
            return GestureDetector(
              onTap: () => setState(() => _voteFor = p.uid),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: AppColors.line, width: selected ? 2 : 1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: selected
                          ? Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.txt,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.barlow(
                              size: 14,
                              weight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400)),
                    ),
                    Text(match.teamName(p.team).toUpperCase(),
                        style: AppText.barlow(size: 10, color: AppColors.dim2)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          PrimaryButton(
            label: _casting ? tr('live.submitting') : tr('live.castVote'),
            height: 48,
            fontSize: 16,
            onTap: _voteFor == null ? null : () => _castVote(match.id, me),
          ),
        ],
      ),
    );
  }

  Future<void> _castVote(String matchId, String me) async {
    final target = _voteFor;
    if (target == null || _casting) return;
    setState(() => _casting = true);
    try {
      await MatchRepository.instance.castVote(matchId, me, target);
      if (!mounted) return;
      showYnoToast(context, tr('live.voteSubmittedToast'));
    } catch (_) {
      if (!mounted) return;
      showYnoToast(context, tr('live.voteFailed'));
    } finally {
      if (mounted) setState(() => _casting = false);
    }
  }

  String _closesIn(DateTime close) {
    final diff = close.difference(DateTime.now());
    if (diff.isNegative) return tr('live.soon');
    if (diff.inHours >= 1) {
      return '${tr('live.inPrefix')} ${diff.inHours}${tr('live.hourShort')}';
    }
    if (diff.inMinutes >= 1) {
      return '${tr('live.inPrefix')} ${diff.inMinutes}${tr('live.minShort')}';
    }
    return tr('live.soon');
  }

  Widget _communityCard({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(title),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  /// The shootout, kick by kick, split by team and listed in the order taken.
  ///
  /// Streamed rather than passed in because it is dead weight on the ~99% of
  /// scorecards that never went to penalties — the collection is only read when
  /// this widget is built at all.
  Widget _shootoutTakers(MatchModel match) {
    return StreamBuilder<List<PenaltyEvent>>(
      stream: MatchRepository.instance.watchPenalties(match.id),
      builder: (context, snap) {
        final kicks = snap.data ?? const <PenaltyEvent>[];
        if (kicks.isEmpty) return const SizedBox.shrink();
        Widget column(TeamSide side, String teamName) {
          final side_ = kicks.where((k) => k.team == side).toList()
            ..sort((a, b) => a.order.compareTo(b.order));
          return Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(teamName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.condensed(
                        size: 15, weight: FontWeight.w800)),
                const SizedBox(height: 6),
                for (final k in side_)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text('⚽ ${k.scorerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.barlow(size: 13)),
                  ),
                if (side_.isEmpty)
                  Text('—', style: AppText.barlow(size: 13, color: AppColors.dim2)),
              ],
            ),
          );
        }

        return _communityCard(
          title: tr('live.shootoutTitle'),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              column(TeamSide.a, match.teamAName),
              const SizedBox(width: 12),
              column(TeamSide.b, match.teamBName),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------- GUEST

  Widget _guestPrompt(MatchPlayer? mine) {
    final goals = mine?.goals ?? 0;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('live.statsSaved').toUpperCase(),
              style: AppText.label(color: AppColors.txt)),
          const SizedBox(height: 8),
          Text(
              goals > 0
                  ? '${tr('live.youScored')} $goals ${goals == 1 ? tr('live.goalWord') : tr('live.goalsWord')} ${tr('live.inThisMatchCreate')}'
                  : tr('live.recordSaved'),
              style: AppText.barlow(size: 14, height: 1.45)),
          const SizedBox(height: 14),
          PrimaryButton(
            label: tr('live.registerNow'),
            height: 50,
            fontSize: 17,
            onTap: () => Navigator.pushNamed(context, Routes.signup),
          ),
          const SizedBox(height: 6),
          GhostButton(
            label: tr('live.remindLater'),
            onTap: _goHome,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- LAYER 2

  Widget _personalLayer(MatchModel match, MatchPlayer? mine) {
    if (mine == null) {
      return SurfaceCard(
        child: Text(tr('live.didNotPlay'),
            style: AppText.barlow(size: 14, color: AppColors.dim)),
      );
    }
    final isMotm = mine.uid == match.motmAUid;
    final isCommunity = mine.uid == match.communityPlayerUid;
    final points = (isMotm ? RewardsRepository.current.manOfMatchPoints : 0) +
        (isCommunity ? RewardsRepository.current.communityPlayerPoints : 0);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InitialsAvatar(initials: mine.initials, size: 44, fontSize: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mine.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.barlow(
                            size: 17, weight: FontWeight.w700)),
                    Text(match.teamName(mine.team).toUpperCase(),
                        style: AppText.barlow(size: 11, color: AppColors.dim)),
                  ],
                ),
              ),
              if (isMotm) const Text('🏆', style: TextStyle(fontSize: 22)),
            ],
          ),
          if (isMotm || isCommunity) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isMotm) TagChip('🏆 ${tr('live.manOfMatch')}'),
                if (isCommunity) TagChip('🤝 ${tr('live.communityAward')}'),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: StatTile(
                      value: '${mine.goals}', label: tr('live.goalsStat'))),
              const SizedBox(width: 10),
              Expanded(
                  child: StatTile(
                      value: '${mine.assists}', label: tr('live.assistsStat'))),
            ],
          ),
          const SizedBox(height: 10),
          // Cards were removed from the product, so goals/assists/points are
          // the whole personal line now.
          StatTile(value: '+$points', label: tr('live.ynoPoints')),
          const SizedBox(height: 14),
          SecondaryButton(
            label: tr('live.shareResult'),
            height: 48,
            fontSize: 16,
            icon: const Icon(Icons.ios_share, size: 18, color: AppColors.txt),
            onTap: () => _share(match, mine, points, isMotm),
          ),
        ],
      ),
    );
  }

  Future<void> _share(
      MatchModel match, MatchPlayer mine, int points, bool isMotm) async {
    final result = tr('result.${match.resultFor(mine.team)}').toUpperCase();
    final buf = StringBuffer()
      ..writeln('⚽ ${match.teamAName} ${match.scoreA}–${match.scoreB} ${match.teamBName}'
          '${match.hasShootoutScore ? ' (${match.penaltyA}–${match.penaltyB} ${tr('live.penalties')})' : ''}')
      ..writeln('$result · ${_outcomeLabel(match)}')
      ..writeln('')
      ..writeln('${tr('live.myMatch')} — ${mine.name}:')
      ..writeln('• ${mine.goals} ${tr('live.goalsLower')} · ${mine.assists} ${tr('live.assistsLower')}')
      ..writeln('• +$points ${tr('live.ynoPointsLower')}${isMotm ? ' · 🏆 ${tr('live.motm')}' : ''}')
      ..writeln('')
      ..write(tr('live.trackedOnYno'));
    try {
      await Share.share(buf.toString());
    } catch (_) {
      if (!mounted) return;
      showYnoToast(context, tr('live.shareFailed'));
    }
  }

  // ------------------------------------------------------------- LAYER 3

  Widget _scorecard(MatchModel match, List<MatchPlayer> players, String? me,
      bool isGuestViewer, String? myName) {
    final teamA = players.where((p) => p.team == TeamSide.a).toList();
    final teamB = players.where((p) => p.team == TeamSide.b).toList();
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _teamHead(match.teamAName, match.scoreA, showLegend: true),
          for (final p in teamA)
            _scoreRow(match, p, me, isGuestViewer, myName),
          _teamHead(match.teamBName, match.scoreB),
          for (final p in teamB)
            _scoreRow(match, p, me, isGuestViewer, myName),
        ],
      ),
    );
  }

  Widget _teamHead(String name, int score, {bool showLegend = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
          border: showLegend
              ? null
              : const Border(top: BorderSide(color: AppColors.line))),
      child: Row(
        children: [
          Expanded(
            child: Text(name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.condensed(size: 15, weight: FontWeight.w800)),
          ),
          if (showLegend)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(tr('live.gaLegend'),
                  style: AppText.barlow(size: 11, color: AppColors.dim)),
            ),
          Text('$score',
              style: AppText.condensed(size: 18, weight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _scoreRow(MatchModel match, MatchPlayer p, String? me,
      bool isGuestViewer, String? myName) {
    final isMe = me != null && p.uid == me;
    final isMotm = p.uid == match.motmAUid;
    final isCommunity = p.uid == match.communityPlayerUid;
    return GestureDetector(
      onTap: () => _openProfile(p),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Own-row marker (monochrome highlight).
            Container(
              width: 3,
              height: 34,
              color: isMe ? AppColors.txt : AppColors.surface,
            ),
            const SizedBox(width: 9),
            InitialsAvatar(initials: p.initials, size: 32, fontSize: 12),
            const SizedBox(width: 10),
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
                                size: 14,
                                weight:
                                    isMe ? FontWeight.w700 : FontWeight.w400)),
                      ),
                      if (isMotm)
                        const Padding(
                            padding: EdgeInsets.only(left: 5),
                            child: Text('🏆', style: TextStyle(fontSize: 12))),
                      if (isCommunity)
                        const Padding(
                            padding: EdgeInsets.only(left: 5),
                            child: Text('🤝', style: TextStyle(fontSize: 12))),
                    ],
                  ),
                  if (p.isGuest)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(tr('badge.guest'),
                          style:
                              AppText.barlow(size: 10, color: AppColors.dim2)),
                    ),
                ],
              ),
            ),
            // Add Friend action (registered viewer, registered target, not me).
            if (me != null &&
                !isGuestViewer &&
                !isMe &&
                !p.isGuest)
              _friendButton(me, p, myName),
            const SizedBox(width: 8),
            SizedBox(
              width: 46,
              child: Text('${p.goals} · ${p.assists}',
                  textAlign: TextAlign.right,
                  style: AppText.condensed(size: 14, weight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _friendButton(String me, MatchPlayer p, String? myName) {
    return StreamBuilder<FriendEdge?>(
      stream: FriendRepository.instance.watchFriendship(me, p.uid),
      builder: (context, snap) {
        final edge = snap.data;
        String label;
        VoidCallback? onTap;
        if (edge == null) {
          label = '+ ${tr('common.add')}';
          onTap = () => _addFriend(me, p, myName);
        } else if (edge.status == FriendStatus.accepted) {
          label = tr('live.friends');
          onTap = null;
        } else {
          label = tr('live.pending');
          onTap = null;
        }
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(label.toUpperCase(),
                style: AppText.barlow(
                    size: 10,
                    weight: FontWeight.w700,
                    color: onTap == null ? AppColors.dim : AppColors.txt)),
          ),
        );
      },
    );
  }

  Future<void> _addFriend(String me, MatchPlayer target, String? myName) async {
    try {
      await FriendRepository.instance.sendRequest(
        me,
        target.uid,
        myName: myName ?? tr('live.aPlayer'),
      );
      if (!mounted) return;
      showYnoToast(context, tr('live.requestSent'));
    } catch (_) {
      if (!mounted) return;
      showYnoToast(context, tr('live.requestFailed'));
    }
  }

  void _openProfile(MatchPlayer p) {
    if (p.isGuest) {
      showYnoToast(context, '${p.name} ${tr('live.notOnYno')}');
      return;
    }
    Navigator.pushNamed(context, Routes.profilePublic, arguments: p.uid);
  }

  // ------------------------------------------------------------- EDIT (admin)

  Widget _editLayer(MatchModel match, List<MatchPlayer> players) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(tr('live.adminEditMatch'),
              trailing: GestureDetector(
                onTap: () => setState(() => _editMode = !_editMode),
                child: Text(
                    (_editMode ? tr('common.close') : tr('common.edit'))
                        .toUpperCase(),
                    style: AppText.barlow(
                        size: 12, weight: FontWeight.w700)),
              )),
          const SizedBox(height: 8),
          Text(tr('live.editHelp'),
              style: AppText.barlow(size: 12, color: AppColors.dim, height: 1.4)),
          if (_editMode) ...[
            const SizedBox(height: 12),
            StreamBuilder<List<GoalEvent>>(
              stream: MatchRepository.instance.watchGoals(match.id),
              builder: (context, snap) {
                final goals = snap.data ?? const <GoalEvent>[];
                if (goals.isEmpty) {
                  return Text(tr('live.noGoalsLogged'),
                      style:
                          AppText.barlow(size: 13, color: AppColors.dim2));
                }
                return Column(
                  children:
                      goals.map((g) => _goalEditRow(match, g, players)).toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _goalEditRow(
      MatchModel match, GoalEvent g, List<MatchPlayer> players) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${g.minute}'  ${g.scorerName}",
                    style: AppText.barlow(size: 13, weight: FontWeight.w700)),
                if (g.assistName != null)
                  Text('${tr('live.assistLabel')} ${g.assistName}',
                      style: AppText.barlow(size: 11, color: AppColors.dim)),
              ],
            ),
          ),
          _miniBtn(tr('live.reassign').toUpperCase(),
              () => _reassignGoal(match, g, players)),
          const SizedBox(width: 6),
          _miniBtn(tr('common.delete').toUpperCase(),
              () => _deleteGoal(match.id, g),
              danger: true),
        ],
      ),
    );
  }

  Widget _miniBtn(String label, VoidCallback onTap, {bool danger = false}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(
              color: danger ? kDangerColor.withValues(alpha: 0.55) : AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: AppText.barlow(
                size: 10,
                weight: FontWeight.w700,
                color: danger ? kDangerColor : AppColors.txt)),
      ),
    );
  }

  Future<void> _deleteGoal(String matchId, GoalEvent g) async {
    final ok = await showConfirm(
      context,
      title: tr('live.deleteGoalQ'),
      message: '${g.scorerName} — ${tr('live.deleteGoalBody')}',
      confirmLabel: tr('common.delete'),
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await MatchRepository.instance.deleteGoal(matchId, g);
      if (!mounted) return;
      showYnoToast(context, tr('live.goalDeleted'));
    } catch (_) {
      if (!mounted) return;
      showYnoToast(context, tr('live.goalDeleteFailed'));
    }
  }

  Future<void> _reassignGoal(
      MatchModel match, GoalEvent g, List<MatchPlayer> players) async {
    // Pick a new scorer among the goal's team.
    final candidates = players.where((p) => p.team == g.team).toList();
    final picked = await showModalBottomSheet<MatchPlayer>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(tr('live.reassignScorer').toUpperCase(),
                  style: AppText.label(color: AppColors.txt)),
            ),
            ...candidates.map((p) => ListTile(
                  title: Text(p.name,
                      style: AppText.barlow(size: 15, weight: FontWeight.w600)),
                  onTap: () => Navigator.pop(ctx, p),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final existingAssist = _find(players, g.assistUid);
    try {
      await MatchRepository.instance.correctGoal(
        match.id,
        g,
        newScorer: picked,
        newAssist: existingAssist,
      );
      if (!mounted) return;
      showYnoToast(context, tr('live.goalReassigned'));
    } catch (_) {
      if (!mounted) return;
      showYnoToast(context, tr('live.reassignFailed'));
    }
  }
}
