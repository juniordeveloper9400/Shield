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

  // ---- Category pastels ----
  // Each category group owns one panel colour, which is what separates one
  // panel from the next on the Categories tab without needing a rule between
  // them, and a lighter chip colour used behind its artwork on the home strip.
  static const Color panelBlue = Color(0xFFEAF3FC);
  static const Color panelGreen = Color(0xFFE8F1EC);
  static const Color panelCream = Color(0xFFFDF3E3);
  static const Color panelPink = Color(0xFFFBECEC);
  static const Color panelSlate = Color(0xFFEDEFF4);

  static const Color chipBlueTint = Color(0xFFE9F2FB);
  static const Color chipGreenTint = Color(0xFFEAF5EC);
  static const Color chipCreamTint = Color(0xFFFDF6E3);
  static const Color chipPinkTint = Color(0xFFFBECEC);
  static const Color chipSlateTint = Color(0xFFF1F3F7);

  // ---- Privilege cards ----
  // One hue per card, so the five are told apart at a glance rather than by
  // reading the amounts. Each accent is dark enough to carry text on its tint,
  // and each pair is distinct from the four category pastels above.
  static const Color silverAccent = Color(0xFF6E7A8A);
  static const Color silverTint = Color(0xFFEFF1F5);

  static const Color goldAccent = Color(0xFFA9791B);
  static const Color goldTint = Color(0xFFFBF1DA);

  static const Color platinumAccent = Color(0xFF2F6E73);
  static const Color platinumTint = Color(0xFFE2F0F0);

  static const Color titaniumAccent = Color(0xFF5A4A96);
  static const Color titaniumTint = Color(0xFFECE7F8);

  static const Color diamondAccent = Color(0xFF1D7FA8);
  static const Color diamondTint = Color(0xFFE0F1F8);

  // ---- Surfaces ----
  static const Color white = Color(0xFFFFFFFF);

  // ---- Text ----
  static const Color textDark = Color(0xFF12203B);
  static const Color textBody = Color(0xFF3A4A66);
  static const Color textMuted = Color(0xFF6B7B95);

  // ---- Rejection ----
  // The one red in the app: field borders, error notes, and a refused code
  // all share it so a rejection reads as one state rather than three.
  static const Color danger = Color(0xFFB4322F);
  static const Color dangerTint = Color(0xFFFBEBEB);
  static const Color dangerLine = Color(0xFFE0A3A1);

  // ---- Lines ----
  static const Color border = Color(0xFFDCE5F1);
  static const Color searchBorder = Color(0xFFC3D2E8);

  static const Color transparent = Colors.transparent;
}
