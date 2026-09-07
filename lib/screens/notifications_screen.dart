import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/auth_repository.dart';
import '../services/friend_repository.dart';
import '../services/models.dart';
import '../services/notification_repository.dart';
import '../services/team_repository.dart';
import '../services/user_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/header.dart';
import '../widgets/motion.dart';
import '../widgets/yno_scaffold.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _timeAgo(DateTime? at) {
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return tr('misc.justNow');
    if (d.inMinutes < 60) return '${d.inMinutes}${tr('misc.minAgo')}';
    if (d.inHours < 24) return '${d.inHours}${tr('misc.hourAgo')}';
    if (d.inDays < 7) return '${d.inDays}${tr('misc.dayAgo')}';
    return '${(d.inDays / 7).floor()}${tr('misc.weekAgo')}';
  }

  /// A distinct glyph per notification category (Section 10).
  String _iconFor(NotifCategory c) {
    switch (c) {
      case NotifCategory.teamInvite:
      case NotifCategory.teamUpdate:
        return '🛡';
      case NotifCategory.rival:
        return '⚔';
      case NotifCategory.matchInvite:
      case NotifCategory.matchUpdate:
        return '⚽';
      case NotifCategory.matchResult:
        return '🏆';
      case NotifCategory.friend:
        return '🤝';
      case NotifCategory.follow:
        return '👁';
      case NotifCategory.points:
        return '⭐';
      case NotifCategory.guest:
        return '👤';
      case NotifCategory.award:
        return '🏅';
      case NotifCategory.general:
        return '🔔';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthRepository.instance.uid;
    return YnoScaffold(
      appBarTitle: tr('misc.notifications'),
      appBarActions: uid == null
          ? null
          : [
              TextButton(
                onPressed: () {
                  NotificationRepository.instance.markAllRead(uid);
                  showYnoToast(context, tr('misc.allMarkedRead'));
                },
                child: Text(tr('misc.markAllRead'),
                    style: AppText.barlow(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppColors.txt)),
              ),
            ],
      child: SafeArea(
        top: false,
        bottom: false,
        child: StreamBuilder<List<AppNotification>>(
          stream: uid == null
              ? const Stream.empty()
              : NotificationRepository.instance.watch(uid),
          builder: (context, snap) {
            final items = snap.data ?? const <AppNotification>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
              children: [
                if (snap.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (items.isEmpty)
                  _empty()
                else
                  for (int i = 0; i < items.length; i++)
                    FadeSlideIn(
                        delay: Duration(milliseconds: 50 * (i > 8 ? 8 : i)),
                        child: _row(context, uid!, items[i])),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _inviteBtn(String label, VoidCallback onTap, {bool primary = false}) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: primary ? AppColors.primary : AppColors.surface,
            border: Border.all(
                color: primary ? AppColors.primary : AppColors.line),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(label,
              style: AppText.barlow(
                  size: 13,
                  weight: FontWeight.w800,
                  color: primary ? AppColors.ink : AppColors.txt)),
        ),
      );

  /// Accept / Decline for an incoming friend request, shown inline on the bell.
  ///
  /// This is the app's primary way to answer a request now that the Friends
  /// page is not in the drawer. It keys off the live friendship edge rather
  /// than the notification text, which matters because `NotifCategory.friend`
  /// covers BOTH "X sent you a request" and "X accepted yours" — only a
  /// still-pending edge that the *other* person opened is answerable, and the
  /// buttons disappear by themselves if it's answered somewhere else.
  Widget _friendRequestActions(
      BuildContext context, String uid, AppNotification n) {
    return StreamBuilder<FriendEdge?>(
      stream: FriendRepository.instance.watchFriendship(uid, n.arg!),
      builder: (context, snap) {
        final edge = snap.data;
        if (edge == null ||
            edge.status != FriendStatus.pending ||
            edge.requester != n.arg) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              _inviteBtn(tr('social.accept'), primary: true, () async {
                final me = await UserRepository.instance.getUser(uid);
                await FriendRepository.instance.acceptRequest(uid, n.arg!,
                    myName: me?.name ?? tr('social.aPlayer'));
                await NotificationRepository.instance.remove(uid, n.id);
                if (context.mounted) {
                  showYnoToast(context, tr('social.friendAdded'));
                }
              }),
              const SizedBox(width: 8),
              _inviteBtn(tr('social.decline'), () async {
                await FriendRepository.instance.removeOrDecline(uid, n.arg!);
                await NotificationRepository.instance.remove(uid, n.id);
                if (context.mounted) {
                  showYnoToast(context, tr('social.requestDeclined'));
                }
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _empty() => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              const Text('🔔', style: TextStyle(fontSize: 34)),
              const SizedBox(height: 10),
              Text(tr('misc.allCaughtUp'),
                  style: AppText.barlow(size: 15, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(tr('misc.notifEmptyBody'),
                  textAlign: TextAlign.center,
                  style: AppText.barlow(size: 13, color: AppColors.dim2)),
            ],
          ),
        ),
      );

  Widget _row(BuildContext context, String uid, AppNotification n) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!n.read) {
          NotificationRepository.instance.markRead(uid, n.id);
        }
        final route = n.route;
        if (route != null && route.isNotEmpty) {
          Navigator.pushNamed(context, route, arguments: n.arg);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: n.read ? AppColors.line : AppColors.line2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(_iconFor(n.category),
                  style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(n.title,
                      style: AppText.barlow(
                          size: 14, weight: FontWeight.w700, height: 1.25)),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(n.body,
                        style: AppText.barlow(size: 13, color: AppColors.dim)),
                  ],
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(_timeAgo(n.at),
                          style:
                              AppText.barlow(size: 12, color: AppColors.dim2)),
                      if (n.route != null && n.route!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(tr('misc.tapToOpen'),
                            style: AppText.barlow(
                                size: 12,
                                weight: FontWeight.w600,
                                color: AppColors.dim)),
                      ],
                    ],
                  ),
                  // A team invite is answered right here: Accept joins the team,
                  // Reject notifies the owner. Both then clear this notification.
                  if (n.category == NotifCategory.teamInvite &&
                      n.arg != null &&
                      n.arg!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _inviteBtn(tr('social.accept'), primary: true, () async {
                          await TeamRepository.instance.acceptInvite(n.arg!, uid);
                          await NotificationRepository.instance.remove(uid, n.id);
                          if (context.mounted) {
                            showYnoToast(context, tr('teams.inviteAccepted'));
                          }
                        }),
                        const SizedBox(width: 8),
                        _inviteBtn(tr('teams.reject'), () async {
                          await TeamRepository.instance
                              .declineInvite(n.arg!, uid);
                          await NotificationRepository.instance.remove(uid, n.id);
                          if (context.mounted) {
                            showYnoToast(context, tr('teams.inviteRejected'));
                          }
                        }),
                      ],
                    ),
                  ],
                  // A friend request is answered right here too.
                  if (n.category == NotifCategory.friend &&
                      n.arg != null &&
                      n.arg!.isNotEmpty)
                    _friendRequestActions(context, uid, n),
                ],
              ),
            ),
            if (!n.read) ...[
              const SizedBox(width: 8),
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                    color: AppColors.txt, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
