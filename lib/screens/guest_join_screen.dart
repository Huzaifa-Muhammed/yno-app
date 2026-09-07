import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/match_repository.dart';
import '../services/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/header.dart';
import '../widgets/inputs.dart';
import '../widgets/yno_scaffold.dart';

/// Accountless join. A guest opens a shared link, enters (or is handed) a match
/// code, then their name + phone/email. No account is created — the stats are
/// saved as a claimable guest record. They can instead just follow the match
/// live, or create a full account.
class GuestJoinScreen extends StatefulWidget {
  const GuestJoinScreen({super.key});

  @override
  State<GuestJoinScreen> createState() => _GuestJoinScreenState();
}

class _GuestJoinScreenState extends State<GuestJoinScreen> {
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _code = TextEditingController();

  bool _finding = false;
  bool _busy = false;
  MatchModel? _match;
  TeamSide _side = TeamSide.a;
  bool _prefilledCode = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A deep link may pass the code in as a route argument.
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (!_prefilledCode && arg is String && arg.isNotEmpty) {
      _prefilledCode = true;
      _code.text = arg;
      WidgetsBinding.instance.addPostFrameCallback((_) => _find());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) {
      showYnoToast(context, tr('match.enterMatchCode'));
      return;
    }
    setState(() => _finding = true);
    try {
      final found = await MatchRepository.instance.findByCode(code);
      if (!mounted) return;
      if (found == null) {
        showYnoToast(context, tr('match.noMatchForCode'));
        setState(() => _finding = false);
        return;
      }
      setState(() {
        _match = found.$1;
        _side = found.$2;
        _finding = false;
      });
    } catch (_) {
      if (!mounted) return;
      showYnoToast(context, tr('match.couldNotLookup'));
      setState(() => _finding = false);
    }
  }

  Future<void> _join() async {
    final match = _match;
    if (match == null) {
      showYnoToast(context, tr('match.findMatchFirst'));
      return;
    }
    if (_busy) return;
    final name = _name.text.trim();
    final contact = _contact.text.trim();
    if (name.isEmpty) {
      showYnoToast(context, tr('match.enterYourName'));
      return;
    }
    setState(() => _busy = true);
    final isEmail = contact.contains('@');
    final live = match.status == MatchStatus.live;
    try {
      await MatchRepository.instance.guestJoin(
        matchId: match.id,
        name: name,
        phone: (!isEmail && contact.isNotEmpty) ? contact : null,
        email: isEmail ? contact : null,
        team: _side,
        midGame: live,
      );
      if (!mounted) return;
      // Live match → new joiners wait for admin approval; send them to the
      // read-only scoreboard. Pre-match → straight into the lobby view.
      final route = live ? Routes.liveScoreboard : Routes.lobby;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(route, (_) => false, arguments: match.id);
    } catch (_) {
      if (!mounted) return;
      showYnoToast(context, tr('match.couldNotJoin'));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = _match;
    return YnoScaffold(
      appBarTitle: tr('match.joinMatchTitle'),
      child: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
                  Center(
                    child: Text('YNO',
                        style: AppText.condensed(
                            size: 42, weight: FontWeight.w800, height: 0.9)),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(tr('match.invitedToPlay'),
                        style: AppText.barlow(size: 13, color: AppColors.dim)),
                  ),
                  const SizedBox(height: 22),

                  // ---- Step 1: find the match ---------------------------
                  FieldLabel(tr('match.matchCode')),
                  YnoTextField(
                    controller: _code,
                    hint: tr('match.matchCodeHint'),
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _find(),
                    trailing: GestureDetector(
                      onTap: _find,
                      child: Text(_finding ? '…' : tr('match.find'),
                          style: AppText.barlow(
                              size: 14,
                              weight: FontWeight.w700,
                              color: AppColors.txt)),
                    ),
                  ),

                  if (match != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              match.name.isEmpty
                                  ? '${match.teamAName} vs ${match.teamBName}'
                                  : match.name,
                              style: AppText.condensed(
                                  size: 19, weight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                              [
                                if (match.hasFixedFormat) match.format,
                                if (match.surface.isNotEmpty) match.surface,
                                match.status == MatchStatus.live
                                    ? '● ${tr('match.live')}'
                                    : tr('match.lobbyOpen'),
                              ].join(' · '),
                              style: AppText.barlow(
                                  size: 12, color: AppColors.dim)),
                          const SizedBox(height: 8),
                          Text('${tr('match.youWillJoin')} ${match.teamName(_side)}.',
                              style: AppText.barlow(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: AppColors.txt)),
                          if (match.status == MatchStatus.live)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                  tr('match.matchStartedApprove'),
                                  style: AppText.barlow(
                                      size: 12, color: AppColors.dim2)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    FieldLabel(tr('match.yourName')),
                    YnoTextField(
                      controller: _name,
                      hint: tr('match.fullName'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 14),
                    FieldLabel(tr('match.phoneOrEmail'), optional: true),
                    YnoTextField(
                      controller: _contact,
                      hint: tr('match.contactHintGuest'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                        tr('match.noAccountSync'),
                        style: AppText.barlow(size: 12, color: AppColors.dim2)),
                    const SizedBox(height: 18),
                    PrimaryButton(
                      label: _busy ? tr('match.joining') : tr('match.joinTheMatch'),
                      fontSize: 20,
                      onTap: _join,
                    ),
                    const SizedBox(height: 12),
                    SecondaryButton(
                      label: '📺 ${tr('match.followLive')}',
                      fontSize: 16,
                      onTap: () => Navigator.of(context).pushNamed(
                          Routes.liveScoreboard,
                          arguments: match.id),
                    ),
                  ],

                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context)
                          .pushNamedAndRemoveUntil(Routes.signup, (_) => false),
                      child: Text(tr('match.createAccountInstead'),
                          style: AppText.barlow(
                              size: 13,
                              weight: FontWeight.w700,
                              color: AppColors.txt)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
