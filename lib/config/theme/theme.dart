import 'package:flutter/material.dart';

class AppTheme {
  // 🎯 Paleta refinada — tonos equilibrados y profesionales
  static const Color primary = Color(0xFFC8102E); // Rojo Sioma
  static const Color secondary = Color(0xFF1E1E1E); // Gris oscuro elegante
  static const Color accent = Color(0xFFF7F7F7); // Gris claro para fondos
  static const Color neutral = Color(0xFF9E9E9E); // Gris medio para textos secundarios

  static final ThemeData themeData = ThemeData(
    useMaterial3: true, // 💎 Activa Material 3 (más moderno)
    fontFamily: 'Montserrat',

    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      surface: Colors.white,
      background: Colors.white,
      error: Colors.red.shade700,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: secondary,
    ),

    scaffoldBackgroundColor: Colors.white,

    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      elevation: 3,
      centerTitle: true,
      shadowColor: Colors.black26,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
        fontFamily: 'Montserrat',
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 3,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          fontFamily: 'Montserrat',
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontFamily: 'Montserrat',
        ),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 3,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: accent,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      labelStyle: const TextStyle(
        color: secondary,
        fontFamily: 'Montserrat',
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: neutral.withOpacity(0.8),
        fontFamily: 'Montserrat',
      ),
    ),

    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      shadowColor: Colors.black12,
    ),

    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: secondary,
        fontWeight: FontWeight.bold,
        fontSize: 24,
        fontFamily: 'Montserrat',
      ),
      titleLarge: TextStyle(
        color: secondary,
        fontWeight: FontWeight.bold,
        fontSize: 20,
        fontFamily: 'Montserrat',
      ),
      bodyMedium: TextStyle(
        color: secondary,
        fontSize: 16,
        fontFamily: 'Montserrat',
        height: 1.4,
      ),
      labelLarge: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        fontFamily: 'Montserrat',
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: primary,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w500,
        fontFamily: 'Montserrat',
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
