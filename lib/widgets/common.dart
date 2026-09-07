import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routes.dart';
import '../services/auth_repository.dart';
import '../services/user_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// "Account made for you? Claim it" — the entry into [Routes.claim].
///
/// Shown on both login and sign-up: a player whose account a host created has
/// no password to type on either screen, so without this they are stuck. Pass
/// [email] to carry whatever they already typed into the claim screen.
class ClaimAccountLink extends StatelessWidget {
  const ClaimAccountLink({super.key, this.email});

  /// Pre-fills the claim screen's email box. Blank is fine — it just starts
  /// empty and they type it there.
  final String? email;

  @override
  Widget build(BuildContext context) {
    final prefill = (email ?? '').trim();
    return Center(
      child: GestureDetector(
        onTap: () => Navigator.of(context).pushNamed(
          Routes.claim,
          arguments: prefill.isEmpty ? null : prefill,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppText.barlow(size: 14, color: AppColors.dim),
              children: [
                TextSpan(text: tr('auth.claimPrompt')),
                TextSpan(
                  text: tr('auth.claimAction'),
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small uppercase section heading (e.g. "FORMAT").
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.color = AppColors.dim,
    this.trailing,
    this.padding = EdgeInsets.zero,
  });

  final String text;
  final Color color;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(text.toUpperCase(), style: AppText.label(color: color)),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

/// Circular initials avatar with an optional accent ring. Shows a network photo
/// when [photoUrl] is set, otherwise the initials.
/// A team's badge: uploaded image, else preset emoji, else its first letter.
///
/// Takes the three fields rather than a `TeamModel` so this file keeps out of
/// `services/` — and so a caller holding only a name can still draw something.
///
/// The fallback chain is the load-bearing part: a team may have no upload, and
/// `presetBadge` may be null or empty (older teams predate it), and both had to
/// end somewhere other than a blank square. Lifted out of `teams_screen` so the
/// match-creation picker cannot drift from the Teams page.
class TeamBadge extends StatelessWidget {
  const TeamBadge({
    super.key,
    this.badgeUrl,
    this.presetBadge,
    required this.name,
    this.size = 44,
    this.radius = 12,
    this.background = AppColors.surface,
    this.border = AppColors.line,
  });

  final String? badgeUrl;
  final String? presetBadge;
  final String name;
  final double size;
  final double radius;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final hasImage = badgeUrl != null && badgeUrl!.isNotEmpty;
    final hasPreset = presetBadge != null && presetBadge!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.hardEdge,
      alignment: Alignment.center,
      child: hasImage
          ? Image.network(
              badgeUrl!,
              fit: BoxFit.contain,
              // A dead Cloudinary URL used to render Flutter's grey error box
              // inside the badge; fall through to the letter instead.
              errorBuilder: (_, __, ___) => _letter(hasPreset),
            )
          : _letter(hasPreset),
    );
  }

  Widget _letter(bool hasPreset) => Text(
        hasPreset
            ? presetBadge!
            : (name.isEmpty ? '?' : name.substring(0, 1).toUpperCase()),
        style: hasPreset
            ? TextStyle(fontSize: size * 0.5)
            : AppText.condensed(size: size * 0.44, weight: FontWeight.w800),
      );
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.initials,
    this.size = 42,
    this.fontSize = 16,
    this.ringColor,
    this.gradientRing = false,
    this.fill,
    this.photoUrl,
  });

  final String initials;
  final double size;
  final double fontSize;
  final Color? ringColor;
  final bool gradientRing;
  final Color? fill;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    final ring = ringColor ?? (gradientRing ? AppColors.primary : AppColors.line2);
    final inner = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill ?? AppColors.surface2,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: gradientRing ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: hasPhoto
          ? Image.network(
              photoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initials(),
            )
          : _initials(),
    );
    if (gradientRing) {
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.cyan],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: inner,
      );
    }
    return inner;
  }

  Widget _initials() => Text(
        initials,
        style: AppText.condensed(
            size: fontSize, weight: FontWeight.w700, color: AppColors.txt),
      );
}

/// Pill tag (e.g. "⚡ Forward").
class TagChip extends StatelessWidget {
  const TagChip(
    this.text, {
    super.key,
    this.color = AppColors.dim,
    this.background,
    this.borderColor,
  });

  final String text;
  final Color color;
  final Color? background;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? AppColors.surface2,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: borderColor ?? AppColors.line),
      ),
      child: Text(
        text.toUpperCase(),
        style: AppText.barlow(
          size: 11,
          weight: FontWeight.w700,
          color: color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Generic surface card container.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.color = AppColors.surface,
    this.border = AppColors.line,
    this.borderWidth = 1,
    this.dashed = false,
    this.gradient,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color color;
  final Color border;
  final double borderWidth;
  final bool dashed;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: dashed ? null : Border.all(color: border, width: borderWidth),
      ),
      child: child,
    );

    Widget wrapped = dashed
        ? CustomPaint(
            painter: _DashedBorderPainter(color: border, radius: radius),
            child: content,
          )
        : content;

    if (onTap != null) {
      wrapped = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: wrapped),
      );
    }
    return wrapped;
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        canvas.drawPath(
          metric.extractPath(dist, dist + dash),
          paint,
        );
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

/// Two/three-way segmented pill toggle. The selected segment fills with the
/// volt-green accent.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
    this.height = 44,
    this.fontSize = 14,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tabs[i],
                    style: AppText.barlow(
                      size: fontSize,
                      weight: i == index ? FontWeight.w700 : FontWeight.w600,
                      color: i == index ? AppColors.ink : AppColors.dim,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Stat tile: big value + small uppercase label.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.valueColor = AppColors.txt,
    this.background = AppColors.surface,
    this.border = AppColors.line,
    this.valueSize = 34,
  });

  final String value;
  final String label;
  final Color valueColor;
  final Color background;
  final Color border;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: AppText.condensed(
                  size: valueSize,
                  weight: FontWeight.w800,
                  color: valueColor,
                  height: 1)),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: AppText.barlow(
                size: 12, color: AppColors.dim, letterSpacing: 0.6),
          ),
        ],
      ),
    );
  }
}

/// Simulated iOS status bar + dynamic island, used on full-bleed screens
/// so the design reads like the mockup without depending on device chrome.
class FakeStatusBar extends StatelessWidget {
  const FakeStatusBar({super.key, this.color = AppColors.txt});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Text('9:41', style: AppText.semiCondensed(size: 16, color: color)),
            const Spacer(),
            Icon(Icons.signal_cellular_alt, size: 16, color: color),
            const SizedBox(width: 5),
            Icon(Icons.wifi, size: 16, color: color),
            const SizedBox(width: 5),
            Icon(Icons.battery_full, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}

/// The language picker, shared by the side drawer and Settings.
///
/// 🐛 It lives here because it used to be written twice. Settings had the
/// complete version; the drawer had a copy whose row `onTap` only called
/// `Navigator.pop()` — it dismissed the sheet and changed nothing, so
/// "language doesn't work" was reported from the drawer while the identical
/// control in Settings worked fine. One implementation cannot drift like that.
///
/// Switches the locale live ([L.setLanguage] drives a [ValueNotifier] the
/// MaterialApp listens to) **and** persists the choice to the user's profile,
/// which is what `splash_screen` reads back on the next launch. Doing only the
/// first is the other easy half-fix: the language changes and then forgets.
///
/// Returns true if the language actually changed, so a caller holding state
/// can rebuild.
Future<bool> showLanguagePicker(BuildContext context) async {
  final before = L.isAr;
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      side: BorderSide(color: AppColors.line2),
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(tr('home.languageSheetTitle'),
                style: AppText.condensed(size: 22, weight: FontWeight.w800)),
          ),
          for (final opt in const [
            ['en', 'English'],
            ['ar', 'العربية'],
          ])
            ListTile(
              title: Text(opt[1],
                  style: AppText.barlow(size: 16, weight: FontWeight.w600)),
              trailing: (L.isAr ? 'ar' : 'en') == opt[0]
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.pop(sheetCtx, opt[0]),
            ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );
  if (choice == null) return false;

  L.setLanguage(choice);

  // Persist under the human label the profile stores ('English' / 'Arabic') —
  // `splash_screen` feeds that same string back into L.setLanguage on launch,
  // and it accepts either form.
  //
  // Deliberately after the switch and deliberately swallowed: the language has
  // already changed on screen, and a write that fails (offline, signed out)
  // must not turn a working language switch into an unhandled async error. The
  // cost of failing here is only that the choice is forgotten at next launch.
  try {
    final uid = AuthRepository.instance.uid;
    if (uid != null) {
      await UserRepository.instance
          .updateProfile(uid, language: choice == 'ar' ? 'Arabic' : 'English');
    }
  } catch (_) {
    // Ignored on purpose — see above.
  }
  return L.isAr != before;
}

/// Dismisses the on-screen keyboard when a tap lands outside a focused field.
///
/// Wrapped once around the whole app in [YnoApp]'s `MaterialApp.builder`, so it
/// covers every route, sheet and dialog pushed on the app navigator instead of
/// needing a copy per screen. Before this, `unfocus()` appeared nowhere in the
/// codebase and the hardware back button was the only way to close the
/// keyboard — client point C17.
///
/// ⚠️ Two choices that are load-bearing:
///
/// * **`translucent`, not `opaque`.** The child is hit-tested first, so buttons,
///   list rows and the text fields themselves keep working normally; this
///   recogniser only wins the arena for taps that reach empty space. `opaque`
///   would swallow every tap in the app.
/// * **`FocusManager.instance.primaryFocus`, not `FocusScope.of(context)`.**
///   This widget sits above the Navigator, so its context resolves to the root
///   scope — unfocusing that leaves the field inside the current route still
///   holding focus and the keyboard still up.
class DismissKeyboard extends StatelessWidget {
  const DismissKeyboard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
