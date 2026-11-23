import 'package:flutter/material.dart';

/// Rydio's visual language, pulled from the Figma file: a near-monochrome
/// black/white base (per the designer's own comment: "startup page ...
/// in black and white theme") with a single warm accent lifted straight
/// from the hand-drawn rider illustration's red tow-rope, used sparingly
/// for the one or two things per screen that need to pop.
abstract class AppColors {
  static const ink = Color(0xFF0E0E10);
  static const inkSoft = Color(0xFF1C1C1F);
  static const paper = Color(0xFFFFFFFF);
  static const cloud = Color(0xFFF4F4F6);
  static const mist = Color(0xFFE7E7EB);
  static const slate = Color(0xFF8A8A92);
  static const slateLight = Color(0xFFB8B8C0);

  /// Lifted from the rider illustration's red rope.
  static const accent = Color(0xFFFF5A3C);
  static const accentSoft = Color(0xFFFFE4DC);

  static const success = Color(0xFF2ECC71);

  // Figma's splash gradient is flat black until 42.5%, flat white after
  // 80.8%, with the fade happening only in between — so it needs 4 stops,
  // not a smooth 3-color blend across the whole frame.
  static const gradientSplash = [ink, ink, paper, paper];
  static const List<double> gradientSplashStops = [0.0, 0.425, 0.808, 1.0];
}
