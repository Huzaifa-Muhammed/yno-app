import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';

/// Reads/writes `users/{uid}` profile documents.
class UserRepository {
  UserRepository._();
  static final UserRepository instance = UserRepository._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Future<AppUser?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromDoc(doc);
  }

  Stream<AppUser?> watchUser(String uid) => _users.doc(uid).snapshots().map(
        (doc) => doc.exists ? AppUser.fromDoc(doc) : null,
      );

  Future<List<AppUser>> getUsers(Iterable<String> uids) async {
    final list = uids.toSet().where((u) => u.isNotEmpty).toList();
    final out = <AppUser>[];
    // whereIn is capped at 30 (recent SDKs) / 10 (older) — chunk at 10 to be safe.
    for (var i = 0; i < list.length; i += 10) {
      final chunk = list.sublist(i, (i + 10).clamp(0, list.length));
      if (chunk.isEmpty) break;
      final q =
          await _users.where(FieldPath.documentId, whereIn: chunk).get();
      out.addAll(q.docs.map(AppUser.fromDoc));
    }
    return out;
  }

  /// Real-time username availability check (case-insensitive).
  Future<bool> isUsernameAvailable(String username) async {
    final u = username.trim().toLowerCase();
    if (u.isEmpty) return false;
    final q = await _users.where('usernameLower', isEqualTo: u).limit(1).get();
    return q.docs.isEmpty;
  }

  Future<AppUser?> findByReferralCode(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return null;
    final q =
        await _users.where('referralCode', isEqualTo: trimmed).limit(1).get();
    if (q.docs.isEmpty) return null;
    return AppUser.fromDoc(q.docs.first);
  }

  /// Look up a user by exact email — used at sign-up to detect an account that
  /// already exists for this address (e.g. one auto-created when a host added
  /// the person to a match or team). `users` is world-readable, so this resolves
  /// even before the caller has signed in.
  Future<AppUser?> findByEmail(String email) async {
    final e = email.trim();
    if (e.isEmpty) return null;
    final q = await _users.where('email', isEqualTo: e).limit(1).get();
    if (q.docs.isEmpty) return null;
    return AppUser.fromDoc(q.docs.first);
  }

  /// Search users by username prefix or exact phone — for the friends "search"
  /// path and team roster search.
  Future<List<AppUser>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final results = <String, AppUser>{};
    final lower = q.toLowerCase();
    final byName = await _users
        .orderBy('usernameLower')
        .startAt([lower])
        .endAt(['$lower'])
        .limit(20)
        .get();
    for (final d in byName.docs) {
      results[d.id] = AppUser.fromDoc(d);
    }
    if (q.startsWith('+') || RegExp(r'^\d').hasMatch(q)) {
      final byPhone =
          await _users.where('phone', isEqualTo: q).limit(10).get();
      for (final d in byPhone.docs) {
        results[d.id] = AppUser.fromDoc(d);
      }
    }
    // Deactivated accounts are hidden from discovery.
    return results.values.where((u) => !u.deactivated).toList();
  }

  /// Match phone numbers against registered accounts (contact sync).
  Future<List<AppUser>> findByPhones(List<String> phones) async {
    final out = <AppUser>[];
    for (var i = 0; i < phones.length; i += 10) {
      final chunk = phones.sublist(i, (i + 10).clamp(0, phones.length));
      if (chunk.isEmpty) break;
      final q = await _users.where('phone', whereIn: chunk).get();
      out.addAll(q.docs.map(AppUser.fromDoc).where((u) => !u.deactivated));
    }
    return out;
  }

  Future<void> updateProfile(
    String uid, {
    String? name,
    String? firstName,
    String? lastName,
    String? username,
    String? position,
    String? preferredFoot,
    String? skillLevel,
    String? language,
    String? photoUrl,
    String? photoPublicId,
    String? phone,
    String? email,
    DateTime? dob,
    bool? dobLocked,
    bool? sportProfileDone,
    bool? autoCreated,
    Map<String, String>? socialLinks,
    Map<String, String>? socialVisibility,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (firstName != null) data['firstName'] = firstName;
    if (lastName != null) data['lastName'] = lastName;
    if (username != null) {
      data['username'] = username;
      data['usernameLower'] = username.toLowerCase();
    }
    if (position != null) data['position'] = position;
    if (preferredFoot != null) data['preferredFoot'] = preferredFoot;
    if (skillLevel != null) data['skillLevel'] = skillLevel;
    if (language != null) data['language'] = language;
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    if (photoPublicId != null) data['photoPublicId'] = photoPublicId;
    if (phone != null) data['phone'] = phone;
    if (email != null) data['email'] = email;
    if (dob != null) data['dob'] = Timestamp.fromDate(dob);
    if (dobLocked != null) data['dobLocked'] = dobLocked;
    if (sportProfileDone != null) data['sportProfileDone'] = sportProfileDone;
    if (autoCreated != null) data['autoCreated'] = autoCreated;
    if (socialLinks != null) data['socialLinks'] = socialLinks;
    if (socialVisibility != null) data['socialVisibility'] = socialVisibility;
    if (data.isEmpty) return;
    await _users.doc(uid).update(data);
  }

  /// Complete the football sport profile (Section 1 / sport-setup trigger).
  /// Save the sport profile. Onboarding now only asks for [position]; [foot]
  /// defaults to Right and [skill] is optional (both editable later).
  Future<void> completeSportProfile(
    String uid, {
    required String position,
    String foot = 'Right',
    String? skill,
  }) {
    final data = <String, dynamic>{
      'position': position,
      'preferredFoot': foot,
      'sportProfileDone': true,
    };
    if (skill != null && skill.isNotEmpty) data['skillLevel'] = skill;
    return _users.doc(uid).update(data);
  }

  Future<void> addPoints(String uid, int delta) =>
      _users.doc(uid).update({'points': FieldValue.increment(delta)});

  /// Temporarily deactivate the account for [days] (clamped to 1–30; the product
  /// rule is no longer than a month). Caller signs the user out afterward.
  Future<void> deactivate(String uid, {required int days}) {
    final capped = days.clamp(1, 30);
    return _users.doc(uid).update({
      'deactivated': true,
      'deactivatedAt': FieldValue.serverTimestamp(),
      'reactivateAt':
          Timestamp.fromDate(DateTime.now().add(Duration(days: capped))),
    });
  }

  /// Reactivate an account (auto on next login once the window passes, or early).
  Future<void> reactivate(String uid) => _users.doc(uid).update({
        'deactivated': false,
        'reactivateAt': null,
      });

  Future<void> updatePrefs(
    String uid, {
    bool? notifyMatchAlerts,
    bool? notifyFriendActivity,
    bool? contactSync,
    bool? profilePublic,
  }) async {
    final data = <String, dynamic>{};
    if (notifyMatchAlerts != null) data['notifyMatchAlerts'] = notifyMatchAlerts;
    if (notifyFriendActivity != null) {
      data['notifyFriendActivity'] = notifyFriendActivity;
    }
    if (contactSync != null) data['contactSync'] = contactSync;
    if (profilePublic != null) data['profilePublic'] = profilePublic;
    if (data.isEmpty) return;
    await _users.doc(uid).update(data);
  }

  /// Fold one finished match into a user's career counters. Additive stats use
  /// increment; streaks need the previous value so we read first. Call once per
  /// match per player (guarded by the match's `awardsDone` flag).
  Future<void> applyMatchStats(
    String uid, {
    required int goals,
    required int assists,
    required String result, // 'win' | 'loss' | 'draw'
    bool motm = false,
    bool community = false,
    String? surface,
    String? format,
  }) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return;
    final u = AppUser.fromDoc(doc);
    final isWin = result == 'win';
    final isLoss = result == 'loss';
    final newStreak = isWin ? u.currentStreak + 1 : 0;
    final newBest = newStreak > u.bestStreak ? newStreak : u.bestStreak;
    final newUnbeaten = isLoss ? 0 : u.unbeatenStreak + 1;
    final newBestUnbeaten =
        newUnbeaten > u.unbeatenStreak ? newUnbeaten : u.unbeatenStreak;

    final form = [...u.formLast5, isWin ? 'W' : (isLoss ? 'L' : 'D')];
    while (form.length > 5) {
      form.removeAt(0);
    }

    final surfaceKey = (surface ?? '').toLowerCase();
    final formatKey = format ?? '';
    final bySurface = Map<String, String>.from(u.goalsBySurface);
    if (goals > 0 && surfaceKey.isNotEmpty) {
      bySurface[surfaceKey] =
          ((int.tryParse(bySurface[surfaceKey] ?? '0') ?? 0) + goals).toString();
    }
    final byFormat = Map<String, String>.from(u.goalsByFormat);
    if (goals > 0 && formatKey.isNotEmpty) {
      byFormat[formatKey] =
          ((int.tryParse(byFormat[formatKey] ?? '0') ?? 0) + goals).toString();
    }

    await _users.doc(uid).update({
      'matchesPlayed': FieldValue.increment(1),
      'careerGoals': FieldValue.increment(goals),
      'careerAssists': FieldValue.increment(assists),
      if (result == 'win') 'wins': FieldValue.increment(1),
      if (result == 'loss') 'losses': FieldValue.increment(1),
      if (result == 'draw') 'draws': FieldValue.increment(1),
      if (motm) 'motmCount': FieldValue.increment(1),
      if (community) 'communityCount': FieldValue.increment(1),
      if (goals >= 3) 'hatTricks': FieldValue.increment(1),
      if (goals > u.bestScoringMatch) 'bestScoringMatch': goals,
      'currentStreak': newStreak,
      'bestStreak': newBest,
      'unbeatenStreak': newBestUnbeaten,
      'formLast5': form,
      'goalsBySurface': bySurface,
      'goalsByFormat': byFormat,
    });
  }

  // ---- Follow graph (one-way) -------------------------------------------

  Future<void> follow(String me, String target) async {
    if (me == target) return;
    final batch = _db.batch();
    batch.update(_users.doc(me), {
      'following': FieldValue.arrayUnion([target]),
    });
    batch.update(_users.doc(target), {
      'followersCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> unfollow(String me, String target) async {
    final batch = _db.batch();
    batch.update(_users.doc(me), {
      'following': FieldValue.arrayRemove([target]),
    });
    batch.update(_users.doc(target), {
      'followersCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  Future<int> countReferrals(String uid) async {
    final q = await _users.where('referredBy', isEqualTo: uid).get();
    return q.docs.length;
  }

  /// Users referred by [uid], for the referral list (name + join date).
  Future<List<AppUser>> referredUsers(String uid) async {
    final q = await _users.where('referredBy', isEqualTo: uid).get();
    final list = q.docs.map(AppUser.fromDoc).toList();
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  /// Global leaderboard by app points. Deactivated accounts are hidden
  /// (filtered client-side so no composite index is needed).
  Stream<List<AppUser>> watchTopUsers({int limit = 20}) => _users
      .orderBy('points', descending: true)
      .limit(limit + 10)
      .snapshots()
      .map((s) => s.docs
          .map(AppUser.fromDoc)
          .where((u) => !u.deactivated)
          .take(limit)
          .toList());
}
