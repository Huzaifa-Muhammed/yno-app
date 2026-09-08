import 'package:cloud_firestore/cloud_firestore.dart';
import 'rewards_config.dart';

import 'auth_repository.dart';
import 'codes.dart';
import 'friend_repository.dart';
import 'models.dart';
import 'notification_repository.dart';
import 'team_repository.dart';
import 'user_repository.dart';


/// A DRAFT match (created but never started — still in the lobby) is
/// auto-deleted this long after creation.
const kDraftTtl = Duration(days: 2);

/// Everything about a match: creation, joining, live logging, voting, awards.
class MatchRepository {
  MatchRepository._();
  static final MatchRepository instance = MatchRepository._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _matches =>
      _db.collection('matches');
  CollectionReference<Map<String, dynamic>> get _guests =>
      _db.collection('guests');

  CollectionReference<Map<String, dynamic>> _players(String id) =>
      _matches.doc(id).collection('players');
  CollectionReference<Map<String, dynamic>> _pending(String id) =>
      _matches.doc(id).collection('pending');
  CollectionReference<Map<String, dynamic>> _goals(String id) =>
      _matches.doc(id).collection('goals');
  CollectionReference<Map<String, dynamic>> _penalties(String id) =>
      _matches.doc(id).collection('penalties');
  CollectionReference<Map<String, dynamic>> _votes(String id) =>
      _matches.doc(id).collection('votes');

  // ---- Creation ---------------------------------------------------------

  Future<MatchModel> createMatch({
    required String adminUid,
    required String adminName,
    required String teamAName,
    required String teamBName,
    String name = '',
    String format = '5v5',
    // Surface, location and kick-off time are no longer collected at creation
    // (they were removed from the create screen). Kept as optional params so
    // older matches still read back, and so they can return without a schema
    // change — an empty surface never lands in a player's goals-by-surface.
    String surface = '',
    String location = '',
    bool isPublic = false,
    JoiningMethod joiningMethod = JoiningMethod.separateTeams,
    TimingMode timingMode = TimingMode.none,
    int durationMin = 60,
    DateTime? scheduledAt,
    bool adminOnlyMode = false,
    String? adminPosition,
    String? teamAId,
    String? teamBId,
    String? challengedTeamId,
    String? challengedTeamName,
    String? challengeCaptainUid,
    List<String> challengeRecipientUids = const [],
  }) async {
    final code = randomCode(6);
    final ref = _matches.doc();
    await ref.set({
      'name': name.trim().isEmpty
          ? '$teamAName vs $teamBName'
          : name.trim(),
      'code': code,
      'codeA': joiningMethod == JoiningMethod.separateTeams ? code : null,
      'codeB': joiningMethod == JoiningMethod.separateTeams
          ? randomCode(6)
          : null,
      'adminUid': adminUid,
      'teamAName': teamAName,
      'teamBName': teamBName,
      'format': format,
      'surface': surface,
      'location': location,
      'isPublic': isPublic,
      'joiningMethod': joiningMethod.id,
      'timingMode': timingMode.id,
      'durationMin': durationMin,
      'matchType': 'friendly',
      'adminOnlyMode': adminOnlyMode,
      'status': 'lobby',
      'scoreA': 0,
      'scoreB': 0,
      'currentHalf': 1,
      'halfTime': false,
      'awardsDone': false,
      'playerUids': adminOnlyMode ? <String>[] : [adminUid],
      if (scheduledAt != null) 'scheduledAt': Timestamp.fromDate(scheduledAt),
      if (teamAId != null) 'teamAId': teamAId,
      if (teamBId != null) 'teamBId': teamBId,
      if (challengedTeamId != null) ...{
        'challengedTeamId': challengedTeamId,
        'challengedTeamName': challengedTeamName,
        'challengeCaptainUid': challengeCaptainUid,
        'challengeRecipientUids': challengeRecipientUids,
        'challengeStatus': 'pending',
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
    // The admin joins Team A as a player unless they're admin-only.
    if (!adminOnlyMode) {
      await _players(ref.id).doc(adminUid).set(MatchPlayer(
            uid: adminUid,
            name: adminName,
            team: TeamSide.a,
            position: adminPosition,
            joinedVia: 'admin',
            isAdmin: true,
          ).toMap());
    }
    // A saved team picked for a side brings its whole roster into the line-up.
    // Side B skips this when it's a *pending challenge* — those players come in
    // only if/when the challenged team accepts (see [acceptChallenge]).
    if (teamAId != null) {
      await addTeamRoster(ref.id, teamAId, TeamSide.a);
    }
    if (teamBId != null && challengedTeamId == null) {
      await addTeamRoster(ref.id, teamBId, TeamSide.b);
    }
    return MatchModel.fromDoc(await ref.get());
  }

  /// Edit a match that hasn't kicked off yet. The lobby is effectively page 2
  /// of creation, so the creator can step back and fix a setting they got
  /// wrong. Only the *settings* are editable — team links, rosters and
  /// challenges are deliberately left alone here, because those already pulled
  /// players in and sent notifications; the line-up is managed in the lobby.
  ///
  /// Two of the settings have side effects, handled here rather than by the
  /// screen so they can't drift apart:
  /// * the joining method decides whether per-side codes exist;
  /// * admin mode decides whether the creator is a player at all.
  Future<void> updateMatchSettings(
    String matchId, {
    required String adminUid,
    required String name,
    required String teamAName,
    required String teamBName,
    required String format,
    required JoiningMethod joiningMethod,
    required TimingMode timingMode,
    required int durationMin,
    required bool adminOnlyMode,
    String adminName = 'Admin',
    String? adminPosition,
  }) async {
    final m = await getMatch(matchId);
    if (m == null) throw StateError('match-missing');
    // Kick-off freezes the settings — the live screen reads them every tick.
    if (m.status != MatchStatus.lobby) throw StateError('match-started');
    if (m.adminUid != adminUid) throw StateError('not-admin');

    final data = <String, dynamic>{
      'name': name.trim().isEmpty ? '$teamAName vs $teamBName' : name.trim(),
      'teamAName': teamAName,
      'teamBName': teamBName,
      'format': format,
      'joiningMethod': joiningMethod.id,
      'timingMode': timingMode.id,
      'durationMin': durationMin,
      'adminOnlyMode': adminOnlyMode,
    };
    // Separate teams needs a code per side; an open lobby has only the master
    // code. Existing codes are kept so anything already shared still works.
    if (joiningMethod == JoiningMethod.separateTeams) {
      data['codeA'] = m.codeA ?? m.code;
      data['codeB'] = m.codeB ?? randomCode(6);
    } else {
      data['codeA'] = null;
      data['codeB'] = null;
    }
    await _matches.doc(matchId).update(data);

    if (adminOnlyMode != m.adminOnlyMode) {
      if (adminOnlyMode) {
        // Stepping off the pitch: drop the player doc, and the armband with it
        // — a captain who isn't playing would block `_start` forever.
        await _players(matchId).doc(adminUid).delete();
        await _matches.doc(matchId).update({
          'playerUids': FieldValue.arrayRemove([adminUid]),
          if (m.captainAUid == adminUid) 'captainAUid': null,
          if (m.captainBUid == adminUid) 'captainBUid': null,
        });
      } else {
        await _players(matchId).doc(adminUid).set(MatchPlayer(
              uid: adminUid,
              name: adminName,
              team: TeamSide.a,
              position: adminPosition,
              joinedVia: 'admin',
              isAdmin: true,
            ).toMap());
        await _matches.doc(matchId).update({
          'playerUids': FieldValue.arrayUnion([adminUid]),
        });
      }
    }
  }

  // ---- Lookups / streams ------------------------------------------------

  Stream<MatchModel?> watchMatch(String id) => _matches.doc(id).snapshots().map(
        (d) => d.exists ? MatchModel.fromDoc(d) : null,
      );

  Future<MatchModel?> getMatch(String id) async {
    final d = await _matches.doc(id).get();
    return d.exists ? MatchModel.fromDoc(d) : null;
  }

  // ---- Team challenges --------------------------------------------------

  /// Challenges awaiting this user's answer — they're the challenged team's
  /// owner OR captain. Drives the home popup/banner for BOTH; whoever answers
  /// first flips the status, so it drops out of everyone's stream at once.
  /// Sorted client-side (see [watchUserMatches]) to keep the index minimal.
  Stream<List<MatchModel>> watchPendingChallenges(String uid) => _matches
      .where('challengeRecipientUids', arrayContains: uid)
      .where('challengeStatus', isEqualTo: 'pending')
      .snapshots()
      .map((s) {
        final list = s.docs.map(MatchModel.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  /// Whoever may answer a challenge: any recipient (owner/captain), with a
  /// fallback to the legacy single-captain field for older match docs.
  bool _canAnswerChallenge(MatchModel m, String uid) =>
      m.challengeRecipientUids.contains(uid) || m.challengeCaptainUid == uid;

  /// Once one recipient answers, clear the challenge bell notification from all
  /// recipients so it doesn't linger for the others.
  Future<void> _clearChallengeNotifs(MatchModel m, String matchId) async {
    final uids = {...m.challengeRecipientUids, if (m.challengeCaptainUid != null) m.challengeCaptainUid!};
    for (final u in uids) {
      try {
        await NotificationRepository.instance.clearByArg(u, matchId,
            category: NotifCategory.matchInvite);
      } catch (_) {/* best-effort */}
    }
  }

  /// Captain accepts: they join side B, become its captain, and the admin is
  /// told. Side B stays linked to their team, so stats fold into it as usual.
  Future<void> acceptChallenge(
    String matchId, {
    required String uid,
    required String name,
    String? position,
  }) async {
    final m = await getMatch(matchId);
    if (m == null || !m.challengePending || !_canAnswerChallenge(m, uid)) return;
    await joinMatch(
      matchId: matchId,
      uid: uid,
      name: name,
      team: TeamSide.b,
      position: position,
      joinedVia: 'challenge',
    );
    await _matches.doc(matchId).update({
      'challengeStatus': 'accepted',
      'captainBUid': uid,
    });
    // Bring the accepting team's whole roster onto side B (the captain who just
    // joined is skipped) so their line-up is ready without re-adding players.
    if (m.challengedTeamId != null) {
      await addTeamRoster(matchId, m.challengedTeamId!, TeamSide.b);
    }
    await _clearChallengeNotifs(m, matchId);
    try {
      await NotificationRepository.instance.emit(
        m.adminUid,
        title: 'Challenge accepted',
        body: '"${m.challengedTeamName ?? m.teamBName}" accepted your challenge.',
        category: NotifCategory.matchUpdate,
        route: '/lobby',
        arg: matchId,
      );
    } catch (_) {/* best-effort */}
  }

  /// Captain declines: side B is released back to a free-text "Team B" so the
  /// admin can re-challenge, pick another team, or just play. The match itself
  /// is kept — other players may already have joined side A.
  Future<void> declineChallenge(String matchId, {required String uid}) async {
    final m = await getMatch(matchId);
    if (m == null || !m.challengePending || !_canAnswerChallenge(m, uid)) return;
    await _matches.doc(matchId).update({
      'challengeStatus': 'declined',
      'teamBId': null,
      'teamBName': 'Team B',
    });
    await _clearChallengeNotifs(m, matchId);
    try {
      await NotificationRepository.instance.emit(
        m.adminUid,
        title: 'Challenge declined',
        body: '"${m.challengedTeamName ?? m.teamBName}" declined your challenge.',
        category: NotifCategory.matchUpdate,
        route: '/lobby',
        arg: matchId,
      );
    } catch (_) {/* best-effort */}
  }

  /// Find by any join code (shared, side A or side B). Returns the match + the
  /// side the code maps to.
  Future<(MatchModel, TeamSide)?> findByCode(String code) async {
    final c = code.trim().toUpperCase();
    for (final field in ['code', 'codeA', 'codeB']) {
      final q = await _matches.where(field, isEqualTo: c).limit(1).get();
      if (q.docs.isNotEmpty) {
        final m = MatchModel.fromDoc(q.docs.first);
        final side = (m.codeB == c) ? TeamSide.b : TeamSide.a;
        return (m, side);
      }
    }
    return null;
  }

  Stream<List<MatchPlayer>> watchPlayers(String id) => _players(id)
      .orderBy('joinedAt')
      .snapshots()
      .map((s) => s.docs.map(MatchPlayer.fromDoc).toList());

  Future<List<MatchPlayer>> getPlayers(String id) async {
    final s = await _players(id).orderBy('joinedAt').get();
    return s.docs.map(MatchPlayer.fromDoc).toList();
  }

  Stream<List<PendingPlayer>> watchPending(String id) => _pending(id)
      .orderBy('at')
      .snapshots()
      .map((s) => s.docs.map(PendingPlayer.fromDoc).toList());

  Stream<List<GoalEvent>> watchGoals(String id) => _goals(id)
      .orderBy('at')
      .snapshots()
      .map((s) => s.docs.map(GoalEvent.fromDoc).toList());

  // NOTE: cards (yellow/red) and substitutions were removed from the product —
  // no screen logs or shows them. The `cards`/`subs` subcollections are still
  // swept by `quitDiscard`/`restartMatch`/the admin wipe so any documents left
  // by an older build get cleaned up rather than orphaned.

  Stream<List<MatchModel>> watchUserMatches(String uid) => _matches
      .where('playerUids', arrayContains: uid)
      .snapshots()
      .map((s) {
        final list = s.docs.map(MatchModel.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  /// The one match this user is CURRENTLY playing that is live, if any. Drives
  /// the global "you're in a live match" gate: whoever is in the roster is held
  /// on the live screen until the creator ends it, and is sent straight back to
  /// it on app restart. Filtered client-side off the existing arrayContains
  /// query so no composite index is needed. Newest kickoff wins on the (rare)
  /// chance of two concurrent live matches.
  Stream<MatchModel?> watchMyLiveMatch(String uid) => _matches
      .where('playerUids', arrayContains: uid)
      .snapshots()
      .map((s) {
        final live = s.docs
            .map(MatchModel.fromDoc)
            .where((m) => m.status == MatchStatus.live)
            .toList();
        if (live.isEmpty) return null;
        live.sort((a, b) => (b.startedAt ?? b.createdAt ?? DateTime(0))
            .compareTo(a.startedAt ?? a.createdAt ?? DateTime(0)));
        return live.first;
      });

  /// This user's current DRAFT match — one they created (`adminUid`) that is
  /// still in the lobby (never started) — or null.
  ///
  /// A user may only ever hold **one** draft at a time (enforced in
  /// `openCreateMatch`), so this is the single draft rather than a list; if a
  /// build ever leaves two behind, the newest wins and the Draft screen's delete
  /// clears them one at a time. Filtered client-side off a single-field
  /// `adminUid` query, so **no composite index** is needed.
  Stream<MatchModel?> watchMyDraft(String uid) =>
      _matches.where('adminUid', isEqualTo: uid).snapshots().map(_pickDraft);

  /// One-shot read of [watchMyDraft], for the create-match gate.
  Future<MatchModel?> getMyDraft(String uid) async {
    final snap = await _matches.where('adminUid', isEqualTo: uid).get();
    return _pickDraft(snap);
  }

  /// Newest still-in-the-lobby match from an `adminUid` query result.
  ///
  /// Drafts past [kDraftTtl] are treated as already gone even if
  /// [sweepStaleDrafts] hasn't caught up — cleanup is lazy (no Cloud
  /// Functions), so an expired draft must never keep showing its red dot or
  /// keep blocking a new one.
  MatchModel? _pickDraft(QuerySnapshot<Map<String, dynamic>> snap) {
    final cutoff = DateTime.now().subtract(kDraftTtl);
    final drafts = snap.docs
        .map(MatchModel.fromDoc)
        .where((m) =>
            m.status == MatchStatus.lobby &&
            !(m.createdAt?.isBefore(cutoff) ?? false))
        .toList();
    if (drafts.isEmpty) return null;
    drafts.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return drafts.first;
  }

  /// Delete this user's stale DRAFT matches — ones they created (`adminUid`)
  /// that are still in the lobby (never started) and older than [kDraftTtl].
  /// There are no Cloud Functions, so this runs lazily whenever the Draft
  /// page opens. Filters status client-side (single-field `adminUid` query, so
  /// no composite index). Best-effort per doc.
  Future<void> sweepStaleDrafts(String uid) async {
    final cutoff = DateTime.now().subtract(kDraftTtl);
    try {
      final snap = await _matches.where('adminUid', isEqualTo: uid).get();
      for (final d in snap.docs) {
        final m = MatchModel.fromDoc(d);
        if (m.status == MatchStatus.lobby &&
            m.createdAt != null &&
            m.createdAt!.isBefore(cutoff)) {
          await quitDiscard(m.id);
        }
      }
    } catch (_) {/* best-effort — the warning on the card still informs the user */}
  }

  // NOTE: `watchOpenMatches` (public lobbies) was removed along with the Find
  // Match screen — every match is private now, so the query could only ever
  // return nothing. The `status + isPublic` composite index stays deployed and
  // simply goes unused; restore both together if public matches come back.

  // ---- Joining ----------------------------------------------------------

  Future<void> joinMatch({
    required String matchId,
    required String uid,
    required String name,
    TeamSide team = TeamSide.a,
    String? position,
    String joinedVia = 'code',
    bool isGuest = false,
  }) async {
    await _players(matchId).doc(uid).set(MatchPlayer(
          uid: uid,
          name: name,
          team: team,
          position: position,
          joinedVia: joinedVia,
          isGuest: isGuest,
        ).toMap());
    await _matches.doc(matchId).update({
      'playerUids': FieldValue.arrayUnion([uid]),
    });
    try {
      final m = await getMatch(matchId);
      if (m != null && m.adminUid.isNotEmpty && m.adminUid != uid) {
        await NotificationRepository.instance.emit(
          m.adminUid,
          title: 'New player joined',
          body: '$name joined "${m.teamName(team)}".',
          category: NotifCategory.matchUpdate,
          route: '/lobby',
          arg: matchId,
        );
      }
    } catch (_) {/* best-effort */}
  }

  // ---- Registered-player invites ----------------------------------------

  /// Invite a registered player to the match instead of adding them outright.
  /// They get a popup + a bell/push notification and only actually join if they
  /// accept. [byName] is the inviter's display name (shown in the popup).
  Future<void> invitePlayer(
    String matchId, {
    required String uid,
    required String name,
    required TeamSide team,
    required String byName,
  }) async {
    await _matches.doc(matchId).update({
      'invitedUids': FieldValue.arrayUnion([uid]),
      'invites.$uid': {'team': team.id, 'name': name, 'byName': byName},
    });
    try {
      final m = await getMatch(matchId);
      final label = (m == null || m.name.isEmpty)
          ? 'a match'
          : '"${m.name}"';
      await NotificationRepository.instance.emit(
        uid,
        title: 'Match invite',
        body: '$byName invited you to join $label. Tap to respond.',
        category: NotifCategory.matchInvite,
        route: '/home',
        arg: matchId,
      );
    } catch (_) {/* best-effort — the home popup still shows via the stream */}
  }

  /// Matches this user has an unanswered invite to. Drives the home popup/banner.
  /// Filtered client-side to lobby/live so no composite index is needed.
  Stream<List<MatchModel>> watchPendingMatchInvites(String uid) => _matches
      .where('invitedUids', arrayContains: uid)
      .snapshots()
      .map((s) {
        final list = s.docs
            .map(MatchModel.fromDoc)
            .where((m) =>
                m.status == MatchStatus.lobby || m.status == MatchStatus.live)
            .toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  /// The invited player accepts: they join the side they were invited to and
  /// the invite is cleared. Notifies the admin like any other join.
  Future<void> acceptMatchInvite(
    String matchId, {
    required String uid,
    required String name,
    String? position,
  }) async {
    final m = await getMatch(matchId);
    if (m == null || !m.invitedUids.contains(uid)) return;
    final side = m.invitedTeam(uid) ?? TeamSide.a;
    await joinMatch(
      matchId: matchId,
      uid: uid,
      name: name,
      team: side,
      position: position,
      joinedVia: 'invite',
    );
    await _matches.doc(matchId).update({
      'invitedUids': FieldValue.arrayRemove([uid]),
      'invites.$uid': FieldValue.delete(),
    });
  }

  /// Decline (invitee) or cancel (creator/captain) an outstanding invite.
  Future<void> declineMatchInvite(String matchId, String uid) =>
      _matches.doc(matchId).update({
        'invitedUids': FieldValue.arrayRemove([uid]),
        'invites.$uid': FieldValue.delete(),
      });

  /// Add every member of [teamId] to the match as players on [side], skipping
  /// anyone already in the match. Used when a saved team is picked for a side,
  /// or when a challenged team accepts — so their whole line-up shows up without
  /// re-adding people by hand. Members become normal match players (auto-created
  /// members keep their guest flag); removing one later affects only this match,
  /// never the saved team.
  Future<void> addTeamRoster(
      String matchId, String teamId, TeamSide side) async {
    final team = await TeamRepository.instance.getTeam(teamId);
    if (team == null) return;
    final existing = (await getPlayers(matchId)).map((p) => p.uid).toSet();
    final toAdd =
        team.memberUids.where((u) => u.isNotEmpty && !existing.contains(u)).toList();
    if (toAdd.isNotEmpty) {
      final users = await UserRepository.instance.getUsers(toAdd);
      final byId = {for (final u in users) u.uid: u};
      final batch = _db.batch();
      for (final uid in toAdd) {
        final u = byId[uid];
        batch.set(
          _players(matchId).doc(uid),
          MatchPlayer(
            uid: uid,
            name: u?.name ?? 'Player',
            team: side,
            position: u?.position,
            joinedVia: 'team',
            isGuest: u?.autoCreated ?? false,
          ).toMap(),
        );
      }
      batch.update(_matches.doc(matchId),
          {'playerUids': FieldValue.arrayUnion(toAdd)});
      await batch.commit();
    }
    await _adoptTeamCaptain(matchId, team, side);
  }

  /// A team that already elected a captain shouldn't have to elect one again
  /// for the match: if that captain (owner as fallback) is playing on [side],
  /// they take the armband automatically, so the creator only nominates for a
  /// side that has no team behind it.
  ///
  /// Runs whether or not anyone was just added — the captain is often already
  /// in the match (the creator is a player from `createMatch`, so a saved Team
  /// A adds nobody new). Never overrides a captain the side already has, which
  /// is what leaves `acceptChallenge`'s "whoever answered runs side B" intact.
  Future<void> _adoptTeamCaptain(
      String matchId, TeamModel team, TeamSide side) async {
    final match = await getMatch(matchId);
    if (match == null || match.captainUid(side) != null) return;
    final captain = (team.captainUid?.isNotEmpty ?? false)
        ? team.captainUid!
        : team.ownerUid;
    if (captain.isEmpty) return;
    // Re-read so a player added by the batch above is included.
    final onSide = (await getPlayers(matchId))
        .where((p) => p.uid == captain && p.team == side)
        .toList();
    if (onSide.isEmpty) return; // captain isn't playing this one — ask instead
    await assignMatchCaptain(matchId, side, onSide.first);
  }

  /// Accountless guest join (name + phone/email). Stores a claimable guest
  /// record and adds the guest to the lobby. Returns the generated guest id.
  Future<String> guestJoin({
    required String matchId,
    required String name,
    String? phone,
    String? email,
    TeamSide team = TeamSide.a,
    bool midGame = false,
  }) async {
    final guestId = 'g_${randomCode(10)}';
    await _guests.doc(guestId).set({
      'name': name,
      'phone': phone,
      'email': email,
      'matchId': matchId,
      'claimed': false,
      'at': FieldValue.serverTimestamp(),
    });
    if (midGame) {
      await addPending(
          matchId: matchId, uid: guestId, name: name, team: team,
          isGuest: true, midGame: true);
    } else {
      await joinMatch(
          matchId: matchId, uid: guestId, name: name, team: team,
          joinedVia: 'link', isGuest: true);
    }
    return guestId;
  }

  /// Admin adds a not-yet-registered player as a guest directly to a team.
  Future<String> addGuestPlayer({
    required String matchId,
    required String name,
    String? phone,
    String? email,
    TeamSide team = TeamSide.a,
  }) =>
      guestJoin(
          matchId: matchId, name: name, phone: phone, email: email, team: team);

  /// Admin adds a player by email: creates a real account for them, then adds
  /// them to the match.
  ///
  /// [createPlayerAccount] may hand back an account that ALREADY existed (its
  /// `email-already-in-use` branch), so the profile is read back rather than
  /// assumed. Three things come from it:
  ///
  ///  * **`isGuest`** — `u?.autoCreated ?? false`, the same rule `addTeamRoster`
  ///    uses and the same one the website's join uses. A profile nobody has
  ///    filled in yet reads as a guest until its owner claims it; it used to be
  ///    hard-coded false here, so the identical person looked like a guest when
  ///    they arrived via a saved team and a full player when added by email.
  ///  * **name and position** — an existing account's own, so adding somebody
  ///    who is already on YNO does not relabel them with whatever the admin
  ///    typed.
  ///
  /// Since `finalizeMatch` resolves stats against the `users` document rather
  /// than this flag, being marked a guest here costs them nothing.
  Future<String> addNewPlayer({
    required String matchId,
    required String name,
    required String email,
    TeamSide team = TeamSide.a,
    String? position,
  }) async {
    final uid = await AuthRepository.instance
        .createPlayerAccount(name: name, email: email, position: position);
    final u = await UserRepository.instance.getUser(uid);
    final profileName = (u?.name ?? '').trim();
    await joinMatch(
        matchId: matchId,
        uid: uid,
        name: profileName.isEmpty ? name : profileName,
        team: team,
        position: position ?? u?.position,
        joinedVia: 'added',
        isGuest: u?.autoCreated ?? false);
    return uid;
  }

  // ---- Pending area / mid-game -----------------------------------------

  Future<void> addPending({
    required String matchId,
    required String uid,
    required String name,
    TeamSide team = TeamSide.a,
    bool isGuest = false,
    bool midGame = false,
  }) async {
    await _pending(matchId).doc(uid).set(PendingPlayer(
          uid: uid, name: name, team: team, isGuest: isGuest, midGame: midGame,
        ).toMap());
    final m = await getMatch(matchId);
    if (m != null) {
      await NotificationRepository.instance.emit(
        m.adminUid,
        title: 'Player waiting',
        body: '$name is waiting to join${midGame ? ' (mid-game)' : ''}.',
        category: NotifCategory.matchUpdate,
        route: m.status == MatchStatus.live ? '/live' : '/lobby',
        arg: matchId,
      );
    }
  }

  Future<void> approvePending(String matchId, PendingPlayer p) async {
    await joinMatch(
        matchId: matchId, uid: p.uid, name: p.name, team: p.team,
        joinedVia: 'link', isGuest: p.isGuest);
    await _pending(matchId).doc(p.uid).delete();
  }

  Future<void> declinePending(String matchId, String uid) =>
      _pending(matchId).doc(uid).delete();

  // ---- Admin powers -----------------------------------------------------

  Future<void> removePlayer(String matchId, String uid) async {
    await _players(matchId).doc(uid).delete();
    await _matches.doc(matchId).update({
      'playerUids': FieldValue.arrayRemove([uid]),
    });
  }

  /// A player removes **themselves** from a match they have not started yet.
  ///
  /// Distinct from [removePlayer], which is a manager acting on someone else.
  /// Leaving is always the player's own call, so it needs no `canManageSide`
  /// check — but two things have to be cleaned up or the lobby breaks:
  ///
  /// * **The armband.** `_start` blocks until both sides have a captain, so a
  ///   captain who walks out would freeze the match for everyone left behind.
  /// * **A pending invite**, otherwise the invite they just declined by leaving
  ///   would pop straight back up on their home screen.
  ///
  /// Throws `StateError('match-started')` once the match is live — quitting a
  /// running game is the host's call (End / abandon), not a silent exit — and
  /// `StateError('admin-cannot-leave')` for the creator, who must delete the
  /// draft or end the match instead.
  Future<void> leaveMatch(String matchId, String uid) async {
    final m = await getMatch(matchId);
    if (m == null) return;
    if (m.status != MatchStatus.lobby) throw StateError('match-started');
    if (m.adminUid == uid) throw StateError('admin-cannot-leave');

    await _players(matchId).doc(uid).delete();
    await _matches.doc(matchId).update({
      'playerUids': FieldValue.arrayRemove([uid]),
      'invitedUids': FieldValue.arrayRemove([uid]),
      'invites.$uid': FieldValue.delete(),
      if (m.captainAUid == uid) 'captainAUid': null,
      if (m.captainBUid == uid) 'captainBUid': null,
    });
  }

  /// A player walks out of a match that has already kicked off.
  ///
  /// Deliberately NOT [leaveMatch] with the status check relaxed, because the
  /// two are opposite operations. Leaving a lobby deletes you: you were never
  /// in the game, so nothing should remember you. Leaving a live match must
  /// keep every trace of you — you played part of it, you may have scored, and
  /// the host has to go on assigning goals and assists to you afterwards. So
  /// the roster document stays exactly where it is and only gains a flag.
  ///
  /// 🔑 **Removing the uid from `playerUids` is the part that does the work.**
  /// `watchMyLiveMatch` feeds the global gate in `app.dart`, which force-pushes
  /// the live screen at anyone in that array; a leave that only navigated home
  /// would be dragged straight back within a frame. The array is match
  /// *participation*, the subcollection is the match *record* — this splits
  /// them, which is exactly what the feature needs.
  ///
  /// Consequences that follow from that split, all intended:
  /// * The match leaves their Matches list (`watchUserMatches` is the same
  ///   array) and they are no longer redirected to the results at full time.
  /// * Their stats still land: `applyMatchStats` walks the players
  ///   subcollection, not `playerUids`, so career goals, assists and awards are
  ///   credited as if they had stayed.
  ///
  /// The armband is surrendered on the way out — a side cannot be run by
  /// somebody who has gone home — but unlike the lobby that frees nothing, so
  /// it is only about who can manage the roster from here on.
  ///
  /// Throws `StateError('not-live')` if the match is not running (use
  /// [leaveMatch] in the lobby) and `StateError('admin-cannot-leave')` for the
  /// creator, who drives the match and must end or abandon it instead.
  Future<void> leaveLiveMatch(String matchId, String uid) async {
    final m = await getMatch(matchId);
    if (m == null) return;
    if (m.status != MatchStatus.live) throw StateError('not-live');
    if (m.adminUid == uid) throw StateError('admin-cannot-leave');

    await _players(matchId).doc(uid).update({
      'left': true,
      'leftAt': FieldValue.serverTimestamp(),
      if (m.captainAUid == uid || m.captainBUid == uid) 'isCaptain': false,
    });
    await _matches.doc(matchId).update({
      'playerUids': FieldValue.arrayRemove([uid]),
      if (m.captainAUid == uid) 'captainAUid': null,
      if (m.captainBUid == uid) 'captainBUid': null,
    });
  }

  Future<void> movePlayer(String matchId, MatchPlayer p, TeamSide to) =>
      _players(matchId).doc(p.uid).update({'team': to.id});

  /// Assign the match captain for a side (clears any previous captain there).
  Future<void> assignMatchCaptain(
      String matchId, TeamSide side, MatchPlayer p) async {
    final players = await getPlayers(matchId);
    final batch = _db.batch();
    for (final other in players.where((x) => x.team == side && x.isCaptain)) {
      batch.update(_players(matchId).doc(other.uid), {'isCaptain': false});
    }
    batch.update(_players(matchId).doc(p.uid), {'isCaptain': true});
    batch.update(_matches.doc(matchId),
        {side == TeamSide.a ? 'captainAUid' : 'captainBUid': p.uid});
    await batch.commit();
  }

  Future<void> regenerateCode(String matchId, {TeamSide? side}) async {
    final m = await getMatch(matchId);
    if (m == null) return;
    if (m.joiningMethod == JoiningMethod.openLobby || side == null) {
      await _matches.doc(matchId).update({'code': randomCode(6)});
    } else if (side == TeamSide.a) {
      await _matches.doc(matchId).update({'codeA': randomCode(6)});
    } else {
      await _matches.doc(matchId).update({'codeB': randomCode(6)});
    }
  }

  /// Both teams must have a confirmed captain before a match can start.
  Future<bool> canStart(String matchId) async {
    final m = await getMatch(matchId);
    if (m == null) return false;
    return m.captainAUid != null && m.captainBUid != null;
  }

  // ---- Live match -------------------------------------------------------

  Future<void> startMatch(String id) async {
    final m = await getMatch(id);
    if (m == null) return;
    final now = DateTime.now();
    // For "two halves" the duration is per-half; for "full" it's the total.
    final minutes = m.timingMode == TimingMode.none ? 0 : m.durationMin;
    await _matches.doc(id).update({
      'status': 'live',
      'startedAt': Timestamp.fromDate(now),
      if (minutes > 0)
        'endsAt': Timestamp.fromDate(now.add(Duration(minutes: minutes))),
    });
  }

  Future<void> extendMatch(String id, int minutes) async {
    final m = await getMatch(id);
    if (m == null) return;
    final base = m.endsAt ?? DateTime.now();
    await _matches.doc(id).update({
      'endsAt': Timestamp.fromDate(base.add(Duration(minutes: minutes))),
    });
  }

  /// Stop the clock mid-play (injury, lost ball, argument). Everyone's readout
  /// freezes because the screens read the clock against `pausedAt` while it's
  /// set. No-op if already paused, so a double tap can't lose the timestamp.
  Future<void> pauseMatch(String id) async {
    final m = await getMatch(id);
    if (m == null || m.paused) return;
    await _matches.doc(id).update({
      'pausedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Resume: give back exactly the time the break took by pushing both ends of
  /// the clock forward, so a pause never costs match minutes. `startedAt` moves
  /// too — it drives both the count-up readout and `actualDurationSec`, which
  /// should measure football played, not wall-clock.
  Future<void> resumeMatch(String id) async {
    final m = await getMatch(id);
    if (m == null || m.pausedAt == null) return;
    final break_ = DateTime.now().difference(m.pausedAt!);
    await _matches.doc(id).update({
      'pausedAt': null,
      if (m.startedAt != null)
        'startedAt': Timestamp.fromDate(m.startedAt!.add(break_)),
      if (m.endsAt != null)
        'endsAt': Timestamp.fromDate(m.endsAt!.add(break_)),
    });
  }

  /// Two-halves: pause at half-time.
  ///
  /// Stamps when the interval began so [startSecondHalf] can hand the break
  /// back to the clock. `halfTimeAt` rather than `pausedAt` on purpose — see
  /// the field's own note; `pausedAt` raises a PAUSED badge and a Resume
  /// button, which would fight the half-time panel.
  Future<void> pauseHalfTime(String id) async {
    final m = await getMatch(id);
    if (m == null || m.halfTime) return; // Don't restamp on a double tap.
    await _matches.doc(id).update({
      'halfTime': true,
      'halfTimeAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Two-halves: begin the second half.
  ///
  /// Pushes `startedAt` forward by the length of the interval, the same trick
  /// [resumeMatch] uses for a pause. The readout counts UP from `startedAt`, so
  /// without this a twenty-minute half-time would put the second half on screen
  /// at 65:00 — and `actualDurationSec`, which is meant to measure football
  /// played, would bill the tea break as match time.
  Future<void> startSecondHalf(String id) async {
    final m = await getMatch(id);
    if (m == null) return;
    final now = DateTime.now();
    final interval =
        m.halfTimeAt == null ? Duration.zero : now.difference(m.halfTimeAt!);
    await _matches.doc(id).update({
      'halfTime': false,
      'halfTimeAt': null,
      'currentHalf': 2,
      if (m.startedAt != null)
        'startedAt': Timestamp.fromDate(m.startedAt!.add(interval)),
      'endsAt': Timestamp.fromDate(now.add(Duration(minutes: m.durationMin))),
    });
  }

  Future<void> recordGoal({
    required String matchId,
    required MatchPlayer scorer,
    required int minute,
    MatchPlayer? assist,
  }) async {
    final m = await getMatch(matchId);
    final newA = (m?.scoreA ?? 0) + (scorer.team == TeamSide.a ? 1 : 0);
    final newB = (m?.scoreB ?? 0) + (scorer.team == TeamSide.b ? 1 : 0);
    final batch = _db.batch();
    batch.set(_goals(matchId).doc(), {
      'scorerUid': scorer.uid,
      'scorerName': scorer.name,
      'team': scorer.team.id,
      'minute': minute,
      if (assist != null) 'assistUid': assist.uid,
      if (assist != null) 'assistName': assist.name,
      'scoreAAfter': newA,
      'scoreBAfter': newB,
      'at': FieldValue.serverTimestamp(),
    });
    batch.update(
        _players(matchId).doc(scorer.uid), {'goals': FieldValue.increment(1)});
    if (assist != null && assist.uid != scorer.uid) {
      batch.update(_players(matchId).doc(assist.uid),
          {'assists': FieldValue.increment(1)});
    }
    batch.update(_matches.doc(matchId),
        {scorer.team == TeamSide.a ? 'scoreA' : 'scoreB': FieldValue.increment(1)});
    await batch.commit();
  }

  /// End a level match with an explicit outcome method.
  /// [method] ∈ 'draw' | 'penalties' | 'goldenGoal'. [winnerSide] required for
  /// penalties/goldenGoal.
  /// Record how a level match was settled. [penaltyA]/[penaltyB] carry the
  /// shootout score when [method] is `'penalties'`; they are written only when
  /// supplied, so a legacy penalties result without a score stays untouched.
  Future<void> setOutcome(String matchId,
          {required String method,
          TeamSide? winnerSide,
          int? penaltyA,
          int? penaltyB}) =>
      _matches.doc(matchId).update({
        'outcomeMethod': method,
        'winnerSide': winnerSide?.id,
        if (penaltyA != null) 'penaltyA': penaltyA,
        if (penaltyB != null) 'penaltyB': penaltyB,
      });

  Future<void> endMatch(String id) async {
    final m = await getMatch(id);
    if (m == null) return;
    final now = DateTime.now();
    final dur = m.startedAt == null
        ? 0
        : now.difference(m.startedAt!).inSeconds;
    await _matches.doc(id).update({
      'status': 'ended',
      'endedAt': Timestamp.fromDate(now),
      'actualDurationSec': dur,
      // ⚠️ A level match is left with `outcomeMethod: null` ON PURPOSE — it is
      // the host's decision, and this is the flag the whole hold works on.
      //
      // This used to stamp `'draw'` here for a level score. That defeated the
      // one thing it was supposed to enable: `live_match_screen`'s
      // `_awaitingHostDecision` requires `outcomeMethod == null`, so the panel
      // that pins the other players while the host chooses never appeared. They
      // were released to a scorecard reading "Draw" the instant End was tapped,
      // and could walk away before the host had even seen the extra time /
      // penalties options. `MatchOutcomeScreen` always writes the real value.
      if (m.outcomeMethod == null && !m.isLevel) 'outcomeMethod': 'fullTime',
    });
  }

  /// Send a level match into extra time: the clock reopens for [minutes] and
  /// everyone goes back to the live screen.
  ///
  /// Extra time was a retrospective checkbox until 2026-09-07 — the host was
  /// asked "was extra time played?" *after* [endMatch], so none of it ever
  /// happened inside the app. It is a real period now, which is why this has to
  /// undo the end rather than annotate it: `status` back to `live`, `endedAt`
  /// and `actualDurationSec` cleared (they are re-stamped by the next
  /// [endMatch], and a stale pair would report a match that finished before its
  /// own extra time), and the clock pushed out from *now* rather than from the
  /// old `endsAt`, which is already in the past.
  ///
  /// [minutes] accumulates into `extraTimeMin`, so a second period grants
  /// 90+10+5 rather than resetting the label.
  ///
  /// **`minutes == 0` means an open-ended period**, and it is the normal case
  /// now: matches created since 2026-09-07 have no clock at all
  /// ([TimingMode.none]) — the host runs a stopwatch and ends the match by
  /// hand. Asking such a host to commit to "10 minutes" of extra time would
  /// reintroduce the very pre-set length the timing picker was removed to get
  /// rid of. So `endsAt` is left untouched, the stopwatch simply keeps running,
  /// and they end it again when they decide it is over.
  ///
  /// `extraTimeMin` still increments in that case, because it is also the flag
  /// [MatchOutcomeScreen] reads to know extra time was played and to stop
  /// offering it a second time as though none had been. The `90+10` label needs
  /// a regulation clock to measure against and correctly renders as empty —
  /// see [MatchModel.extraTimeLabel].
  Future<void> startExtraTime(String id, int minutes) async {
    final m = await getMatch(id);
    if (m == null || minutes < 0) return;
    final now = DateTime.now();
    await _matches.doc(id).update({
      'status': 'live',
      'endedAt': null,
      'actualDurationSec': null,
      'outcomeMethod': null,
      'pausedAt': null,
      // Half-time is a regulation concept; extra time is played straight
      // through. Leaving `halfTime` set would freeze the readout at "HT".
      'halfTime': false,
      // Minimum 1 so an open-ended period still marks the match as having gone
      // to extra time; the number is not shown when there is no clock.
      'extraTimeMin': FieldValue.increment(minutes == 0 ? 1 : minutes),
      if (minutes > 0)
        'endsAt': Timestamp.fromDate(now.add(Duration(minutes: minutes))),
      // `startedAt` keeps measuring the whole match, extra time included — but
      // it is pushed forward by however long the host spent on the outcome
      // screen. That gap is not football: the readout counts UP from
      // `startedAt`, so a host who deliberated for four minutes would otherwise
      // kick extra time off at 94:00 and carry the error into
      // `actualDurationSec`.
      if (m.startedAt != null && m.endedAt != null)
        'startedAt':
            Timestamp.fromDate(m.startedAt!.add(now.difference(m.endedAt!))),
    });
  }

  /// Settle a level match on penalties, recording *who* converted.
  ///
  /// The shootout score is the length of each list, so the two can never
  /// disagree. [scorersA]/[scorersB] may repeat a player (sudden death comes
  /// back round the order), and each entry increments that player's
  /// `players/{uid}.goals` — the client's decision that shootout kicks count
  /// toward a career tally. See [PenaltyEvent] for why they are not written to
  /// `goals` and never touch `scoreA`/`scoreB`.
  ///
  /// One batch, so a half-written shootout can't leave the match settled with
  /// the kicks missing.
  Future<void> recordShootout(
    String matchId, {
    required List<MatchPlayer> scorersA,
    required List<MatchPlayer> scorersB,
  }) async {
    final a = scorersA.length;
    final b = scorersB.length;
    if (a == b) return; // A shootout has a winner; the sheet enforces this too.
    final batch = _db.batch();
    final tally = <String, int>{};
    for (final entry in [
      (TeamSide.a, scorersA),
      (TeamSide.b, scorersB),
    ]) {
      final side = entry.$1;
      for (var i = 0; i < entry.$2.length; i++) {
        final p = entry.$2[i];
        batch.set(_penalties(matchId).doc(), {
          'scorerUid': p.uid,
          'scorerName': p.name,
          'team': side.id,
          'order': i + 1,
          'at': FieldValue.serverTimestamp(),
        });
        tally[p.uid] = (tally[p.uid] ?? 0) + 1;
      }
    }
    // Increment once per player rather than once per kick — a hat-trick in the
    // shootout is one write, and `FieldValue.increment` can't be applied twice
    // to the same field in one batch.
    tally.forEach((uid, n) {
      batch.update(_players(matchId).doc(uid), {
        'goals': FieldValue.increment(n),
      });
    });
    batch.update(_matches.doc(matchId), {
      'outcomeMethod': 'penalties',
      'winnerSide': (a > b ? TeamSide.a : TeamSide.b).id,
      'penaltyA': a,
      'penaltyB': b,
    });
    await batch.commit();
  }

  /// Converted spot-kicks, in the order they were taken.
  Stream<List<PenaltyEvent>> watchPenalties(String id) => _penalties(id)
      .orderBy('at')
      .snapshots()
      .map((s) => s.docs.map(PenaltyEvent.fromDoc).toList());

  /// Quit → save what was played, mark abandoned. Stats still count.
  Future<void> quitAbandon(String id) async {
    final m = await getMatch(id);
    final now = DateTime.now();
    await _matches.doc(id).update({
      'status': 'abandoned',
      'endedAt': Timestamp.fromDate(now),
      'outcomeMethod': 'abandoned',
      if (m?.startedAt != null)
        'actualDurationSec': now.difference(m!.startedAt!).inSeconds,
    });
  }

  /// Quit → discard entirely (delete the match + its subcollections best-effort).
  Future<void> quitDiscard(String id) async {
    for (final col in ['players', 'pending', 'goals', 'penalties', 'cards', 'subs', 'votes']) {
      final snap = await _matches.doc(id).collection(col).get();
      for (final d in snap.docs) {
        await d.reference.delete();
      }
    }
    await _matches.doc(id).delete();
  }

  /// Restart: wipe the events + score and **kick off again from 0:00** with the
  /// same players. The clock is re-armed here — it used to be nulled, which left
  /// a restarted match reading `--:--` forever with no way to start it (the
  /// Start button lives in the lobby, and the match never goes back there).
  Future<void> restartMatch(String id) async {
    final m = await getMatch(id);
    // 'cards'/'subs' are legacy — swept so an older build's events don't
    // survive a restart even though nothing writes them any more.
    for (final col in ['goals', 'penalties', 'cards', 'subs']) {
      final snap = await _matches.doc(id).collection(col).get();
      for (final d in snap.docs) {
        await d.reference.delete();
      }
    }
    final players = await _players(id).get();
    final now = DateTime.now();
    final minutes = (m == null || m.timingMode == TimingMode.none)
        ? 0
        : m.durationMin;
    final batch = _db.batch();
    for (final d in players.docs) {
      batch.update(d.reference, {'goals': 0, 'assists': 0});
    }
    batch.update(_matches.doc(id), {
      'scoreA': 0,
      'scoreB': 0,
      'currentHalf': 1,
      'halfTime': false,
      'pausedAt': null,
      'startedAt': Timestamp.fromDate(now),
      'endsAt': minutes > 0
          ? Timestamp.fromDate(now.add(Duration(minutes: minutes)))
          : null,
    });
    await batch.commit();
  }

  // ---- Community voting -------------------------------------------------

  Future<void> castVote(String matchId, String voterUid, String votedUid) =>
      _votes(matchId).doc(voterUid).set({
        'votedUid': votedUid,
        'at': FieldValue.serverTimestamp(),
      });

  Stream<bool> watchHasVoted(String matchId, String voterUid) =>
      _votes(matchId).doc(voterUid).snapshots().map((d) => d.exists);

  Stream<int> watchVoteCount(String matchId) =>
      _votes(matchId).snapshots().map((s) => s.docs.length);

  // ---- Ratings (legacy compatibility) -----------------------------------

  Future<void> submitRatings({
    required String matchId,
    required String raterUid,
    required Map<String, int> scores,
  }) =>
      _matches.doc(matchId).collection('ratings').doc(raterUid).set({
        'scores': scores,
        'at': FieldValue.serverTimestamp(),
      });

  Stream<bool> watchHasRated(String matchId, String raterUid) => _matches
      .doc(matchId)
      .collection('ratings')
      .doc(raterUid)
      .snapshots()
      .map((d) => d.exists);

  // ---- Finalize (immediate on end) --------------------------------------

  /// Which of [players] have a real account **at this moment**.
  ///
  /// ⚠️ Deliberately NOT `!p.isGuest`. `MatchPlayer.isGuest` is a snapshot taken
  /// when the player joined, and it is true for anyone whose profile was still a
  /// stub then (`autoCreated`) — which is what the lobby renders, and should
  /// keep rendering. But it must not decide where the stats go:
  ///
  ///  * someone who **claimed their account between kick-off and the final
  ///    whistle** is a real player by the time this runs; the snapshot says
  ///    otherwise and their whole match would be filed as a guest's;
  ///  * worse, the guest branch writes `guests/{uid}`, and `claimGuestStats`
  ///    finds those records by **email** — a field that write never sets. For a
  ///    player with a real uid (a host-added account, or a web join) the stats
  ///    landed somewhere nothing ever reads them back from. Lost for good.
  ///
  /// So the question asked here is the one that actually matters: **is there a
  /// `users/{uid}` document?** An accountless `g_…` guest is the only kind that
  /// has none, and they are the only kind whose stats belong in `guests`.
  /// Every uid is looked up, `g_…` ids included. Filtering them out first would
  /// save a little query room, but it would make the answer depend on guessing
  /// an id's shape — and getting that guess wrong sends a real player's stats to
  /// the guest branch. A `g_` id simply has no document, which is the same
  /// answer arrived at without assuming anything.
  Future<Set<String>> _playersWithAccounts(List<MatchPlayer> players) async {
    final candidates =
        players.map((p) => p.uid).where((u) => u.isNotEmpty).toSet();
    if (candidates.isEmpty) return const <String>{};
    final users = await UserRepository.instance.getUsers(candidates);
    return users.map((u) => u.uid).toSet();
  }

  /// Compute the algorithm MOTM, fold career/team stats, record played-with,
  /// open the 24h community vote + edit window, award MOTM points and send
  /// post-match notifications. Idempotent via `awardsDone`.
  Future<void> finalizeMatch(String matchId) async {
    final matchRef = _matches.doc(matchId);
    final already = await _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(matchRef);
      if ((snap.data()?['awardsDone'] ?? false) as bool) return true;
      tx.update(matchRef, {'awardsDone': true});
      return false;
    });
    if (already) return;

    final match = await getMatch(matchId);
    if (match == null) return;
    final players = await getPlayers(matchId);
    final users = UserRepository.instance;
    final teams = TeamRepository.instance;
    final notifs = NotificationRepository.instance;
    final friends = FriendRepository.instance;

    // Resolved once, read live — see _playersWithAccounts for why the join-time
    // `isGuest` flag is not the right question here.
    final withAccounts = await _playersWithAccounts(players);
    bool hasAccount(MatchPlayer p) => earnsCareerStats(p, withAccounts);

    // Algorithm MOTM: most goals; tie → most assists; zero goals / tie → none.
    MatchPlayer? motm;
    final scorers = players.where((p) => p.goals > 0).toList();
    if (scorers.isNotEmpty) {
      scorers.sort((a, b) {
        final g = b.goals.compareTo(a.goals);
        return g != 0 ? g : b.assists.compareTo(a.assists);
      });
      final top = scorers.first;
      final tiedTop = scorers
          .where((p) => p.goals == top.goals && p.assists == top.assists)
          .length;
      if (tiedTop == 1) motm = top;
    }

    final now = DateTime.now();
    await matchRef.update({
      'motmAUid': motm?.uid,
      // Community vote is open for 6 hours after the match ends.
      'voteCloseAt': Timestamp.fromDate(now.add(const Duration(hours: 6))),
      // Admin scorecard corrections stay open longer (24h).
      'editableUntil': Timestamp.fromDate(now.add(const Duration(hours: 24))),
    });
    if (motm != null && hasAccount(motm)) {
      await users.addPoints(motm.uid, RewardsRepository.current.manOfMatchPoints);
    }

    // Career + guest stats.
    for (final p in players) {
      final result = match.resultFor(p.team);
      if (!hasAccount(p)) {
        await _guests.doc(p.uid).set({
          'goals': p.goals,
          'assists': p.assists,
          'result': result,
          'surface': match.surface,
          'format': match.format,
        }, SetOptions(merge: true));
      } else {
        await users.applyMatchStats(
          p.uid,
          goals: p.goals,
          assists: p.assists,
          result: result,
          motm: p.uid == motm?.uid,
          surface: match.surface,
          format: match.format,
        );
      }
    }

    // Saved-team stats.
    if (match.teamAId != null) {
      await teams.applyMatchStats(match.teamAId!,
          result: match.resultFor(TeamSide.a),
          goalsFor: match.scoreA,
          goalsAgainst: match.scoreB);
      if (motm?.team == TeamSide.a) {
        await teams.incrementRecognition(match.teamAId!, motm: true);
      }
    }
    if (match.teamBId != null) {
      await teams.applyMatchStats(match.teamBId!,
          result: match.resultFor(TeamSide.b),
          goalsFor: match.scoreB,
          goalsAgainst: match.scoreA);
      if (motm?.team == TeamSide.b) {
        await teams.incrementRecognition(match.teamBId!, motm: true);
      }
    }

    // Players I've played with (all pairs, both directions), registered only.
    final real = players.where(hasAccount).toList();
    for (final a in real) {
      for (final b in real) {
        if (a.uid != b.uid) {
          await friends.recordPlayedWith(a.uid, b.uid, otherName: b.name);
        }
      }
    }

    // Notifications: result to all, MOTM, vote invite, guest reminders.
    // Keyed on hasAccount, not isGuest: an auto-created player HAS a bell to
    // deliver to, and telling them to "create an account" when one already
    // exists in their name is the wrong instruction.
    for (final p in players) {
      if (!hasAccount(p)) {
        try {
          await notifs.emit(p.uid,
              title: 'Your stats are saved',
              body:
                  'You played "${match.name}". Create an account to claim them.',
              category: NotifCategory.guest,
              route: '/post-match',
              arg: matchId);
        } catch (_) {}
        continue;
      }
      final res = match.resultFor(p.team);
      await notifs.emit(p.uid,
          title: 'Match result',
          body:
              '${match.teamAName} ${match.scoreA}–${match.scoreB} ${match.teamBName} · ${res.toUpperCase()}',
          category: NotifCategory.matchResult,
          route: '/post-match',
          arg: matchId);
      await notifs.add(p.uid,
          title: 'Vote for Community Award',
          body: 'Voting closes in 6 hours.',
          category: NotifCategory.matchUpdate,
          route: '/post-match',
          arg: matchId);
    }
    if (motm != null && hasAccount(motm)) {
      await notifs.emit(motm.uid,
          title: 'Man of the Match ⭐',
          body: 'You were Man of the Match! +${RewardsRepository.current.manOfMatchPoints} points.',
          category: NotifCategory.award,
          route: '/post-match',
          arg: matchId);
    }
  }

  /// Resolve the community award once the 24h window closes. Idempotent via
  /// `communityAwarded`. Safe to call from the scorecard when now ≥ voteCloseAt.
  Future<void> resolveCommunityAward(String matchId) async {
    final ref = _matches.doc(matchId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final m = MatchModel.fromDoc(snap);
    if ((snap.data()?['communityAwarded'] ?? false) as bool) return;
    if (m.voteCloseAt == null || m.voteCloseAt!.isAfter(DateTime.now())) return;

    final guard = await _db.runTransaction<bool>((tx) async {
      final s = await tx.get(ref);
      if ((s.data()?['communityAwarded'] ?? false) as bool) return true;
      tx.update(ref, {'communityAwarded': true});
      return false;
    });
    if (guard) return;

    final votes = await _votes(matchId).get();
    if (votes.docs.isEmpty) return;
    final tally = <String, int>{};
    for (final d in votes.docs) {
      final v = (d.data()['votedUid'] ?? '') as String;
      if (v.isNotEmpty) tally[v] = (tally[v] ?? 0) + 1;
    }
    if (tally.isEmpty) return;
    final winner =
        tally.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    await ref.update({'communityPlayerUid': winner});
    final players = await getPlayers(matchId);
    MatchPlayer? wp;
    for (final p in players) {
      if (p.uid == winner) {
        wp = p;
        break;
      }
    }
    // Same live check as finalizeMatch — this runs 6 hours later, so the
    // snapshot is even staler here. Someone who claimed their account during
    // the voting window has every right to the points their team-mates voted
    // them.
    final withAccounts = await _playersWithAccounts(players);
    if (wp != null && earnsCareerStats(wp, withAccounts)) {
      await UserRepository.instance.addPoints(winner, RewardsRepository.current.communityPlayerPoints);
      await _db.collection('users').doc(winner).update({
        'communityCount': FieldValue.increment(1),
      });
      final teamId = m.teamId(wp.team);
      if (teamId != null) {
        await TeamRepository.instance
            .incrementRecognition(teamId, community: true);
      }
      await NotificationRepository.instance.emit(winner,
          title: 'Community Award 🤝',
          body:
              'Your teammates voted you best performer! +${RewardsRepository.current.communityPlayerPoints} points.',
          category: NotifCategory.award,
          route: '/post-match',
          arg: matchId);
    }
  }

  /// Back-compat shim for callers still invoking the old award entry point.
  Future<void> finalizeAwards(String matchId) => finalizeMatch(matchId);

  // ---- 24h scorecard edit ----------------------------------------------

  Future<bool> isEditable(String matchId) async {
    final m = await getMatch(matchId);
    return m?.editableUntil != null &&
        m!.editableUntil!.isAfter(DateTime.now());
  }

  /// Correct a goal's scorer/assist within the edit window (adjusts tallies).
  Future<void> correctGoal(
    String matchId,
    GoalEvent goal, {
    required MatchPlayer newScorer,
    MatchPlayer? newAssist,
  }) async {
    final batch = _db.batch();
    // Reverse old.
    batch.update(_players(matchId).doc(goal.scorerUid),
        {'goals': FieldValue.increment(-1)});
    if (goal.assistUid != null) {
      batch.update(_players(matchId).doc(goal.assistUid!),
          {'assists': FieldValue.increment(-1)});
    }
    // Apply new.
    batch.update(_players(matchId).doc(newScorer.uid),
        {'goals': FieldValue.increment(1)});
    if (newAssist != null) {
      batch.update(_players(matchId).doc(newAssist.uid),
          {'assists': FieldValue.increment(1)});
    }
    batch.update(_goals(matchId).doc(goal.id), {
      'scorerUid': newScorer.uid,
      'scorerName': newScorer.name,
      'assistUid': newAssist?.uid,
      'assistName': newAssist?.name,
    });
    await batch.commit();
  }

  Future<void> deleteGoal(String matchId, GoalEvent goal) async {
    final batch = _db.batch();
    batch.delete(_goals(matchId).doc(goal.id));
    batch.update(_players(matchId).doc(goal.scorerUid),
        {'goals': FieldValue.increment(-1)});
    if (goal.assistUid != null) {
      batch.update(_players(matchId).doc(goal.assistUid!),
          {'assists': FieldValue.increment(-1)});
    }
    batch.update(_matches.doc(matchId), {
      goal.team == TeamSide.a ? 'scoreA' : 'scoreB': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  // ---- Guest claim ------------------------------------------------------

  /// Auto-claim: fold every unclaimed guest record matching [phone]/[email]
  /// into [uid]'s career stats. Called on sign-up.
  Future<int> claimGuestStats(String uid,
      {String? phone, String? email}) async {
    final users = UserRepository.instance;
    final matches = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    if (phone != null && phone.isNotEmpty) {
      matches.addAll((await _guests
              .where('phone', isEqualTo: phone)
              .where('claimed', isEqualTo: false)
              .get())
          .docs);
    }
    if (email != null && email.isNotEmpty) {
      matches.addAll((await _guests
              .where('email', isEqualTo: email)
              .where('claimed', isEqualTo: false)
              .get())
          .docs);
    }
    var claimed = 0;
    for (final d in matches) {
      final data = d.data();
      if ((data['result'] ?? '') != '') {
        await users.applyMatchStats(
          uid,
          goals: (data['goals'] ?? 0) as int,
          assists: (data['assists'] ?? 0) as int,
          result: (data['result'] ?? 'draw') as String,
          surface: data['surface'] as String?,
          format: data['format'] as String?,
        );
      }
      await d.reference.update({'claimed': true, 'claimedBy': uid});
      claimed++;
    }
    return claimed;
  }
}
