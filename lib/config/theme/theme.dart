import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF4CAF50);    // Verde
  static const Color secondary = Color(0xFF333333);  // Gris Oscuro
  static const Color accent = Color(0xFF2196F3);      // Azul

  static final ThemeData themeData = ThemeData(
    primaryColor: primary,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: primary, // Corregido: de 'color' a 'backgroundColor'
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[200],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary),
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: secondary,
        fontWeight: FontWeight.bold,
        fontSize: 24,
      ),
      bodyMedium: TextStyle(
        color: secondary,
        fontSize: 16,
      ),
    ),
  );
}