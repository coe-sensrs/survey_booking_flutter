import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Palette (Sage & Stone theme)
  static const Color primary = Color(0xFF1B3B2B); // Deep Forest Green / Sage Primary
  static const Color primaryLight = Color(0xFF2D5A42);
  static const Color primaryDark = Color(0xFF0F241A);
  static const Color accent = Color(0xFFC49A45); // Stone Gold / Warm Sand

  // Light Theme Colors
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE4E7ED);

  static const Color textPrimaryLight = Color(0xFF1D2129);
  static const Color textSecondaryLight = Color(0xFF4E5969);
  static const Color textMutedLight = Color(0xFF86909C);

  // Dark Theme Colors
  static const Color backgroundDark = Color(0xFF0D1611); // Deep Dark Sage Background
  static const Color surfaceDark = Color(0xFF16241C);    // Dark Sage Surface
  static const Color cardDark = Color(0xFF1E3026);       // Elevated Dark Card
  static const Color borderDark = Color(0xFF2B4235);     // Dark Forest Border
  static const Color primaryDarkAccent = Color(0xFF386B50); // Vibrant Sage Accent in Dark

  static const Color textPrimaryDark = Color(0xFFEDF2EE);
  static const Color textSecondaryDark = Color(0xFFA5B8AC);
  static const Color textMutedDark = Color(0xFF6E8577);

  // Aliases for default/light mode widgets
  static const Color background = backgroundLight;
  static const Color surface = surfaceLight;
  static const Color cardBackground = cardLight;
  static const Color border = borderLight;
  static const Color textPrimary = textPrimaryLight;
  static const Color textSecondary = textSecondaryLight;
  static const Color textMuted = textMutedLight;

  // Status Colors (Universal)
  static const Color pending = Color(0xFFE6A23C);
  static const Color inProgress = Color(0xFF409EFF);
  static const Color approved = Color(0xFF67C23A);
  static const Color rejected = Color(0xFFF56C6C);
  static const Color clarification = Color(0xFF909399);

  static const Color textInverse = Color(0xFFFFFFFF);
}
