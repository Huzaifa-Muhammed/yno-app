import 'package:flutter/material.dart';
import '../services/rewards_config.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../links.dart';
import '../services/auth_repository.dart';
import '../services/models.dart';
import '../services/user_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/header.dart';
import '../widgets/motion.dart';
import '../widgets/yno_scaffold.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  int _referrals = 0;
  List<AppUser> _referred = const [];
  bool _loadingList = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = AuthRepository.instance.uid;
    if (uid == null) {
      setState(() => _loadingList = false);
      return;
    }
    final results = await Future.wait([
      UserRepository.instance.countReferrals(uid),
      UserRepository.instance.referredUsers(uid),
    ]);
    if (!mounted) return;
    setState(() {
      _referrals = results[0] as int;
      _referred = results[1] as List<AppUser>;
      _loadingList = false;
    });
  }

  /// The shared text: the code in words, then the link that carries it.
  ///
  /// The link is built here rather than baked into `shareMsgB` because it
  /// contains the code — the whole point of the change. The old message ended
  /// in a bare `kJoinBaseUrl`, which pointed at the *match* join page and
  /// carried no referral at all, so every tap lost the referral and the friend
  /// had to retype the code by hand.
  String _shareMessage(String code) =>
      '${tr('misc.shareMsgA')}$code${tr('misc.shareMsgB')}${referralLink(code)}';

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    showYnoToast(context, tr('misc.codeCopied'));
  }

  Future<void> _shareWhatsApp(String code) async {
    final msg = _shareMessage(code);
    final wa = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}');
    try {
      if (await canLaunchUrl(wa)) {
        final ok = await launchUrl(wa, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
    } catch (_) {/* fall through to native share sheet */}
    // Fallback: OS share sheet via share_plus.
    try {
      await Share.share(msg, subject: tr('misc.shareSubject'));
    } catch (_) {
      if (!mounted) return;
      showYnoToast(context, tr('misc.couldNotShare'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthRepository.instance.uid;
    return YnoScaffold(
      appBarTitle: tr('misc.referEarn'),
      child: SafeArea(
        top: false,
        bottom: false,
        child: StreamBuilder<AppUser?>(
          stream: uid == null
              ? const Stream.empty()
              : UserRepository.instance.watchUser(uid),
          builder: (context, snap) {
            final user = snap.data;
            final code = user?.referralCode ?? '——';
            final hasCode = user?.referralCode != null &&
                user!.referralCode.isNotEmpty;
            return ListView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
              children: [
                const Center(child: Text('🎁', style: TextStyle(fontSize: 60))),
                const SizedBox(height: 6),
                Text(tr('misc.inviteEarnHeadline'),
                    textAlign: TextAlign.center,
                    style: AppText.condensed(
                        size: 30, weight: FontWeight.w800, height: 1)),
                const SizedBox(height: 10),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: AppText.barlow(
                            size: 14, color: AppColors.dim, height: 1.45),
                        children: [
                          TextSpan(text: tr('misc.rewardYou')),
                          TextSpan(
                              text: tr('misc.rewardFriend'),
                              style: AppText.barlow(
                                  size: 14,
                                  weight: FontWeight.w700,
                                  color: AppColors.txt)),
                          TextSpan(text: tr('misc.rewardEachEarn')),
                          TextSpan(
                              text: '+${RewardsRepository.current.referralPoints} ${tr('misc.points')}',
                              style: AppText.barlow(
                                  size: 14,
                                  weight: FontWeight.w800,
                                  color: AppColors.txt)),
                          TextSpan(text: tr('misc.rewardMoment')),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FadeSlideIn(
                  child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.line2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(tr('misc.yourCode'),
                          style: AppText.barlow(
                              size: 11,
                              weight: FontWeight.w700,
                              color: AppColors.dim2,
                              letterSpacing: 1.1)),
                      const SizedBox(height: 8),
                      Text(code,
                          style: AppText.condensed(
                              size: 38,
                              weight: FontWeight.w800,
                              letterSpacing: 4)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              label: '📋 ${tr('common.copy')}',
                              condensed: false,
                              fontSize: 15,
                              height: 48,
                              onTap: hasCode ? () => _copy(code) : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PrimaryButton(
                              label: '💬 WhatsApp',
                              fontSize: 15,
                              height: 48,
                              color: const Color(0xFF25D366),
                              onTap:
                                  hasCode ? () => _shareWhatsApp(code) : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ),
                const SizedBox(height: 14),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 80),
                  child: Row(
                    children: [
                      Expanded(
                        child: StatTile(
                            value: '$_referrals',
                            label: tr('misc.friendsJoined'),
                            valueSize: 32),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatTile(
                            value: '${_referrals * RewardsRepository.current.referralPoints}',
                            label: tr('misc.pointsFromReferrals'),
                            valueSize: 32),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SectionLabel(tr('misc.whoJoined')),
                const SizedBox(height: 10),
                _referredList(),
                const SizedBox(height: 18),
                Text(
                    tr('misc.referralFooter'),
                    textAlign: TextAlign.center,
                    style: AppText.barlow(
                        size: 12, color: AppColors.dim2, height: 1.5)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _referredList() {
    if (_loadingList) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 26),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_referred.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Text(tr('misc.noReferralsYet'),
                  style: AppText.barlow(size: 14, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(tr('misc.shareToEarn'),
                  textAlign: TextAlign.center,
                  style: AppText.barlow(size: 12, color: AppColors.dim2)),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        for (int i = 0; i < _referred.length; i++)
          FadeSlideIn(
              delay: Duration(milliseconds: 50 * (i > 8 ? 8 : i)),
              child: _referredRow(_referred[i])),
      ],
    );
  }

  Widget _referredRow(AppUser u) {
    final joined = u.createdAt == null
        ? '—'
        : '${tr('misc.joined')} ${DateFormat('MMM d, yyyy').format(u.createdAt!)}';
    final displayName = u.name.trim().isNotEmpty
        ? u.name
        : (u.handle.isNotEmpty ? '@${u.handle}' : tr('misc.ynoPlayer'));
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          InitialsAvatar(
            initials: u.initials,
            size: 40,
            fontSize: 15,
            photoUrl: (u.photoUrl?.isEmpty ?? true) ? null : u.photoUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.barlow(size: 14, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(joined,
                    style: AppText.barlow(size: 12, color: AppColors.dim2)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('+${RewardsRepository.current.referralPoints} ${tr('misc.pts')}',
              style: AppText.barlow(
                  size: 13,
                  weight: FontWeight.w800,
                  color: AppColors.txt)),
        ],
      ),
    );
  }
}
