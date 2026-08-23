import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeStore {
  ThemeModeStore._();
  static final ThemeModeStore instance = ThemeModeStore._();

  static const String _key = 'settings.theme_mode.v1';

  final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    mode.value = _decode(prefs.getString(_key));
  }

  Future<void> setMode(ThemeMode next) async {
    if (mode.value == next) return;
    mode.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _encode(next));
  }

  static ThemeMode _decode(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
  }

  static String _encode(ThemeMode value) {
    return switch (value) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}
