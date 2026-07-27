import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppColors.indigoPrimary,
        secondary: AppColors.accentPurple,
        surface: AppColors.surfaceColor,
        error: AppColors.errorRed,
        background: AppColors.backgroundColor,
      ),
      scaffoldBackgroundColor: AppColors.backgroundColor,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: AppColors.textColor,
        displayColor: AppColors.textColor,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceColor,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.indigoPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceColor,
        indicatorColor: AppColors.indigoPrimary.withOpacity(0.1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.outfit(
              color: AppColors.indigoPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            );
          }
          return GoogleFonts.outfit(
            color: AppColors.mutedText,
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.indigoPrimary);
          }
          return const IconThemeData(color: AppColors.mutedText);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.indigoPrimary, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.mutedText),
        hintStyle: const TextStyle(color: AppColors.mutedText),
      ),
    );
  }
}
