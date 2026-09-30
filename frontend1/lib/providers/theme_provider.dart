import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider pour gérer le thème de l'application (clair/sombre)
class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  static const String _themeModeKey = 'theme_mode';

  ThemeProvider() {
    _loadThemeMode();
  }

  /// Mode de thème actuel
  ThemeMode get themeMode => _themeMode;

  /// Vérifie si le thème sombre est actif
  bool get isDark => _themeMode == ThemeMode.dark;

  /// Toggle entre thème clair et sombre
  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    _saveThemeMode();
    notifyListeners();
  }

  /// Définit le mode de thème spécifique
  void setTheme(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      _saveThemeMode();
      notifyListeners();
    }
  }

  /// Charge le thème sauvegardé depuis SharedPreferences
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themeModeKey);

      if (savedMode != null) {
        _themeMode = savedMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ThemeProvider] Erreur lors du chargement du thème: $e');
    }
  }

  /// Sauvegarde le thème dans SharedPreferences
  Future<void> _saveThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _themeModeKey,
        _themeMode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (e) {
      debugPrint('[ThemeProvider] Erreur lors de la sauvegarde du thème: $e');
    }
  }
}
