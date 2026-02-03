import 'package:flutter/material.dart';

class ChessMazeScreen extends StatefulWidget {
  const ChessMazeScreen({super.key});

  @override
  State<ChessMazeScreen> createState() => _ChessMazeScreenState();
}

class _ChessMazeScreenState extends State<ChessMazeScreen> {
  static const int gridSize = 4;
  late List<List<String?>> board;
  int knightRow = 2;
  int knightCol = 1;
  int goalRow = 3;
  int goalCol = 3;
  List<List<bool>> stars = List.generate(gridSize, (_) => List.filled(gridSize, false));
  int moves = 0;
  int starsCollected = 0;
  bool gameWon = false;

  @override
  void initState() {
    super.initState();
    _resetBoard();
  }

  void _resetBoard() {
    board = List.generate(gridSize, (_) => List.filled(gridSize, null));
    knightRow = 2;
    knightCol = 1;
    goalRow = 3;
    goalCol = 3;
    moves = 0;
    starsCollected = 0;
    gameWon = false;
    // Place stars
    for (var row in stars) {
      row.fillRange(0, gridSize, false);
    }
    stars[0][1] = true;
    stars[1][2] = true;
    setState(() {});
  }

  bool _isValidMove(int newRow, int newCol) {
    int dr = (newRow - knightRow).abs();
    int dc = (newCol - knightCol).abs();
    return newRow >= 0 && newRow < gridSize && newCol >= 0 && newCol < gridSize && ((dr == 2 && dc == 1) || (dr == 1 && dc == 2));
  }

  void _moveKnight(int dRow, int dCol) {
    int newRow = knightRow + dRow;
    int newCol = knightCol + dCol;
    if (_isValidMove(newRow, newCol) && !gameWon) {
      setState(() {
        knightRow = newRow;
        knightCol = newCol;
        moves++;
        if (stars[knightRow][knightCol]) {
          stars[knightRow][knightCol] = false;
          starsCollected++;
        }
        if (knightRow == goalRow && knightCol == goalCol) {
          gameWon = true;
        }
      });
    }
  }

  Widget _buildCell(int row, int col) {
    Color cellColor = ((row + col) % 2 == 0) ? const Color(0xFFF3E8FF) : const Color(0xFFD1C4E9);
    Widget? child;
    if (row == knightRow && col == knightCol) {
      child = const Text('♞', style: TextStyle(fontSize: 38));
    } else if (row == goalRow && col == goalCol) {
      child = const Text('🏆', style: TextStyle(fontSize: 34));
    } else if (stars[row][col]) {
      child = const Text('⭐', style: TextStyle(fontSize: 30));
    }
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cellColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurple.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD1C4E9), Color(0xFFF3E8FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 18),
              Row(
                children: [
                  const SizedBox(width: 12),
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
                      padding: const EdgeInsets.all(14),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 32),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Chess Maze',
                    style: TextStyle(
                      fontFamily: 'Baloo2',
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF8E6CFF),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 18),
              // Board
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int row = 0; row < gridSize; row++)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int col = 0; col < gridSize; col++) SizedBox(width: 54, height: 54, child: _buildCell(row, col)),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Controls
              if (!gameWon)
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ArrowButton(icon: Icons.arrow_upward_rounded, onTap: () => _moveKnight(-2, -1)),
                        const SizedBox(width: 12),
                        _ArrowButton(icon: Icons.arrow_upward_rounded, onTap: () => _moveKnight(-2, 1)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ArrowButton(icon: Icons.arrow_back_rounded, onTap: () => _moveKnight(-1, -2)),
                        const SizedBox(width: 12),
                        _ArrowButton(icon: Icons.arrow_forward_rounded, onTap: () => _moveKnight(-1, 2)),
                        const SizedBox(width: 12),
                        _ArrowButton(icon: Icons.arrow_back_rounded, onTap: () => _moveKnight(1, -2)),
                        const SizedBox(width: 12),
                        _ArrowButton(icon: Icons.arrow_forward_rounded, onTap: () => _moveKnight(1, 2)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ArrowButton(icon: Icons.arrow_downward_rounded, onTap: () => _moveKnight(2, -1)),
                        const SizedBox(width: 12),
                        _ArrowButton(icon: Icons.arrow_downward_rounded, onTap: () => _moveKnight(2, 1)),
                      ],
                    ),
                  ],
                ),
              if (gameWon)
                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    children: [
                      const Text('🎉', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 8),
                      const Text('You reached the goal!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF8E6CFF), fontFamily: 'Baloo2')),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8E6CFF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 18),
                        ),
                        onPressed: _resetBoard,
                        child: const Text('Play Again', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Baloo2')),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Moves: $moves', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF8E6CFF), fontFamily: 'Baloo2')),
                  const SizedBox(width: 32),
                  Text('Stars: $starsCollected/2', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFF9F43), fontFamily: 'Baloo2')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFF8E6CFF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0x338E6CFF),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}
