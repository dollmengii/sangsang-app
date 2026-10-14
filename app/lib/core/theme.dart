import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 해 질 녘 같은, 조용하고 센치한 색. 종이 같은 바탕에 먼지 낀 장밋빛과 저녁 하늘 파랑.
class AppColors {
  const AppColors._({
    required this.paper,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.rose,
    required this.dusk,
    required this.glow,
  });

  final Color paper;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color line;
  final Color rose;
  final Color dusk;
  final Color glow;

  static const light = AppColors._(
    paper: Color(0xFFF4EFEA),
    surface: Color(0xFFFBF8F5),
    ink: Color(0xFF2E2A33),
    muted: Color(0xFF7D7584),
    line: Color(0xFFE4DCD5),
    rose: Color(0xFF9E6668),
    dusk: Color(0xFF6E7C9C),
    glow: Color(0xFFE9C9B7),
  );

  static const dark = AppColors._(
    paper: Color(0xFF15131A),
    surface: Color(0xFF1F1C25),
    ink: Color(0xFFECE6EF),
    muted: Color(0xFFA59EAD),
    line: Color(0xFF2F2B36),
    rose: Color(0xFFD7A3A4),
    dusk: Color(0xFF9DABC9),
    glow: Color(0xFF6B4C4F),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.rose,
    onPrimary: brightness == Brightness.dark ? c.paper : Colors.white,
    secondary: c.dusk,
    onSecondary: Colors.white,
    error: const Color(0xFFB3474B),
    onError: Colors.white,
    surface: c.paper,
    onSurface: c.ink,
    surfaceContainerLowest: c.surface,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.surface,
    onSurfaceVariant: c.muted,
    outline: c.line,
    outlineVariant: c.line,
  );

  final body = GoogleFonts.notoSansKrTextTheme(
    ThemeData(brightness: brightness).textTheme,
  ).apply(bodyColor: c.ink, displayColor: c.ink);
  TextStyle serif(TextStyle? base, {double? size, FontWeight? weight}) =>
      GoogleFonts.gowunBatang(textStyle: base, fontSize: size, fontWeight: weight, color: c.ink, height: 1.35);

  final text = body.copyWith(
    displayLarge: serif(body.displayLarge, size: 52, weight: FontWeight.w700),
    displayMedium: serif(body.displayMedium, size: 40, weight: FontWeight.w700),
    displaySmall: serif(body.displaySmall, size: 32, weight: FontWeight.w700),
    headlineMedium: serif(body.headlineMedium, size: 26, weight: FontWeight.w700),
    headlineSmall: serif(body.headlineSmall, size: 22, weight: FontWeight.w700),
    titleLarge: serif(body.titleLarge, size: 20, weight: FontWeight.w700),
    bodyLarge: body.bodyLarge?.copyWith(height: 1.7, fontSize: 15.5),
    bodyMedium: body.bodyMedium?.copyWith(height: 1.65, fontSize: 14.5),
    bodySmall: body.bodySmall?.copyWith(height: 1.5, color: c.muted),
    labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0.2),
  );

  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.paper,
    textTheme: text,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: c.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      foregroundColor: c.ink,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: rounded,
        textStyle: text.labelLarge?.copyWith(fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: rounded,
        side: BorderSide(color: c.line),
        foregroundColor: c.ink,
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: c.muted)),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.line),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      iconColor: c.muted,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodySmall,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(color: c.muted),
      hintStyle: TextStyle(color: c.muted.withValues(alpha: 0.7)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.rose, width: 1.4)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.rose,
      inactiveTrackColor: c.line,
      thumbColor: c.rose,
      overlayColor: c.rose.withValues(alpha: 0.12),
      trackHeight: 3,
    ),
    radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.rose : c.muted)),
    dialogTheme: DialogThemeData(backgroundColor: c.surface, surfaceTintColor: Colors.transparent),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide(color: c.muted, width: 1.4),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.paper,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.rose.withValues(alpha: 0.14),
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(text.labelSmall?.copyWith(color: c.muted)),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.rose : c.muted),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: text.bodyMedium?.copyWith(color: c.paper),
      shape: rounded,
    ),
  );
}
