import 'package:flutter/material.dart';

class AppTheme {
  // Minecraft-inspired colors
  static const Color grassGreen = Color(0xFF5D9B47);
  static const Color darkGreen = Color(0xFF3D6B31);
  static const Color dirt = Color(0xFF8B6B4C);
  static const Color stone = Color(0xFF7F7F7F);
  static const Color darkStone = Color(0xFF4A4A4A);
  static const Color obsidian = Color(0xFF1A1A2E);
  static const Color diamond = Color(0xFF4AEDD9);
  static const Color gold = Color(0xFFFFD700);
  static const Color redstone = Color(0xFFFF3B3B);
  static const Color enderPurple = Color(0xFF9B4DCA);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: grassGreen,
        onPrimary: Colors.white,
        secondary: diamond,
        onSecondary: Colors.black,
        tertiary: gold,
        surface: const Color(0xFF1E1E2E),
        onSurface: Colors.white,
        error: redstone,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: obsidian,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF16161F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF252538),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: grassGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: grassGreen,
          side: const BorderSide(color: grassGreen),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF252538),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: grassGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: redstone, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: grassGreen,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF16161F),
        selectedItemColor: grassGreen,
        unselectedItemColor: Colors.grey,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF252538),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF252538),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: grassGreen,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF3A3A4A),
        thickness: 1,
      ),
    );
  }
}
