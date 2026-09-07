import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
import '../services/user_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/yno_scaffold.dart';

/// Marker thrown by [_SplashScreenState._probe] when the device looks offline.
class _OfflineException implements Exception {
  const _OfflineException();
}

/// Splash: logo animates in over ~1.5s with three pulsing dots, then the app
/// auth-gates automatically (no tap). Before routing it does a quick Firestore
/// connectivity probe with a 5s timeout; on failure it shows a Retry button.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  bool _error = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _dots.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    setState(() => _error = false);
    _entrance
      ..reset()
      ..forward();
    try {
      // Play the animation and probe connectivity in parallel; hold the splash
      // for at least ~1.5s so the intro never flickers past.
      await Future.wait([
        Future<void>.delayed(const Duration(milliseconds: 1500)),
        _probe(),
      ]);
    } on _OfflineException {
      if (mounted) setState(() => _error = true);
      return;
    } catch (_) {
      // Any other failure: don't hard-block the user on a cold start.
    }
    if (!mounted) return;
    final user = await _restoredUser();
    if (!mounted) return;
    if (user != null) {
      // Apply the saved language so the app opens in the user's locale.
      try {
        final profile = await UserRepository.instance.getUser(user.uid);
        if (profile != null) L.setLanguage(profile.language);
      } catch (_) {/* default locale */}
      if (!mounted) return;
    }
    final next = user != null ? Routes.home : Routes.welcome;
    Navigator.of(context).pushReplacementNamed(next);
  }

  /// The signed-in user, once Firebase has finished restoring the saved
  /// session from disk.
  ///
  /// ⚠️ Reading `currentUser` directly is a **race**, and it is the one that
  /// makes a signed-in user land on the welcome screen after a device reboot.
  /// Firebase restores the persisted session asynchronously after
  /// `initializeApp`, so `currentUser` can still be null for a moment on a cold
  /// start — precisely when the disk is slow and the app has just been launched
  /// from scratch. `authStateChanges()` does not emit until restoration has
  /// settled, so its first event is the real answer.
  ///
  /// 🔑 There is nothing to configure for persistence on Android/iOS: the
  /// session is written to disk always, and `setPersistence` is web-only. The
  /// session survives reboots on its own — this is only about not asking before
  /// it has been read back.
  ///
  /// The timeout keeps a wedged auth channel from stranding the user on the
  /// splash forever; falling back to `currentUser` is no worse than the old
  /// behaviour.
  Future<User?> _restoredUser() async {
    try {
      return await AuthRepository.instance.authState.first
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return AuthRepository.instance.currentUser;
    }
  }

  /// Light connectivity check. A server round-trip that *reaches* Firestore
  /// (even a permission error) counts as online; only a timeout or an
  /// `unavailable`/network error is treated as offline.
  Future<void> _probe() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      throw const _OfflineException();
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'network-request-failed') {
        throw const _OfflineException();
      }
      // Reached the server (e.g. permission-denied) — we're online.
    }
  }

  @override
  Widget build(BuildContext context) {
    return YnoScaffold(
      baseColor: AppColors.bg,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: FadeTransition(
                opacity: CurvedAnimation(
                    parent: _entrance, curve: Curves.easeOut),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.86, end: 1).animate(
                    CurvedAnimation(parent: _entrance, curve: Curves.easeOut),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: AppText.condensed(
                                  size: 96,
                                  weight: FontWeight.w800,
                                  height: 0.82),
                              children: const [
                                TextSpan(text: 'YN'),
                                TextSpan(
                                    text: 'O',
                                    style:
                                        TextStyle(color: AppColors.primary)),
                              ],
                            ),
                          ),
                          Positioned(
                            right: -10,
                            top: 6,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.line),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('يلا نلعب',
                          style: AppText.barlow(
                              size: 19,
                              weight: FontWeight.w600,
                              color: AppColors.dim)),
                    ],
                  ),
                ),
              ),
            ),
            if (_error)
              _OfflinePanel(onRetry: _boot)
            else
              Positioned(
                left: 0,
                right: 0,
                bottom: 96,
                child: _LoadingDots(controller: _dots),
              ),
          ],
        ),
      ),
    );
  }
}

/// Three dots that pulse in sequence while the app boots.
class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            // Each dot leads the next by a third of the cycle.
            final phase = (controller.value - i * 0.18) % 1.0;
            final t = (1 - (phase * 2 - 1).abs()).clamp(0.0, 1.0);
            final opacity = 0.25 + 0.75 * t;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.5),
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

/// Offline error state with a Retry button.
class _OfflinePanel extends StatelessWidget {
  const _OfflinePanel({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: 56,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              tr('auth.offlineMessage'),
              textAlign: TextAlign.center,
              style: AppText.barlow(
                  size: 14, color: AppColors.dim, height: 1.45),
            ),
          ),
          const SizedBox(height: 14),
          SecondaryButton(label: tr('common.retry'), onTap: onRetry),
        ],
      ),
    );
  }
}
