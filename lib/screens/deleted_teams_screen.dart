import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
import '../services/models.dart';
import '../services/team_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/header.dart';
import '../widgets/motion.dart';
import '../widgets/yno_scaffold.dart';

/// Disbanded teams the user owns — restorable within 6 months.
class DeletedTeamsScreen extends StatelessWidget {
  const DeletedTeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthRepository.instance.uid;
    return YnoScaffold(
      appBarTitle: tr('teams.deletedTeams'),
      child: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<List<TeamModel>>(
                stream: uid == null
                    ? const Stream.empty()
                    : TeamRepository.instance.watchDeletedTeams(uid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final teams = snap.data ?? const <TeamModel>[];
                  if (teams.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(tr('teams.noDisbanded'),
                            style: AppText.barlow(
                                size: 14, color: AppColors.dim)),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < teams.length; i++) ...[
                        FadeSlideIn(
                          delay: Duration(milliseconds: 50 * i),
                          child: _DeletedCard(team: teams[i]),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeletedCard extends StatefulWidget {
  const _DeletedCard({required this.team});
  final TeamModel team;

  @override
  State<_DeletedCard> createState() => _DeletedCardState();
}

class _DeletedCardState extends State<_DeletedCard> {
  bool _busy = false;

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    await TeamRepository.instance.restore(widget.team.id);
    if (!mounted) return;
    showYnoToast(context, tr('teams.teamRestored'));
    Navigator.of(context)
        .pushReplacementNamed(Routes.teamProfile, arguments: widget.team.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.team;
    final restorable = t.restorable;
    final when = t.disbandedAt == null
        ? ''
        : DateFormat('d MMM yyyy').format(t.disbandedAt!);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _badge(t, 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.condensed(
                            size: 20, weight: FontWeight.w800, height: 1)),
                    const SizedBox(height: 3),
                    Text(
                        when.isEmpty
                            ? tr('teams.disbandedWord')
                            : '${tr('teams.disbandedWord')} $when',
                        style:
                            AppText.barlow(size: 12, color: AppColors.dim2)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line2),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(tr('teams.disbanded'),
                    style: AppText.barlow(
                        size: 10, weight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (restorable)
            GestureDetector(
              onTap: _restore,
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                    _busy ? tr('teams.restoring') : '↻ ${tr('teams.restoreTeam')}',
                    style: AppText.barlow(size: 14, weight: FontWeight.w700)),
              ),
            )
          else
            Container(
              height: 46,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.dim2),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(tr('teams.cannotReactivate'),
                  textAlign: TextAlign.center,
                  style: AppText.barlow(size: 12, color: AppColors.dim2)),
            ),
        ],
      ),
    );
  }

  Widget _badge(TeamModel t, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
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
