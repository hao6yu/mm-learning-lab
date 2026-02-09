import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../services/theme_service.dart';

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key});

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

enum SudokuDifficulty { easy, medium, hard }

class _SudokuScreenState extends State<SudokuScreen> {
  // Game state
  late List<List<int>> puzzle;
  late List<List<int>> solution;
  late List<List<bool>> isFixed;
  late List<List<bool>> isError;
  SudokuDifficulty difficulty = SudokuDifficulty.easy;
  int? selectedRow;
  int? selectedCol;
  bool isCompleted = false;
  int mistakes = 0;
  int get maxMistakes {
    switch (difficulty) {
      case SudokuDifficulty.easy:
        return 5; // More forgiving for beginners
      case SudokuDifficulty.medium:
        return 4; // Slightly more forgiving
      case SudokuDifficulty.hard:
        return 3; // Keep challenging for experts
    }
  }

  @override
  void initState() {
    super.initState();
    _generateNewPuzzle();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _generateNewPuzzle() {
    // Generate a complete valid Sudoku solution
    solution = _generateCompleteSudoku();

    // Create puzzle by removing numbers based on difficulty
    puzzle = _createPuzzleFromSolution(solution, difficulty);

    // Track which cells are fixed (given) and which have errors
    isFixed =
        List.generate(9, (i) => List.generate(9, (j) => puzzle[i][j] != 0));
    isError = List.generate(9, (i) => List.generate(9, (j) => false));

    selectedRow = null;
    selectedCol = null;
    isCompleted = false;
    mistakes = 0;

    setState(() {});
  }

  List<List<int>> _generateCompleteSudoku() {
    List<List<int>> grid = List.generate(9, (i) => List.generate(9, (j) => 0));
    _fillGrid(grid);
    return grid;
  }

  bool _fillGrid(List<List<int>> grid) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (grid[row][col] == 0) {
          List<int> numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9];
          numbers.shuffle();

          for (int num in numbers) {
            if (_isValidMove(grid, row, col, num)) {
              grid[row][col] = num;
              if (_fillGrid(grid)) {
                return true;
              }
              grid[row][col] = 0;
            }
          }
          return false;
        }
      }
    }
    return true;
  }

  List<List<int>> _createPuzzleFromSolution(
      List<List<int>> solution, SudokuDifficulty difficulty) {
    List<List<int>> puzzle =
        solution.map((row) => List<int>.from(row)).toList();

    int cellsToRemove;
    switch (difficulty) {
      case SudokuDifficulty.easy:
        cellsToRemove = 35; // Remove 35 numbers (46 given)
        break;
      case SudokuDifficulty.medium:
        cellsToRemove = 45; // Remove 45 numbers (36 given)
        break;
      case SudokuDifficulty.hard:
        cellsToRemove = 55; // Remove 55 numbers (26 given)
        break;
    }

    List<List<int>> positions = [];
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        positions.add([i, j]);
      }
    }
    positions.shuffle();

    for (int i = 0; i < cellsToRemove && i < positions.length; i++) {
      int row = positions[i][0];
      int col = positions[i][1];
      puzzle[row][col] = 0;
    }

    return puzzle;
  }

  bool _isValidMove(List<List<int>> grid, int row, int col, int num) {
    // Check row
    for (int j = 0; j < 9; j++) {
      if (grid[row][j] == num) return false;
    }

    // Check column
    for (int i = 0; i < 9; i++) {
      if (grid[i][col] == num) return false;
    }

    // Check 3x3 box
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    for (int i = boxRow; i < boxRow + 3; i++) {
      for (int j = boxCol; j < boxCol + 3; j++) {
        if (grid[i][j] == num) return false;
      }
    }

    return true;
  }

  void _onCellTap(int row, int col) {
    if (isFixed[row][col] || isCompleted) return;

    // If tapping on the same selected cell that has a value, clear it
    if (selectedRow == row && selectedCol == col && puzzle[row][col] != 0) {
      setState(() {
        puzzle[row][col] = 0;
        isError[row][col] = false;
      });
      return;
    }

    setState(() {
      selectedRow = row;
      selectedCol = col;
    });
  }

  void _onNumberTap(int number) {
    if (selectedRow == null || selectedCol == null || isCompleted) return;
    if (isFixed[selectedRow!][selectedCol!]) return;

    // Clear any previous error state
    setState(() {
      isError[selectedRow!][selectedCol!] = false;
    });

    if (_isValidMove(puzzle, selectedRow!, selectedCol!, number)) {
      // Correct move
      setState(() {
        puzzle[selectedRow!][selectedCol!] = number;
      });

      // Check if puzzle is completed
      if (_isPuzzleComplete()) {
        setState(() {
          isCompleted = true;
        });
      }
    } else {
      // Invalid move
      setState(() {
        mistakes++;
        isError[selectedRow!][selectedCol!] = true;
      });

      // Check if game over due to too many mistakes
      if (mistakes >= maxMistakes) {
        // Reset after a delay
        Future.delayed(const Duration(seconds: 2), () {
          _generateNewPuzzle();
        });
      }

      // Clear error state after a delay
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            isError[selectedRow!][selectedCol!] = false;
          });
        }
      });
    }
  }

  bool _isPuzzleComplete() {
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (puzzle[i][j] == 0) return false;
      }
    }
    return true;
  }

  int _getFilledCells() {
    int count = 0;
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (puzzle[i][j] != 0) count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final isLandscape = screenSize.width > screenSize.height;
    final themeConfig = context.watch<ThemeService>().config;

    // More accurate tablet detection
    final shortestSide = screenSize.width < screenSize.height
        ? screenSize.width
        : screenSize.height;
    final isTablet =
        shortestSide > 600 || (shortestSide > 500 && devicePixelRatio < 2.5);
    final isSmallPhoneLandscape =
        isLandscape && !isTablet && screenSize.height < 380;

    // Debug print to see what's happening
    debugPrint(
        'Sudoku Screen - Width: ${screenSize.width}, Height: ${screenSize.height}, shortestSide: $shortestSide, devicePixelRatio: $devicePixelRatio, isLandscape: $isLandscape, isTablet: $isTablet');

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: themeConfig.screenGradient,
          ),
        ),
        child: SafeArea(
          child: isLandscape
              ? _buildLandscapeLayout(isTablet, isSmallPhoneLandscape)
              : _buildPortraitLayout(isTablet),
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(bool isTablet, bool isSmallPhoneLandscape) {
    return Column(
      children: [
        _buildHeader(isTablet, isSmallPhoneLandscape),
        Expanded(
          child: Row(
            children: [
              // Left panel: Expanded controls to better utilize space
              Container(
                width:
                    isTablet ? 280.0 : (isSmallPhoneLandscape ? 200.0 : 240.0),
                padding: EdgeInsets.symmetric(
                  horizontal:
                      isTablet ? 16.0 : (isSmallPhoneLandscape ? 8.0 : 12.0),
                  vertical:
                      isTablet ? 12.0 : (isSmallPhoneLandscape ? 6.0 : 8.0),
                ),
                child: _buildLandscapeControlsPanel(
                    isTablet, isSmallPhoneLandscape),
              ),
              // Right panel: Game board
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(
                      isTablet ? 12.0 : (isSmallPhoneLandscape ? 6.0 : 8.0)),
                  child: _buildGameBoard(isTablet, isSmallPhoneLandscape, true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout(bool isTablet) {
    final screenSize = MediaQuery.of(context).size;
    final hasEnoughHeightForSideBySide =
        screenSize.height > 700; // Ensure enough height for side-by-side

    if (isTablet && hasEnoughHeightForSideBySide) {
      // iPad: Use side-by-side layout for better space utilization
      return Column(
        children: [
          _buildHeader(isTablet, false),
          _buildCompactControlsBar(isTablet, false),
          Expanded(
            child: Row(
              children: [
                // Left side: Game board (takes most space)
                Expanded(
                  flex: 7,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: _buildGameBoard(isTablet, false, false),
                    ),
                  ),
                ),
                // Right side: Compact number pad
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildCompactTabletNumberPad(),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      // Phone: Keep original layout
      return Column(
        children: [
          _buildHeader(isTablet, false),
          _buildCompactControlsBar(isTablet, false),
          // Flexible content area that can scroll if needed
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Game board
                  Padding(
                    padding: EdgeInsets.all(12.0),
                    child: _buildGameBoard(isTablet, false, false),
                  ),
                  // Minimal spacing between board and number pad
                  SizedBox(height: 12.0),
                  // Number pad
                  _buildNumberPad(isTablet, false),
                  // Bottom padding
                  SizedBox(height: 16.0),
                ],
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildHeader(bool isTablet, bool isSmallPhoneLandscape) {
    final headerPadding =
        isTablet ? 20.0 : (isSmallPhoneLandscape ? 8.0 : 12.0);
    final titleSize = isTablet ? 32.0 : (isSmallPhoneLandscape ? 20.0 : 28.0);
    final iconSize = isTablet ? 24.0 : (isSmallPhoneLandscape ? 16.0 : 20.0);
    final buttonPadding = isTablet ? 12.0 : (isSmallPhoneLandscape ? 6.0 : 8.0);

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
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: EdgeInsets.all(buttonPadding),
              child: Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: iconSize),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Sudoku',
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
          GestureDetector(
            onTap: () => _showHelpDialog(),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF8E6CFF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x338E6CFF),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: EdgeInsets.all(buttonPadding),
              child:
                  Icon(Icons.help_outline, color: Colors.white, size: iconSize),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactControlsBar(bool isTablet, bool isSmallPhoneLandscape) {
    final fontSize = isTablet ? 14.0 : (isSmallPhoneLandscape ? 11.0 : 12.0);
    final padding = isTablet ? 16.0 : (isSmallPhoneLandscape ? 8.0 : 12.0);

    return Container(
      margin:
          EdgeInsets.symmetric(horizontal: padding, vertical: padding * 0.5),
      padding: EdgeInsets.all(padding * 0.75),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row: Difficulty and New Game
          Row(
            children: [
              // Difficulty chips
              Expanded(
                flex: 3,
                child: Wrap(
                  spacing: 6,
                  children: [
                    _buildDifficultyChip(
                        'Easy', SudokuDifficulty.easy, fontSize),
                    _buildDifficultyChip(
                        'Medium', SudokuDifficulty.medium, fontSize),
                    _buildDifficultyChip(
                        'Hard', SudokuDifficulty.hard, fontSize),
                  ],
                ),
              ),
              SizedBox(width: padding),
              // New Game button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF43C465),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(
                    horizontal: padding,
                    vertical: padding * 0.5,
                  ),
                  minimumSize: Size(0, 0),
                ),
                onPressed: _generateNewPuzzle,
                child: Text(
                  'New Game',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Baloo2',
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: padding * 0.5),
          // Bottom row: Progress stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('Filled', '${_getFilledCells()}/81', fontSize),
              Container(width: 1, height: 20, color: Colors.grey[300]),
              _buildStatItem('Mistakes', '$mistakes/$maxMistakes', fontSize,
                  mistakes >= maxMistakes ? Colors.red : null),
              if (isCompleted) ...[
                Container(width: 1, height: 20, color: Colors.grey[300]),
                Text(
                  '🎉 Solved! 🎉',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF43C465),
                    fontFamily: 'Baloo2',
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, double fontSize,
      [Color? valueColor]) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize * 0.8,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: valueColor ?? const Color(0xFF8E6CFF),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeControlsPanel(
      bool isTablet, bool isSmallPhoneLandscape) {
    final fontSize = isTablet ? 14.0 : (isSmallPhoneLandscape ? 10.0 : 12.0);
    final spacing = isTablet ? 12.0 : (isSmallPhoneLandscape ? 6.0 : 8.0);

    return Column(
      children: [
        // Combined difficulty and new game row
        Container(
          padding: EdgeInsets.all(spacing * 0.75),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Top row: Difficulty dropdown + New Game button
              Row(
                children: [
                  // Difficulty section (takes 65% of width)
                  Expanded(
                    flex: 13,
                    child: Row(
                      children: [
                        Text(
                          'Difficulty:',
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8E6CFF),
                          ),
                        ),
                        SizedBox(width: spacing * 0.5),
                        Expanded(
                          child: DropdownButton<SudokuDifficulty>(
                            value: difficulty,
                            onChanged: (SudokuDifficulty? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  difficulty = newValue;
                                });
                                _generateNewPuzzle();
                              }
                            },
                            style: TextStyle(
                              fontSize: fontSize,
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                            dropdownColor: Colors.white,
                            underline: Container(),
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: SudokuDifficulty.easy,
                                child: Text('Easy'),
                              ),
                              DropdownMenuItem(
                                value: SudokuDifficulty.medium,
                                child: Text('Medium'),
                              ),
                              DropdownMenuItem(
                                value: SudokuDifficulty.hard,
                                child: Text('Hard'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: spacing),
                  // New Game button (takes 35% of width)
                  Expanded(
                    flex: 7,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF43C465),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing * 0.5,
                          vertical: spacing * 0.6,
                        ),
                        minimumSize: Size(0, 0),
                      ),
                      onPressed: _generateNewPuzzle,
                      child: Text(
                        isTablet ? 'New Game' : 'New',
                        style: TextStyle(
                          fontSize: fontSize * (isTablet ? 1.0 : 0.85),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Baloo2',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing * 0.5),
              // Bottom row: Progress stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Filled',
                        style: TextStyle(
                          fontSize: fontSize * 0.8,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${_getFilledCells()}/81',
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF8E6CFF),
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 20, color: Colors.grey[300]),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Mistakes',
                        style: TextStyle(
                          fontSize: fontSize * 0.8,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '$mistakes/$maxMistakes',
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: mistakes >= maxMistakes
                              ? Colors.red
                              : const Color(0xFF8E6CFF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: spacing * 0.75),

        // Expanded number pad to fill remaining space
        Expanded(
          child:
              _buildCompactLandscapeNumberPad(isTablet, isSmallPhoneLandscape),
        ),
      ],
    );
  }

  Widget _buildDifficultyChip(
      String label, SudokuDifficulty value, double fontSize) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: fontSize * 0.8,
          fontWeight: FontWeight.bold,
          color: difficulty == value ? Colors.white : Colors.black,
        ),
      ),
      selected: difficulty == value,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            difficulty = value;
          });
          _generateNewPuzzle();
        }
      },
      selectedColor: const Color(0xFF8E6CFF),
      backgroundColor: Colors.grey[200],
    );
  }

  Widget _buildGameBoard(
      bool isTablet, bool isSmallPhoneLandscape, bool isLandscape) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSize = math.min(constraints.maxWidth, constraints.maxHeight);
        // Optimize board size for different layouts
        double boardSize;
        if (isLandscape) {
          boardSize = maxSize * (isSmallPhoneLandscape ? 0.9 : 0.85);
        } else if (isTablet) {
          // iPad portrait: Use most of available space since number pad is on the side
          boardSize = math.min(
            math.min(constraints.maxWidth * 0.95, constraints.maxHeight * 0.95),
            600.0, // Max size for readability
          );
        } else {
          // Phone portrait: use smaller percentage to leave room for number pad
          boardSize = math.min(
            constraints.maxWidth * 0.9,
            320.0,
          );
        }
        final cellSize = boardSize / 9;

        return Center(
          child: Container(
            width: boardSize,
            height: boardSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Grid lines
                CustomPaint(
                  size: Size(boardSize, boardSize),
                  painter: _SudokuGridPainter(),
                ),
                // Cells
                ...List.generate(81, (index) {
                  final row = index ~/ 9;
                  final col = index % 9;
                  return _buildCell(row, col, cellSize);
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell(int row, int col, double cellSize) {
    final isSelected = selectedRow == row && selectedCol == col;
    final hasError = isError[row][col];
    final isGiven = isFixed[row][col];
    final value = puzzle[row][col];

    return Positioned(
      left: col * cellSize,
      top: row * cellSize,
      width: cellSize,
      height: cellSize,
      child: GestureDetector(
        onTap: () => _onCellTap(row, col),
        child: Container(
          decoration: BoxDecoration(
            color: hasError
                ? Colors.red.withValues(alpha: 0.3)
                : isSelected
                    ? const Color(0xFF8E6CFF).withValues(alpha: 0.3)
                    : Colors.transparent,
          ),
          child: Center(
            child: value != 0
                ? Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: cellSize * 0.6,
                      fontWeight: isGiven ? FontWeight.bold : FontWeight.w600,
                      color: isGiven ? Colors.black : const Color(0xFF8E6CFF),
                      fontFamily: 'Baloo2',
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildLandscapeNumberPad(bool isTablet, bool isSmallPhoneLandscape) {
    final buttonSize = isTablet ? 32.0 : (isSmallPhoneLandscape ? 24.0 : 28.0);
    final fontSize = isTablet ? 16.0 : (isSmallPhoneLandscape ? 12.0 : 14.0);
    final spacing = isTablet ? 8.0 : (isSmallPhoneLandscape ? 4.0 : 6.0);

    return Container(
      padding: EdgeInsets.all(spacing * 0.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Numbers',
            style: TextStyle(
              fontSize: fontSize * 0.9,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF8E6CFF),
            ),
          ),
          SizedBox(height: spacing * 0.5),
          // Numbers 1-9 in a 3x3 grid
          ...List.generate(3, (rowIndex) {
            return Padding(
              padding: EdgeInsets.only(bottom: spacing * 0.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (colIndex) {
                  final number = rowIndex * 3 + colIndex + 1;
                  return GestureDetector(
                    onTap: () => _onNumberTap(number),
                    child: Container(
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E6CFF),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF8E6CFF).withValues(alpha: 0.3),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          number.toString(),
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Baloo2',
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCompactLandscapeNumberPad(
      bool isTablet, bool isSmallPhoneLandscape) {
    if (isTablet) {
      // iPad landscape: Better proportioned number pad
      return _buildTabletLandscapeNumberPad();
    } else {
      // Phone landscape: Keep compact design
      final fontSize = isSmallPhoneLandscape ? 14.0 : 16.0;
      final spacing = isSmallPhoneLandscape ? 5.0 : 7.0;

      return Container(
        padding: EdgeInsets.all(spacing * 0.5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              'Numbers',
              style: TextStyle(
                fontSize: fontSize * 0.9,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF8E6CFF),
              ),
            ),
            SizedBox(height: spacing * 0.5),
            // Expanded grid to fill available space
            Expanded(
              child: Column(
                children: [
                  // Numbers 1-9 in a 3x3 grid
                  ...List.generate(3, (rowIndex) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: spacing * 0.3),
                        child: Row(
                          children: List.generate(3, (colIndex) {
                            final number = rowIndex * 3 + colIndex + 1;
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: spacing * 0.2),
                                child: GestureDetector(
                                  onTap: () => _onNumberTap(number),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8E6CFF),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF8E6CFF)
                                              .withValues(alpha: 0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        number.toString(),
                                        style: TextStyle(
                                          fontSize: fontSize,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontFamily: 'Baloo2',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildTabletLandscapeNumberPad() {
    final buttonSize = 55.0;
    final fontSize = 24.0;
    final spacing = 12.0;

    return Container(
      padding: EdgeInsets.all(spacing),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Numbers',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF8E6CFF),
            ),
          ),
          SizedBox(height: spacing),
          // Numbers 1-9 in a 3x3 grid with fixed sizing for tablets
          ...List.generate(3, (rowIndex) {
            return Padding(
              padding: EdgeInsets.only(bottom: spacing * 0.8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (colIndex) {
                  final number = rowIndex * 3 + colIndex + 1;
                  return GestureDetector(
                    onTap: () => _onNumberTap(number),
                    child: Container(
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E6CFF),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF8E6CFF).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          number.toString(),
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Baloo2',
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNumberPad(bool isTablet, bool isSmallPhoneLandscape) {
    if (isTablet) {
      // iPad: Use 3x3 grid layout for better visual balance
      return _buildTabletNumberPad();
    } else {
      // Phone: Keep single row layout but with better sizing
      final buttonSize = 40.0;
      final fontSize = 20.0;
      final spacing = 6.0;

      return Container(
        padding: EdgeInsets.symmetric(horizontal: spacing),
        child: Column(
          children: [
            // Numbers 1-9
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(9, (index) {
                final number = index + 1;
                return GestureDetector(
                  onTap: () => _onNumberTap(number),
                  child: Container(
                    width: buttonSize,
                    height: buttonSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E6CFF),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8E6CFF).withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        number.toString(),
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Baloo2',
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildTabletNumberPad() {
    final buttonSize = 65.0;
    final fontSize = 28.0;
    final spacing = 16.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: spacing * 2, vertical: spacing),
      child: Column(
        children: [
          // Numbers 1-9 in a 3x3 grid for tablets
          ...List.generate(3, (rowIndex) {
            return Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (colIndex) {
                  final number = rowIndex * 3 + colIndex + 1;
                  return GestureDetector(
                    onTap: () => _onNumberTap(number),
                    child: Container(
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E6CFF),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF8E6CFF).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          number.toString(),
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Baloo2',
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCompactTabletNumberPad() {
    final buttonSize = 50.0;
    final fontSize = 22.0;
    final spacing = 12.0;

    return Container(
      padding: EdgeInsets.all(spacing),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Numbers',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF8E6CFF),
              fontFamily: 'Baloo2',
            ),
          ),
          SizedBox(height: spacing),
          // Numbers 1-9 in a compact 3x3 grid
          ...List.generate(3, (rowIndex) {
            return Padding(
              padding: EdgeInsets.only(bottom: spacing * 0.8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (colIndex) {
                  final number = rowIndex * 3 + colIndex + 1;
                  return GestureDetector(
                    onTap: () => _onNumberTap(number),
                    child: Container(
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E6CFF),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF8E6CFF).withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          number.toString(),
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Baloo2',
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFF3E8FF),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'How to Play Sudoku',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8E6CFF),
                    fontFamily: 'Baloo2',
                  ),
                ),
                const SizedBox(height: 18),
                // Sudoku grid example
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CustomPaint(
                    painter: _SudokuGridPainter(),
                    child: Center(
                      child: Text(
                        '1-9',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF8E6CFF),
                          fontFamily: 'Baloo2',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Fill the 9×9 grid so that every row, column, and 3×3 box contains the digits 1-9!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'Baloo2',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRuleItem('📋', 'Each row must contain all numbers 1-9'),
                _buildRuleItem(
                    '📋', 'Each column must contain all numbers 1-9'),
                _buildRuleItem(
                    '📦', 'Each 3×3 box must contain all numbers 1-9'),
                _buildRuleItem(
                    '🎯', 'Tap a cell to select it, then tap a number'),
                _buildRuleItem('🔄', 'Tap the same cell twice to clear it'),
                _buildRuleItem(
                    '⚠️', 'Mistake limits: Easy (5), Medium (4), Hard (3)'),
                const SizedBox(height: 18),
                const Text(
                  'Tips: Start with cells that have fewer possibilities!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Baloo2',
                    color: Color(0xFF43C465),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Good luck solving! 🧩✨',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Baloo2',
                    color: Color(0xFFFF9F43),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E6CFF),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Got it!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Baloo2',
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

  Widget _buildRuleItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontFamily: 'Baloo2',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SudokuGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1;

    final thickPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3;

    final cellSize = size.width / 9;

    // Draw grid lines
    for (int i = 0; i <= 9; i++) {
      final isThick = i % 3 == 0;
      final currentPaint = isThick ? thickPaint : paint;

      // Vertical lines
      canvas.drawLine(
        Offset(i * cellSize, 0),
        Offset(i * cellSize, size.height),
        currentPaint,
      );

      // Horizontal lines
      canvas.drawLine(
        Offset(0, i * cellSize),
        Offset(size.width, i * cellSize),
        currentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
