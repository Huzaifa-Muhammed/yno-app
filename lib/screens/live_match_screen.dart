import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
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

/// Section 6 — Live Match Logging.
///
/// Admin-only event logging surface: a large scoreboard, two big team Goal
/// buttons, pause/resume (with restart while paused), a live goal feed, inline
/// mid-game join approvals, a settings sheet (extend / restart / quit) and an
/// always visible End Match button. Non-admin viewers get a read-only version.
/// Cards and substitutions were removed from the product — this screen logs
/// goals only.
class LiveMatchScreen extends StatefulWidget {
  const LiveMatchScreen({super.key});

  @override
  State<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends State<LiveMatchScreen>
    with TickerProviderStateMixin {
  Timer? _ticker;
  late final AnimationController _pulse;
  bool _ending = false;
  bool _halfPauseSent = false;
  // Guards a one-shot exit: once the match stops being live (creator ended it)
  // every participant is moved to the results exactly once; and if the match is
  // discarded out from under them, they're sent home once.
  bool _left = false;
  bool _hadMatch = false;

  String get _matchId => ModalRoute.of(context)!.settings.arguments as String;

  @override
  void initState() {
    super.initState();
    // Drive the clock display once per second.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  /// The match creator alone drives the match: logging, ending, everything.
  /// Equivalent to [MatchModel.canLogLive] — kept as one check so the screen
  /// can never drift from the model's rule.
  bool _isAdmin(MatchModel m) => m.canLogLive(AuthRepository.instance.uid);

  /// Match is over → send this participant to the results (once). The creator
  /// drives their own navigation from End / quit, so this only moves everyone
  /// else. Non-creators go straight to the scorecard (the outcome picker for a
  /// level draw is the creator's call).
  void _redirectToResults(String matchId) {
    if (_left) return;
    _left = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context)
          .pushReplacementNamed(Routes.postMatch, arguments: matchId);
    });
  }

  /// A finished match whose level score the host has not settled yet.
  ///
  /// Only `ended` counts — an abandoned match has no outcome to choose, so it
  /// must not trap anyone here.
  bool _awaitingHostDecision(MatchModel m) =>
      m.status == MatchStatus.ended && m.isLevel && m.outcomeMethod == null;

  /// How long players are held while the host picks draw / extra time /
  /// penalties before they are offered a way out.
  ///
  /// The hold has no other release: `outcomeMethod` is written by the outcome
  /// screen, and if the host's phone dies on it — battery, crash, a call — that
  /// write never lands. Without this the panel below is a permanent trap for
  /// everyone else in the match, since the screen deliberately can't be popped.
  /// Long enough that nobody escapes a host who is simply reading the options.
  static const _hostDecisionGrace = Duration(minutes: 3);

  /// True once the host has had [_hostDecisionGrace] and still written nothing.
  bool _hostDecisionOverdue(MatchModel m) =>
      m.endedAt != null &&
      DateTime.now().difference(m.endedAt!) > _hostDecisionGrace;

  /// Shown to non-creators while [_awaitingHostDecision]. The screen is already
  /// wrapped in `PopScope(canPop: false)`, so this really does hold them.
  ///
  /// ⚠️ This panel only started rendering on 2026-09-07. `endMatch` used to
  /// stamp `outcomeMethod: 'draw'` on a level match, which made
  /// [_awaitingHostDecision] false immediately and released everyone to a
  /// scorecard reading "Draw" while the host was still choosing. Any change
  /// that reintroduces an early write here silently disables the whole hold.
  Widget _hostDecidingPanel(MatchModel m) {
    final overdue = _hostDecisionOverdue(m);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${tr('live.fullTime').toUpperCase()} · ${tr('live.level').toUpperCase()}',
                style: AppText.label(color: AppColors.dim)),
            const SizedBox(height: 14),
            Text('${m.scoreA} – ${m.scoreB}',
                style: AppText.condensed(
                    size: 52, weight: FontWeight.w800, height: 1)),
            const SizedBox(height: 22),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(height: 18),
            Text(tr('live.hostDecidingTitle'),
                textAlign: TextAlign.center,
                style: AppText.condensed(size: 24, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(tr('live.hostDecidingSub'),
                textAlign: TextAlign.center,
                style: AppText.barlow(
                    size: 14, color: AppColors.dim, height: 1.45)),
            // The escape hatch, offered only once the host is overdue. The
            // result they'll see is the level score as it stands; if the host
            // does eventually choose, `finalizeMatch` and the scorecard both
            // read the match document, so the real outcome lands there anyway.
            if (overdue) ...[
              const SizedBox(height: 26),
              GhostButton(
                label: tr('live.hostDecidingLeave'),
                onTap: () => _redirectToResults(m.id),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The match document vanished (creator discarded it) → bail to home once.
  void _redirectHome() {
    if (_left) return;
    _left = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(Routes.home, (_) => false);
    });
  }

  /// Whole minutes elapsed since kickoff (used to stamp events).
  int _elapsedMinutes(MatchModel m) {
    if (m.startedAt == null) return 0;
    return DateTime.now().difference(m.startedAt!).inMinutes;
  }

  /// "Now" for every clock read — frozen at the pause so a paused match neither
  /// ticks down nor trips half-time while the host sorts something out.
  DateTime _clockNow(MatchModel m) => m.pausedAt ?? DateTime.now();

  bool _clockExpired(MatchModel m) =>
      m.endsAt != null && _clockNow(m).isAfter(m.endsAt!);

  /// True while the two-halves match is paused between halves.
  bool _atHalfTime(MatchModel m) =>
      m.timingMode == TimingMode.halves &&
      (m.halfTime || (m.currentHalf == 1 && _clockExpired(m)));

  String _mmss(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';

  /// Seconds of football played so far — the stopwatch value.
  ///
  /// `startedAt` is the single source: it is pushed forward by every pause
  /// ([MatchRepository.resumeMatch]), by half-time ([startSecondHalf]) and by
  /// the outcome-screen gap before extra time ([startExtraTime]), so the
  /// difference from it is playing time and nothing else. That is why this
  /// needs no per-period bookkeeping.
  int _elapsedSeconds(MatchModel m) =>
      m.startedAt == null ? 0 : _clockNow(m).difference(m.startedAt!).inSeconds;

  /// Where the current period is scheduled to end, as an elapsed value.
  ///
  /// Derived from `endsAt` rather than from `durationMin` so it follows every
  /// adjustment automatically: the host's +5/+10 extends, the second half
  /// (`endsAt` is re-set from the restart, and `startedAt` has absorbed the
  /// interval, so this lands on 90:00 for two 45s), and extra time.
  int? _capSeconds(MatchModel m) => (m.startedAt == null || m.endsAt == null)
      ? null
      : m.endsAt!.difference(m.startedAt!).inSeconds;

  /// Timer readout — a **stopwatch**, counting up, as a referee's watch does.
  ///
  /// It counted DOWN to zero on a timed match until 2026-09-07 and then showed
  /// `+MM:SS`, which meant the number on screen never matched the minute a goal
  /// was being stamped with (`_elapsedMinutes` has always counted up), and a
  /// player glancing at it could not say what minute the match was in.
  ///
  /// Past the scheduled end it switches to football's own added-time form —
  /// `45:00 +2:30` — rather than running on, so full time stays readable as the
  /// moment it was supposed to be.
  String _timerText(MatchModel m) {
    if (m.startedAt == null) return '--:--';
    if (m.halfTime) return tr('live.halfReadout');
    final elapsed = _elapsedSeconds(m);
    final cap = _capSeconds(m);
    // No clock set: a plain stopwatch, with nothing to be "over".
    if (cap == null || cap <= 0) return _mmss(elapsed);
    if (elapsed <= cap) return _mmss(elapsed);
    return '${_mmss(cap)} +${_mmss(elapsed - cap)}';
  }

  /// The period everyone is watching — "SECOND HALF", "HALF TIME", and once the
  /// host has granted added minutes, "EXTRA TIME · 90+10".
  ///
  /// Extra time wins over the half label: it is played straight through, so
  /// "SECOND HALF" would be wrong, and `currentHalf` is left at 2 from
  /// regulation. It also shows for [TimingMode.full] and even [TimingMode.none]
  /// — a match with no clock can still go to extra time, and the players
  /// watching deserve to know the game was extended.
  String _phaseLabel(MatchModel m) {
    if (m.inExtraTime) {
      final label = m.extraTimeLabel; // '' when there is no clock to measure.
      return label.isEmpty
          ? tr('live.extraTimeOpt').toUpperCase()
          : '${tr('live.extraTimeOpt').toUpperCase()} · $label';
    }
    if (m.timingMode != TimingMode.halves) return '';
    if (_atHalfTime(m)) return tr('live.halfTime').toUpperCase();
    return m.currentHalf == 1
        ? tr('live.firstHalf').toUpperCase()
        : tr('live.secondHalf').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final id = _matchId;
    // While live the screen is sticky: the system back button can't dismiss it.
    // Players leave only when the match stops being live (auto-redirect below);
    // the creator leaves via End / quit.
    return PopScope(
      canPop: false,
      child: YnoScaffold(
        appBarTitle: tr('live.appTitle'),
        showBackButton: false,
        child: SafeArea(
          top: false,
          child: StreamBuilder<MatchModel?>(
            stream: MatchRepository.instance.watchMatch(id),
            builder: (context, matchSnap) {
              final match = matchSnap.data;
              if (match == null) {
                // Was showing a match that has now been deleted → go home.
                if (_hadMatch) _redirectHome();
                return const Center(child: CircularProgressIndicator());
              }
              _hadMatch = true;
              final admin = _isAdmin(match);

              // Match ended/abandoned → move every non-creator to the results.
              // The creator's own End/quit flow handles their navigation.
              if (match.status != MatchStatus.live) {
                if (!admin) {
                  // …except on a level score the host has not settled yet.
                  // Sending players to the scorecard here showed them a "draw"
                  // and let them walk away while the host was still choosing
                  // extra time or a shootout. Hold them until `outcomeMethod`
                  // is written; the stream then rebuilds and moves them on.
                  if (_awaitingHostDecision(match)) {
                    return _hostDecidingPanel(match);
                  }
                  _redirectToResults(match.id);
                }
                return const Center(child: CircularProgressIndicator());
              }

              // Auto-enter half-time once the first half clock runs out so every
              // watcher's scoreboard flips to "Half Time" without admin action.
              if (admin &&
                  match.timingMode == TimingMode.halves &&
                  match.currentHalf == 1 &&
                  !match.halfTime &&
                  _clockExpired(match) &&
                  !_halfPauseSent) {
                _halfPauseSent = true;
                MatchRepository.instance.pauseHalfTime(match.id);
              }

              return StreamBuilder<List<MatchPlayer>>(
                stream: MatchRepository.instance.watchPlayers(id),
                builder: (context, playerSnap) {
                  final players = playerSnap.data ?? const <MatchPlayer>[];
                  return Column(
                    children: [
                      FadeSlideIn(child: _header(match, admin)),
                      _scoreboard(match),
                      if (admin) _pendingBanner(match),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                          child: Text(tr('live.matchFeed').toUpperCase(),
                              style: AppText.label()),
                        ),
                      ),
                      Expanded(child: _feed(match)),
                      if (admin)
                        _actionArea(match, players)
                      // Everyone else is read-only. At half-time — or while the
                      // host has the clock stopped — say why the match isn't
                      // moving rather than repeating the generic note.
                      else if (_atHalfTime(match))
                        _halfTimeWaiting()
                      else if (match.paused)
                        _pausedNote()
                      else
                        _viewerNote(),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ---- Header: pulsing LIVE dot + timer + settings ----------------------

  Widget _header(MatchModel match, bool admin) {
    final over = _clockExpired(match) && !_atHalfTime(match);
    final phase = _phaseLabel(match);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.line2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // The pulse is what says "running" — a paused match shows a
                // steady gold dot instead, so the state reads at a glance.
                if (match.paused)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppColors.gold, shape: BoxShape.circle),
                  )
                else
                  FadeTransition(
                    opacity: _pulse,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: AppColors.loss, shape: BoxShape.circle),
                    ),
                  ),
                const SizedBox(width: 7),
                Text(
                    match.paused
                        ? tr('live.paused')
                        : (over ? tr('live.extra') : tr('live.live')),
                    style: AppText.barlow(
                        size: 12,
                        weight: FontWeight.w800,
                        letterSpacing: 1.2)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(_timerText(match),
                    style: AppText.condensed(
                        size: 26, weight: FontWeight.w800, letterSpacing: 1)),
                if (phase.isNotEmpty)
                  Text(phase,
                      style: AppText.barlow(
                          size: 10,
                          weight: FontWeight.w700,
                          color: AppColors.dim,
                          letterSpacing: 1)),
              ],
            ),
          ),
          if (admin)
            IconChip(
              onTap: () => _settingsSheet(match),
              size: 40,
              radius: 12,
              child: const Icon(Icons.settings_outlined,
                  size: 20, color: AppColors.txt),
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ---- Scoreboard -------------------------------------------------------

  Widget _scoreboard(MatchModel match) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Row(
        children: [
          Expanded(child: _teamBlock('A', match.teamAName)),
          Row(
            children: [
              Text('${match.scoreA}',
                  style: AppText.condensed(
                      size: 60, weight: FontWeight.w800, height: 0.8)),
              const SizedBox(width: 12),
              Text(':',
                  style: AppText.condensed(
                      size: 28,
                      weight: FontWeight.w700,
                      color: AppColors.dim2)),
              const SizedBox(width: 12),
              Text('${match.scoreB}',
                  style: AppText.condensed(
                      size: 60, weight: FontWeight.w800, height: 0.8)),
            ],
          ),
          Expanded(child: _teamBlock('B', match.teamBName)),
        ],
      ),
    );
  }

  Widget _teamBlock(String badge, String name) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(16)),
          alignment: Alignment.center,
          child: Text(badge,
              style: AppText.condensed(
                  size: 22, weight: FontWeight.w800, color: AppColors.txt)),
        ),
        const SizedBox(height: 8),
        Text(name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                AppText.condensed(size: 14, weight: FontWeight.w700, height: 1)),
      ],
    );
  }

  // ---- Mid-game join approvals -----------------------------------------

  Widget _pendingBanner(MatchModel match) {
    return StreamBuilder<List<PendingPlayer>>(
      stream: MatchRepository.instance.watchPending(match.id),
      builder: (ctx, snap) {
        final waiting =
            (snap.data ?? const <PendingPlayer>[]).where((p) => p.midGame).toList();
        if (waiting.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(18, 2, 18, 6),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          decoration: BoxDecoration(
              border: Border.all(color: AppColors.line2),
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${tr('live.waitingToJoin').toUpperCase()} (${waiting.length})',
                  style: AppText.label(color: AppColors.txt)),
              const SizedBox(height: 6),
              for (final p in waiting)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      InitialsAvatar(initials: p.initials, size: 30, fontSize: 12),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                style: AppText.barlow(
                                    size: 14, weight: FontWeight.w700)),
                            Text('${match.teamName(p.team)}${p.isGuest ? ' · ${tr('live.guest')}' : ''}',
                                style: AppText.barlow(
                                    size: 11, color: AppColors.dim2)),
                          ],
                        ),
                      ),
                      _miniBtn(tr('live.approve').toUpperCase(), () async {
                        await MatchRepository.instance
                            .approvePending(match.id, p);
                        if (mounted) {
                          showYnoToast(context, '${p.name} ${tr('live.added')}');
                        }
                      }),
                      const SizedBox(width: 6),
                      _miniBtn(tr('live.decline').toUpperCase(), () async {
                        await MatchRepository.instance
                            .declinePending(match.id, p.uid);
                      }),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(100)),
        child: Text(label,
            style: AppText.barlow(
                size: 11, weight: FontWeight.w800, letterSpacing: 0.5)),
      ),
    );
  }

  // ---- Merged event feed (goals + cards + subs) -------------------------

  Widget _feed(MatchModel match) {
    return StreamBuilder<List<GoalEvent>>(
      stream: MatchRepository.instance.watchGoals(match.id),
      builder: (context, gSnap) {
        final items = [
          for (final g in gSnap.data ?? const <GoalEvent>[]) _FeedItem.goal(g),
        ];
        // Newest first; events still awaiting a server timestamp sort to the
        // top (treated as "now").
        items.sort((a, b) => b.sortKey.compareTo(a.sortKey));
        if (items.isEmpty) {
          return Center(
            child: Text(tr('live.noEvents'),
                style: AppText.barlow(size: 14, color: AppColors.dim2)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          itemCount: items.length,
          itemBuilder: (_, i) => _eventRow(match, items[i]),
        );
      },
    );
  }

  Widget _eventRow(MatchModel match, _FeedItem e) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line))),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(e.minute > 0 ? "${e.minute}'" : '·',
                style: AppText.condensed(
                    size: 15, weight: FontWeight.w700, color: AppColors.dim)),
          ),
          const SizedBox(width: 10),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(e.icon, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title,
                    style: AppText.barlow(size: 15, weight: FontWeight.w700)),
                Text(e.subtitle(match),
                    style: AppText.barlow(size: 12, color: AppColors.dim2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Action area (creator only) --------------------------------------

  Widget _actionArea(MatchModel match, List<MatchPlayer> players) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_atHalfTime(match))
            _halfTimeBanner(match)
          // A paused match can't be scored into — resume first. This is also
          // the only place the host can restart from, so it's spelled out.
          else if (match.paused)
            _pausedPanel(match)
          else ...[
            Row(
              children: [
                Expanded(
                  child: _goalButton(match, players, TeamSide.a),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _goalButton(match, players, TeamSide.b),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _secondary('⏸', tr('live.pauseMatch').toUpperCase(),
                () => MatchRepository.instance.pauseMatch(match.id)),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _ending ? null : () => _endMatch(match),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.line2, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                  (_ending ? tr('live.ending') : tr('live.endMatch'))
                      .toUpperCase(),
                  style: AppText.condensed(
                      size: 18,
                      weight: FontWeight.w800,
                      color: AppColors.txt,
                      letterSpacing: 0.7)),
            ),
          ),
        ],
      ),
    );
  }

  /// Host's panel while the clock is stopped: resume, or restart from 0:00.
  Widget _pausedPanel(MatchModel match) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.06),
          border: Border.all(color: AppColors.gold),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(tr('live.matchPaused').toUpperCase(),
              style: AppText.condensed(size: 20, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(tr('live.pausedBody'),
              textAlign: TextAlign.center,
              style: AppText.barlow(size: 13, color: AppColors.dim)),
          const SizedBox(height: 12),
          PrimaryButton(
            label: tr('live.resumeMatch'),
            height: 50,
            fontSize: 18,
            onTap: () => MatchRepository.instance.resumeMatch(match.id),
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: tr('live.restartMatch'),
            height: 46,
            fontSize: 16,
            danger: true, // wipes the scoreline back to 0–0
            onTap: () => _restartMatch(match),
          ),
        ],
      ),
    );
  }

  /// Shown to everyone else while the host has the clock stopped.
  Widget _pausedNote() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.06),
          border: Border.all(color: AppColors.gold),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(tr('live.matchPaused').toUpperCase(),
              style: AppText.condensed(size: 18, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(tr('live.pausedWaitingHost'),
              textAlign: TextAlign.center,
              style: AppText.barlow(size: 13, color: AppColors.dim)),
        ],
      ),
    );
  }

  /// Wipe the score + events and kick off again from 0:00, same players.
  /// Shared by the paused panel and the settings sheet.
  Future<void> _restartMatch(MatchModel match) async {
    final ok = await _confirm(
      title: tr('live.restartMatchQ'),
      message: tr('live.restartMsg'),
      confirmLabel: tr('live.restart'),
      danger: true, // wipes the live scoreline
    );
    if (!ok) return;
    _halfPauseSent = false;
    await MatchRepository.instance.restartMatch(match.id);
    if (mounted) showYnoToast(context, tr('live.matchRestarted'));
  }

  /// Shown to captains during half-time — they can't resume, only the creator.
  Widget _halfTimeWaiting() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          border: Border.all(color: AppColors.line2),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(tr('live.firstHalfComplete').toUpperCase(),
              style: AppText.condensed(size: 20, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(tr('live.halfWaitingHost'),
              textAlign: TextAlign.center,
              style: AppText.barlow(size: 13, color: AppColors.dim)),
        ],
      ),
    );
  }

  Widget _halfTimeBanner(MatchModel match) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          border: Border.all(color: AppColors.line2),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(tr('live.firstHalfComplete').toUpperCase(),
              style: AppText.condensed(size: 20, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(tr('live.halfLocked'),
              textAlign: TextAlign.center,
              style: AppText.barlow(size: 13, color: AppColors.dim)),
          const SizedBox(height: 12),
          PrimaryButton(
            label: tr('live.startSecondHalf'),
            height: 50,
            fontSize: 18,
            onTap: () => MatchRepository.instance.startSecondHalf(match.id),
          ),
        ],
      ),
    );
  }

  Widget _goalButton(MatchModel match, List<MatchPlayer> players, TeamSide side) {
    return GestureDetector(
      onTap: () => _goalSheet(match, players, side),
      child: Container(
        height: 74,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚽', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 2),
            Text('${match.teamName(side)} ${tr('live.goal')}'.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.condensed(
                    size: 14, weight: FontWeight.w800, color: AppColors.txt)),
          ],
        ),
      ),
    );
  }

  Widget _secondary(String icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text(label,
                style: AppText.condensed(
                    size: 13, weight: FontWeight.w800, color: AppColors.txt)),
          ],
        ),
      ),
    );
  }

  Widget _viewerNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      child: Text(tr('live.viewerNote'),
          textAlign: TextAlign.center,
          style: AppText.barlow(size: 13, color: AppColors.dim)),
    );
  }

  // ---- Goal flow --------------------------------------------------------

  Future<void> _goalSheet(
      MatchModel match, List<MatchPlayer> players, TeamSide side) {
    final teamPlayers = players.where((p) => p.team == side).toList();
    return _sheet(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${tr('live.whoScored').toUpperCase()} ⚽',
              style: AppText.condensed(size: 24, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${match.teamName(side)} — ${tr('live.tapScorer')}',
              style: AppText.barlow(size: 13, color: AppColors.dim)),
          const SizedBox(height: 16),
          if (teamPlayers.isEmpty)
            Text(tr('live.noPlayersTeam'),
                style: AppText.barlow(size: 14, color: AppColors.dim2)),
          for (final p in teamPlayers)
            _playerTile(
              p,
              match,
              onTap: () async {
                Navigator.pop(context);
                final minute = _elapsedMinutes(match);
                final mates = teamPlayers
                    .where((pl) => pl.uid != p.uid)
                    .toList();
                await _assistSheet(match, p, mates, minute);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _assistSheet(
    MatchModel match,
    MatchPlayer scorer,
    List<MatchPlayer> mates,
    int minute,
  ) {
    Future<void> record(MatchPlayer? assist) async {
      Navigator.pop(context);
      await MatchRepository.instance.recordGoal(
        matchId: match.id,
        scorer: scorer,
        minute: minute,
        assist: assist,
      );
      if (mounted) {
        showYnoToast(context, '${tr('live.goal')} · ${scorer.name}');
      }
    }

    return _sheet(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${tr('live.whoAssisted').toUpperCase()} 🅰️',
              style: AppText.condensed(size: 24, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${scorer.name} ${tr('live.scoredCredit')}',
              style: AppText.barlow(size: 13, color: AppColors.dim)),
          const SizedBox(height: 16),
          for (final p in mates)
            _playerTile(p, match, onTap: () => record(p)),
          _plainTile('—', tr('live.noAssist'), onTap: () => record(null)),
        ],
      ),
    );
  }

  // ---- Card flow --------------------------------------------------------

  // ---- Shared player pickers -------------------------------------------

  Widget _playerTile(MatchPlayer p, MatchModel match, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            InitialsAvatar(initials: p.initials, size: 34, fontSize: 13),
            const SizedBox(width: 12),
            Expanded(
              child: Text(p.name,
                  style: AppText.barlow(size: 16, weight: FontWeight.w700)),
            ),
            Text(match.teamName(p.team).toUpperCase(),
                style: AppText.barlow(
                    size: 11, weight: FontWeight.w800, color: AppColors.dim)),
          ],
        ),
      ),
    );
  }

  Widget _plainTile(String glyph, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(glyph, style: const TextStyle(fontSize: 15)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: AppText.barlow(size: 16, weight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ---- End match --------------------------------------------------------

  Future<void> _endMatch(MatchModel match) async {
    if (_ending) return;
    final ok = await _confirm(
      title: tr('live.endMatchQ'),
      message: match.timingMode != TimingMode.none && !_clockExpired(match)
          ? tr('live.endTimeLeft')
          : tr('live.endConfirm'),
      confirmLabel: tr('live.endMatch'),
    );
    if (!ok || !mounted) return;
    setState(() => _ending = true);
    await MatchRepository.instance.endMatch(match.id);
    if (!mounted) return;
    // Level score → outcome picker; otherwise straight to post-match.
    final next = match.isLevel ? Routes.outcome : Routes.postMatch;
    Navigator.pushReplacementNamed(context, next, arguments: match.id);
  }

  // ---- Settings sheet: restart / quit / (extend) -----------------------

  Future<void> _settingsSheet(MatchModel match) {
    return _sheet(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('live.matchSettings').toUpperCase(),
              style: AppText.condensed(size: 24, weight: FontWeight.w800)),
          const SizedBox(height: 14),
          if (match.timingMode != TimingMode.none) ...[
            Text(tr('live.extendClock').toUpperCase(), style: AppText.label()),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final m in [5, 10]) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        MatchRepository.instance.extendMatch(match.id, m);
                        Navigator.pop(context);
                        showYnoToast(context, '+$m ${tr('live.minAdded')}');
                      },
                      child: Container(
                        height: 48,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                            border: Border.all(color: AppColors.line),
                            borderRadius: BorderRadius.circular(16)),
                        alignment: Alignment.center,
                        child: Text('+$m ${tr('live.min')}',
                            style: AppText.condensed(
                                size: 16, weight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
          ],
          _settingsRow(tr('live.restartMatch'), tr('live.restartSub'), () {
            Navigator.pop(context);
            _restartMatch(match);
          }),
          const SizedBox(height: 10),
          _settingsRow(tr('live.quitMatch'), tr('live.quitSub'), () {
            Navigator.pop(context);
            _quitSheet(match);
          }),
        ],
      ),
    );
  }

  Widget _settingsRow(String title, String sub, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: AppText.condensed(size: 17, weight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(sub, style: AppText.barlow(size: 12, color: AppColors.dim)),
          ],
        ),
      ),
    );
  }

  Future<void> _quitSheet(MatchModel match) {
    return _sheet(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('live.quitMatch').toUpperCase(),
              style: AppText.condensed(size: 24, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(tr('live.quitBody'),
              style: AppText.barlow(size: 13, color: AppColors.dim)),
          const SizedBox(height: 16),
          _settingsRow(tr('live.saveAbandoned'), tr('live.saveAbandonedSub'),
              () async {
            Navigator.pop(context);
            final ok = await _confirm(
              title: tr('live.saveAbandonedQ'),
              message: tr('live.saveAbandonedMsg'),
              confirmLabel: tr('common.save'),
            );
            if (!ok || !mounted) return;
            await MatchRepository.instance.quitAbandon(match.id);
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, Routes.postMatch,
                arguments: match.id);
          }),
          const SizedBox(height: 10),
          _settingsRow(tr('live.discardEverything'), tr('live.discardSub'),
              () async {
            Navigator.pop(context);
            final ok = await _confirm(
              title: tr('live.discardMatchQ'),
              message: tr('live.discardMsg'),
              confirmLabel: tr('live.discard'),
              danger: true, // throws the whole match away
            );
            if (!ok || !mounted) return;
            await MatchRepository.instance.quitDiscard(match.id);
            if (!mounted) return;
            Navigator.pushNamedAndRemoveUntil(
                context, Routes.home, (r) => false);
          }),
        ],
      ),
    );
  }

  // ---- Utilities --------------------------------------------------------

  /// Delegates to the shared [showConfirm]. Pass [danger] only for actions
  /// that LOSE data (discard, restart) — ending a match at full time or
  /// saving it as abandoned preserve it and stay green.
  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) =>
      showConfirm(context,
          title: title.toUpperCase(),
          message: message,
          confirmLabel: confirmLabel,
          danger: danger);

  Future<void> _sheet(Widget child) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: AppColors.line2),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.78),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A unified feed entry so goals, cards and subs render and sort together.
class _FeedItem {
  _FeedItem({
    required this.icon,
    required this.title,
    required this.minute,
    required this.at,
    required String Function(MatchModel) subtitleBuilder,
  }) : _subtitle = subtitleBuilder;

  final String icon;
  final String title;
  final int minute;
  final DateTime? at;
  final String Function(MatchModel) _subtitle;

  /// Null timestamps (writes still pending on the server) sort newest.
  DateTime get sortKey => at ?? DateTime.now();

  String subtitle(MatchModel m) => _subtitle(m);

  factory _FeedItem.goal(GoalEvent g) => _FeedItem(
        icon: '⚽',
        title: g.scorerName,
        minute: g.minute,
        at: g.at,
        subtitleBuilder: (m) => g.assistName != null
            ? '${tr('live.goal')} · ${m.teamName(g.team)} · ${tr('live.assist')} ${g.assistName}'
            : '${tr('live.goal')} · ${m.teamName(g.team)}',
      );

}
