import 'package:flutter/material.dart';

// ─── Brand colours ────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color darkNavy    = Color(0xFF050D1A);
  static const Color surface     = Color(0xFF0D1B2E);
  static const Color card        = Color(0xFF122035);
  static const Color cardBorder  = Color(0xFF1E3050);

  // Teal header / accent
  static const Color clinicalTeal       = Color(0xFF0F7B8C);
  static const Color clinicalTealLight  = Color(0xFF12A3BA);
  static const Color clinicalTealGlow   = Color(0x2212A3BA);

  // Triage severity
  static const Color emergency         = Color(0xFFDC2626); // deep crimson
  static const Color emergencyGlow     = Color(0x55DC2626);
  static const Color urgent            = Color(0xFFD97706); // amber-orange
  static const Color urgentGlow        = Color(0x55D97706);
  static const Color normalGreen       = Color(0xFF059669); // emerald
  static const Color normalGlow        = Color(0x5505AB6E);

  // Text
  static const Color textPrimary   = Color(0xFFF0F8FF);
  static const Color textSecondary = Color(0xFF8BA6C0);
  static const Color textMuted     = Color(0xFF4A6B8A);

  // UI chrome
  static const Color inputFill    = Color(0xFF0D2030);
  static const Color inputBorder  = Color(0xFF1E3A55);
  static const Color divider      = Color(0xFF152740);
  static const Color statusGreen  = Color(0xFF34D399);
}

// ─── Text styles ──────────────────────────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle headingMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.8,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.6,
  );

  static const TextStyle monoBold = TextStyle(
    fontFamily: 'RobotoMono',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.clinicalTealLight,
  );
}

// ─── ThemeData ────────────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkNavy,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.dark(
      primary: AppColors.clinicalTeal,
      secondary: AppColors.clinicalTealLight,
      surface: AppColors.surface,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.clinicalTeal, width: 1.5),
      ),
      hintStyle: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 14,
        fontFamily: 'Inter',
      ),
      labelStyle: AppTextStyles.labelLarge,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.clinicalTeal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 1.2,
        ),
      ),
    ),
    dividerColor: AppColors.divider,
  );
}
