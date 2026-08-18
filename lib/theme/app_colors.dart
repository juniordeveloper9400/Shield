import 'package:flutter/material.dart';

/// Palette derived from `assets/logos/shield_mark.png`.
///
/// The two source values are sampled straight from the logo artwork:
/// the shield body (#2C57A6) and the check mark (#93C73F). Everything else
/// is a tint or shade of those two hues so the UI stays on-brand.
class AppColors {
  // ---- Sampled directly from the logo ----
  static const Color brandBlue = Color(0xFF2C57A6);
  static const Color brandGreen = Color(0xFF93C73F);

  // ---- Shades ----
  static const Color brandNavy = Color(0xFF16305C);
  static const Color brandBlueDeep = Color(0xFF224787);
  static const Color brandGreenDeep = Color(0xFF6B9A2E);
  static const Color brandGreenDark = Color(0xFF5A8127);

  // ---- Tints ----
  static const Color pageTint = Color(0xFFEFF4FC);
  static const Color bannerTop = Color(0xFFD9E4F5);
  static const Color bannerBottom = Color(0xFFEDF3FC);
  static const Color offerTint = Color(0xFFE4EDF9);
  static const Color categoryPanel = Color(0xFFE6EDF8);
  static const Color greenTint = Color(0xFFF0F7E4);
  static const Color creamTint = Color(0xFFF7F4DF);

  // ---- Surfaces ----
  static const Color white = Color(0xFFFFFFFF);

  // ---- Text ----
  static const Color textDark = Color(0xFF12203B);
  static const Color textBody = Color(0xFF3A4A66);
  static const Color textMuted = Color(0xFF6B7B95);

  // ---- Lines ----
  static const Color border = Color(0xFFDCE5F1);
  static const Color searchBorder = Color(0xFFC3D2E8);

  static const Color transparent = Colors.transparent;
}
