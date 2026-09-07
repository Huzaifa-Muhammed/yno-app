import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// THE DESTRUCTIVE-ACTION CONVENTION.
///
/// Anything that deletes data, removes a person, or irreversibly discards
/// something is coloured [AppColors.loss] — never the volt-green primary, which
/// reads as "go ahead". Pass `danger: true` to [PrimaryButton] /
/// [SecondaryButton], or use [kDangerColor] directly for bespoke rows.
///
/// This is for LOSS OF DATA, not merely "negative": declining an invite,
/// rejecting a join request, signing out, or booking a red card are normal-flow
/// actions and stay neutral. Reversible-by-design actions (deactivate account,
/// unfollow) stay neutral too.
const kDangerColor = AppColors.loss;

/// Big volt-green call-to-action button (condensed uppercase label). Springs
/// inward while pressed. Set [danger] for destructive actions.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.height = 58,
    this.fontSize = 21,
    this.glow = true,
    this.icon,
    this.color = AppColors.primary,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  final bool glow;
  final Widget? icon;
  final Color color;

  /// Destructive action — fills with [kDangerColor], overriding [color].
  final bool danger;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final base = widget.danger ? kDangerColor : widget.color;
    final fill = enabled ? base : AppColors.surface3;
    final fg = enabled ? AppColors.ink : AppColors.dim;
    return AnimatedScale(
      scale: _down ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: SizedBox(
        width: double.infinity,
        height: widget.height,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _down = v),
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(18),
                boxShadow: (widget.glow && enabled)
                    ? [
                        BoxShadow(
                          color: base.withValues(alpha: 0.30),
                          blurRadius: 24,
                          offset: const Offset(0, 7),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      widget.icon!,
                      const SizedBox(width: 8)
                    ],
                    Text(
                      widget.label.toUpperCase(),
                      style: AppText.condensed(
                        size: widget.fontSize,
                        weight: FontWeight.w700,
                        color: fg,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined / surface button. Springs inward while pressed. Set [danger] for
/// destructive actions — see [kDangerColor].
class SecondaryButton extends StatefulWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.height = 58,
    this.fontSize = 21,
    this.icon,
    this.condensed = true,
    this.color = AppColors.txt,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  final Widget? icon;
  final bool condensed;
  final Color color;

  /// Destructive action — tints the label and border with [kDangerColor].
  final bool danger;

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _down ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: SizedBox(
        width: double.infinity,
        height: widget.height,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _down = v),
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: widget.danger
                        ? kDangerColor.withValues(alpha: 0.55)
                        : AppColors.line2,
                    width: 1.2),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      widget.icon!,
                      const SizedBox(width: 8)
                    ],
                    Text(
                      widget.condensed
                          ? widget.label.toUpperCase()
                          : widget.label,
                      style: widget.condensed
                          ? AppText.condensed(
                              size: widget.fontSize,
                              weight: FontWeight.w700,
                              color: widget.danger
                                  ? kDangerColor
                                  : widget.color,
                              letterSpacing: 0.6,
                            )
                          : AppText.barlow(
                              size: widget.fontSize,
                              weight: FontWeight.w700,
                              color: widget.danger
                                  ? kDangerColor
                                  : widget.color,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plain text button (e.g. "Skip for now").
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onTap,
    this.color = AppColors.dim,
    this.height = 46,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: TextButton(
        onPressed: onTap,
        child: Text(
          label,
          style: AppText.barlow(size: 16, weight: FontWeight.w600, color: color),
        ),
      ),
    );
  }
}

/// Round back chip ("‹").
class BackChip extends StatelessWidget {
  const BackChip({super.key, this.onTap, this.size = 40});

  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.line),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.only(bottom: 3),
        child: Text(
          '‹',
          style: AppText.barlow(
              size: 24, weight: FontWeight.w500, color: AppColors.txt),
        ),
      ),
    );
  }
}

/// Small rounded icon chip used in headers (e.g. ⚙️, 🔔).
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.child,
    this.onTap,
    this.size = 42,
    this.radius = 15,
    this.badge,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double size;
  final double radius;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: AppColors.line),
            ),
            alignment: Alignment.center,
            child: child,
          ),
          if (badge != null)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.loss,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.bg, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  badge!,
                  style: AppText.barlow(
                    size: 10,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
