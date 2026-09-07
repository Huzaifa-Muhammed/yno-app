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
import '../widgets/inputs.dart';
import '../widgets/motion.dart';
import '../widgets/yno_scaffold.dart';

/// Friends & requests hub (Section 4).
///
/// Three lists derived from [FriendRepository.watchMyEdges] — accepted friends,
/// requests received and requests sent — plus a username/name **search** path
/// (Way 1) and an opt-in **contact sync** toggle. Each friend row opens their
/// public profile and offers a side-by-side Compare.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchCtrl = TextEditingController();

  AppUser? _me;
  String get _uid => AuthRepository.instance.uid ?? '';

  // Search.
  List<AppUser> _results = const [];
  bool _searching = false;
  String _lastQuery = '';

  // Contact sync (opt-in, off by default). Switched on in Settings, not here.
  bool _contactSync = false;
  bool _syncing = false;
  String? _syncError;
  List<AppUser> _contactMatches = const [];

  // Optimistic pending set (uids we just sent a request to).
  final _justSent = <String>{};

  // Name cache for edge counter-parties, memoised by the uid-set key.
  String _usersKey = '';
  Future<List<AppUser>>? _usersFuture;

  @override
  void initState() {
    super.initState();
    final uid = AuthRepository.instance.uid;
    if (uid != null) {
      UserRepository.instance.getUser(uid).then((u) {
        if (!mounted) return;
        setState(() {
          _me = u;
          _contactSync = u?.contactSync ?? false;
        });
        if (_contactSync) _runContactSync();
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _myName => _me?.name ?? _me?.username ?? tr('social.aPlayer');

  Future<void> _runSearch() async {
    final q = _searchCtrl.text.trim();
    if (q == _lastQuery && _results.isNotEmpty) return;
    _lastQuery = q;
    if (q.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _searching = true);
    final res = await UserRepository.instance.search(q);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _results = res.where((u) => u.uid != _uid).toList();
    });
  }

  /// Contact sync is switched on in **Settings only** — this page just reflects
  /// it. Open Settings, then re-read the flag on the way back so flipping it
  /// there takes effect here immediately.
  Future<void> _openSettings() async {
    await Navigator.of(context).pushNamed(Routes.settings);
    if (!mounted) return;
    final me = await UserRepository.instance.getUser(_uid);
    if (!mounted) return;
    setState(() {
      _me = me ?? _me;
      _contactSync = me?.contactSync ?? false;
    });
    if (_contactSync && _contactMatches.isEmpty) _runContactSync();
  }

  /// Match the device address book against registered players. Contacts are
  /// never stored — see `services/contact_matcher.dart`, which the Community
  /// Contacts tab shares. (This used to match against a hard-coded empty list,
  /// so the section could only ever report "nobody found".)
  Future<void> _runContactSync() async {
    setState(() {
      _syncing = true;
      _syncError = null;
    });
    final lookup = await findRegisteredContacts(_uid);
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _contactMatches = lookup.matches;
      _syncError = switch (lookup.status) {
        ContactLookupStatus.ok => null,
        ContactLookupStatus.permissionDenied =>
          tr('social.contactsPermissionDenied'),
        ContactLookupStatus.failed => tr('social.couldNotReadContacts'),
      };
    });
  }

  Future<void> _sendRequest(String target) async {
    setState(() => _justSent.add(target));
    await FriendRepository.instance
        .sendRequest(_uid, target, myName: _myName);
    if (mounted) showYnoToast(context, tr('social.requestSent'));
  }

  Future<void> _accept(String other) async {
    await FriendRepository.instance
        .acceptRequest(_uid, other, myName: _myName);
    if (mounted) showYnoToast(context, tr('social.friendAdded'));
  }

  Future<void> _remove(String other, String verb) async {
    await FriendRepository.instance.removeOrDecline(_uid, other);
    if (mounted) showYnoToast(context, verb);
  }

  Future<List<AppUser>> _usersFor(List<String> uids) {
    final key = (uids.toList()..sort()).join(',');
    if (key != _usersKey || _usersFuture == null) {
      _usersKey = key;
      _usersFuture = UserRepository.instance.getUsers(uids);
    }
    return _usersFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return YnoScaffold(
      appBarTitle: tr('drawer.friends'),
      child: SafeArea(
        top: false,
        bottom: false,
        child: _uid.isEmpty
            ? Center(child: Text(tr('social.signInToManage')))
            : StreamBuilder<List<FriendEdge>>(
                stream: FriendRepository.instance.watchMyEdges(_uid),
                builder: (context, snap) {
                  final edges = snap.data ?? const <FriendEdge>[];

                  final accepted = <String>[];
                  final received = <String>[]; // pending, they asked me
                  final sent = <String>[]; // pending, I asked them
                  final status = <String, FriendStatus>{};
                  for (final e in edges) {
                    final other = e.other(_uid);
                    if (other.isEmpty) continue;
                    status[other] = e.status;
                    if (e.status == FriendStatus.accepted) {
                      accepted.add(other);
                    } else if (e.requester == _uid) {
                      sent.add(other);
                    } else {
                      received.add(other);
                    }
                  }

                  final allUids = <String>{...accepted, ...received, ...sent}
                      .toList();

                  return FutureBuilder<List<AppUser>>(
                    future: _usersFor(allUids),
                    builder: (context, usnap) {
                      final byUid = {
                        for (final u in usnap.data ?? const <AppUser>[])
                          u.uid: u
                      };
                      AppUser userFor(String uid) =>
                          byUid[uid] ??
                          AppUser(
                              uid: uid,
                              name: tr('social.playerFallback'),
                              email: '');

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                        children: [
                          // ---- Search (Way 1) --------------------------
                          FadeSlideIn(child: _searchSection(status)),

                          const SizedBox(height: 18),

                          // ---- Contact sync ----------------------------
                          FadeSlideIn(
                              delay: const Duration(milliseconds: 80),
                              child: _contactSyncSection(status)),

                          const SizedBox(height: 22),

                          // ---- Requests received -----------------------
                          if (received.isNotEmpty) ...[
                            SectionLabel(
                                '${tr('social.requestsReceived')} · ${received.length}'),
                            const SizedBox(height: 10),
                            for (final uid in received)
                              _requestRow(userFor(uid), incoming: true),
                            const SizedBox(height: 20),
                          ],

                          // ---- Requests sent ---------------------------
                          if (sent.isNotEmpty) ...[
                            SectionLabel('${tr('social.requestsSent')} · ${sent.length}'),
                            const SizedBox(height: 10),
                            for (final uid in sent)
                              _requestRow(userFor(uid), incoming: false),
                            const SizedBox(height: 20),
                          ],

                          // ---- Friends ---------------------------------
                          SectionLabel('${tr('drawer.friends')} · ${accepted.length}'),
                          const SizedBox(height: 10),
                          if (accepted.isEmpty)
                            _emptyBox(tr('social.noFriendsYet'))
                          else
                            for (int i = 0; i < accepted.length; i++)
                              FadeSlideIn(
                                  delay: Duration(milliseconds: 50 * i),
                                  child: _friendRow(userFor(accepted[i]))),
                        ],
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  // ---- Sections ---------------------------------------------------------

  Widget _searchSection(Map<String, FriendStatus> status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(tr('social.addBySearch')),
        const SizedBox(height: 9),
        YnoTextField(
          controller: _searchCtrl,
          hint: tr('social.searchHint'),
          height: 50,
          fontSize: 15,
          textCapitalization: TextCapitalization.none,
          onSubmitted: (_) => _runSearch(),
          leading: const Text('🔍', style: TextStyle(fontSize: 15)),
          trailing: GestureDetector(
            onTap: _runSearch,
            child: Text(tr('common.search'),
                style: AppText.barlow(
                    size: 13,
                    weight: FontWeight.w700,
                    color: AppColors.txt)),
          ),
        ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_lastQuery.isNotEmpty && _results.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('${tr('social.noPlayersFoundFor')} "$_lastQuery".',
                style: AppText.barlow(size: 13, color: AppColors.dim2)),
          )
        else
          for (final u in _results) ...[
            const SizedBox(height: 9),
            _searchResultRow(u, status[u.uid]),
          ],
      ],
    );
  }

  /// Contact sync. The **switch lives in Settings** (one home for the setting),
  /// so when it's off this is a signpost that walks you there rather than a
  /// second toggle that could disagree with the first.
  Widget _contactSyncSection(Map<String, FriendStatus> status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Text('📇', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr('social.contactSync'),
                        style: AppText.barlow(
                            size: 15, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                        _contactSync
                            ? tr('social.contactSyncSubtitle')
                            : tr('social.contactSyncEnableInSettings'),
                        style: AppText.barlow(
                            size: 11, color: AppColors.dim2, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // On → refresh the match list. Off → go turn it on in Settings.
              _contactSyncAction(),
            ],
          ),
        ),
        if (_contactSync) ...[
          const SizedBox(height: 8),
          if (_syncing)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_syncError != null)
            Text(_syncError!,
                style: AppText.barlow(
                    size: 11, color: AppColors.loss, height: 1.4))
          else if (_contactMatches.isEmpty)
            Text(tr('social.noContactsMatched'),
                style: AppText.barlow(
                    size: 11, color: AppColors.dim2, height: 1.4))
          else ...[
            SectionLabel(tr('social.suggestedFromContacts')),
            const SizedBox(height: 8),
            for (final u in _contactMatches) _searchResultRow(u, status[u.uid]),
          ],
        ],
      ],
    );
  }

  Widget _contactSyncAction() {
    final on = _contactSync;
    return GestureDetector(
      onTap: _syncing ? null : (on ? _runContactSync : _openSettings),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: on ? AppColors.line : AppColors.primary,
              width: on ? 1 : 1.5),
        ),
        child: Text(
            on ? tr('social.refresh') : tr('social.openSettings'),
            style: AppText.barlow(
                size: 12.5,
                weight: FontWeight.w800,
                color: on ? AppColors.dim : AppColors.txt)),
      ),
    );
  }

  // ---- Rows -------------------------------------------------------------

  Widget _personBase(AppUser u, {required Widget trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          InitialsAvatar(
              initials: u.initials,
              size: 40,
              fontSize: 14,
              photoUrl: u.photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(u.name.isEmpty ? (u.username.isEmpty ? tr('social.playerFallback') : u.username) : u.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppText.barlow(size: 15, weight: FontWeight.w700)),
                Text(
                    u.username.isNotEmpty
                        ? '@${u.username}'
                        : (u.position ?? tr('social.playerFallback')),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.barlow(size: 12, color: AppColors.dim2)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
  }

  Widget _searchResultRow(AppUser u, FriendStatus? st) {
    final sent = _justSent.contains(u.uid) || st == FriendStatus.pending;
    final friends = st == FriendStatus.accepted;
    Widget btn;
    if (friends) {
      btn = _pill(tr('social.statusFriends'), muted: true);
    } else if (sent) {
      btn = _pill(tr('social.pending'), muted: true);
    } else {
      btn = _tapPill('＋ ${tr('common.add')}', () => _sendRequest(u.uid));
    }
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, Routes.profilePublic,
          arguments: u.uid),
      child: _personBase(u, trailing: btn),
    );
  }

  Widget _requestRow(AppUser u, {required bool incoming}) {
    final Widget trailing;
    if (incoming) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tapPill(tr('social.accept'), () => _accept(u.uid)),
          const SizedBox(width: 7),
          _tapPill('✕', () => _remove(u.uid, tr('social.requestDeclined'))),
        ],
      );
    } else {
      trailing = _tapPill(tr('common.cancel'), () => _remove(u.uid, tr('social.requestCancelled')));
    }
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, Routes.profilePublic,
          arguments: u.uid),
      child: _personBase(u, trailing: trailing),
    );
  }

  Widget _friendRow(AppUser u) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, Routes.profilePublic,
          arguments: u.uid),
      child: _personBase(
        u,
        trailing: _tapPill('⇄ ${tr('social.compare')}',
            () => Navigator.pushNamed(context, Routes.friendCompare,
                arguments: u.uid)),
      ),
    );
  }

  // ---- Bits -------------------------------------------------------------

  Widget _pill(String label, {bool muted = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: muted ? AppColors.line : AppColors.line2),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(label,
            style: AppText.barlow(
                size: 12,
                weight: FontWeight.w700,
                color: muted ? AppColors.dim : AppColors.txt)),
      );

  Widget _tapPill(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: _pill(label),
      );

  Widget _emptyBox(String msg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(msg,
              textAlign: TextAlign.center,
              style: AppText.barlow(size: 13, color: AppColors.dim)),
        ),
      );
}
