import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
import '../services/match_repository.dart';
import '../services/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/confirm.dart';
import '../widgets/header.dart';
import '../widgets/match_actions.dart';
import '../widgets/motion.dart';
import '../widgets/yno_scaffold.dart';

/// **Draft Matches** — the drawer's home for everything the user is in or has
/// played: the match they are in right now, their one unstarted **draft**, and
/// their played history.
///
/// Reached only from the side drawer, whose row (and the home hamburger) wears
/// a red dot while a draft is waiting — a draft self-deletes after 2 days, so
/// it needs to be visible without opening anything.
///
/// A user may hold **one** draft at a time; the rule is enforced in
/// [openCreateMatch], which is why the draft section shows a single match
/// rather than a list.
class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  @override
  void initState() {
    super.initState();
    // No Cloud Functions — clean up the user's expired draft lazily on open.
    final uid = AuthRepository.instance.uid;
    if (uid != null) MatchRepository.instance.sweepStaleDrafts(uid);
  }

  Future<void> _deleteDraft(MatchModel draft) async {
    final ok = await showConfirm(
      context,
      title: tr('draft.deleteTitle'),
      message: '${tr('draft.deleteBody')} '
          '"${draft.teamAName} ${tr('match.vs')} ${draft.teamBName}"',
      confirmLabel: tr('draft.delete'),
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await MatchRepository.instance.quitDiscard(draft.id);
      if (mounted) showYnoToast(context, tr('draft.deleted'));
    } catch (_) {
      if (mounted) showYnoToast(context, tr('draft.deleteFailed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthRepository.instance.uid;
    return YnoScaffold(
      appBarTitle: tr('matches.title'),
      child: SafeArea(
        top: false,
        // Two streams: the draft is read through `watchMyDraft` rather than
        // filtered out of the list below, because that is the query that also
        // discards a draft past its TTL.
        child: StreamBuilder<List<MatchModel>>(
          stream: uid == null
              ? const Stream.empty()
              : MatchRepository.instance.watchUserMatches(uid),
          builder: (context, listSnap) {
            return StreamBuilder<MatchModel?>(
              stream: uid == null
                  ? const Stream.empty()
                  : MatchRepository.instance.watchMyDraft(uid),
              builder: (context, draftSnap) {
                if (listSnap.connectionState == ConnectionState.waiting &&
                    draftSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = listSnap.data ?? const <MatchModel>[];
                final draft = draftSnap.data;
                final ongoing = all
                    .where((m) => m.status == MatchStatus.live)
                    .toList();
                final played = all
                    .where((m) =>
                        m.status == MatchStatus.ended ||
                        m.status == MatchStatus.abandoned)
                    .toList();

                if (ongoing.isEmpty && played.isEmpty && draft == null) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
                    children: [FadeSlideIn(child: _empty(context))],
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
                  children: [
                    if (ongoing.isNotEmpty) ...[
                      SectionLabel(tr('matches.ongoing')),
                      const SizedBox(height: 10),
                      for (final m in ongoing) ...[
                        FadeSlideIn(child: _MatchRow(match: m)),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 12),
                    ],
                    if (draft != null) ...[
                      SectionLabel(tr('matches.draft')),
                      const SizedBox(height: 10),
                      FadeSlideIn(child: _warning()),
                      const SizedBox(height: 12),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 60),
                        child: _DraftCard(
                          draft: draft,
                          onDelete: () => _deleteDraft(draft),
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                    if (played.isNotEmpty) ...[
                      SectionLabel('${tr('matches.played')} · ${played.length}'),
                      const SizedBox(height: 10),
                      for (final m in played) ...[
                        _MatchRow(match: m),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Nothing at all — explain the one-draft-at-a-time rule and offer to create.
  Widget _empty(BuildContext context) => Column(
        children: [
          const SizedBox(height: 30),
          const Text('📝', style: TextStyle(fontSize: 46)),
          const SizedBox(height: 14),
          Text(tr('matches.emptyTitle'),
              textAlign: TextAlign.center,
              style: AppText.condensed(size: 24, weight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(tr('draft.emptyBody'),
              textAlign: TextAlign.center,
              style:
                  AppText.barlow(size: 14, color: AppColors.dim, height: 1.5)),
          const SizedBox(height: 24),
          PrimaryButton(
            label: tr('draft.createMatch'),
            onTap: () => openCreateMatch(context),
          ),
        ],
      );

  /// The 2-day deletion warning — the reason the draft is surfaced at all.
  Widget _warning() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 9),
            Expanded(
              child: Text(tr('draft.warning'),
                  style: AppText.barlow(
                      size: 12.5, color: AppColors.txt, height: 1.45)),
            ),
          ],
        ),
      );
}

/// A live or played match. Tapping routes by status — live matches to the live
/// screen, finished ones to their scorecard.
class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match});

  final MatchModel match;

  bool get _live => match.status == MatchStatus.live;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      onTap: () => Navigator.pushNamed(
          context, _live ? Routes.live : Routes.postMatch,
          arguments: match.id),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_live) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                            color: AppColors.primary, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(tr('matches.liveNow').toUpperCase(),
                          style: AppText.label(color: AppColors.primary)),
                    ] else
                      Text(_fmtDate(match.endedAt ?? match.createdAt),
                          style:
                              AppText.barlow(size: 11.5, color: AppColors.dim2)),
                  ],
                ),
                const SizedBox(height: 5),
                Text('${match.teamAName} ${tr('match.vs')} ${match.teamBName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppText.condensed(size: 19, weight: FontWeight.w800)),
                if (match.hasFixedFormat) ...[
                  const SizedBox(height: 2),
                  Text(match.format,
                      style: AppText.barlow(size: 11.5, color: AppColors.dim2)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text('${match.scoreA} – ${match.scoreB}',
              style: AppText.condensed(
                  size: 24,
                  weight: FontWeight.w800,
                  color: _live ? AppColors.primary : AppColors.txt)),
        ],
      ),
    );
  }
}

/// The single draft: teams, meta, a live "deletes in" countdown, and the two
/// things you can do with it — resume it in the lobby, or delete it.
class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.draft, required this.onDelete});

  final MatchModel draft;
  final VoidCallback onDelete;

  /// Human "Deletes in Xd/Xh", from createdAt + [kDraftTtl].
  String _deletesLabel() {
    final created = draft.createdAt;
    if (created == null) return tr('draft.deletesSoon');
    final left = created.add(kDraftTtl).difference(DateTime.now());
    if (left.isNegative) return tr('draft.deletesSoon');
    if (left.inHours >= 24) {
      return '${tr('draft.deletesIn')} ${(left.inHours / 24).ceil()}d';
    }
    if (left.inHours >= 1) {
      return '${tr('draft.deletesIn')} ${left.inHours}h';
    }
    return tr('draft.deletesSoon');
  }

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
                ),
                child: Text(tr('draft.badge'),
                    style: AppText.condensed(
                        size: 12,
                        weight: FontWeight.w800,
                        color: AppColors.gold,
                        letterSpacing: 1)),
              ),
              const Spacer(),
              Text('⚠️ ${_deletesLabel()}',
                  style: AppText.barlow(
                      size: 11.5,
                      weight: FontWeight.w700,
                      color: AppColors.gold)),
            ],
          ),
          const SizedBox(height: 14),
          Text('${draft.teamAName} ${tr('match.vs')} ${draft.teamBName}',
              style: AppText.condensed(size: 26, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
              [
                _fmtDate(draft.createdAt),
                if (draft.hasFixedFormat) draft.format,
                if (draft.location.isNotEmpty) '📍 ${draft.location}',
              ].join('  ·  '),
              style: AppText.barlow(size: 12.5, color: AppColors.dim2)),
          const SizedBox(height: 18),
          PrimaryButton(
            label: tr('draft.resume'),
            onTap: () =>
                Navigator.pushNamed(context, Routes.lobby, arguments: draft.id),
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: tr('draft.delete'),
            danger: true,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
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
