import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme { light, dark, amoled }

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  AppTheme _currentTheme = AppTheme.dark;
  Color _seekbarColor = Colors.red;

  AppTheme get currentTheme => _currentTheme;
  Color get seekbarColor => _seekbarColor;

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme') ?? 1;
    final colorValue = prefs.getInt('seekbar_color') ?? Colors.red.value;

    _seekbarColor = Color(colorValue);
    _currentTheme = AppTheme.values[themeIndex];

    switch (_currentTheme) {
      case AppTheme.light:
        state = ThemeMode.light;
        break;
      case AppTheme.dark:
      case AppTheme.amoled:
        state = ThemeMode.dark;
        break;
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme', theme.index);

    switch (theme) {
      case AppTheme.light:
        state = ThemeMode.light;
        break;
      case AppTheme.dark:
      case AppTheme.amoled:
        state = ThemeMode.dark;
        break;
    }
  }

  Future<void> setSeekbarColor(Color color) async {
    _seekbarColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seekbar_color', color.value);
    // Trigger rebuild
    state = state;
  }

  ThemeData get lightTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seekbarColor,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: _seekbarColor,
      unselectedItemColor: Colors.grey,
      elevation: 8,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: _seekbarColor,
      thumbColor: _seekbarColor,
      inactiveTrackColor: Colors.grey.shade300,
    ),
  );

  ThemeData get darkTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seekbarColor,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: _currentTheme == AppTheme.amoled
        ? Colors.black
        : const Color(0xFF121212),
    appBarTheme: AppBarTheme(
      backgroundColor: _currentTheme == AppTheme.amoled
          ? Colors.black
          : const Color(0xFF1F1F1F),
      foregroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: _currentTheme == AppTheme.amoled
          ? Colors.black
          : const Color(0xFF1F1F1F),
      selectedItemColor: _seekbarColor,
      unselectedItemColor: Colors.grey,
      elevation: 8,
    ),
    cardColor: _currentTheme == AppTheme.amoled
        ? Colors.black
        : const Color(0xFF1F1F1F),
    sliderTheme: SliderThemeData(
      activeTrackColor: _seekbarColor,
      thumbColor: _seekbarColor,
      inactiveTrackColor: Colors.grey.shade600,
    ),
  );
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});
