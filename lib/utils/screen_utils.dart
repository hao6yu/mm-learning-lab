import 'package:flutter/material.dart';

extension ScreenUtils on BuildContext {
  // Basic screen properties
  Size get screenSize => MediaQuery.of(this).size;
  double get width => screenSize.width;
  double get height => screenSize.height;
  double get aspectRatio => width / height;

  // Device type detection
  bool get isPhone => width < 600;
  bool get isTablet => width >= 600;
  bool get isLandscape => aspectRatio > 1.0;
  bool get isPortrait => aspectRatio <= 1.0;
  bool get isSmallPhone => width < 400;

  // Simple responsive values
  double responsive(double mobile, {double? tablet, double? landscape}) {
    if (isLandscape && landscape != null) return landscape;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }

  // Common responsive sizes
  double get avatarSize => responsive(120, tablet: 140, landscape: 80);
  double get buttonPadding => responsive(16, tablet: 20, landscape: 12);
  double get spacing => responsive(16, tablet: 24, landscape: 12);
  double get largeSpacing => responsive(32, tablet: 48, landscape: 24);

  // Font scaling
  double scaledFont(double baseSize) =>
      responsive(baseSize, tablet: baseSize * 1.2, landscape: baseSize * 0.8);
}

// Alternative: Simple breakpoint constants
class Breakpoints {
  static const double mobile = 400;
  static const double tablet = 600;
  static const double desktop = 1200;
}

// Helper function for quick responsive values
T responsiveValue<T>(
  BuildContext context, {
  required T mobile,
  T? tablet,
  T? desktop,
}) {
  final width = MediaQuery.of(context).size.width;
  if (width >= Breakpoints.desktop && desktop != null) return desktop;
  if (width >= Breakpoints.tablet && tablet != null) return tablet;
  return mobile;
}
