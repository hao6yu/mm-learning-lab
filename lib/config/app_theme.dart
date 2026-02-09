import 'package:flutter/material.dart';

/// Available app themes
enum AppThemeType {
  standard,
  valentine,
}

/// Theme configuration with all colors needed throughout the app
class AppThemeConfig {
  final String name;
  final String emoji;
  final Color seedColor;
  
  // Background gradients
  final List<Color> screenGradient;
  final List<Color> homeGradient;
  
  // Primary UI colors
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  
  // Card colors (for game selection cards)
  final Color cardAiChat;
  final Color cardStory;
  final Color cardVoiceCall;
  final Color cardMath;
  final Color cardPuzzle;
  final Color cardTracing;
  final Color cardPhonics;
  
  // Text colors
  final Color headingColor;
  final Color subtitleColor;
  
  // Button colors
  final Color buttonPrimary;
  final Color buttonSecondary;
  
  // Special effects
  final List<Color> celebrationColors;
  final Color sparkleColor;

  const AppThemeConfig({
    required this.name,
    required this.emoji,
    required this.seedColor,
    required this.screenGradient,
    required this.homeGradient,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.cardAiChat,
    required this.cardStory,
    required this.cardVoiceCall,
    required this.cardMath,
    required this.cardPuzzle,
    required this.cardTracing,
    required this.cardPhonics,
    required this.headingColor,
    required this.subtitleColor,
    required this.buttonPrimary,
    required this.buttonSecondary,
    required this.celebrationColors,
    required this.sparkleColor,
  });

  /// Get Flutter ThemeData for MaterialApp
  ThemeData toThemeData() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

/// Standard theme (current orange/blue look)
const standardTheme = AppThemeConfig(
  name: 'Standard',
  emoji: '🌈',
  seedColor: Colors.orange,
  
  // Light blue to warm cream gradient
  screenGradient: [Color(0xFF8FD6FF), Color(0xFFFFF3E0)],
  homeGradient: [Color(0xFF8FD6FF), Color(0xFFFFF3E0)],
  
  primaryColor: Color(0xFFFF9800), // Orange
  secondaryColor: Color(0xFF64B5F6), // Light blue
  accentColor: Color(0xFFFFD54F), // Amber
  
  // Card colors - playful rainbow
  cardAiChat: Color(0xFF7C4DFF), // Purple
  cardStory: Color(0xFFFF7043), // Deep orange
  cardVoiceCall: Color(0xFF26A69A), // Teal
  cardMath: Color(0xFF42A5F5), // Blue
  cardPuzzle: Color(0xFFAB47BC), // Purple
  cardTracing: Color(0xFF66BB6A), // Green
  cardPhonics: Color(0xFFFFCA28), // Amber
  
  headingColor: Color(0xFF355C7D), // Dark blue-gray
  subtitleColor: Color(0xFF5D8AA8), // Steel blue
  
  buttonPrimary: Color(0xFFFF9800),
  buttonSecondary: Color(0xFF64B5F6),
  
  celebrationColors: [
    Color(0xFFFF9800),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
  ],
  sparkleColor: Color(0xFFFFD700),
);

/// Valentine's Day theme 💕
const valentineTheme = AppThemeConfig(
  name: "Valentine's Day",
  emoji: '💕',
  seedColor: Color(0xFFE91E63), // Pink
  
  // Soft pink to lavender gradient
  screenGradient: [Color(0xFFFFB6C1), Color(0xFFE6E6FA)],
  homeGradient: [Color(0xFFFFC1CC), Color(0xFFFFE4EC)],
  
  primaryColor: Color(0xFFFF6B95), // Soft pink
  secondaryColor: Color(0xFFB39DDB), // Lavender
  accentColor: Color(0xFFFF4081), // Pink accent
  
  // Card colors - Valentine palette
  cardAiChat: Color(0xFFE91E63), // Pink
  cardStory: Color(0xFFFF6B95), // Soft rose
  cardVoiceCall: Color(0xFFCE93D8), // Light purple
  cardMath: Color(0xFFFF8A80), // Soft red
  cardPuzzle: Color(0xFFB39DDB), // Lavender
  cardTracing: Color(0xFFF48FB1), // Light pink
  cardPhonics: Color(0xFFFFAB91), // Peach
  
  headingColor: Color(0xFF880E4F), // Dark pink
  subtitleColor: Color(0xFFAD1457), // Medium pink
  
  buttonPrimary: Color(0xFFE91E63),
  buttonSecondary: Color(0xFFCE93D8),
  
  // Hearts and sparkles!
  celebrationColors: [
    Color(0xFFE91E63), // Pink
    Color(0xFFFF4081), // Pink accent
    Color(0xFFCE93D8), // Lavender
    Color(0xFFFF80AB), // Light pink
    Color(0xFFFFFFFF), // White
  ],
  sparkleColor: Color(0xFFFFD1DC), // Light pink sparkle
);

/// Get theme config by type
AppThemeConfig getThemeConfig(AppThemeType type) {
  switch (type) {
    case AppThemeType.valentine:
      return valentineTheme;
    case AppThemeType.standard:
      return standardTheme;
  }
}

/// Check if Valentine's theme should be default based on date
bool isValentineSeason() {
  final now = DateTime.now();
  // All of February
  return now.month == 2;
}

/// Get the default theme based on current date
AppThemeType getSeasonalDefaultTheme() {
  if (isValentineSeason()) {
    return AppThemeType.valentine;
  }
  return AppThemeType.standard;
}
