import 'package:flutter/material.dart';

class KidGameCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final bool isNew;
  final String? badgeLabel;
  final bool isTablet;
  final bool isLandscape;

  const KidGameCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
    required this.isTablet,
    required this.isLandscape,
    this.isNew = false,
    this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final verticalPadding =
        isLandscape ? (isTablet ? 16.0 : 12.0) : (isTablet ? 20.0 : 16.0);
    final horizontalPadding = isTablet ? 16.0 : 12.0;
    final borderRadius = isTablet ? 28.0 : 24.0;
    final iconSize =
        isLandscape ? (isTablet ? 28.0 : 24.0) : (isTablet ? 32.0 : 28.0);
    final titleFontSize =
        isLandscape ? (isTablet ? 18.0 : 16.0) : (isTablet ? 22.0 : 20.0);
    final subtitleFontSize =
        isLandscape ? (isTablet ? 12.0 : 11.0) : (isTablet ? 14.0 : 13.0);
    final spacing =
        isLandscape ? (isTablet ? 10.0 : 8.0) : (isTablet ? 16.0 : 14.0);

    return Semantics(
      button: true,
      label: 'Open $title',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: verticalPadding,
              horizontal: horizontalPadding,
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: isTablet ? 20.0 : 16.0,
                  offset: Offset(0, isTablet ? 6.0 : 4.0),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: iconSize),
                SizedBox(width: spacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Baloo2',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: subtitleFontSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.92),
                            fontFamily: 'Baloo2',
                          ),
                          maxLines: isLandscape ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (isNew || badgeLabel != null) ...[
                  SizedBox(width: spacing / 2),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      badgeLabel ?? 'NEW',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 12.0 : 10.0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
