import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';

class NumberPopScreen extends StatefulWidget {
  const NumberPopScreen({super.key});

  @override
  State<NumberPopScreen> createState() => _NumberPopScreenState();
}

class _NumberPopScreenState extends State<NumberPopScreen>
    with SingleTickerProviderStateMixin {
  final Random _random = Random();
  int _targetNumber = 5;
  int _score = 0;
  List<_Bubble> _bubbles = [];
  int _timeLeft = 60;
  Timer? _timer;
  bool _gameOver = false;
  bool _showGetReady = true;
  bool _scoreShake = false;
  String? _scoreEffect; // '+1' or '-1'

  // Device and orientation detection helpers
  bool get _isTablet {
    final data = MediaQuery.of(context);
    return data.size.shortestSide >= 600; // iPad or large tablet
  }

  bool get _isLandscape {
    final data = MediaQuery.of(context);
    return data.size.width > data.size.height;
  }

  bool get _isPhoneLandscape {
    return !_isTablet && _isLandscape;
  }

  // Responsive helpers
  double get _topUiHeight {
    final screenWidth = MediaQuery.of(context).size.width;

    // Base UI elements: back button (44) + timer (44) + padding + target badge height + spacing
    double baseHeight = 44 + 32; // Back button + top padding

    // Target badge height varies by device type and orientation
    if (_isPhoneLandscape) {
      baseHeight += 50; // Compact for phone landscape
    } else if (screenWidth < 400) {
      baseHeight += 60; // Smaller target badge + spacing
    } else {
      baseHeight += 80; // Larger target badge + spacing
    }

    // Add buffer for safe area and spacing - less for phone landscape
    baseHeight += _isPhoneLandscape ? 20 : 40;

    return baseHeight;
  }

  double get _bubbleMinSize {
    if (_isPhoneLandscape) {
      // Smaller bubbles for phone landscape to fit more
      return 35;
    } else if (_isTablet) {
      // Larger bubbles for tablets
      return 55;
    } else {
      // Phone portrait
      final width = MediaQuery.of(context).size.width;
      if (width < 360) return 38;
      if (width < 500) return 48;
      return 60;
    }
  }

  double get _bubbleMaxSize {
    if (_isPhoneLandscape) {
      // Smaller max size for phone landscape
      return 65;
    } else if (_isTablet) {
      // Larger bubbles for tablets
      return 120;
    } else {
      // Phone portrait
      final width = MediaQuery.of(context).size.width;
      if (width < 360) return 60;
      if (width < 500) return 80;
      return 100;
    }
  }

  int get _numBubbles {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final area = width * height;

    // Device-specific bubble counts
    if (_isPhoneLandscape) {
      // Phone landscape: use area-based calculation like portrait, but slightly reduced
      // Account for the fact that we have more horizontal space but less vertical
      if (area < 300000) return 5; // Same as portrait small
      if (area < 500000) return 6; // Slightly less than portrait (7)
      return 7; // Slightly less than portrait (8)
    } else if (_isTablet) {
      // Tablets have more space for bubbles
      if (area < 800000) return 8;
      if (area < 1200000) return 10;
      return 12;
    } else {
      // Phone portrait
      if (area < 300000) return 5;
      if (area < 500000) return 7;
      return 8;
    }
  }

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    _score = 0;
    _timeLeft = 60;
    _gameOver = false;
    _showGetReady = true;
    _scoreShake = false;
    _scoreEffect = null;
    _nextRound();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0 && !_gameOver) {
        setState(() {
          _timeLeft--;
        });
        if (_timeLeft == 0) {
          _endGame();
        }
      }
    });
  }

  void _endGame() {
    setState(() {
      _gameOver = true;
      _timer?.cancel();
    });
  }

  void _nextRound() async {
    setState(() {
      _showGetReady = true;
    });
    await Future.delayed(const Duration(milliseconds: 900));
    setState(() {
      _showGetReady = false;
      _targetNumber = _random.nextInt(9) + 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use LayoutBuilder to get available area for bubbles
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      final topUiHeight = _topUiHeight;

      // Device and orientation-aware padding calculation
      double sidePadding, topPadding, bottomPadding;

      if (_isPhoneLandscape) {
        // Phone landscape: increased side padding to prevent cutoff
        sidePadding = 60.0; // Increased from 16.0
        topPadding = 8.0;
        bottomPadding = 40.0; // Minimal bottom padding for phone landscape
      } else if (_isTablet && _isLandscape) {
        // Tablet landscape: generous spacing
        sidePadding = 60.0;
        topPadding = 16.0;
        bottomPadding = 80.0;
      } else if (_isTablet) {
        // Tablet portrait: generous spacing
        sidePadding = 20.0;
        topPadding = 16.0;
        bottomPadding = 100.0;
      } else {
        // Phone portrait: standard spacing
        sidePadding = 12.0;
        topPadding = 12.0;
        bottomPadding = screenHeight < 700 ? 100.0 : 120.0;
      }

      final availableWidth = screenWidth - (sidePadding * 2);
      final availableHeight =
          screenHeight - topUiHeight - topPadding - bottomPadding;

      // Ensure we have minimum space for bubbles
      if (availableHeight < _bubbleMinSize || availableWidth < _bubbleMinSize) {
        // Not enough space, skip this round
        setState(() {
          _bubbles = [];
        });
        return;
      }

      List<_Bubble> bubbles = [];
      int numBubbles = _numBubbles;
      int targetIndex = _random.nextInt(numBubbles);

      // Ensure at least one target number exists
      bool hasTarget = false;

      for (int i = 0; i < numBubbles; i++) {
        int number;
        if (i == targetIndex || (!hasTarget && i == numBubbles - 1)) {
          number = _targetNumber;
          hasTarget = true;
        } else {
          // Generate different numbers to avoid confusion
          do {
            number = _random.nextInt(9) + 1;
          } while (number == _targetNumber && _random.nextBool());
        }

        double size = _random.nextDouble() * (_bubbleMaxSize - _bubbleMinSize) +
            _bubbleMinSize;
        double left, top;
        int tries = 0;
        bool positioned = false;

        // Try to position bubble with better space utilization
        do {
          // Ensure bubble fits completely within available area
          double maxLeft = screenWidth - size - sidePadding;
          double maxTop = screenHeight - size - bottomPadding;

          left = _random.nextDouble() * (maxLeft - sidePadding) + sidePadding;
          top = _random.nextDouble() * (maxTop - (topUiHeight + topPadding)) +
              topUiHeight +
              topPadding;

          // Additional safety check for bounds
          left = left.clamp(sidePadding, maxLeft);
          top = top.clamp(topUiHeight + topPadding, maxTop);

          // Check for overlaps with existing bubbles
          positioned = true;
          for (var existingBubble in bubbles) {
            double distance = sqrt(pow(
                    left +
                        size / 2 -
                        (existingBubble.left + existingBubble.size / 2),
                    2) +
                pow(
                    top +
                        size / 2 -
                        (existingBubble.top + existingBubble.size / 2),
                    2));
            double minDistance =
                (size + existingBubble.size) / 2 + 8; // 8px minimum gap

            if (distance < minDistance) {
              positioned = false;
              break;
            }
          }

          tries++;
        } while (!positioned && tries < 50);

        // If we couldn't position after many tries, use a fallback position
        if (!positioned) {
          // Grid-based fallback with proper bounds checking
          int cols = _isPhoneLandscape ? 2 : 3;
          int col = i % cols;
          int row = i ~/ cols;

          double cellWidth = availableWidth / cols;
          double cellHeight = availableHeight /
              ((numBubbles + cols - 1) ~/ cols); // Ceiling division

          left = sidePadding +
              col * cellWidth +
              _random.nextDouble() *
                  (cellWidth - size).clamp(0, cellWidth - size);
          top = topUiHeight +
              topPadding +
              row * cellHeight +
              _random.nextDouble() *
                  (cellHeight - size).clamp(0, cellHeight - size);
        }

        // Final safety check to ensure bubble is within screen bounds
        left = left.clamp(sidePadding, screenWidth - size - sidePadding);
        top = top.clamp(
            topUiHeight + topPadding, screenHeight - size - bottomPadding);

        bubbles.add(_Bubble(
          key: UniqueKey(),
          number: number,
          left: left,
          top: top,
          size: size,
          duration: Duration(milliseconds: 3500 + _random.nextInt(2000)),
        ));
      }

      setState(() {
        _bubbles = bubbles;
      });
    });
  }

  void _popBubble(_Bubble bubble) {
    if (_gameOver || _showGetReady) return;
    if (bubble.number == _targetNumber) {
      // Correct bubble popped
      HapticFeedback.lightImpact(); // Success haptic
      setState(() {
        _score++;
        _scoreEffect = '+1';
        _scoreShake = true;
        _bubbles.remove(bubble);
        if (_bubbles.where((b) => b.number == _targetNumber).isEmpty) {
          Future.delayed(const Duration(milliseconds: 500), _nextRound);
        }
      });
      Future.delayed(const Duration(milliseconds: 350), () {
        setState(() {
          _scoreShake = false;
          _scoreEffect = null;
        });
      });
    } else {
      // Wrong bubble popped
      HapticFeedback.mediumImpact(); // Error haptic
      setState(() {
        _score = _score > 0 ? _score - 1 : 0;
        _scoreEffect = '-1';
        _scoreShake = true;
        _bubbles.remove(bubble);
      });
      Future.delayed(const Duration(milliseconds: 350), () {
        setState(() {
          _scoreShake = false;
          _scoreEffect = null;
        });
      });
    }
  }

  void _bubbleDisappeared(_Bubble bubble) {
    if (_gameOver || _showGetReady) return;
    setState(() {
      _bubbles.remove(bubble);
      if (_bubbles.isEmpty) {
        Future.delayed(const Duration(milliseconds: 300), _nextRound);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gameOver) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8FD6FF), Color(0xFFFFF3E0)],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Responsive sizing based on available space
                final isCompact =
                    constraints.maxHeight < 600 || _isPhoneLandscape;
                final emojiSize = isCompact ? 50.0 : 80.0;
                final titleSize = isCompact ? 32.0 : 48.0;
                final scoreSize = isCompact ? 24.0 : 36.0;
                final buttonTextSize = isCompact ? 20.0 : 28.0;
                final buttonPadding = isCompact
                    ? const EdgeInsets.symmetric(horizontal: 32, vertical: 12)
                    : const EdgeInsets.symmetric(horizontal: 44, vertical: 18);
                final spacing1 = isCompact ? 12.0 : 24.0;
                final spacing2 = isCompact ? 8.0 : 18.0;
                final spacing3 = isCompact ? 16.0 : 32.0;
                final spacing4 = isCompact ? 8.0 : 16.0;

                return Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _score >= 20
                              ? '🏆'
                              : _score >= 10
                                  ? '🎉'
                                  : '👏',
                          style: TextStyle(fontSize: emojiSize),
                        ),
                        SizedBox(height: spacing1),
                        Text(
                          'Time\'s Up!',
                          style: TextStyle(
                            fontFamily: 'Baloo2',
                            fontSize: titleSize,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF8E6CFF),
                          ),
                        ),
                        SizedBox(height: spacing2),
                        Text(
                          'Your Score: $_score',
                          style: TextStyle(
                            fontFamily: 'Baloo2',
                            fontSize: scoreSize,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFF9F43),
                          ),
                        ),
                        SizedBox(height: spacing3),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8E6CFF),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(isCompact ? 20 : 28)),
                            padding: buttonPadding,
                          ),
                          onPressed: () {
                            setState(() {
                              _startGame();
                            });
                          },
                          child: Text(
                            'Play Again',
                            style: TextStyle(
                              fontFamily: 'Baloo2',
                              fontSize: buttonTextSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(height: spacing4),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(isCompact ? 20 : 28)),
                            side: const BorderSide(
                                color: Color(0xFFFF9F43), width: 2),
                            padding: buttonPadding,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Return',
                            style: TextStyle(
                              fontFamily: 'Baloo2',
                              fontSize: buttonTextSize,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFFF9F43),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8FD6FF), Color(0xFFFFF3E0)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Top row: Back button, timer, score
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back button
                        Padding(
                          padding: const EdgeInsets.only(left: 12.0),
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Color(0xFF8E6CFF),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x338E6CFF),
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(Icons.arrow_back_rounded,
                                    color: Colors.white, size: 28),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Timer (centered)
                        Expanded(
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 44,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: _timeLeft <= 10
                                    ? Colors.red.shade600
                                    : const Color(0xFF8E6CFF),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                    color: _timeLeft <= 10
                                        ? Colors.red.shade300
                                        : const Color(0xFFFF9F43),
                                    width: _timeLeft <= 5 ? 3 : 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: _timeLeft <= 10
                                        ? Colors.red.withValues(alpha: 0.4)
                                        : const Color(0x338E6CFF),
                                    blurRadius: _timeLeft <= 5 ? 12 : 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.timer,
                                      color: Colors.white, size: 28),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$_timeLeft s',
                                    style: const TextStyle(
                                      fontFamily: 'Baloo2',
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Score (star)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            transform: _scoreShake
                                ? Matrix4.translationValues(-8, 0, 0)
                                : Matrix4.identity(),
                            curve: Curves.elasticIn,
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                  color: const Color(0xFFFF9F43), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withValues(alpha: 0.13),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star,
                                    color: const Color(0xFFFFC107), size: 28),
                                const SizedBox(width: 6),
                                Text(
                                  '$_score',
                                  style: const TextStyle(
                                    fontFamily: 'Baloo2',
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF9F43),
                                  ),
                                ),
                                if (_scoreEffect != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6.0),
                                    child: Text(
                                      _scoreEffect!,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: _scoreEffect == '+1'
                                            ? Colors.green
                                            : Colors.red,
                                        fontFamily: 'Baloo2',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Target badge under timer
                  Positioned(
                    top: 65,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal:
                                _isPhoneLandscape ? 12 : (_isTablet ? 32 : 16),
                            vertical:
                                _isPhoneLandscape ? 6 : (_isTablet ? 18 : 8)),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9C4),
                          borderRadius: BorderRadius.circular(
                              _isPhoneLandscape ? 12 : 16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.yellow.withValues(alpha: 0.18),
                              blurRadius: _isPhoneLandscape ? 12 : 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                              color: const Color(0xFFFF9F43),
                              width: _isPhoneLandscape ? 3 : 4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🎯',
                                style: TextStyle(
                                    fontSize: _isPhoneLandscape
                                        ? 16
                                        : (_isTablet ? 38 : 22))),
                            SizedBox(
                                width: _isPhoneLandscape
                                    ? 6
                                    : (_isTablet ? 16 : 8)),
                            Text(
                              'Pop all the',
                              style: TextStyle(
                                fontFamily: 'Baloo2',
                                fontSize: _isPhoneLandscape
                                    ? 12
                                    : (_isTablet ? 24 : 14),
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                            SizedBox(
                                width: _isPhoneLandscape
                                    ? 4
                                    : (_isTablet ? 12 : 6)),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: _isPhoneLandscape
                                      ? 6
                                      : (_isTablet ? 18 : 8),
                                  vertical: _isPhoneLandscape
                                      ? 3
                                      : (_isTablet ? 8 : 4)),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9F43),
                                borderRadius: BorderRadius.circular(
                                    _isPhoneLandscape ? 12 : 18),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.orange.withValues(alpha: 0.18),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                '$_targetNumber',
                                style: TextStyle(
                                  fontFamily: 'Baloo2',
                                  fontSize: _isPhoneLandscape
                                      ? 18
                                      : (_isTablet ? 38 : 22),
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: _isPhoneLandscape ? 1 : 2,
                                  shadows: [
                                    const Shadow(
                                        blurRadius: 4, color: Colors.black26)
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(
                                width: _isPhoneLandscape
                                    ? 4
                                    : (_isTablet ? 12 : 6)),
                            Text('!',
                                style: TextStyle(
                                    fontSize: _isPhoneLandscape
                                        ? 16
                                        : (_isTablet ? 38 : 22),
                                    color: const Color(0xFFFF9F43),
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Get Ready animation
                  if (_showGetReady)
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal:
                                _isPhoneLandscape ? 16 : (_isTablet ? 36 : 18),
                            vertical:
                                _isPhoneLandscape ? 8 : (_isTablet ? 24 : 12)),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(
                              _isPhoneLandscape ? 20 : 32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: _isPhoneLandscape ? 8 : 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          'Get Ready!',
                          style: TextStyle(
                            fontFamily: 'Baloo2',
                            fontSize:
                                _isPhoneLandscape ? 22 : (_isTablet ? 44 : 28),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8E6CFF),
                            letterSpacing: _isPhoneLandscape ? 0.8 : 1.2,
                          ),
                        ),
                      ),
                    ),

                  // Bubbles
                  ..._bubbles.map((bubble) => _AnimatedBubble(
                        key: bubble.key,
                        bubble: bubble,
                        onPop: () => _popBubble(bubble),
                        onDisappear: () => _bubbleDisappeared(bubble),
                      )),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Bubble {
  final Key key;
  final int number;
  final double left;
  final double top;
  final double size;
  final Duration duration;
  _Bubble(
      {required this.key,
      required this.number,
      required this.left,
      required this.top,
      required this.size,
      required this.duration});
}

class _AnimatedBubble extends StatefulWidget {
  final _Bubble bubble;
  final VoidCallback onPop;
  final VoidCallback onDisappear;
  const _AnimatedBubble(
      {required Key key,
      required this.bubble,
      required this.onPop,
      required this.onDisappear})
      : super(key: key);

  @override
  State<_AnimatedBubble> createState() => _AnimatedBubbleState();
}

class _AnimatedBubbleState extends State<_AnimatedBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: widget.bubble.duration);
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(_controller);
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_popped) {
        setState(() {
          _popped = true;
        });
        widget.onDisappear();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_popped) return const SizedBox.shrink();

    // Cache the bubble content to avoid rebuilding on every animation frame
    final bubbleContent = Container(
      width: widget.bubble.size,
      height: widget.bubble.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.primaries[widget.bubble.number % Colors.primaries.length]
            .withValues(alpha: 0.85),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          widget.bubble.number.toString(),
          style: TextStyle(
            fontFamily: 'Baloo2',
            fontSize: widget.bubble.size * 0.45,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black26)],
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _controller,
      child: bubbleContent, // Pass as child to avoid rebuilding
      builder: (context, child) {
        final screenHeight = MediaQuery.of(context).size.height;
        final top = widget.bubble.top +
            (screenHeight - widget.bubble.top - widget.bubble.size) *
                (1.0 - _animation.value);

        return Positioned(
          left: widget.bubble.left,
          top: top,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _popped = true;
              });
              widget.onPop();
            },
            child: AnimatedScale(
              scale: _popped ? 0.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Opacity(
                opacity: _popped ? 0.0 : 1.0,
                child: child!, // Use the cached child
              ),
            ),
          ),
        );
      },
    );
  }
}
