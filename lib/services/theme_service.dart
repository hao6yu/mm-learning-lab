import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_theme.dart';

/// Service that manages app theme state and persistence
class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'app_theme_type';
  static const String _autoSeasonalKey = 'auto_seasonal_theme';
  
  AppThemeType _currentTheme = AppThemeType.standard;
  bool _autoSeasonal = true;
  bool _isInitialized = false;

  AppThemeType get currentTheme => _currentTheme;
  bool get autoSeasonal => _autoSeasonal;
  bool get isInitialized => _isInitialized;
  
  /// Get the current theme configuration
  AppThemeConfig get config => getThemeConfig(_currentTheme);

  /// Initialize theme from stored preferences
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    _autoSeasonal = prefs.getBool(_autoSeasonalKey) ?? true;
    
    if (_autoSeasonal) {
      // Use seasonal default
      _currentTheme = getSeasonalDefaultTheme();
    } else {
      // Use stored preference
      final storedTheme = prefs.getString(_themeKey);
      if (storedTheme != null) {
        _currentTheme = AppThemeType.values.firstWhere(
          (t) => t.name == storedTheme,
          orElse: () => AppThemeType.standard,
        );
      }
    }
    
    _isInitialized = true;
    notifyListeners();
  }

  /// Set the current theme
  Future<void> setTheme(AppThemeType theme) async {
    if (_currentTheme == theme) return;
    
    _currentTheme = theme;
    _autoSeasonal = false; // User explicitly chose, disable auto
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme.name);
    await prefs.setBool(_autoSeasonalKey, false);
    
    notifyListeners();
  }

  /// Enable auto-seasonal theme switching
  Future<void> setAutoSeasonal(bool enabled) async {
    _autoSeasonal = enabled;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSeasonalKey, enabled);
    
    if (enabled) {
      _currentTheme = getSeasonalDefaultTheme();
    }
    
    notifyListeners();
  }

  /// Get all available themes for the picker
  List<AppThemeConfig> get availableThemes => [
    standardTheme,
    valentineTheme,
  ];
}
