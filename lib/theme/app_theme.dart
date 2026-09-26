import 'package:flutter/material.dart';

/// Shared colors and controls for the phone and desktop workspaces.
class AppTheme {
  static const Color background = Color(0xFF101714);
  static const Color surface = Color(0xFF17211C);
  static const Color panel = Color(0xFF1E2B24);
  static const Color border = Color(0xFF304238);
  static const Color muted = Color(0xFFA6B8AC);
  static const Color grassGreen = Color(0xFF86D9A0);
  static const Color darkGreen = Color(0xFF284D36);
  static const Color dirt = Color(0xFFB99A7A);
  static const Color stone = Color(0xFF9CAAA1);
  static const Color darkStone = Color(0xFF46594D);
  static const Color obsidian = background;
  static const Color diamond = Color(0xFF81CFC3);
  static const Color gold = Color(0xFFE8C67A);
  static const Color redstone = Color(0xFFFF9292);
  static const Color enderPurple = Color(0xFFBAAFE8);

  static ThemeData get darkTheme {
    final colors =
        ColorScheme.fromSeed(
          seedColor: grassGreen,
          brightness: Brightness.dark,
        ).copyWith(
          primary: grassGreen,
          onPrimary: const Color(0xFF102B1A),
          primaryContainer: darkGreen,
          onPrimaryContainer: const Color(0xFFC7F4D4),
          secondary: diamond,
          onSecondary: background,
          secondaryContainer: const Color(0xFF253C34),
          onSecondaryContainer: const Color(0xFFD8EFE1),
          tertiary: gold,
          surface: surface,
          surfaceContainerLowest: background,
          surfaceContainerLow: surface,
          surfaceContainer: panel,
          surfaceContainerHigh: const Color(0xFF26352C),
          surfaceContainerHighest: const Color(0xFF304238),
          onSurface: const Color(0xFFEDF4EF),
          onSurfaceVariant: muted,
          outline: const Color(0xFF617668),
          outlineVariant: border,
          error: redstone,
          onError: const Color(0xFF480E12),
          errorContainer: const Color(0xFF50282B),
          onErrorContainer: const Color(0xFFFFDADB),
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colors,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.1,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          color: muted,
          height: 1.4,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 72,
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          color: colors.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shape.copyWith(side: const BorderSide(color: border)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: grassGreen,
          foregroundColor: colors.onPrimary,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.onSurface,
          side: const BorderSide(color: border),
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        hintStyle: const TextStyle(color: muted, fontWeight: FontWeight.w400),
        labelStyle: const TextStyle(color: muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: grassGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: darkGreen,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: states.contains(WidgetState.selected) ? grassGreen : muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? grassGreen : muted,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: grassGreen,
        foregroundColor: colors.onPrimary,
        elevation: 2,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: darkGreen,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        labelStyle: TextStyle(color: colors.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panel,
        contentTextStyle: TextStyle(color: colors.onSurface, height: 1.4),
        behavior: SnackBarBehavior.floating,
        shape: shape.copyWith(side: const BorderSide(color: border)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: colors.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        textStyle: TextStyle(color: colors.onSurface, fontSize: 12),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: darkGreen,
        textColor: grassGreen,
      ),
    );
  }
}
