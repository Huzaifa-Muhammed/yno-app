import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/models.dart';

/// Outcome of a delete operation. Instead of silently swallowing failures (which
/// makes a permission-denied wipe look successful), every delete records how
/// many docs went and how many failed, plus the first error seen — so the UI can
/// report the truth.
class DeleteResult {
  int deleted = 0;
  int failed = 0;
  String? firstError;

  void _ok() => deleted++;
  void _fail(Object e) {
    failed++;
    firstError ??= e.toString();
  }

  bool get allOk => failed == 0;

  String summary() {
    if (deleted == 0 && failed == 0) return 'Nothing to delete.';
    if (failed == 0) return 'Deleted $deleted.';
    return 'Deleted $deleted · FAILED $failed'
        '${firstError != null ? ' · $firstError' : ''}';
  }
}

/// Data access for the super-admin web dashboard: read every user/team and
/// delete users, teams, or the whole database. All deletes run client-side, so
/// they depend on the caller being signed in as a super-admin (see
/// admin_config.dart / admin_app.dart) AND on the matching `isSuperAdmin()`
/// allowance in `firestore.rules` being deployed.
///
/// Note: the Firebase client SDK cannot delete another user's Auth login — only
/// their Firestore data.
class AdminRepository {
  AdminRepository._();
  static final AdminRepository instance = AdminRepository._();

  final _db = FirebaseFirestore.instance;

  // ---- Reads ------------------------------------------------------------

  Stream<List<AppUser>> watchUsers() => _db
      .collection('users')
      .snapshots()
      .map((s) => s.docs.map(AppUser.fromDoc).toList());

  Stream<List<TeamModel>> watchTeams() => _db
      .collection('teams')
      .snapshots()
      .map((s) => s.docs.map(TeamModel.fromDoc).toList());

  Stream<List<MatchModel>> watchMatches() => _db
      .collection('matches')
      .snapshots()
      .map((s) => s.docs.map(MatchModel.fromDoc).toList());

  /// Live document counts for the summary bar. Reads from the server so it
  /// reflects the true state, not a local cache.
  Future<Map<String, int>> counts() async {
    Future<int> count(String c) async {
      try {
        final agg =
            await _db.collection(c).count().get(source: AggregateSource.server);
        return agg.count ?? 0;
      } catch (_) {
        return (await _db.collection(c).get()).size;
      }
    }

    final results = await Future.wait([
      count('users'),
      count('teams'),
      count('matches'),
      count('guests'),
      count('friendships'),
    ]);
    return {
      'users': results[0],
      'teams': results[1],
      'matches': results[2],
      'guests': results[3],
      'friendships': results[4],
    };
  }

  // ---- Delete helpers ---------------------------------------------------

  /// Delete every document returned by [q], recording successes and failures
  /// into [r]. Reads from the server so a stale cache can't hide live docs.
  Future<void> _wipe(Query<Map<String, dynamic>> q, DeleteResult r) async {
    try {
      final snap = await q.get(const GetOptions(source: Source.server));
      for (final d in snap.docs) {
        try {
          await d.reference.delete();
          r._ok();
        } catch (e) {
          r._fail(e);
        }
      }
    } catch (e) {
      // The query itself was denied (e.g. list not allowed) — record it.
      r._fail(e);
    }
  }

  // ---- Single deletes ---------------------------------------------------

  /// Delete a user's profile doc and its subcollections.
  Future<DeleteResult> deleteUser(String uid) async {
    final r = DeleteResult();
    final ref = _db.collection('users').doc(uid);
    await _wipe(ref.collection('notifications'), r);
    await _wipe(ref.collection('playedWith'), r);
    try {
      await ref.delete();
      r._ok();
    } catch (e) {
      r._fail(e);
    }
    return r;
  }

  /// Delete a team, its subcollections, and its `teamCodes` entry.
  Future<DeleteResult> deleteTeam(String teamId) async {
    final r = DeleteResult();
    final ref = _db.collection('teams').doc(teamId);
    await _wipe(ref.collection('private'), r);
    await _wipe(ref.collection('invites'), r);
    await _wipe(ref.collection('guests'), r);
    try {
      await ref.delete();
      r._ok();
    } catch (e) {
      r._fail(e);
    }
    await _wipe(
        _db.collection('teamCodes').where('teamId', isEqualTo: teamId), r);
    return r;
  }

  /// Delete a single match (and its subcollections) — used by the Matches tab.
  Future<DeleteResult> deleteMatch(String matchId) async {
    final r = DeleteResult();
    await _deleteMatch(matchId, r);
    return r;
  }

  /// Delete a single match and its subcollections.
  Future<void> _deleteMatch(String matchId, DeleteResult r) async {
    final ref = _db.collection('matches').doc(matchId);
    for (final sub in const [
      'players',
      'pending',
      'goals',
      'cards',
      'subs',
      'votes',
      'ratings',
    ]) {
      await _wipe(ref.collection(sub), r);
    }
    try {
      await ref.delete();
      r._ok();
    } catch (e) {
      r._fail(e);
    }
  }

  // ---- Bulk deletes -----------------------------------------------------

  Future<DeleteResult> deleteAllUsers([DeleteResult? into]) async {
    final r = into ?? DeleteResult();
    final snap =
        await _db.collection('users').get(const GetOptions(source: Source.server));
    for (final d in snap.docs) {
      final sub = await deleteUser(d.id);
      r.deleted += sub.deleted;
      r.failed += sub.failed;
      r.firstError ??= sub.firstError;
    }
    return r;
  }

  Future<DeleteResult> deleteAllTeams([DeleteResult? into]) async {
    final r = into ?? DeleteResult();
    final snap =
        await _db.collection('teams').get(const GetOptions(source: Source.server));
    for (final d in snap.docs) {
      final sub = await deleteTeam(d.id);
      r.deleted += sub.deleted;
      r.failed += sub.failed;
      r.firstError ??= sub.firstError;
    }
    // Sweep any stray codes left behind.
    await _wipe(_db.collection('teamCodes'), r);
    return r;
  }

  Future<DeleteResult> deleteAllMatches([DeleteResult? into]) async {
    final r = into ?? DeleteResult();
    final snap = await _db
        .collection('matches')
        .get(const GetOptions(source: Source.server));
    for (final d in snap.docs) {
      await _deleteMatch(d.id, r);
    }
    return r;
  }

  /// Wipe the entire app database. Continues through every section even if one
  /// fails, and returns a combined result so the UI can report what actually
  /// happened.
  Future<DeleteResult> deleteAllData() async {
    final r = DeleteResult();
    await deleteAllUsers(r);
    await deleteAllTeams(r);
    await deleteAllMatches(r);
    await _wipe(_db.collection('guests'), r);
    await _wipe(_db.collection('friendships'), r);
    await _wipe(_db.collection('rivalries'), r);
    return r;
  }
}
