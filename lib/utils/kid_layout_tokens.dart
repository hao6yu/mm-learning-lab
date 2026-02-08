import 'dart:math' as math;

import 'package:flutter/material.dart';

class KidSelectionLayout {
  final Size size;
  final bool isLandscape;
  final bool isTablet;
  final bool isSmallPhoneLandscape;

  const KidSelectionLayout._({
    required this.size,
    required this.isLandscape,
    required this.isTablet,
    required this.isSmallPhoneLandscape,
  });

  factory KidSelectionLayout.fromContext(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final height = mediaQuery.size.height;
    final shortestSide = math.min(width, height);
    final isTablet = shortestSide >= 600;
    final isLandscape = width > height;
    final isSmallPhoneLandscape =
        isLandscape && !isTablet && shortestSide < 380;

    return KidSelectionLayout._(
      size: mediaQuery.size,
      isLandscape: isLandscape,
      isTablet: isTablet,
      isSmallPhoneLandscape: isSmallPhoneLandscape,
    );
  }

  double get horizontalPadding => isTablet ? 32.0 : (isLandscape ? 20.0 : 18.0);
  double get verticalPadding => isTablet ? 16.0 : 10.0;
  double get gridSpacing => isTablet ? 20.0 : 12.0;
  double get sectionSpacing => isTablet ? 12.0 : 8.0;
  double get subtitleFontSize => isTablet ? 17.0 : 14.0;

  int columnsForLandscape(int itemCount) {
    if (!isLandscape) {
      return 1;
    }
    if (itemCount <= 4) {
      return 2;
    }
    return isTablet ? 3 : 2;
  }

  double landscapeAspectRatio(int columnCount) {
    if (columnCount <= 2) {
      return isTablet ? 2.8 : 2.5;
    }
    return isTablet ? 2.2 : 2.0;
  }

  double portraitCardHeight(int itemCount) {
    final availableHeight = size.height - (isTablet ? 250.0 : 220.0);
    final baseHeight = (availableHeight / itemCount) - (isTablet ? 16.0 : 12.0);
    return baseHeight.clamp(
      isTablet ? 88.0 : 72.0,
      isTablet ? 128.0 : 104.0,
    );
  }
}
