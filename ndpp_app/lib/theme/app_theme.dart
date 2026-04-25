import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    const seed = Color(0xFF0F766E);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed),
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: const Color(0xFFF7FAFC),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: seed, width: 1.5),
        ),
      ),
    );
  }
}
