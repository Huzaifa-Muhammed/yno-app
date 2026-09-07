import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

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
import '../widgets/motion.dart';
import '../widgets/yno_scaffold.dart';

/// Localised label for a team role.
String _roleLabel(TeamRole r) => switch (r) {
      TeamRole.owner => tr('role.owner'),
      TeamRole.captain => tr('role.captain'),
      TeamRole.vice => tr('role.vice'),
      TeamRole.player => tr('role.player'),
    };

class TeamProfileScreen extends StatefulWidget {
  const TeamProfileScreen({super.key});

  @override
  State<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends State<TeamProfileScreen> {
  String get _teamId => ModalRoute.of(context)!.settings.arguments as String;

  @override
  Widget build(BuildContext context) {
    final myUid = AuthRepository.instance.uid;
    return StreamBuilder<TeamModel?>(
      stream: TeamRepository.instance.watchTeam(_teamId),
      builder: (context, snap) {
        final team = snap.data;
        final canManage = team != null && myUid != null && team.canManage(myUid);
        return YnoScaffold(
          appBarTitle: tr('teams.team'),
          appBarActions: team == null
              ? null
              : [
                  if (team.disbanded)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.line2)),
                          child: Text(tr('teams.disbanded'),
                              style: AppText.barlow(
                                  size: 12, weight: FontWeight.w800)),
                        ),
                      ),
                    )
                  else if (canManage)
                    IconButton(
                      onPressed: () => Navigator.of(context).pushNamed(
                          Routes.teamManage,
                          arguments: team.id),
                      icon: const Icon(Icons.edit_outlined, color: AppColors.txt),
                      tooltip: tr('teams.editTeam'),
                    ),
                ],
          child: SafeArea(
            top: false,
            bottom: false,
            child: team == null
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FadeSlideIn(child: _header(team, canManage)),
                        if (myUid != null &&
                            !team.disbanded &&
                            !team.memberUids.contains(myUid)) ...[
                          const SizedBox(height: 16),
                          FadeSlideIn(child: _joinBlock(team, myUid)),
                        ],
                        const SizedBox(height: 20),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 80),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionLabel(tr('teams.matchRecord')),
                              const SizedBox(height: 11),
                              _matchStats(team),
                              const SizedBox(height: 14),
                              _formSection(team),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 160),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionLabel(tr('teams.scoring')),
                              const SizedBox(height: 11),
                              _scoringStats(team),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 240),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionLabel(tr('teams.recognition')),
                              const SizedBox(height: 11),
                              _recognitionStats(team),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 320),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionLabel(tr('teams.roster'),
                                  trailing: Text('${team.memberUids.length}',
                                      style: AppText.barlow(
                                          size: 13, color: AppColors.dim))),
                              const SizedBox(height: 11),
                              _roster(team),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _rivals(team),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  /// Ask to join — shown to anyone viewing a team they are not in.
  ///
  /// You could always *see* a team and never get into it: joining was invite-
  /// only or by code. A **public** team now takes requests; a **private** one
  /// says plainly that it needs a code, instead of silently offering nothing.
  Widget _joinBlock(TeamModel team, String myUid) {
    if (!team.isPublic) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 16, color: AppColors.dim),
            const SizedBox(width: 9),
            Expanded(
              child: Text(tr('teams.privateJoinNote'),
                  style: AppText.barlow(
                      size: 12.5, color: AppColors.dim, height: 1.4)),
            ),
          ],
        ),
      );
    }
    return StreamBuilder<bool>(
      stream: TeamRepository.instance.watchMyJoinRequest(team.id, myUid),
      // The State's own `context` is used inside the callbacks (not the
      // builder's), so the `mounted` guards actually match what they protect.
      builder: (_, snap) {
        final pending = snap.data ?? false;
        if (pending) {
          return SecondaryButton(
            label: tr('teams.requestPending'),
            height: 48,
            onTap: () async {
              final ok = await showConfirm(
                context,
                title: tr('teams.withdrawRequestQ'),
                message: tr('teams.withdrawRequestBody'),
                confirmLabel: tr('teams.withdrawRequest'),
              );
              if (!ok || !mounted) return;
              await TeamRepository.instance
                  .declineJoinRequest(team.id, myUid, notify: false);
              if (mounted) showYnoToast(context, tr('teams.requestWithdrawn'));
            },
          );
        }
        return PrimaryButton(
          label: tr('teams.requestToJoin'),
          height: 48,
          onTap: () async {
            final me = await UserRepository.instance.getUser(myUid);
            if (!mounted) return;
            await TeamRepository.instance.requestToJoin(
              team.id,
              uid: myUid,
              name: me?.name ?? me?.username ?? tr('social.aPlayer'),
            );
            if (mounted) showYnoToast(context, tr('teams.requestSent'));
          },
        );
      },
    );
  }

  // ---- Header -----------------------------------------------------------
  /// [canManage] (captain, or owner when no captain is assigned) gates the
  /// invite code — it's what lets someone challenge or join the team, so it is
  /// not shown to ordinary members or outside viewers.
  Widget _header(TeamModel team, bool canManage) {
    return Column(
      children: [
        Center(child: _badge(team, 88)),
        const SizedBox(height: 12),
        Center(
          child: Text(team.name,
              textAlign: TextAlign.center,
              style: AppText.condensed(size: 30, weight: FontWeight.w800, height: 1)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColors.line)),
            child: Text(
                (team.isPublic ? tr('teams.public') : tr('teams.private'))
                    .toUpperCase(),
                style: AppText.barlow(
                    size: 11, weight: FontWeight.w800, letterSpacing: 0.6)),
          ),
        ),
        if (canManage) _inviteCode(team),
      ],
    );
  }

  /// Only built for managers (owner or captain) — and the code itself comes from
  /// a doc the rules only let managers read, so this can't leak even if the gate
  /// above slips.
  ///
  /// Copy and share only: a team's code is issued once at creation and never
  /// rotates (client, 2026-08-18), so there is no owner-only control here any
  /// more and no `amOwner` parameter.
  Widget _inviteCode(TeamModel team) {
    return StreamBuilder<String?>(
      stream: TeamRepository.instance.watchInviteCode(team.id),
      builder: (context, snap) {
        final code = snap.data;
        if (code == null || code.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                showYnoToast(context, tr('teams.inviteCodeCopied'));
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr('teams.inviteCode'), style: AppText.label()),
                    const SizedBox(width: 12),
                    Text(code,
                        style: AppText.condensed(
                            size: 20, weight: FontWeight.w800, letterSpacing: 2)),
                    const SizedBox(width: 10),
                    const Icon(Icons.copy, size: 16, color: AppColors.dim),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: () => Share.share(
                          '${tr('teams.shareCodeMessage')} ${team.name}: $code'),
                      behavior: HitTestBehavior.opaque,
                      child: const Icon(Icons.ios_share,
                          size: 16, color: AppColors.dim),
                    ),
                    // No regenerate control (client, 2026-08-18): a team has
                    // ONE code for its lifetime, like a match. The repo's
                    // `regenerateInviteCode` is left in place, uncalled.
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(tr('teams.inviteCodeCaptainOnly'),
                style: AppText.barlow(size: 11, color: AppColors.dim2)),
          ],
        );
      },
    );
  }

  // ---- Section 9: match stats ------------------------------------------
  Widget _matchStats(TeamModel team) {
    return Column(
      children: [
        _statGrid([
          ('${team.matchesPlayed}', tr('teams.statPlayed')),
          ('${team.wins}', tr('teams.wins')),
          ('${team.losses}', tr('teams.losses')),
          ('${team.draws}', tr('teams.draws')),
          ('${team.winRate}%', tr('teams.winPct')),
          ('${team.currentStreak}', tr('teams.currStreak')),
        ]),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _wideTile(
                    '${team.bestStreak}', tr('teams.longestWin'))),
            const SizedBox(width: 10),
            Expanded(
                child: _wideTile(
                    '${team.unbeatenStreak}', tr('teams.longestUnbeaten'))),
          ],
        ),
      ],
    );
  }

  Widget _formSection(TeamModel team) {
    final last10 = team.formLast10;
    final last5 = last10.length <= 5
        ? last10
        : last10.sublist(last10.length - 5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _formRow(tr('teams.formLast5'), last5),
        const SizedBox(height: 8),
        _formRow(tr('teams.formLast10'), last10),
      ],
    );
  }

  Widget _formRow(String label, List<String> form) {
    return Row(
      children: [
        SizedBox(
          width: 108,
          child: Text(label.toUpperCase(),
              style: AppText.label()),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: form.isEmpty
              ? Text('—', style: AppText.barlow(size: 13, color: AppColors.dim2))
              : Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final r in form)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.line)),
                        alignment: Alignment.center,
                        child: Text(r,
                            style: AppText.barlow(
                                size: 12, weight: FontWeight.w800)),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _scoringStats(TeamModel team) {
    final gpm = team.matchesPlayed == 0
        ? '0.0'
        : (team.goalsFor / team.matchesPlayed).toStringAsFixed(1);
    final cpm = team.matchesPlayed == 0
        ? '0.0'
        : (team.goalsAgainst / team.matchesPlayed).toStringAsFixed(1);
    return _statGrid([
      ('${team.goalsFor}', tr('teams.goalsFor')),
      ('${team.goalsAgainst}', tr('teams.conceded')),
      ('${team.cleanSheets}', tr('teams.cleanSheets')),
      (gpm, tr('teams.goalsPerMatch')),
      (cpm, tr('teams.concededPerMatch')),
      ('${team.goalsFor - team.goalsAgainst}', tr('teams.goalDiff')),
    ]);
  }

  Widget _recognitionStats(TeamModel team) {
    return Row(
      children: [
        Expanded(child: _wideTile('${team.teamMotm}', tr('teams.motm'))),
        const SizedBox(width: 10),
        Expanded(
            child: _wideTile('${team.teamCommunity}', tr('teams.communityAwards'))),
      ],
    );
  }

  Widget _statGrid(List<(String, String)> items) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: [
        for (final it in items)
          StatTile(value: it.$1, label: it.$2, valueSize: 26),
      ],
    );
  }

  Widget _wideTile(String v, String l) =>
      StatTile(value: v, label: l, valueSize: 26);

  // ---- Roster -----------------------------------------------------------
  Widget _roster(TeamModel team) {
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line)),
          child: Column(
            children: [
              for (int i = 0; i < ordered.length; i++)
                _memberRow(team, ordered[i], byId[ordered[i]], first: i == 0),
            ],
          ),
        );
      },
    );
  }

  Widget _memberRow(TeamModel team, String uid, AppUser? user,
      {required bool first}) {
    final role = team.roleOf(uid);
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .pushNamed(Routes.profilePublic, arguments: uid),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          border: first
              ? null
              : const Border(top: BorderSide(color: AppColors.line)),
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
                  if (user != null && user.username.isNotEmpty)
                    Text('@${user.username}',
                        style:
                            AppText.barlow(size: 12, color: AppColors.dim2)),
                ],
              ),
            ),
            if (user?.autoCreated == true) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line)),
                child: Text(tr('badge.guest'),
                    style: AppText.barlow(size: 10, weight: FontWeight.w800)),
              ),
              const SizedBox(width: 6),
            ],
            if (role != TeamRole.player)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line)),
                child: Text(
                    role == TeamRole.vice
                        ? tr('teams.viceShort')
                        : _roleLabel(role).toUpperCase(),
                    style: AppText.barlow(
                        size: 10, weight: FontWeight.w800)),
              ),
          ],
        ),
      ),
    );
  }

  // ---- Rival teams ------------------------------------------------------
  Widget _rivals(TeamModel team) {
    return StreamBuilder<List<RivalEdge>>(
      stream: FriendRepository.instance.watchTeamRivalries(team.id),
      builder: (context, snap) {
        final edges = (snap.data ?? const <RivalEdge>[])
            .where((e) => e.status == FriendStatus.accepted)
            .toList();
        if (edges.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(tr('teams.rivalTeams')),
            const SizedBox(height: 11),
            for (final e in edges) _rivalRow(team.id, e.other(team.id)),
          ],
        );
      },
    );
  }

  Widget _rivalRow(String teamId, String rivalId) {
    return FutureBuilder<TeamModel?>(
      future: TeamRepository.instance.getTeam(rivalId),
      builder: (context, snap) {
        final rival = snap.data;
        if (rival == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => Navigator.of(context)
                .pushNamed(Routes.teamProfile, arguments: rival.id),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line)),
              child: Row(
                children: [
                  _badge(rival, 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(rival.name,
                        style:
                            AppText.barlow(size: 15, weight: FontWeight.w700)),
                  ),
                  const Text('›',
                      style: TextStyle(fontSize: 20, color: AppColors.dim2)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---- Shared badge -----------------------------------------------------
  Widget _badge(TeamModel t, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(size > 60 ? 16 : 12),
          border: Border.all(color: AppColors.line2, width: size > 60 ? 2 : 1)),
      clipBehavior: Clip.hardEdge,
      alignment: Alignment.center,
      child: t.badgeUrl != null && t.badgeUrl!.isNotEmpty
          ? Image.network(t.badgeUrl!, fit: BoxFit.contain)
          : Text(
              t.presetBadge != null && t.presetBadge!.isNotEmpty
                  ? t.presetBadge!
                  : (t.name.isEmpty ? '?' : t.name.substring(0, 1).toUpperCase()),
              style: (t.presetBadge != null && t.presetBadge!.isNotEmpty)
                  ? TextStyle(fontSize: size * 0.5)
                  : AppText.condensed(size: size * 0.44, weight: FontWeight.w800),
            ),
    );
  }
}
