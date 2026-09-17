import 'package:flutter/material.dart';

class AppTheme {
  // Blueprint and Steel Engineering Color Palette
  static const Color blueprintDark = Color(0xFF0B132B);
  static const Color blueprintSurface = Color(0xFF1C2541);
  static const Color blueprintCard = Color(0xFF1E293B);
  static const Color blueprintGrid = Color(0xFF233249);
  
  static const Color cyanLine = Color(0xFF38BDF8);
  static const Color cyanBright = Color(0xFF00F0FF);
  static const Color amberSteel = Color(0xFFF59E0B);
  static const Color steelBorder = Color(0xFF334155);

  static const Color textLight = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textSubtle = Color(0xFF64748B);

  static const Color statusSuccess = Color(0xFF10B981);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusDanger = Color(0xFFEF4444);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: blueprintDark,
      primaryColor: cyanLine,
      colorScheme: const ColorScheme.dark(
        primary: cyanLine,
        secondary: amberSteel,
        surface: blueprintSurface,
        error: statusDanger,
        onPrimary: blueprintDark,
        onSecondary: blueprintDark,
        onSurface: textLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: blueprintSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textLight,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: cyanLine),
      ),
      cardTheme: CardThemeData(
        color: blueprintCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: steelBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: blueprintSurface,
        hintStyle: const TextStyle(color: textSubtle, fontSize: 14),
        labelStyle: const TextStyle(color: cyanLine, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: steelBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: steelBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cyanLine, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: statusDanger),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cyanLine,
          foregroundColor: blueprintDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cyanLine,
          side: const BorderSide(color: cyanLine, width: 1.2),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: steelBorder,
        thickness: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: blueprintSurface,
        selectedItemColor: cyanLine,
        unselectedItemColor: textSubtle,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
