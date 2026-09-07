import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// YNO typography — **Barlow** for body/UI and **Barlow Condensed** for the
/// big display/heading treatments (matching the design). Arabic falls back to
/// Cairo, which covers the glyphs Barlow doesn't.
class AppText {
  AppText._();

  /// Arabic-capable fallback family — Barlow has no Arabic glyphs, so Arabic
  /// characters render in Cairo while Latin stays in Barlow.
  static final List<String> _arabicFallback = <String>[
    GoogleFonts.cairo().fontFamily!,
  ];

  /// Body / UI text — Barlow.
  static TextStyle barlow({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.txt,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.barlow(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      ).copyWith(fontFamilyFallback: _arabicFallback);

  /// Display / heading — Barlow Condensed (bold, tight, usually uppercase).
  static TextStyle condensed({
    double size = 24,
    FontWeight weight = FontWeight.w800,
    Color color = AppColors.txt,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.barlowCondensed(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      ).copyWith(fontFamilyFallback: _arabicFallback);

  /// Semi-condensed — between body and display (e.g. compact numeric labels).
  static TextStyle semiCondensed({
    double size = 14,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.txt,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.barlowSemiCondensed(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      ).copyWith(fontFamilyFallback: _arabicFallback);

  /// Small uppercase section label (e.g. "FORMAT", "ACCOUNT").
  static TextStyle label({Color color = AppColors.dim}) =>
      GoogleFonts.barlow(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1.2,
      ).copyWith(fontFamilyFallback: _arabicFallback);
}
