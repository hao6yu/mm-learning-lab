import 'package:flutter/material.dart';
import 'dart:math' as math;

class ResponsiveConfig {
  final double screenWidth;
  final double screenHeight;
  final double devicePixelRatio;

  ResponsiveConfig.fromContext(BuildContext context)
      : screenWidth = MediaQuery.of(context).size.width,
        screenHeight = MediaQuery.of(context).size.height,
        devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

  // Device type detection
  bool get isTablet {
    final shortestSide = math.min(screenWidth, screenHeight);
    return shortestSide > 600 || (shortestSide > 500 && devicePixelRatio < 2.5);
  }

  bool get isLandscape => screenWidth > screenHeight;
  bool get isSmallScreen => screenWidth < 400;

  // Avatar settings
  double get avatarSize => isTablet ? 140.0 : (isLandscape ? 80.0 : 120.0);
  double get avatarFontSize => isTablet ? 70.0 : (isLandscape ? 45.0 : 60.0);

  // Font sizes
  double get titleFontSize => isTablet ? 48.0 : (isLandscape ? 28.0 : 36.0);
  double get subtitleFontSize => isTablet ? 18.0 : (isLandscape ? 14.0 : 16.0);
  double get buttonFontSize => isTablet ? 28.0 : 24.0;

  // Spacing
  double get smallSpacing => isTablet ? 12.0 : (isLandscape ? 6.0 : 8.0);
  double get mediumSpacing => isTablet ? 24.0 : (isLandscape ? 12.0 : 16.0);
  double get largeSpacing => isTablet ? 48.0 : (isLandscape ? 24.0 : 32.0);

  // Button sizing
  double get buttonHorizontalPadding => isTablet ? 56.0 : (isLandscape ? 32.0 : 40.0);
  double get buttonVerticalPadding => isTablet ? 20.0 : (isLandscape ? 12.0 : 16.0);
  double get buttonBorderRadius => isTablet ? 28.0 : (isLandscape ? 16.0 : 20.0);

  // Layout constraints
  double get maxContentWidth => isTablet ? 800.0 : (isLandscape ? 700.0 : 500.0);
  double get topPadding => isLandscape ? 20.0 : 60.0;
}
