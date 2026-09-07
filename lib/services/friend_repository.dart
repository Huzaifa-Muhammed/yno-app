import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';
import 'notification_repository.dart';
import 'user_repository.dart';

/// Two-way friendships + rival-team edges + "players I've played with".
class FriendRepository {
  FriendRepository._();
  static final FriendRepository instance = FriendRepository._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _friendships =>
      _db.collection('friendships');
  CollectionReference<Map<String, dynamic>> get _rivalries =>
      _db.collection('rivalries');

  String _pairId(String a, String b) =>
      (a.compareTo(b) < 0) ? '${a}_$b' : '${b}_$a';

  // ---- Friends ----------------------------------------------------------

  Stream<FriendEdge?> watchFriendship(String me, String other) => _friendships
      .doc(_pairId(me, other))
      .snapshots()
      .map((d) => d.exists ? FriendEdge.fromDoc(d) : null);

  Future<FriendEdge?> getFriendship(String me, String other) async {
    final d = await _friendships.doc(_pairId(me, other)).get();
    return d.exists ? FriendEdge.fromDoc(d) : null;
  }

  /// All edges touching me (accepted friends + incoming/outgoing requests).
  Stream<List<FriendEdge>> watchMyEdges(String me) => _friendships
      .where('users', arrayContains: me)
      .snapshots()
      .map((s) => s.docs.map(FriendEdge.fromDoc).toList());

  /// Send (or silently re-send) a friend request. [silent] suppresses the
  /// push until later (lobby pre-match case).
  Future<void> sendRequest(
    String me,
    String target, {
    required String myName,
    bool silent = false,
  }) async {
    if (me == target) return;
    final id = _pairId(me, target);
    final existing = await _friendships.doc(id).get();
    if (existing.exists) return;
    await _friendships.doc(id).set({
      'users': [me, target],
      'requester': me,
      'status': 'pending',
      'at': FieldValue.serverTimestamp(),
    });
    if (!silent) {
      await NotificationRepository.instance.emit(
        target,
        title: 'Friend request',
        body: '$myName sent you a friend request.',
        category: NotifCategory.friend,
        route: '/friends',
        // Who asked — lets the notification itself offer Accept / Decline,
        // which is now the main way requests get answered.
        arg: me,
      );
    }
  }

  Future<void> acceptRequest(String me, String other,
      {required String myName}) async {
    await _friendships.doc(_pairId(me, other)).update({'status': 'accepted'});
    await NotificationRepository.instance.emit(
      other,
      title: 'Friend request accepted',
      body: '$myName accepted your friend request.',
      category: NotifCategory.friend,
      route: '/profile-public',
      arg: me,
    );
  }

  Future<void> removeOrDecline(String me, String other) =>
      _friendships.doc(_pairId(me, other)).delete();

  /// Accepted friends' uids.
  Future<List<String>> friendUids(String me) async {
    final q = await _friendships
        .where('users', arrayContains: me)
        .where('status', isEqualTo: 'accepted')
        .get();
    return q.docs
        .map((d) => FriendEdge.fromDoc(d).other(me))
        .where((u) => u.isNotEmpty)
        .toList();
  }

  /// Friends leaderboard, ranked by a chosen [stat]. Includes me.
  /// [stat] ∈ goals | matches | winRate | motm.
  Future<List<AppUser>> friendsLeaderboard(String me,
      {String stat = 'goals'}) async {
    final uids = await friendUids(me);
    uids.add(me);
    final users = await UserRepository.instance.getUsers(uids);
    int key(AppUser u) => switch (stat) {
          'matches' => u.matchesPlayed,
          'winRate' => u.winRate,
          'motm' => u.totalMotm,
          _ => u.careerGoals,
        };
    users.sort((a, b) => key(b).compareTo(key(a)));
    return users;
  }

  // ---- Rival teams ------------------------------------------------------

  Stream<RivalEdge?> watchRivalry(String teamA, String teamB) => _rivalries
      .doc(_pairId(teamA, teamB))
      .snapshots()
      .map((d) => d.exists ? RivalEdge.fromDoc(d) : null);

  Stream<List<RivalEdge>> watchTeamRivalries(String teamId) => _rivalries
      .where('teams', arrayContains: teamId)
      .snapshots()
      .map((s) => s.docs.map(RivalEdge.fromDoc).toList());

  Future<void> requestRival(String fromTeam, String toTeam) async {
    final id = _pairId(fromTeam, toTeam);
    if ((await _rivalries.doc(id).get()).exists) return;
    await _rivalries.doc(id).set({
      'teams': [fromTeam, toTeam],
      'requester': fromTeam,
      'status': 'pending',
      'at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptRival(String teamA, String teamB) =>
      _rivalries.doc(_pairId(teamA, teamB)).update({'status': 'accepted'});

  Future<void> removeRival(String teamA, String teamB) =>
      _rivalries.doc(_pairId(teamA, teamB)).delete();

  // ---- Players I've played with -----------------------------------------

  CollectionReference<Map<String, dynamic>> _playedWith(String uid) =>
      _db.collection('users').doc(uid).collection('playedWith');

  /// Record that [me] shared a pitch with [other] (called post-match, both
  /// directions). Bumps a counter + last-played timestamp. Best-effort.
  Future<void> recordPlayedWith(
    String me,
    String other, {
    required String otherName,
  }) async {
    if (me == other || other.isEmpty) return;
    await _playedWith(me).doc(other).set({
      'name': otherName,
      'count': FieldValue.increment(1),
      'lastAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<PlayedWith>> watchPlayedWith(String uid) => _playedWith(uid)
      .orderBy('lastAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(PlayedWith.fromDoc).toList());
}

/// A "played with" entry (`users/{uid}/playedWith/{otherUid}`).
class PlayedWith {
  const PlayedWith({
    required this.uid,
    required this.name,
    required this.count,
  });
  final String uid;
  final String name;
  final int count;

  factory PlayedWith.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return PlayedWith(
      uid: doc.id,
      name: (d['name'] ?? '') as String,
      count: (d['count'] ?? 0) as int,
    );
  }
}
