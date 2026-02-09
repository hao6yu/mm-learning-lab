import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import '../services/theme_service.dart';

class BubblePopScreen extends StatefulWidget {
  const BubblePopScreen({super.key});

  @override
  State<BubblePopScreen> createState() => _BubblePopScreenState();
}

class _BubblePopScreenState extends State<BubblePopScreen>
    with TickerProviderStateMixin {
  late String targetLetter;
  List<String> bubbles = [];
  List<AnimationController> _controllers = [];
  int? poppingIndex;
  int? shakingIndex;
  bool showConfetti = false;
  final List<String> allLetters = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z'
  ];
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Random _rand = Random();

  // Add error handling flag
  bool hasError = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    try {
      _setupRound();
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = e.toString();
      });
    }
  }

  void _setupRound() {
    try {
      // Dispose old controllers if any
      if (_controllers.isNotEmpty) {
        for (final c in _controllers) {
          c.dispose();
        }
      }
      targetLetter = allLetters[_rand.nextInt(allLetters.length)];
      final Set<String> bubbleSet = {targetLetter};
      while (bubbleSet.length < 6) {
        bubbleSet.add(allLetters[_rand.nextInt(allLetters.length)]);
      }
      bubbles = bubbleSet.toList()..shuffle();
      _controllers = List.generate(
          6,
          (i) => AnimationController(
                vsync: this,
                duration: const Duration(milliseconds: 350),
              ));
      poppingIndex = null;
      shakingIndex = null;
      showConfetti = false;
      setState(() {
        hasError = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> _playSound(String file) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/$file'));
    } catch (e) {
      // Silently handle audio errors
      debugPrint('Error playing sound: $e');
    }
  }

  void _onBubbleTap(int i) async {
    if (bubbles[i] == targetLetter) {
      poppingIndex = i;
      await _playSound('pop.mp3');
      _controllers[i].forward().then((_) async {
        setState(() => showConfetti = true);
        await _playSound('cheer.mp3');
        await Future.delayed(const Duration(milliseconds: 900));
        _setupRound();
      });
    } else {
      shakingIndex = i;
      await _playSound('boing.mp3');
      setState(() {});
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() {
            shakingIndex = null;
          });
        }
      });
    }
  }

  // Improved random positioning that ensures all bubbles are visible
  List<Offset> _generateRandomBubblePositions(
      Size area, double bubbleRadius, int count) {
    // Use a grid layout with jitter, but ensure all bubbles are fully inside the area
    List<Offset> positions = [];
    final margin = 8.0; // margin from the edge
    final safeWidth = area.width - 2 * (bubbleRadius + margin);
    final safeHeight = area.height - 2 * (bubbleRadius + margin);
    final topOffset = margin; // always start at the top of the available area

    int cols = 2;
    int rows = 3;
    double sectionWidth = safeWidth / cols;
    double sectionHeight = safeHeight / rows;
    double edgeBuffer = 0.2;

    for (int i = 0; i < count; i++) {
      int row = i ~/ cols;
      int col = i % cols;
      double baseX = col * sectionWidth + sectionWidth / 2;
      double baseY = topOffset + row * sectionHeight + sectionHeight / 2;
      double jitterX = ((_rand.nextDouble() * 2) - 1) *
          (sectionWidth * (1 - edgeBuffer * 2)) *
          0.5;
      double jitterY = ((_rand.nextDouble() * 2) - 1) *
          (sectionHeight * (1 - edgeBuffer * 2)) *
          0.5;
      double x = baseX + jitterX;
      double y = baseY + jitterY;
      // Ensure within bounds (fully visible)
      x = x.clamp(bubbleRadius + margin, area.width - bubbleRadius - margin);
      y = y.clamp(bubbleRadius + margin, area.height - bubbleRadius - margin);
      positions.add(Offset(x, y));
    }
    // Final pass to ensure no overlaps
    for (int i = 0; i < positions.length; i++) {
      for (int j = i + 1; j < positions.length; j++) {
        double distance = (positions[i] - positions[j]).distance;
        double minDistance = bubbleRadius * 2.1;
        if (distance < minDistance) {
          double dx = positions[i].dx - positions[j].dx;
          double dy = positions[i].dy - positions[j].dy;
          double length = sqrt(dx * dx + dy * dy);
          if (length > 0.0001) {
            dx /= length;
            dy /= length;
          } else {
            double angle = _rand.nextDouble() * 2 * pi;
            dx = cos(angle);
            dy = sin(angle);
          }
          double pushAmount = (minDistance - distance) / 2;
          positions[i] = Offset(
            (positions[i].dx + dx * pushAmount).clamp(
                bubbleRadius + margin, area.width - bubbleRadius - margin),
            (positions[i].dy + dy * pushAmount).clamp(
                bubbleRadius + margin, area.height - bubbleRadius - margin),
          );
          positions[j] = Offset(
            (positions[j].dx - dx * pushAmount).clamp(
                bubbleRadius + margin, area.width - bubbleRadius - margin),
            (positions[j].dy - dy * pushAmount).clamp(
                bubbleRadius + margin, area.height - bubbleRadius - margin),
          );
        }
      }
    }
    return positions;
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  // Helper to get responsive sizing
  double _getResponsiveSize(BuildContext context, double defaultSize) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return defaultSize * 0.7;
    if (width < 600) return defaultSize * 0.85;
    return defaultSize;
  }

  // Helper for button size
  double _getButtonSize(BuildContext context) {
    return _getResponsiveSize(context, 60);
  }

  // Helper for icon size
  double _getIconSize(BuildContext context) {
    return _getResponsiveSize(context, 32);
  }

  // Helper for font size
  double _getTitleFontSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 36;
    if (width < 600) return 48;
    return 56;
  }

  // Helper for bubble size
  double _getBubbleSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 75.0; // Smaller bubbles on small screens
    if (width < 600) return 100.0;
    return 140.0;
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = context.watch<ThemeService>().config;
    
    // Fallback widget in case of errors
    if (hasError) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: themeConfig.screenGradient,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9F43),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x33FF9F43),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Oops! Something went wrong.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    _setupRound();
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    // Calculate bubble sizes based on screen size
    final bubbleSize = _getBubbleSize(context);
    final bubbleRadius = bubbleSize / 2;

    // Button sizes
    final buttonSize = _getButtonSize(context);
    final iconSize = _getIconSize(context);
    final titleFontSize = _getTitleFontSize(context);

    // Decorative bubbles
    final emptyBubbles = isSmallScreen
        ? []
        : [
            const Offset(0.0, -0.7),
            const Offset(1.0, 0.5),
          ];

    // If state is out of sync (e.g. after hot reload), reset round
    if (bubbles.length != 6 || _controllers.length != 6) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setupRound();
      });
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: themeConfig.screenGradient,
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Playful background with clouds
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: themeConfig.screenGradient,
                ),
              ),
            ),
          ),

          // Only show clouds on medium/large screens
          if (!isSmallScreen) ...[
            Positioned(top: 40, left: 40, child: _Cloud(size: 60)),
            Positioned(top: 100, right: 60, child: _Cloud(size: 40)),
            Positioned(top: 180, left: 120, child: _Cloud(size: 32)),
          ],

          // Main content
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 8.0 : 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Playful back button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: buttonSize,
                          height: buttonSize,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9F43),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x33FF9F43),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: iconSize,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                SizedBox(height: isSmallScreen ? 0 : 8),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Bubble Pop',
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFF9F43),
                      letterSpacing: isSmallScreen ? 1 : 2,
                      shadows: [
                        const Shadow(
                          color: Colors.white,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: isSmallScreen ? 4 : 12),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Pop the bubble with:',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 22 : 28,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8E6CFF),
                    ),
                  ),
                ),

                SizedBox(height: isSmallScreen ? 4 : 8),

                Text(
                  targetLetter,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 48 : 64,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFFF6B6B),
                    letterSpacing: isSmallScreen ? 1 : 2,
                    shadows: const [
                      Shadow(
                        color: Colors.white,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),

                // This determines the available space for bubbles
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final area =
                          Size(constraints.maxWidth, constraints.maxHeight);
                      final bubblePositions = _generateRandomBubblePositions(
                        area,
                        bubbleRadius,
                        bubbles.length,
                      );
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // Decorative empty bubbles - only on larger screens
                          if (emptyBubbles.isNotEmpty)
                            for (final pos in emptyBubbles)
                              Positioned(
                                left: area.width * 0.5 +
                                    pos.dx * 100 -
                                    bubbleRadius * 0.6,
                                top: area.height * 0.4 +
                                    pos.dy * 100 -
                                    bubbleRadius * 0.6,
                                child: _Bubble(
                                  letter: '',
                                  isTarget: false,
                                  isDecorative: true,
                                  popping: false,
                                  shaking: false,
                                  size: bubbleSize * 0.6,
                                ),
                              ),
                          // Main bubbles
                          for (int i = 0; i < bubbles.length; i++)
                            AnimatedBuilder(
                              animation: _controllers[i],
                              builder: (context, child) {
                                final popping = poppingIndex == i;
                                final shaking = shakingIndex == i;
                                return Positioned(
                                  left: bubblePositions[i].dx - bubbleRadius,
                                  top: bubblePositions[i].dy - bubbleRadius,
                                  child: GestureDetector(
                                    onTap: () => _onBubbleTap(i),
                                    child: Transform.scale(
                                      scale: popping
                                          ? 1 - _controllers[i].value
                                          : 1,
                                      child: _Bubble(
                                        letter: bubbles[i],
                                        isTarget: bubbles[i] == targetLetter,
                                        isDecorative: false,
                                        popping: popping,
                                        shaking: shaking,
                                        size: bubbleSize,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          if (showConfetti && poppingIndex != null)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: _ConfettiOverlay(
                                  origin: bubblePositions[poppingIndex!],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String letter;
  final bool isTarget;
  final bool isDecorative;
  final bool popping;
  final bool shaking;
  final double size;

  const _Bubble({
    required this.letter,
    required this.isTarget,
    required this.isDecorative,
    required this.size,
    this.popping = false,
    this.shaking = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    // Special handling for narrow letters
    bool isNarrowLetter = "IijJl1".contains(letter);

    // Scale font size based on bubble size, with special handling for narrow letters
    final fontSize =
        isDecorative ? 0.0 : (isNarrowLetter ? size * 0.6 : size * 0.45);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size,
      height: size,
      transform: shaking
          ? (Matrix4.identity()
            ..translateByDouble(Random().nextInt(12) - 6.0, 0.0, 0.0, 1.0))
          : Matrix4.identity(),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDecorative
            ? Colors.white.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.7), // More opacity
        border: Border.all(
          color: const Color(0xFFB3E0FF),
          width: isDecorative ? 2 : (isSmallScreen ? 3 : 6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12), // Stronger shadow
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (letter.isNotEmpty)
            Center(
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF8E6CFF),
                  letterSpacing: 0, // Remove letter spacing to center better
                  shadows: [
                    Shadow(
                      color: Colors.black
                          .withValues(alpha: 0.15), // Stronger text shadow
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          // Bubble highlight - smaller on small screens
          if (!isDecorative || !isSmallScreen)
            Positioned(
              top: size * 0.17,
              left: size * 0.25,
              child: Container(
                width: size * 0.25,
                height: size * 0.12,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(size * 0.08),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cloud extends StatelessWidget {
  final double size;
  const _Cloud({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 0.6,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Stack(
        children: [
          Positioned(
            left: size * 0.18,
            top: size * 0.18,
            child: Container(
              width: size * 0.5,
              height: size * 0.32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(size * 0.16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced confetti overlay that bursts from the popped bubble's position
class _ConfettiOverlay extends StatefulWidget {
  final Offset origin;
  const _ConfettiOverlay({required this.origin});
  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ConfettiBurstPainter(
            progress: _controller.value,
            origin: widget.origin,
            isSmallScreen: MediaQuery.of(context).size.width < 360,
          ),
        );
      },
    );
  }
}

class _ConfettiBurstPainter extends CustomPainter {
  final double progress;
  final Offset origin;
  final bool isSmallScreen;
  final Random _rand = Random();

  _ConfettiBurstPainter({
    required this.progress,
    required this.origin,
    required this.isSmallScreen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int confettiCount = isSmallScreen ? 20 : 32;
    final double maxDistance = isSmallScreen ? 80 : 120;

    for (int i = 0; i < confettiCount; i++) {
      final angle = (2 * pi / confettiCount) * i + _rand.nextDouble() * 0.2;
      final distance = 0.0 + progress * (maxDistance + _rand.nextDouble() * 40);
      final x = origin.dx + cos(angle) * distance;
      final y = origin.dy + sin(angle) * distance;
      final r = isSmallScreen
          ? (2.0 + _rand.nextDouble() * 3)
          : (4.0 + _rand.nextDouble() * 4);
      final paint = Paint()
        ..color = Color.fromARGB(
                255, _rand.nextInt(256), _rand.nextInt(256), _rand.nextInt(256))
            .withValues(alpha: 1 - progress * 0.7);
      canvas.drawCircle(Offset(x, y), r, paint);
    }

    // Draw a few stars
    final starCount = isSmallScreen ? 5 : 8;
    for (int i = 0; i < starCount; i++) {
      final angle = (2 * pi / starCount) * i + _rand.nextDouble() * 0.2;
      final distance = 0.0 +
          progress * ((isSmallScreen ? 60 : 90) + _rand.nextDouble() * 30);
      final x = origin.dx + cos(angle) * distance;
      final y = origin.dy + sin(angle) * distance;
      final paint = Paint()
        ..color = Colors.yellow.withValues(alpha: 1 - progress * 0.7);
      final starSize = isSmallScreen
          ? (6.0 + _rand.nextDouble() * 3)
          : (10.0 + _rand.nextDouble() * 4);
      _drawStar(canvas, Offset(x, y), starSize, paint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (2 * pi / 5) * i - pi / 2;
      final x = center.dx + cos(angle) * radius;
      final y = center.dy + sin(angle) * radius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      final innerAngle = angle + pi / 5;
      final innerX = center.dx + cos(innerAngle) * (radius * 0.4);
      final innerY = center.dy + sin(innerAngle) * (radius * 0.4);
      path.lineTo(innerX, innerY);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
