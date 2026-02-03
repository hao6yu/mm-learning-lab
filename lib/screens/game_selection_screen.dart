import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service.dart';

class GameSelectionScreen extends StatefulWidget {
  const GameSelectionScreen({super.key});

  @override
  State<GameSelectionScreen> createState() => _GameSelectionScreenState();
}

class _GameSelectionScreenState extends State<GameSelectionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8FD6FF), Color(0xFFFFF3E0)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(isTablet),

              // Game cards with responsive layout
              Expanded(
                child: _buildGameGrid(isLandscape, isTablet),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isTablet) {
    final headerPadding = 12.0;
    final buttonSize = isTablet ? 16.0 : 14.0;
    final titleSize = isTablet ? 32.0 : 28.0;

    return Padding(
      padding: EdgeInsets.all(headerPadding),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF8E6CFF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x338E6CFF),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.all(buttonSize),
              child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: isTablet ? 28.0 : 24.0),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Learning Games',
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: titleSize,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF8E6CFF),
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          SizedBox(width: isTablet ? 56.0 : 48.0), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildGameGrid(bool isLandscape, bool isTablet) {
    final games = [
      _GameData(
        title: 'AI Story Time',
        color: const Color(0xFF8E6CFF),
        icon: CupertinoIcons.wand_stars,
        isNew: true,
        onTap: () => Navigator.pushNamed(context, '/story-adventure'),
      ),
      _GameData(
        title: 'Talk with AI',
        color: const Color(0xFF3ED6C1),
        icon: CupertinoIcons.chat_bubble_fill,
        isNew: true,
        onTap: () => Navigator.pushNamed(context, '/ai-chat'),
      ),
      _GameData(
        title: 'Letter Tracing',
        color: const Color(0xFFFF9F43),
        icon: CupertinoIcons.pencil,
        onTap: () => Navigator.pushNamed(context, '/tracing'),
      ),
      _GameData(
        title: 'Bubble Pop',
        color: const Color(0xFF3ED6C1),
        icon: CupertinoIcons.circle_grid_3x3,
        onTap: () => Navigator.pushNamed(context, '/bubble-pop'),
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32.0 : 20.0,
        vertical: isTablet ? 16.0 : 8.0,
      ),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return isLandscape ? _buildLandscapeGrid(games, isTablet) : _buildPortraitGrid(context, games, isTablet);
        },
      ),
    );
  }

  Widget _buildLandscapeGrid(List<_GameData> games, bool isTablet) {
    // Landscape: Use 3 columns to fit more games nicely (future-proof for 5+ games)
    final crossAxisCount = games.length <= 4 ? 2 : 3;
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: isTablet ? 20.0 : 12.0,
        mainAxisSpacing: isTablet ? 20.0 : 12.0,
        childAspectRatio: crossAxisCount == 2 ? (isTablet ? 2.8 : 2.5) : (isTablet ? 2.2 : 2.0),
      ),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        return _buildAnimatedCard(
          index,
          _GameCard(
            title: game.title,
            color: game.color,
            icon: game.icon,
            isNew: game.isNew,
            onTap: game.onTap,
            isTablet: isTablet,
            isLandscape: true,
          ),
        );
      },
    );
  }

  Widget _buildPortraitGrid(BuildContext context, List<_GameData> games, bool isTablet) {
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = screenHeight - 200; // Account for header and padding
    final cardHeight = (availableHeight / games.length) - (isTablet ? 16.0 : 12.0); // Dynamic based on game count

    return SingleChildScrollView(
      child: Column(
        children: games.asMap().entries.map((entry) {
          final index = entry.key;
          final game = entry.value;
          final isLast = index == games.length - 1;

          return Container(
            height: cardHeight.clamp(isTablet ? 80.0 : 70.0, isTablet ? 120.0 : 100.0),
            margin: EdgeInsets.only(
              bottom: isLast ? 0 : (isTablet ? 16.0 : 12.0),
            ),
            child: _buildAnimatedCard(
              index,
              _GameCard(
                title: game.title,
                color: game.color,
                icon: game.icon,
                isNew: game.isNew,
                onTap: game.onTap,
                isTablet: isTablet,
                isLandscape: false,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnimatedCard(int index, Widget child) {
    final delay = index * 0.2;
    final start = delay;
    final end = (start + 0.6).clamp(0.0, 1.0);
    final fadeInInterval = Interval(start, end, curve: Curves.easeOutBack);

    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: fadeInInterval,
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: fadeInInterval,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _GameData {
  final String title;
  final Color color;
  final IconData icon;
  final bool isNew;
  final VoidCallback onTap;

  _GameData({
    required this.title,
    required this.color,
    required this.icon,
    required this.onTap,
    this.isNew = false,
  });
}

class _GameCard extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final bool isNew;
  final bool isTablet;
  final bool isLandscape;

  const _GameCard({
    required this.title,
    required this.color,
    required this.icon,
    required this.onTap,
    required this.isTablet,
    required this.isLandscape,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    // More compact sizing for better fit
    final verticalPadding = isLandscape ? (isTablet ? 16.0 : 12.0) : (isTablet ? 20.0 : 16.0);
    final horizontalPadding = isTablet ? 16.0 : 12.0;
    final borderRadius = isTablet ? 28.0 : 24.0;
    final iconSize = isLandscape ? (isTablet ? 28.0 : 24.0) : (isTablet ? 32.0 : 28.0);
    final fontSize = isLandscape ? (isTablet ? 18.0 : 16.0) : (isTablet ? 22.0 : 20.0);
    final spacing = isLandscape ? (isTablet ? 10.0 : 8.0) : (isTablet ? 16.0 : 14.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: horizontalPadding),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.18),
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
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Baloo2',
                ),
                textAlign: TextAlign.center,
                maxLines: isLandscape ? 1 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isNew) ...[
              SizedBox(width: spacing / 2),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  "NEW",
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
    );
  }
}
