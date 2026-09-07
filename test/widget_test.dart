// Unit tests for YNO domain logic (Firebase-free).
//
// The app root (splash) auth-gates against live Firebase, which isn't
// initialised in the bare test host, so we cover the pure model/helper logic
// here instead of booting the widget tree.
import 'package:flutter_test/flutter_test.dart';

import 'package:ynoapp/services/codes.dart';
import 'package:ynoapp/services/models.dart';

void main() {
  group('randomCode', () {
    test('has the requested length and uses the unambiguous alphabet', () {
      final code = randomCode(6);
      expect(code.length, 6);
      expect(RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]+$').hasMatch(code),
          isTrue);
    });

    test('is reasonably unique across calls', () {
      final codes = {for (var i = 0; i < 200; i++) randomCode(8)};
      expect(codes.length, greaterThan(190));
    });
  });

  group('AppUser', () {
    test('new player starts with zeroed rates', () {
      const u = AppUser(uid: 'u1', name: 'Test Player', email: 't@x.com');
      expect(u.winRate, 0);
      expect(u.goalsPerMatch, 0);
      expect(u.totalMotm, 0);
    });

    test('win rate, goals/match and contributions compute from counters', () {
      const u = AppUser(
        uid: 'u2',
        name: 'Ada Striker',
        email: 'a@x.com',
        matchesPlayed: 10,
        wins: 6,
        careerGoals: 15,
        careerAssists: 5,
        motmCount: 2,
        communityCount: 1,
      );
      expect(u.winRate, 60);
      expect(u.goalsPerMatch, closeTo(1.5, 0.001));
      expect(u.goalContributions, 20);
      expect(u.totalMotm, 3);
    });

    test('initials and handle fall back sensibly', () {
      const u = AppUser(
          uid: 'u3', name: 'Lionel Messi', email: 'l@x.com', username: 'leo10');
      expect(u.initials, 'LM');
      expect(u.handle, 'leo10');
    });
  });

  group('MatchModel.resultFor', () {
    MatchModel m({required int a, required int b, String? winner}) => MatchModel(
          id: 'm',
          code: 'ABC123',
          adminUid: 'admin',
          teamAName: 'A',
          teamBName: 'B',
          durationMin: 60,
          status: MatchStatus.ended,
          scoreA: a,
          scoreB: b,
          winnerSide: winner,
        );

    test('decides win/loss by score', () {
      final match = m(a: 3, b: 1);
      expect(match.isLevel, isFalse);
      expect(match.resultFor(TeamSide.a), 'win');
      expect(match.resultFor(TeamSide.b), 'loss');
    });

    test('level score with no winner is a draw both sides', () {
      final match = m(a: 2, b: 2);
      expect(match.isLevel, isTrue);
      expect(match.resultFor(TeamSide.a), 'draw');
      expect(match.resultFor(TeamSide.b), 'draw');
    });

    test('level score decided by penalties/golden goal honours winnerSide', () {
      final match = m(a: 2, b: 2, winner: 'B');
      expect(match.resultFor(TeamSide.a), 'loss');
      expect(match.resultFor(TeamSide.b), 'win');
    });
  });

  group('MatchModel team challenges', () {
    MatchModel m({String? status, String? teamBId}) => MatchModel(
          id: 'm',
          code: 'ABC123',
          adminUid: 'admin',
          teamAName: 'Rovers',
          teamBName: 'Wolves',
          durationMin: 60,
          status: MatchStatus.lobby,
          teamBId: teamBId,
          challengedTeamId: teamBId,
          challengedTeamName: teamBId == null ? null : 'Wolves',
          challengeCaptainUid: teamBId == null ? null : 'cap1',
          challengeStatus: status,
        );

    test('a match with no challenge is neither pending nor accepted', () {
      final match = m();
      expect(match.challengePending, isFalse);
      expect(match.challengeAccepted, isFalse);
      expect(match.challengeCaptainUid, isNull);
    });

    test('a pending challenge holds side B for the challenged team', () {
      final match = m(status: 'pending', teamBId: 't2');
      expect(match.challengePending, isTrue);
      expect(match.challengeAccepted, isFalse);
      expect(match.teamId(TeamSide.b), 't2');
      expect(match.challengeCaptainUid, 'cap1');
    });

    test('accepted and declined are both no longer pending', () {
      expect(m(status: 'accepted', teamBId: 't2').challengePending, isFalse);
      expect(m(status: 'accepted', teamBId: 't2').challengeAccepted, isTrue);
      expect(m(status: 'declined', teamBId: 't2').challengePending, isFalse);
      expect(m(status: 'declined', teamBId: 't2').challengeAccepted, isFalse);
    });
  });

  // ---- Who earns career stats -------------------------------------------
  //
  // 🔑 The rule that decides whether a match counts towards someone's career.
  // It is NOT `!player.isGuest`, and these tests exist so that it does not
  // quietly become that again. The flag is a join-time snapshot, and reading it
  // here failed in both directions: it stripped claimed accounts of their
  // stats, and it wrote everyone else's into `guests/{uid}` documents that
  // `claimGuestStats` — which finds them by email — can never match.
  group('earnsCareerStats', () {
    MatchPlayer p(String uid, {bool isGuest = false}) => MatchPlayer(
          uid: uid,
          name: 'Player',
          team: TeamSide.a,
          isGuest: isGuest,
        );

    test('a normal registered player earns them', () {
      expect(earnsCareerStats(p('u1'), {'u1', 'u2'}), isTrue);
    });

    test('an accountless g_ guest does not — their stats go to guests/', () {
      expect(
          earnsCareerStats(p('g_ABCDEFGHJK', isGuest: true), {'u1'}), isFalse);
    });

    test('a player flagged isGuest still earns them once an account exists', () {
      // The fix, in one assertion. An auto-created player — added by email in
      // the app, or joined from the website — carries isGuest: true so the
      // lobby shows them as a guest, but they have a real users/{uid}
      // document, and that is where their stats belong.
      expect(earnsCareerStats(p('u_auto', isGuest: true), {'u_auto'}), isTrue);
    });

    test('a player NOT flagged isGuest earns nothing without an account', () {
      // The mirror case: the snapshot said "real player", but the account is
      // gone by the final whistle. Trusting the flag would send career stats to
      // a document that no longer exists.
      expect(earnsCareerStats(p('u_deleted'), {'u1'}), isFalse);
    });

    test('the join-time flag never changes the answer, either way', () {
      for (final uid in ['u1', 'u_missing']) {
        expect(
          earnsCareerStats(p(uid, isGuest: true), {'u1'}),
          earnsCareerStats(p(uid, isGuest: false), {'u1'}),
          reason: 'isGuest must not influence the answer for $uid',
        );
      }
    });

    test('an empty uid is nobody', () {
      expect(earnsCareerStats(p(''), {''}), isFalse);
    });

    test('an empty account set means nobody earns anything', () {
      expect(earnsCareerStats(p('u1'), const <String>{}), isFalse);
    });
  });
}
