import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class WordCard extends StatefulWidget {
  final String word;
  final bool isTitle;
  final FlutterTts flutterTts;
  final bool isCurrentWord;
  final VoidCallback onTap;

  const WordCard({
    super.key,
    required this.word,
    required this.isTitle,
    required this.flutterTts,
    required this.isCurrentWord,
    required this.onTap,
  });

  @override
  State<WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<WordCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _showDefinition = false;
  String? _definition;
  bool _isLoadingDefinition = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchDefinition() async {
    if (_isLoadingDefinition) return;
    setState(() {
      _isLoadingDefinition = true;
    });
    try {
      final url =
          'https://api.dictionaryapi.dev/api/v2/entries/en/${widget.word.toLowerCase()}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final definition =
            data[0]['meanings'][0]['definitions'][0]['definition'];
        setState(() {
          _definition = definition;
          _isLoadingDefinition = false;
        });
      } else {
        setState(() {
          _definition = 'No definition found.';
          _isLoadingDefinition = false;
        });
      }
    } catch (e) {
      setState(() {
        _definition = 'Error fetching definition.';
        _isLoadingDefinition = false;
      });
    }
  }

  void _handleTap() async {
    if (widget.isTitle) {
      await widget.flutterTts.stop();
      await widget.flutterTts.speak(widget.word);
    } else {
      widget.onTap();
    }
  }

  void _handleLongPress() {
    if (!widget.isTitle) {
      setState(() {
        _showDefinition = !_showDefinition;
        if (_showDefinition && _definition == null) {
          _fetchDefinition();
        }
      });
    }
  }

  // Get a color based on the word to add variety for children
  Color _getWordColor() {
    // Simple algorithm to generate a consistent color based on the first letter
    final List<Color> colors = [
      Color(0xFF8E6CFF), // Purple
      Color(0xFF4CAF50), // Green
      Color(0xFF2196F3), // Blue
      Color(0xFFFFA000), // Amber
      Color(0xFFE91E63), // Pink
      Color(0xFF00BCD4), // Cyan
      Color(0xFFFF5722), // Deep Orange
      Color(0xFF3F51B5), // Indigo
      Color(0xFF795548), // Brown
      Color(0xFF607D8B), // Blue Grey
    ];

    if (widget.word.isEmpty) return colors[0];

    // Get a consistent index based on the first letter
    final int charCode = widget.word.toLowerCase().codeUnitAt(0);
    final int colorIndex = charCode % colors.length;

    return colors[colorIndex];
  }

  @override
  Widget build(BuildContext context) {
    final bool isPunctuation = widget.word.contains(RegExp(r'[.,!?;:]'));

    // Responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    // Responsive dimensions
    final titleFontSize = isTablet ? 18.0 : 14.0;
    final wordFontSize = isTablet ? 20.0 : 16.0;
    final borderRadius = isTablet ? 10.0 : 8.0;
    final horizontalPadding =
        widget.isTitle ? (isTablet ? 10.0 : 6.0) : (isTablet ? 8.0 : 5.0);
    final verticalPadding =
        widget.isTitle ? (isTablet ? 6.0 : 3.0) : (isTablet ? 5.0 : 2.0);
    final blurRadius = isTablet ? 4.0 : 3.0;
    final shadowOffset = isTablet ? 1.5 : 1.0;

    // Use a simple widget for punctuation
    if (isPunctuation) {
      return Text(
        widget.word,
        style: TextStyle(
          fontSize: widget.isTitle ? titleFontSize : wordFontSize,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF26324A),
        ),
      );
    }

    final wordColor = _getWordColor();
    final backgroundColor =
        widget.isCurrentWord ? wordColor.withValues(alpha: 0.3) : Colors.white;

    return GestureDetector(
      onTap: _handleTap,
      onLongPress: _handleLongPress,
      onTapDown: (_) {
        _controller.forward();
        setState(() => _isHovered = true);
      },
      onTapUp: (_) {
        _controller.reverse();
        setState(() => _isHovered = false);
      },
      onTapCancel: () {
        _controller.reverse();
        setState(() => _isHovered = false);
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Stack(
          children: [
            // Main word card
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, vertical: verticalPadding),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: widget.isCurrentWord || _isHovered
                      ? wordColor
                      : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: blurRadius,
                    offset: Offset(0, shadowOffset),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Word text
                  Text(
                    widget.word,
                    style: TextStyle(
                      fontSize: widget.isTitle ? titleFontSize : wordFontSize,
                      fontWeight: FontWeight.w600,
                      color: widget.isCurrentWord
                          ? wordColor
                          : const Color(0xFF26324A),
                    ),
                  ),
                  // Show definition if available
                  if (_showDefinition && _definition != null) ...[
                    SizedBox(height: isTablet ? 6.0 : 4.0),
                    Container(
                      padding: EdgeInsets.all(isTablet ? 8.0 : 6.0),
                      decoration: BoxDecoration(
                        color: wordColor.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(isTablet ? 6.0 : 4.0),
                      ),
                      child: Text(
                        _definition!,
                        style: TextStyle(
                          fontSize: isTablet ? 12.0 : 10.0,
                          color: const Color(0xFF555555),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  // Loading indicator for definition
                  if (_showDefinition && _isLoadingDefinition) ...[
                    SizedBox(height: isTablet ? 6.0 : 4.0),
                    SizedBox(
                      width: isTablet ? 16.0 : 12.0,
                      height: isTablet ? 16.0 : 12.0,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(wordColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Tap indicator for titles
            if (widget.isTitle)
              Positioned(
                top: isTablet ? 2.0 : 1.0,
                right: isTablet ? 4.0 : 2.0,
                child: Icon(
                  Icons.volume_up,
                  size: isTablet ? 14.0 : 12.0,
                  color: wordColor.withValues(alpha: 0.7),
                ),
              ),
            // Long press indicator for words
            if (!widget.isTitle)
              Positioned(
                bottom: isTablet ? 2.0 : 1.0,
                right: isTablet ? 4.0 : 2.0,
                child: Icon(
                  Icons.info_outline,
                  size: isTablet ? 12.0 : 10.0,
                  color: wordColor.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
