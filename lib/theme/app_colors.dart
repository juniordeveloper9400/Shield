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
  // One hue per card, so the three are told apart at a glance rather than by
  // reading the amounts. Each accent is dark enough to carry text on its tint
  // and white text on itself, and each pair is distinct from the category
  // pastels above.
  static const Color silverAccent = Color(0xFF6E7A8A);
  static const Color silverTint = Color(0xFFEFF1F5);

  static const Color goldAccent = Color(0xFFA9791B);
  static const Color goldTint = Color(0xFFFBF1DA);

  static const Color platinumAccent = Color(0xFF2F6E73);
  static const Color platinumTint = Color(0xFFE2F0F0);

  // ---- Reward points ----
  // The coin the points balance is struck on. Its own gold rather than the
  // Gold card's above: a coin sitting in the home header in the Gold Shield's
  // colour would read as a plan the member holds, which is a different thing
  // from a points balance entirely.
  static const Color coinFace = Color(0xFFF3C144);
  static const Color coinShine = Color(0xFFFFE7A6);
  static const Color coinEdge = Color(0xFFC08E1C);

  /// The brightest point of the struck face and the lit side of the star —
  /// what gives the disc its dome.
  static const Color coinHighlight = Color(0xFFFFF7DA);

  /// The shaded quarter of the milled rim, opposite the light.
  static const Color coinDeep = Color(0xFF9A6B12);

  /// What is struck into the face. Dark enough to be read on [coinFace] at
  /// the 13px the header coin is drawn at.
  static const Color coinInk = Color(0xFF6E4A0C);

  // ---- Referral ladder ----
  // One hue per rung, running cool to warm so a glance up the ladder reads as
  // a climb. Deliberately not the privilege card colours: a level is earned by
  // bringing people in, a card is bought, and sharing a palette said the two
  // were the same ladder. Each accent carries white text; each tint carries
  // its own accent.
  static const Color levelStarter = Color(0xFF3F7FB5);
  static const Color levelStarterTint = Color(0xFFE7F0F8);

  static const Color levelRiser = Color(0xFF2F8F7A);
  static const Color levelRiserTint = Color(0xFFE3F2EE);

  static const Color levelAchiever = Color(0xFF6E8C2B);
  static const Color levelAchieverTint = Color(0xFFEFF4E1);

  static const Color levelChampion = Color(0xFFC4761B);
  static const Color levelChampionTint = Color(0xFFFBF0E0);

  static const Color levelLegend = Color(0xFF9A4C8E);
  static const Color levelLegendTint = Color(0xFFF6EAF4);

  // ---- Wallet panel ----
  // Flat [brandBlue] — the same blue the top-up button under the panel is
  // filled with, so the card and the one control on the screen read as one
  // piece rather than as a card and a button that happen to sit together.
  //
  // Flat rather than a gradient: the point is that it matches something
  // sitting right beside it, and a panel that darkens across its own face
  // stops matching anything halfway along.
  //
  // It carries white type, like the button does.
  static const Color walletPanel = brandBlue;

  /// The shadow that lifts the panel off the page.
  static const Color walletShadow = Color(0xFF16305C);

  // ---- Plan status ----
  // Whether a plan's instalment has come due this month. Both are lifted well
  // clear of the app's own green and red, because they sit on the blue panel
  // and have to be read on it — and because a plan that has not come round
  // yet is waiting rather than wrong.
  static const Color planActive = Color(0xFFB6E05A);
  static const Color planWaiting = Color(0xFFF9A8A5);

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
