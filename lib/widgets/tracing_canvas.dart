import 'package:flutter/material.dart';

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

class _TracingCanvasState extends State<TracingCanvas> with SingleTickerProviderStateMixin {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;

  AnimationController? _demoController;
  List<Offset>? _demoPath;
  int _demoPathLength = 0;

  @override
  void initState() {
    super.initState();
    _initDemoController();
  }

  @override
  void didUpdateWidget(covariant TracingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateDemo && !oldWidget.animateDemo) {
      _startDemoAnimation();
    }
  }

  void _initDemoController() {
    _demoController?.dispose();
    _demoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
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

  void _startDemoAnimation() {
    _demoPath = _getDemoPath(widget.letter);
    _demoPathLength = _demoPath?.length ?? 0;
    _demoController?.reset();
    _demoController?.forward();
  }

  List<Offset> _getDemoPath(String letter) {
    // Simple demo paths for A, B, C. Others: diagonal line.
    switch (letter) {
      case 'A':
        return [
          const Offset(60, 320),
          const Offset(150, 80),
          const Offset(240, 320),
          const Offset(110, 200),
          const Offset(190, 200),
        ];
      case 'B':
        return [
          const Offset(80, 80),
          const Offset(80, 320),
          const Offset(80, 200),
          const Offset(180, 160),
          const Offset(80, 200),
          const Offset(180, 240),
          const Offset(80, 320),
        ];
      case 'C':
        return [
          const Offset(220, 100),
          const Offset(120, 80),
          const Offset(80, 200),
          const Offset(120, 320),
          const Offset(220, 300),
        ];
      default:
        return [
          const Offset(60, 320),
          const Offset(240, 80),
        ];
    }
  }

  @override
  void dispose() {
    _demoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
                  fontSize: 200,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey.withOpacity(0.2),
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
              setState(() {
                _currentStroke?.add(details.localPosition);
              });
            },
            onPanEnd: (details) {
              _currentStroke = null;
              // TODO: Check if the tracing is complete
              // widget.onCompleted();
            },
            child: CustomPaint(
              size: const Size(300, 400),
              painter: _TracingPainter(
                strokes: _strokes,
                demoPath: (widget.animateDemo && _demoPath != null && _demoController != null) ? _demoPath!.sublist(0, (_demoPathLength * (_demoController!.value)).clamp(0, _demoPathLength).toInt()) : null,
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
                });
              },
              icon: const Icon(Icons.refresh),
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _TracingPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset>? demoPath;

  _TracingPainter({required this.strokes, this.demoPath});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8E6CFF)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      path.moveTo(stroke[0].dx, stroke[0].dy);

      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }

      canvas.drawPath(path, paint);
    }

    if (demoPath != null && demoPath!.length > 1) {
      final demoPaint = Paint()
        ..color = Colors.orange
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final demo = Path();
      demo.moveTo(demoPath![0].dx, demoPath![0].dy);
      for (int i = 1; i < demoPath!.length; i++) {
        demo.lineTo(demoPath![i].dx, demoPath![i].dy);
      }
      canvas.drawPath(demo, demoPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
