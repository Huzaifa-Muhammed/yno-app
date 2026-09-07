import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
import '../services/storage_service.dart';
import '../services/team_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/header.dart';
import '../widgets/inputs.dart';
import '../widgets/motion.dart';
import '../widgets/yno_scaffold.dart';

/// Preset team badges (used when the owner does not upload a PNG).
const _presetBadges = <String>[
  '🦁', '🦅', '🐯', '🐺', '⚡', '🔥', '⚽', '🛡️',
];

class TeamCreateScreen extends StatefulWidget {
  const TeamCreateScreen({super.key});

  @override
  State<TeamCreateScreen> createState() => _TeamCreateScreenState();
}

/// Real-time availability state for the name step.
enum _NameState { empty, invalid, checking, available, taken }

class _TeamCreateScreenState extends State<TeamCreateScreen> {
  final _name = TextEditingController();

  int _step = 0;
  bool _busy = false;

  _NameState _nameState = _NameState.empty;
  Timer? _debounce;
  int _checkToken = 0;

  // Badge selection (custom upload OR preset).
  String? _badgeUrl;
  String? _badgePublicId;
  String? _presetBadge;
  bool _uploading = false;

  bool _isPublic = false; // default Private

  static final _nameAllowed = RegExp(r"^[A-Za-z0-9 '-]+$");

  @override
  void initState() {
    super.initState();
    _name.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.removeListener(_onNameChanged);
    _name.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    _debounce?.cancel();
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameState = _NameState.empty);
      return;
    }
    if (name.length > 40 || !_nameAllowed.hasMatch(name)) {
      setState(() => _nameState = _NameState.invalid);
      return;
    }
    setState(() => _nameState = _NameState.checking);
    final token = ++_checkToken;
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final ok = await TeamRepository.instance.isNameAvailable(name);
      if (!mounted || token != _checkToken) return;
      setState(() => _nameState = ok ? _NameState.available : _NameState.taken);
    });
  }

  Future<void> _pickPng() async {
    if (_uploading) return;
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (x == null) return;
      setState(() => _uploading = true);
      final res = await StorageService.instance.uploadImage(
        File(x.path),
        folder: 'team_badges',
        pngOnly: true,
      );
      if (!mounted) return;
      if (res == null) {
        showYnoToast(context, tr('teams.uploadFailed'));
        setState(() => _uploading = false);
        return;
      }
      setState(() {
        _badgeUrl = res.url;
        _badgePublicId = res.publicId;
        _presetBadge = null;
        _uploading = false;
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      showYnoToast(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploading = false);
      showYnoToast(context, tr('teams.uploadBadgeError'));
    }
  }

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _nameState == _NameState.available;
      case 1:
        return _badgeUrl != null || _presetBadge != null;
      default:
        return true;
    }
  }

  void _next() {
    if (!_canContinue) {
      showYnoToast(context, _step == 0
          ? tr('teams.pickNameFirst')
          : tr('teams.chooseBadge'));
      return;
    }
    if (_step < 3) {
      setState(() => _step += 1);
    } else {
      _create();
    }
  }

  Future<void> _create() async {
    if (_busy) return;
    final uid = AuthRepository.instance.uid;
    if (uid == null) {
      showYnoToast(context, tr('teams.needLogin'));
      return;
    }
    setState(() => _busy = true);
    try {
      final team = await TeamRepository.instance.createTeam(
        name: _name.text.trim(),
        ownerUid: uid,
        badgeUrl: _badgeUrl,
        badgePublicId: _badgePublicId,
        presetBadge: _presetBadge,
        isPublic: _isPublic,
      );
      if (!mounted) return;
      Navigator.of(context)
          .pushReplacementNamed(Routes.teamProfile, arguments: team.id);
    } catch (_) {
      if (!mounted) return;
      showYnoToast(context, tr('teams.createError'));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Native AppBar back doubles as the wizard's step-back: intercept the pop
    // and rewind a step until we're on the first one, then let the route pop.
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _step -= 1);
      },
      child: YnoScaffold(
        appBarTitle: tr('teams.createTeam'),
        child: SafeArea(
          top: false,
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${tr('teams.step')} ${_step + 1} ${tr('teams.of')} 4',
                    style: AppText.label()),
                const SizedBox(height: 10),
                _stepDots(),
              const SizedBox(height: 22),
              if (_step == 0)
                FadeSlideIn(key: const ValueKey(0), child: _stepName()),
              if (_step == 1)
                FadeSlideIn(key: const ValueKey(1), child: _stepBadge()),
              if (_step == 2)
                FadeSlideIn(key: const ValueKey(2), child: _stepPrivacy()),
              if (_step == 3)
                FadeSlideIn(key: const ValueKey(3), child: _stepReview()),
              const SizedBox(height: 28),
              PrimaryButton(
                label: _busy
                    ? tr('teams.creating')
                    : _step == 3
                        ? tr('teams.createTeam')
                        : tr('common.continue'),
                onTap: _busy ? null : _next,
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepDots() {
    return Row(
      children: [
        for (int i = 0; i < 4; i++) ...[
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i <= _step ? AppColors.primary : AppColors.surface3,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          if (i < 3) const SizedBox(width: 6),
        ],
      ],
    );
  }

  // ---- Step 1: name -----------------------------------------------------
  Widget _stepName() {
    final (statusText, statusColor) = switch (_nameState) {
      _NameState.empty => (tr('teams.nameHintEmpty'), AppColors.dim),
      _NameState.invalid => (tr('teams.nameHintInvalid'), AppColors.txt),
      _NameState.checking => (tr('teams.checkingAvailability'), AppColors.dim),
      _NameState.available => ('✓ "${_name.text.trim()}" ${tr('teams.nameAvailable')}',
          AppColors.txt),
      _NameState.taken => (tr('teams.nameTaken'), AppColors.txt),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('teams.teamName'),
            style: AppText.condensed(size: 26, weight: FontWeight.w800)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🔒', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(tr('teams.identityLockedNote'),
                  style: AppText.barlow(
                      size: 12.5, color: AppColors.dim, height: 1.4)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        YnoTextField(
          controller: _name,
          hint: tr('teams.nameHintExample'),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(statusText,
                  style: AppText.barlow(size: 12, color: statusColor)),
            ),
            Text('${_name.text.trim().length}/40',
                style: AppText.barlow(size: 12, color: AppColors.dim2)),
          ],
        ),
      ],
    );
  }

  // ---- Step 2: badge ----------------------------------------------------
  Widget _stepBadge() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('teams.teamBadge'),
            style: AppText.condensed(size: 26, weight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(tr('teams.badgeHelp'),
            style: AppText.barlow(size: 13, color: AppColors.dim)),
        const SizedBox(height: 18),
        Center(child: _badgePreview(96)),
        const SizedBox(height: 18),
        SecondaryButton(
          label: _uploading ? tr('teams.uploading') : tr('teams.uploadPng'),
          height: 52,
          fontSize: 16,
          onTap: _uploading ? null : _pickPng,
        ),
        const SizedBox(height: 22),
        SectionLabel(tr('teams.orPickPreset')),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final p in _presetBadges)
              GestureDetector(
                onTap: () => setState(() {
                  _presetBadge = p;
                  _badgeUrl = null;
                  _badgePublicId = null;
                }),
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(
                      color: _presetBadge == p
                          ? AppColors.primary
                          : AppColors.line,
                      width: _presetBadge == p ? 2.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(p, style: const TextStyle(fontSize: 30)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ---- Step 3: privacy --------------------------------------------------
  Widget _stepPrivacy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('teams.privacy'),
            style: AppText.condensed(size: 26, weight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(tr('teams.privacyHint'),
            style: AppText.barlow(size: 13, color: AppColors.dim)),
        const SizedBox(height: 18),
        SelectableRow(
          title: tr('teams.private'),
          subtitle: tr('teams.privateSubDefault'),
          selected: !_isPublic,
          onTap: () => setState(() => _isPublic = false),
        ),
        const SizedBox(height: 12),
        SelectableRow(
          title: tr('teams.public'),
          subtitle: tr('teams.publicSub'),
          selected: _isPublic,
          onTap: () => setState(() => _isPublic = true),
        ),
      ],
    );
  }

  // ---- Step 4: review ---------------------------------------------------
  Widget _stepReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('teams.review'),
            style: AppText.condensed(size: 26, weight: FontWeight.w800)),
        const SizedBox(height: 18),
        Center(child: _badgePreview(88)),
        const SizedBox(height: 14),
        Center(
          child: Text(_name.text.trim(),
              style: AppText.condensed(size: 26, weight: FontWeight.w800)),
        ),
        const SizedBox(height: 20),
        _reviewRow(tr('teams.name'), _name.text.trim()),
        _reviewRow(tr('teams.badge'),
            _badgeUrl != null ? tr('teams.customPng') : tr('teams.preset')),
        _reviewRow(tr('teams.privacy'),
            _isPublic ? tr('teams.public') : tr('teams.private')),
      ],
    );
  }

  Widget _reviewRow(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(k.toUpperCase(),
                style: AppText.label()),
            const Spacer(),
            Text(v,
                style: AppText.barlow(size: 14, weight: FontWeight.w700)),
          ],
        ),
      );

  Widget _badgePreview(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line2, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.hardEdge,
      alignment: Alignment.center,
      child: _badgeUrl != null
          ? Image.network(_badgeUrl!, fit: BoxFit.contain)
          : Text(_presetBadge ?? '🛡️',
              style: TextStyle(fontSize: size * 0.42)),
    );
  }
}
