import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
import '../services/friend_repository.dart';
import '../services/match_repository.dart';
import '../services/models.dart';
import '../services/team_repository.dart';
import '../services/user_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/header.dart';
import '../widgets/motion.dart';
import '../widgets/side_drawer.dart';
import '../widgets/yno_scaffold.dart';


/// Translate a stored attribute value (position / foot / skill / language) to
/// the active language; unknown values pass through unchanged.
String _trAttr(String v) {
  const map = {
    'Goalkeeper': 'profile.posGoalkeeper',
    'Defender': 'profile.posDefender',
    'Midfielder': 'profile.posMidfielder',
    'Forward': 'profile.posForward',
    'Left': 'profile.footLeft',
    'Right': 'profile.footRight',
    'Both': 'profile.footBoth',
    'Beginner': 'profile.skillBeginner',
    'Intermediate': 'profile.skillIntermediate',
    'Advanced': 'profile.skillAdvanced',
    'English': 'profile.langEnglish',
    'Arabic': 'profile.langArabic',
  };
  final k = map[v];
  return k == null ? v : tr(k);
}

/// Time-window for the stats view.
enum _Filter { allTime, month, week }

/// Section 12 — the player's own profile. A single compact surface that folds
/// in the full personal-stats breakdown (Section 8): everything the standalone
/// Stats page used to show is here, with deeper sections collapsed by default so
/// the whole profile stays tight.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  _Filter _filter = _Filter.allTime;

  // Memoised window aggregate so unrelated rebuilds don't re-hit Firestore.
  String? _aggKey;
  Future<_WindowStats>? _aggFuture;

  String? get _uid => AuthRepository.instance.uid;

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return YnoScaffold(
      appBarTitle: tr('profile.title'),
      appBarActions: [
        IconButton(
          onPressed: () => Navigator.of(context).pushNamed(Routes.editProfile),
          icon: const Icon(Icons.edit_outlined, color: AppColors.txt),
          tooltip: tr('profile.editTitle'),
        ),
        Builder(
          builder: (c) => IconButton(
            onPressed: () => Scaffold.of(c).openEndDrawer(),
            icon: const Icon(Icons.menu, color: AppColors.txt),
            tooltip: tr('drawer.settings'),
          ),
        ),
      ],
      endDrawer: YnoDrawer(),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Builder(
          builder: (ctx) => StreamBuilder<AppUser?>(
            stream: uid == null
                ? const Stream.empty()
                : UserRepository.instance.watchUser(uid),
            builder: (context, userSnap) {
              final user = userSnap.data;
              return StreamBuilder<List<MatchModel>>(
                stream: uid == null
                    ? const Stream.empty()
                    : MatchRepository.instance.watchUserMatches(uid),
                builder: (context, matchSnap) {
                  final matches = matchSnap.data ?? const <MatchModel>[];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FadeSlideIn(child: _header(ctx, user)),
                        const SizedBox(height: 20),
                        FadeSlideIn(
                            delay: const Duration(milliseconds: 160),
                            child: _statsBlock(uid, user, matches)),
                        const SizedBox(height: 14),
                        FadeSlideIn(
                            delay: const Duration(milliseconds: 240),
                            child: _matchHistory(ctx, uid, matches)),
                        const SizedBox(height: 12),
                        FadeSlideIn(
                            delay: const Duration(milliseconds: 320),
                            child: _teamsSection(ctx, uid)),
                        const SizedBox(height: 12),
                        FadeSlideIn(
                            delay: const Duration(milliseconds: 400),
                            child: _playedWith(ctx, uid)),
                        const SizedBox(height: 12),
                        if (user != null)
                          FadeSlideIn(
                              delay: const Duration(milliseconds: 480),
                              child: _about(ctx, user)),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ---- Header -------------------------------------------------------------
  Widget _header(BuildContext ctx, AppUser? user) {
    final chips = <String>[
      if (user?.position != null && user!.position!.isNotEmpty)
        '⚡ ${_trAttr(user.position!)}',
      if (user?.preferredFoot != null && user!.preferredFoot!.isNotEmpty)
        '🦶 ${_trAttr(user.preferredFoot!)}',
    ];
    return Center(
      child: Column(
        children: [
          InitialsAvatar(
            initials: user?.initials ?? '··',
            size: 88,
            fontSize: 34,
            photoUrl: user?.photoUrl,
          ),
          const SizedBox(height: 10),
          Text(user?.name ?? tr('common.loading'),
              style:
                  AppText.condensed(size: 25, weight: FontWeight.w800, height: 1)),
          if (user != null)
            Text('@${user.handle}',
                style: AppText.barlow(size: 13, color: AppColors.dim)),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              alignment: WrapAlignment.center,
              children: [for (final c in chips) TagChip(c)],
            ),
          ],
          const SizedBox(height: 12),
          _socialLinks(ctx, user),
        ],
      ),
    );
  }

  Widget _socialLinks(BuildContext ctx, AppUser? user) {
    if (user == null) return const SizedBox.shrink();
    final links = <MapEntry<String, String>>[];
    for (final e in user.socialLinks.entries) {
      if (e.value.trim().isEmpty) continue;
      final vis = user.socialVisibility[e.key] ?? 'off';
      if (vis == 'off') continue;
      links.add(e);
    }
    if (links.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final e in links)
            GestureDetector(
              onTap: () => _openSocial(ctx, e.key, e.value),
              child: TagChip('${_socialIcon(e.key)} ${_cap(e.key)}'),
            ),
        ],
      ),
    );
  }

  // ---- Full stats (folded in from the old Stats page) --------------------
  Widget _statsBlock(String? uid, AppUser? user, List<MatchModel> all) {
    final _WindowStats s;
    if (_filter == _Filter.allTime) {
      s = _WindowStats.fromUser(user);
    } else {
      final start = _windowStart(_filter);
      final windowed = all
          .where((m) =>
              m.createdAt != null &&
              (start == null || !m.createdAt!.isBefore(start)))
          .toList();
      final key = '${_filter.index}|${windowed.map((m) => m.id).join(',')}';
      if (uid != null && key != _aggKey) {
        _aggKey = key;
        _aggFuture = _computeWindow(uid, windowed);
      }
      // Rendered inside a FutureBuilder below.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsHeader(),
          const SizedBox(height: 12),
          FutureBuilder<_WindowStats>(
            future: _aggFuture,
            builder: (context, snap) =>
                _statsBody(user, snap.data ?? const _WindowStats()),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statsHeader(),
        const SizedBox(height: 12),
        _statsBody(user, s),
      ],
    );
  }

  Widget _statsHeader() {
    return SegmentedTabs(
      tabs: [
        tr('profile.allTime'),
        tr('profile.thisMonth'),
        tr('profile.thisWeek')
      ],
      index: _filter.index,
      onChanged: (i) => setState(() => _filter = _Filter.values[i]),
    );
  }

  Widget _statsBody(AppUser? user, _WindowStats s) {
    final allTime = _filter == _Filter.allTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Always-visible headline record.
        SectionLabel(tr('profile.matchRecord')),
        const SizedBox(height: 10),
        _grid([
          StatTile(value: '${s.matches}', label: tr('profile.matches'), valueSize: 24),
          StatTile(value: '${s.wins}', label: tr('profile.wins'), valueSize: 24),
          StatTile(value: '${s.losses}', label: tr('profile.losses'), valueSize: 24),
          StatTile(value: '${s.draws}', label: tr('profile.draws'), valueSize: 24),
          StatTile(value: '${s.winRate}%', label: tr('profile.winPct'), valueSize: 24),
          StatTile(value: '${s.totalMotm}', label: tr('profile.awards'), valueSize: 24),
        ]),
        const SizedBox(height: 12),
        _formRow(user?.formLast5 ?? const []),
        const SizedBox(height: 12),
        // Deeper breakdowns collapsed to keep the profile compact.
        _Expandable(
          title: tr('profile.scoring'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _grid([
                StatTile(value: '${s.goals}', label: tr('profile.careerGoals'), valueSize: 24),
                StatTile(
                    value: s.goalsPerMatch.toStringAsFixed(1),
                    label: tr('profile.goalsPerMatch'),
                    valueSize: 24),
                StatTile(value: '${s.hatTricks}', label: tr('profile.hatTricks'), valueSize: 24),
                StatTile(value: '${s.bestScoring}', label: tr('profile.bestMatch'), valueSize: 24),
              ]),
              // Goals-by-surface is gone: matches no longer record a surface,
              // so the breakdown could only ever show old data. Goals-by-format
              // stays — format is still chosen at creation.
              const SizedBox(height: 10),
              _breakdown(tr('profile.goalsByFormat'),
                  user?.goalsByFormat ?? const {},
                  allTime: allTime),
            ],
          ),
        ),
        const SizedBox(height: 9),
        _Expandable(
          title: tr('profile.assists'),
          child: _grid([
            StatTile(value: '${s.assists}', label: tr('profile.careerAssists'), valueSize: 24),
            StatTile(
                value: s.assistsPerMatch.toStringAsFixed(1),
                label: tr('profile.assistsPerMatch'),
                valueSize: 24),
            StatTile(value: '${s.contributions}', label: tr('profile.goalContributions'), valueSize: 24),
            StatTile(
                value: s.contributionsPerMatch.toStringAsFixed(1),
                label: tr('profile.contribPerMatch'),
                valueSize: 24),
          ]),
        ),
        const SizedBox(height: 9),
        _Expandable(
          title: tr('profile.recognition'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _grid([
                StatTile(value: '${s.motm}', label: tr('profile.motm'), valueSize: 24),
                StatTile(value: '${s.community}', label: tr('nav.community'), valueSize: 24),
                StatTile(value: '${s.totalMotm}', label: tr('profile.totalMotm'), valueSize: 24),
              ]),
              const SizedBox(height: 10),
              _rowStats([
                (tr('profile.currentStreak'), '${user?.currentStreak ?? 0}'),
                (tr('profile.longestStreak'), '${user?.bestStreak ?? 0}'),
                (tr('profile.longestUnbeaten'), '${user?.unbeatenStreak ?? 0}'),
              ]),
              const SizedBox(height: 4),
              Text(
                  allTime
                      ? tr('profile.statsInfoAllTime')
                      : tr('profile.statsInfoWindowed'),
                  style:
                      AppText.barlow(size: 11, color: AppColors.dim2, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _grid(List<Widget> tiles) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 9,
        crossAxisSpacing: 9,
        childAspectRatio: 2.2,
        children: tiles,
      );

  Widget _formRow(List<String> form) {
    if (form.isEmpty) {
      return Text(tr('profile.noFormYet'),
          style: AppText.barlow(size: 13, color: AppColors.dim));
    }
    return Row(
      children: [
        Text(tr('profile.form'), style: AppText.label(color: AppColors.dim)),
        const SizedBox(width: 10),
        for (final r in form)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(r,
                  style: AppText.condensed(size: 14, weight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }

  Widget _rowStats(List<(String, String)> items) => Column(
        children: [
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(it.$1,
                        style: AppText.barlow(size: 13, color: AppColors.dim)),
                    Text(it.$2,
                        style: AppText.condensed(
                            size: 20, weight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
        ],
      );

  Widget _breakdown(String title, Map<String, String> data,
      {required bool allTime}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${title.toUpperCase()}${allTime ? '' : ' · ${tr('profile.career')}'}',
              style: AppText.label(color: AppColors.dim)),
          const SizedBox(height: 9),
          if (data.isEmpty)
            Text(tr('profile.noGoalsRecorded'),
                style: AppText.barlow(size: 13, color: AppColors.dim2))
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final e in data.entries) TagChip('${_cap(e.key)} · ${e.value}'),
              ],
            ),
        ],
      ),
    );
  }

  static DateTime? _windowStart(_Filter f) {
    final now = DateTime.now();
    switch (f) {
      case _Filter.week:
        return now.subtract(const Duration(days: 7));
      case _Filter.month:
        return DateTime(now.year, now.month, 1);
      case _Filter.allTime:
        return null;
    }
  }

  Future<_WindowStats> _computeWindow(String uid, List<MatchModel> ms) async {
    var matches = 0, wins = 0, losses = 0, draws = 0;
    var goals = 0, assists = 0, motm = 0, community = 0;
    var hatTricks = 0, bestScoring = 0;
    for (final m in ms) {
      if (m.status != MatchStatus.ended) continue;
      final players = await MatchRepository.instance.getPlayers(m.id);
      MatchPlayer? me;
      for (final p in players) {
        if (p.uid == uid) {
          me = p;
          break;
        }
      }
      if (me == null) continue;
      matches++;
      final r = m.resultFor(me.team);
      if (r == 'win') {
        wins++;
      } else if (r == 'loss') {
        losses++;
      } else {
        draws++;
      }
      goals += me.goals;
      assists += me.assists;
      if (me.goals >= 3) hatTricks++;
      if (me.goals > bestScoring) bestScoring = me.goals;
      if (m.motmAUid == uid || m.motmBUid == uid) motm++;
      if (m.communityPlayerUid == uid) community++;
    }
    return _WindowStats(
      matches: matches,
      wins: wins,
      losses: losses,
      draws: draws,
      goals: goals,
      assists: assists,
      motm: motm,
      community: community,
      hatTricks: hatTricks,
      bestScoring: bestScoring,
    );
  }

  // ---- Match history ------------------------------------------------------
  Widget _matchHistory(BuildContext ctx, String? uid, List<MatchModel> matches) {
    return _Expandable(
      title: tr('profile.matchHistory'),
      trailing: matches.isEmpty ? null : '${matches.length}',
      initiallyExpanded: true,
      child: matches.isEmpty
          ? _matchEmpty(ctx)
          : Column(
              children: [
                for (final m in matches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _MatchRow(match: m, uid: uid!),
                  ),
              ],
            ),
    );
  }

  Widget _matchEmpty(BuildContext ctx) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(tr('profile.emptyFirstMatch'),
              textAlign: TextAlign.center,
              style: AppText.barlow(size: 13, color: AppColors.dim)),
        ),
        const SizedBox(height: 10),
        PrimaryButton(
          label: '＋ ${tr('drawer.createMatch')}',
          height: 50,
          fontSize: 17,
          onTap: () => Navigator.of(ctx).pushNamed(Routes.matchCreate),
        ),
      ],
    );
  }

  // ---- Teams --------------------------------------------------------------
  Widget _teamsSection(BuildContext ctx, String? uid) {
    return _Expandable(
      title: tr('drawer.myTeams'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<List<TeamModel>>(
            stream: uid == null
                ? const Stream.empty()
                : TeamRepository.instance.watchUserTeams(uid),
            builder: (context, snap) {
              final teams = snap.data ?? const <TeamModel>[];
              if (teams.isEmpty) return _mutedBox(tr('profile.noTeams'));
              return Column(
                children: [
                  for (final t in teams)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _teamCard(ctx, t, uid!),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: GestureDetector(
              onTap: () => Navigator.of(ctx).pushNamed(Routes.teamCreate),
              child: Text('＋ ${tr('common.create')}',
                  style: AppText.label(color: AppColors.txt)),
            ),
          ),
          const SizedBox(height: 14),
          SectionLabel(tr('profile.historicalTeams')),
          const SizedBox(height: 10),
          StreamBuilder<List<TeamModel>>(
            stream: uid == null
                ? const Stream.empty()
                : TeamRepository.instance.watchDeletedTeams(uid),
            builder: (context, snap) {
              final teams = snap.data ?? const <TeamModel>[];
              if (teams.isEmpty) return _mutedBox(tr('profile.noPastTeams'));
              return Column(
                children: [
                  for (final t in teams)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _teamCard(ctx, t, uid!, historical: true),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _teamCard(BuildContext ctx, TeamModel t, String uid,
      {bool historical = false}) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onTap: () =>
          Navigator.of(ctx).pushNamed(Routes.teamProfile, arguments: t.id),
      child: Row(
        children: [
          InitialsAvatar(
            initials: _teamInitials(t.name),
            size: 44,
            fontSize: 16,
            photoUrl: t.badgeUrl,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.barlow(size: 16, weight: FontWeight.w700)),
                Text(historical ? tr('profile.disbanded') : t.roleOf(uid).label,
                    style: AppText.barlow(
                        size: 12, weight: FontWeight.w600, color: AppColors.dim)),
              ],
            ),
          ),
          Text('${t.memberUids.length}',
              style: AppText.condensed(
                  size: 16, weight: FontWeight.w700, color: AppColors.dim)),
        ],
      ),
    );
  }

  // ---- Players I've played with ------------------------------------------
  Widget _playedWith(BuildContext ctx, String? uid) {
    if (uid == null) return const SizedBox.shrink();
    return _Expandable(
      title: tr('profile.playedWith'),
      child: StreamBuilder<List<PlayedWith>>(
        stream: FriendRepository.instance.watchPlayedWith(uid),
        builder: (context, snap) {
          final list = snap.data ?? const <PlayedWith>[];
          if (list.isEmpty) return _mutedBox(tr('profile.noPlayedWith'));
          return Column(
            children: [
              for (final p in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _PlayedWithRow(me: uid, entry: p),
                ),
            ],
          );
        },
      ),
    );
  }

  // ---- About --------------------------------------------------------------
  Widget _about(BuildContext ctx, AppUser user) {
    return _Expandable(
      title: tr('profile.about'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _aboutRow(tr('profile.dob'), _fmtDate(user.dob)),
          _aboutRow(tr('profile.phone'), _maskPhone(user.phone)),
          _aboutRow(tr('profile.email'), user.email.isEmpty ? '—' : user.email),
          _aboutRow(tr('drawer.language'), _trAttr(user.language)),
          _aboutRow(tr('profile.memberSince'), _fmtDate(user.createdAt)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _copyReferral(ctx, user.referralCode),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('profile.referralCode'),
                          style: AppText.label(color: AppColors.dim)),
                      const SizedBox(height: 3),
                      Text(user.referralCode.isEmpty ? '—' : user.referralCode,
                          style: AppText.condensed(
                              size: 22, weight: FontWeight.w800)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _shareReferral(user.referralCode),
                    child: Text(tr('common.share'),
                        style: AppText.label(color: AppColors.txt)),
                  ),
                  const SizedBox(width: 14),
                  Text(tr('common.copy'),
                      style: AppText.label(color: AppColors.txt)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppText.barlow(size: 13, color: AppColors.dim)),
              Flexible(
                child: Text(value,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.barlow(size: 14, weight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );

  Widget _mutedBox(String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(msg,
            textAlign: TextAlign.center,
            style: AppText.barlow(size: 13, color: AppColors.dim)),
      );

  // ---- actions ------------------------------------------------------------
  void _copyReferral(BuildContext ctx, String code) {
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    showYnoToast(ctx, tr('profile.referralCopied'));
  }

  void _shareReferral(String code) {
    if (code.isEmpty) return;
    Share.share(
        '${tr('profile.referralShareMsg1')} $code ${tr('profile.referralShareMsg2')}');
  }

  Future<void> _openSocial(
      BuildContext ctx, String platform, String handle) async {
    final url = _socialUrl(platform, handle);
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (ctx.mounted) {
      showYnoToast(ctx, tr('profile.couldNotOpenLink'));
    }
  }
}

/// Filterable per-window figures. Built either from career counters (all-time)
/// or aggregated from match data (windowed).
class _WindowStats {
  const _WindowStats({
    this.matches = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.goals = 0,
    this.assists = 0,
    this.motm = 0,
    this.community = 0,
    this.hatTricks = 0,
    this.bestScoring = 0,
  });

  final int matches, wins, losses, draws;
  final int goals, assists, motm, community, hatTricks, bestScoring;

  int get winRate => matches == 0 ? 0 : ((wins / matches) * 100).round();
  double get goalsPerMatch => matches == 0 ? 0 : goals / matches;
  double get assistsPerMatch => matches == 0 ? 0 : assists / matches;
  int get contributions => goals + assists;
  double get contributionsPerMatch =>
      matches == 0 ? 0 : contributions / matches;
  int get totalMotm => motm + community;

  factory _WindowStats.fromUser(AppUser? u) {
    if (u == null) return const _WindowStats();
    return _WindowStats(
      matches: u.matchesPlayed,
      wins: u.wins,
      losses: u.losses,
      draws: u.draws,
      goals: u.careerGoals,
      assists: u.careerAssists,
      motm: u.motmCount,
      community: u.communityCount,
      hatTricks: u.hatTricks,
      bestScoring: u.bestScoringMatch,
    );
  }
}

/// A collapsible section with a wireframe SectionLabel header + chevron. Keeps
/// the profile compact — deep sections start collapsed unless told otherwise.
class _Expandable extends StatefulWidget {
  const _Expandable({
    required this.title,
    required this.child,
    this.trailing,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final String? trailing;
  final bool initiallyExpanded;

  @override
  State<_Expandable> createState() => _ExpandableState();
}

class _ExpandableState extends State<_Expandable> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SectionLabel(
              widget.title,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.trailing != null)
                    Text(widget.trailing!,
                        style: AppText.label(color: AppColors.dim)),
                  const SizedBox(width: 6),
                  Icon(_open ? Icons.expand_less : Icons.expand_more,
                      size: 20, color: AppColors.dim),
                ],
              ),
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 11),
          widget.child,
        ],
      ],
    );
  }
}

// ---- shared helpers -------------------------------------------------------

String _teamInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

String _cap(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

String _socialIcon(String platform) {
  switch (platform.toLowerCase()) {
    case 'instagram':
      return '📷';
    case 'snapchat':
      return '👻';
    case 'tiktok':
      return '🎵';
    case 'whatsapp':
      return '💬';
    default:
      return '🔗';
  }
}

String? _socialUrl(String platform, String handle) {
  final h = handle.trim().replaceAll('@', '');
  if (h.isEmpty) return null;
  switch (platform.toLowerCase()) {
    case 'instagram':
      return 'https://instagram.com/$h';
    case 'snapchat':
      return 'https://snapchat.com/add/$h';
    case 'tiktok':
      return 'https://tiktok.com/@$h';
    case 'whatsapp':
      return 'https://wa.me/${h.replaceAll(RegExp(r'[^0-9]'), '')}';
    default:
      return handle.startsWith('http') ? handle : null;
  }
}

String _maskPhone(String? phone) {
  if (phone == null || phone.trim().isEmpty) return '—';
  final p = phone.trim();
  if (p.length <= 4) return p;
  return '•••• ${p.substring(p.length - 4)}';
}

/// Format a date as e.g. "12 Jun 2026".
String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

/// A single match-history row: date, A vs B, result badge, score, own G/A,
/// MOTM/Community badge. Loads the player's own row for goals/assists + side.
class _MatchRow extends StatefulWidget {
  const _MatchRow({required this.match, required this.uid});

  final MatchModel match;
  final String uid;

  @override
  State<_MatchRow> createState() => _MatchRowState();
}

class _MatchRowState extends State<_MatchRow> {
  late final Future<List<MatchPlayer>> _players =
      MatchRepository.instance.getPlayers(widget.match.id);

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final uid = widget.uid;
    return FutureBuilder<List<MatchPlayer>>(
      future: _players,
      builder: (context, snap) {
        MatchPlayer? me;
        for (final p in (snap.data ?? const <MatchPlayer>[])) {
          if (p.uid == uid) {
            me = p;
            break;
          }
        }
        final side = me?.team;
        final result = side == null ? null : match.resultFor(side);
        final isMotm = match.motmAUid == uid || match.motmBUid == uid;
        final isCommunity = match.communityPlayerUid == uid;
        return SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          onTap: () {
            final String route;
            switch (match.status) {
              case MatchStatus.live:
                route = Routes.live;
                break;
              case MatchStatus.lobby:
                route = Routes.lobby;
                break;
              case MatchStatus.ended:
              case MatchStatus.abandoned:
                route = Routes.postMatch;
                break;
            }
            Navigator.of(context).pushNamed(route, arguments: match.id);
          },
          child: Row(
            children: [
              _resultBadge(match.status, result),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${match.teamAName} vs ${match.teamBName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.barlow(size: 15, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(_fmtDate(match.createdAt),
                            style: AppText.barlow(
                                size: 12, color: AppColors.dim2)),
                        if (me != null) ...[
                          const SizedBox(width: 8),
                          Text('⚽ ${me.goals}  🅰 ${me.assists}',
                              style: AppText.barlow(
                                  size: 12, color: AppColors.dim)),
                        ],
                        if (isMotm || isCommunity) ...[
                          const SizedBox(width: 8),
                          Text(isMotm ? '★ MOTM' : '♥ COM',
                              style: AppText.barlow(
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color: AppColors.txt)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text('${match.scoreA}–${match.scoreB}',
                  style: AppText.condensed(size: 19, weight: FontWeight.w800)),
            ],
          ),
        );
      },
    );
  }

  Widget _resultBadge(MatchStatus status, String? result) {
    String label;
    if (status == MatchStatus.live) {
      label = 'LIVE';
    } else if (status == MatchStatus.lobby) {
      label = 'LOB';
    } else if (result == 'win') {
      label = 'W';
    } else if (result == 'loss') {
      label = 'L';
    } else if (result == 'draw') {
      label = 'D';
    } else {
      label = 'FT';
    }
    return Container(
      width: 42,
      height: 40,
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12)),
      alignment: Alignment.center,
      child: Text(label,
          style: AppText.condensed(size: 15, weight: FontWeight.w800)),
    );
  }
}

/// A "played with" row with an Add Friend affordance reflecting live state.
class _PlayedWithRow extends StatelessWidget {
  const _PlayedWithRow({required this.me, required this.entry});

  final String me;
  final PlayedWith entry;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      onTap: () => Navigator.of(context)
          .pushNamed(Routes.profilePublic, arguments: entry.uid),
      child: Row(
        children: [
          InitialsAvatar(initials: _teamInitials(entry.name), size: 40, fontSize: 15),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name.isEmpty ? tr('role.player') : entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.barlow(size: 15, weight: FontWeight.w700)),
                Text('${tr('profile.played')} ${entry.count}×',
                    style: AppText.barlow(size: 12, color: AppColors.dim2)),
              ],
            ),
          ),
          _friendAction(context),
        ],
      ),
    );
  }

  Widget _friendAction(BuildContext context) {
    return StreamBuilder<FriendEdge?>(
      stream: FriendRepository.instance.watchFriendship(me, entry.uid),
      builder: (context, snap) {
        final edge = snap.data;
        String label;
        VoidCallback? onTap;
        if (edge == null) {
          label = '＋ ${tr('common.add')}';
          onTap = () async {
            final myUser = await UserRepository.instance.getUser(me);
            await FriendRepository.instance.sendRequest(me, entry.uid,
                myName: myUser?.name ?? tr('profile.aPlayer'));
            if (context.mounted) {
              showYnoToast(context, tr('profile.friendRequestSent'));
            }
          };
        } else if (edge.status == FriendStatus.accepted) {
          label = tr('drawer.friends');
        } else {
          label = tr('profile.pending');
        }
        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(label, style: AppText.label(color: AppColors.txt)),
          ),
        );
      },
    );
  }
}
