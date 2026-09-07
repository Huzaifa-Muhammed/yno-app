// Firebase-free unit tests for the match roster/logging permission rules
// (Section 6). These back the "own-team-only" lobby management and the
// "creator-only" live logging rules, so the convention is machine-checked,
// not just enforced inline in the screens.
import 'package:flutter_test/flutter_test.dart';

import 'package:ynoapp/services/models.dart';

/// A match created by `alpha` (Team A), challenged by `beta`'s club (Team B,
/// captain confirmed). `alpha` is Team A's captain; `beta` is Team B's captain.
MatchModel _challengeMatch() => const MatchModel(
      id: 'm1',
      code: 'ABC123',
      adminUid: 'alpha',
      teamAName: 'Rovers',
      teamBName: 'Wanderers',
      durationMin: 60,
      status: MatchStatus.lobby,
      captainAUid: 'alpha',
      captainBUid: 'beta',
    );

/// A casual pickup created by `alpha`, no captain on Team B yet.
MatchModel _casualMatch() => const MatchModel(
      id: 'm2',
      code: 'XYZ789',
      adminUid: 'alpha',
      teamAName: 'Team A',
      teamBName: 'Team B',
      durationMin: 60,
      status: MatchStatus.lobby,
      captainAUid: 'alpha',
    );

void main() {
  group('canManageSide (own-team-only)', () {
    test('creator manages their own Team A', () {
      expect(_challengeMatch().canManageSide('alpha', TeamSide.a), isTrue);
    });

    test('creator CANNOT touch a challenged Team B that has a captain', () {
      expect(_challengeMatch().canManageSide('alpha', TeamSide.b), isFalse);
    });

    test('opposing captain manages their own Team B', () {
      expect(_challengeMatch().canManageSide('beta', TeamSide.b), isTrue);
    });

    test('opposing captain CANNOT touch Team A', () {
      expect(_challengeMatch().canManageSide('beta', TeamSide.a), isFalse);
    });

    test('creator CAN run Team B while it has no captain (casual)', () {
      expect(_casualMatch().canManageSide('alpha', TeamSide.b), isTrue);
    });

    test('a random player manages nothing; null uid manages nothing', () {
      final m = _challengeMatch();
      expect(m.canManageSide('random', TeamSide.a), isFalse);
      expect(m.canManageSide('random', TeamSide.b), isFalse);
      expect(m.canManageSide(null, TeamSide.a), isFalse);
    });
  });

  group('canLogLive (match creator only)', () {
    test('the creator can log', () {
      expect(_challengeMatch().canLogLive('alpha'), isTrue);
    });

    test('an opposing captain CANNOT log, even for their own team', () {
      // `beta` is Team B's confirmed captain and runs that roster in the
      // lobby — logging the match is still the creator's alone.
      final m = _challengeMatch();
      expect(m.canManageSide('beta', TeamSide.b), isTrue);
      expect(m.canLogLive('beta'), isFalse);
    });

    test('a plain player cannot log; null uid cannot log', () {
      final m = _challengeMatch();
      expect(m.canLogLive('random'), isFalse);
      expect(m.canLogLive(null), isFalse);
    });

    test('a captain who is also the creator can log', () {
      // `alpha` is both — the creator check is what grants it.
      expect(_casualMatch().canLogLive('alpha'), isTrue);
    });
  });

  group('registered-player invites', () {
    // Match with two outstanding invites: carl to Team A, dana to Team B.
    const invited = MatchModel(
      id: 'm3',
      code: 'INV001',
      adminUid: 'alpha',
      teamAName: 'Rovers',
      teamBName: 'Wanderers',
      durationMin: 60,
      status: MatchStatus.lobby,
      invitedUids: ['carl', 'dana'],
      invites: {
        'carl': {'team': 'A', 'name': 'Carl', 'byName': 'Alpha'},
        'dana': {'team': 'B', 'name': 'Dana', 'byName': 'Alpha'},
      },
    );

    test('invitedTeam resolves the side each player was invited to', () {
      expect(invited.invitedTeam('carl'), TeamSide.a);
      expect(invited.invitedTeam('dana'), TeamSide.b);
      expect(invited.invitedTeam('nobody'), isNull);
    });

    test('inviter and invitee names read from the invite entry', () {
      expect(invited.inviterName('carl'), 'Alpha');
      expect(invited.inviteeName('dana'), 'Dana');
      expect(invited.inviteeName('nobody'), '');
    });

    test('invitedForSide buckets invites by team', () {
      expect(invited.invitedForSide(TeamSide.a), ['carl']);
      expect(invited.invitedForSide(TeamSide.b), ['dana']);
    });

    test('a match with no invites reports none', () {
      expect(_casualMatch().invitedUids, isEmpty);
      expect(_casualMatch().invitedForSide(TeamSide.a), isEmpty);
      expect(_casualMatch().invitedTeam('anyone'), isNull);
    });
  });

  group('paused clock', () {
    test('a running match is not paused', () {
      expect(_casualMatch().paused, isFalse);
      expect(_casualMatch().pausedAt, isNull);
    });

    test('pausedAt marks the match paused', () {
      final m = MatchModel(
        id: 'm3',
        code: 'PAU555',
        adminUid: 'alpha',
        teamAName: 'Team A',
        teamBName: 'Team B',
        durationMin: 45,
        status: MatchStatus.live,
        pausedAt: DateTime(2026, 7, 27, 20, 30),
      );
      expect(m.paused, isTrue);
    });

    // The whole point of the pause: the readout is taken against `pausedAt`
    // instead of "now", so the clock stops for everyone watching. This is the
    // arithmetic the live screen's `_clockNow` does.
    test('time remaining is frozen at the moment of the pause', () {
      final pausedAt = DateTime(2026, 7, 27, 20, 30);
      final endsAt = pausedAt.add(const Duration(minutes: 12));
      final m = MatchModel(
        id: 'm4',
        code: 'PAU666',
        adminUid: 'alpha',
        teamAName: 'Team A',
        teamBName: 'Team B',
        durationMin: 45,
        status: MatchStatus.live,
        endsAt: endsAt,
        pausedAt: pausedAt,
      );
      final remaining = m.endsAt!.difference(m.pausedAt ?? DateTime.now());
      expect(remaining, const Duration(minutes: 12));
    });
  });

  // A level match settled from the penalty spot. The score is optional on the
  // doc — matches settled on penalties before the score was captured must keep
  // reading back, so every display site is gated on `hasShootoutScore`.
  group('penalty shootout', () {
    MatchModel shootout({int? penA, int? penB, String method = 'penalties'}) =>
        MatchModel(
          id: 'pk1',
          code: 'PKS777',
          adminUid: 'alpha',
          teamAName: 'Team A',
          teamBName: 'Team B',
          durationMin: 45,
          status: MatchStatus.ended,
          scoreA: 2,
          scoreB: 2,
          outcomeMethod: method,
          winnerSide: (penA ?? 0) > (penB ?? 0) ? 'A' : 'B',
          penaltyA: penA,
          penaltyB: penB,
        );

    test('a recorded shootout score is exposed', () {
      final m = shootout(penA: 5, penB: 4);
      expect(m.hasShootoutScore, isTrue);
      expect(m.penaltyA, 5);
      expect(m.penaltyB, 4);
    });

    test('a legacy penalties result without a score is not shown', () {
      expect(shootout().hasShootoutScore, isFalse);
    });

    test('a shootout score on a non-penalties outcome is ignored', () {
      expect(shootout(penA: 5, penB: 4, method: 'draw').hasShootoutScore,
          isFalse);
    });

    // The scoreline stays level; the shootout decides the result. This is what
    // makes a shootout count as a real win in career stats.
    test('the shootout winner takes the win despite a level scoreline', () {
      final m = shootout(penA: 5, penB: 4);
      expect(m.isLevel, isTrue);
      expect(m.resultFor(TeamSide.a), 'win');
      expect(m.resultFor(TeamSide.b), 'loss');
    });
  });
}
