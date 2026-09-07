import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/match_repository.dart';
import '../services/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/motion.dart';
import '../widgets/yno_scaffold.dart';

/// Fake desktop-browser top bar used on the public (guest) web screens.
class BrowserChrome extends StatelessWidget {
  const BrowserChrome({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          _dot(AppColors.loss),
          const SizedBox(width: 8),
          _dot(AppColors.gold),
          const SizedBox(width: 8),
          _dot(AppColors.win),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.bg,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(100),
              ),
              alignment: Alignment.centerLeft,
              child: Text('🔒 $url',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.barlow(size: 12, color: AppColors.dim2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(100)));
}

/// Section 6 — Public, read-only live scoreboard for a shared match link.
///
/// Anyone with the link can watch: live score, scorers, cards, timer and team
/// names update in real time. No logging controls. Reads the match id from the
/// route arguments (String).
class LiveScoreboardScreen extends StatefulWidget {
  const LiveScoreboardScreen({super.key});

  @override
  State<LiveScoreboardScreen> createState() => _LiveScoreboardScreenState();
}

class _LiveScoreboardScreenState extends State<LiveScoreboardScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Keep the advisory clock ticking for watchers.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arg = ModalRoute.of(context)?.settings.arguments;
    final matchId = arg is String ? arg : null;
    return YnoScaffold(
      appBarTitle: tr('live.liveTitle'),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const BrowserChrome(url: 'yno.app/live'),
            Expanded(
              child: matchId == null
                  ? _noMatch(context)
                  : _liveBody(context, matchId),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noMatch(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const Center(child: Text('📺', style: TextStyle(fontSize: 44))),
          const SizedBox(height: 14),
          Text(tr('live.noMatchSelected'),
              textAlign: TextAlign.center,
              style: AppText.condensed(size: 24, weight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(tr('live.openShareLink'),
              textAlign: TextAlign.center,
              style: AppText.barlow(size: 14, color: AppColors.dim)),
          const SizedBox(height: 22),
          PrimaryButton(
            label: tr('live.downloadYno'),
            height: 50,
            fontSize: 18,
            onTap: () => Navigator.of(context).pushNamed(Routes.welcome),
          ),
        ],
      );

  String _mmss(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';

  /// Frozen at the pause, exactly like the host's screen — a watcher must not
  /// see the clock run down while play is stopped.
  DateTime _clockNow(MatchModel m) => m.pausedAt ?? DateTime.now();

  bool _clockExpired(MatchModel m) =>
      m.endsAt != null && _clockNow(m).isAfter(m.endsAt!);

  bool _atHalfTime(MatchModel m) =>
      m.timingMode == TimingMode.halves &&
      (m.halfTime || (m.currentHalf == 1 && _clockExpired(m)));

  /// Stopwatch readout, counting up. Must stay identical in shape to
  /// `live_match_screen._timerText` — the same match is on both screens at
  /// once, and two different numbers for one clock is worse than either.
  String _timerText(MatchModel m) {
    if (m.status != MatchStatus.live) return '';
    if (_atHalfTime(m)) return tr('live.halfTime').toUpperCase();
    if (m.startedAt == null) return '';
    final elapsed = _clockNow(m).difference(m.startedAt!).inSeconds;
    final cap = m.endsAt?.difference(m.startedAt!).inSeconds;
    if (cap == null || cap <= 0) return _mmss(elapsed);
    if (elapsed <= cap) return _mmss(elapsed);
    // Football's added-time form, e.g. "45:00 +2:30".
    return '${_mmss(cap)} +${_mmss(elapsed - cap)}';
  }

  Widget _liveBody(BuildContext context, String matchId) {
    return StreamBuilder<MatchModel?>(
      stream: MatchRepository.instance.watchMatch(matchId),
      builder: (context, snap) {
        final match = snap.data;
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (match == null) {
          return _noMatch(context);
        }
        final live = match.status == MatchStatus.live;
        final ended = match.status == MatchStatus.ended ||
            match.status == MatchStatus.abandoned;
        final timer = _timerText(match);
        return StreamBuilder<List<MatchPlayer>>(
          stream: MatchRepository.instance.watchPlayers(matchId),
          builder: (context, pSnap) {
            final players = pSnap.data ?? const <MatchPlayer>[];
            final aCount = players.where((p) => p.team == TeamSide.a).length;
            final bCount = players.where((p) => p.team == TeamSide.b).length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                FadeSlideIn(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: match.paused
                                      ? AppColors.gold
                                      : AppColors.loss,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 7),
                          Text(
                              ended
                                  ? tr('live.fullTime').toUpperCase()
                                  : (match.paused
                                      ? tr('live.paused')
                                      : (live
                                          ? tr('live.live')
                                          : tr('live.lobby'))),
                              style: AppText.barlow(
                                  size: 12,
                                  weight: FontWeight.w800,
                                  letterSpacing: 1.1)),
                        ],
                      ),
                      if (timer.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: Text(timer,
                              style: AppText.condensed(
                                  size: 26,
                                  weight: FontWeight.w800,
                                  letterSpacing: 1)),
                        ),
                      ],
                      // Extra time, in football's own shorthand — "90+10". A
                      // watcher who opens the scoreboard mid-period would
                      // otherwise see a clock running past a full-time score
                      // with nothing to explain it. Shown after the whistle
                      // too: how a level game got settled is part of the
                      // result.
                      if (match.inExtraTime) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                                color: AppColors.primaryGlow(0.10),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.primary)),
                            child: Text(
                                match.extraTimeLabel.isEmpty
                                    ? tr('live.extraTimeOpt').toUpperCase()
                                    : '${tr('live.extraTimeOpt').toUpperCase()} · ${match.extraTimeLabel}',
                                style: AppText.barlow(
                                    size: 11,
                                    weight: FontWeight.w800,
                                    letterSpacing: 0.8)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _team('A', match.teamAName, aCount)),
                          Text('${match.scoreA} : ${match.scoreB}',
                              style: AppText.condensed(
                                  size: 52,
                                  weight: FontWeight.w800,
                                  height: 0.8)),
                          Expanded(child: _team('B', match.teamBName, bCount)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(tr('live.goals'),
                    style: AppText.barlow(
                        size: 11,
                        weight: FontWeight.w700,
                        color: AppColors.dim2,
                        letterSpacing: 1.1)),
                const SizedBox(height: 10),
                StreamBuilder<List<GoalEvent>>(
                  stream: MatchRepository.instance.watchGoals(matchId),
                  builder: (context, gSnap) {
                    final goals =
                        (gSnap.data ?? const <GoalEvent>[]).reversed.toList();
                    if (goals.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(tr('live.noGoals'),
                            style:
                                AppText.barlow(size: 13, color: AppColors.dim2)),
                      );
                    }
                    return Column(
                        children: [for (final g in goals) _goalRow(match, g)]);
                  },
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: tr('live.downloadYno'),
                  height: 50,
                  fontSize: 17,
                  onTap: () => Navigator.of(context).pushNamed(Routes.welcome),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _team(String letter, String name, int count) => Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: Text(letter,
                style: AppText.condensed(
                    size: 22, weight: FontWeight.w800, color: AppColors.txt)),
          ),
          const SizedBox(height: 8),
          Text(name.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.condensed(size: 14, weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('$count ${count == 1 ? tr('live.player') : tr('live.players')}',
              style: AppText.barlow(size: 10, color: AppColors.dim2)),
        ],
      );

  Widget _goalRow(MatchModel match, GoalEvent g) => _row(
        "${g.minute}'",
        '⚽',
        g.scorerName,
        g.assistName != null
            ? '${tr('live.goal')} · ${match.teamName(g.team)} · ${tr('live.assist')} ${g.assistName}'
            : '${tr('live.goal')} · ${match.teamName(g.team)}',
      );

  Widget _row(String minute, String icon, String title, String sub) => Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(minute,
                  style: AppText.condensed(
                      size: 15, weight: FontWeight.w700, color: AppColors.dim)),
            ),
            const SizedBox(width: 6),
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: AppText.barlow(size: 14, weight: FontWeight.w700)),
                  Text(sub,
                      style: AppText.barlow(size: 12, color: AppColors.dim2)),
                ],
              ),
            ),
          ],
        ),
      );
}
