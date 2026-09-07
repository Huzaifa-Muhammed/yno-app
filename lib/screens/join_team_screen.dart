import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
import '../services/team_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/header.dart';
import '../widgets/inputs.dart';
import '../widgets/yno_scaffold.dart';

/// Join a club by invite code. Reached from the **side drawer** only.
///
/// This was one half of a Match / Team tab pair inside the Let's Play sheet's
/// join step, which meant every player heading into a game answered "match or
/// team?" first. Joining a team is a once-ever errand and does not belong on the
/// path to kicking off, so it became a page of its own.
///
/// The logic is a straight lift of that tab's `joinTeam`, including both refusal
/// cases — a disbanded team and one you are already in. Losing either would turn
/// a clear message into a silent no-op.
class JoinTeamScreen extends StatefulWidget {
  const JoinTeamScreen({super.key});

  @override
  State<JoinTeamScreen> createState() => _JoinTeamScreenState();
}

class _JoinTeamScreenState extends State<JoinTeamScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_busy) return;
    final uid = AuthRepository.instance.uid;
    final entered = _code.text.trim().toUpperCase();
    if (entered.isEmpty || uid == null) {
      setState(() => _error = tr('home.enterTeamCode'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    // Errors render inline rather than as a toast. On the old bottom sheet a
    // toast was fine; on a full page the message belongs next to the field that
    // caused it.
    try {
      final team = await TeamRepository.instance.findByInviteCode(entered);
      if (!mounted) return;
      if (team == null || team.disbanded) {
        setState(() {
          _busy = false;
          _error = tr('home.noTeamFound');
        });
        return;
      }
      if (team.memberUids.contains(uid)) {
        setState(() {
          _busy = false;
          _error = tr('teams.alreadyMember');
        });
        return;
      }
      await TeamRepository.instance.addMember(team.id, uid);
      if (!mounted) return;
      showYnoToast(context, tr('teams.joinedTeam'));
      // Replace, not push: coming back to a code field you have just spent is a
      // dead end, and the drawer is one tap away.
      Navigator.of(context)
          .pushReplacementNamed(Routes.teamProfile, arguments: team.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = tr('home.couldNotJoinTeam');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return YnoScaffold(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
          children: [
            ScreenHeader(
              title: tr('drawer.joinTeam'),
              onBack: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: 18),
            Text(tr('home.joinTeamPrompt'),
                style: AppText.barlow(
                    size: 14, color: AppColors.dim, height: 1.45)),
            const SizedBox(height: 18),
            YnoTextField(
              controller: _code,
              hint: tr('home.teamCodeHint'),
              textCapitalization: TextCapitalization.characters,
              autofocus: true,
              // Enter submits. Leaving this off is exactly what made client
              // point C18 feel broken — the keyboard's action key did nothing.
              onSubmitted: (_) => _join(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: AppText.barlow(size: 13, color: AppColors.loss)),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
              label: _busy ? tr('home.joining') : tr('home.joinTeam'),
              onTap: _join,
            ),
          ],
        ),
      ),
    );
  }
}
