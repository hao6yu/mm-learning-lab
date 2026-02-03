import 'package:flutter/material.dart';

class LetterBubble extends StatelessWidget {
  final String letter;
  final bool isTarget;
  final VoidCallback onTap;

  const LetterBubble({
    super.key,
    required this.letter,
    required this.isTarget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          color: isTarget ? const Color(0xFFFFE066) : const Color(0xFFEAF6FF),
          shape: BoxShape.circle,
          border: Border.all(
            color: isTarget ? const Color(0xFFFFE066) : const Color(0xFFB3E0FF),
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: isTarget ? const Color(0xFFB07D00) : const Color(0xFF8E6CFF),
            ),
          ),
        ),
      ),
    );
  }
}
