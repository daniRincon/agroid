import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFFC8102E);    // Rojo Sioma
  static const Color secondary = Color(0xFF222222);  // Gris Oscuro
  static const Color accent = Color(0xFFF5F5F5);     // Gris claro

  static final ThemeData themeData = ThemeData(
    fontFamily: 'Montserrat',
    primaryColor: primary,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'Montserrat',
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
          fontFamily: 'Montserrat',
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: accent,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary),
      ),
      labelStyle: TextStyle(
        color: primary,
        fontFamily: 'Montserrat',
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: secondary,
        fontWeight: FontWeight.bold,
        fontSize: 24,
        fontFamily: 'Montserrat',
      ),
      bodyMedium: TextStyle(
        color: secondary,
        fontSize: 16,
        fontFamily: 'Montserrat',
      ),
    ),
  );
}