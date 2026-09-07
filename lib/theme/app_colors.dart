import 'package:flutter/material.dart';

/// YNO brand palette — a modern **dark** theme with a volt-green accent, taken
/// from the design (`.claude/design/design.html`).
///
/// Base is a near-black olive-tinted charcoal; surfaces step up in lightness to
/// build depth; the signature accent is the volt/lime green used in the logo
/// ("YN**O**"). Semantic win/loss/gold/cyan are kept for match states.
///
/// `bg` / `surface` / `line` / `primary` are the four values the design bundle
/// names directly; `bgDeep`, `surface2/3`, `line2` and `primaryDeep` are stepped
/// from them along the same olive hue so depth reads consistently.
class AppColors {
  AppColors._();

  // ---- Surfaces (dark, stepped for depth) --------------------------------
  static const Color bg = Color(0xFF0C0F0A); // app background
  static const Color bgDeep = Color(0xFF070906); // deepest (behind cards)
  static const Color surface = Color(0xFF161A14); // card
  static const Color surface2 = Color(0xFF1E241A); // elevated card / input
  static const Color surface3 = Color(0xFF282F22); // highest / pressed

  // ---- Borders (subtle hairlines on dark) --------------------------------
  static const Color line = Color(0xFF252B21); // subtle divider / card border
  static const Color line2 = Color(0xFF39412F); // stronger / focused border

  // ---- Text ---------------------------------------------------------------
  static const Color txt = Color(0xFFF1F4F2); // primary text
  static const Color dim = Color(0xFF8B948F); // secondary
  static const Color dim2 = Color(0xFF5B635E); // tertiary / hints

  // ---- Accent (volt green) ------------------------------------------------
  static const Color primary = Color(0xFFD4FF00); // brand accent
  static const Color primaryDeep = Color(0xFFB0D400); // pressed / deeper
  static const Color ink = Color(0xFF0C0F0A); // text/icon ON the accent fill

  // ---- Semantic match states ---------------------------------------------
  static const Color win = Color(0xFF3DE27A);
  static const Color loss = Color(0xFFFF4D5E);
  static const Color gold = Color(0xFFFFC53D);
  static const Color cyan = Color(0xFF38E0E0);

  // ---- Translucent accent washes (radial glows / tints) ------------------
  static Color primaryGlow(double o) => primary.withValues(alpha: o);
  static Color lossGlow(double o) => loss.withValues(alpha: o);
  static Color goldGlow(double o) => gold.withValues(alpha: o);
  static Color winGlow(double o) => win.withValues(alpha: o);
  static Color cyanGlow(double o) => cyan.withValues(alpha: o);
}
