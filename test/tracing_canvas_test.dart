import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:mm_learning_lab/utils/tracing_completion_evaluator.dart';

void main() {
  List<Offset> scalePath(List<Offset> normalized, Size size) {
    return normalized
        .map((point) => Offset(point.dx * size.width, point.dy * size.height))
        .toList();
  }

  List<Offset> samplePath(List<Offset> path, {int stepsPerSegment = 12}) {
    final sampled = <Offset>[];
    for (int i = 0; i < path.length - 1; i++) {
      final start = path[i];
      final end = path[i + 1];
      for (int step = 0; step < stepsPerSegment; step++) {
        final t = step / stepsPerSegment;
        sampled.add(Offset.lerp(start, end, t)!);
      }
    }
    sampled.add(path.last);
    return sampled;
  }

  test('completion evaluator accepts a sufficiently traced A path', () {
    const canvasSize = Size(320, 440);
    const normalizedAPath = [
      Offset(0.2, 0.88),
      Offset(0.5, 0.12),
      Offset(0.8, 0.88),
      Offset(0.65, 0.53),
      Offset(0.35, 0.53),
    ];

    final referencePath = scalePath(normalizedAPath, canvasSize);
    final userPoints = samplePath(referencePath, stepsPerSegment: 14);

    final isComplete = TracingCompletionEvaluator.isTracingComplete(
      userPoints: userPoints,
      canvasSize: canvasSize,
      referencePath: referencePath,
    );

    expect(isComplete, isTrue);
  });

  test('completion evaluator rejects short/incomplete trace', () {
    const canvasSize = Size(320, 440);
    final referencePath = scalePath(
      const [
        Offset(0.2, 0.88),
        Offset(0.5, 0.12),
        Offset(0.8, 0.88),
        Offset(0.65, 0.53),
        Offset(0.35, 0.53),
      ],
      canvasSize,
    );

    final isComplete = TracingCompletionEvaluator.isTracingComplete(
      userPoints: const [
        Offset(60, 320),
        Offset(70, 300),
        Offset(80, 280),
      ],
      canvasSize: canvasSize,
      referencePath: referencePath,
    );

    expect(isComplete, isFalse);
  });

  test('completion evaluator rejects very narrow traces', () {
    const canvasSize = Size(320, 440);
    final referencePath = scalePath(
      const [
        Offset(0.2, 0.88),
        Offset(0.5, 0.12),
        Offset(0.8, 0.88),
        Offset(0.65, 0.53),
        Offset(0.35, 0.53),
      ],
      canvasSize,
    );

    final userPoints = List<Offset>.generate(
      30,
      (index) => Offset(160, 80 + index * 9),
    );

    final isComplete = TracingCompletionEvaluator.isTracingComplete(
      userPoints: userPoints,
      canvasSize: canvasSize,
      referencePath: referencePath,
    );

    expect(isComplete, isFalse);
  });
}
