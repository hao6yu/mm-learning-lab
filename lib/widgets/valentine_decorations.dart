import 'dart:math';
import 'package:flutter/material.dart';

/// Floating hearts animation overlay for Valentine's theme
class FloatingHeartsOverlay extends StatefulWidget {
  final int heartCount;
  final Widget child;
  
  const FloatingHeartsOverlay({
    super.key,
    this.heartCount = 15,
    required this.child,
  });

  @override
  State<FloatingHeartsOverlay> createState() => _FloatingHeartsOverlayState();
}

class _FloatingHeartsOverlayState extends State<FloatingHeartsOverlay>
    with TickerProviderStateMixin {
  late List<_HeartData> _hearts;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _hearts = List.generate(widget.heartCount, (_) => _createHeart());
  }

  _HeartData _createHeart() {
    final controller = AnimationController(
      duration: Duration(milliseconds: 4000 + _random.nextInt(4000)),
      vsync: this,
    );
    
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.reset();
        controller.forward();
      }
    });
    
    controller.forward(from: _random.nextDouble());
    
    return _HeartData(
      controller: controller,
      startX: _random.nextDouble(),
      size: 12.0 + _random.nextDouble() * 16.0,
      opacity: 0.3 + _random.nextDouble() * 0.4,
      wobble: _random.nextDouble() * 30.0,
      emoji: _random.nextBool() ? '💕' : (_random.nextBool() ? '💖' : '💗'),
    );
  }

  @override
  void dispose() {
    for (final heart in _hearts) {
      heart.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Floating hearts layer
        Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              children: _hearts.map((heart) {
                return AnimatedBuilder(
                  animation: heart.controller,
                  builder: (context, child) {
                    final progress = heart.controller.value;
                    final screenWidth = MediaQuery.of(context).size.width;
                    final screenHeight = MediaQuery.of(context).size.height;
                    
                    // Float from bottom to top with slight wobble
                    final x = heart.startX * screenWidth + 
                        sin(progress * 3 * pi) * heart.wobble;
                    final y = screenHeight * (1 - progress);
                    
                    return Positioned(
                      left: x,
                      top: y,
                      child: Opacity(
                        opacity: heart.opacity * (1 - progress * 0.5),
                        child: Text(
                          heart.emoji,
                          style: TextStyle(fontSize: heart.size),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeartData {
  final AnimationController controller;
  final double startX;
  final double size;
  final double opacity;
  final double wobble;
  final String emoji;

  _HeartData({
    required this.controller,
    required this.startX,
    required this.size,
    required this.opacity,
    required this.wobble,
    required this.emoji,
  });
}

/// Floating sparkles overlay
class FloatingSparklesOverlay extends StatefulWidget {
  final int sparkleCount;
  final Widget child;
  
  const FloatingSparklesOverlay({
    super.key,
    this.sparkleCount = 8,
    required this.child,
  });

  @override
  State<FloatingSparklesOverlay> createState() => _FloatingSparklesOverlayState();
}

class _FloatingSparklesOverlayState extends State<FloatingSparklesOverlay>
    with TickerProviderStateMixin {
  late List<_SparkleData> _sparkles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _sparkles = List.generate(widget.sparkleCount, (_) => _createSparkle());
  }

  _SparkleData _createSparkle() {
    final controller = AnimationController(
      duration: Duration(milliseconds: 1000 + _random.nextInt(1500)),
      vsync: this,
    );
    
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        // Randomize position when restarting
        if (mounted) {
          setState(() {
            final index = _sparkles.indexWhere((s) => s.controller == controller);
            if (index >= 0) {
              _sparkles[index] = _SparkleData(
                controller: controller,
                x: _random.nextDouble(),
                y: _random.nextDouble() * 0.7, // Keep in upper 70% of screen
                size: 14.0 + _random.nextDouble() * 12.0,
                delay: _random.nextInt(500),
              );
            }
          });
        }
        Future.delayed(Duration(milliseconds: _random.nextInt(2000)), () {
          if (controller.status == AnimationStatus.dismissed) {
            controller.forward();
          }
        });
      }
    });
    
    // Start with random delay
    Future.delayed(Duration(milliseconds: _random.nextInt(2000)), () {
      if (mounted) controller.forward();
    });
    
    return _SparkleData(
      controller: controller,
      x: _random.nextDouble(),
      y: _random.nextDouble() * 0.7,
      size: 14.0 + _random.nextDouble() * 12.0,
      delay: _random.nextInt(500),
    );
  }

  @override
  void dispose() {
    for (final sparkle in _sparkles) {
      sparkle.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Sparkles layer
        Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              children: _sparkles.map((sparkle) {
                return AnimatedBuilder(
                  animation: sparkle.controller,
                  builder: (context, child) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final screenHeight = MediaQuery.of(context).size.height;
                    
                    return Positioned(
                      left: sparkle.x * screenWidth,
                      top: sparkle.y * screenHeight,
                      child: Transform.scale(
                        scale: 0.5 + sparkle.controller.value * 0.5,
                        child: Opacity(
                          opacity: sparkle.controller.value,
                          child: Text(
                            '✨',
                            style: TextStyle(fontSize: sparkle.size),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _SparkleData {
  final AnimationController controller;
  final double x;
  final double y;
  final double size;
  final int delay;

  _SparkleData({
    required this.controller,
    required this.x,
    required this.y,
    required this.size,
    required this.delay,
  });
}

/// Decorative corner hearts for cards/containers
class HeartCornerDecoration extends StatelessWidget {
  final Widget child;
  final double size;
  final Color? color;
  
  const HeartCornerDecoration({
    super.key,
    required this.child,
    this.size = 20.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: -2,
          left: -2,
          child: Text('💕', style: TextStyle(fontSize: size)),
        ),
        Positioned(
          top: -2,
          right: -2,
          child: Text('💕', style: TextStyle(fontSize: size)),
        ),
      ],
    );
  }
}

/// Sparkle effect widget
class SparkleWidget extends StatefulWidget {
  final double size;
  final Color color;
  
  const SparkleWidget({
    super.key,
    this.size = 20.0,
    this.color = const Color(0xFFFFD1DC),
  });

  @override
  State<SparkleWidget> createState() => _SparkleWidgetState();
}

class _SparkleWidgetState extends State<SparkleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Text(
            '✨',
            style: TextStyle(fontSize: widget.size),
          ),
        );
      },
    );
  }
}

/// Valentine banner widget
class ValentineBanner extends StatelessWidget {
  final String message;
  final bool isTablet;
  
  const ValentineBanner({
    super.key,
    required this.message,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24.0 : 16.0,
        vertical: isTablet ? 12.0 : 8.0,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B95), Color(0xFFFF8FAB)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B95).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('💝', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isTablet ? 16.0 : 14.0,
            ),
          ),
          const SizedBox(width: 8),
          const Text('💝', style: TextStyle(fontSize: 20)),
        ],
      ),
    );
  }
}
