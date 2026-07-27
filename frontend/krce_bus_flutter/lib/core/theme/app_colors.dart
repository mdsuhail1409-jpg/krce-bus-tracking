import 'package:flutter/material.dart';

class AppColors {
  // Primary palette (New UI/UX Spec)
  static const Color indigoPrimary = Color(0xFF14B8B5);
  static const Color accentPurple = Color(0xFF0F766E); // Kept the variable name for compatibility but changed color to Primary Dark
  static const Color accentCyan = Color(0xFF22D3EE);

  // Backgrounds
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color bgSecondary = Color(0xFFF1F5F9);

  // Text
  static const Color textColor = Color(0xFF1E293B);
  static const Color mutedText = Color(0xFF64748B);

  // Status
  static const Color successGreen = Color(0xFF22C55E);
  static const Color warningYellow = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color infoCyan = Color(0xFF06B6D4);

  // Borders
  static const Color borderColor = Color(0xFFE2E8F0);

  // Gradients
  static const LinearGradient gradientPrimary = LinearGradient(
    colors: [Color(0xFF14B8B5), Color(0xFF0F766E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientSuccess = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientWarning = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientDanger = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
