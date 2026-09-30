import 'package:flutter/material.dart';

class NdColors {
  static const accent = Color(0xFF0E6E58);
  static const accentDark = Color(0xFF57C9A0);
  static const paper = Color(0xFFFAFAF8);
  static const ink = Color(0xFF15181A);
  static const darkSurface = Color(0xFF141A18);
  static const darkPaper = Color(0xFF0E1210);
}

ThemeData ndLightTheme({String? fontFamily}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: NdColors.accent,
    brightness: Brightness.light,
    surface: NdColors.paper,
  ).copyWith(
    primary: NdColors.accent,
    surface: NdColors.paper,
    onSurface: NdColors.ink,
  );
  return _base(scheme, fontFamily: fontFamily);
}

ThemeData ndDarkTheme({String? fontFamily}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: NdColors.accent,
    brightness: Brightness.dark,
    surface: NdColors.darkPaper,
  ).copyWith(
    primary: NdColors.accentDark,
    surface: NdColors.darkPaper,
    surfaceContainerHighest: NdColors.darkSurface,
  );
  return _base(scheme, fontFamily: fontFamily);
}

ThemeData _base(ColorScheme scheme, {String? fontFamily}) {
  TextStyle ts(double size,
          {FontWeight? weight, Color? color, double? letterSpacing}) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        fontFamily: fontFamily,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: ts(20,
          weight: FontWeight.w600,
          color: scheme.onSurface,
          letterSpacing: -0.3),
    ),
    cardTheme: CardThemeData(
      color: scheme.brightness == Brightness.light
          ? Colors.white
          : NdColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      margin: EdgeInsets.zero,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
      labelTextStyle: WidgetStatePropertyAll(
        ts(12, weight: FontWeight.w500, color: scheme.onSurface),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: ts(14, weight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: ts(14, weight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      labelStyle: ts(12, color: scheme.onSurfaceVariant),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      thickness: 1,
      space: 1,
    ),
  );
}
