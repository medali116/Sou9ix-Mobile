import 'package:flutter/material.dart';

/// Central brand palette for Sou9ix, derived from the app logo
/// (deep teal gradient, gold accent, near-black surfaces).
class AppColors {
  AppColors._();

  static const Color tealDark = Color(0xFF0B7A66);
  static const Color teal = Color(0xFF12A388);
  static const Color tealLight = Color(0xFF2DD4BF);

  static const Color gold = Color(0xFFF2B84B);
  static const Color goldDark = Color(0xFFE0A430);

  static const Color ink = Color(0xFF10171B);
  static const Color inkSoft = Color(0xFF17222A);

  static const Color background = Color(0xFFF5F7F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEFF3F3);

  static const Color textPrimary = Color(0xFF15201F);
  static const Color textSecondary = Color(0xFF66787A);
  static const Color textFaint = Color(0xFFA2B0B1);

  static const Color border = Color(0xFFE4EAEA);

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color purple = Color(0xFF8B5CF6);

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tealDark, teal, tealLight],
  );

  static const LinearGradient inkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [ink, inkSoft],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldDark, gold],
  );

  static Color categoryColor(int index) {
    const palette = [teal, gold, info, danger, tealDark, goldDark];
    return palette[index % palette.length];
  }
}
