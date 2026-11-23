import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Poppins for everything UI (matches the Figma mode-card labels, which are
/// Poppins Bold), and "Merge One" just for the RYDIO wordmark lockup since
/// that's the display face the designer actually used on the splash frame.
///
/// "Merge One" has no generated camelCase shortcut in google_fonts (it's
/// only exposed through the dynamic lookup), so it's pulled with
/// [GoogleFonts.getFont] rather than a `GoogleFonts.mergeOne()` call.
abstract class AppTextStyles {
  static TextStyle wordmark({double size = 72, Color color = AppColors.paper}) {
    return GoogleFonts.getFont(
      'Merge One',
      fontSize: size,
      color: color,
      letterSpacing: size * 0.04,
      height: 1.0,
    );
  }

  static TextStyle get display => GoogleFonts.poppins(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        height: 1.15,
        letterSpacing: -0.5,
      );

  static TextStyle get headline => GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        height: 1.2,
      );

  static TextStyle get title => GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );

  static TextStyle get body => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
        height: 1.45,
      );

  static TextStyle get bodyMuted => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.slate,
        height: 1.4,
      );

  static TextStyle get label => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.slate,
        letterSpacing: 0.4,
      );

  /// The big "WALKIE TALKIE MODE" / "INTER-COM MODE" card labels.
  static TextStyle get cardTitle => GoogleFonts.poppins(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.paper,
        height: 1.15,
        letterSpacing: 0.2,
      );

  static TextStyle get button => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.paper,
      );
}

abstract class AppSpacing {
  static const xs = 6.0;
  static const sm = 12.0;
  static const md = 20.0;
  static const lg = 28.0;
  static const xl = 40.0;
  static const radiusLg = 28.0;
  static const radiusXl = 35.0; // exact Figma frame/card radius
}
