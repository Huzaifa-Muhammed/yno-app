import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Display-only text field box (these are static UI mockups — no real input).
class FieldBox extends StatelessWidget {
  const FieldBox({
    super.key,
    this.value,
    this.hint,
    this.leading,
    this.trailing,
    this.active = false,
    this.valid = false,
    this.height = 56,
    this.fontSize = 17,
    this.fontWeight = FontWeight.w600,
  });

  final String? value;
  final String? hint;
  final Widget? leading;
  final Widget? trailing;
  final bool active;
  final bool valid;
  final double height;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final borderColor = valid
        ? AppColors.win
        : active
            ? AppColors.primary
            : AppColors.line;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(
            child: Text(
              value ?? hint ?? '',
              style: AppText.barlow(
                size: fontSize,
                weight: fontWeight,
                color: value == null ? AppColors.dim2 : AppColors.txt,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Editable text field styled to match [FieldBox]. Use this wherever the app
/// needs real input (auth, forms, codes).
class YnoTextField extends StatefulWidget {
  const YnoTextField({
    super.key,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.leading,
    this.trailing,
    this.height = 56,
    this.fontSize = 17,
    this.autofocus = false,
    this.onSubmitted,
    this.onChanged,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Widget? leading;
  final Widget? trailing;
  final double height;
  final double fontSize;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  /// Shows the value but blocks editing (no cursor, no keyboard) and dims the
  /// field so it reads as locked rather than merely empty.
  final bool readOnly;

  @override
  State<YnoTextField> createState() => _YnoTextFieldState();
}

class _YnoTextFieldState extends State<YnoTextField> {
  final _focus = FocusNode();
  late bool _obscured = widget.obscure;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _focus.hasFocus && !widget.readOnly;
    return Container(
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: widget.readOnly ? AppColors.surface : AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? AppColors.primary : AppColors.line,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          if (widget.leading != null) ...[widget.leading!, const SizedBox(width: 8)],
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              obscureText: _obscured,
              keyboardType: widget.keyboardType,
              textCapitalization: widget.textCapitalization,
              onSubmitted: widget.onSubmitted,
              onChanged: widget.onChanged,
              readOnly: widget.readOnly,
              showCursor: !widget.readOnly,
              cursorColor: AppColors.txt,
              style: AppText.barlow(
                size: widget.fontSize,
                weight: FontWeight.w600,
                color: widget.readOnly ? AppColors.dim : AppColors.txt,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle: AppText.barlow(
                  size: widget.fontSize,
                  weight: FontWeight.w600,
                  color: AppColors.dim2,
                ),
              ),
            ),
          ),
          if (widget.obscure)
            GestureDetector(
              onTap: () => setState(() => _obscured = !_obscured),
              child: Text(
                _obscured ? 'Show' : 'Hide',
                style: AppText.barlow(size: 14, color: AppColors.dim),
              ),
            )
          else if (widget.trailing != null)
            widget.trailing!,
        ],
      ),
    );
  }
}

/// Form field label above a [FieldBox].
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.optional = false});

  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: RichText(
        text: TextSpan(
          text: text.toUpperCase(),
          style: AppText.label(),
          children: optional
              ? [
                  TextSpan(
                    text: '  · optional',
                    style: AppText.barlow(size: 12, color: AppColors.dim2),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

/// A selectable option row (radio-style) used across onboarding.
class SelectableRow extends StatelessWidget {
  const SelectableRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.selected = false,
    this.onTap,
    this.height,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final VoidCallback? onTap;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        constraints: height == null ? const BoxConstraints(minHeight: 56) : null,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryGlow(0.10) : AppColors.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.barlow(
                      size: 17,
                      weight: FontWeight.w700,
                      color: selected ? AppColors.txt : AppColors.txt,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppText.barlow(size: 12, color: AppColors.dim),
                    ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.check, size: 13, color: AppColors.ink),
              ),
          ],
        ),
      ),
    );
  }
}
