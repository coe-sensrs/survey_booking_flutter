import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:google_fonts/google_fonts.dart';

/// App theme built with FlexColorScheme v8.
///
/// Usage in [MaterialApp]:
/// ```dart
/// MaterialApp(
///   theme: AppTheme.lightTheme,
///   darkTheme: AppTheme.darkTheme,
/// );
/// ```
class AppTheme {
  AppTheme._();

  static const _subThemes = FlexSubThemesData(
    interactionEffects: true,
    tintedDisabledControls: true,
    useM2StyleDividerInM3: true,
    // Input decoration
    inputDecoratorIsFilled: true,
    inputDecoratorBorderType: FlexInputBorderType.outline,
    inputDecoratorRadius: 10,
    inputDecoratorContentPadding: EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 14,
    ),
    // Buttons
    elevatedButtonRadius: 10,
    outlinedButtonRadius: 10,
    textButtonRadius: 10,
    // Cards
    cardRadius: 12,
    // Navigation
    alignedDropdown: true,
    navigationBarLabelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    navigationRailUseIndicator: true,
  );

  static ThemeData get lightTheme {
    final base = FlexThemeData.light(
      scheme: FlexScheme.greenM3,
      subThemesData: _subThemes,
      fontFamily: GoogleFonts.inter().fontFamily,
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
    );

    // Apply button minimum height (not supported in FlexSubThemesData)
    return ResponsiveTheme.fromTheme(
      base.copyWith(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: (base.elevatedButtonTheme.style ?? const ButtonStyle())
              .copyWith(
                minimumSize: const WidgetStatePropertyAll(Size.fromHeight(50)),
              ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: (base.outlinedButtonTheme.style ?? const ButtonStyle())
              .copyWith(
                minimumSize: const WidgetStatePropertyAll(Size.fromHeight(50)),
              ),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = FlexThemeData.dark(
      scheme: FlexScheme.greenM3,
      subThemesData: _subThemes.copyWith(blendOnColors: true),
      fontFamily: GoogleFonts.inter().fontFamily,
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
    );

    return ResponsiveTheme.fromTheme(
      base.copyWith(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: (base.elevatedButtonTheme.style ?? const ButtonStyle())
              .copyWith(
                minimumSize: const WidgetStatePropertyAll(Size.fromHeight(50)),
              ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: (base.outlinedButtonTheme.style ?? const ButtonStyle())
              .copyWith(
                minimumSize: const WidgetStatePropertyAll(Size.fromHeight(50)),
              ),
        ),
      ),
    );
  }
}
