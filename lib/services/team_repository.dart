import 'package:cloud_firestore/cloud_firestore.dart';

import 'codes.dart';
import 'models.dart';
import 'notification_repository.dart';

/// Persistent teams (`teams/{id}`) — roles, invites, discovery, stats.
class TeamRepository {
  TeamRepository._();
  static final TeamRepository instance = TeamRepository._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _teams =>
      _db.collection('teams');
  CollectionReference<Map<String, dynamic>> _invites(String id) =>
      _teams.doc(id).collection('invites');

  /// Manager-read-only side doc holding the team's invite code. Kept off the
  /// team doc because team docs are world-readable.
  DocumentReference<Map<String, dynamic>> _private(String id) =>
      _teams.doc(id).collection('private').doc('meta');

  /// Code → team lookup, keyed BY the code. Rules allow `get` but deny `list`,
  /// so possessing a code resolves it while nobody can enumerate all codes.
  DocumentReference<Map<String, dynamic>> _code(String code) =>
      _db.collection('teamCodes').doc(code.trim().toUpperCase());

  /// Team-name uniqueness (case-insensitive). Pass [exceptTeamId] when renaming
  /// an existing team so its own current name doesn't count as a collision.
  Future<bool> isNameAvailable(String name, {String? exceptTeamId}) async {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return false;
    final q = await _teams.where('nameLower', isEqualTo: n).limit(2).get();
    return q.docs.every((d) => d.id == exceptTeamId);
  }

  Future<TeamModel> createTeam({
    required String name,
    required String ownerUid,
    String? badgeUrl,
    String? badgePublicId,
    String? presetBadge,
    bool isPublic = false,
  }) async {
    final ref = _teams.doc();
    await ref.set({
      'name': name.trim(),
      'nameLower': name.trim().toLowerCase(),
      'ownerUid': ownerUid,
      'badgeUrl': badgeUrl,
      'badgePublicId': badgePublicId,
      'presetBadge': presetBadge,
      'isPublic': isPublic,
      // The creator is both owner and captain to start with; they can hand
      // captaincy to another member later. `roleOf` checks ownerUid first, so
      // the owner still renders as OWNER despite captainUid pointing at them.
      'captainUid': ownerUid,
      'viceCaptainUids': <String>[],
      'memberUids': [ownerUid],
      'roles': {ownerUid: TeamRole.owner.id},
      'disbanded': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // After the team doc exists — the rules on both writes below resolve the
    // caller's manage rights by reading it.
    await _writeInviteCode(ref.id, randomCode(6));
    return TeamModel.fromDoc(await ref.get());
  }

  // ---- Invite code ------------------------------------------------------

  /// Point [code] at [teamId] and record it as the team's current code.
  Future<void> _writeInviteCode(String teamId, String code) async {
    await _code(code).set({
      'teamId': teamId,
      'at': FieldValue.serverTimestamp(),
    });
    await _private(teamId).set({'inviteCode': code});
  }

  /// The team's current invite code — managers only (the rules deny everyone
  /// else, so this stream errors rather than leaks for a non-manager).
  Stream<String?> watchInviteCode(String teamId) => _private(teamId)
      .snapshots()
      .map((d) => d.data()?['inviteCode'] as String?);

  /// Mint a code for a team that has none (teams created before the code moved
  /// off the team doc). No-op when one already exists. Returns the live code.
  Future<String?> ensureInviteCode(String teamId) async {
    final existing = (await _private(teamId).get()).data()?['inviteCode'];
    if (existing is String && existing.isNotEmpty) return existing;
    final code = randomCode(6);
    await _writeInviteCode(teamId, code);
    return code;
  }

  Stream<List<TeamModel>> watchUserTeams(String uid) => _teams
      .where('memberUids', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs
          .map(TeamModel.fromDoc)
          .where((t) => !t.disbanded)
          .toList());

  /// Teams the user owns that are disbanded but still restorable.
  Stream<List<TeamModel>> watchDeletedTeams(String uid) => _teams
      .where('ownerUid', isEqualTo: uid)
      .where('disbanded', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(TeamModel.fromDoc).toList());

  Stream<TeamModel?> watchTeam(String id) => _teams
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? TeamModel.fromDoc(d) : null);

  Future<TeamModel?> getTeam(String id) async {
    final d = await _teams.doc(id).get();
    return d.exists ? TeamModel.fromDoc(d) : null;
  }

  /// Public-team discovery search by name prefix.
  Future<List<TeamModel>> discover(String query) async {
    final q = query.trim().toLowerCase();
    final base = _teams.where('isPublic', isEqualTo: true);
    final snap = q.isEmpty
        ? await base.limit(30).get()
        : await base
            .orderBy('nameLower')
            .startAt([q]).endAt(['$q']).limit(30).get();
    return snap.docs
        .map(TeamModel.fromDoc)
        .where((t) => !t.disbanded)
        .toList();
  }

  /// Resolve a code someone gave you. A single doc `get` keyed by the code —
  /// never a query, so codes stay unenumerable.
  Future<TeamModel?> findByInviteCode(String code) async {
    final snap = await _code(code).get();
    final teamId = snap.data()?['teamId'] as String?;
    if (teamId == null) return null;
    return getTeam(teamId);
  }

  /// Edit a team's identity (name / badge). Only the fields passed are written,
  /// so callers can change the badge without touching the name and vice versa.
  /// Caller must check [isNameAvailable] first when renaming.
  Future<void> updateTeam(
    String teamId, {
    String? name,
    String? presetBadge,
    String? badgeUrl,
    String? badgePublicId,
  }) {
    final trimmed = name?.trim();
    return _teams.doc(teamId).update({
      if (trimmed != null && trimmed.isNotEmpty) ...{
        'name': trimmed,
        'nameLower': trimmed.toLowerCase(),
      },
      if (presetBadge != null) 'presetBadge': presetBadge,
      if (badgeUrl != null) 'badgeUrl': badgeUrl,
      if (badgePublicId != null) 'badgePublicId': badgePublicId,
    });
  }

  Future<void> setPrivacy(String teamId, bool isPublic) =>
      _teams.doc(teamId).update({'isPublic': isPublic});

  /// Retire the current code and mint a new one. Any code a friend is still
  /// holding — to join OR to challenge — stops resolving.
  Future<void> regenerateInviteCode(String teamId) async {
    final old = (await _private(teamId).get()).data()?['inviteCode'];
    await _writeInviteCode(teamId, randomCode(6));
    if (old is String && old.isNotEmpty) {
      try {
        await _code(old).delete();
      } catch (_) {/* the new code is already live — best-effort cleanup */}
    }
  }

  // ---- Roles ------------------------------------------------------------

  Future<void> assignCaptain(String teamId, String uid) async {
    final t = await getTeam(teamId);
    if (t == null) return;
    final roles = Map<String, String>.from(t.roles);
    // Demote any previous captain to player.
    if (t.captainUid != null) roles[t.captainUid!] = TeamRole.player.id;
    roles[uid] = TeamRole.captain.id;
    await _teams.doc(teamId).update({
      'captainUid': uid,
      'viceCaptainUids': FieldValue.arrayRemove([uid]),
      'roles': roles,
    });
  }

  /// Set the ordered vice-captain list (index 0 = priority 1, max 4).
  Future<void> setViceCaptains(String teamId, List<String> uids) async {
    final t = await getTeam(teamId);
    if (t == null) return;
    final capped = uids.take(4).toList();
    final roles = Map<String, String>.from(t.roles);
    for (final v in t.viceCaptainUids) {
      if (!capped.contains(v)) roles[v] = TeamRole.player.id;
    }
    for (final v in capped) {
      roles[v] = TeamRole.vice.id;
    }
    await _teams.doc(teamId).update({
      'viceCaptainUids': capped,
      'roles': roles,
    });
  }

  // ---- Members & invites ------------------------------------------------

  Stream<List<TeamInvite>> watchInvites(String teamId) => _invites(teamId)
      .orderBy('at', descending: true)
      .snapshots()
      .map((s) => s.docs.map(TeamInvite.fromDoc).toList());

  // ---- Join requests (a player asking to join) ----------------------------
  //
  // The mirror image of an invite: the team asks a player with [inviteMember],
  // a player asks the team with [requestToJoin]. Both land in a subcollection
  // the managers act on, so a public team is reachable without a code — you
  // could previously *view* a team and have no way in at all.

  CollectionReference<Map<String, dynamic>> _joinRequests(String teamId) =>
      _teams.doc(teamId).collection('joinRequests');

  Stream<List<TeamInvite>> watchJoinRequests(String teamId) =>
      _joinRequests(teamId)
          .orderBy('at', descending: true)
          .snapshots()
          .map((s) => s.docs.map(TeamInvite.fromDoc).toList());

  /// Whether this user has a request pending on this team (drives the button
  /// state on the team profile).
  Stream<bool> watchMyJoinRequest(String teamId, String uid) =>
      _joinRequests(teamId).doc(uid).snapshots().map((d) => d.exists);

  /// Ask to join. Notifies the owner **and** the captain — whoever gets there
  /// first approves it, exactly like a match challenge.
  Future<void> requestToJoin(
    String teamId, {
    required String uid,
    required String name,
  }) async {
    final t = await getTeam(teamId);
    if (t == null) return;
    if (t.memberUids.contains(uid)) return;
    await _joinRequests(teamId).doc(uid).set({
      'name': name,
      'at': FieldValue.serverTimestamp(),
    });
    final recipients = <String>{t.ownerUid, if (t.captainUid != null) t.captainUid!};
    for (final r in recipients) {
      await NotificationRepository.instance.emit(
        r,
        title: 'Join request',
        body: '$name asked to join "${t.name}".',
        category: NotifCategory.teamUpdate,
        route: '/team-manage',
        arg: teamId,
      );
    }
  }

  /// Manager approves — the requester becomes a full member.
  Future<void> approveJoinRequest(String teamId, String uid) async {
    await addMember(teamId, uid);
    await _joinRequests(teamId).doc(uid).delete();
    final t = await getTeam(teamId);
    if (t != null) {
      await NotificationRepository.instance.emit(
        uid,
        title: 'Request accepted',
        body: 'You are now a member of "${t.name}".',
        category: NotifCategory.teamUpdate,
        route: '/team-profile',
        arg: teamId,
      );
    }
  }

  /// Manager declines, or the requester withdraws (same call, no notification
  /// when they cancel their own).
  Future<void> declineJoinRequest(String teamId, String uid,
      {bool notify = true}) async {
    await _joinRequests(teamId).doc(uid).delete();
    if (!notify) return;
    final t = await getTeam(teamId);
    if (t != null) {
      await NotificationRepository.instance.add(
        uid,
        title: 'Request declined',
        body: 'Your request to join "${t.name}" was declined.',
        category: NotifCategory.teamUpdate,
      );
    }
  }

  /// Invite an existing user — creates a 7-day pending invite + notification.
  Future<void> inviteMember(
    String teamId, {
    required String uid,
    required String name,
    required String teamName,
  }) async {
    await _invites(teamId).doc(uid).set({
      'name': name,
      'at': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7))),
    });
    await NotificationRepository.instance.emit(
      uid,
      title: 'Team invite',
      body: 'You were invited to join "$teamName".',
      category: NotifCategory.teamInvite,
      route: '/team-profile',
      arg: teamId,
    );
  }

  Future<void> acceptInvite(String teamId, String uid) async {
    final t = await getTeam(teamId);
    if (t == null) return;
    final roles = Map<String, String>.from(t.roles)..[uid] = TeamRole.player.id;
    await _teams.doc(teamId).update({
      'memberUids': FieldValue.arrayUnion([uid]),
      'roles': roles,
    });
    await _invites(teamId).doc(uid).delete();
    await NotificationRepository.instance.emit(
      t.ownerUid,
      title: 'Invite accepted',
      body: 'A player joined "${t.name}".',
      category: NotifCategory.teamUpdate,
      route: '/team-profile',
      arg: teamId,
    );
  }

  Future<void> declineInvite(String teamId, String uid) async {
    await _invites(teamId).doc(uid).delete();
    final t = await getTeam(teamId);
    if (t != null) {
      await NotificationRepository.instance.add(
        t.ownerUid,
        title: 'Invite declined',
        body: 'A player declined your invite to "${t.name}".',
        category: NotifCategory.teamUpdate,
      );
    }
  }

  /// Add a guest (not-yet-registered) player to the roster.
  Future<void> addGuest(String teamId, {required String name}) =>
      _teams.doc(teamId).collection('guests').add({
        'name': name,
        'at': FieldValue.serverTimestamp(),
      });

  Stream<List<String>> watchGuests(String teamId) => _teams
      .doc(teamId)
      .collection('guests')
      .snapshots()
      .map((s) => s.docs.map((d) => (d.data()['name'] ?? '') as String).toList());

  Future<void> addMember(String teamId, String uid) async {
    final t = await getTeam(teamId);
    final roles = Map<String, String>.from(t?.roles ?? {})
      ..[uid] = TeamRole.player.id;
    await _teams.doc(teamId).update({
      'memberUids': FieldValue.arrayUnion([uid]),
      'roles': roles,
    });
  }

  Future<void> removeMember(String teamId, String uid) async {
    final t = await getTeam(teamId);
    final roles = Map<String, String>.from(t?.roles ?? {})..remove(uid);
    await _teams.doc(teamId).update({
      'memberUids': FieldValue.arrayRemove([uid]),
      'viceCaptainUids': FieldValue.arrayRemove([uid]),
      'roles': roles,
      if (t?.captainUid == uid) 'captainUid': null,
    });
    if (t != null) {
      await NotificationRepository.instance.add(
        t.ownerUid,
        title: 'Player left',
        body: 'A player left "${t.name}".',
        category: NotifCategory.teamUpdate,
      );
    }
  }

  // ---- Disband / restore ------------------------------------------------

  Future<void> disband(String teamId) => _teams.doc(teamId).update({
        'disbanded': true,
        'disbandedAt': FieldValue.serverTimestamp(),
      });

  Future<void> restore(String teamId) => _teams.doc(teamId).update({
        'disbanded': false,
        'disbandedAt': null,
      });

  // ---- Stats ------------------------------------------------------------

  /// Fold one finished match into a saved team's stats. Called once per match
  /// (guarded by the match's `awardsDone` flag).
  Future<void> applyMatchStats(
    String teamId, {
    required String result, // 'win' | 'loss' | 'draw'
    required int goalsFor,
    required int goalsAgainst,
  }) async {
    final t = await getTeam(teamId);
    if (t == null) return;
    final isWin = result == 'win';
    final isLoss = result == 'loss';
    final newStreak = isWin ? t.currentStreak + 1 : 0;
    final newBest = newStreak > t.bestStreak ? newStreak : t.bestStreak;
    final newUnbeaten = isLoss ? 0 : t.unbeatenStreak + 1;
    final form = [...t.formLast10, isWin ? 'W' : (isLoss ? 'L' : 'D')];
    while (form.length > 10) {
      form.removeAt(0);
    }
    await _teams.doc(teamId).update({
      'matchesPlayed': FieldValue.increment(1),
      'goalsFor': FieldValue.increment(goalsFor),
      'goalsAgainst': FieldValue.increment(goalsAgainst),
      if (goalsAgainst == 0) 'cleanSheets': FieldValue.increment(1),
      if (result == 'win') 'wins': FieldValue.increment(1),
      if (result == 'loss') 'losses': FieldValue.increment(1),
      if (result == 'draw') 'draws': FieldValue.increment(1),
      'currentStreak': newStreak,
      'bestStreak': newBest,
      'unbeatenStreak':
          newUnbeaten > t.unbeatenStreak ? newUnbeaten : t.unbeatenStreak,
      'formLast10': form,
    });
  }

  Future<void> incrementRecognition(
    String teamId, {
    bool motm = false,
    bool community = false,
  }) =>
      _teams.doc(teamId).update({
        if (motm) 'teamMotm': FieldValue.increment(1),
        if (community) 'teamCommunity': FieldValue.increment(1),
      });
}
