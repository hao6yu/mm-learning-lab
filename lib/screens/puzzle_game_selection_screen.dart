import 'package:flutter/material.dart';
import 'chess_maze_screen.dart';
import 'memory_match_screen.dart';
import 'tic_tac_toe_screen.dart';
import 'gobang_screen.dart';
import 'chess_screen.dart';
import 'sudoku_screen.dart';

class PuzzleGameSelectionScreen extends StatelessWidget {
  const PuzzleGameSelectionScreen({super.key});

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
            colors: [Color(0xFFEAF6FF), Color(0xFFF3E8FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(context, isTablet),

              // Game cards with responsive layout
              Expanded(
                child: _buildGameGrid(context, isLandscape, isTablet),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isTablet) {
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
                'Puzzle Games',
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

  Widget _buildGameGrid(BuildContext context, bool isLandscape, bool isTablet) {
    final games = [
      _GameData(
        title: 'Sudoku',
        color: const Color(0xFFE91E63),
        icon: Icons.grid_4x4,
        route: 'sudoku',
        isNew: true,
      ),
      _GameData(
        title: 'Memory Match',
        color: const Color(0xFF43C465),
        icon: Icons.memory_rounded,
        route: 'memory_match',
      ),
      _GameData(
        title: 'Tic-Tac-Toe',
        color: const Color(0xFFFF9F43),
        icon: Icons.grid_3x3,
        route: 'tic_tac_toe',
      ),
      _GameData(
        title: 'Gobang',
        color: const Color(0xFF00B8D4),
        icon: Icons.blur_circular,
        route: 'gobang',
      ),
      _GameData(
        title: 'Chess',
        color: const Color(0xFF8E6CFF),
        icon: Icons.emoji_events,
        route: 'chess',
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32.0 : 20.0,
        vertical: isTablet ? 16.0 : 8.0,
      ),
      child: isLandscape ? _buildLandscapeGrid(games, isTablet) : _buildPortraitGrid(context, games, isTablet),
    );
  }

  Widget _buildLandscapeGrid(List<_GameData> games, bool isTablet) {
    // Landscape: Use 3 columns to fit all 5 games nicely
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: isTablet ? 20.0 : 12.0,
        mainAxisSpacing: isTablet ? 20.0 : 12.0,
        childAspectRatio: isTablet ? 2.2 : 2.0,
      ),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        return _GameCard(
          title: game.title,
          color: game.color,
          icon: game.icon,
          isNew: game.isNew,
          onTap: () => _navigateToGame(context, game.route),
          isTablet: isTablet,
          isLandscape: true,
        );
      },
    );
  }

  Widget _buildPortraitGrid(BuildContext context, List<_GameData> games, bool isTablet) {
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = screenHeight - 200; // Account for header and padding
    final cardHeight = (availableHeight / 5) - (isTablet ? 16.0 : 12.0); // Divide by 5 games with spacing

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
            child: _GameCard(
              title: game.title,
              color: game.color,
              icon: game.icon,
              isNew: game.isNew,
              onTap: () => _navigateToGame(context, game.route),
              isTablet: isTablet,
              isLandscape: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  void _navigateToGame(BuildContext context, String route) {
    switch (route) {
      case 'memory_match':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MemoryMatchScreen(),
          ),
        );
        break;
      case 'tic_tac_toe':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TicTacToeScreen(),
          ),
        );
        break;
      case 'sudoku':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SudokuScreen(),
          ),
        );
        break;
      case 'gobang':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const GobangScreen(),
          ),
        );
        break;
      case 'chess':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ChessScreen(),
          ),
        );
        break;
    }
  }
}

class _GameData {
  final String title;
  final Color color;
  final IconData icon;
  final String route;
  final bool isNew;

  _GameData({
    required this.title,
    required this.color,
    required this.icon,
    required this.route,
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
