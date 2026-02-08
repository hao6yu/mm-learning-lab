import 'dart:math' as math;

import 'dart:ui';

class TracingCompletionEvaluator {
  static bool isTracingComplete({
    required List<Offset> userPoints,
    required Size canvasSize,
    required List<Offset> referencePath,
  }) {
    if (userPoints.length < 12 || referencePath.length < 4) {
      return false;
    }

    final strokeLength = _strokeLength(userPoints);
    final minimumLength = canvasSize.shortestSide * 0.85;
    if (strokeLength < minimumLength) {
      return false;
    }

    final tolerance = canvasSize.shortestSide * 0.13;
    int coveredPoints = 0;

    for (final reference in referencePath) {
      final isCovered = userPoints.any(
        (point) => (point - reference).distance <= tolerance,
      );
      if (isCovered) {
        coveredPoints += 1;
      }
    }

    final coverageRatio = coveredPoints / referencePath.length;
    final userBounds = _calculateBounds(userPoints);
    final widthRatio = userBounds.width / canvasSize.width;
    final heightRatio = userBounds.height / canvasSize.height;

    return coverageRatio >= 0.5 && widthRatio >= 0.22 && heightRatio >= 0.24;
  }

  static double _strokeLength(List<Offset> points) {
    double length = 0;
    for (int i = 1; i < points.length; i++) {
      length += (points[i] - points[i - 1]).distance;
    }
    return length;
  }

  static Rect _calculateBounds(List<Offset> points) {
    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;

    for (final point in points) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}
