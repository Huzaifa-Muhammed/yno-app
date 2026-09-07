import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/app_version.dart';
import '../services/auth_repository.dart';
import '../services/models.dart';
import '../services/user_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/confirm.dart';
import '../widgets/motion.dart';
import '../widgets/yno_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _matchAlerts = true;
  bool _friendActivity = false;
  bool _contactSync = false;
  bool _profilePublic = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  /// Seed the toggles from the stored user prefs.
  Future<void> _loadPrefs() async {
    final uid = AuthRepository.instance.uid;
    if (uid == null) return;
    final user = await UserRepository.instance.getUser(uid);
    if (user == null || !mounted) return;
    setState(() {
      _matchAlerts = user.notifyMatchAlerts;
      _friendActivity = user.notifyFriendActivity;
      _contactSync = user.contactSync;
      _profilePublic = user.profilePublic;
    });
  }

  /// Optimistically flip a toggle and persist it in the background.
  void _setPref({
    bool? matchAlerts,
    bool? friendActivity,
    bool? contactSync,
    bool? profilePublic,
  }) {
    setState(() {
      if (matchAlerts != null) _matchAlerts = matchAlerts;
      if (friendActivity != null) _friendActivity = friendActivity;
      if (contactSync != null) _contactSync = contactSync;
      if (profilePublic != null) _profilePublic = profilePublic;
    });
    final uid = AuthRepository.instance.uid;
    if (uid == null) return;
    UserRepository.instance.updatePrefs(
      uid,
      notifyMatchAlerts: matchAlerts,
      notifyFriendActivity: friendActivity,
      contactSync: contactSync,
      profilePublic: profilePublic,
    );
  }

  /// Open a route and re-read prefs on the way back. Edit Profile writes the
  /// same `profilePublic` and `language` fields this screen shows, so without
  /// this the rows would go stale the moment they're changed over there.
  Future<void> _pushAndRefresh(String route) async {
    await Navigator.of(context).pushNamed(route);
    await _loadPrefs();
  }

  @override
  Widget build(BuildContext context) {
    return YnoScaffold(
      appBarTitle: tr('drawer.settings'),
      child: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
          children: [
            FadeSlideIn(child: _accountCard()),
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(tr('home.notifications')),
                  _group([
                    _toggleRow('🔔', tr('home.matchTeamAlerts'), null,
                        _matchAlerts, (v) => _setPref(matchAlerts: v)),
                    _toggleRow('👥', tr('home.friendActivity'), null,
                        _friendActivity, (v) => _setPref(friendActivity: v)),
                  ]),
                ],
              ),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(tr('home.account')),
                  _group([
                    _navRow('👤', tr('home.editProfile'),
                        onTap: () => _pushAndRefresh(Routes.editProfile)),
                    // Public ↔ private profile. Private hides stats and match
                    // history from everyone but accepted friends. Same
                    // `profilePublic` field the Edit Profile toggle writes.
                    _toggleRow(
                        _profilePublic ? '🌐' : '🔒',
                        _profilePublic
                            ? tr('profile.publicProfile')
                            : tr('profile.privateProfile'),
                        _profilePublic
                            ? tr('profile.publicProfileSub')
                            : tr('profile.privateProfileSub'),
                        _profilePublic,
                        (v) => _setPref(profilePublic: v)),
                    _navRow('🌐', tr('drawer.language'),
                        trailing: '${L.isAr ? 'العربية' : 'English'} ›',
                        onTap: _pickLanguage),
                    _toggleRow('📇', tr('home.contactSync'),
                        tr('home.contactSyncSub'), _contactSync,
                        (v) => _setPref(contactSync: v)),
                    _navRow('⏸️', tr('home.deactivateAccount'), onTap: _deactivateAccount),
                    // Permanent deletion sits directly beneath temporary
                    // deactivation, so the reversible option is read first,
                    // and is danger-red so it never reads as routine.
                    _navRow('🗑️', tr('auth.deleteRow'),
                        color: kDangerColor,
                        onTap: () => Navigator.of(context)
                            .pushNamed(Routes.deleteAccount)),
                  ]),
                ],
              ),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 240),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(tr('home.support')),
                  _group([
                    _navRow('❓', tr('drawer.help'), onTap: () => Navigator.of(context).pushNamed(Routes.help)),
                    _navRow('ℹ️', tr('drawer.about'),
                        // Real build version, not a hard-coded string.
                        trailing: AppVersion.current.isEmpty
                            ? null
                            : 'v${AppVersion.current} ›',
                        onTap: () =>
                            Navigator.of(context).pushNamed(Routes.about)),
                  ]),
                ],
              ),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 320),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(tr('home.dangerZone')),
                  _group([
                    _rowBase(
                      emoji: '🗑️',
                      onTap: _deleteAllData,
                      center: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tr('home.deleteAllMyData'),
                              style: AppText.barlow(
                                  size: 15,
                                  weight: FontWeight.w700,
                                  color: kDangerColor)),
                          Text(tr('home.deleteAllMyDataSub'),
                              style:
                                  AppText.barlow(size: 12, color: AppColors.dim2)),
                        ],
                      ),
                      trailing: Text('›',
                          style: AppText.barlow(size: 14, color: AppColors.dim2)),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 4),
            FadeSlideIn(
              delay: const Duration(milliseconds: 400),
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _signOut,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.line2, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(tr('drawer.logout'),
                      style: AppText.barlow(size: 16, weight: FontWeight.w700, color: AppColors.txt)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Language picker. The sheet itself lives in widgets/common.dart so the
  /// side drawer runs the exact same code — it used to carry its own copy,
  /// which silently did nothing.
  Future<void> _pickLanguage() async {
    final changed = await showLanguagePicker(context);
    if (changed && mounted) setState(() {});
  }

  /// Sign out, behind a confirmation. NOT danger-red: signing out loses
  /// nothing and you can sign straight back in (the §20 convention) — but it
  /// still deserves a "really?" so a mis-tap doesn't dump you at the welcome
  /// screen. Same dialog the side drawer's logout uses.
  Future<void> _signOut() async {
    final ok = await showConfirm(
      context,
      title: tr('home.logoutTitle'),
      message: tr('home.logoutBody'),
      confirmLabel: tr('drawer.logout'),
    );
    if (!ok || !mounted) return;
    await AuthRepository.instance.signOut();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(Routes.welcome, (r) => false);
  }

  /// Temporarily deactivate the account for a chosen period (max 1 month).
  Future<void> _deactivateAccount() async {
    final days = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.line2),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
              child: Text(tr('home.deactivateTitle'),
                  style: AppText.condensed(size: 20, weight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Text(tr('home.deactivateBody'),
                  style:
                      AppText.barlow(size: 13, color: AppColors.dim, height: 1.4)),
            ),
            _durationRow(sheetCtx, '7 ${tr('home.days')}', 7),
            _durationRow(sheetCtx, '15 ${tr('home.days')}', 15),
            _durationRow(sheetCtx, tr('home.oneMonth30'), 30),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (days == null || !mounted) return;
    final uid = AuthRepository.instance.uid;
    if (uid == null) return;
    await UserRepository.instance.deactivate(uid, days: days);
    await AuthRepository.instance.signOut();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(Routes.welcome, (r) => false);
  }

  Widget _durationRow(BuildContext sheetCtx, String label, int days) => InkWell(
        onTap: () => Navigator.pop(sheetCtx, days),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.line))),
          child: Row(
            children: [
              const Text('⏸️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style:
                        AppText.barlow(size: 15, weight: FontWeight.w600)),
              ),
              Text('›', style: AppText.barlow(size: 14, color: AppColors.dim2)),
            ],
          ),
        ),
      );

  /// Destructive: wipe everything after a 10-second cooling-off confirmation.
  Future<void> _deleteAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteDataDialog(),
    );
    if (confirmed != true || !mounted) return;

    // Blocking progress while we wipe the backend.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await AuthRepository.instance.deleteAllData();
    } catch (_) {/* best-effort; the account is signed out regardless */}
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(Routes.welcome, (r) => false);
  }

  Widget _accountCard() {
    final uid = AuthRepository.instance.uid;
    return StreamBuilder<AppUser?>(
      stream: uid == null
          ? const Stream.empty()
          : UserRepository.instance.watchUser(uid),
      builder: (context, snap) {
        final user = snap.data;
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              InitialsAvatar(
                  initials: user?.initials ?? '··',
                  size: 44,
                  fontSize: 16,
                  fill: AppColors.surface3),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? tr('home.signedIn'),
                        style:
                            AppText.barlow(size: 16, weight: FontWeight.w700)),
                    Text(user?.email ?? '',
                        style: AppText.barlow(size: 13, color: AppColors.dim)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t.toUpperCase(),
            style: AppText.barlow(size: 11, weight: FontWeight.w700, color: AppColors.dim2, letterSpacing: 1.1)),
      );

  Widget _group(List<Widget> rows) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i != rows.length - 1) {
        children.add(const Divider(height: 1, thickness: 1, color: AppColors.line));
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _rowBase({required String emoji, required Widget center, Widget? trailing, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(width: 24, child: Text(emoji, style: const TextStyle(fontSize: 18))),
            const SizedBox(width: 12),
            Expanded(child: center),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _navRow(String emoji, String title,
          {String? trailing, VoidCallback? onTap, Color? color}) =>
      _rowBase(
        emoji: emoji,
        onTap: onTap,
        center: Text(title,
            style: AppText.barlow(
                size: 15,
                weight: FontWeight.w600,
                color: color ?? AppColors.txt)),
        trailing: Text(trailing ?? '›', style: AppText.barlow(size: 14, color: AppColors.dim2)),
      );

  Widget _toggleRow(String emoji, String title, String? sub, bool value, ValueChanged<bool> onChanged) =>
      _rowBase(
        emoji: emoji,
        center: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AppText.barlow(size: 15, weight: FontWeight.w600)),
            if (sub != null)
              Text(sub, style: AppText.barlow(size: 12, color: AppColors.dim2)),
          ],
        ),
        trailing: _PillSwitch(value: value, onChanged: onChanged),
      );
}

/// Confirmation dialog whose Delete button stays locked for a 10-second
/// backward countdown, forcing a deliberate pause before irreversible deletion.
class _DeleteDataDialog extends StatefulWidget {
  const _DeleteDataDialog();

  @override
  State<_DeleteDataDialog> createState() => _DeleteDataDialogState();
}

class _DeleteDataDialogState extends State<_DeleteDataDialog> {
  static const _start = 10;
  int _seconds = _start;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds <= 1) {
        t.cancel();
        setState(() => _seconds = 0);
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _seconds == 0;
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.line2),
          borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('home.deleteAllDataTitle'),
                style: AppText.condensed(size: 22, weight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(tr('home.deleteAllDataBody'),
                style: AppText.barlow(size: 14, color: AppColors.dim, height: 1.5)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.line),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(tr('common.cancel'),
                          style: AppText.barlow(
                              size: 15, weight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: Opacity(
                      opacity: ready ? 1 : 0.45,
                      child: OutlinedButton(
                        onPressed:
                            ready ? () => Navigator.pop(context, true) : null,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: ready ? kDangerColor : null,
                          side: BorderSide(
                              color: ready ? kDangerColor : AppColors.line2,
                              width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(ready ? tr('common.delete') : '${tr('common.delete')} ($_seconds)',
                            style: AppText.barlow(
                                size: 15,
                                weight: FontWeight.w800,
                                color: ready ? AppColors.ink : AppColors.txt)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PillSwitch extends StatelessWidget {
  const _PillSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 46,
        height: 27,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? AppColors.primaryGlow(0.16) : AppColors.surface,
          border: Border.all(color: value ? AppColors.primary : AppColors.line),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 21,
            height: 21,
            decoration: BoxDecoration(
              color: value ? AppColors.primary : AppColors.surface,
              border: Border.all(color: value ? AppColors.primary : AppColors.line),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),
      ),
    );
  }
}
