import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

const String _themeBoxName = 'settingsBox';
const String _themeKey = 'themeMode';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final box = await Hive.openBox(_themeBoxName);
      final savedTheme = box.get(_themeKey, defaultValue: 'system') as String;
      if (savedTheme == 'light') {
        state = ThemeMode.light;
      } else if (savedTheme == 'dark') {
        state = ThemeMode.dark;
      } else {
        state = ThemeMode.system;
      }
    } catch (_) {
      state = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final box = await Hive.openBox(_themeBoxName);
      String value = 'system';
      if (mode == ThemeMode.light) value = 'light';
      if (mode == ThemeMode.dark) value = 'dark';
      await box.put(_themeKey, value);
    } catch (_) {}
  }

  Future<void> toggleTheme() async {
    if (state == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});
