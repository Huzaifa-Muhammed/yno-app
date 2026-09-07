import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/models.dart';
import '../services/team_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/header.dart';
import '../widgets/inputs.dart';
import '../widgets/motion.dart';
import '../widgets/yno_scaffold.dart';

/// Public-team discovery + join-by-invite-code.
class TeamDiscoverScreen extends StatefulWidget {
  const TeamDiscoverScreen({super.key});

  @override
  State<TeamDiscoverScreen> createState() => _TeamDiscoverScreenState();
}

class _TeamDiscoverScreenState extends State<TeamDiscoverScreen> {
  final _search = TextEditingController();
  final _code = TextEditingController();

  List<TeamModel> _results = const [];
  bool _loading = true;
  bool _codeBusy = false;

  @override
  void initState() {
    super.initState();
    _run('');
  }

  @override
  void dispose() {
    _search.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(String q) async {
    setState(() => _loading = true);
    final r = await TeamRepository.instance.discover(q);
    if (!mounted) return;
    setState(() {
      _results = r;
      _loading = false;
    });
  }

  Future<void> _join() async {
    if (_codeBusy) return;
    final code = _code.text.trim();
    if (code.isEmpty) return;
    setState(() => _codeBusy = true);
    final team = await TeamRepository.instance.findByInviteCode(code);
    if (!mounted) return;
    setState(() => _codeBusy = false);
    if (team == null) {
      showYnoToast(context, tr('teams.noTeamForCode'));
      return;
    }
    Navigator.of(context).pushNamed(Routes.teamProfile, arguments: team.id);
  }

  @override
  Widget build(BuildContext context) {
    return YnoScaffold(
      appBarTitle: tr('teams.discover'),
      child: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Join by invite code ----
              FadeSlideIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel(tr('teams.joinWithCode')),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: YnoTextField(
                            controller: _code,
                            hint: tr('teams.inviteCodeHint'),
                            textCapitalization: TextCapitalization.characters,
                            onSubmitted: (_) => _join(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 96,
                          child: SecondaryButton(
                            label: _codeBusy ? '…' : tr('teams.find'),
                            height: 56,
                            fontSize: 16,
                            onTap: _join,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ---- Public search ----
              FadeSlideIn(
                delay: const Duration(milliseconds: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel(tr('teams.searchPublic')),
                    const SizedBox(height: 10),
                    YnoTextField(
                      controller: _search,
                      hint: tr('teams.teamNameHint'),
                      onSubmitted: _run,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_results.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Center(
                    child: Text(tr('teams.noPublicTeams'),
                        style:
                            AppText.barlow(size: 14, color: AppColors.dim)),
                  ),
                )
              else
                for (var i = 0; i < _results.length; i++) ...[
                  FadeSlideIn(
                    delay: Duration(milliseconds: 50 * i),
                    child: _teamCard(_results[i]),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _teamCard(TeamModel t) {
    return SurfaceCard(
      onTap: () =>
          Navigator.of(context).pushNamed(Routes.teamProfile, arguments: t.id),
      child: Row(
        children: [
          _badge(t, 50),
          const SizedBox(width: 13),
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
                    '${t.memberUids.length} ${tr('teams.members')} · '
                    '${t.matchesPlayed} ${tr('teams.played')} · W${t.wins} D${t.draws} L${t.losses}',
                    style: AppText.barlow(size: 12, color: AppColors.dim)),
              ],
            ),
          ),
          const Text('›',
              style: TextStyle(fontSize: 20, color: AppColors.dim2)),
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
