import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.indigoPrimary,
        secondary: AppColors.accentPurple,
        surface: AppColors.surfaceColor,
        error: AppColors.errorRed,
      ),
      scaffoldBackgroundColor: AppColors.backgroundColor,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      cardTheme: CardThemeData(
        color: AppColors.surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.borderColor),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceColor,
        indicatorColor: Colors.transparent,
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
            return IconThemeData(color: AppColors.indigoPrimary);
          }
          return IconThemeData(color: AppColors.mutedText);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.indigoPrimary, width: 2),
        ),
        labelStyle: TextStyle(color: AppColors.mutedText),
      ),
    );
  }
}
