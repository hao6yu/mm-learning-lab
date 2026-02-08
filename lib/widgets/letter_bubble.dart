import 'package:flutter/material.dart';

class LetterBubble extends StatelessWidget {
  final String letter;
  final VoidCallback onTap;
  final double size;
  final bool enabled;
  final bool isSelected;
  final bool showResult;
  final bool isCorrectTarget;
  final bool isWrongSelection;

  const LetterBubble({
    super.key,
    required this.letter,
    required this.onTap,
    this.size = 88,
    this.enabled = true,
    this.isSelected = false,
    this.showResult = false,
    this.isCorrectTarget = false,
    this.isWrongSelection = false,
  });

  @override
  Widget build(BuildContext context) {
    final state = _resolveVisualState();

    return Opacity(
      opacity: enabled ? 1.0 : 0.86,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: state.backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: state.borderColor,
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: state.shadowColor,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              letter,
              style: TextStyle(
                fontFamily: 'Baloo2',
                fontSize: size * 0.42,
                fontWeight: FontWeight.w900,
                color: state.textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  _LetterBubbleVisualState _resolveVisualState() {
    if (showResult && isCorrectTarget) {
      return const _LetterBubbleVisualState(
        backgroundColor: Color(0xFFB8F5C4),
        borderColor: Color(0xFF35A853),
        textColor: Color(0xFF1F7D3A),
        shadowColor: Color(0x5535A853),
      );
    }

    if (showResult && isWrongSelection) {
      return const _LetterBubbleVisualState(
        backgroundColor: Color(0xFFFFD3D3),
        borderColor: Color(0xFFE05A5A),
        textColor: Color(0xFFB02A2A),
        shadowColor: Color(0x55E05A5A),
      );
    }

    if (isSelected) {
      return const _LetterBubbleVisualState(
        backgroundColor: Color(0xFFFFE066),
        borderColor: Color(0xFFF9B233),
        textColor: Color(0xFF9E6C00),
        shadowColor: Color(0x55F9B233),
      );
    }

    return const _LetterBubbleVisualState(
      backgroundColor: Color(0xFFEAF6FF),
      borderColor: Color(0xFF9BD0F8),
      textColor: Color(0xFF8E6CFF),
      shadowColor: Color(0x22000000),
    );
  }
}

class _LetterBubbleVisualState {
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color shadowColor;

  const _LetterBubbleVisualState({
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.shadowColor,
  });
}
