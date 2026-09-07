/// Named routes for every YNO screen.
class Routes {
  Routes._();

  static const splash = '/';
  static const welcome = '/welcome';
  static const signup = '/signup';
  static const footballProfile = '/football-profile';
  static const login = '/login';
  static const forgot = '/forgot';
  static const claim = '/claim';
  static const deleteAccount = '/delete-account'; // permanent deletion, OTP-confirmed
  static const home = '/home';
  static const matches = '/matches'; // drawer-only: ongoing · draft · played
  static const matchCreate = '/match-create';
  static const lobby = '/lobby';
  static const live = '/live';
  static const outcome = '/outcome';
  static const postMatch = '/post-match';
  static const profile = '/profile';
  static const teams = '/teams';
  static const teamCreate = '/team-create';
  static const teamProfile = '/team-profile';

  /// Join a club by invite code. Drawer-only — it was a tab inside the Let's
  /// Play join sheet until 2026-08-21.
  static const joinTeam = '/join-team';
  static const teamManage = '/team-manage';
  static const teamDiscover = '/team-discover';
  static const deletedTeams = '/deleted-teams';
  static const community = '/community';
  static const friends = '/friends';
  static const friendCompare = '/friend-compare';
  static const notifications = '/notifications';
  static const referral = '/referral';
  static const settings = '/settings';
  // Two routes onto one screen (`FeedbackScreen`), differing only by type.
  // The side drawer's `_item` helper navigates by name with no arguments, so a
  // single route taking one would need a special case there.
  static const reportBug = '/report-bug';
  static const suggestion = '/suggestion';
  static const help = '/help';
  static const about = '/about';
  static const editProfile = '/edit-profile';
  static const profilePublic = '/profile-public';
  static const guestJoin = '/guest-join';
  static const liveScoreboard = '/live-scoreboard';
}
