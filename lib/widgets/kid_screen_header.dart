import 'package:flutter/material.dart';

class KidScreenHeader extends StatelessWidget {
  final String title;
  final bool isTablet;
  final VoidCallback? onBack;
  final VoidCallback? onHome;
  final Widget? trailing;

  const KidScreenHeader({
    super.key,
    required this.title,
    required this.isTablet,
    this.onBack,
    this.onHome,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final edgePadding = isTablet ? 16.0 : 12.0;
    final buttonSize = isTablet ? 50.0 : 44.0;
    final leftSlotWidth = isTablet ? 128.0 : 112.0;

    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: edgePadding, vertical: edgePadding),
      child: Row(
        children: [
          SizedBox(
            width: leftSlotWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (onBack != null)
                  _HeaderCircleButton(
                    icon: Icons.arrow_back_rounded,
                    size: buttonSize,
                    color: const Color(0xFF8E6CFF),
                    onTap: onBack!,
                    semanticsLabel: 'Back',
                  ),
                if (onBack != null && onHome != null)
                  SizedBox(width: isTablet ? 8.0 : 6.0),
                if (onHome != null)
                  _HeaderCircleButton(
                    icon: Icons.home_rounded,
                    size: buttonSize,
                    color: const Color(0xFF43C465),
                    onTap: onHome!,
                    semanticsLabel: 'Home',
                  ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: isTablet ? 32.0 : 28.0,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF8E6CFF),
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          SizedBox(
            width: leftSlotWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: trailing ?? const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback onTap;
  final String semanticsLabel;

  const _HeaderCircleButton({
    required this.icon,
    required this.size,
    required this.color,
    required this.onTap,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Tooltip(
        message: semanticsLabel,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: onTap,
            radius: size * 0.7,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.32),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: size * 0.52,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
