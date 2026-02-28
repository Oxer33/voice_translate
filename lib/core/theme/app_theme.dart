/// Tema dell'applicazione VoiceTranslate.
/// Supporta tema scuro (default) e chiaro automatico in base al sistema.
/// Design moderno ispirato a Linear.app e Vercel.com.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colori principali dell'app
class AppColors {
  AppColors._();

  // --- Colori primari (blu e bianco come da spec) ---
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryBlueLight = Color(0xFF60A5FA);
  static const Color primaryBlueDark = Color(0xFF1D4ED8);

  // --- Tema scuro ---
  static const Color darkBackground = Color(0xFF0A0A0B);
  static const Color darkSurface = Color(0xFF141416);
  static const Color darkSurfaceVariant = Color(0xFF1E1E22);
  static const Color darkCard = Color(0xFF18181B);
  static const Color darkBorder = Color(0xFF27272A);
  static const Color darkTextPrimary = Color(0xFFF4F4F5);
  static const Color darkTextSecondary = Color(0xFFA1A1AA);
  static const Color darkTextTertiary = Color(0xFF71717A);

  // --- Tema chiaro ---
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF4F4F5);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE4E4E7);
  static const Color lightTextPrimary = Color(0xFF09090B);
  static const Color lightTextSecondary = Color(0xFF52525B);
  static const Color lightTextTertiary = Color(0xFF71717A);

  // --- Colori funzionali ---
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
}

/// Classe principale per la gestione del tema
class AppTheme {
  AppTheme._();

  /// Font base dell'app
  static String? get _fontFamily => GoogleFonts.inter().fontFamily;

  /// Tema scuro (default)
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: _fontFamily,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryBlue,
          onPrimary: Colors.white,
          secondary: AppColors.primaryBlueLight,
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkTextPrimary,
          error: AppColors.error,
          outline: AppColors.darkBorder,
        ),
        scaffoldBackgroundColor: AppColors.darkBackground,
        cardTheme: CardThemeData(
          color: AppColors.darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.darkBorder, width: 1),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: AppColors.darkTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.darkTextPrimary,
            side: const BorderSide(color: AppColors.darkBorder),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkSurfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primaryBlue, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(color: AppColors.darkTextTertiary),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.darkBorder,
          thickness: 1,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primaryBlue,
          linearTrackColor: AppColors.darkSurfaceVariant,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.darkSurfaceVariant,
          contentTextStyle: const TextStyle(color: AppColors.darkTextPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryBlue;
            }
            return AppColors.darkTextTertiary;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryBlue.withValues(alpha: 0.3);
            }
            return AppColors.darkSurfaceVariant;
          }),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: AppColors.primaryBlue,
          inactiveTrackColor: AppColors.darkSurfaceVariant,
          thumbColor: AppColors.primaryBlue,
          overlayColor: Color(0x292563EB),
        ),
      );

  /// Tema chiaro
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: _fontFamily,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primaryBlue,
          onPrimary: Colors.white,
          secondary: AppColors.primaryBlueDark,
          surface: AppColors.lightSurface,
          onSurface: AppColors.lightTextPrimary,
          error: AppColors.error,
          outline: AppColors.lightBorder,
        ),
        scaffoldBackgroundColor: AppColors.lightBackground,
        cardTheme: CardThemeData(
          color: AppColors.lightCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.lightBorder, width: 1),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: AppColors.lightTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.lightTextPrimary,
            side: const BorderSide(color: AppColors.lightBorder),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.lightSurfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.lightBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.lightBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primaryBlue, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(color: AppColors.lightTextTertiary),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.lightBorder,
          thickness: 1,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primaryBlue,
          linearTrackColor: AppColors.lightSurfaceVariant,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.lightSurface,
          contentTextStyle: const TextStyle(color: AppColors.lightTextPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryBlue;
            }
            return AppColors.lightTextTertiary;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryBlue.withValues(alpha: 0.3);
            }
            return AppColors.lightSurfaceVariant;
          }),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: AppColors.primaryBlue,
          inactiveTrackColor: AppColors.lightSurfaceVariant,
          thumbColor: AppColors.primaryBlue,
          overlayColor: Color(0x292563EB),
        ),
      );
}
