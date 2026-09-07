import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
import '../services/contact_matcher.dart';
import '../services/friend_repository.dart';
import '../services/models.dart';
import '../services/user_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/common.dart';
import '../widgets/header.dart';
import '../widgets/yno_scaffold.dart';

/// The tabs of the Community hub.
enum _CommunityTab { friends, global, contacts }

/// Whether the **global** points leaderboard is shown.
///
/// Off until the player base passes ~[kGlobalLeaderboardMinUsers]: a global
/// ranking over a handful of accounts is noise, and being "#3 in the world" out
/// of nine players devalues it. Flip this to `true` to bring the tab back — the
/// section, its queries and its add-friend pill are all still here and compiled,
/// nothing needs rebuilding.
const bool kGlobalLeaderboardEnabled = false;

/// The player count the global board is waiting on (product decision, 2026-08-03).
const int kGlobalLeaderboardMinUsers = 500;

/// Community hub (Section 4).
///
/// A **friends leaderboard**, the **global** points leaderboard (currently
/// disabled — see [kGlobalLeaderboardEnabled]), and **Contacts** — match your
/// phone contacts against registered players so you can add the people you
/// already know.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  static const _stats = ['goals', 'matches', 'winRate', 'motm'];
  List<String> get _statLabels =>
      [tr('social.goals'), tr('social.matches'), tr('social.winPct'), tr('social.motm')];
  List<String> get _frames =>
      [tr('social.weekly'), tr('social.monthly'), tr('social.allTime')];

  /// Which tab is showing — an index into [_tabs], NOT a fixed 0/1/2. Going
  /// through [_CommunityTab] means hiding a tab can't silently re-point the
  /// others at the wrong section.
  int _mode = 0;
  int _statIndex = 0;
  int _frameIndex = 2;

  /// The tabs actually on screen. Global is filtered out while it is disabled.
  List<_CommunityTab> get _tabs => [
        _CommunityTab.friends,
        if (kGlobalLeaderboardEnabled) _CommunityTab.global,
        _CommunityTab.contacts,
      ];

  String _tabLabel(_CommunityTab t) => switch (t) {
        _CommunityTab.friends => tr('drawer.friends'),
        _CommunityTab.global => tr('social.global'),
        _CommunityTab.contacts => tr('social.contacts'),
      };

  String get _uid => AuthRepository.instance.uid ?? '';
  String _myName = tr('social.aPlayer');

  // Memoise the friends-leaderboard future so unrelated rebuilds don't refetch.
  String _fKey = '';
  Future<List<AppUser>>? _fFuture;

  // Contacts state.
  bool _contactsLoading = false;
  bool _contactsDone = false;
  String? _contactsError;
  List<AppUser> _contactMatches = const [];
  final _requested = <String>{};

  @override
  void initState() {
    super.initState();
    if (_uid.isNotEmpty) {
      UserRepository.instance.getUser(_uid).then((u) {
        if (mounted && u != null) {
          setState(() => _myName = u.name.isEmpty ? u.handle : u.name);
        }
      });
    }
  }

  Future<List<AppUser>> _friendsBoard() {
    final key = '${_uid}_${_stats[_statIndex]}';
    if (key != _fKey || _fFuture == null) {
      _fKey = key;
      _fFuture = FriendRepository.instance
          .friendsLeaderboard(_uid, stat: _stats[_statIndex]);
    }
    return _fFuture!;
  }

  String _statValue(AppUser u) => switch (_stats[_statIndex]) {
        'matches' => '${u.matchesPlayed}',
        'winRate' => '${u.winRate}%',
        'motm' => '${u.totalMotm}',
        _ => '${u.careerGoals}',
      };

  @override
  Widget build(BuildContext context) {
    return YnoScaffold(
      // Titled "Your Friends" (client, 2026-08-18) — the page is the friends
      // hub, and "Community" read as something bigger than it is. The file and
      // class keep the Community name: `friends_screen.dart` already exists and
      // is a different page (requests + search), so renaming this one would be
      // actively confusing.
      appBarTitle: tr('nav.yourFriends'),
      child: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
          children: [
            SegmentedTabs(
              tabs: [for (final t in _tabs) _tabLabel(t)],
              index: _mode,
              onChanged: (i) => setState(() => _mode = i),
            ),
            const SizedBox(height: 16),
            ...switch (_tabs[_mode]) {
              _CommunityTab.friends => _friendsSection(),
              _CommunityTab.global => _globalSection(),
              _CommunityTab.contacts => _contactsSection(),
            },
          ],
        ),
      ),
    );
  }

  // ---- Friends leaderboard ----------------------------------------------

  List<Widget> _friendsSection() {
    return [
      SegmentedTabs(
        tabs: _statLabels,
        index: _statIndex,
        fontSize: 12.5,
        onChanged: (i) => setState(() => _statIndex = i),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Text('${tr('social.rankedBy')} ${_statLabels[_statIndex].toUpperCase()}',
              style: AppText.label()),
          const Spacer(),
          for (int i = 0; i < _frames.length; i++)
            GestureDetector(
              onTap: () => setState(() => _frameIndex = i),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(_frames[i].toUpperCase(),
                    style: AppText.barlow(
                        size: 10.5,
                        weight: i == _frameIndex
                            ? FontWeight.w800
                            : FontWeight.w400,
                        color:
                            i == _frameIndex ? AppColors.txt : AppColors.dim2)),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (_uid.isEmpty)
        _empty(tr('social.signInLeaderboard'))
      else
        FutureBuilder<List<AppUser>>(
          future: _friendsBoard(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final users = snap.data ?? const <AppUser>[];
            if (users.length <= 1) {
              return _empty(tr('social.buildLeaderboard'));
            }
            return Column(
              children: [
                for (int i = 0; i < users.length; i++)
                  _row(i + 1, users[i], _statValue(users[i]),
                      users[i].uid == _uid),
              ],
            );
          },
        ),
    ];
  }

  // ---- Global leaderboard -----------------------------------------------

  List<Widget> _globalSection() {
    return [
      SectionLabel(tr('social.globalRankedByPoints')),
      const SizedBox(height: 12),
      // The friendship edges drive each row's Add / Pending / Friends pill.
      StreamBuilder<List<FriendEdge>>(
        stream: _uid.isEmpty
            ? const Stream.empty()
            : FriendRepository.instance.watchMyEdges(_uid),
        builder: (context, esnap) {
          final statusByUid = <String, FriendStatus>{};
          for (final e in esnap.data ?? const <FriendEdge>[]) {
            final other = e.other(_uid);
            if (other.isNotEmpty) statusByUid[other] = e.status;
          }
          return StreamBuilder<List<AppUser>>(
            stream: UserRepository.instance.watchTopUsers(limit: 50),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              // The global board is for discovering OTHER players — hide myself.
              final users = (snap.data ?? const <AppUser>[])
                  .where((u) => u.uid != _uid)
                  .toList();
              if (users.isEmpty) {
                return _empty(tr('social.noPlayersYet'));
              }
              return Column(
                children: [
                  for (int i = 0; i < users.length; i++)
                    _row(i + 1, users[i], '${users[i].points}', false,
                        coin: true,
                        friendState: statusByUid[users[i].uid],
                        onAdd: () => _addFriend(users[i])),
                ],
              );
            },
          );
        },
      ),
    ];
  }

  // ---- Contacts on YNO --------------------------------------------------

  List<Widget> _contactsSection() {
    return [
      SectionLabel(tr('social.peopleYouKnow')),
      const SizedBox(height: 6),
      Text(
          tr('social.contactsPrivacy'),
          style: AppText.barlow(size: 12, color: AppColors.dim2, height: 1.4)),
      const SizedBox(height: 14),
      if (!_contactsDone)
        GestureDetector(
          onTap: _contactsLoading ? null : _findFromContacts,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line2, width: 1.5)),
            alignment: Alignment.center,
            child: Text(
                _contactsLoading ? tr('social.checkingContacts') : '📇  ${tr('social.findFromContacts')}',
                style: AppText.barlow(size: 15, weight: FontWeight.w700)),
          ),
        ),
      if (_contactsError != null) ...[
        const SizedBox(height: 14),
        _empty(_contactsError!),
      ],
      if (_contactsDone && _contactsError == null) ...[
        const SizedBox(height: 4),
        if (_contactMatches.isEmpty)
          _empty(tr('social.noContactsOnYno'))
        else
          Column(
            children: [
              for (final u in _contactMatches) _contactRow(u),
            ],
          ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _findFromContacts,
          child: Center(
            child: Text('↻ ${tr('social.refreshContacts')}',
                style: AppText.barlow(
                    size: 13, weight: FontWeight.w700, color: AppColors.dim)),
          ),
        ),
      ],
    ];
  }

  Widget _contactRow(AppUser u) {
    final requested = _requested.contains(u.uid);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, Routes.profilePublic,
                arguments: u.uid),
            child: InitialsAvatar(
                initials: u.initials, size: 42, fontSize: 15, photoUrl: u.photoUrl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(u.name.isEmpty ? u.handle : u.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.barlow(size: 15, weight: FontWeight.w700)),
                Text(u.phone == null || u.phone!.isEmpty ? '@${u.handle}' : u.phone!,
                    style: AppText.barlow(size: 12, color: AppColors.dim2)),
              ],
            ),
          ),
          GestureDetector(
            onTap: requested ? null : () => _addFriend(u),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: requested ? AppColors.line : AppColors.primary,
                      width: requested ? 1 : 1.5)),
              child: Text(requested ? tr('social.requested') : '＋ ${tr('common.add')}',
                  style: AppText.barlow(
                      size: 13,
                      weight: FontWeight.w800,
                      color: requested ? AppColors.dim : AppColors.txt)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addFriend(AppUser u) async {
    setState(() => _requested.add(u.uid));
    await FriendRepository.instance.sendRequest(_uid, u.uid, myName: _myName);
    if (mounted) showYnoToast(context, '${tr('social.requestSentTo')} ${u.name}');
  }

  /// Ask for contacts permission, read numbers, and match them against the
  /// registered player base. The lookup itself lives in
  /// `services/contact_matcher.dart` — the Friends page runs the same one.
  Future<void> _findFromContacts() async {
    if (_uid.isEmpty) return;
    setState(() {
      _contactsLoading = true;
      _contactsError = null;
    });
    final lookup = await findRegisteredContacts(_uid);
    if (!mounted) return;
    setState(() {
      _contactsLoading = false;
      _contactsDone = lookup.ok;
      _contactMatches = lookup.matches;
      _contactsError = switch (lookup.status) {
        ContactLookupStatus.ok => null,
        ContactLookupStatus.permissionDenied =>
          tr('social.contactsPermissionDenied'),
        ContactLookupStatus.failed => tr('social.couldNotReadContacts'),
      };
    });
  }

  // ---- Shared row -------------------------------------------------------

  Widget _row(int rank, AppUser u, String value, bool isMe,
      {bool coin = false, FriendStatus? friendState, VoidCallback? onAdd}) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, Routes.profilePublic,
          arguments: u.uid),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryGlow(0.06) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isMe ? AppColors.primary : AppColors.line,
              width: isMe ? 1.6 : 1),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text('$rank',
                  textAlign: TextAlign.center,
                  style: AppText.condensed(
                      size: 18,
                      weight: FontWeight.w800,
                      color: AppColors.dim)),
            ),
            const SizedBox(width: 8),
            InitialsAvatar(
                initials: u.initials,
                size: 42,
                fontSize: 15,
                photoUrl: u.photoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(u.name.isEmpty ? tr('social.playerFallback') : u.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.barlow(
                                size: 15, weight: FontWeight.w700)),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Text(tr('common.you'),
                            style: AppText.barlow(
                                size: 10,
                                weight: FontWeight.w800,
                                color: AppColors.dim)),
                      ],
                    ],
                  ),
                  Text(u.position ?? tr('social.outfieldPlayer'),
                      style:
                          AppText.barlow(size: 12, color: AppColors.dim2)),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (coin) ...[
                  const Text('🪙', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 5),
                ],
                Text(value,
                    style: AppText.condensed(
                        size: 18, weight: FontWeight.w800)),
                if (onAdd != null && !isMe) ...[
                  const SizedBox(width: 10),
                  _friendPill(u, friendState, onAdd),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Add / Pending / Friends control shown on the global leaderboard rows.
  Widget _friendPill(AppUser u, FriendStatus? state, VoidCallback onAdd) {
    final friends = state == FriendStatus.accepted;
    final pending = state == FriendStatus.pending || _requested.contains(u.uid);
    final label = friends
        ? '✓'
        : pending
            ? tr('social.pending')
            : '＋';
    final muted = friends || pending;
    return GestureDetector(
      onTap: muted ? null : onAdd,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
              color: muted ? AppColors.line : AppColors.primary,
              width: muted ? 1 : 1.5),
        ),
        child: Text(label,
            style: AppText.barlow(
                size: 12,
                weight: FontWeight.w800,
                color: muted ? AppColors.dim : AppColors.txt)),
      ),
    );
  }

  Widget _empty(String msg) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Center(
          child: Text(msg,
              textAlign: TextAlign.center,
              style: AppText.barlow(size: 14, color: AppColors.dim)),
        ),
      );
}
