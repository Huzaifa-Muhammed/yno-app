import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
import '../services/match_repository.dart';
import '../services/models.dart';
import '../services/notification_repository.dart';
import '../services/team_repository.dart';
import '../services/user_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/header.dart';
import '../widgets/inputs.dart';
import '../widgets/motion.dart';
import '../widgets/yno_scaffold.dart';

/// Side of a team tile's badge box in the side-A picker. Also the tile's width,
/// so the name underneath wraps against the badge rather than its neighbours.
const double _kTeamTile = 72;

/// The names a side carries when it is not linked to a saved team.
///
/// ⚠️ Deliberately NOT localised. These are **stored on the match** and read by
/// every participant, so a match created in Arabic would otherwise show a
/// different team name to an English player looking at the same lobby.
///
/// They were three literals each until 2026-08-21 — the controller's initial
/// value and two `isEmpty` fallbacks. The "Team A" tile in the picker has to
/// display exactly what will be saved, and a fourth copy is how that stops
/// being true.
const String _kDefaultTeamA = 'Team A';
const String _kDefaultTeamB = 'Team B';

class MatchCreateScreen extends StatefulWidget {
  const MatchCreateScreen({super.key});

  @override
  State<MatchCreateScreen> createState() => _MatchCreateScreenState();
}

class _MatchCreateScreenState extends State<MatchCreateScreen> {
  /// Every new match is created with no fixed side size.
  ///
  /// The picker that offered 4v4 / 5v5 / … / 11v11 was removed on 2026-09-07 at
  /// the client's request — hosts pick their own numbers on the pitch, and the
  /// chip row was a decision most of them skipped anyway.
  ///
  /// ⚠️ The stored value stays the string `'Unlimited'`, NOT `'Custom'` and not
  /// empty. Three things depend on that exact word: matches created before the
  /// rename read back unchanged, `_teamSize`'s `^(\d+)v` parse returns null for
  /// it (which is what stops the lobby drawing empty team slots), and
  /// `match.formatUnlimited` renders it as "Custom" wherever a format is shown.
  ///
  /// It is still a *field*, deliberately. `applyMatchStats` buckets goals by
  /// format for the profile breakdown, and existing matches carry real values
  /// like '7v7' that must keep displaying — only the picker went, not the data.
  static const _kDefaultFormat = 'Unlimited';
  String _format = _kDefaultFormat;

  final _name = TextEditingController();

  // ⚠️ `_join` and `_timing` have NO picker any more (both removed 2026-09-07),
  // but they are still state rather than constants, and that is load-bearing:
  // [_loadMatch] overwrites them from the match being edited, and [_saveEdits]
  // writes them back. Turning either into a `const` would silently rewrite an
  // older match's joining method or wipe its two-halves clock the moment its
  // creator opened this screen to change something unrelated.
  //
  // New matches therefore get the values below; edited ones keep their own.
  int _join = 0; // 0 separate, 1 open — new matches are always separate teams.
  TimingMode _timing = TimingMode.none; // New matches run on the stopwatch.
  bool _adminOnly = false;

  // Team names are no longer typed. Each side shows the name of whatever is
  // linked to it, falling back to the constant default, so these are plain
  // strings rather than controllers.
  //
  // WARNING: they are still loaded verbatim from an existing match in
  // [_loadMatch]. Matches created before the name fields were removed may carry
  // a hand-typed name, and re-deriving the name on save would rename them.
  String _teamAName = _kDefaultTeamA;
  String _teamBName = _kDefaultTeamB;

  /// What actually gets written. Guards the one case the UI can no longer
  /// produce but a loaded document still can: an empty stored name.
  String get _teamAFinal =>
      _teamAName.trim().isEmpty ? _kDefaultTeamA : _teamAName.trim();
  String get _teamBFinal =>
      _teamBName.trim().isEmpty ? _kDefaultTeamB : _teamBName.trim();

  /// A timed match runs at most 45 minutes — per half when playing halves.
  ///
  /// Only reached through [_loadMatch] now: the duration stepper went with the
  /// timing picker, and a new match has no clock to set. Kept for the same
  /// reason as `_timing` — so editing an older, timed match preserves its
  /// length instead of resetting it.
  static const _maxDurationMin = 45;
  int _durationMin = _maxDurationMin;
  bool _busy = false;

  /// Set when this screen was opened from the lobby to **edit** an existing,
  /// not-yet-started match. The lobby is page 2 of creation, so the creator can
  /// step back here to fix a setting; the screen itself is the same one.
  String? _editId;
  bool _argsRead = false;
  bool _loading = false;
  bool get _editing => _editId != null;
  // Non-essential settings (surface, timing, visibility, …) live in a
  // collapsed "More options" panel — a match can be created without them.
  bool _showMore = false;
  AppUser? _me;

  // Optional links to saved teams (null = plain free-text name).
  String? _teamAId;
  String? _teamBId;
  List<TeamModel> _savedTeams = const [];
  StreamSubscription<List<TeamModel>>? _teamsSub;

  // Side B may instead be an opponent team fetched by its invite code. When
  // set, its captain is notified once the match exists.
  final _challengeCode = TextEditingController();
  TeamModel? _challenged;
  bool _challengeBusy = false;

  @override
  void initState() {
    super.initState();
    final uid = AuthRepository.instance.uid;
    if (uid != null) {
      UserRepository.instance.getUser(uid).then((u) {
        if (mounted) setState(() => _me = u);
      });
      // A live subscription, not the `.first` this used to be. The grid is the
      // only place side A can be linked, and a one-shot read at initState goes
      // stale the moment a team is created, renamed or left in another tab —
      // leaving a picker showing teams that no longer match reality.
      _teamsSub = TeamRepository.instance.watchUserTeams(uid).listen((list) {
        if (mounted) setState(() => _savedTeams = list);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    // A matchId argument means "edit this one"; no argument means "create".
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String && arg.isNotEmpty) {
      _editId = arg;
      _loadMatch(arg);
    }
  }

  /// Prefill every field from the match being edited.
  Future<void> _loadMatch(String id) async {
    setState(() => _loading = true);
    final m = await MatchRepository.instance.getMatch(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (m == null) return;
      _name.text = m.name;
      _teamAName = m.teamAName;
      _teamBName = m.teamBName;
      _format = m.format;
      _join = m.joiningMethod == JoiningMethod.separateTeams ? 0 : 1;
      _timing = m.timingMode;
      // Older matches were created with 60/90 — clamp into the current range.
      _durationMin = m.durationMin.clamp(1, _maxDurationMin);
      _adminOnly = m.adminOnlyMode;
      _teamAId = m.teamAId;
      _teamBId = m.teamBId;
      // They came back for a specific setting, so don't make them hunt for it.
      _showMore = true;
    });
  }

  /// Toggle one of your saved teams onto **side A** (the only side they're
  /// offered on): selecting locks the side to that team's name; tapping the
  /// already-selected team unlinks it back to free-text.
  void _pickTeam(TeamModel team) {
    if (_teamAId == team.id) {
      _unlinkTeam(TeamSide.a);
      return;
    }
    setState(() {
      _teamAId = team.id;
      _teamAName = team.name;
      // The opponent can't also be this team — drop a stale challenge to it.
      if (_challenged?.id == team.id) {
        _challenged = null;
        _teamBId = null;
      }
    });
  }

  /// Drop the link to a saved/challenged team and return the side to its
  /// default name.
  ///
  /// This used to leave the old name in place as an editable starting point.
  /// With the name fields gone there is nothing left to edit, so a side reading
  /// "Falcons" with no team linked would show a name the user could neither
  /// explain nor change. Restoring the default is now the only coherent result,
  /// which is also why the separate [_useDefaultTeam] this screen briefly had
  /// has been folded in here.
  void _unlinkTeam(TeamSide side) {
    setState(() {
      if (side == TeamSide.a) {
        _teamAId = null;
        _teamAName = _kDefaultTeamA;
      } else {
        _teamBId = null;
        _teamBName = _kDefaultTeamB;
        _challenged = null;
      }
    });
  }

  /// Look up a friend's team by its invite code and set it as the opponent.
  Future<void> _fetchChallenge() async {
    if (_challengeBusy) return;
    final code = _challengeCode.text.trim();
    if (code.isEmpty) return;
    setState(() => _challengeBusy = true);
    try {
      final team = await TeamRepository.instance.findByInviteCode(code);
      if (!mounted) return;
      if (team == null || team.disbanded) {
        showYnoToast(context, tr('match.teamCodeNotFound'));
        return;
      }
      final uid = AuthRepository.instance.uid;
      if (uid != null && team.memberUids.contains(uid)) {
        showYnoToast(context, tr('match.cannotChallengeOwnTeam'));
        return;
      }
      if (_teamAId == team.id) {
        showYnoToast(context, tr('match.teamAlreadyOnSideA'));
        return;
      }
      setState(() {
        _challenged = team;
        _teamBId = team.id;
        _teamBName = team.name;
        _challengeCode.clear();
      });
    } catch (_) {
      if (mounted) showYnoToast(context, tr('match.couldNotFetchTeam'));
    } finally {
      if (mounted) setState(() => _challengeBusy = false);
    }
  }

  @override
  void dispose() {
    _teamsSub?.cancel();
    _name.dispose();
    _challengeCode.dispose();
    super.dispose();
  }


  /// Save edits back to an existing match, then return to the lobby (which is
  /// streaming the doc, so it repaints on its own).
  Future<void> _saveEdits() async {
    if (_busy) return;
    final uid = AuthRepository.instance.uid;
    if (uid == null) {
      showYnoToast(context, tr('match.needLogin'));
      return;
    }
    setState(() => _busy = true);
    try {
      await MatchRepository.instance.updateMatchSettings(
        _editId!,
        adminUid: uid,
        name: _name.text.trim(),
        teamAName: _teamAFinal,
        teamBName: _teamBFinal,
        format: _format,
        joiningMethod:
            _join == 0 ? JoiningMethod.separateTeams : JoiningMethod.openLobby,
        timingMode: _timing,
        durationMin: _durationMin,
        adminOnlyMode: _adminOnly,
        adminName: _me?.name ?? 'Admin',
        adminPosition: _me?.position,
      );
      if (!mounted) return;
      showYnoToast(context, tr('match.matchUpdated'));
      Navigator.pop(context);
    } on StateError catch (e) {
      if (!mounted) return;
      showYnoToast(
          context,
          e.message == 'match-started'
              ? tr('match.startedNoEdit')
              : tr('match.couldNotSaveMatch'));
      setState(() => _busy = false);
    } catch (_) {
      if (!mounted) return;
      showYnoToast(context, tr('match.couldNotSaveMatch'));
      setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    if (_busy) return;
    final uid = AuthRepository.instance.uid;
    if (uid == null) {
      showYnoToast(context, tr('match.needLogin'));
      return;
    }
    setState(() => _busy = true);
    // Both the owner AND the captain of a challenged team may answer. The
    // captain is the primary (drives the accepter→captainB link); the owner
    // stands in when no distinct captain is assigned so a team is never
    // unreachable. Recipients (deduped) are who we notify + who may respond.
    final challenged = _challenged;
    final challengeCaptainUid = challenged == null
        ? null
        : (challenged.captainUid ?? challenged.ownerUid);
    final challengeRecipients = challenged == null
        ? <String>[]
        : <String>{
            challenged.ownerUid,
            if (challenged.captainUid != null) challenged.captainUid!,
          }.toList();
    try {
      final match = await MatchRepository.instance.createMatch(
        adminUid: uid,
        adminName: _me?.name ?? 'Admin',
        name: _name.text.trim(),
        teamAName: _teamAFinal,
        teamBName: _teamBFinal,
        format: _format,
        // Every match is private for now — you get in by invite or by code, so
        // there's nothing to choose. Surface, location and kick-off time are no
        // longer collected either (the repo leaves them empty/unset).
        isPublic: false,
        joiningMethod:
            _join == 0 ? JoiningMethod.separateTeams : JoiningMethod.openLobby,
        timingMode: _timing,
        durationMin: _durationMin,
        adminOnlyMode: _adminOnly,
        adminPosition: _me?.position,
        teamAId: _teamAId,
        teamBId: _teamBId,
        challengedTeamId: challenged?.id,
        challengedTeamName: challenged?.name,
        challengeCaptainUid: challengeCaptainUid,
        challengeRecipientUids: challengeRecipients,
      );
      // Tell everyone who can answer (owner + captain). Routed to home, where
      // the popup + banner carry the Accept/Decline; the first answer clears
      // the bell for the others. `emit` swallows its own errors, so this can't
      // strand the created match.
      if (challenged != null) {
        // Name the challenger only when side A is a real team. Unlinked, the
        // name is now always the constant "Team A" — which tells the recipient
        // nothing — so the generic wording is the more informative of the two.
        // The old empty-string test can no longer fire: there is no field left
        // to clear.
        final challenger = _teamAId == null ? tr('match.aPlayer') : _teamAFinal;
        final body = '$challenger '
            '${tr('match.challengeNotifBody')} "${challenged.name}".';
        for (final rid in challengeRecipients) {
          await NotificationRepository.instance.emit(
            rid,
            title: tr('match.challengeNotifTitle'),
            body: body,
            category: NotifCategory.matchInvite,
            route: Routes.home,
            arg: match.id,
          );
        }
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, Routes.lobby, arguments: match.id);
    } catch (_) {
      if (!mounted) return;
      showYnoToast(context, tr('match.couldNotCreateMatch'));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return YnoScaffold(
      appBarTitle: _editing
          ? tr('match.editMatchTitle')
          : tr('match.createMatchTitle'),
      // Full-width Create/Save button docked at the bottom, always reachable.
      bottomNav: Container(
        color: AppColors.bg,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: SafeArea(
          top: false,
          child: PrimaryButton(
            label: _busy
                ? (_editing ? tr('common.saving') : tr('match.creating'))
                : (_editing
                    ? tr('match.saveChanges')
                    : tr('match.createMatchTitle')),
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.ink))
                : Icon(_editing ? Icons.check_rounded : Icons.add_rounded,
                    color: AppColors.ink),
            onTap: _busy ? null : (_editing ? _saveEdits : _create),
          ),
        ),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeSlideIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FieldLabel(tr('match.matchName'), optional: true),
                    YnoTextField(
                      controller: _name,
                      hint: tr('match.matchNameHint'),
                      textCapitalization: TextCapitalization.words,
                      trailing: null,
                    ),
                    const SizedBox(height: 6),
                    Text(tr('match.upTo50'),
                        style: AppText.barlow(size: 12, color: AppColors.dim2)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ---- Team setup ------------------------------------------------
              FadeSlideIn(
                delay: const Duration(milliseconds: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionLabel(tr('match.teamSetup')),
                    const SizedBox(height: 11),
                    _teamSide(TeamSide.a),
                    const SizedBox(height: 14),
                    Center(
                        child: Text(tr('match.vs'),
                            style:
                                AppText.barlow(size: 14, color: AppColors.dim))),
                    const SizedBox(height: 14),
                    _teamSide(TeamSide.b),
                  ],
                ),
              ),

              // The FORMAT section stood here — a row of chips for Custom /
              // 4v4 / 5v5 / … / 11v11. Removed 2026-09-07 at the client's
              // request: every match is now Custom, i.e. no fixed side size.
              //
              // `_format` is still written to the match document (as
              // 'Unlimited') because it is a stored field that older matches
              // carry, several screens read, and `applyMatchStats` buckets
              // goals by. Dropping the *field* would orphan every existing
              // match's format and the profile's goals-by-format breakdown; it
              // is only the picker that went.
              const SizedBox(height: 24),
              _moreOptionsToggle(),
              if (_showMore) ...[
              // Two sections stood here and were removed on 2026-09-07 at the
              // client's request:
              //
              // * JOINING METHOD — separate team codes vs one open lobby.
              //   Every match is separate-teams now (`_join` is fixed at 0), so
              //   there was one option left and nothing to choose.
              // * TIMING — no timer / full match / two halves, plus the
              //   duration stepper. Matches are no longer given a length up
              //   front: the live screen runs a stopwatch and the host ends the
              //   match when they decide it is over.
              //
              // ⚠️ Both FIELDS survive on the match document and are still read
              // everywhere. Older matches carry real `timingMode`/`durationMin`
              // values and a genuine countdown-era `endsAt`, and the live
              // screen, the scoreboard and the website clock all still honour
              // them — a match created last month must not start behaving like
              // a stopwatch retroactively. It is only the pickers that went.
              const SizedBox(height: 24),
              FadeSlideIn(
                delay: const Duration(milliseconds: 320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionLabel(tr('match.adminMode')),
                    const SizedBox(height: 11),
                    // Two explicit choices — the old single row flipped its own
                    // label when tapped, so you couldn't see the alternative
                    // before picking it. Playing admin is the default.
                    SelectableRow(
                      title: tr('match.playingAdmin'),
                      subtitle: tr('match.playingAdminSub'),
                      selected: !_adminOnly,
                      onTap: () => setState(() => _adminOnly = false),
                    ),
                    const SizedBox(height: 10),
                    SelectableRow(
                      title: tr('match.adminOnly'),
                      subtitle: tr('match.adminOnlySub'),
                      selected: _adminOnly,
                      onTap: () => setState(() => _adminOnly = true),
                    ),
                    const SizedBox(height: 6),
                    Text(tr('match.adminModeHint'),
                        style: AppText.barlow(size: 12, color: AppColors.dim2)),
                  ],
                ),
              ),
              ],
              // Room so the floating Create button never covers the last field.
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
    );
  }

  // ---- More options (collapsible) ------------------------------------------

  /// Header that expands/collapses the non-essential settings. Collapsed by
  /// default so the screen shows only what a match needs (teams + format).
  Widget _moreOptionsToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showMore = !_showMore),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.tune, size: 18, color: AppColors.dim),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tr('match.moreOptions'),
                      style:
                          AppText.barlow(size: 15, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(tr('match.moreOptionsSub'),
                      style: AppText.barlow(size: 11, color: AppColors.dim2)),
                ],
              ),
            ),
            AnimatedRotation(
              turns: _showMore ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.keyboard_arrow_down,
                  color: AppColors.dim),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Team side (name + saved teams + new) --------------------------------

  Widget _teamSide(TeamSide side) {
    final name = side == TeamSide.a ? _teamAName : _teamBName;
    final selId = side == TeamSide.a ? _teamAId : _teamBId;
    // A linked team always plays under its own name.
    final linked = selId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line)),
              child: Text(side.id,
                  style: AppText.condensed(size: 15, weight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            // The name is shown, not typed. It is always either a linked
            // team's own name or the constant default, so there is nothing
            // here for a user to decide — and a free-text field invited them
            // to rename a side in a way that either got overwritten the
            // moment a team was linked, or diverged from the team it named.
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.condensed(
                    size: 18, weight: FontWeight.w800, height: 1.1),
              ),
            ),
            // Side A's explanation sits on the "Team A" tile in the grid
            // below, next to the choice it describes. Side B has no grid, so
            // its info affordance belongs here against the name.
            if (side == TeamSide.b)
              _InfoTip(message: tr('match.teamBInfo'), iconSize: 17),
          ],
        ),
        // Side A only. This line says "Edit it in My Teams", and side B's
        // linked team is a team you *challenged* — someone else's, not in your
        // My Teams and not yours to rename. It has been showing there on every
        // challenge; the challenge card below already explains that side.
        if (linked && side == TeamSide.a) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Text(tr('match.savedTeamNameLocked'),
                style: AppText.barlow(size: 11, color: AppColors.dim2)),
          ),
        ],
        // Editing an existing match shows names only: picking a different team
        // or firing a new challenge would have to move rosters and re-notify,
        // which belongs in the lobby, not here.
        if (_editing) ...[
          if (side == TeamSide.b) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 38),
              child: Text(tr('match.editTeamLinksLocked'),
                  style: AppText.barlow(size: 11, color: AppColors.dim2)),
            ),
          ],
        ]
        // Your saved teams are offered on side A only — listing them on both
        // sides let you field your own team against itself. There's no
        // "new team" shortcut: an unregistered opponent just gets a typed
        // name here, and you build their line-up in the lobby.
        else if (side == TeamSide.a) ...[
          const SizedBox(height: 10),
          // Your own teams were previously a bare row of unlabelled chips —
          // and nothing at all if you owned none, so there was no hint the
          // feature existed. Both states are now spelled out.
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: _ownTeamBlock(selId),
          ),
        ] else ...[
          const SizedBox(height: 12),
          _challengeBlock(),
        ],
      ],
    );
  }

  // ---- Challenge an opponent team by its invite code ------------------------

  Widget _challengeBlock() {
    final team = _challenged;
    if (team != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.primaryGlow(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: Row(
          children: [
            Text(team.presetBadge?.isNotEmpty == true ? team.presetBadge! : '🛡️',
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(team.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.condensed(
                          size: 18, weight: FontWeight.w800, height: 1.1)),
                  const SizedBox(height: 3),
                  Text(tr('match.challengeWillNotify'),
                      style: AppText.barlow(size: 11, color: AppColors.dim)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _unlinkTeam(TeamSide.b),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.close, size: 18, color: AppColors.dim),
              ),
            ),
          ],
        ),
      );
    }
    // Presented as an explicit alternative to typing a name: a bordered block
    // with a heading and a plain-English explanation of what a team code is
    // and what happens when you use one. It was a 12px dim label above a field
    // labelled only "code", which read as an optional extra rather than the
    // other way to pick an opponent.
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('⚡', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 7),
            Text(tr('match.challengeTeam'),
                style: AppText.barlow(
                    size: 13.5, weight: FontWeight.w700, color: AppColors.txt)),
          ],
        ),
        const SizedBox(height: 4),
        Text(tr('match.challengeExplain'),
            style: AppText.barlow(
                size: 11.5, color: AppColors.dim2, height: 1.35)),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: YnoTextField(
                controller: _challengeCode,
                hint: tr('match.challengeCodeHint'),
                height: 48,
                fontSize: 15,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _fetchChallenge(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _fetchChallenge,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: _challengeBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(tr('match.challengeFetch'),
                        style: AppText.barlow(
                            size: 13,
                            weight: FontWeight.w800,
                            color: AppColors.txt)),
              ),
            ),
          ],
        ),
      ],
      ),
    );
  }

  /// Side A's team picker: a grid of badge tiles, ending in a "+" tile.
  ///
  /// Picking a team here is what links the match to it — the roster is copied
  /// in, its captain takes the armband, and the result folds into the team's
  /// stats. That is why the one-line explanation stays: it was previously
  /// implied by an unlabelled chip and nobody could have guessed it.
  ///
  /// The "+" tile is always last, so a user with no teams sees a grid of one.
  /// That replaced a separate empty-state signpost row — two layouts for the
  /// same choice, and the one you saw depended on whether you happened to own a
  /// team.
  ///
  /// A `Wrap` of fixed-width tiles rather than a `GridView`: this sits inside a
  /// scrolling form, and a nested scrollable there needs `shrinkWrap` plus a
  /// disabled physics to behave — a Wrap reads as a grid and just works.
  Widget _ownTeamBlock(String? selId) {
    // Whatever is already the opponent is excluded, so the same team can never
    // end up on both sides.
    final mine = _savedTeams.where((t) => t.id != _teamBId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('match.useYourTeam'),
            style: AppText.barlow(
                size: 12, weight: FontWeight.w700, color: AppColors.dim)),
        const SizedBox(height: 3),
        Text(mine.isEmpty
                ? tr('match.noTeamsYetSub')
                : tr('match.useYourTeamSub'),
            style: AppText.barlow(
                size: 11.5, color: AppColors.dim2, height: 1.35)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final t in mine)
              _teamTile(
                selected: selId == t.id,
                label: t.name,
                onTap: () => _pickTeam(t),
                child: TeamBadge(
                  badgeUrl: t.badgeUrl,
                  presetBadge: t.presetBadge,
                  name: t.name,
                  size: _kTeamTile,
                  radius: 18,
                  border: selId == t.id ? AppColors.primary : AppColors.line,
                ),
              ),
            // The "no saved team" option, and the default. Selected whenever
            // nothing is linked, so the grid always shows exactly one choice
            // lit — previously the unlinked state lit nothing at all and there
            // was no way back to it except re-tapping the team you had picked.
            _teamTile(
              selected: _teamAId == null,
              label: _kDefaultTeamA,
              onTap: () => _unlinkTeam(TeamSide.a),
              child: Stack(
                children: [
                  Container(
                    width: _kTeamTile,
                    height: _kTeamTile,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: _teamAId == null
                              ? AppColors.primary
                              : AppColors.line),
                    ),
                    alignment: Alignment.center,
                    child: Text(TeamSide.a.id,
                        style: AppText.condensed(
                            size: _kTeamTile * 0.44, weight: FontWeight.w800)),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: _InfoTip(message: tr('match.defaultTeamInfo')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// One tile: a square badge box with the name underneath it.
  Widget _teamTile({
    required bool selected,
    required String label,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _kTeamTile,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              // Two lines then ellipsis: team names are user-typed and a long
              // one must not make its tile taller than its neighbours.
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.barlow(
                size: 11.5,
                height: 1.2,
                weight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.dim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// A tappable info icon that reveals [message] for a few seconds.
///
/// Both sides of the create screen now explain themselves this way, and the
/// mechanics below are subtle enough that a second hand-rolled copy would
/// drift from this one:
///
/// * **[TooltipTriggerMode.manual] plus an explicit `ensureTooltipVisible()`.**
///   A tap-triggered Tooltip and the surrounding tile's own tap both enter
///   the gesture arena, so asking for the explanation would also change the
///   selection underneath it.
/// * **Hidden by a [Timer], not by `Tooltip.showDuration`.** That property
///   only applies to the built-in tap/long-press triggers; under a manual
///   trigger the tooltip sits there until something else steals a tap.
class _InfoTip extends StatefulWidget {
  const _InfoTip({required this.message, this.iconSize = 14});

  final String message;
  final double iconSize;

  @override
  State<_InfoTip> createState() => _InfoTipState();
}

class _InfoTipState extends State<_InfoTip> {
  final _key = GlobalKey<TooltipState>();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _show() {
    _key.currentState?.ensureTooltipVisible();
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) Tooltip.dismissAllToolTips();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      key: _key,
      message: widget.message,
      triggerMode: TooltipTriggerMode.manual,
      preferBelow: false,
      textStyle:
          AppText.barlow(size: 11.5, color: AppColors.txt, height: 1.35),
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line2),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _show,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(Icons.info_outline,
              size: widget.iconSize, color: AppColors.dim),
        ),
      ),
    );
  }
}
