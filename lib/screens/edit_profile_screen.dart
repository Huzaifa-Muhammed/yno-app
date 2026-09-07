import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/l10n.dart';
import '../services/auth_repository.dart';
import '../services/models.dart';
import '../services/storage_service.dart';
import '../services/user_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/header.dart';
import '../widgets/inputs.dart';
import '../widgets/motion.dart';
import '../widgets/yno_scaffold.dart';

/// Section 12 — Edit Profile (own only).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

const _positions = ['Goalkeeper', 'Defender', 'Midfielder', 'Forward'];
const _feet = ['Left', 'Right', 'Both'];
const _skills = ['Beginner', 'Intermediate', 'Advanced'];
const _languages = ['English', 'Arabic'];
const _platforms = ['instagram', 'snapchat', 'tiktok', 'whatsapp'];
const _visOptions = ['off', 'friends', 'public'];

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _currentPw = TextEditingController();
  final _newPw = TextEditingController();
  final _social = {for (final p in _platforms) p: TextEditingController()};

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  bool _changingPw = false;
  AppUser? _user;

  String? _position, _foot, _skill;
  String _language = 'English';
  bool _profilePublic = true;
  DateTime? _dob;
  bool _dobLocked = false;
  String? _photoUrl, _photoPublicId;
  // The photo saved when the screen opened — so on save we can delete the OLD
  // Cloudinary image once it's been replaced.
  String? _originalPhotoPublicId;
  final _visibility = <String, String>{};

  String _originalUsername = '';
  Timer? _debounce;
  int _checkToken = 0;
  // null = unknown, true = available, false = taken
  bool? _usernameOk;

  @override
  void initState() {
    super.initState();
    _username.addListener(() => _onUsernameChanged(_username.text));
    _load();
  }

  Future<void> _load() async {
    final uid = AuthRepository.instance.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final user = await UserRepository.instance.getUser(uid);
    if (!mounted) return;
    setState(() {
      _user = user;
      _name.text = user?.name ?? '';
      _originalUsername = user?.username ?? '';
      _username.text = user?.username ?? '';
      _email.text = user?.email ?? '';
      _position = user?.position;
      _foot = user?.preferredFoot;
      _skill = user?.skillLevel;
      _language = user?.language ?? 'English';
      _profilePublic = user?.profilePublic ?? true;
      _dob = user?.dob;
      _dobLocked = user?.dobLocked ?? false;
      _photoUrl = user?.photoUrl;
      _photoPublicId = user?.photoPublicId;
      _originalPhotoPublicId = user?.photoPublicId;
      for (final p in _platforms) {
        _social[p]!.text = user?.socialLinks[p] ?? '';
        _visibility[p] = user?.socialVisibility[p] ?? 'off';
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _currentPw.dispose();
    _newPw.dispose();
    for (final c in _social.values) {
      c.dispose();
    }
    _debounce?.cancel();
    super.dispose();
  }

  // ---- username availability ---------------------------------------------
  void _onUsernameChanged(String v) {
    _debounce?.cancel();
    final u = v.trim();
    if (u.toLowerCase() == _originalUsername.toLowerCase() || u.isEmpty) {
      setState(() => _usernameOk = null);
      return;
    }
    final token = ++_checkToken;
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final ok = await UserRepository.instance.isUsernameAvailable(u);
      if (!mounted || token != _checkToken) return;
      setState(() => _usernameOk = ok);
    });
  }

  // ---- photo --------------------------------------------------------------
  Future<void> _pickPhoto() async {
    if (_uploading) return;
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (x == null) return;
      setState(() => _uploading = true);
      // The image about to be replaced — if it's an unsaved intermediate upload
      // from earlier in this session, clean it up so it doesn't orphan. The
      // ORIGINAL (last-saved) image is left alone until save succeeds.
      final replacing = _photoPublicId;
      final res = await StorageService.instance
          .uploadImage(File(x.path), folder: 'profile_pictures');
      if (!mounted) return;
      if (res == null) {
        showYnoToast(context, tr('profile.uploadFailed'));
        setState(() => _uploading = false);
        return;
      }
      if (replacing != null &&
          replacing.isNotEmpty &&
          replacing != _originalPhotoPublicId &&
          replacing != res.publicId) {
        StorageService.instance.deleteImage(replacing); // best-effort
      }
      setState(() {
        _photoUrl = res.url;
        _photoPublicId = res.publicId;
        _uploading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploading = false);
      showYnoToast(context, tr('profile.uploadPhotoError'));
    }
  }

  // ---- DOB ----------------------------------------------------------------
  Future<void> _pickDob() async {
    if (_dobLocked) {
      showYnoToast(context, tr('profile.dobLockedToast'));
      return;
    }
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  // ---- save ---------------------------------------------------------------
  Future<void> _save() async {
    if (_saving) return;
    final uid = AuthRepository.instance.uid;
    if (uid == null) return;
    if (_name.text.trim().isEmpty) {
      showYnoToast(context, tr('profile.nameEmpty'));
      return;
    }
    final newUsername = _username.text.trim();
    final usernameChanged =
        newUsername.toLowerCase() != _originalUsername.toLowerCase();
    if (usernameChanged) {
      if (newUsername.isEmpty) {
        showYnoToast(context, tr('profile.usernameEmpty'));
        return;
      }
      if (_usernameOk == false) {
        showYnoToast(context, tr('profile.usernameTaken'));
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final socialLinks = <String, String>{
        for (final p in _platforms)
          if (_social[p]!.text.trim().isNotEmpty) p: _social[p]!.text.trim(),
      };
      // Whether the DOB is being set for the first time / changed.
      final dobChanged =
          !_dobLocked && _dob != null && _dob != _user?.dob;
      await UserRepository.instance.updateProfile(
        uid,
        name: _name.text.trim(),
        username: usernameChanged ? newUsername : null,
        position: _position,
        preferredFoot: _foot,
        skillLevel: _skill,
        language: _language,
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        photoUrl: _photoUrl,
        photoPublicId: _photoPublicId,
        dob: dobChanged ? _dob : null,
        dobLocked: dobChanged ? true : null,
        socialLinks: socialLinks,
        socialVisibility: Map<String, String>.from(_visibility),
      );
      await UserRepository.instance
          .updatePrefs(uid, profilePublic: _profilePublic);
      // The new picture is saved — now remove the previous one from Cloudinary
      // so only the current image lives there. Best-effort.
      final oldId = _originalPhotoPublicId;
      if (oldId != null && oldId.isNotEmpty && oldId != _photoPublicId) {
        await StorageService.instance.deleteImage(oldId);
        _originalPhotoPublicId = _photoPublicId;
      }
      if (!mounted) return;
      showYnoToast(context, tr('profile.profileSaved'));
      Navigator.of(context).maybePop();
    } catch (_) {
      if (!mounted) return;
      showYnoToast(context, tr('profile.saveError'));
      setState(() => _saving = false);
    }
  }

  // ---- password -----------------------------------------------------------
  Future<void> _changePassword() async {
    if (_changingPw) return;
    final current = _currentPw.text;
    final next = _newPw.text;
    if (current.isEmpty || next.isEmpty) {
      showYnoToast(context, tr('profile.pwEnterBoth'));
      return;
    }
    if (next.length < 6) {
      showYnoToast(context, tr('profile.pwTooShort'));
      return;
    }
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null || authUser.email == null) {
      showYnoToast(context, tr('profile.pwNoAccount'));
      return;
    }
    setState(() => _changingPw = true);
    try {
      final cred = EmailAuthProvider.credential(
          email: authUser.email!, password: current);
      await authUser.reauthenticateWithCredential(cred);
      await authUser.updatePassword(next);
      if (!mounted) return;
      _currentPw.clear();
      _newPw.clear();
      showYnoToast(context, tr('profile.pwUpdated'));
      setState(() => _changingPw = false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _changingPw = false);
      showYnoToast(context, authErrorMessage(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _changingPw = false);
      showYnoToast(context, tr('profile.pwUpdateError'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return YnoScaffold(
      appBarTitle: tr('profile.editTitle'),
      appBarActions: [
        TextButton(
          onPressed: _save,
          child: Text(_saving ? tr('common.saving') : tr('common.save'),
              style: AppText.barlow(
                  size: 15, weight: FontWeight.w700, color: AppColors.txt)),
        ),
      ],
      child: SafeArea(
        top: false,
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  FadeSlideIn(child: _photoBlock()),
                  const SizedBox(height: 22),
                  FieldLabel(tr('profile.fullName')),
                  YnoTextField(
                    controller: _name,
                    hint: tr('profile.yourNameHint'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 14),
                  FieldLabel(tr('profile.username')),
                  YnoTextField(
                    controller: _username,
                    hint: tr('profile.usernameHint'),
                  ),
                  _usernameNote(),
                  const SizedBox(height: 14),
                  _chipPicker(tr('profile.position'), _positions, _position,
                      (v) => setState(() => _position = v)),
                  const SizedBox(height: 14),
                  _chipPicker(tr('profile.preferredFoot'), _feet, _foot,
                      (v) => setState(() => _foot = v)),
                  const SizedBox(height: 14),
                  _chipPicker(tr('profile.skillLevel'), _skills, _skill,
                      (v) => setState(() => _skill = v)),
                  const SizedBox(height: 14),
                  _chipPicker(tr('drawer.language'), _languages, _language,
                      (v) => setState(() => _language = v ?? 'English')),
                  const SizedBox(height: 20),
                  _dobBlock(),
                  const SizedBox(height: 20),
                  FieldLabel(tr('profile.email')),
                  YnoTextField(
                    controller: _email,
                    hint: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  SectionLabel(tr('profile.privacy')),
                  const SizedBox(height: 12),
                  _privacyToggle(),
                  const SizedBox(height: 24),
                  SectionLabel(tr('profile.socialLinks')),
                  const SizedBox(height: 12),
                  for (int i = 0; i < _platforms.length; i++)
                    FadeSlideIn(
                        delay: Duration(milliseconds: 50 * i),
                        child: _socialBlock(_platforms[i])),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: _saving ? tr('common.saving') : tr('profile.saveChanges'),
                    onTap: _save,
                  ),
                  const SizedBox(height: 24),
                  SectionLabel(tr('profile.changePassword')),
                  const SizedBox(height: 12),
                  FieldLabel(tr('profile.currentPassword')),
                  YnoTextField(controller: _currentPw, obscure: true),
                  const SizedBox(height: 12),
                  FieldLabel(tr('profile.newPassword')),
                  YnoTextField(controller: _newPw, obscure: true),
                  const SizedBox(height: 12),
                  SecondaryButton(
                    label: _changingPw ? tr('profile.updating') : tr('profile.updatePassword'),
                    height: 50,
                    fontSize: 16,
                    condensed: false,
                    onTap: _changePassword,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      tr('profile.accountInfoNote'),
                      style: AppText.barlow(
                          size: 12, color: AppColors.dim, height: 1.5),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _photoBlock() {
    return Center(
      child: GestureDetector(
        onTap: _pickPhoto,
        child: Column(
          children: [
            InitialsAvatar(
              initials: _user?.initials ?? '··',
              size: 96,
              fontSize: 36,
              photoUrl: _photoUrl,
            ),
            const SizedBox(height: 8),
            Text(_uploading ? tr('profile.uploading') : tr('profile.changePhoto'),
                style: AppText.barlow(
                    size: 13, weight: FontWeight.w700, color: AppColors.txt)),
          ],
        ),
      ),
    );
  }

  Widget _usernameNote() {
    String msg;
    if (_username.text.trim().toLowerCase() ==
        _originalUsername.toLowerCase()) {
      msg = tr('profile.usernameCooldownNote');
    } else if (_usernameOk == true) {
      msg = tr('profile.usernameAvailable');
    } else if (_usernameOk == false) {
      msg = tr('profile.usernameTakenNote');
    } else {
      msg = tr('profile.checking');
    }
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Text(msg, style: AppText.barlow(size: 12, color: AppColors.dim)),
    );
  }

  Widget _chipPicker(String label, List<String> options, String? selected,
      ValueChanged<String?> onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              GestureDetector(
                onTap: () => onSelect(o),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(
                      color: AppColors.line,
                      width: o == selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(_trAttr(o),
                      style: AppText.barlow(
                          size: 14,
                          weight: o == selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: o == selected
                              ? AppColors.txt
                              : AppColors.dim)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _dobBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(tr('profile.dob')),
        GestureDetector(
          onTap: _pickDob,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.line, width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _dob == null ? tr('profile.selectDate') : _fmtDate(_dob),
                    style: AppText.barlow(
                        size: 17,
                        weight: FontWeight.w600,
                        color: _dob == null ? AppColors.dim2 : AppColors.txt),
                  ),
                ),
                Text(_dobLocked ? '🔒 ${tr('profile.locked')}' : tr('profile.editableOnce'),
                    style: AppText.barlow(size: 12, color: AppColors.dim2)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Public ↔ private profile toggle. Private hides stats/history from
  /// non-friends on the public profile.
  Widget _privacyToggle() {
    return GestureDetector(
      onTap: () => setState(() => _profilePublic = !_profilePublic),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(_profilePublic ? '🌐' : '🔒',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      _profilePublic
                          ? tr('profile.publicProfile')
                          : tr('profile.privateProfile'),
                      style: AppText.barlow(size: 15, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                      _profilePublic
                          ? tr('profile.publicProfileSub')
                          : tr('profile.privateProfileSub'),
                      style: AppText.barlow(
                          size: 11, color: AppColors.dim2, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 52,
              height: 30,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: _profilePublic
                    ? AppColors.primary
                    : AppColors.surface2,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                    color: _profilePublic ? AppColors.primary : AppColors.line),
              ),
              alignment: _profilePublic
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                    color: AppColors.bg, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialBlock(String platform) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(_cap(platform)),
          YnoTextField(
            controller: _social[platform]!,
            hint: platform == 'whatsapp' ? '+9715…' : '@handle',
          ),
          const SizedBox(height: 8),
          SegmentedTabs(
            tabs: [tr('profile.visOff'), tr('drawer.friends'), tr('profile.visPublic')],
            index: _visOptions.indexOf(_visibility[platform] ?? 'off'),
            onChanged: (i) =>
                setState(() => _visibility[platform] = _visOptions[i]),
          ),
        ],
      ),
    );
  }
}

String _cap(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

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

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
