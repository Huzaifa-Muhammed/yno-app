import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
import '../services/models.dart';
import '../services/team_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/yno_scaffold.dart';

/// Localised label for a team role.
String _roleLabel(TeamRole r) => switch (r) {
      TeamRole.owner => tr('role.owner'),
      TeamRole.captain => tr('role.captain'),
      TeamRole.vice => tr('role.vice'),
      TeamRole.player => tr('role.player'),
    };

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  int _filter = 0; // 0 All, 1 Owner, 2 Captain, 3 Player

  bool _matchesFilter(TeamModel t, String uid) {
    switch (_filter) {
      case 1:
        return t.roleOf(uid) == TeamRole.owner;
      case 2:
        return t.roleOf(uid) == TeamRole.captain;
      case 3:
        final r = t.roleOf(uid);
        return r == TeamRole.player || r == TeamRole.vice;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthRepository.instance.uid;
    return YnoScaffold(
      appBarTitle: tr('drawer.myTeams'),
      appBarActions: [
        IconButton(
          onPressed: () => Navigator.of(context).pushNamed(Routes.teamCreate),
          icon: const Icon(Icons.add, color: AppColors.txt),
          tooltip: tr('teams.createTeam'),
        ),
      ],
      child: SafeArea(
        top: false,
        bottom: false,
        child: StreamBuilder<List<TeamModel>>(
          stream: uid == null
              ? const Stream.empty()
              : TeamRepository.instance.watchUserTeams(uid),
          builder: (context, snap) {
            final all = snap.data ?? const <TeamModel>[];
            final teams =
                uid == null ? all : all.where((t) => _matchesFilter(t, uid)).toList();
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeSlideIn(
                    child: SegmentedTabs(
                      tabs: [
                        tr('teams.all'),
                        tr('role.owner'),
                        tr('role.captain'),
                        tr('role.player'),
                      ],
                      index: _filter,
                      fontSize: 13,
                      onChanged: (i) => setState(() => _filter = i),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 80),
                    child: _navRow(
                      context,
                      icon: '🔍',
                      label: tr('teams.discoverTeams'),
                      sub: tr('teams.discoverSub'),
                      onTap: () =>
                          Navigator.of(context).pushNamed(Routes.teamDiscover),
                    ),
                  ),
                  if (uid != null) _deletedEntry(context, uid),
                  const SizedBox(height: 14),
                  if (snap.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (all.isEmpty)
                    _empty(context)
                  else if (teams.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Center(
                        child: Text(tr('teams.noTeamsFilter'),
                            style:
                                AppText.barlow(size: 14, color: AppColors.dim)),
                      ),
                    )
                  else
                    for (var i = 0; i < teams.length; i++) ...[
                      FadeSlideIn(
                        delay: Duration(milliseconds: 50 * i),
                        child: _teamCard(context, teams[i], uid!),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// "Deleted Teams" entry — only when the user owns disbanded teams.
  Widget _deletedEntry(BuildContext context, String uid) {
    return StreamBuilder<List<TeamModel>>(
      stream: TeamRepository.instance.watchDeletedTeams(uid),
      builder: (context, snap) {
        final n = snap.data?.length ?? 0;
        if (n == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _navRow(
            context,
            icon: '🗑',
            label: tr('teams.deletedTeams'),
            sub: '$n ${tr('teams.disbandedTeamsLabel')}',
            onTap: () =>
                Navigator.of(context).pushNamed(Routes.deletedTeams),
          ),
        );
      },
    );
  }

  Widget _navRow(BuildContext context,
      {required String icon,
      required String label,
      required String sub,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          AppText.barlow(size: 15, weight: FontWeight.w700)),
                  Text(sub,
                      style: AppText.barlow(size: 12, color: AppColors.dim2)),
                ],
              ),
            ),
            const Text('›',
                style: TextStyle(fontSize: 20, color: AppColors.dim2)),
          ],
        ),
      ),
    );
  }

  Widget _teamCard(BuildContext context, TeamModel t, String uid) {
    final role = _roleLabel(t.roleOf(uid));
    return SurfaceCard(
      onTap: () =>
          Navigator.of(context).pushNamed(Routes.teamProfile, arguments: t.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _badge(t, 54),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.condensed(
                            size: 22, weight: FontWeight.w800, height: 1)),
                    const SizedBox(height: 3),
                    Text(
                        '${role.toUpperCase()} · ${t.memberUids.length} ${tr('teams.members')}',
                        style: AppText.barlow(
                            size: 12,
                            weight: FontWeight.w700,
                            color: AppColors.dim,
                            letterSpacing: 0.5)),
                  ],
                ),
              ),
              _pendingBadge(t, uid),
              if (t.canManage(uid))
                GestureDetector(
                  onTap: () => Navigator.of(context)
                      .pushNamed(Routes.teamManage, arguments: t.id),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child:
                        Icon(Icons.edit_outlined, size: 18, color: AppColors.dim),
                  ),
                ),
              const Text('›',
                  style: TextStyle(fontSize: 20, color: AppColors.dim2)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _recordChip('W', t.wins),
              const SizedBox(width: 8),
              _recordChip('D', t.draws),
              const SizedBox(width: 8),
              _recordChip('L', t.losses),
              const Spacer(),
              Text('${t.matchesPlayed} ${tr('teams.played')}',
                  style: AppText.barlow(size: 12, color: AppColors.dim2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pendingBadge(TeamModel t, String uid) {
    if (!t.canManage(uid)) return const SizedBox.shrink();
    return StreamBuilder<List<TeamInvite>>(
      stream: TeamRepository.instance.watchInvites(t.id),
      builder: (context, snap) {
        final n = snap.data?.length ?? 0;
        if (n == 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text('$n ${tr('teams.pending')}',
              style: AppText.barlow(
                  size: 10, weight: FontWeight.w800, color: AppColors.txt)),
        );
      },
    );
  }

  Widget _recordChip(String k, int v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text('$k $v',
            style: AppText.barlow(
                size: 12, weight: FontWeight.w700, color: AppColors.txt)),
      );

  /// Now a thin wrapper over the shared [TeamBadge] — the fallback chain used
  /// to live here and was about to be copied into the match-creation picker.
  Widget _badge(TeamModel t, double size) => TeamBadge(
        badgeUrl: t.badgeUrl,
        presetBadge: t.presetBadge,
        name: t.name,
        size: size,
      );

  Widget _empty(BuildContext context) => SurfaceCard(
        dashed: true,
        border: AppColors.line2,
        onTap: () => Navigator.of(context).pushNamed(Routes.teamCreate),
        child: Column(
          children: [
            const Text('🛡️', style: TextStyle(fontSize: 34)),
            const SizedBox(height: 10),
            Text(tr('teams.createFirst'),
                style: AppText.barlow(size: 15, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(tr('teams.createFirstSub'),
                textAlign: TextAlign.center,
                style: AppText.barlow(size: 13, color: AppColors.dim2)),
          ],
        ),
      );
}
