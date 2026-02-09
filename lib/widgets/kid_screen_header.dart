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
    final hasHome = onHome != null;
    final hasBack = onBack != null;
    // Shrink side slots on phones to give the title more room
    final double leftSlotWidth;
    if (isTablet) {
      leftSlotWidth = 128.0;
    } else if (hasBack && hasHome) {
      leftSlotWidth = 100.0;
    } else {
      leftSlotWidth = 56.0;
    }
    final rightSlotWidth = isTablet ? 128.0 : (trailing != null ? 56.0 : leftSlotWidth);

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
                if (hasBack)
                  _HeaderCircleButton(
                    icon: Icons.arrow_back_rounded,
                    size: buttonSize,
                    color: const Color(0xFF8E6CFF),
                    onTap: onBack!,
                    semanticsLabel: 'Back',
                  ),
                if (hasBack && hasHome)
                  SizedBox(width: isTablet ? 8.0 : 6.0),
                if (hasHome)
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
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: isTablet ? 32.0 : 26.0,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF8E6CFF),
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          SizedBox(
            width: rightSlotWidth,
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
