import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/tracing_completion_evaluator.dart';

class TracingCanvas extends StatefulWidget {
  final String letter;
  final bool showGuide;
  final VoidCallback onCompleted;
  final bool animateDemo;
  final VoidCallback? onDemoComplete;

  const TracingCanvas({
    super.key,
    required this.letter,
    required this.showGuide,
    required this.onCompleted,
    this.animateDemo = false,
    this.onDemoComplete,
  });

  @override
  State<TracingCanvas> createState() => _TracingCanvasState();
}

class _TracingCanvasState extends State<TracingCanvas>
    with SingleTickerProviderStateMixin {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;

  late final AnimationController _demoController;
  List<Offset> _demoPath = [];
  bool _hasCompleted = false;

  @override
  void initState() {
    super.initState();
    _demoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onDemoComplete?.call();
        }
      });
  }

  @override
  void didUpdateWidget(covariant TracingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.letter != oldWidget.letter) {
      _strokes.clear();
      _currentStroke = null;
      _hasCompleted = false;
      _demoPath = [];
      _demoController.reset();
    }
  }

  @override
  void dispose() {
    _demoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        final letterPath = _scaledPath(widget.letter, canvasSize);

        if (widget.animateDemo && !_demoController.isAnimating) {
          _startDemoAnimation(letterPath);
        }

        final demoPath = _demoPath.isEmpty
            ? null
            : _demoPath
                .take(
                  (_demoPath.length * _demoController.value)
                      .clamp(0, _demoPath.length)
                      .toInt(),
                )
                .toList();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (widget.showGuide)
                Center(
                  child: Text(
                    widget.letter,
                    style: TextStyle(
                      fontFamily: 'Baloo2',
                      fontSize:
                          math.min(canvasSize.width, canvasSize.height) * 0.64,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _currentStroke = [details.localPosition];
                    _strokes.add(_currentStroke!);
                  });
                },
                onPanUpdate: (details) {
                  if (!_isInsideCanvas(details.localPosition, canvasSize)) {
                    return;
                  }
                  setState(() {
                    _currentStroke?.add(details.localPosition);
                  });
                },
                onPanEnd: (_) {
                  _currentStroke = null;
                  if (_hasCompleted) {
                    return;
                  }

                  if (_isTracingComplete(canvasSize, letterPath)) {
                    _hasCompleted = true;
                    widget.onCompleted();
                  }
                },
                child: CustomPaint(
                  size: canvasSize,
                  painter: _TracingPainter(
                    strokes: _strokes,
                    demoPath: demoPath,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _strokes.clear();
                      _currentStroke = null;
                      _hasCompleted = false;
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  color: const Color(0xFF6D7A8A),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _startDemoAnimation(List<Offset> path) {
    _demoPath = path;
    _demoController
      ..reset()
      ..forward();
  }

  bool _isInsideCanvas(Offset point, Size size) {
    return point.dx >= 0 &&
        point.dy >= 0 &&
        point.dx <= size.width &&
        point.dy <= size.height;
  }

  bool _isTracingComplete(Size canvasSize, List<Offset> referencePath) {
    final userPoints = _strokes.expand((stroke) => stroke).toList();
    return TracingCompletionEvaluator.isTracingComplete(
      userPoints: userPoints,
      canvasSize: canvasSize,
      referencePath: referencePath,
    );
  }

  List<Offset> _scaledPath(String letter, Size size) {
    final normalizedPath = _normalizedLetterPath(letter.toUpperCase());
    return normalizedPath
        .map(
          (point) => Offset(point.dx * size.width, point.dy * size.height),
        )
        .toList();
  }

  List<Offset> _normalizedLetterPath(String letter) {
    switch (letter) {
      case 'A':
        return const [
          Offset(0.2, 0.88),
          Offset(0.5, 0.12),
          Offset(0.8, 0.88),
          Offset(0.65, 0.53),
          Offset(0.35, 0.53),
        ];
      case 'B':
        return const [
          Offset(0.28, 0.12),
          Offset(0.28, 0.88),
          Offset(0.68, 0.75),
          Offset(0.28, 0.5),
          Offset(0.7, 0.25),
          Offset(0.28, 0.12),
        ];
      case 'C':
        return const [
          Offset(0.75, 0.2),
          Offset(0.58, 0.12),
          Offset(0.32, 0.2),
          Offset(0.22, 0.5),
          Offset(0.32, 0.8),
          Offset(0.58, 0.88),
          Offset(0.75, 0.8),
        ];
      case 'D':
        return const [
          Offset(0.28, 0.12),
          Offset(0.28, 0.88),
          Offset(0.65, 0.76),
          Offset(0.78, 0.5),
          Offset(0.65, 0.24),
          Offset(0.28, 0.12),
        ];
      case 'E':
        return const [
          Offset(0.75, 0.12),
          Offset(0.28, 0.12),
          Offset(0.28, 0.88),
          Offset(0.75, 0.88),
          Offset(0.28, 0.5),
          Offset(0.62, 0.5),
        ];
      case 'F':
        return const [
          Offset(0.28, 0.88),
          Offset(0.28, 0.12),
          Offset(0.75, 0.12),
          Offset(0.28, 0.48),
          Offset(0.62, 0.48),
        ];
      case 'G':
        return const [
          Offset(0.75, 0.26),
          Offset(0.58, 0.12),
          Offset(0.32, 0.18),
          Offset(0.22, 0.5),
          Offset(0.32, 0.82),
          Offset(0.65, 0.88),
          Offset(0.78, 0.62),
          Offset(0.58, 0.62),
        ];
      case 'H':
        return const [
          Offset(0.28, 0.12),
          Offset(0.28, 0.88),
          Offset(0.28, 0.5),
          Offset(0.72, 0.5),
          Offset(0.72, 0.12),
          Offset(0.72, 0.88),
        ];
      case 'I':
        return const [
          Offset(0.25, 0.12),
          Offset(0.75, 0.12),
          Offset(0.5, 0.12),
          Offset(0.5, 0.88),
          Offset(0.25, 0.88),
          Offset(0.75, 0.88),
        ];
      case 'J':
        return const [
          Offset(0.25, 0.12),
          Offset(0.75, 0.12),
          Offset(0.6, 0.12),
          Offset(0.6, 0.75),
          Offset(0.5, 0.88),
          Offset(0.3, 0.8),
        ];
      case 'K':
        return const [
          Offset(0.28, 0.12),
          Offset(0.28, 0.88),
          Offset(0.72, 0.12),
          Offset(0.28, 0.5),
          Offset(0.72, 0.88),
        ];
      case 'L':
        return const [
          Offset(0.3, 0.12),
          Offset(0.3, 0.88),
          Offset(0.75, 0.88),
        ];
      case 'M':
        return const [
          Offset(0.2, 0.88),
          Offset(0.2, 0.12),
          Offset(0.5, 0.52),
          Offset(0.8, 0.12),
          Offset(0.8, 0.88),
        ];
      case 'N':
        return const [
          Offset(0.22, 0.88),
          Offset(0.22, 0.12),
          Offset(0.78, 0.88),
          Offset(0.78, 0.12),
        ];
      case 'O':
        return const [
          Offset(0.5, 0.12),
          Offset(0.72, 0.22),
          Offset(0.8, 0.5),
          Offset(0.72, 0.78),
          Offset(0.5, 0.88),
          Offset(0.28, 0.78),
          Offset(0.2, 0.5),
          Offset(0.28, 0.22),
          Offset(0.5, 0.12),
        ];
      case 'P':
        return const [
          Offset(0.28, 0.88),
          Offset(0.28, 0.12),
          Offset(0.68, 0.2),
          Offset(0.68, 0.45),
          Offset(0.28, 0.5),
        ];
      case 'Q':
        return const [
          Offset(0.5, 0.12),
          Offset(0.72, 0.22),
          Offset(0.8, 0.5),
          Offset(0.72, 0.78),
          Offset(0.5, 0.88),
          Offset(0.28, 0.78),
          Offset(0.2, 0.5),
          Offset(0.28, 0.22),
          Offset(0.5, 0.12),
          Offset(0.65, 0.72),
          Offset(0.8, 0.88),
        ];
      case 'R':
        return const [
          Offset(0.28, 0.88),
          Offset(0.28, 0.12),
          Offset(0.68, 0.2),
          Offset(0.68, 0.45),
          Offset(0.28, 0.5),
          Offset(0.72, 0.88),
        ];
      case 'S':
        return const [
          Offset(0.72, 0.2),
          Offset(0.52, 0.12),
          Offset(0.3, 0.24),
          Offset(0.5, 0.5),
          Offset(0.7, 0.76),
          Offset(0.48, 0.88),
          Offset(0.28, 0.8),
        ];
      case 'T':
        return const [
          Offset(0.2, 0.12),
          Offset(0.8, 0.12),
          Offset(0.5, 0.12),
          Offset(0.5, 0.88),
        ];
      case 'U':
        return const [
          Offset(0.25, 0.12),
          Offset(0.25, 0.7),
          Offset(0.5, 0.88),
          Offset(0.75, 0.7),
          Offset(0.75, 0.12),
        ];
      case 'V':
        return const [
          Offset(0.22, 0.12),
          Offset(0.5, 0.88),
          Offset(0.78, 0.12),
        ];
      case 'W':
        return const [
          Offset(0.16, 0.12),
          Offset(0.32, 0.88),
          Offset(0.5, 0.35),
          Offset(0.68, 0.88),
          Offset(0.84, 0.12),
        ];
      case 'X':
        return const [
          Offset(0.2, 0.12),
          Offset(0.8, 0.88),
          Offset(0.5, 0.5),
          Offset(0.8, 0.12),
          Offset(0.2, 0.88),
        ];
      case 'Y':
        return const [
          Offset(0.2, 0.12),
          Offset(0.5, 0.48),
          Offset(0.8, 0.12),
          Offset(0.5, 0.48),
          Offset(0.5, 0.88),
        ];
      case 'Z':
        return const [
          Offset(0.2, 0.12),
          Offset(0.8, 0.12),
          Offset(0.2, 0.88),
          Offset(0.8, 0.88),
        ];
      default:
        return const [
          Offset(0.2, 0.88),
          Offset(0.8, 0.12),
        ];
    }
  }
}

class _TracingPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset>? demoPath;

  _TracingPainter({required this.strokes, this.demoPath});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = const Color(0xFF8E6CFF)
      ..strokeWidth = math.max(5, size.shortestSide * 0.02)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, strokePaint);
    }

    if (demoPath != null && demoPath!.length > 1) {
      final demoPaint = Paint()
        ..color = const Color(0xFFFF9F43)
        ..strokeWidth = math.max(6, size.shortestSide * 0.024)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path()..moveTo(demoPath!.first.dx, demoPath!.first.dy);
      for (int i = 1; i < demoPath!.length; i++) {
        path.lineTo(demoPath![i].dx, demoPath![i].dy);
      }
      canvas.drawPath(path, demoPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TracingPainter oldDelegate) {
    return oldDelegate.strokes != strokes || oldDelegate.demoPath != demoPath;
  }
}
