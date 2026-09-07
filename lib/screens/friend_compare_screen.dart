import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';
import '../services/auth_repository.dart';
import '../services/models.dart';
import '../services/user_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/yno_scaffold.dart';

/// Side-by-side stat comparison between the current user and a friend
/// (Section 4). Reads the friend's uid from the route argument, loads both
/// profiles and shows who leads each stat, with a share-friendly layout.
class FriendCompareScreen extends StatefulWidget {
  const FriendCompareScreen({super.key});

  @override
  State<FriendCompareScreen> createState() => _FriendCompareScreenState();
}

class _FriendCompareScreenState extends State<FriendCompareScreen> {
  late final Future<List<AppUser>> _future;
  String? _friendUid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _friendUid ??= () {
      final arg = ModalRoute.of(context)?.settings.arguments;
      final friend = (arg is String && arg.isNotEmpty) ? arg : '';
      final me = AuthRepository.instance.uid ?? '';
      _future = UserRepository.instance.getUsers([me, friend]);
      return friend;
    }();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthRepository.instance.uid ?? '';
    return FutureBuilder<List<AppUser>>(
      future: _future,
      builder: (context, snap) {
        final waiting = snap.connectionState == ConnectionState.waiting;
        final users = snap.data ?? const <AppUser>[];
        AppUser? find(String uid) {
          for (final u in users) {
            if (u.uid == uid) return u;
          }
          return null;
        }

        final me = find(myUid);
        final friend = find(_friendUid ?? '');
        final rows = friend == null ? const <_Cmp>[] : _rows(me, friend);
        return YnoScaffold(
          appBarTitle: tr('social.compare'),
          appBarActions: friend == null
              ? null
              : [
                  IconButton(
                    onPressed: () => _share(me, friend, rows),
                    icon: const Icon(Icons.ios_share, color: AppColors.txt),
                    tooltip: tr('common.share'),
                  ),
                ],
          child: SafeArea(
            top: false,
            bottom: false,
            child: waiting
                ? const Center(child: CircularProgressIndicator())
                : friend == null
                    ? _missing(context)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                        children: [
                          FadeSlideIn(child: _headerCard(me, friend)),
                          const SizedBox(height: 16),
                          for (int i = 0; i < rows.length; i++)
                            FadeSlideIn(
                                delay: Duration(milliseconds: 50 * i),
                                child: _statRow(rows[i])),
                          const SizedBox(height: 14),
                          FadeSlideIn(
                              delay:
                                  Duration(milliseconds: 50 * rows.length),
                              child: _tally(rows)),
                        ],
                      ),
          ),
        );
      },
    );
  }

  // ---- Data -------------------------------------------------------------

  List<_Cmp> _rows(AppUser? me, AppUser friend) {
    String pct(int v) => '$v%';
    String rate(double v) => v.toStringAsFixed(1);
    return [
      _Cmp(tr('social.matches'), me?.matchesPlayed ?? 0, friend.matchesPlayed),
      _Cmp(tr('social.goals'), me?.careerGoals ?? 0, friend.careerGoals),
      _Cmp(tr('social.assists'), me?.careerAssists ?? 0, friend.careerAssists),
      _Cmp(tr('social.wins'), me?.wins ?? 0, friend.wins),
      _Cmp(tr('social.losses'), me?.losses ?? 0, friend.losses, lowerWins: true),
      _Cmp(tr('social.winRate'), me?.winRate ?? 0, friend.winRate,
          fmt: pct),
      _Cmp(tr('social.motm'), me?.totalMotm ?? 0, friend.totalMotm),
      _Cmp(tr('social.goalsPerMatch'),
          ((me?.goalsPerMatch ?? 0) * 10).round(),
          (friend.goalsPerMatch * 10).round(),
          display: (v) => rate(v / 10)),
    ];
  }

  // ---- UI pieces --------------------------------------------------------

  Widget _headerCard(AppUser? me, AppUser friend) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: _person(me?.name ?? tr('social.youName'),
              me?.initials ?? 'ME', me?.photoUrl, tr('common.you'))),
          Container(width: 1, height: 74, color: AppColors.line),
          Expanded(
              child: _person(friend.name.isEmpty ? tr('social.friendName') : friend.name,
                  friend.initials, friend.photoUrl, tr('social.friendTag'))),
        ],
      ),
    );
  }

  Widget _person(String name, String initials, String? photo, String tag) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InitialsAvatar(
            initials: initials, size: 60, fontSize: 22, photoUrl: photo),
        const SizedBox(height: 9),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppText.barlow(size: 15, weight: FontWeight.w700)),
        ),
        const SizedBox(height: 3),
        Text(tag,
            style: AppText.barlow(
                size: 10, color: AppColors.dim2, letterSpacing: 1)),
      ],
    );
  }

  Widget _statRow(_Cmp r) {
    final meLeads = r.meLeads;
    final friendLeads = r.friendLeads;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _leadMark(meLeads),
                const SizedBox(width: 6),
                Text(r.meText,
                    style: AppText.condensed(
                        size: 20,
                        weight: meLeads ? FontWeight.w800 : FontWeight.w400,
                        color: meLeads ? AppColors.txt : AppColors.dim)),
              ],
            ),
          ),
          Expanded(
            child: Text(r.label.toUpperCase(),
                textAlign: TextAlign.center,
                style: AppText.barlow(
                    size: 11, color: AppColors.dim, letterSpacing: 0.5)),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(r.friendText,
                    style: AppText.condensed(
                        size: 20,
                        weight:
                            friendLeads ? FontWeight.w800 : FontWeight.w400,
                        color:
                            friendLeads ? AppColors.txt : AppColors.dim)),
                const SizedBox(width: 6),
                _leadMark(friendLeads),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _leadMark(bool on) => SizedBox(
        width: 10,
        child: on
            ? Text('▸',
                style: AppText.barlow(size: 13, weight: FontWeight.w800))
            : const SizedBox.shrink(),
      );

  Widget _tally(List<_Cmp> rows) {
    int mine = 0, theirs = 0;
    for (final r in rows) {
      if (r.meLeads) mine++;
      if (r.friendLeads) theirs++;
    }
    final verdict = mine == theirs
        ? '${tr('social.deadEven')} — $mine ${tr('social.each')}'
        : mine > theirs
            ? '${tr('social.youLead')} $mine–$theirs'
            : '${tr('social.friendLeads')} $theirs–$mine';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(verdict.toUpperCase(),
            style: AppText.condensed(size: 18, weight: FontWeight.w800)),
      ),
    );
  }

  Widget _missing(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        children: [
          Center(
            child: Text(tr('social.couldntLoadFriend'),
                style: AppText.barlow(size: 14, color: AppColors.dim)),
          ),
        ],
      );

  void _share(AppUser? me, AppUser friend, List<_Cmp> rows) {
    final meName = me?.name.isNotEmpty == true ? me!.name : tr('social.me');
    final frName = friend.name.isNotEmpty ? friend.name : tr('social.friendName');
    final b = StringBuffer('YNO — $meName ${tr('social.vs')} $frName\n');
    for (final r in rows) {
      b.writeln('${r.label}: ${r.meText} ${tr('social.vs')} ${r.friendText}');
    }
    b.writeln('\n${tr('social.compareYoursOnYno')}');
    Share.share(b.toString(), subject: tr('social.shareSubject'));
  }
}

/// One comparison line. Values are compared as ints; [display]/[fmt] control
/// how each side is rendered.
class _Cmp {
  _Cmp(
    this.label,
    this.meVal,
    this.friendVal, {
    this.lowerWins = false,
    String Function(int)? fmt,
    String Function(int)? display,
  }) : _fmt = display ?? fmt ?? ((v) => '$v');

  final String label;
  final int meVal;
  final int friendVal;
  final bool lowerWins;
  final String Function(int) _fmt;

  bool get meLeads =>
      lowerWins ? meVal < friendVal : meVal > friendVal;
  bool get friendLeads =>
      lowerWins ? friendVal < meVal : friendVal > meVal;

  String get meText => _fmt(meVal);
  String get friendText => _fmt(friendVal);
}
