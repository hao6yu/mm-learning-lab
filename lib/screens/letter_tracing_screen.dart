import 'package:flutter/material.dart';
import '../widgets/tracing_canvas.dart';

class LetterTracingScreen extends StatefulWidget {
  const LetterTracingScreen({super.key});

  @override
  State<LetterTracingScreen> createState() => _LetterTracingScreenState();
}

class _LetterTracingScreenState extends State<LetterTracingScreen> {
  int currentLetterIndex = 0;
  bool showGuide = true;
  bool animateDemo = false;
  bool isUpperCase = true;
  Key canvasKey = UniqueKey();

  static const List<String> letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'];

  void _showDemo() {
    setState(() {
      animateDemo = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        animateDemo = true;
      });
    });
  }

  void _onDemoComplete() {
    setState(() {
      animateDemo = false;
    });
  }

  void _switchLetter(int newIndex) {
    setState(() {
      currentLetterIndex = newIndex;
      canvasKey = UniqueKey(); // force TracingCanvas to reset
      animateDemo = false;
    });
  }

  void _toggleCase() {
    setState(() {
      isUpperCase = !isUpperCase;
      canvasKey = UniqueKey(); // force TracingCanvas to reset
      animateDemo = false;
    });
  }

  // Helper method to determine if we're on a small screen
  bool _isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 360;
  }

  // Helper method to get consistent button size
  double _getButtonSize(BuildContext context) {
    return _isSmallScreen(context) ? 36.0 : 42.0;
  }

  // Helper method to get consistent icon size
  double _getIconSize(BuildContext context) {
    return _isSmallScreen(context) ? 18.0 : 22.0;
  }

  // Helper method to get consistent text size
  double _getTextSize(BuildContext context) {
    return _isSmallScreen(context) ? 14.0 : 16.0;
  }

  @override
  Widget build(BuildContext context) {
    final currentLetter = isUpperCase ? letters[currentLetterIndex] : letters[currentLetterIndex].toLowerCase();
    final buttonSize = _getButtonSize(context);
    final isSmallScreen = _isSmallScreen(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8FD6FF), Color(0xFFEAF6FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8.0 : 12.0, vertical: isSmallScreen ? 8.0 : 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNavButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.pop(context),
                      isCircle: true,
                      size: buttonSize,
                    ),
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Letter Tracing',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Baloo2',
                              fontSize: isSmallScreen ? 20 : 24,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFFF6B6B),
                              letterSpacing: isSmallScreen ? 1.0 : 1.5,
                              shadows: [
                                Shadow(
                                  color: Colors.white,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                                Shadow(
                                  color: Colors.black.withOpacity(0.10),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildNavButton(
                          icon: showGuide ? Icons.visibility : Icons.visibility_off,
                          onTap: () {
                            setState(() {
                              showGuide = !showGuide;
                            });
                          },
                          isCircle: true,
                          size: buttonSize,
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 10),
                        _buildCaseToggleButton(size: buttonSize),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Center(
                  child: Text(
                    currentLetter,
                    style: const TextStyle(
                      fontSize: 150,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF8E6CFF),
                      fontFamily: 'Baloo2',
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: TracingCanvas(
                    key: canvasKey,
                    letter: currentLetter,
                    showGuide: showGuide,
                    animateDemo: animateDemo,
                    onDemoComplete: _onDemoComplete,
                    onCompleted: () {
                      // TODO: Handle completion
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: currentLetterIndex > 0
                          ? () {
                              _switchLetter(currentLetterIndex - 1);
                            }
                          : null,
                      child: Opacity(
                        opacity: currentLetterIndex > 0 ? 1.0 : 0.4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9F43),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x33FF9F43),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(18),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 32),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          canvasKey = UniqueKey();
                          animateDemo = false;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9F43),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0x33FF9F43),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(18),
                        child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 32),
                      ),
                    ),
                    GestureDetector(
                      onTap: currentLetterIndex < letters.length - 1
                          ? () {
                              _switchLetter(currentLetterIndex + 1);
                            }
                          : null,
                      child: Opacity(
                        opacity: currentLetterIndex < letters.length - 1 ? 1.0 : 0.4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9F43),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x33FF9F43),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(18),
                          child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 32),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isCircle,
    required double size,
  }) {
    final iconSize = _getIconSize(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFFF9F43),
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(size / 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0x33FF9F43),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildCaseToggleButton({required double size}) {
    final textSize = _getTextSize(context);

    return GestureDetector(
      onTap: _toggleCase,
      child: Container(
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFFF9F43),
          borderRadius: BorderRadius.circular(size / 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0x33FF9F43),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: size / 3),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'A',
                style: TextStyle(
                  fontSize: textSize,
                  fontWeight: isUpperCase ? FontWeight.bold : FontWeight.normal,
                  color: isUpperCase ? Colors.white : Colors.white70,
                  fontFamily: 'Baloo2',
                ),
              ),
              SizedBox(width: size / 10),
              Text(
                'a',
                style: TextStyle(
                  fontSize: textSize,
                  fontWeight: !isUpperCase ? FontWeight.bold : FontWeight.normal,
                  color: !isUpperCase ? Colors.white : Colors.white70,
                  fontFamily: 'Baloo2',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
