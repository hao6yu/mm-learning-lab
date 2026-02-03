import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class GameCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSpecial;
  final bool compactMode;

  const GameCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
    this.isSpecial = false,
    this.compactMode = false,
  });

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Determine layout based on compact mode
    final double iconSize = widget.compactMode ? 40 : 50;
    final double iconInnerSize = widget.compactMode ? 20 : 24;
    final double titleFontSize = widget.compactMode ? 14 : 15;
    final double subtitleFontSize = widget.compactMode ? 9 : 10;
    final double contentPadding = widget.compactMode ? 6.0 : 10.0;

    return Card(
      elevation: _isHovered ? 4 : 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: widget.isSpecial ? BorderSide(color: widget.color.withOpacity(0.4), width: 1) : BorderSide.none,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: widget.onTap,
            onHover: (hover) {
              if (mounted) {
                setState(() => _isHovered = hover);
              }
            },
            child: Stack(
              children: [
                // Main content - use compactMode to choose layout type
                widget.compactMode
                    ? _buildCompactLayout(
                        iconSize: iconSize,
                        iconInnerSize: iconInnerSize,
                        titleFontSize: titleFontSize,
                        subtitleFontSize: subtitleFontSize,
                        contentPadding: contentPadding,
                      )
                    : _buildRegularLayout(
                        iconSize: iconSize,
                        iconInnerSize: iconInnerSize,
                        titleFontSize: titleFontSize,
                        subtitleFontSize: subtitleFontSize,
                        contentPadding: contentPadding,
                      ),

                // Special badge if isSpecial is true
                if (widget.isSpecial)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 6,
                          ),
                          SizedBox(width: 2),
                          Text(
                            'AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Compact layout for phone screens (horizontal arrangement)
  Widget _buildCompactLayout({
    required double iconSize,
    required double iconInnerSize,
    required double titleFontSize,
    required double subtitleFontSize,
    required double contentPadding,
  }) {
    return Padding(
      padding: EdgeInsets.all(contentPadding),
      child: Row(
        children: [
          // Icon container with animation
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(_isHovered ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              widget.icon,
              color: widget.color,
              size: iconInnerSize,
            ),
          ),
          SizedBox(width: 8),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3436),
                  ),
                ),
                // Subtitle if provided
                if (widget.subtitle != null) ...[
                  SizedBox(height: 1),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(
                      fontSize: subtitleFontSize,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Regular layout for tablet screens (vertical arrangement)
  Widget _buildRegularLayout({
    required double iconSize,
    required double iconInnerSize,
    required double titleFontSize,
    required double subtitleFontSize,
    required double contentPadding,
  }) {
    return Padding(
      padding: EdgeInsets.all(contentPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon container with animation
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(_isHovered ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.icon,
              color: widget.color,
              size: iconInnerSize,
            ),
          ),
          SizedBox(height: 6),
          // Title
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3436),
            ),
          ),
          // Subtitle if provided
          if (widget.subtitle != null) ...[
            SizedBox(height: 1),
            Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: subtitleFontSize,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
