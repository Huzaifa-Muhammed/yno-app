import 'package:cloud_firestore/cloud_firestore.dart';

/// Which side of a match a player belongs to.
enum TeamSide { a, b }

extension TeamSideX on TeamSide {
  String get id => this == TeamSide.a ? 'A' : 'B';
  static TeamSide fromId(String? v) => v == 'B' ? TeamSide.b : TeamSide.a;
}

/// Lifecycle of a match.
enum MatchStatus { lobby, live, ended, abandoned }

MatchStatus _statusFrom(String? v) {
  switch (v) {
    case 'live':
      return MatchStatus.live;
    case 'ended':
      return MatchStatus.ended;
    case 'abandoned':
      return MatchStatus.abandoned;
    default:
      return MatchStatus.lobby;
  }
}

extension MatchStatusX on MatchStatus {
  String get id => switch (this) {
        MatchStatus.live => 'live',
        MatchStatus.ended => 'ended',
        MatchStatus.abandoned => 'abandoned',
        MatchStatus.lobby => 'lobby',
      };
}

/// How players join a match (Section 5).
enum JoiningMethod { separateTeams, openLobby }

JoiningMethod joiningMethodFrom(String? v) =>
    v == 'openLobby' ? JoiningMethod.openLobby : JoiningMethod.separateTeams;

extension JoiningMethodX on JoiningMethod {
  String get id =>
      this == JoiningMethod.openLobby ? 'openLobby' : 'separateTeams';
}

/// Live-match timing modes (Section 6).
enum TimingMode { none, full, halves }

TimingMode timingModeFrom(String? v) => switch (v) {
      'full' => TimingMode.full,
      'halves' => TimingMode.halves,
      _ => TimingMode.none,
    };

extension TimingModeX on TimingMode {
  String get id => switch (this) {
        TimingMode.full => 'full',
        TimingMode.halves => 'halves',
        TimingMode.none => 'none',
      };
}

/// A team member's role (Section 3).
enum TeamRole { owner, captain, vice, player }

TeamRole teamRoleFrom(String? v) => switch (v) {
      'owner' => TeamRole.owner,
      'captain' => TeamRole.captain,
      'vice' => TeamRole.vice,
      _ => TeamRole.player,
    };

extension TeamRoleX on TeamRole {
  String get id => switch (this) {
        TeamRole.owner => 'owner',
        TeamRole.captain => 'captain',
        TeamRole.vice => 'vice',
        TeamRole.player => 'player',
      };
  String get label => switch (this) {
        TeamRole.owner => 'Owner',
        TeamRole.captain => 'Captain',
        TeamRole.vice => 'Vice Captain',
        TeamRole.player => 'Player',
      };
}

/// State of a two-way friend request.
enum FriendStatus { pending, accepted }

/// Category of a notification — drives icon + phone-push eligibility + routing.
enum NotifCategory {
  teamInvite,
  teamUpdate,
  rival,
  matchInvite,
  matchUpdate,
  matchResult,
  friend,
  follow,
  points,
  guest,
  award,
  general,
}

NotifCategory notifCategoryFrom(String? v) => NotifCategory.values.firstWhere(
      (c) => c.name == v,
      orElse: () => NotifCategory.general,
    );

/// Which notification categories fire a lock-screen push by default (the
/// doc's "phone notifications — essential" set). Social categories are opt-in.
const kPhoneNotifCategories = <NotifCategory>{
  NotifCategory.teamInvite,
  NotifCategory.matchInvite,
  NotifCategory.matchUpdate,
  NotifCategory.matchResult,
  NotifCategory.guest,
  NotifCategory.award,
};

DateTime? _dt(dynamic v) => v is Timestamp ? v.toDate() : null;
List<String> _strList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];
Map<String, String> _strMap(dynamic v) => v is Map
    ? v.map((k, val) => MapEntry(k.toString(), val.toString()))
    : <String, String>{};

String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

/// A registered app user + their profile doc (`users/{uid}`).
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.username = '',
    this.firstName = '',
    this.lastName = '',
    this.phone,
    this.dob,
    this.dobLocked = false,
    this.gender,
    this.language = 'English',
    this.photoUrl,
    this.photoPublicId,
    this.position,
    this.preferredFoot,
    this.skillLevel,
    this.sportProfileDone = false,
    this.points = 0,
    this.referralCode = '',
    this.referredBy,
    this.autoCreated = false,
    this.createdAt,
    this.socialLinks = const {},
    this.socialVisibility = const {},
    this.fcmTokens = const [],
    this.following = const [],
    this.followersCount = 0,
    this.tcAcceptedAt,
    this.careerGoals = 0,
    this.careerAssists = 0,
    this.matchesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.motmCount = 0,
    this.communityCount = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.unbeatenStreak = 0,
    this.hatTricks = 0,
    this.bestScoringMatch = 0,
    this.formLast5 = const [],
    this.goalsBySurface = const {},
    this.goalsByFormat = const {},
    this.notifyMatchAlerts = true,
    this.notifyFriendActivity = false,
    this.contactSync = false,
    this.profilePublic = true,
    this.deactivated = false,
    this.reactivateAt,
  });

  final String uid;
  final String name; // composite display name (first + last)
  final String email;
  final String username;
  final String firstName;
  final String lastName;
  final String? phone;
  final DateTime? dob;
  final bool dobLocked;
  final String? gender;
  final String language;
  final String? photoUrl;
  final String? photoPublicId;

  // Sport profile (football).
  final String? position;
  final String? preferredFoot;
  final String? skillLevel;
  final bool sportProfileDone;

  final int points;
  final String referralCode;
  final String? referredBy;

  /// True when the account was created behind the scenes by a match admin.
  final bool autoCreated;
  final DateTime? createdAt;

  /// e.g. {instagram: '@x', whatsapp: '+9715...'}.
  final Map<String, String> socialLinks;

  /// Per-platform visibility: {instagram: 'public'|'friends'|'off'}.
  final Map<String, String> socialVisibility;

  /// Registered device push tokens.
  final List<String> fcmTokens;

  /// Uids this user follows (one-way).
  final List<String> following;
  final int followersCount;
  final DateTime? tcAcceptedAt;

  // ---- Denormalised career counters.
  final int careerGoals;
  final int careerAssists;
  final int matchesPlayed;
  final int wins;
  final int losses;
  final int draws;
  final int motmCount;
  final int communityCount;
  final int currentStreak;
  final int bestStreak;
  final int unbeatenStreak;
  final int hatTricks;
  final int bestScoringMatch;
  final List<String> formLast5; // e.g. ['W','W','L','D','W']
  final Map<String, String> goalsBySurface; // surface -> count (as string)
  final Map<String, String> goalsByFormat;

  // ---- Notification / privacy preferences.
  final bool notifyMatchAlerts;
  final bool notifyFriendActivity;
  final bool contactSync;

  /// When false, only the user themselves and accepted friends can see stats /
  /// match history on the public profile. Everyone else sees basic identity +
  /// an Add Friend prompt. Defaults to public.
  final bool profilePublic;

  /// Temporary self-deactivation (max 1 month). While deactivated the account
  /// is signed out; it auto-reactivates on next login once [reactivateAt] passes
  /// (or the user can reactivate early).
  final bool deactivated;
  final DateTime? reactivateAt;

  int get winRate =>
      matchesPlayed == 0 ? 0 : ((wins / matchesPlayed) * 100).round();

  double get goalsPerMatch =>
      matchesPlayed == 0 ? 0 : careerGoals / matchesPlayed;

  double get assistsPerMatch =>
      matchesPlayed == 0 ? 0 : careerAssists / matchesPlayed;

  int get goalContributions => careerGoals + careerAssists;
  int get totalMotm => motmCount + communityCount;

  /// The @handle to show (falls back to the name if username is unset).
  String get handle => username.isNotEmpty ? username : name;

  int get age {
    if (dob == null) return 0;
    final now = DateTime.now();
    var a = now.year - dob!.year;
    if (now.month < dob!.month ||
        (now.month == dob!.month && now.day < dob!.day)) {
      a--;
    }
    return a;
  }

  String get initials => _initialsOf(name.isEmpty ? username : name);

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return AppUser(
      uid: doc.id,
      name: (d['name'] ?? '') as String,
      email: (d['email'] ?? '') as String,
      username: (d['username'] ?? '') as String,
      firstName: (d['firstName'] ?? '') as String,
      lastName: (d['lastName'] ?? '') as String,
      phone: d['phone'] as String?,
      dob: _dt(d['dob']),
      dobLocked: (d['dobLocked'] ?? false) as bool,
      gender: d['gender'] as String?,
      language: (d['language'] ?? 'English') as String,
      photoUrl: d['photoUrl'] as String?,
      photoPublicId: d['photoPublicId'] as String?,
      position: d['position'] as String?,
      preferredFoot: d['preferredFoot'] as String?,
      skillLevel: d['skillLevel'] as String?,
      sportProfileDone: (d['sportProfileDone'] ?? false) as bool,
      points: (d['points'] ?? 0) as int,
      referralCode: (d['referralCode'] ?? '') as String,
      referredBy: d['referredBy'] as String?,
      autoCreated: (d['autoCreated'] ?? false) as bool,
      createdAt: _dt(d['createdAt']),
      socialLinks: _strMap(d['socialLinks']),
      socialVisibility: _strMap(d['socialVisibility']),
      fcmTokens: _strList(d['fcmTokens']),
      following: _strList(d['following']),
      followersCount: (d['followersCount'] ?? 0) as int,
      tcAcceptedAt: _dt(d['tcAcceptedAt']),
      careerGoals: (d['careerGoals'] ?? 0) as int,
      careerAssists: (d['careerAssists'] ?? 0) as int,
      matchesPlayed: (d['matchesPlayed'] ?? 0) as int,
      wins: (d['wins'] ?? 0) as int,
      losses: (d['losses'] ?? 0) as int,
      draws: (d['draws'] ?? 0) as int,
      motmCount: (d['motmCount'] ?? 0) as int,
      communityCount: (d['communityCount'] ?? 0) as int,
      currentStreak: (d['currentStreak'] ?? 0) as int,
      bestStreak: (d['bestStreak'] ?? 0) as int,
      unbeatenStreak: (d['unbeatenStreak'] ?? 0) as int,
      hatTricks: (d['hatTricks'] ?? 0) as int,
      bestScoringMatch: (d['bestScoringMatch'] ?? 0) as int,
      formLast5: _strList(d['formLast5']),
      goalsBySurface: _strMap(d['goalsBySurface']),
      goalsByFormat: _strMap(d['goalsByFormat']),
      notifyMatchAlerts: (d['notifyMatchAlerts'] ?? true) as bool,
      notifyFriendActivity: (d['notifyFriendActivity'] ?? false) as bool,
      contactSync: (d['contactSync'] ?? false) as bool,
      profilePublic: (d['profilePublic'] ?? true) as bool,
      deactivated: (d['deactivated'] ?? false) as bool,
      reactivateAt: _dt(d['reactivateAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'username': username,
        'usernameLower': username.toLowerCase(),
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'dob': dob == null ? null : Timestamp.fromDate(dob!),
        'dobLocked': dobLocked,
        'gender': gender,
        'language': language,
        'photoUrl': photoUrl,
        'photoPublicId': photoPublicId,
        'position': position,
        'preferredFoot': preferredFoot,
        'skillLevel': skillLevel,
        'sportProfileDone': sportProfileDone,
        'points': points,
        'referralCode': referralCode,
        'referredBy': referredBy,
        'autoCreated': autoCreated,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
        'socialLinks': socialLinks,
        'socialVisibility': socialVisibility,
        'fcmTokens': fcmTokens,
        'following': following,
        'followersCount': followersCount,
        'tcAcceptedAt': tcAcceptedAt == null
            ? null
            : Timestamp.fromDate(tcAcceptedAt!),
        'careerGoals': careerGoals,
        'careerAssists': careerAssists,
        'matchesPlayed': matchesPlayed,
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'motmCount': motmCount,
        'communityCount': communityCount,
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'unbeatenStreak': unbeatenStreak,
        'hatTricks': hatTricks,
        'bestScoringMatch': bestScoringMatch,
        'formLast5': formLast5,
        'goalsBySurface': goalsBySurface,
        'goalsByFormat': goalsByFormat,
        'notifyMatchAlerts': notifyMatchAlerts,
        'notifyFriendActivity': notifyFriendActivity,
        'contactSync': contactSync,
        'profilePublic': profilePublic,
        'deactivated': deactivated,
        'reactivateAt':
            reactivateAt == null ? null : Timestamp.fromDate(reactivateAt!),
      };
}

/// A match document (`matches/{id}`).
class MatchModel {
  const MatchModel({
    required this.id,
    required this.code,
    required this.adminUid,
    required this.teamAName,
    required this.teamBName,
    required this.durationMin,
    required this.status,
    this.name = '',
    this.format = '5v5',
    this.surface = 'Grass',
    this.location = '',
    this.isPublic = false,
    this.joiningMethod = JoiningMethod.separateTeams,
    this.timingMode = TimingMode.none,
    this.matchType = 'friendly',
    this.adminOnlyMode = false,
    this.codeA,
    this.codeB,
    this.scoreA = 0,
    this.scoreB = 0,
    this.captainAUid,
    this.captainBUid,
    this.currentHalf = 1,
    this.halfTime = false,
    this.halfTimeAt,
    this.scheduledAt,
    this.startedAt,
    this.endsAt,
    this.pausedAt,
    this.endedAt,
    this.actualDurationSec,
    this.createdAt,
    this.outcomeMethod,
    this.winnerSide,
    this.penaltyA,
    this.penaltyB,
    this.extraTimeMin = 0,
    this.awardsDone = false,
    this.communityPlayerUid,
    this.motmAUid,
    this.motmBUid,
    this.voteCloseAt,
    this.editableUntil,
    this.teamAId,
    this.teamBId,
    this.challengedTeamId,
    this.challengedTeamName,
    this.challengeCaptainUid,
    this.challengeRecipientUids = const [],
    this.challengeStatus,
    this.invitedUids = const [],
    this.invites = const {},
  });

  final String id;
  final String code;
  final String adminUid;
  final String teamAName;
  final String teamBName;
  final int durationMin;
  final MatchStatus status;

  final String name;
  final String format;
  final String surface;
  final String location;
  final bool isPublic;
  final JoiningMethod joiningMethod;
  final TimingMode timingMode;
  final String matchType; // friendly | affiliate | official (V1: friendly)
  final bool adminOnlyMode;

  /// Separate-teams join codes (one per side). Falls back to [code].
  final String? codeA;
  final String? codeB;

  final int scoreA;
  final int scoreB;
  final String? captainAUid;
  final String? captainBUid;
  final int currentHalf;
  final bool halfTime;

  /// When the half-time interval began.
  ///
  /// Exists so the break can be given back to the clock: [startSecondHalf]
  /// pushes `startedAt` forward by however long half-time lasted, exactly as
  /// [resumeMatch] does for a pause. Without it the readout — which counts UP
  /// from `startedAt` as of 2026-09-07 — would include the interval, so a
  /// twenty-minute half-time would restart the second half at 65:00.
  ///
  /// ⚠️ Deliberately NOT `pausedAt`. That field means "the host stopped the
  /// clock", and it drives a PAUSED badge and a Resume button; half-time has
  /// its own panel and must not raise either.
  final DateTime? halfTimeAt;

  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? endsAt;

  /// When the host paused the clock, or null while it's running. The clock is
  /// read against this instead of "now" while set, and resuming shifts
  /// [startedAt]/[endsAt] forward by however long the break lasted — so a pause
  /// costs no match time.
  final DateTime? pausedAt;
  final DateTime? endedAt;
  final int? actualDurationSec;
  final DateTime? createdAt;

  /// 'fullTime' | 'draw' | 'penalties' | 'goldenGoal' | 'abandoned'.
  final String? outcomeMethod;

  /// 'A' | 'B' | null (draw). Used when penalties/golden-goal decide a level tie.
  final String? winnerSide;

  /// Shootout score, when [outcomeMethod] is `'penalties'`. Null for every
  /// other outcome — and null on penalties matches recorded before shootout
  /// scores were captured, so display sites must tolerate a missing score.
  final int? penaltyA;
  final int? penaltyB;

  /// True when this match was settled by a shootout AND the score was recorded.
  bool get hasShootoutScore =>
      outcomeMethod == 'penalties' && penaltyA != null && penaltyB != null;

  /// Extra-time minutes the host added after a level full time, totalled over
  /// however many periods were granted. `0` on every match that finished inside
  /// regulation.
  ///
  /// Extra time used to be a question asked *after* [MatchRepository.endMatch],
  /// so it recorded that extra time happened without any of it ever being
  /// played in the app — no clock, no goals, nothing for the other players to
  /// watch. It is now a real period: the match goes back to `live` with the
  /// clock extended, which is what this field measures.
  final int extraTimeMin;

  /// Regulation minutes for the whole match, ignoring extra time. `durationMin`
  /// is *per half* in [TimingMode.halves] and the total otherwise — the reason
  /// the readout label can't just print `durationMin`.
  int get regulationMin => timingMode == TimingMode.none
      ? 0
      : (timingMode == TimingMode.halves ? durationMin * 2 : durationMin);

  /// True once the host has sent a level match into extra time.
  bool get inExtraTime => extraTimeMin > 0;

  /// The football-style clock label — `90+10` — shown to everyone watching, so
  /// a player who joined late can tell added time from regulation.
  /// Empty when there is no clock or no extra time to distinguish.
  String get extraTimeLabel =>
      (!inExtraTime || regulationMin == 0) ? '' : '$regulationMin+$extraTimeMin';

  final bool awardsDone;
  final String? communityPlayerUid;
  final String? motmAUid;
  final String? motmBUid;
  final DateTime? voteCloseAt;
  final DateTime? editableUntil;

  final String? teamAId;
  final String? teamBId;

  /// A team challenged by invite code on the create screen. Side B is held for
  /// them until their captain answers; [challengeStatus] is
  /// 'pending' | 'accepted' | 'declined' (null = no challenge was made).
  final String? challengedTeamId;
  final String? challengedTeamName;

  /// The primary answerer — the challenged team's captain, or its owner when no
  /// captain is assigned. Kept for the accepter→captainB link.
  final String? challengeCaptainUid;

  /// Everyone who may accept/decline the challenge — the team's owner AND
  /// captain (deduped). Both get notified; whoever answers first resolves it for
  /// all, and the others' bell notification is cleared.
  final List<String> challengeRecipientUids;

  final String? challengeStatus;

  /// Registered players invited to this match who haven't answered yet. The
  /// creator (or a captain) adds them from "Add player → Registered"; they get a
  /// popup and only actually join if they accept. [invitedUids] is the array the
  /// invitee queries by; [invites] maps uid → {team, name, byName} for the side
  /// and the display names.
  final List<String> invitedUids;
  final Map<String, dynamic> invites;

  /// The host has stopped the clock mid-half (injury, argument, ball on a roof).
  bool get paused => pausedAt != null;

  bool get challengePending => challengeStatus == 'pending';
  bool get challengeAccepted => challengeStatus == 'accepted';

  /// Side an invited player was invited to (null if not invited / no side set).
  TeamSide? invitedTeam(String uid) {
    final e = invites[uid];
    if (e is Map && e['team'] != null) {
      return TeamSideX.fromId(e['team'] as String?);
    }
    return null;
  }

  /// Display name of whoever sent [uid]'s invite.
  String inviterName(String uid) {
    final e = invites[uid];
    return (e is Map ? e['byName'] as String? : null) ?? '';
  }

  /// Display name of the invited player [uid].
  String inviteeName(String uid) {
    final e = invites[uid];
    return (e is Map ? e['name'] as String? : null) ?? '';
  }

  /// Uids invited to a given side, still awaiting an answer.
  List<String> invitedForSide(TeamSide side) =>
      invitedUids.where((u) => invitedTeam(u) == side).toList();

  String teamName(TeamSide side) => side == TeamSide.a ? teamAName : teamBName;
  int score(TeamSide side) => side == TeamSide.a ? scoreA : scoreB;
  String? teamId(TeamSide side) => side == TeamSide.a ? teamAId : teamBId;
  String? captainUid(TeamSide side) =>
      side == TeamSide.a ? captainAUid : captainBUid;

  /// Whether [uid] may add/remove players on [side]. Each team is self-managed:
  /// the creator (admin) runs Team A; each side's captain runs their own side.
  /// The creator may also run Team B ONLY while it has no captain (an ordinary
  /// pickup match) — once a captain owns it (e.g. an accepted club challenge)
  /// the creator can no longer touch that roster.
  bool canManageSide(String? uid, TeamSide side) {
    if (uid == null) return false;
    final amAdmin = adminUid == uid;
    if (side == TeamSide.a) return amAdmin || captainAUid == uid;
    return captainBUid == uid || (amAdmin && captainBUid == null);
  }

  /// Whether [uid] may log live events (goals/cards/subs). **The match creator
  /// alone** — captains run their own roster in the lobby (see
  /// [canManageSide]) but do NOT log the match; everyone else, captains
  /// included, gets the read-only live screen.
  bool canLogLive(String? uid) => uid != null && adminUid == uid;

  /// Join code for a side (separate-teams) or the shared code (open lobby).
  String codeFor(TeamSide side) =>
      (side == TeamSide.a ? codeA : codeB) ?? code;

  bool get isFuture => scheduledAt != null && scheduledAt!.isAfter(DateTime.now());

  /// True when this match names a real side size ('7v7', '11v11') worth showing.
  ///
  /// The format picker was removed on 2026-09-07 and every new match stores
  /// `'Unlimited'`, so without this guard each match card, the scorecard and
  /// the join preview would print the literal word "Unlimited" on every single
  /// match — a label that is now noise on all of them.
  ///
  /// Matches created *before* that change carry real values and keep displaying
  /// them, which is why this hides the default rather than dropping the format
  /// line outright: a 7v7 played last month is still a 7v7.
  bool get hasFixedFormat => format.isNotEmpty && format != 'Unlimited';

  /// Which side won by final score alone (before penalties/golden-goal).
  bool get isLevel => scoreA == scoreB;

  /// Resolved result side considering [winnerSide] override on level scores.
  String resultFor(TeamSide side) {
    if (isLevel) {
      if (winnerSide == null) return 'draw';
      return winnerSide == side.id ? 'win' : 'loss';
    }
    final aWon = scoreA > scoreB;
    return (side == TeamSide.a) == aWon ? 'win' : 'loss';
  }

  factory MatchModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return MatchModel(
      id: doc.id,
      code: (d['code'] ?? '') as String,
      adminUid: (d['adminUid'] ?? '') as String,
      teamAName: (d['teamAName'] ?? 'Team A') as String,
      teamBName: (d['teamBName'] ?? 'Team B') as String,
      durationMin: (d['durationMin'] ?? 60) as int,
      status: _statusFrom(d['status'] as String?),
      name: (d['name'] ?? '') as String,
      format: (d['format'] ?? '5v5') as String,
      surface: (d['surface'] ?? 'Grass') as String,
      location: (d['location'] ?? '') as String,
      isPublic: (d['isPublic'] ?? false) as bool,
      joiningMethod: joiningMethodFrom(d['joiningMethod'] as String?),
      timingMode: timingModeFrom(d['timingMode'] as String?),
      matchType: (d['matchType'] ?? 'friendly') as String,
      adminOnlyMode: (d['adminOnlyMode'] ?? false) as bool,
      codeA: d['codeA'] as String?,
      codeB: d['codeB'] as String?,
      scoreA: (d['scoreA'] ?? 0) as int,
      scoreB: (d['scoreB'] ?? 0) as int,
      captainAUid: d['captainAUid'] as String?,
      captainBUid: d['captainBUid'] as String?,
      currentHalf: (d['currentHalf'] ?? 1) as int,
      halfTime: (d['halfTime'] ?? false) as bool,
      halfTimeAt: _dt(d['halfTimeAt']),
      scheduledAt: _dt(d['scheduledAt']),
      startedAt: _dt(d['startedAt']),
      endsAt: _dt(d['endsAt']),
      pausedAt: _dt(d['pausedAt']),
      endedAt: _dt(d['endedAt']),
      actualDurationSec: d['actualDurationSec'] as int?,
      createdAt: _dt(d['createdAt']),
      outcomeMethod: d['outcomeMethod'] as String?,
      winnerSide: d['winnerSide'] as String?,
      penaltyA: d['penaltyA'] as int?,
      penaltyB: d['penaltyB'] as int?,
      extraTimeMin: (d['extraTimeMin'] ?? 0) as int,
      awardsDone: (d['awardsDone'] ?? false) as bool,
      communityPlayerUid: d['communityPlayerUid'] as String?,
      motmAUid: d['motmAUid'] as String?,
      motmBUid: d['motmBUid'] as String?,
      voteCloseAt: _dt(d['voteCloseAt']),
      editableUntil: _dt(d['editableUntil']),
      teamAId: d['teamAId'] as String?,
      teamBId: d['teamBId'] as String?,
      challengedTeamId: d['challengedTeamId'] as String?,
      challengedTeamName: d['challengedTeamName'] as String?,
      challengeCaptainUid: d['challengeCaptainUid'] as String?,
      challengeRecipientUids: _strList(d['challengeRecipientUids']),
      challengeStatus: d['challengeStatus'] as String?,
      invitedUids: _strList(d['invitedUids']),
      invites: (d['invites'] is Map)
          ? Map<String, dynamic>.from(d['invites'] as Map)
          : const {},
    );
  }
}

/// A player within a match (`matches/{id}/players/{uid}`).
class MatchPlayer {
  const MatchPlayer({
    required this.uid,
    required this.name,
    required this.team,
    this.position,
    this.goals = 0,
    this.assists = 0,
    this.joinedVia = 'code',
    this.isAdmin = false,
    this.isGuest = false,
    this.isCaptain = false,
  });

  final String uid;
  final String name;
  final TeamSide team;
  final String? position;
  final int goals;
  final int assists;

  /// How the player got in: `code`, `link`, `added`, `admin`, `invite`.
  final String joinedVia;
  final bool isAdmin;
  final bool isGuest;
  final bool isCaptain;

  String get initials => _initialsOf(name);

  factory MatchPlayer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return MatchPlayer(
      uid: doc.id,
      name: (d['name'] ?? '') as String,
      team: TeamSideX.fromId(d['team'] as String?),
      position: d['position'] as String?,
      goals: (d['goals'] ?? 0) as int,
      assists: (d['assists'] ?? 0) as int,
      joinedVia: (d['joinedVia'] ?? 'code') as String,
      isAdmin: (d['isAdmin'] ?? false) as bool,
      isGuest: (d['isGuest'] ?? false) as bool,
      isCaptain: (d['isCaptain'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'team': team.id,
        'position': position,
        'goals': goals,
        'assists': assists,
        'joinedVia': joinedVia,
        'isAdmin': isAdmin,
        'isGuest': isGuest,
        'isCaptain': isCaptain,
        'joinedAt': FieldValue.serverTimestamp(),
      };
}

/// Does [player] earn career stats, points and played-with edges?
///
/// [uidsWithAccounts] is the set of player uids that have a `users/{uid}`
/// document **right now** — see `MatchRepository._playersWithAccounts`.
///
/// ⚠️ This is deliberately NOT `!player.isGuest`, and the difference is the
/// whole point. `isGuest` is a snapshot of how complete the profile looked when
/// they joined, and it is what the lobby renders — an auto-created account (a
/// host added them by email, or they joined from the website) shows as a guest
/// until its owner claims it. Deciding stats on that flag went wrong twice:
///
///  * someone who **claims their account before the final whistle** is a real
///    player by then, and their whole match was still being filed as a guest's;
///  * the guest branch writes `guests/{uid}`, which `claimGuestStats` finds by
///    **email** — a field that write never sets. Stats for anyone holding a real
///    uid went to a document nothing ever reads back, and were lost for good.
///
/// A `g_…` guest has no account, so this is false for them and their stats go
/// to `guests/{g_id}` with the email that makes them claimable. That is the only
/// case that belongs there.
bool earnsCareerStats(MatchPlayer player, Set<String> uidsWithAccounts) =>
    player.uid.isNotEmpty && uidsWithAccounts.contains(player.uid);

/// A player waiting for admin approval (`matches/{id}/pending/{uid}`).
class PendingPlayer {
  const PendingPlayer({
    required this.uid,
    required this.name,
    required this.team,
    this.isGuest = false,
    this.midGame = false,
    this.at,
  });

  final String uid;
  final String name;
  final TeamSide team;
  final bool isGuest;
  final bool midGame;
  final DateTime? at;

  String get initials => _initialsOf(name);

  factory PendingPlayer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return PendingPlayer(
      uid: doc.id,
      name: (d['name'] ?? '') as String,
      team: TeamSideX.fromId(d['team'] as String?),
      isGuest: (d['isGuest'] ?? false) as bool,
      midGame: (d['midGame'] ?? false) as bool,
      at: _dt(d['at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'team': team.id,
        'isGuest': isGuest,
        'midGame': midGame,
        'at': FieldValue.serverTimestamp(),
      };
}

/// A goal event (`matches/{id}/goals/{goalId}`).
class GoalEvent {
  const GoalEvent({
    required this.id,
    required this.scorerUid,
    required this.scorerName,
    required this.team,
    required this.minute,
    this.assistUid,
    this.assistName,
    this.scoreAAfter,
    this.scoreBAfter,
    this.at,
  });

  final String id;
  final String scorerUid;
  final String scorerName;
  final TeamSide team;
  final int minute;
  final String? assistUid;
  final String? assistName;
  final int? scoreAAfter;
  final int? scoreBAfter;
  final DateTime? at;

  factory GoalEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return GoalEvent(
      id: doc.id,
      scorerUid: (d['scorerUid'] ?? '') as String,
      scorerName: (d['scorerName'] ?? '') as String,
      team: TeamSideX.fromId(d['team'] as String?),
      minute: (d['minute'] ?? 0) as int,
      assistUid: d['assistUid'] as String?,
      assistName: d['assistName'] as String?,
      scoreAAfter: d['scoreAAfter'] as int?,
      scoreBAfter: d['scoreBAfter'] as int?,
      at: _dt(d['at']),
    );
  }
}

/// One converted spot-kick in a shootout (`matches/{id}/penalties/{auto}`).
///
/// Kept out of the `goals` subcollection on purpose: a shootout kick is not a
/// match goal. `goals` docs carry `scoreAAfter`/`scoreBAfter` and drive the
/// match timeline, and a 2–2 game settled 4–3 on penalties must still read 2–2
/// everywhere — team `goalsFor` folds from `match.scoreA`/`scoreB`, so writing
/// shootout kicks there would silently inflate every club's goal difference.
///
/// The scorer's *personal* tally is a separate question, and the answer here is
/// yes: [MatchRepository.recordShootout] increments `players/{uid}.goals`, which
/// `finalizeMatch` folds into `careerGoals`. That is the client's call
/// (2026-09-07) and it departs from real-football convention, where shootout
/// kicks never count toward a striker's season total.
///
/// Only *converted* kicks are stored. Misses are not modelled — the shootout
/// sheet captures who scored, which is all the scorecard shows.
class PenaltyEvent {
  const PenaltyEvent({
    required this.id,
    required this.scorerUid,
    required this.scorerName,
    required this.team,
    this.order = 0,
    this.at,
  });

  final String id;
  final String scorerUid;
  final String scorerName;
  final TeamSide team;

  /// Position in that team's run of kicks, 1-based — so the scorecard can list
  /// them in the order they were taken rather than by write time.
  final int order;
  final DateTime? at;

  factory PenaltyEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return PenaltyEvent(
      id: doc.id,
      scorerUid: (d['scorerUid'] ?? '') as String,
      scorerName: (d['scorerName'] ?? '') as String,
      team: TeamSideX.fromId(d['team'] as String?),
      order: (d['order'] ?? 0) as int,
      at: _dt(d['at']),
    );
  }
}

/// What a [FeedbackReport] is: a fault, or an idea.
///
/// Kept as one collection with a type rather than two collections, because the
/// admin panel wants them in one list sorted by arrival — the difference is a
/// filter, not a different kind of record.
enum FeedbackType { bug, suggestion }

FeedbackType feedbackTypeFrom(String? v) =>
    v == 'suggestion' ? FeedbackType.suggestion : FeedbackType.bug;

extension FeedbackTypeX on FeedbackType {
  String get id => this == FeedbackType.suggestion ? 'suggestion' : 'bug';
}

/// Where a report sits in the admin's queue.
///
/// `open` → `resolved` is the whole lifecycle; there is no assignee and no
/// priority, because one person reads these and a second field they never set
/// would just be noise in the list.
enum FeedbackStatus { open, resolved }

FeedbackStatus feedbackStatusFrom(String? v) =>
    v == 'resolved' ? FeedbackStatus.resolved : FeedbackStatus.open;

extension FeedbackStatusX on FeedbackStatus {
  String get id => this == FeedbackStatus.resolved ? 'resolved' : 'open';
}

/// A bug report or a suggestion sent from the side drawer (`feedback/{id}`).
///
/// The reporter's identity and build are captured at submit time rather than
/// asked for: a bug report that does not say who sent it, on what version, is
/// usually unactionable, and nobody types their app version correctly.
///
/// ⚠️ `feedback` is NOT world-readable — see `firestore.rules`. Reports carry
/// an email address and whatever the user chose to type, which can include
/// anything, so only the super-admin and the author can read one back. That is
/// unlike `users`, which is public.
class FeedbackReport {
  const FeedbackReport({
    required this.id,
    required this.type,
    required this.message,
    this.status = FeedbackStatus.open,
    this.uid = '',
    this.userName = '',
    this.userEmail = '',
    this.appVersion = '',
    this.platform = '',
    this.createdAt,
  });

  final String id;
  final FeedbackType type;
  final String message;
  final FeedbackStatus status;

  /// Who sent it. Empty only on a report written before this field existed —
  /// submission requires being signed in.
  final String uid;
  final String userName;
  final String userEmail;

  /// The build it came from, e.g. `1.0.0`, and `android` / `ios` / `web`.
  /// Both can be empty: [AppVersion.current] is empty when the platform
  /// channel fails, and it is better to store nothing than a guess.
  final String appVersion;
  final String platform;

  final DateTime? createdAt;

  bool get isResolved => status == FeedbackStatus.resolved;

  factory FeedbackReport.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return FeedbackReport(
      id: doc.id,
      type: feedbackTypeFrom(d['type'] as String?),
      message: (d['message'] ?? '') as String,
      status: feedbackStatusFrom(d['status'] as String?),
      uid: (d['uid'] ?? '') as String,
      userName: (d['userName'] ?? '') as String,
      userEmail: (d['userEmail'] ?? '') as String,
      appVersion: (d['appVersion'] ?? '') as String,
      platform: (d['platform'] ?? '') as String,
      createdAt: _dt(d['createdAt']),
    );
  }
}

/// A community-award vote (`matches/{id}/votes/{voterUid}`).
class VoteRecord {
  const VoteRecord({required this.voterUid, required this.votedUid, this.at});
  final String voterUid;
  final String votedUid;
  final DateTime? at;

  factory VoteRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return VoteRecord(
      voterUid: doc.id,
      votedUid: (d['votedUid'] ?? '') as String,
      at: _dt(d['at']),
    );
  }
}

/// A persistent team (`teams/{id}`).
class TeamModel {
  const TeamModel({
    required this.id,
    required this.name,
    required this.ownerUid,
    this.badgeUrl,
    this.badgePublicId,
    this.presetBadge,
    this.isPublic = false,
    this.captainUid,
    this.viceCaptainUids = const [],
    this.memberUids = const [],
    this.roles = const {},
    this.disbanded = false,
    this.disbandedAt,
    this.createdAt,
    this.matchesPlayed = 0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
    this.cleanSheets = 0,
    this.formLast10 = const [],
    this.bestStreak = 0,
    this.unbeatenStreak = 0,
    this.currentStreak = 0,
    this.teamMotm = 0,
    this.teamCommunity = 0,
  });

  final String id;
  final String name;
  final String ownerUid;
  final String? badgeUrl;
  final String? badgePublicId;

  /// Name of a chosen preset badge (when no custom upload).
  final String? presetBadge;
  final bool isPublic;

  // NOTE: the invite code is deliberately NOT a field here. Team docs are
  // world-readable (public profiles, discovery, scorecards), so anything on
  // them is public — a rule cannot hide a single field. The code lives in
  // `teams/{id}/private/meta` (manager-read only) and is resolved by
  // `teamCodes/{CODE}`. Read it via TeamRepository.watchInviteCode.

  final String? captainUid;

  /// Ordered vice-captain uids (index 0 = priority 1).
  final List<String> viceCaptainUids;
  final List<String> memberUids;

  /// uid -> role id (owner/captain/vice/player).
  final Map<String, String> roles;
  final bool disbanded;
  final DateTime? disbandedAt;
  final DateTime? createdAt;

  // ---- Denormalised team stats.
  final int matchesPlayed;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int cleanSheets;
  final List<String> formLast10;
  final int bestStreak;
  final int unbeatenStreak;
  final int currentStreak;
  final int teamMotm;
  final int teamCommunity;

  int get winRate =>
      matchesPlayed == 0 ? 0 : ((wins / matchesPlayed) * 100).round();

  TeamRole roleOf(String uid) {
    if (uid == ownerUid) return TeamRole.owner;
    if (uid == captainUid) return TeamRole.captain;
    if (viceCaptainUids.contains(uid)) return TeamRole.vice;
    return teamRoleFrom(roles[uid]);
  }

  bool canManage(String uid) => uid == ownerUid || uid == captainUid;

  /// True within the 6-month restore window.
  bool get restorable =>
      disbanded &&
      disbandedAt != null &&
      DateTime.now().difference(disbandedAt!).inDays <= 183;

  factory TeamModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return TeamModel(
      id: doc.id,
      name: (d['name'] ?? '') as String,
      ownerUid: (d['ownerUid'] ?? '') as String,
      badgeUrl: d['badgeUrl'] as String?,
      badgePublicId: d['badgePublicId'] as String?,
      presetBadge: d['presetBadge'] as String?,
      isPublic: (d['isPublic'] ?? false) as bool,
      captainUid: d['captainUid'] as String?,
      viceCaptainUids: _strList(d['viceCaptainUids']),
      memberUids: _strList(d['memberUids']),
      roles: _strMap(d['roles']),
      disbanded: (d['disbanded'] ?? false) as bool,
      disbandedAt: _dt(d['disbandedAt']),
      createdAt: _dt(d['createdAt']),
      matchesPlayed: (d['matchesPlayed'] ?? 0) as int,
      wins: (d['wins'] ?? 0) as int,
      draws: (d['draws'] ?? 0) as int,
      losses: (d['losses'] ?? 0) as int,
      goalsFor: (d['goalsFor'] ?? 0) as int,
      goalsAgainst: (d['goalsAgainst'] ?? 0) as int,
      cleanSheets: (d['cleanSheets'] ?? 0) as int,
      formLast10: _strList(d['formLast10']),
      bestStreak: (d['bestStreak'] ?? 0) as int,
      unbeatenStreak: (d['unbeatenStreak'] ?? 0) as int,
      currentStreak: (d['currentStreak'] ?? 0) as int,
      teamMotm: (d['teamMotm'] ?? 0) as int,
      teamCommunity: (d['teamCommunity'] ?? 0) as int,
    );
  }
}

/// A pending team invite (`teams/{id}/invites/{uid}`), 7-day expiry.
class TeamInvite {
  const TeamInvite({
    required this.uid,
    required this.name,
    this.expiresAt,
    this.at,
  });

  final String uid;
  final String name;
  final DateTime? expiresAt;
  final DateTime? at;

  bool get expired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  String get initials => _initialsOf(name);

  factory TeamInvite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return TeamInvite(
      uid: doc.id,
      name: (d['name'] ?? '') as String,
      expiresAt: _dt(d['expiresAt']),
      at: _dt(d['at']),
    );
  }
}

/// A two-way friendship edge (`friendships/{pairId}`), pairId = sorted uids.
class FriendEdge {
  const FriendEdge({
    required this.id,
    required this.users,
    required this.requester,
    required this.status,
    this.at,
  });

  final String id;
  final List<String> users;
  final String requester;
  final FriendStatus status;
  final DateTime? at;

  String other(String me) => users.firstWhere((u) => u != me, orElse: () => '');

  factory FriendEdge.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return FriendEdge(
      id: doc.id,
      users: _strList(d['users']),
      requester: (d['requester'] ?? '') as String,
      status: (d['status'] == 'accepted')
          ? FriendStatus.accepted
          : FriendStatus.pending,
      at: _dt(d['at']),
    );
  }
}

/// A two-way rival-team edge (`rivalries/{pairId}`).
class RivalEdge {
  const RivalEdge({
    required this.id,
    required this.teams,
    required this.requester,
    required this.status,
    this.at,
  });

  final String id;
  final List<String> teams;
  final String requester; // team id that initiated
  final FriendStatus status;
  final DateTime? at;

  String other(String teamId) =>
      teams.firstWhere((t) => t != teamId, orElse: () => '');

  factory RivalEdge.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return RivalEdge(
      id: doc.id,
      teams: _strList(d['teams']),
      requester: (d['requester'] ?? '') as String,
      status: (d['status'] == 'accepted')
          ? FriendStatus.accepted
          : FriendStatus.pending,
      at: _dt(d['at']),
    );
  }
}

/// A typed notification (`users/{uid}/notifications/{id}`).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.category = NotifCategory.general,
    this.route,
    this.arg,
    this.read = false,
    this.at,
  });

  final String id;
  final String title;
  final String body;
  final NotifCategory category;

  /// Optional deep target for tap-routing.
  final String? route;
  final String? arg;
  final bool read;
  final DateTime? at;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return AppNotification(
      id: doc.id,
      title: (d['title'] ?? '') as String,
      body: (d['body'] ?? '') as String,
      category: notifCategoryFrom(d['category'] as String?),
      route: d['route'] as String?,
      arg: d['arg'] as String?,
      read: (d['read'] ?? false) as bool,
      at: _dt(d['at']),
    );
  }
}
