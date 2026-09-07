import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/feedback_repository.dart';
import '../services/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/common.dart';
import '../widgets/confirm.dart';
import 'admin_repository.dart';

/// The super-admin control panel: view every user and team, delete individually,
/// or wipe users / teams / all data. Web-only, English-only (internal tool).
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _repo = AdminRepository.instance;
  final _search = TextEditingController();
  // Owned here rather than by _typeToConfirm: `showDialog` completes when the
  // route is popped, not when it has finished animating out, so disposing after
  // the await can kill a controller the TextField is still rebuilding with.
  // See SESSION_PROGRESS §72/§73.
  final _typeConfirm = TextEditingController();
  String _query = '';
  int _countsKey = 0; // bump to refresh the summary counts
  // Matches tab status filter: 'all' | 'live' | 'lobby' | 'done'.
  String _matchFilter = 'all';
  /// 'all' | 'open' | 'bug' | 'suggestion' — applied in memory, see _feedbackTab.
  String _feedbackFilter = 'all';

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      setState(() => _query = _search.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _typeConfirm.dispose();
    super.dispose();
  }

  void _refreshCounts() => setState(() => _countsKey++);

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: AppText.barlow(size: 14)),
        backgroundColor: AppColors.surface2,
      ));
  }

  /// Show the outcome of a bulk delete in a dialog so failures (e.g.
  /// permission-denied when the rules aren't deployed) are impossible to miss.
  Future<void> _showResult(String action, DeleteResult res) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            side: BorderSide(color: AppColors.line2)),
        title: Text(res.allOk ? 'Done' : 'Completed with errors',
            style: AppText.condensed(
                size: 20,
                weight: FontWeight.w800,
                color: res.allOk ? AppColors.primary : AppColors.loss)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$action\n\nDeleted: ${res.deleted}   Failed: ${res.failed}',
                style: AppText.barlow(size: 14, height: 1.5)),
            if (!res.allOk && res.firstError != null) ...[
              const SizedBox(height: 12),
              Text('First error:',
                  style: AppText.barlow(
                      size: 12, weight: FontWeight.w700, color: AppColors.loss)),
              const SizedBox(height: 4),
              Text(res.firstError!,
                  style:
                      AppText.barlow(size: 12, color: AppColors.dim, height: 1.4)),
              const SizedBox(height: 12),
              Text(
                  'If this says permission-denied, deploy the rules:\n'
                  'firebase deploy --only firestore:rules --project yno-app-e96f5',
                  style: AppText.barlow(
                      size: 12, color: AppColors.dim2, height: 1.4)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('OK',
                style: AppText.barlow(
                    weight: FontWeight.w800, color: AppColors.txt)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('YNO · SUPER ADMIN',
                  style: AppText.condensed(size: 20, weight: FontWeight.w800)),
              Builder(builder: (_) {
                final u = FirebaseAuth.instance.currentUser;
                final signedIn = u != null;
                return Text(
                  signedIn
                      ? 'signed in as ${u.email ?? u.uid}'
                      : '⚠ NOT SIGNED IN — deletes will fail',
                  style: AppText.barlow(
                      size: 11,
                      color: signedIn ? AppColors.dim2 : AppColors.loss),
                );
              }),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout, color: AppColors.txt),
              onPressed: () => FirebaseAuth.instance.signOut(),
            ),
          ],
          bottom: const TabBar(
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            unselectedLabelColor: AppColors.dim,
            isScrollable: true,
            tabs: [
              Tab(text: 'USERS'),
              Tab(text: 'TEAMS'),
              Tab(text: 'MATCHES'),
              Tab(text: 'FEEDBACK'),
              Tab(text: 'DANGER ZONE'),
            ],
          ),
        ),
        body: Column(
          children: [
            _summaryBar(),
            const Divider(height: 1, color: AppColors.line),
            Expanded(
              child: TabBarView(
                children: [
                  _usersTab(),
                  _teamsTab(),
                  _matchesTab(),
                  _feedbackTab(),
                  _dangerTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Summary ----------------------------------------------------------

  Widget _summaryBar() {
    return FutureBuilder<Map<String, int>>(
      key: ValueKey(_countsKey),
      future: _repo.counts(),
      builder: (context, snap) {
        final c = snap.data ?? const {};
        Widget chip(String label, String key) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${c[key] ?? '—'}',
                        style: AppText.condensed(
                            size: 18,
                            weight: FontWeight.w800,
                            color: AppColors.primary)),
                    const SizedBox(width: 6),
                    Text(label.toUpperCase(),
                        style:
                            AppText.barlow(size: 11, color: AppColors.dim2)),
                  ],
                ),
              ),
            );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              chip('users', 'users'),
              chip('teams', 'teams'),
              chip('matches', 'matches'),
              chip('guests', 'guests'),
              chip('friendships', 'friendships'),
              IconButton(
                tooltip: 'Refresh counts',
                onPressed: _refreshCounts,
                icon: const Icon(Icons.refresh, color: AppColors.dim),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---- Users ------------------------------------------------------------

  Widget _usersTab() {
    return Column(
      children: [
        _searchField('Search users by name, @username or email…'),
        Expanded(
          child: StreamBuilder<List<AppUser>>(
            stream: _repo.watchUsers(),
            builder: (context, snap) {
              if (snap.hasError) {
                return _errorState('Could not load users.\n${snap.error}');
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var users = snap.data!;
              if (_query.isNotEmpty) {
                users = users
                    .where((u) =>
                        u.name.toLowerCase().contains(_query) ||
                        u.username.toLowerCase().contains(_query) ||
                        u.email.toLowerCase().contains(_query))
                    .toList();
              }
              users.sort((a, b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()));
              if (users.isEmpty) return _emptyState('No users.');
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: users.length,
                itemBuilder: (context, i) => _userCard(users[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _userCard(AppUser u) {
    return _card(
      leading: InitialsAvatar(
          initials: u.initials, size: 42, fontSize: 15, photoUrl: u.photoUrl),
      title: u.name.isEmpty ? '(no name)' : u.name,
      subtitleLines: [
        '@${u.handle}',
        if (u.email.isNotEmpty) u.email,
        if (u.phone != null && u.phone!.isNotEmpty) u.phone!,
        '${u.points} pts · ${u.matchesPlayed} matches',
      ],
      badges: [
        if (u.autoCreated) 'auto-created',
        if (u.deactivated) 'deactivated',
      ],
      onDelete: () async {
        final ok = await showConfirm(
          context,
          title: 'Delete user?',
          message:
              'Delete ${u.name.isEmpty ? u.email : u.name} and all their data? '
              'This removes their profile and subcollections. Their login (if any) '
              'is not removed but will no longer resolve to a profile.',
          confirmLabel: 'Delete',
          danger: true,
        );
        if (!ok) return;
        try {
          final res = await _repo.deleteUser(u.uid);
          _toast(res.allOk
              ? 'Deleted ${u.name.isEmpty ? u.email : u.name}.'
              : res.summary());
          _refreshCounts();
        } catch (e) {
          _toast('Delete failed: $e');
        }
      },
    );
  }

  // ---- Teams ------------------------------------------------------------

  Widget _teamsTab() {
    return StreamBuilder<List<TeamModel>>(
      stream: _repo.watchTeams(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _errorState('Could not load teams.\n${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final teams = snap.data!
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        if (teams.isEmpty) return _emptyState('No teams.');
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          itemCount: teams.length,
          itemBuilder: (context, i) => _teamCard(teams[i]),
        );
      },
    );
  }

  Widget _teamCard(TeamModel t) {
    return _card(
      leading: InitialsAvatar(initials: _teamInitials(t.name), size: 42, fontSize: 15),
      title: t.name.isEmpty ? '(no name)' : t.name,
      subtitleLines: [
        '${t.memberUids.length} members',
        'owner: ${t.ownerUid}',
      ],
      badges: [
        t.isPublic ? 'public' : 'private',
        if (t.disbanded) 'disbanded',
      ],
      onDelete: () async {
        final ok = await showConfirm(
          context,
          title: 'Delete team?',
          message:
              'Delete "${t.name}" and its invite code, invites and guests? '
              'This cannot be undone.',
          confirmLabel: 'Delete',
          danger: true,
        );
        if (!ok) return;
        try {
          final res = await _repo.deleteTeam(t.id);
          _toast(res.allOk ? 'Deleted "${t.name}".' : res.summary());
          _refreshCounts();
        } catch (e) {
          _toast('Delete failed: $e');
        }
      },
    );
  }

  // ---- Matches ----------------------------------------------------------

  Widget _matchesTab() {
    return Column(
      children: [
        _searchField('Search matches by team, location or format…'),
        _matchFilterRow(),
        Expanded(
          child: StreamBuilder<List<MatchModel>>(
            stream: _repo.watchMatches(),
            builder: (context, snap) {
              if (snap.hasError) {
                return _errorState('Could not load matches.\n${snap.error}');
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var matches = snap.data!.where((m) {
                switch (_matchFilter) {
                  case 'live':
                    return m.status == MatchStatus.live;
                  case 'lobby':
                    return m.status == MatchStatus.lobby;
                  case 'done':
                    return m.status == MatchStatus.ended ||
                        m.status == MatchStatus.abandoned;
                  default:
                    return true;
                }
              }).toList();
              if (_query.isNotEmpty) {
                matches = matches
                    .where((m) =>
                        '${m.teamAName} ${m.teamBName} ${m.location} ${m.format}'
                            .toLowerCase()
                            .contains(_query))
                    .toList();
              }
              matches.sort((a, b) => (b.createdAt ?? DateTime(0))
                  .compareTo(a.createdAt ?? DateTime(0)));
              if (matches.isEmpty) return _emptyState('No matches.');
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: matches.length,
                itemBuilder: (context, i) => _matchCard(matches[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _matchFilterRow() {
    Widget chip(String label, String value) {
      final selected = _matchFilter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _matchFilter = value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surface,
              border: Border.all(
                  color: selected ? AppColors.primary : AppColors.line),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(label,
                style: AppText.barlow(
                    size: 12,
                    weight: FontWeight.w700,
                    color: selected ? AppColors.ink : AppColors.dim)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Row(
        children: [
          chip('All', 'all'),
          chip('Ongoing', 'live'),
          chip('Drafts', 'lobby'),
          chip('Played', 'done'),
        ],
      ),
    );
  }

  Widget _matchCard(MatchModel m) {
    return _card(
      leading: _matchStatusChip(m.status),
      title: '${m.teamAName} vs ${m.teamBName}',
      subtitleLines: [
        if (m.name.isNotEmpty && m.name != '${m.teamAName} vs ${m.teamBName}')
          m.name,
        [
          if (m.format.isNotEmpty) m.format,
          if (m.surface.isNotEmpty) m.surface,
          if (m.location.isNotEmpty) '📍 ${m.location}',
        ].join(' · '),
        'score ${m.scoreA}–${m.scoreB} · code ${m.code}',
        if (m.createdAt != null) 'created ${_fmtDate(m.createdAt!)}',
      ],
      badges: const [],
      onDelete: () async {
        final ok = await showConfirm(
          context,
          title: 'Delete match?',
          message:
              'Delete "${m.teamAName} vs ${m.teamBName}" and all its events '
              '(players, goals, cards, subs, votes)? This cannot be undone.',
          confirmLabel: 'Delete',
          danger: true,
        );
        if (!ok) return;
        try {
          final res = await _repo.deleteMatch(m.id);
          _toast(res.allOk
              ? 'Deleted "${m.teamAName} vs ${m.teamBName}".'
              : res.summary());
          _refreshCounts();
        } catch (e) {
          _toast('Delete failed: $e');
        }
      },
    );
  }

  Widget _matchStatusChip(MatchStatus status) {
    final (label, color) = switch (status) {
      MatchStatus.live => ('LIVE', AppColors.primary),
      MatchStatus.lobby => ('DRAFT', AppColors.gold),
      MatchStatus.ended => ('FT', AppColors.dim),
      MatchStatus.abandoned => ('ABD', AppColors.loss),
    };
    return Container(
      width: 46,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: AppText.condensed(
              size: 13, weight: FontWeight.w800, color: color)),
    );
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  // ---- Danger zone ------------------------------------------------------

  // ---- Feedback (bug reports + suggestions from the app's side drawer) ----

  /// Bug reports and suggestions, newest first.
  ///
  /// Filtered in memory rather than by query: a `where` on type or status
  /// alongside the `orderBy` needs a composite index, and this collection is
  /// small enough that maintaining one would cost more than it saves. See
  /// [FeedbackRepository.watchAll].
  Widget _feedbackTab() {
    return Column(
      children: [
        _searchField('Search feedback by text, name or email…'),
        _feedbackFilterRow(),
        Expanded(
          child: StreamBuilder<List<FeedbackReport>>(
            stream: FeedbackRepository.instance.watchAll(),
            builder: (context, snap) {
              if (snap.hasError) {
                // The likeliest cause by far is rules: `feedback` is readable
                // only by the super-admin, so a panel signed in as anyone else
                // gets permission-denied here and nowhere else.
                return _errorState(
                    'Could not load feedback.\n${snap.error}');
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var items = snap.data!.where((f) {
                switch (_feedbackFilter) {
                  case 'bug':
                    return f.type == FeedbackType.bug;
                  case 'suggestion':
                    return f.type == FeedbackType.suggestion;
                  case 'open':
                    return !f.isResolved;
                  default:
                    return true;
                }
              }).toList();
              if (_query.isNotEmpty) {
                items = items
                    .where((f) =>
                        f.message.toLowerCase().contains(_query) ||
                        f.userName.toLowerCase().contains(_query) ||
                        f.userEmail.toLowerCase().contains(_query))
                    .toList();
              }
              if (items.isEmpty) {
                return _emptyState(_query.isNotEmpty || _feedbackFilter != 'all'
                    ? 'Nothing matches that filter.'
                    : 'No feedback yet.');
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
                children: [
                  // Open count up front: the only number an admin opening this
                  // tab actually wants is "how many still need me".
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, left: 2),
                    child: Text(
                        '${items.where((f) => !f.isResolved).length} open · '
                        '${items.length} shown',
                        style: AppText.barlow(
                            size: 12, color: AppColors.dim2)),
                  ),
                  ...items.map(_feedbackCard),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _feedbackFilterRow() {
    Widget chip(String label, String value) {
      final selected = _feedbackFilter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _feedbackFilter = value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surface,
              border: Border.all(
                  color: selected ? AppColors.primary : AppColors.line),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(label,
                style: AppText.barlow(
                    size: 12,
                    weight: FontWeight.w700,
                    color: selected ? AppColors.ink : AppColors.dim)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      child: Row(
        children: [
          chip('All', 'all'),
          chip('Open', 'open'),
          chip('🐞 Bugs', 'bug'),
          chip('💡 Suggestions', 'suggestion'),
        ],
      ),
    );
  }

  /// One report.
  ///
  /// Deliberately NOT the shared [_card]: that clamps every subtitle line to
  /// `maxLines: 1`, which is right for a user or a match row and useless here —
  /// the message is the entire content, and a truncated bug report cannot be
  /// acted on.
  Widget _feedbackCard(FeedbackReport f) {
    final isBug = f.type == FeedbackType.bug;
    final meta = <String>[
      if (f.userName.isNotEmpty) f.userName,
      if (f.userEmail.isNotEmpty) f.userEmail,
      if (f.appVersion.isNotEmpty) 'v${f.appVersion}',
      if (f.platform.isNotEmpty) f.platform,
      if (f.createdAt != null) _fmtDate(f.createdAt!),
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        // Resolved reports stay in the list but stop shouting: a muted border
        // is enough to tell them apart while scrolling.
        border: Border.all(
            color: f.isResolved ? AppColors.line : AppColors.line2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(isBug ? '🐞 BUG' : '💡 SUGGESTION',
                    style: AppText.barlow(
                        size: 10,
                        weight: FontWeight.w800,
                        color: isBug ? AppColors.loss : AppColors.primary)),
              ),
              if (f.isResolved) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('RESOLVED',
                      style: AppText.barlow(
                          size: 10,
                          weight: FontWeight.w800,
                          color: AppColors.dim2)),
                ),
              ],
              const Spacer(),
              // Reversible on purpose — "resolved" gets tapped by accident, and
              // there is no undo anywhere else on this screen.
              TextButton(
                onPressed: () => _setFeedbackStatus(f),
                child: Text(f.isResolved ? 'Reopen' : 'Mark resolved',
                    style: AppText.barlow(
                        size: 12,
                        weight: FontWeight.w800,
                        color: AppColors.txt)),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () => _deleteFeedback(f),
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.loss, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // The message in full. `SelectableText` so an admin can copy a stack
          // trace or a phrase out of it — this is the one screen where the text
          // is the artefact.
          SelectableText(f.message,
              style: AppText.barlow(size: 14, height: 1.5)),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(meta,
                style: AppText.barlow(size: 11.5, color: AppColors.dim2)),
          ],
        ],
      ),
    );
  }

  Future<void> _setFeedbackStatus(FeedbackReport f) async {
    try {
      await FeedbackRepository.instance.setStatus(
        f.id,
        f.isResolved ? FeedbackStatus.open : FeedbackStatus.resolved,
      );
    } catch (e) {
      _toast('Could not update: $e');
    }
  }

  Future<void> _deleteFeedback(FeedbackReport f) async {
    final ok = await showConfirm(
      context,
      title: 'Delete this feedback?',
      message: 'This removes the report permanently. It cannot be undone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!ok) return;
    try {
      await FeedbackRepository.instance.delete(f.id);
      _toast('Deleted.');
    } catch (e) {
      _toast('Delete failed: $e');
    }
  }

  Widget _dangerTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        Text('Danger Zone',
            style: AppText.condensed(
                size: 26, weight: FontWeight.w800, color: AppColors.loss)),
        const SizedBox(height: 6),
        Text(
            'These actions permanently delete data from live Firebase and cannot '
            'be undone. Each asks you to type DELETE ALL to confirm.',
            style: AppText.barlow(size: 13, color: AppColors.dim, height: 1.5)),
        const SizedBox(height: 20),
        _dangerButton(
          'Delete ALL users',
          'Every user profile and its subcollections will be removed.',
          () => _repo.deleteAllUsers(),
        ),
        _dangerButton(
          'Delete ALL teams',
          'Every team, its subcollections and all team codes will be removed.',
          () => _repo.deleteAllTeams(),
        ),
        _dangerButton(
          'Delete ALL data',
          'Wipes users, teams, matches, guests, friendships and rivalries — the '
              'entire app database. The super-admin login itself is kept.',
          () => _repo.deleteAllData(),
        ),
      ],
    );
  }

  Widget _dangerButton(
      String label, String desc, Future<DeleteResult> Function() run) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.loss.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppText.barlow(
                  size: 16, weight: FontWeight.w800, color: AppColors.loss)),
          const SizedBox(height: 4),
          Text(desc,
              style: AppText.barlow(size: 13, color: AppColors.dim, height: 1.4)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.loss),
              onPressed: () async {
                final ok = await _typeToConfirm(label);
                if (!ok) return;
                _toast('Working… this can take a moment.');
                try {
                  final res = await run();
                  _showResult(label, res);
                  _refreshCounts();
                } catch (e) {
                  _toast('Failed: $e');
                }
              },
              child: Text(label, style: AppText.barlow(weight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  /// A stronger gate than [showConfirm]: the exact phrase must be typed.
  Future<bool> _typeToConfirm(String action) async {
    const phrase = 'DELETE ALL';
    final ctrl = _typeConfirm..clear();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setLocal) {
          final matches = ctrl.text.trim() == phrase;
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: const RoundedRectangleBorder(
                side: BorderSide(color: AppColors.line2)),
            title: Text(action,
                style: AppText.condensed(size: 20, weight: FontWeight.w800)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type "$phrase" to confirm. This is irreversible.',
                    style: AppText.barlow(
                        size: 14, color: AppColors.dim, height: 1.5)),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  onChanged: (_) => setLocal(() {}),
                  style: AppText.barlow(size: 15),
                  decoration: const InputDecoration(hintText: phrase),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: Text('Cancel',
                    style: AppText.barlow(
                        weight: FontWeight.w700, color: AppColors.dim)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.loss),
                onPressed:
                    matches ? () => Navigator.pop(dialogCtx, true) : null,
                child: Text('Delete',
                    style: AppText.barlow(weight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
    return ok ?? false;
  }

  // ---- Shared bits ------------------------------------------------------

  Widget _searchField(String hint) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: TextField(
          controller: _search,
          style: AppText.barlow(size: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search, color: AppColors.dim),
            isDense: true,
          ),
        ),
      );

  Widget _card({
    required Widget leading,
    required String title,
    required List<String> subtitleLines,
    required List<String> badges,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.barlow(
                              size: 15, weight: FontWeight.w800)),
                    ),
                    ...badges.map((b) => Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(b,
                                style: AppText.barlow(
                                    size: 10, color: AppColors.dim2)),
                          ),
                        )),
                  ],
                ),
                const SizedBox(height: 2),
                ...subtitleLines.map((s) => Text(s,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.barlow(size: 12, color: AppColors.dim))),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: AppColors.loss),
          ),
        ],
      ),
    );
  }

  String _teamInitials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Widget _emptyState(String msg) => Center(
        child: Text(msg, style: AppText.barlow(size: 14, color: AppColors.dim)),
      );

  Widget _errorState(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(msg,
              textAlign: TextAlign.center,
              style: AppText.barlow(size: 13, color: AppColors.loss)),
        ),
      );
}
