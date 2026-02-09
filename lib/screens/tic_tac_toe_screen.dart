import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../services/theme_service.dart';

class TicTacToeScreen extends StatefulWidget {
  const TicTacToeScreen({super.key});

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

enum Player { x, o }

enum GameMode { twoPlayer, vsAI }

enum AIDifficulty { easy, medium, hard }

class _TicTacToeScreenState extends State<TicTacToeScreen> {
  List<Player?> board = List.filled(9, null);
  Player currentPlayer = Player.x;
  Player? winner;
  bool gameOver = false;
  GameMode mode = GameMode.vsAI;
  AIDifficulty aiDifficulty = AIDifficulty.hard;
  bool aiThinking = false;
  String? message;

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
    setState(() {
      board = List.filled(9, null);
      currentPlayer = Player.x;
      winner = null;
      gameOver = false;
      aiThinking = false;
      message = null;
    });
    if (mode == GameMode.vsAI && currentPlayer == Player.o) {
      _aiMove();
    }
  }

  void _setMode(GameMode newMode) {
    setState(() {
      mode = newMode;
    });
    _resetGame();
  }

  void _setAIDifficulty(AIDifficulty diff) {
    setState(() {
      aiDifficulty = diff;
    });
    _resetGame();
  }

  void _handleTap(int idx) async {
    if (gameOver ||
        board[idx] != null ||
        (mode == GameMode.vsAI && currentPlayer == Player.o)) {
      return;
    }
    setState(() {
      board[idx] = currentPlayer;
    });
    _checkWinner();
    if (!gameOver) {
      setState(() {
        currentPlayer = currentPlayer == Player.x ? Player.o : Player.x;
      });
      if (mode == GameMode.vsAI && currentPlayer == Player.o) {
        await Future.delayed(const Duration(milliseconds: 400));
        _aiMove();
      }
    }
  }

  void _aiMove() async {
    setState(() {
      aiThinking = true;
    });
    int move;
    switch (aiDifficulty) {
      case AIDifficulty.easy:
        move = _randomMove();
        break;
      case AIDifficulty.medium:
        move = _mediumAIMove();
        break;
      case AIDifficulty.hard:
        move = _bestMove(Player.o);
        break;
    }
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() {
      board[move] = Player.o;
      aiThinking = false;
    });
    _checkWinner();
    if (!gameOver) {
      setState(() {
        currentPlayer = Player.x;
      });
    }
  }

  int _randomMove() {
    final empty = <int>[];
    for (int i = 0; i < 9; i++) {
      if (board[i] == null) empty.add(i);
    }
    return empty[math.Random().nextInt(empty.length)];
  }

  int _mediumAIMove() {
    // Win if possible
    for (int i = 0; i < 9; i++) {
      if (board[i] == null) {
        board[i] = Player.o;
        if (_calculateWinner(board) == Player.o) {
          board[i] = null;
          return i;
        }
        board[i] = null;
      }
    }
    // Block X if possible
    for (int i = 0; i < 9; i++) {
      if (board[i] == null) {
        board[i] = Player.x;
        if (_calculateWinner(board) == Player.x) {
          board[i] = null;
          return i;
        }
        board[i] = null;
      }
    }
    // Otherwise random
    return _randomMove();
  }

  int _bestMove(Player ai) {
    int bestScore = -1000;
    int move = -1;
    for (int i = 0; i < 9; i++) {
      if (board[i] == null) {
        board[i] = ai;
        int score = _minimax(board, 0, false, ai);
        board[i] = null;
        if (score > bestScore) {
          bestScore = score;
          move = i;
        }
      }
    }
    return move;
  }

  int _minimax(List<Player?> b, int depth, bool isMax, Player ai) {
    Player? result = _calculateWinner(b);
    if (result == ai) return 10 - depth;
    if (result != null && result != ai) return depth - 10;
    if (!b.contains(null)) return 0;
    int best = isMax ? -1000 : 1000;
    for (int i = 0; i < 9; i++) {
      if (b[i] == null) {
        b[i] = isMax ? ai : (ai == Player.x ? Player.o : Player.x);
        int score = _minimax(b, depth + 1, !isMax, ai);
        b[i] = null;
        if (isMax) {
          best = math.max(score, best);
        } else {
          best = math.min(score, best);
        }
      }
    }
    return best;
  }

  void _checkWinner() {
    final win = _calculateWinner(board);
    if (win != null) {
      setState(() {
        winner = win;
        gameOver = true;
        message = win == Player.x ? 'X wins! 🎉' : 'O wins! 🎉';
      });
    } else if (!board.contains(null)) {
      setState(() {
        gameOver = true;
        message = 'It\'s a draw!';
      });
    }
  }

  Player? _calculateWinner(List<Player?> b) {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // cols
      [0, 4, 8], [2, 4, 6], // diags
    ];
    for (var line in lines) {
      if (b[line[0]] != null &&
          b[line[0]] == b[line[1]] &&
          b[line[1]] == b[line[2]]) {
        return b[line[0]];
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final themeConfig = context.watch<ThemeService>().config;

    // Enhanced device detection (same as other screens)
    final shortestSide = math.min(screenWidth, screenHeight);
    final isTablet =
        shortestSide > 600 || (shortestSide > 500 && devicePixelRatio < 2.5);
    final isLandscape = screenWidth > screenHeight;
    final isSmallPhoneLandscape =
        isLandscape && !isTablet && screenHeight < 380;

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

  // Landscape layout with two panels
  Widget _buildLandscapeLayout(bool isTablet, bool isSmallPhoneLandscape) {
    // Enhanced responsive sizing
    final horizontalPadding =
        isTablet ? 24.0 : (isSmallPhoneLandscape ? 8.0 : 12.0);
    final verticalPadding =
        isTablet ? 18.0 : (isSmallPhoneLandscape ? 6.0 : 8.0);
    final titleFontSize =
        isTablet ? 32.0 : (isSmallPhoneLandscape ? 20.0 : 24.0);
    final iconSize = isTablet ? 32.0 : (isSmallPhoneLandscape ? 20.0 : 24.0);
    final buttonFontSize =
        isTablet ? 16.0 : (isSmallPhoneLandscape ? 12.0 : 14.0);
    final messageFontSize =
        isTablet ? 28.0 : (isSmallPhoneLandscape ? 18.0 : 22.0);
    final statusFontSize =
        isTablet ? 20.0 : (isSmallPhoneLandscape ? 14.0 : 16.0);

    return Column(
      children: [
        // Top bar with title and back button
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding, vertical: verticalPadding * 0.5),
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
                  padding: EdgeInsets.all(
                      isTablet ? 12.0 : (isSmallPhoneLandscape ? 6.0 : 8.0)),
                  child: Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: iconSize * 0.7),
                ),
              ),
              const Spacer(),
              Text(
                'Tic-Tac-Toe',
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: titleFontSize * 0.9,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF8E6CFF),
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              SizedBox(
                  width:
                      isTablet ? 40.0 : (isSmallPhoneLandscape ? 20.0 : 28.0)),
            ],
          ),
        ),
        // Two-panel layout
        Expanded(
          child: Row(
            children: [
              // Left panel - Controls (compact and scrollable)
              SizedBox(
                width:
                    isTablet ? 240.0 : (isSmallPhoneLandscape ? 180.0 : 200.0),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding * 0.75,
                      vertical: verticalPadding * 0.5),
                  child: Column(
                    children: [
                      // Mode selection
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: verticalPadding * 0.75,
                            vertical: verticalPadding * 0.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius:
                              BorderRadius.circular(isTablet ? 12.0 : 8.0),
                        ),
                        child: Column(
                          children: [
                            Text('Game Mode',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: buttonFontSize * 0.9,
                                    color: const Color(0xFF8E6CFF))),
                            SizedBox(height: verticalPadding * 0.5),
                            Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ChoiceChip(
                                    label: Text('2 Players',
                                        style: TextStyle(
                                            fontFamily: 'Baloo2',
                                            fontWeight: FontWeight.bold,
                                            fontSize: buttonFontSize * 0.8)),
                                    selected: mode == GameMode.twoPlayer,
                                    onSelected: (_) =>
                                        _setMode(GameMode.twoPlayer),
                                  ),
                                ),
                                SizedBox(height: verticalPadding * 0.25),
                                SizedBox(
                                  width: double.infinity,
                                  child: ChoiceChip(
                                    label: Text('Play vs chatGPT',
                                        style: TextStyle(
                                            fontFamily: 'Baloo2',
                                            fontWeight: FontWeight.bold,
                                            fontSize: buttonFontSize * 0.8)),
                                    selected: mode == GameMode.vsAI,
                                    onSelected: (_) => _setMode(GameMode.vsAI),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (mode == GameMode.vsAI) ...[
                        SizedBox(height: verticalPadding * 0.75),
                        // AI Difficulty
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: verticalPadding * 0.75,
                              vertical: verticalPadding * 0.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius:
                                BorderRadius.circular(isTablet ? 12.0 : 8.0),
                          ),
                          child: Column(
                            children: [
                              Text('Difficulty',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: buttonFontSize * 0.9,
                                      color: const Color(0xFF8E6CFF))),
                              SizedBox(height: verticalPadding * 0.25),
                              DropdownButton<AIDifficulty>(
                                value: aiDifficulty,
                                onChanged: (v) => _setAIDifficulty(v!),
                                style: TextStyle(
                                    fontSize: buttonFontSize * 0.8,
                                    color: Colors.black),
                                isExpanded: true,
                                isDense: true,
                                items: const [
                                  DropdownMenuItem(
                                    value: AIDifficulty.easy,
                                    child: Text('Easy'),
                                  ),
                                  DropdownMenuItem(
                                    value: AIDifficulty.medium,
                                    child: Text('Medium'),
                                  ),
                                  DropdownMenuItem(
                                    value: AIDifficulty.hard,
                                    child: Text('Hard'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(height: verticalPadding * 0.75),
                      // Status messages
                      if (aiThinking)
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: verticalPadding * 0.75,
                              vertical: verticalPadding * 0.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius:
                                BorderRadius.circular(isTablet ? 12.0 : 8.0),
                          ),
                          child: Text(
                            'ChatGPT is thinking...',
                            style: TextStyle(
                                fontSize: statusFontSize * 0.8,
                                fontFamily: 'Baloo2',
                                color: const Color(0xFF8E6CFF)),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (message != null)
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: verticalPadding * 0.75,
                              vertical: verticalPadding * 0.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius:
                                BorderRadius.circular(isTablet ? 12.0 : 8.0),
                          ),
                          child: Text(
                            message!,
                            style: TextStyle(
                                fontSize: messageFontSize * 0.7,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF8E6CFF),
                                fontFamily: 'Baloo2'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (gameOver) ...[
                        SizedBox(height: verticalPadding * 0.75),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8E6CFF),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    isTablet ? 20.0 : 14.0)),
                            padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 32.0 : 20.0,
                                vertical: isTablet ? 14.0 : 10.0),
                          ),
                          onPressed: _resetGame,
                          child: Text('Play Again',
                              style: TextStyle(
                                  fontSize: buttonFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Baloo2')),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Right panel - Game board (use all available space)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate optimal board size using all available space
                    final availableWidth =
                        constraints.maxWidth - (horizontalPadding);
                    final availableHeight =
                        constraints.maxHeight - (verticalPadding);
                    final optimalBoardSize =
                        math.min(availableWidth, availableHeight).clamp(
                              isTablet
                                  ? 280.0
                                  : (isSmallPhoneLandscape ? 200.0 : 240.0),
                              isTablet
                                  ? 480.0
                                  : (isSmallPhoneLandscape ? 320.0 : 400.0),
                            );

                    return Container(
                      padding: EdgeInsets.all(horizontalPadding * 0.5),
                      child: Center(
                        child: Container(
                          width: optimalBoardSize,
                          height: optimalBoardSize,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1), // pastel yellow
                            borderRadius: BorderRadius.circular(isTablet
                                ? 40.0
                                : (isSmallPhoneLandscape ? 20.0 : 30.0)),
                            border: Border.all(
                                color: const Color(0xFFFFD180),
                                width: isTablet
                                    ? 6.0
                                    : (isSmallPhoneLandscape ? 3.0 : 4.0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.10),
                                blurRadius: isTablet
                                    ? 18.0
                                    : (isSmallPhoneLandscape ? 8.0 : 12.0),
                                offset: Offset(
                                    0,
                                    isTablet
                                        ? 6.0
                                        : (isSmallPhoneLandscape ? 3.0 : 4.0)),
                              ),
                            ],
                          ),
                          child: GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: isTablet
                                  ? 12.0
                                  : (isSmallPhoneLandscape ? 6.0 : 8.0),
                              mainAxisSpacing: isTablet
                                  ? 12.0
                                  : (isSmallPhoneLandscape ? 6.0 : 8.0),
                              childAspectRatio: 1.0,
                            ),
                            itemCount: 9,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.all(isTablet
                                ? 24.0
                                : (isSmallPhoneLandscape ? 12.0 : 16.0)),
                            itemBuilder: (context, idx) {
                              return GestureDetector(
                                onTap: () => _handleTap(idx),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: board[idx] == null
                                        ? const Color(0xFFFFF3E0)
                                        : (board[idx] == Player.x
                                            ? const Color(0xFFD1C4E9)
                                            : const Color(0xFFFFECB3)),
                                    borderRadius: BorderRadius.circular(isTablet
                                        ? 28.0
                                        : (isSmallPhoneLandscape
                                            ? 14.0
                                            : 20.0)),
                                    border: Border.all(
                                        color: Colors.deepOrange.shade100,
                                        width: isTablet
                                            ? 3.0
                                            : (isSmallPhoneLandscape
                                                ? 2.0
                                                : 2.5)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orange
                                            .withValues(alpha: 0.10),
                                        blurRadius: isTablet
                                            ? 8.0
                                            : (isSmallPhoneLandscape
                                                ? 4.0
                                                : 6.0),
                                        offset: Offset(0, isTablet ? 2.0 : 1.5),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: board[idx] == null
                                        ? const SizedBox.shrink()
                                        : FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                // White stroke for contrast
                                                Text(
                                                  board[idx] == Player.x
                                                      ? 'X'
                                                      : 'O',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize:
                                                        optimalBoardSize / 4.2,
                                                    fontWeight: FontWeight.w900,
                                                    fontFamily: 'Baloo2',
                                                    foreground: Paint()
                                                      ..style =
                                                          PaintingStyle.stroke
                                                      ..strokeWidth = isTablet
                                                          ? 8.0
                                                          : (isSmallPhoneLandscape
                                                              ? 4.0
                                                              : 6.0)
                                                      ..color = Colors.white,
                                                    height: 1.0,
                                                  ),
                                                ),
                                                // Colored fill
                                                Text(
                                                  board[idx] == Player.x
                                                      ? 'X'
                                                      : 'O',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize:
                                                        optimalBoardSize / 4.2,
                                                    fontWeight: FontWeight.w900,
                                                    fontFamily: 'Baloo2',
                                                    color:
                                                        board[idx] == Player.x
                                                            ? const Color(
                                                                0xFF7C4DFF)
                                                            : const Color(
                                                                0xFFFFB300),
                                                    height: 1.0,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Portrait layout (original single-column layout)
  Widget _buildPortraitLayout(bool isTablet) {
    // Enhanced responsive sizing for portrait
    final verticalPadding = isTablet ? 18.0 : 12.0;
    final horizontalPadding = isTablet ? 12.0 : 8.0;
    final titleFontSize = isTablet ? 32.0 : 28.0;
    final iconSize = isTablet ? 32.0 : 28.0;
    final buttonFontSize = isTablet ? 16.0 : 14.0;
    final messageFontSize = isTablet ? 28.0 : 24.0;
    final statusFontSize = isTablet ? 20.0 : 18.0;

    return Column(
      children: [
        SizedBox(height: verticalPadding),
        Row(
          children: [
            SizedBox(width: horizontalPadding),
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
                padding: EdgeInsets.all(isTablet ? 14.0 : 12.0),
                child: Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: iconSize),
              ),
            ),
            const Spacer(),
            Text(
              'Tic-Tac-Toe',
              style: TextStyle(
                fontFamily: 'Baloo2',
                fontSize: titleFontSize,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF8E6CFF),
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            SizedBox(width: isTablet ? 48.0 : 40.0),
          ],
        ),
        SizedBox(height: verticalPadding),
        // Mode and AI selection
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              label: Text('2 Players',
                  style: TextStyle(
                      fontFamily: 'Baloo2',
                      fontWeight: FontWeight.bold,
                      fontSize: buttonFontSize)),
              selected: mode == GameMode.twoPlayer,
              onSelected: (_) => _setMode(GameMode.twoPlayer),
            ),
            SizedBox(width: isTablet ? 16.0 : 12.0),
            ChoiceChip(
              label: Text('Play vs chatGPT',
                  style: TextStyle(
                      fontFamily: 'Baloo2',
                      fontWeight: FontWeight.bold,
                      fontSize: buttonFontSize)),
              selected: mode == GameMode.vsAI,
              onSelected: (_) => _setMode(GameMode.vsAI),
            ),
            if (mode == GameMode.vsAI) ...[
              SizedBox(width: isTablet ? 24.0 : 16.0),
              DropdownButton<AIDifficulty>(
                value: aiDifficulty,
                onChanged: (v) => _setAIDifficulty(v!),
                items: const [
                  DropdownMenuItem(
                    value: AIDifficulty.easy,
                    child: Text('Easy'),
                  ),
                  DropdownMenuItem(
                    value: AIDifficulty.medium,
                    child: Text('Medium'),
                  ),
                  DropdownMenuItem(
                    value: AIDifficulty.hard,
                    child: Text('Hard'),
                  ),
                ],
              ),
            ],
          ],
        ),
        SizedBox(height: verticalPadding),
        // Board
        LayoutBuilder(
          builder: (context, constraints) {
            final double minBoard = isTablet ? 280.0 : 240.0;
            final double maxBoard = isTablet ? 480.0 : 400.0;
            final double boardSize =
                (math.min(constraints.maxWidth, constraints.maxHeight) * 0.7)
                    .clamp(minBoard, maxBoard);
            return Center(
              child: Container(
                width: boardSize,
                height: boardSize,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1), // pastel yellow
                  borderRadius: BorderRadius.circular(isTablet ? 40.0 : 30.0),
                  border: Border.all(
                      color: const Color(0xFFFFD180),
                      width: isTablet ? 6.0 : 4.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.10),
                      blurRadius: isTablet ? 18.0 : 12.0,
                      offset: Offset(0, isTablet ? 6.0 : 4.0),
                    ),
                  ],
                ),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: isTablet ? 12.0 : 8.0,
                    mainAxisSpacing: isTablet ? 12.0 : 8.0,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: 9,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
                  itemBuilder: (context, idx) {
                    return GestureDetector(
                      onTap: () => _handleTap(idx),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: board[idx] == null
                              ? const Color(0xFFFFF3E0)
                              : (board[idx] == Player.x
                                  ? const Color(0xFFD1C4E9)
                                  : const Color(0xFFFFECB3)),
                          borderRadius:
                              BorderRadius.circular(isTablet ? 28.0 : 20.0),
                          border: Border.all(
                              color: Colors.deepOrange.shade100,
                              width: isTablet ? 3.0 : 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.10),
                              blurRadius: isTablet ? 8.0 : 6.0,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: board[idx] == null
                              ? const SizedBox.shrink()
                              : FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // White stroke for contrast
                                      Text(
                                        board[idx] == Player.x ? 'X' : 'O',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: boardSize / 4.2,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'Baloo2',
                                          foreground: Paint()
                                            ..style = PaintingStyle.stroke
                                            ..strokeWidth = isTablet ? 8.0 : 6.0
                                            ..color = Colors.white,
                                          height: 1.0,
                                        ),
                                      ),
                                      // Colored fill
                                      Text(
                                        board[idx] == Player.x ? 'X' : 'O',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: boardSize / 4.2,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'Baloo2',
                                          color: board[idx] == Player.x
                                              ? const Color(0xFF7C4DFF)
                                              : const Color(0xFFFFB300),
                                          height: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        SizedBox(height: verticalPadding),
        if (aiThinking)
          Text('ChatGPT is thinking...',
              style: TextStyle(
                  fontSize: statusFontSize,
                  fontFamily: 'Baloo2',
                  color: const Color(0xFF8E6CFF))),
        if (message != null)
          Padding(
            padding: EdgeInsets.all(isTablet ? 12.0 : 8.0),
            child: Text(
              message!,
              style: TextStyle(
                  fontSize: messageFontSize,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF8E6CFF),
                  fontFamily: 'Baloo2'),
            ),
          ),
        if (gameOver)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8E6CFF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isTablet ? 28.0 : 20.0)),
              padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 44.0 : 32.0,
                  vertical: isTablet ? 18.0 : 14.0),
            ),
            onPressed: _resetGame,
            child: Text('Play Again',
                style: TextStyle(
                    fontSize: isTablet ? 22.0 : 18.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Baloo2')),
          ),
      ],
    );
  }
}
