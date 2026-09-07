import 'package:flutter/material.dart';
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
import '../widgets/yno_scaffold.dart';

/// Translate a stored attribute value (position / foot / skill) to the active
/// language; unknown values pass through unchanged.
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
  };
  final k = map[v];
  return k == null ? v : tr(k);
}

/// Section 12 — public view of another player's profile. Public information
/// only: no DOB / phone / email / played-with / referral / about / edit.
class PublicProfileScreen extends StatelessWidget {
  const PublicProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final arg = ModalRoute.of(context)?.settings.arguments;
    final me = AuthRepository.instance.uid;
    final targetUid =
        (arg is String && arg.isNotEmpty) ? arg : me;
    final isSelf = targetUid == me;

    return YnoScaffold(
      appBarTitle: tr('profile.title'),
      appBarActions: targetUid == null
          ? null
          : [
              IconButton(
                icon: const Icon(Icons.ios_share, color: AppColors.txt),
                tooltip: tr('common.share'),
                onPressed: () async {
                  final u = await UserRepository.instance.getUser(targetUid);
                  _share(u, targetUid);
                },
              ),
            ],
      child: SafeArea(
        top: false,
        bottom: false,
        child: StreamBuilder<AppUser?>(
          stream: targetUid == null
              ? const Stream.empty()
              : UserRepository.instance.watchUser(targetUid),
          builder: (context, snap) {
            final user = snap.data;
            // A deactivated account is not viewable by others.
            if (user != null && user.deactivated && !isSelf) {
              return _unavailable(context);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
              children: [
                FadeSlideIn(child: _header(context, user, targetUid)),
                const SizedBox(height: 18),
                if (!isSelf && me != null && targetUid != null)
                  FadeSlideIn(
                      delay: const Duration(milliseconds: 80),
                      child: _actions(context, me, targetUid, user)),
                if (!isSelf) const SizedBox(height: 20),
                FadeSlideIn(
                    delay: const Duration(milliseconds: 160),
                    child: _gatedContent(context, me, targetUid, user, isSelf)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---- Deactivated / unavailable -----------------------------------------
  Widget _unavailable(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
      children: [
        const SizedBox(height: 80),
        const Center(
          child: Text('👤', style: TextStyle(fontSize: 44)),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(tr('profile.unavailable'),
              style: AppText.condensed(size: 24, weight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(tr('profile.deactivated'),
              textAlign: TextAlign.center,
              style: AppText.barlow(size: 14, color: AppColors.dim)),
        ),
      ],
    );
  }

  // ---- Header -------------------------------------------------------------
  Widget _header(BuildContext context, AppUser? user, String? uid) {
    final chips = <String>[
      if (user?.position != null && user!.position!.isNotEmpty)
        '⚡ ${_trAttr(user.position!)}',
      if (user?.preferredFoot != null && user!.preferredFoot!.isNotEmpty)
        '🦶 ${_trAttr(user.preferredFoot!)}',
      if (user?.skillLevel != null && user!.skillLevel!.isNotEmpty)
        '★ ${_trAttr(user.skillLevel!)}',
    ];
    return Column(
      children: [
        Center(
          child: InitialsAvatar(
              initials: user?.initials ?? '··',
              size: 96,
              fontSize: 36,
              photoUrl: user?.photoUrl),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(user?.name ?? tr('common.loading'),
              style:
                  AppText.condensed(size: 28, weight: FontWeight.w800, height: 1)),
        ),
        if (user != null)
          Center(
            child: Text('@${user.handle}',
                style: AppText.barlow(size: 14, color: AppColors.dim)),
          ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 12),
          Center(
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              alignment: WrapAlignment.center,
              children: [for (final c in chips) TagChip(c)],
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (uid != null) _teamBadges(context, uid),
        _socialLinks(context, user),
      ],
    );
  }

  Widget _teamBadges(BuildContext context, String uid) {
    return StreamBuilder<List<TeamModel>>(
      stream: TeamRepository.instance.watchUserTeams(uid),
      builder: (context, snap) {
        final teams = snap.data ?? const <TeamModel>[];
        if (teams.isEmpty) return const SizedBox.shrink();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final t in teams)
              GestureDetector(
                onTap: () => Navigator.of(context)
                    .pushNamed(Routes.teamProfile, arguments: t.id),
                child: InitialsAvatar(
                  initials: _teamInitials(t.name),
                  size: 40,
                  fontSize: 15,
                  photoUrl: t.badgeUrl,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _socialLinks(BuildContext context, AppUser? user) {
    if (user == null) return const SizedBox.shrink();
    // Public view: only links set to public or friends-only.
    final links = <MapEntry<String, String>>[];
    for (final e in user.socialLinks.entries) {
      if (e.value.trim().isEmpty) continue;
      final vis = user.socialVisibility[e.key] ?? 'off';
      if (vis == 'public' || vis == 'friends') links.add(e);
    }
    if (links.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final e in links)
            GestureDetector(
              onTap: () => _openSocial(context, e.key, e.value),
              child: TagChip('${_socialIcon(e.key)} ${_cap(e.key)}'),
            ),
        ],
      ),
    );
  }

  // ---- Follow / Add Friend / Share ---------------------------------------
  Widget _actions(
      BuildContext context, String me, String target, AppUser? user) {
    return Row(
      children: [
        Expanded(child: _addFriendButton(context, me, target)),
        const SizedBox(width: 10),
        Expanded(child: _followButton(context, me, target)),
      ],
    );
  }

  Widget _followButton(BuildContext context, String me, String target) {
    return StreamBuilder<AppUser?>(
      stream: UserRepository.instance.watchUser(me),
      builder: (context, snap) {
        final following = snap.data?.following.contains(target) ?? false;
        return SecondaryButton(
          label: following ? tr('profile.following') : tr('profile.follow'),
          height: 46,
          fontSize: 15,
          condensed: false,
          onTap: () async {
            if (following) {
              await UserRepository.instance.unfollow(me, target);
              if (context.mounted) showYnoToast(context, tr('profile.unfollowed'));
            } else {
              await UserRepository.instance.follow(me, target);
              if (context.mounted) showYnoToast(context, tr('profile.following'));
            }
          },
        );
      },
    );
  }

  Widget _addFriendButton(BuildContext context, String me, String target) {
    return StreamBuilder<FriendEdge?>(
      stream: FriendRepository.instance.watchFriendship(me, target),
      builder: (context, snap) {
        final edge = snap.data;
        String label;
        VoidCallback? onTap;
        if (edge == null) {
          label = '＋ ${tr('profile.addFriend')}';
          onTap = () async {
            final myUser = await UserRepository.instance.getUser(me);
            await FriendRepository.instance.sendRequest(me, target,
                myName: myUser?.name ?? tr('profile.aPlayer'));
            if (context.mounted) {
              showYnoToast(context, tr('profile.friendRequestSent'));
            }
          };
        } else if (edge.status == FriendStatus.accepted) {
          label = '✓ ${tr('drawer.friends')}';
        } else {
          label = tr('profile.pending');
        }
        return PrimaryButton(
          label: label,
          height: 46,
          fontSize: 15,
          onTap: onTap ?? () {},
        );
      },
    );
  }

  // ---- Privacy gate -------------------------------------------------------
  /// Stats + match history are open to the player themselves, to anyone when the
  /// profile is public, and to accepted friends when it's private. Otherwise a
  /// "private profile" card is shown (the Add Friend button lives in _actions
  /// above).
  Widget _gatedContent(BuildContext context, String? me, String? targetUid,
      AppUser? user, bool isSelf) {
    final open = isSelf || (user?.profilePublic ?? true);
    if (open) return _statsAndHistory(context, targetUid, user);
    if (me == null || targetUid == null) return _privateCard();
    return StreamBuilder<FriendEdge?>(
      stream: FriendRepository.instance.watchFriendship(me, targetUid),
      builder: (context, snap) {
        final accepted = snap.data?.status == FriendStatus.accepted;
        return accepted
            ? _statsAndHistory(context, targetUid, user)
            : _privateCard();
      },
    );
  }

  Widget _statsAndHistory(
          BuildContext context, String? targetUid, AppUser? user) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stats(user),
          const SizedBox(height: 22),
          _matchHistory(context, targetUid),
        ],
      );

  Widget _privateCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Text('🔒', style: TextStyle(fontSize: 34)),
            const SizedBox(height: 12),
            Text(tr('profile.privateTitle'),
                style: AppText.condensed(size: 20, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(tr('profile.privateBody'),
                textAlign: TextAlign.center,
                style: AppText.barlow(size: 14, color: AppColors.dim, height: 1.5)),
          ],
        ),
      );

  // ---- Stats (all-time) ---------------------------------------------------
  Widget _stats(AppUser? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(tr('profile.matchRecord')),
        const SizedBox(height: 11),
        _grid([
          StatTile(
              value: '${user?.matchesPlayed ?? 0}',
              label: tr('profile.matches'),
              valueSize: 26),
          StatTile(value: '${user?.wins ?? 0}', label: tr('profile.wins'), valueSize: 26),
          StatTile(
              value: '${user?.careerGoals ?? 0}',
              label: tr('profile.goals'),
              valueSize: 26),
          StatTile(
              value: '${user?.winRate ?? 0}%', label: tr('profile.winPct'), valueSize: 26),
        ]),
        const SizedBox(height: 14),
        _formRow(user?.formLast5 ?? const []),
        const SizedBox(height: 22),
        SectionLabel(tr('profile.scoringRecognition')),
        const SizedBox(height: 11),
        _grid([
          StatTile(
              value: '${user?.careerGoals ?? 0}',
              label: tr('profile.careerGoals'),
              valueSize: 26),
          StatTile(
              value: '${user?.careerAssists ?? 0}',
              label: tr('profile.careerAssists'),
              valueSize: 26),
          StatTile(
              value: (user?.goalsPerMatch ?? 0).toStringAsFixed(1),
              label: tr('profile.goalsPerMatch'),
              valueSize: 26),
          StatTile(
              value: '${user?.totalMotm ?? 0}',
              label: tr('profile.totalMotm'),
              valueSize: 26),
        ]),
      ],
    );
  }

  Widget _grid(List<Widget> tiles) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 9,
        crossAxisSpacing: 9,
        childAspectRatio: 2.1,
        children: tiles,
      );

  Widget _formRow(List<String> form) {
    if (form.isEmpty) {
      return Text(tr('profile.noMatchesYet'),
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

  // ---- Match history ------------------------------------------------------
  Widget _matchHistory(BuildContext context, String? uid) {
    return StreamBuilder<List<MatchModel>>(
      stream: uid == null
          ? const Stream.empty()
          : MatchRepository.instance.watchUserMatches(uid),
      builder: (context, snap) {
        final matches = snap.data ?? const <MatchModel>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(tr('profile.matchHistory')),
            const SizedBox(height: 11),
            if (matches.isEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(tr('profile.noMatchesPlayed'),
                    textAlign: TextAlign.center,
                    style: AppText.barlow(size: 13, color: AppColors.dim)),
              )
            else
              for (final m in matches)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _MatchRow(match: m, uid: uid!),
                ),
          ],
        );
      },
    );
  }

  void _share(AppUser? user, String? uid) {
    final name = user?.name ?? tr('profile.thisPlayer');
    Share.share(
        '${tr('profile.shareCheck')} $name ${tr('profile.shareOnYno')}! yno://profile/${uid ?? ''}');
  }

  Future<void> _openSocial(
      BuildContext context, String platform, String handle) async {
    final url = _socialUrl(platform, handle);
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      showYnoToast(context, tr('profile.couldNotOpenLink'));
    }
  }
}

// ---- helpers --------------------------------------------------------------

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

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

/// Match-history row (public view — same layout as own profile).
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
          onTap: () => Navigator.of(context)
              .pushNamed(Routes.postMatch, arguments: match.id),
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
    if (status != MatchStatus.ended) {
      label = status == MatchStatus.live ? 'LIVE' : 'LOB';
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
