import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/l10n.dart';
import 'routes.dart';
import 'services/auth_repository.dart';
import 'services/match_repository.dart';
import 'services/models.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/football_profile_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/claim_account_screen.dart';
import 'screens/home_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/match_create_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/live_match_screen.dart';
import 'screens/match_outcome_screen.dart';
import 'screens/post_match_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/teams_screen.dart';
import 'screens/team_create_screen.dart';
import 'screens/join_team_screen.dart';
import 'screens/team_profile_screen.dart';
import 'screens/team_manage_screen.dart';
import 'screens/team_discover_screen.dart';
import 'screens/deleted_teams_screen.dart';
import 'screens/community_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/friend_compare_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/delete_account_screen.dart';
import 'screens/referral_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/help_screen.dart';
import 'screens/about_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/public_profile_screen.dart';
import 'screens/guest_join_screen.dart';
import 'screens/live_scoreboard_screen.dart';

/// Global navigator key so services (push tap-routing) can navigate.
final GlobalKey<NavigatorState> ynoNavigatorKey = GlobalKey<NavigatorState>();

/// Observes navigation so the active-match gate always knows the top route
/// name (it can't read the navigator's stack directly).
final _RouteTracker _routeTracker = _RouteTracker();

class YnoApp extends StatelessWidget {
  const YnoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild the whole app when the language changes so every `tr(...)`
    // re-resolves and the layout flips LTR/RTL.
    return ValueListenableBuilder<Locale>(
      valueListenable: L.locale,
      builder: (context, locale, _) => MaterialApp(
        title: 'YNO',
        debugShowCheckedModeBanner: false,
        navigatorKey: ynoNavigatorKey,
        navigatorObservers: [_routeTracker],
        theme: AppTheme.dark,
        locale: locale,
        supportedLocales: L.supported,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Wrap every route so a signed-in player who is in a LIVE match is
        // always pulled onto the live screen — on match start, from any screen,
        // and again after an app restart — until the creator ends it.
        //
        // [DismissKeyboard] is the outer of the two so it covers the gate's own
        // subtree as well; it only claims taps that reach empty space.
        builder: (context, child) => DismissKeyboard(
          child: ActiveMatchGate(child: child ?? const SizedBox.shrink()),
        ),
        initialRoute: Routes.splash,
        routes: _routes(),
      ),
    );
  }

  Map<String, WidgetBuilder> _routes() {
    return {
        Routes.splash: (_) => const SplashScreen(),
        Routes.welcome: (_) => const WelcomeScreen(),
        Routes.signup: (_) => const SignupScreen(),
        Routes.footballProfile: (_) => const FootballProfileScreen(),
        Routes.login: (_) => const LoginScreen(),
        Routes.forgot: (_) => const ForgotPasswordScreen(),
        Routes.claim: (_) => const ClaimAccountScreen(),
        Routes.home: (_) => const HomeScreen(),
        Routes.matches: (_) => const MatchesScreen(),
        Routes.matchCreate: (_) => const MatchCreateScreen(),
        Routes.lobby: (_) => const LobbyScreen(),
        Routes.live: (_) => const LiveMatchScreen(),
        Routes.outcome: (_) => const MatchOutcomeScreen(),
        Routes.postMatch: (_) => const PostMatchScreen(),
        Routes.profile: (_) => const ProfileScreen(),
        Routes.teams: (_) => const TeamsScreen(),
        Routes.teamCreate: (_) => const TeamCreateScreen(),
        Routes.teamProfile: (_) => const TeamProfileScreen(),
        Routes.joinTeam: (_) => const JoinTeamScreen(),
        Routes.teamManage: (_) => const TeamManageScreen(),
        Routes.teamDiscover: (_) => const TeamDiscoverScreen(),
        Routes.deletedTeams: (_) => const DeletedTeamsScreen(),
        Routes.community: (_) => const CommunityScreen(),
        Routes.friends: (_) => const FriendsScreen(),
        Routes.friendCompare: (_) => const FriendCompareScreen(),
        Routes.notifications: (_) => const NotificationsScreen(),
        Routes.deleteAccount: (_) => const DeleteAccountScreen(),
        Routes.referral: (_) => const ReferralScreen(),
        Routes.settings: (_) => const SettingsScreen(),
        Routes.reportBug: (_) =>
            const FeedbackScreen(type: FeedbackType.bug),
        Routes.suggestion: (_) =>
            const FeedbackScreen(type: FeedbackType.suggestion),
        Routes.help: (_) => const HelpScreen(),
        Routes.about: (_) => const AboutScreen(),
        Routes.editProfile: (_) => const EditProfileScreen(),
        Routes.profilePublic: (_) => const PublicProfileScreen(),
        Routes.guestJoin: (_) => const GuestJoinScreen(),
        Routes.liveScoreboard: (_) => const LiveScoreboardScreen(),
    };
  }
}

/// Tracks the name of the current top route so [ActiveMatchGate] can tell
/// whether it's already showing the match flow.
class _RouteTracker extends NavigatorObserver {
  final ValueNotifier<String?> current = ValueNotifier<String?>(null);

  void _set(Route<dynamic>? route) => current.value = route?.settings.name;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _set(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(previousRoute);
}

/// Global "you're in a live match" gate. Sits above the Navigator and, whenever
/// the signed-in user is a player in a match whose status is `live`, pushes the
/// live screen on top — no matter what screen they're on and even after the app
/// is killed and relaunched. It steps aside on auth/splash screens and while the
/// match flow (live / outcome / post-match) is already on top, so it never
/// fights the screens that own that flow. Leaving is impossible until the match
/// stops being live (creator ends it), at which point the stream reports no live
/// match and the live screen itself moves everyone on to the results.
class ActiveMatchGate extends StatefulWidget {
  const ActiveMatchGate({super.key, required this.child});

  final Widget child;

  @override
  State<ActiveMatchGate> createState() => _ActiveMatchGateState();
}

class _ActiveMatchGateState extends State<ActiveMatchGate> {
  StreamSubscription<dynamic>? _authSub;
  StreamSubscription<MatchModel?>? _matchSub;
  String? _uid;
  String? _liveMatchId;
  bool _navigating = false;

  /// Routes where the gate must NOT interfere: auth/onboarding (no session or
  /// mid-signup) and the match flow itself (which drives its own navigation).
  static const _skip = <String>{
    Routes.splash,
    Routes.welcome,
    Routes.signup,
    Routes.login,
    Routes.forgot,
    Routes.claim,
    Routes.footballProfile,
    Routes.live,
    Routes.outcome,
    Routes.postMatch,
  };

  @override
  void initState() {
    super.initState();
    _routeTracker.current.addListener(_scheduleCheck);
    _authSub = AuthRepository.instance.authState.listen((_) => _onAuth());
    _onAuth();
  }

  void _onAuth() {
    final uid = AuthRepository.instance.uid;
    if (uid == _uid) return;
    _uid = uid;
    _matchSub?.cancel();
    _liveMatchId = null;
    if (uid == null) return;
    _matchSub =
        MatchRepository.instance.watchMyLiveMatch(uid).listen((live) {
      _liveMatchId = live?.id;
      _scheduleCheck();
    });
  }

  void _scheduleCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRedirect());
  }

  void _maybeRedirect() {
    final id = _liveMatchId;
    if (id == null || _navigating || !mounted) return;
    final nav = ynoNavigatorKey.currentState;
    if (nav == null) return;
    final top = _routeTracker.current.value;
    if (top == null || _skip.contains(top)) return;
    _navigating = true;
    nav
        .pushNamed(Routes.live, arguments: id)
        .whenComplete(() => _navigating = false);
  }

  @override
  void dispose() {
    _routeTracker.current.removeListener(_scheduleCheck);
    _authSub?.cancel();
    _matchSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
