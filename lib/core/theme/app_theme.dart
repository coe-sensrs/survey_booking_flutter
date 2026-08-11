import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_spacing.dart';

/// Sage & Stone design system — Flutter theme implementation.
/// Place in lib/theme/app_theme.dart.
///
/// Both LIGHT and DARK schemes below are taken verbatim from design.md —
/// this app now has real designer-authored exports for both, not a
/// generated approximation. Cross-checked: every "fixed" role (primaryFixed,
/// onPrimaryFixed, etc.) is byte-identical between the two source files,
/// which is exactly what M3 spec requires since fixed roles are defined to
/// be brightness-independent — confirms these are a properly generated
/// pair, not two disconnected palettes.
///
/// ⚠️ NOT compiled or verified against the Flutter SDK — no Flutter
/// toolchain is available in the sandbox that generated this file.
/// Specific known risk: `primaryFixed` / `surfaceContainer*` roles were
/// added to `ColorScheme` in Flutter 3.22 (confirmed via Flutter's own
/// breaking-changes docs). If your project pins an older SDK, this
/// constructor will fail to compile and those named parameters need to
/// be removed. `CardThemeData` (vs. the older `CardTheme`) has also seen
/// renames across recent Flutter versions — check your SDK's docs if
/// `cardTheme:` below throws a type error.
///
/// Requires the `google_fonts` package — add to pubspec.yaml:
///   google_fonts: ^6.2.1
class AppTheme {
  AppTheme._();

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF316342),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF4A7C59),
    onPrimaryContainer: Color(0xFFE1FFE5),
    secondary: Color(0xFF655D52),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE9DED0),
    onSecondaryContainer: Color(0xFF696156),
    tertiary: Color(0xFF6D5622),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFF886E38),
    onTertiaryContainer: Color(0xFFFFF6ED),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    surface: Color(0xFFF7FAF4),
    onSurface: Color(0xFF191D19),
    onSurfaceVariant: Color(0xFF414942),
    outline: Color(0xFF717971),
    outlineVariant: Color(0xFFC1C9BF),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF2D312E),
    onInverseSurface: Color(0xFFEFF2EC),
    inversePrimary: Color(0xFF9DD3AA),
    surfaceTint: Color(0xFF376847),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF1F5EF),
    surfaceContainer: Color(0xFFECEFE9),
    surfaceContainerHigh: Color(0xFFE6E9E3),
    surfaceContainerHighest: Color(0xFFE0E3DE),
    surfaceDim: Color(0xFFD8DBD5),
    surfaceBright: Color(0xFFF7FAF4),
    primaryFixed: Color(0xFFB9EFC5),
    primaryFixedDim: Color(0xFF9DD3AA),
    onPrimaryFixed: Color(0xFF00210E),
    onPrimaryFixedVariant: Color(0xFF1E5031),
    secondaryFixed: Color(0xFFECE1D3),
    secondaryFixedDim: Color(0xFFD0C5B8),
    onSecondaryFixed: Color(0xFF201B12),
    onSecondaryFixedVariant: Color(0xFF4D463C),
    tertiaryFixed: Color(0xFFFFDEA0),
    tertiaryFixedDim: Color(0xFFE2C284),
    onTertiaryFixed: Color(0xFF261A00),
    onTertiaryFixedVariant: Color(0xFF594311),
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF9DD3AA),
    onPrimary: Color(0xFF01391C),
    primaryContainer: Color(0xFF4A7C59),
    onPrimaryContainer: Color(0xFFE1FFE5),
    secondary: Color(0xFFD0C5B8),
    onSecondary: Color(0xFF362F26),
    secondaryContainer: Color(0xFF4F483E),
    onSecondaryContainer: Color(0xFFC1B7AA),
    tertiary: Color(0xFFE2C284),
    onTertiary: Color(0xFF402D00),
    tertiaryContainer: Color(0xFF886E38),
    onTertiaryContainer: Color(0xFFFFF6ED),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF101411),
    onSurface: Color(0xFFE0E3DE),
    onSurfaceVariant: Color(0xFFC1C9BF),
    outline: Color(0xFF8B938A),
    outlineVariant: Color(0xFF414942),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE0E3DE),
    onInverseSurface: Color(0xFF2D312E),
    inversePrimary: Color(0xFF376847),
    surfaceTint: Color(0xFF9DD3AA),
    surfaceContainerLowest: Color(0xFF0B0F0C),
    surfaceContainerLow: Color(0xFF191D19),
    surfaceContainer: Color(0xFF1D211D),
    surfaceContainerHigh: Color(0xFF272B27),
    surfaceContainerHighest: Color(0xFF323632),
    surfaceDim: Color(0xFF101411),
    surfaceBright: Color(0xFF363A36),
    primaryFixed: Color(0xFFB9EFC5),
    primaryFixedDim: Color(0xFF9DD3AA),
    onPrimaryFixed: Color(0xFF00210E),
    onPrimaryFixedVariant: Color(0xFF1E5031),
    secondaryFixed: Color(0xFFECE1D3),
    secondaryFixedDim: Color(0xFFD0C5B8),
    onSecondaryFixed: Color(0xFF201B12),
    onSecondaryFixedVariant: Color(0xFF4D463C),
    tertiaryFixed: Color(0xFFFFDEA0),
    tertiaryFixedDim: Color(0xFFE2C284),
    onTertiaryFixed: Color(0xFF261A00),
    onTertiaryFixedVariant: Color(0xFF594311),
  );

  /// Only headline-lg, headline-md, body-lg, and label-md were specified
  /// in design.md — 4 of Flutter's 15 TextTheme roles. Every other role
  /// below is extrapolated using standard M3 type-scale ratios, not given
  /// directly in the design system. Titles default to Nunito Sans since
  /// design.md only assigns Literata to "headlines" and Nunito Sans to
  /// "body & labels" — titles aren't mentioned either way. Flag this if
  /// you actually want serif titles.
  static TextTheme _textTheme(ColorScheme scheme) {
    final base = TextTheme(
      displayLarge: GoogleFonts.literata(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        height: 64 / 57,
      ),
      displayMedium: GoogleFonts.literata(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        height: 52 / 45,
      ),
      displaySmall: GoogleFonts.literata(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 44 / 36,
      ),
      headlineLarge: GoogleFonts.literata(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32,
      ), // given
      headlineMedium: GoogleFonts.literata(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
      ), // given
      headlineSmall: GoogleFonts.literata(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
      ),
      titleLarge: GoogleFonts.nunitoSans(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 28 / 22,
      ),
      titleMedium: GoogleFonts.nunitoSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 24 / 16,
      ),
      titleSmall: GoogleFonts.nunitoSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
      ),
      bodyLarge: GoogleFonts.nunitoSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
      ), // given
      bodyMedium: GoogleFonts.nunitoSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
      ),
      bodySmall: GoogleFonts.nunitoSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
      ),
      labelLarge: GoogleFonts.nunitoSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
        letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.nunitoSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 16 / 12,
        letterSpacing: 0.5,
      ), // given
      labelSmall: GoogleFonts.nunitoSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 16 / 11,
        letterSpacing: 0.5,
      ),
    );
    return base.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
  }

  static ThemeData get light => _buildTheme(_lightScheme);
  static ThemeData get dark => _buildTheme(_darkScheme);

  static ThemeData _buildTheme(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: _textTheme(scheme),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.base),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.base),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.base),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.base),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        labelStyle: GoogleFonts.nunitoSans(color: scheme.onSurfaceVariant),
      ),

      cardTheme: CardThemeData(
        // Dark mode's design.md explicitly calls for surface-container-high
        // (or -highest) for cards, not the lower container level used for
        // light — elevation reads as "lighter" in dark M3, per its own
        // Elevation & Depth section. Light keeps the lower container per
        // its doc's softer, subtler tonal-shift guidance.
        color: scheme.brightness == Brightness.dark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLow,
        elevation: 1,
        shadowColor: scheme.shadow.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        margin: const EdgeInsets.all(AppSpacing.sm),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.tertiaryContainer,
        labelStyle: GoogleFonts.nunitoSans(
          color: scheme.onTertiaryContainer,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: AppSpacing.md,
      ),
    );
  }
}
