import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
import '../services/friend_repository.dart';
import '../services/models.dart';
import '../services/team_repository.dart';
import '../services/user_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/confirm.dart';
import '../widgets/header.dart';
import '../widgets/inputs.dart';
import '../widgets/motion.dart';
import '../widgets/yno_scaffold.dart';

/// Localised label for a team role.
String _roleLabel(TeamRole r) => switch (r) {
      TeamRole.owner => tr('role.owner'),
      TeamRole.captain => tr('role.captain'),
      TeamRole.vice => tr('role.vice'),
      TeamRole.player => tr('role.player'),
    };

class TeamManageScreen extends StatefulWidget {
  const TeamManageScreen({super.key});

  @override
  State<TeamManageScreen> createState() => _TeamManageScreenState();
}

class _TeamManageScreenState extends State<TeamManageScreen> {
  String get _teamId => ModalRoute.of(context)!.settings.arguments as String;

  final _repo = TeamRepository.instance;

  // 🔑 The sheets' text controllers live with the SCREEN, not with each sheet's
  // future. `showModalBottomSheet` completes when the route is popped, not when
  // it has finished animating out, and the sheet keeps rebuilding through that
  // animation — the keyboard collapsing drives it via `viewInsets`. Disposing a
  // controller right after the await therefore killed one the TextField was
  // still rebuilding with. `_confirmDisband` also navigates after its pop, the
  // same second trigger that made the join sheet fail every time
  // (SESSION_PROGRESS §72/§73). Owned here, they cannot outlive their owner.
  // Each sheet clears its controller on open, so nothing carries over.
  final _inviteCtrl = TextEditingController();
  final _guestNameCtrl = TextEditingController();
  final _guestEmailCtrl = TextEditingController();
  final _disbandCtrl = TextEditingController();

  @override
  void dispose() {
    _inviteCtrl.dispose();
    _guestNameCtrl.dispose();
    _guestEmailCtrl.dispose();
    _disbandCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthRepository.instance.uid;
    return YnoScaffold(
      appBarTitle: tr('teams.editTeam'),
      child: SafeArea(
        top: false,
        bottom: false,
        child: StreamBuilder<TeamModel?>(
          stream: _repo.watchTeam(_teamId),
          builder: (context, snap) {
            final team = snap.data;
            if (team == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final amOwner = team.ownerUid == myUid;
            final canManage = myUid != null && team.canManage(myUid);
            if (!canManage) {
              return _noAccess(context);
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Team name & crest are locked at creation — read-only here.
                  Text(team.name.toUpperCase(),
                      style: AppText.barlow(
                          size: 13,
                          weight: FontWeight.w700,
                          color: AppColors.dim)),
                  const SizedBox(height: 16),

                  // ---- Roster ----
                  FadeSlideIn(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionLabel(tr('teams.roster')),
                        const SizedBox(height: 11),
                        _rosterList(team, amOwner),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ghostAction('＋ ${tr('teams.invitePlayer')}',
                                  () => _invitePlayerSheet(team)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ghostAction('＋ ${tr('teams.addGuest')}',
                                  () => _addGuestSheet(team)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---- Join requests (incoming) ----
                  // Only rendered when there is something to answer: an empty
                  // box for a feature most teams never see would be noise.
                  _joinRequests(team),

                  // ---- Pending invites (outgoing) ----
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionLabel(tr('teams.pendingInvites')),
                        const SizedBox(height: 11),
                        _pendingInvites(team),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---- Privacy (owner only) ----
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 240),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (amOwner) ...[
                          SectionLabel(tr('teams.privacy')),
                          const SizedBox(height: 11),
                          _privacyToggle(team),
                          const SizedBox(height: 24),
                          _disbandCard(team),
                        ] else
                          _leaveCard(team, myUid),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _noAccess(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 60, 18, 0),
        child: Center(
          child: Text(tr('teams.noAccess'),
              textAlign: TextAlign.center,
              style: AppText.barlow(size: 14, color: AppColors.dim)),
        ),
      );

  // ---- Roster -----------------------------------------------------------
  Widget _rosterList(TeamModel team, bool amOwner) {
    return FutureBuilder<List<AppUser>>(
      future: UserRepository.instance.getUsers(team.memberUids),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final byId = {for (final u in snap.data!) u.uid: u};
        final ordered = [...team.memberUids]
          ..sort((a, b) =>
              team.roleOf(a).index.compareTo(team.roleOf(b).index));
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (int i = 0; i < ordered.length; i++)
                _memberRow(team, ordered[i], byId[ordered[i]],
                    first: i == 0, amOwner: amOwner),
            ],
          ),
        );
      },
    );
  }

  Widget _memberRow(TeamModel team, String uid, AppUser? user,
      {required bool first, required bool amOwner}) {
    final role = team.roleOf(uid);
    String roleTag = _roleLabel(role);
    if (role == TeamRole.vice) {
      final idx = team.viceCaptainUids.indexOf(uid);
      if (idx >= 0) roleTag = '${tr('teams.vice')} ${idx + 1}';
    }
    final isOwnerRow = uid == team.ownerUid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border:
            first ? null : const Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          InitialsAvatar(
              initials: user?.initials ?? '?',
              size: 36,
              fontSize: 13,
              photoUrl: user?.photoUrl),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user?.name ?? tr('role.player'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.barlow(size: 15, weight: FontWeight.w700)),
                Text(roleTag.toUpperCase(),
                    style: AppText.barlow(size: 11, color: AppColors.dim2)),
              ],
            ),
          ),
          // Quick "make captain" chip — a shortcut to the same action in the
          // member sheet, so an owner can hand captaincy in one tap. Hidden for
          // the owner's own row and for whoever is already captain.
          if (amOwner && !isOwnerRow && uid != team.captainUid)
            GestureDetector(
              onTap: () => _promoteCaptain(team, uid, user),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(100)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_border,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(tr('teams.makeCaptain'),
                        style: AppText.barlow(
                            size: 11.5,
                            weight: FontWeight.w700,
                            color: AppColors.primary)),
                  ],
                ),
              ),
            ),
          // Per-member actions (make captain/vice, remove) are owner-only —
          // captains can add members and edit identity but not remove people.
          if (amOwner && !isOwnerRow)
            GestureDetector(
              onTap: () => _memberActions(team, uid, user, amOwner),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: const Icon(Icons.more_horiz,
                    size: 18, color: AppColors.txt),
              ),
            ),
        ],
      ),
    );
  }

  /// Confirm, then promote [uid] to captain (demoting the previous captain).
  Future<void> _promoteCaptain(TeamModel team, String uid, AppUser? user) async {
    final name = user?.name ?? tr('role.player');
    final ok = await showConfirm(
      context,
      title: tr('teams.makeCaptain'),
      message: '${tr('teams.makeCaptainConfirm')} $name → ${team.name}.',
      confirmLabel: tr('teams.makeCaptain'),
    );
    if (!ok) return;
    await _repo.assignCaptain(team.id, uid);
    if (mounted) showYnoToast(context, tr('teams.captainAssigned'));
  }

  void _memberActions(
      TeamModel team, String uid, AppUser? user, bool amOwner) {
    final role = team.roleOf(uid);
    final isVice = team.viceCaptainUids.contains(uid);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.line2)),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(user?.name ?? tr('role.player'),
                    style:
                        AppText.condensed(size: 20, weight: FontWeight.w800)),
              ),
            ),
            if (amOwner && role != TeamRole.captain)
              _sheetOption(tr('teams.makeCaptain'), () async {
                Navigator.pop(sheetCtx);
                await _repo.assignCaptain(team.id, uid);
                if (mounted) showYnoToast(context, tr('teams.captainAssigned'));
              }),
            if (amOwner && !isVice && role != TeamRole.captain)
              _sheetOption(tr('teams.addVice'), () async {
                Navigator.pop(sheetCtx);
                if (team.viceCaptainUids.length >= 4) {
                  if (mounted) {
                    showYnoToast(context, tr('teams.maxVice'));
                  }
                  return;
                }
                await _repo.setViceCaptains(
                    team.id, [...team.viceCaptainUids, uid]);
                if (mounted) showYnoToast(context, tr('teams.viceAdded'));
              }),
            if (amOwner && isVice)
              _sheetOption(tr('teams.removeVice'), () async {
                Navigator.pop(sheetCtx);
                await _repo.setViceCaptains(team.id,
                    team.viceCaptainUids.where((v) => v != uid).toList());
                if (mounted) showYnoToast(context, tr('teams.viceRemoved'));
              }),
            if (amOwner)
              _sheetOption(tr('teams.removeFromTeam'), () async {
                Navigator.pop(sheetCtx);
                final name = user?.name ?? tr('role.player');
                final ok = await _confirm(
                  title: tr('teams.removePlayerTitle'),
                  message:
                      '$name ${tr('teams.removePlayerBody')} "${team.name}".',
                  confirmLabel: tr('teams.remove'),
                );
                if (!ok) return;
                await _repo.removeMember(team.id, uid);
                if (mounted) showYnoToast(context, tr('teams.playerRemoved'));
              }, danger: true),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Delegates to the shared [showConfirm]. Deleting a team keeps its own
  /// stronger type-the-name gate on top of this.
  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = true,
  }) =>
      showConfirm(context,
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          danger: danger);

  Widget _sheetOption(String label, VoidCallback onTap,
      {bool danger = false}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.line))),
        child: Text(label,
            style: AppText.barlow(
                size: 15,
                weight: FontWeight.w700,
                color: danger ? kDangerColor : AppColors.txt)),
      ),
    );
  }

  // ---- Invite player (friends quick-list + search) ---------------------
  Future<void> _invitePlayerSheet(TeamModel team) async {
    final ctrl = _inviteCtrl..clear();
    List<AppUser> results = const [];
    var searching = false;
    // Friends are the easy path — load them once for the quick-list shown
    // before the manager types a search.
    final myUid = AuthRepository.instance.uid;
    final friendsFuture = myUid == null
        ? Future.value(<AppUser>[])
        : FriendRepository.instance
            .friendUids(myUid)
            .then(UserRepository.instance.getUsers);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.line2)),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('teams.invitePlayer').toUpperCase(),
                    style: AppText.condensed(size: 22, weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(tr('teams.searchHint'),
                    style: AppText.barlow(size: 13, color: AppColors.dim)),
                const SizedBox(height: 14),
                YnoTextField(
                  controller: ctrl,
                  hint: '${tr('common.search')}…',
                  autofocus: true,
                  onSubmitted: (q) async {
                    if (q.trim().isEmpty) return;
                    setSheet(() => searching = true);
                    final r = await UserRepository.instance.search(q.trim());
                    setSheet(() {
                      results = r.where((u) => u.uid != team.ownerUid).toList();
                      searching = false;
                    });
                  },
                ),
                const SizedBox(height: 14),
                if (searching)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (results.isEmpty)
                  _friendsInviteList(sheetCtx, team, friendsFuture)
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final u in results)
                          _searchRow(sheetCtx, team, u),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Quick-list of the manager's friends (minus those already on the team),
  /// shown before they type a search — the easy way to invite people you know.
  Widget _friendsInviteList(
      BuildContext sheetCtx, TeamModel team, Future<List<AppUser>> friends) {
    return FutureBuilder<List<AppUser>>(
      future: friends,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Text(tr('teams.typeToSearch'),
              style: AppText.barlow(size: 13, color: AppColors.dim2));
        }
        final list =
            snap.data!.where((u) => !team.memberUids.contains(u.uid)).toList();
        if (list.isEmpty) {
          return Text(tr('teams.typeToSearch'),
              style: AppText.barlow(size: 13, color: AppColors.dim2));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('teams.inviteFriends').toUpperCase(), style: AppText.label()),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final u in list) _searchRow(sheetCtx, team, u),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _searchRow(BuildContext sheetCtx, TeamModel team, AppUser u) {
    final already = team.memberUids.contains(u.uid);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          InitialsAvatar(
              initials: u.initials,
              size: 34,
              fontSize: 12,
              photoUrl: u.photoUrl),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.name.isEmpty ? u.handle : u.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.barlow(size: 14, weight: FontWeight.w700)),
                Text('${u.username.isEmpty ? '' : '@${u.username} · '}'
                    '${u.matchesPlayed} ${tr('teams.played')}',
                    style: AppText.barlow(size: 11, color: AppColors.dim2)),
              ],
            ),
          ),
          GestureDetector(
            onTap: already
                ? null
                : () async {
                    await _repo.inviteMember(team.id,
                        uid: u.uid,
                        name: u.name.isEmpty ? u.handle : u.name,
                        teamName: team.name);
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                    if (mounted) showYnoToast(context, tr('teams.inviteSent'));
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(100)),
              child: Text(already ? tr('teams.member') : tr('teams.invite'),
                  style: AppText.barlow(
                      size: 11,
                      weight: FontWeight.w800,
                      color: already ? AppColors.dim2 : AppColors.txt)),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Add guest --------------------------------------------------------
  // The host supplies name + email; we create a real account (password
  // 123456) and add the player to the roster as a member, so they can log in
  // and claim their profile later — the same rule as adding a player to a match.
  Future<void> _addGuestSheet(TeamModel team) async {
    final ctrl = _guestNameCtrl..clear();
    final emailCtrl = _guestEmailCtrl..clear();
    var busy = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.line2)),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('teams.addGuest').toUpperCase(),
                    style: AppText.condensed(size: 22, weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(tr('teams.guestAccountHint'),
                    style: AppText.barlow(
                        size: 13, color: AppColors.dim, height: 1.4)),
                const SizedBox(height: 14),
                FieldLabel(tr('teams.guestName')),
                YnoTextField(
                    controller: ctrl,
                    hint: tr('teams.guestName'),
                    textCapitalization: TextCapitalization.words,
                    autofocus: true),
                const SizedBox(height: 12),
                FieldLabel(tr('teams.guestEmail')),
                YnoTextField(
                    controller: emailCtrl,
                    hint: tr('teams.guestEmailHint'),
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: busy ? tr('teams.adding') : tr('teams.addGuest'),
                  height: 52,
                  fontSize: 18,
                  onTap: () async {
                    if (busy) return;
                    final name = ctrl.text.trim();
                    final email = emailCtrl.text.trim();
                    if (name.isEmpty) return;
                    if (!email.contains('@') || !email.contains('.')) {
                      showYnoToast(sheetCtx, tr('teams.guestEmailRequired'));
                      return;
                    }
                    setSheet(() => busy = true);
                    try {
                      final uid = await AuthRepository.instance
                          .createPlayerAccount(name: name, email: email);
                      await _repo.addMember(team.id, uid);
                      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      if (mounted) showYnoToast(context, tr('teams.guestAdded'));
                    } catch (_) {
                      setSheet(() => busy = false);
                      if (sheetCtx.mounted) {
                        showYnoToast(sheetCtx, tr('teams.couldNotAddGuest'));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Pending invites --------------------------------------------------
  /// Players who asked to join this team, with Accept / Decline.
  ///
  /// Collapses to nothing when the queue is empty, so it only appears when it
  /// needs answering.
  Widget _joinRequests(TeamModel team) {
    return StreamBuilder<List<TeamInvite>>(
      stream: _repo.watchJoinRequests(team.id),
      builder: (context, snap) {
        final reqs = snap.data ?? const <TeamInvite>[];
        if (reqs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel('${tr('teams.joinRequests')} · ${reqs.length}'),
            const SizedBox(height: 11),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < reqs.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        border: i == 0
                            ? null
                            : const Border(
                                top: BorderSide(color: AppColors.line)),
                      ),
                      child: Row(
                        children: [
                          InitialsAvatar(
                              initials: reqs[i].initials,
                              size: 34,
                              fontSize: 12),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(reqs[i].name,
                                style: AppText.barlow(
                                    size: 14, weight: FontWeight.w700)),
                          ),
                          _requestAction(
                            tr('social.accept'),
                            filled: true,
                            onTap: () async {
                              await _repo
                                  .approveJoinRequest(team.id, reqs[i].uid);
                              if (context.mounted) {
                                showYnoToast(
                                    context, tr('teams.requestAccepted'));
                              }
                            },
                          ),
                          const SizedBox(width: 7),
                          _requestAction(
                            tr('social.decline'),
                            filled: false,
                            onTap: () =>
                                _repo.declineJoinRequest(team.id, reqs[i].uid),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _requestAction(String label,
      {required bool filled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
            color: filled ? AppColors.primary : null,
            border: Border.all(
                color: filled ? AppColors.primary : AppColors.line),
            borderRadius: BorderRadius.circular(100)),
        child: Text(label.toUpperCase(),
            style: AppText.barlow(
                size: 11,
                weight: FontWeight.w800,
                color: filled ? AppColors.ink : AppColors.txt)),
      ),
    );
  }

  Widget _pendingInvites(TeamModel team) {
    return StreamBuilder<List<TeamInvite>>(
      stream: _repo.watchInvites(team.id),
      builder: (context, snap) {
        final invites = snap.data ?? const <TeamInvite>[];
        if (invites.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(16)),
            child: Text(tr('teams.noPendingInvites'),
                style: AppText.barlow(size: 13, color: AppColors.dim2)),
          );
        }
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (int i = 0; i < invites.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    border: i == 0
                        ? null
                        : const Border(top: BorderSide(color: AppColors.line)),
                  ),
                  child: Row(
                    children: [
                      InitialsAvatar(
                          initials: invites[i].initials,
                          size: 34,
                          fontSize: 12),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(invites[i].name,
                                style: AppText.barlow(
                                    size: 14, weight: FontWeight.w700)),
                            Text(
                                invites[i].expired
                                    ? tr('teams.expired')
                                    : '${tr('teams.pending')} · ${tr('teams.expiry7')}',
                                style: AppText.barlow(
                                    size: 11, color: AppColors.dim2)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final ok = await _confirm(
                            title: tr('teams.revokeInviteQ'),
                            message: '${invites[i].name} '
                                '${tr('teams.revokeInviteBody')}',
                            confirmLabel: tr('teams.revoke'),
                          );
                          if (!ok) return;
                          await _repo.declineInvite(team.id, invites[i].uid);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 7),
                          decoration: BoxDecoration(
                              border: Border.all(color: AppColors.line),
                              borderRadius: BorderRadius.circular(100)),
                          child: Text(tr('common.cancel').toUpperCase(),
                              style: AppText.barlow(
                                  size: 11, weight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ---- Privacy ----------------------------------------------------------
  Widget _privacyToggle(TeamModel team) {
    return GestureDetector(
      onTap: () => _repo.setPrivacy(team.id, !team.isPublic),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(team.isPublic ? tr('teams.public') : tr('teams.private'),
                      style:
                          AppText.barlow(size: 15, weight: FontWeight.w700)),
                  Text(
                      team.isPublic
                          ? tr('teams.publicSubShort')
                          : tr('teams.privateSubShort'),
                      style: AppText.barlow(size: 12, color: AppColors.dim2)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(100)),
              child: Text(
                  team.isPublic ? tr('teams.makePrivate') : tr('teams.makePublic'),
                  style:
                      AppText.barlow(size: 11, weight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Disband ----------------------------------------------------------
  Widget _disbandCard(TeamModel team) {
    return GestureDetector(
      onTap: () => _confirmDisband(team),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.line2),
            borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Text('🗑', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('teams.disbandTeam'),
                      style:
                          AppText.barlow(size: 15, weight: FontWeight.w700)),
                  Text(tr('teams.restorable6'),
                      style: AppText.barlow(size: 12, color: AppColors.dim2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDisband(TeamModel team) async {
    final ctrl = _disbandCtrl..clear();
    var canConfirm = false;
    StateSetter? setSheetRef;
    void onType() {
      final ok = ctrl.text.trim().toLowerCase() ==
          team.name.trim().toLowerCase();
      if (ok != canConfirm) {
        canConfirm = ok;
        setSheetRef?.call(() {});
      }
    }

    ctrl.addListener(onType);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.line2)),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          setSheetRef = setSheet;
          return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('teams.disbandTeam').toUpperCase(),
                    style: AppText.condensed(size: 22, weight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                    '${tr('teams.disbandTypePrefix')} "${team.name}" '
                    '${tr('teams.disbandTypeSuffix')}',
                    style: AppText.barlow(size: 13, color: AppColors.dim)),
                const SizedBox(height: 14),
                YnoTextField(
                  controller: ctrl,
                  hint: team.name,
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: tr('teams.disband'),
                  height: 52,
                  fontSize: 18,
                  danger: true,
                  onTap: !canConfirm
                      ? null
                      : () async {
                          await _repo.disband(team.id);
                          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                          if (mounted) {
                            Navigator.of(context).popUntil(
                                (r) => r.settings.name == Routes.teams ||
                                    r.isFirst);
                          }
                        },
                ),
              ],
            ),
          ),
        );
        },
      ),
    );
    // The listener still goes — it closes over this call's `canConfirm` and
    // `setSheetRef`, so leaving it attached would make the next open drive a
    // dead sheet. The controller itself belongs to the State.
    ctrl.removeListener(onType);
  }

  // ---- Leave (non-owner) ------------------------------------------------
  Widget _leaveCard(TeamModel team, String? myUid) {
    return GestureDetector(
      onTap: () async {
        if (myUid == null) return;
        final ok = await _confirm(
          title: tr('teams.leaveTeamTitle'),
          message: '${tr('teams.leaveTeamBody')} "${team.name}".',
          confirmLabel: tr('teams.leave'),
        );
        if (!ok) return;
        await _repo.removeMember(team.id, myUid);
        if (mounted) Navigator.of(context).maybePop();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.line2),
            borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Text('🚪', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 11),
            Text(tr('teams.leaveTeam'),
                style: AppText.barlow(size: 15, weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _ghostAction(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.line2),
            borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.center,
        child: Text(label,
            style: AppText.barlow(size: 14, weight: FontWeight.w700)),
      ),
    );
  }
}
