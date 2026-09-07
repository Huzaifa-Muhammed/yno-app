import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/match_repository.dart';
import '../services/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/confirm.dart';
import '../widgets/motion.dart';
import '../widgets/yno_scaffold.dart';

/// Section 6 — Match Outcome (level score).
///
/// Reached from the live screen when End Match is tapped and the score is
/// tied. The admin chooses how the level game was decided; the choice is
/// written via [MatchRepository.setOutcome] and the flow moves to post-match.
/// [endMatch] has already been called upstream.
class MatchOutcomeScreen extends StatefulWidget {
  const MatchOutcomeScreen({super.key});

  @override
  State<MatchOutcomeScreen> createState() => _MatchOutcomeScreenState();
}

class _MatchOutcomeScreenState extends State<MatchOutcomeScreen> {
  bool _busy = false;

  String get _matchId => ModalRoute.of(context)!.settings.arguments as String;

  /// Which set of options to show. Extra time is a *played* period now, so the
  /// step is a fact about the match (`extraTimeMin > 0`), not a local flag — the
  /// host leaves this screen for the live one and comes back to it when extra
  /// time runs out, and a `bool` field would have reset to step 1 on the way
  /// back and offered extra time a second time as though none had been played.
  bool _afterExtraTime(MatchModel m) => m.inExtraTime;

  /// Send the match back out for [minutes] more, then follow everyone to the
  /// live screen. `pushReplacement` so the finished outcome screen isn't left
  /// under the live one for the back gesture to surface.
  Future<void> _goToExtraTime(int minutes) async {
    if (_busy) return;
    setState(() => _busy = true);
    final id = _matchId;
    await MatchRepository.instance.startExtraTime(id, minutes);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, Routes.live, arguments: id);
  }

  /// Send the match back out for extra time.
  ///
  /// On a match with **no clock** — which is every match created since
  /// 2026-09-07, when the timing picker was removed — this asks nothing and
  /// just restarts play. The host is running a stopwatch and ends the match by
  /// hand, so making them commit to "10 minutes" here would put back exactly
  /// the pre-set length that was taken out.
  ///
  /// Older, timed matches still get the length picker: they have a real clock,
  /// and extra time on a clock needs to know when it stops.
  Future<void> _startExtraTime(MatchModel match) async {
    if (match.timingMode == TimingMode.none) {
      await _goToExtraTime(0); // 0 = open-ended, see startExtraTime
      return;
    }
    await _extraTimeSheet();
  }

  /// How long extra time runs, for a match that has a clock. Football's own
  /// answer is 2×15, but this app is used for five-a-side on a booked pitch as
  /// much as for full games, so the host picks.
  Future<void> _extraTimeSheet() async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.line2),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('live.extraTimeHowLong').toUpperCase(),
                style: AppText.condensed(size: 24, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(tr('live.extraTimeHowLongSub'),
                style: AppText.barlow(
                    size: 13, color: AppColors.dim, height: 1.4)),
            const SizedBox(height: 20),
            for (final m in const [5, 10, 15, 30]) ...[
              _option('+$m ${tr('live.min')}', null,
                  () => Navigator.pop(sheetCtx, m)),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
    if (minutes != null && mounted) await _goToExtraTime(minutes);
  }

  Future<void> _finish({
    required String method,
    TeamSide? winnerSide,
    int? penaltyA,
    int? penaltyB,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    final id = _matchId;
    await MatchRepository.instance.setOutcome(
      id,
      method: method,
      winnerSide: winnerSide,
      penaltyA: penaltyA,
      penaltyB: penaltyB,
    );
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, Routes.postMatch, arguments: id);
  }

  /// Penalty shootout — tap the players who converted, for both teams.
  ///
  /// The score *is* the tally of picks, so the two can never contradict each
  /// other. This replaced a pair of +/− steppers that recorded only the numbers
  /// (2026-09-07): the scorecard could say 4–3 without naming a single taker,
  /// and the kicks reached nobody's stats.
  ///
  /// Tapping a player again adds another kick — sudden death comes back round
  /// the order, so the same player really can score twice. `−` takes one back.
  ///
  /// A shootout cannot be drawn, so Confirm stays disabled while the two tallies
  /// are equal; that is what makes deriving the winner from the score safe
  /// rather than a guess. No assists: nobody assists a penalty.
  Future<void> _shootoutSheet(MatchModel match, List<MatchPlayer> players) async {
    // uid -> kicks converted, per side. Keyed by uid so a repeat tap is an
    // increment rather than a duplicate row.
    final counts = <String, int>{};
    int tally(TeamSide side) => players
        .where((p) => p.team == side)
        .fold(0, (sum, p) => sum + (counts[p.uid] ?? 0));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.line2),
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          final a = tally(TeamSide.a);
          final b = tally(TeamSide.b);
          final level = a == b;
          final none = a == 0 && b == 0;
          return Padding(
            padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 18,
                // The list is tall and the sheet is scrollable; keep the
                // Confirm button clear of the gesture bar.
                bottom: 26 + MediaQuery.of(sheetCtx).viewInsets.bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetCtx).size.height * 0.82),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('live.shootoutTitle').toUpperCase(),
                      style:
                          AppText.condensed(size: 24, weight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(tr('live.shootoutPickHint'),
                      style: AppText.barlow(
                          size: 13, color: AppColors.dim, height: 1.4)),
                  const SizedBox(height: 16),
                  // Running score, so the host can see the shootout stand
                  // without counting the rows themselves.
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line)),
                    child: Text('$a  :  $b',
                        textAlign: TextAlign.center,
                        style: AppText.condensed(
                            size: 34, weight: FontWeight.w800, height: 1)),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final side in TeamSide.values) ...[
                          _sectionLabel(
                              (side == TeamSide.a
                                      ? match.teamAName
                                      : match.teamBName)
                                  .toUpperCase()),
                          const SizedBox(height: 8),
                          ...() {
                            final squad = players
                                .where((p) => p.team == side)
                                .toList();
                            if (squad.isEmpty) {
                              return [
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 14),
                                  child: Text(tr('live.shootoutNoSquad'),
                                      style: AppText.barlow(
                                          size: 12,
                                          color: AppColors.dim2)),
                                ),
                              ];
                            }
                            return squad
                                .map((p) => _kickerRow(
                                      p,
                                      counts[p.uid] ?? 0,
                                      (v) => setSheet(() => counts[p.uid] = v),
                                    ))
                                .toList();
                          }(),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (level)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                          none
                              ? tr('live.shootoutPickSome')
                              : tr('live.shootoutNoDraw'),
                          textAlign: TextAlign.center,
                          style:
                              AppText.barlow(size: 12, color: AppColors.gold)),
                    ),
                  PrimaryButton(
                    label: tr('common.confirm'),
                    height: 52,
                    onTap: level
                        ? null
                        : () {
                            Navigator.pop(sheetCtx);
                            _finishShootout(players, counts);
                          },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Expand the per-player tallies back into one entry per converted kick, in
  /// squad order, and hand them to the repository.
  Future<void> _finishShootout(
      List<MatchPlayer> players, Map<String, int> counts) async {
    if (_busy) return;
    setState(() => _busy = true);
    List<MatchPlayer> takers(TeamSide side) => [
          for (final p in players.where((p) => p.team == side))
            for (var i = 0; i < (counts[p.uid] ?? 0); i++) p,
        ];
    final id = _matchId;
    await MatchRepository.instance.recordShootout(
      id,
      scorersA: takers(TeamSide.a),
      scorersB: takers(TeamSide.b),
    );
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, Routes.postMatch, arguments: id);
  }

  /// One player in the shootout sheet: name, kicks converted, +/−.
  Widget _kickerRow(MatchPlayer p, int value, ValueChanged<int> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
          color: value > 0 ? AppColors.primaryGlow(0.08) : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: value > 0 ? AppColors.primary : AppColors.line)),
      child: Row(
        children: [
          Expanded(
            child: Text(p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.condensed(size: 17, weight: FontWeight.w800)),
          ),
          _stepBtn('−', value == 0 ? null : () => onChanged(value - 1)),
          SizedBox(
            width: 40,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: AppText.condensed(size: 22, weight: FontWeight.w800)),
          ),
          _stepBtn('+', value >= 20 ? null : () => onChanged(value + 1)),
        ],
      ),
    );
  }

  Widget _stepBtn(String glyph, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line)),
          child: Text(glyph,
              style: AppText.condensed(
                  size: 22,
                  weight: FontWeight.w800,
                  color: onTap == null ? AppColors.dim2 : AppColors.txt)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final id = _matchId;
    return YnoScaffold(
      appBarTitle: tr('live.result'),
      showBackButton: false,
      child: SafeArea(
        top: false,
        child: StreamBuilder<MatchModel?>(
          stream: MatchRepository.instance.watchMatch(id),
          builder: (context, snap) {
            final match = snap.data;
            if (match == null) {
              return const Center(child: CircularProgressIndicator());
            }
            // The line-up is needed only by the shootout sheet, but it is
            // streamed here so the sheet opens with the squads already loaded
            // rather than showing an empty list for a frame.
            return StreamBuilder<List<MatchPlayer>>(
              stream: MatchRepository.instance.watchPlayers(id),
              builder: (context, playersSnap) {
                final players = playersSnap.data ?? const <MatchPlayer>[];
                return _body(match, players);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _body(MatchModel match, List<MatchPlayer> players) {
    final afterEt = _afterExtraTime(match);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
      child: FadeSlideIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                  // After extra time the header must not still say FULL TIME —
                  // the score below it now includes the added period.
                  afterEt
                      ? '${tr('live.afterExtraTime').toUpperCase()} · ${tr('live.level').toUpperCase()}'
                      : '${tr('live.fullTime').toUpperCase()} · ${tr('live.level').toUpperCase()}',
                  textAlign: TextAlign.center,
                  style: AppText.condensed(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppColors.dim,
                      letterSpacing: 2.2)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _badge('A'),
                const SizedBox(width: 16),
                Text('${match.scoreA} : ${match.scoreB}',
                    style: AppText.condensed(
                        size: 52, weight: FontWeight.w800, height: 1)),
                const SizedBox(width: 16),
                _badge('B'),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Text('${match.teamAName}  vs  ${match.teamBName}',
                  textAlign: TextAlign.center,
                  style: AppText.barlow(size: 14, color: AppColors.dim)),
            ),
            // How much extra time has already been played, so the host is not
            // offered a second period without being told about the first.
            if (afterEt) ...[
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                      color: AppColors.primaryGlow(0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.primary)),
                  child: Text(
                      '${tr('live.extraTimeOpt').toUpperCase()} · +${match.extraTimeMin} ${tr('live.min')}',
                      style: AppText.barlow(
                          size: 11,
                          weight: FontWeight.w800,
                          letterSpacing: 0.8)),
                ),
              ),
            ],
            const SizedBox(height: 28),
            Center(
              child: Text(
                  afterEt
                      ? tr('live.howEnded').toUpperCase()
                      : tr('live.scoresLevel').toUpperCase(),
                  textAlign: TextAlign.center,
                  style:
                      AppText.condensed(size: 26, weight: FontWeight.w800)),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                  afterEt
                      ? tr('live.extraTimePlayed')
                      : tr('live.chooseFinish'),
                  textAlign: TextAlign.center,
                  style: AppText.barlow(
                      size: 14, color: AppColors.dim, height: 1.4)),
            ),
            const SizedBox(height: 24),
            if (!afterEt)
              ..._initialOptions(match, players)
            else
              ..._extraTimeOptions(match, players),
          ],
        ),
      ),
    );
  }

  List<Widget> _initialOptions(MatchModel match, List<MatchPlayer> players) => [
        // Draw is final and irreversible for everyone in the match, so it is
        // confirmed. It is NOT danger-red: settling a level game as a draw
        // loses no data (see the rule in widgets/buttons.dart).
        _option(tr('live.endsDraw'), tr('live.endsDrawSub'), () async {
          final ok = await showConfirm(
            context,
            title: tr('live.endsDrawQ'),
            message: tr('live.endsDrawConfirm'),
            confirmLabel: tr('live.endsDraw'),
          );
          if (ok) _finish(method: 'draw');
        }),
        const SizedBox(height: 12),
        // Extra time now *restarts the match* rather than recording that it
        // happened offline, so there is nothing to confirm — picking a length
        // in the sheet is the confirmation, and the host can still end the
        // match again the moment it kicks off.
        _option(tr('live.extraTimeOpt'), tr('live.extraTimeOptSub'),
            () => _startExtraTime(match)),
        const SizedBox(height: 12),
        // Shootouts are a top-level way to settle a level game — you do not
        // have to play extra time first.
        _option(tr('live.shootoutOpt'), tr('live.shootoutOptSub'),
            () => _shootoutSheet(match, players)),
      ];

  List<Widget> _extraTimeOptions(MatchModel match, List<MatchPlayer> players) => [
        _option(tr('live.stillDraw'), tr('live.stillDrawSub'),
            () => _finish(method: 'draw')),
        const SizedBox(height: 12),
        _sectionLabel(tr('live.penalties').toUpperCase()),
        const SizedBox(height: 8),
        // One entry point for shootouts, here and at the top level, so the
        // scorers are always captured rather than only the winner.
        _option(tr('live.shootoutOpt'), tr('live.shootoutOptSub'),
            () => _shootoutSheet(match, players)),
        const SizedBox(height: 16),
        _sectionLabel(tr('live.goldenGoal').toUpperCase()),
        const SizedBox(height: 8),
        _option('${match.teamAName} ${tr('live.winOnGolden')}', null,
            () => _finish(method: 'goldenGoal', winnerSide: TeamSide.a)),
        const SizedBox(height: 10),
        _option('${match.teamBName} ${tr('live.winOnGolden')}', null,
            () => _finish(method: 'goldenGoal', winnerSide: TeamSide.b)),
        const SizedBox(height: 20),
        // Another period, when the first one settled nothing. There is no
        // "back" here any more: extra time has been played, and the old back
        // button rewound only a local flag, which would now contradict the
        // match itself.
        _option(tr('live.moreExtraTime'), tr('live.moreExtraTimeSub'),
            () => _startExtraTime(match)),
      ];

  Widget _sectionLabel(String text) => Text(text,
      style: AppText.label(color: AppColors.txt));

  Widget _option(String title, String? sub, VoidCallback onTap) {
    return GestureDetector(
      onTap: _busy ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line, width: 1.2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: AppText.condensed(size: 18, weight: FontWeight.w800)),
            if (sub != null) ...[
              const SizedBox(height: 3),
              Text(sub, style: AppText.barlow(size: 12, color: AppColors.dim)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String b) => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line)),
        alignment: Alignment.center,
        child: Text(b,
            style: AppText.condensed(
                size: 20, weight: FontWeight.w800, color: AppColors.txt)),
      );
}
