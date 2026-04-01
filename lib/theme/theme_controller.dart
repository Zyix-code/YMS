import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark }

class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._();
  ThemeController._();

  AppThemeMode _mode = AppThemeMode.dark;

  AppThemeMode get mode => _mode;
  bool get isDark => _mode == AppThemeMode.dark;

  ThemeMode get flutterThemeMode {
    switch (_mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString('theme') ?? 'dark';

    _mode = AppThemeMode.values.firstWhere(
      (e) => e.name == v,
      orElse: () => AppThemeMode.light,
    );

    notifyListeners();
  }

  Future<void> setMode(AppThemeMode m) async {
    if (_mode == m) return;

    _mode = m;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('theme', m.name);
    notifyListeners();
  }

  Future<void> toggle() async {
    await setMode(isDark ? AppThemeMode.light : AppThemeMode.dark);
  }
}
