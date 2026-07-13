import 'package:flutter/material.dart';

class AppColors {
  // Primary palette — exact matches from Kotlin theme
  static const Color indigoPrimary = Color(0xFF6366F1);
  static const Color accentPurple = Color(0xFF818CF8);
  static const Color accentCyan = Color(0xFF22D3EE);

  // Backgrounds
  static const Color backgroundColor = Color(0xFF0F172A);
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color bgSecondary = Color(0xFF1E293B);

  // Text
  static const Color textColor = Color(0xFFF8FAFC);
  static const Color mutedText = Color(0xFF94A3B8);

  // Status
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningYellow = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color infoCyan = Color(0xFF06B6D4);

  // Borders
  static const Color borderColor = Color(0xFF334155);

  // Gradients
  static const LinearGradient gradientPrimary = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientSuccess = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
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
