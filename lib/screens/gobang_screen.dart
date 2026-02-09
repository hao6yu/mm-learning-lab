import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../services/elevenlabs_service.dart';
import '../services/theme_service.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class GobangScreen extends StatefulWidget {
  const GobangScreen({super.key});

  @override
  State<GobangScreen> createState() => _GobangScreenState();
}

enum GobangPlayer { p1, p2 }

enum GobangMode { twoPlayer, vsAI }

enum GobangAIDifficulty { easy, medium, hard }

class _GobangScreenState extends State<GobangScreen> {
  static const List<int> boardSizes = [10, 12, 15];
  int boardSize = 10;
  late List<List<GobangPlayer?>> board;
  GobangPlayer currentPlayer = GobangPlayer.p1;
  GobangPlayer? winner;
  bool gameOver = false;
  GobangMode mode = GobangMode.vsAI;
  GobangAIDifficulty aiDifficulty = GobangAIDifficulty.hard;
  bool aiThinking = false;
  String? message;

  // Voice and audio related variables
  final ElevenLabsService _elevenLabsService = ElevenLabsService();
  String _selectedVoiceId = '9BWtsMINqrJLrRacOk9x'; // Default voice: Aria
  bool _useVoiceCommentary = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;
  int _tempAudioCounter = 0;
  // Create a queue for pending audio messages
  final List<String> _pendingAudioMessages = [];
  bool _processingAudioQueue = false;

  // Voice personalities with more fun/cheerful settings
  final Map<String, Map<String, dynamic>> _voicePersonalities = {
    // Mary - Friendly teacher
    'mlFsujxZWlk6xPyQJgMb': {
      'style': 0.5, // Increased from 0.3 for more expressiveness
      'stability': 0.45, // Slightly decreased for more variety
      'similarity_boost': 0.75,
      'speed': 1.05, // Slightly faster
      'prefix': 'Teacher',
      'exclamations': [
        'Interesting!',
        'Let me see...',
        'Hmm...',
        'Oh!',
        'Wonderful!',
        'Great!'
      ],
    },
    // Callum - Playful buddy
    'N2lVS1w4EtoT3dr4eOWO': {
      'style': 0.7, // Increased from 0.6
      'stability': 0.35, // Decreased for more expressiveness
      'similarity_boost': 0.8,
      'speed': 1.2, // Increased from 1.15 for more energy
      'prefix': 'Coach',
      'exclamations': [
        'Awesome!',
        'Got it!',
        'Alright!',
        'Let\'s go!',
        'Sweet!',
        'Cool!'
      ],
    },
    // Aria - Enthusiastic coach
    '9BWtsMINqrJLrRacOk9x': {
      'style': 0.8, // Increased from 0.7
      'stability': 0.3,
      'similarity_boost': 0.7,
      'speed': 1.15, // Increased from 1.1
      'prefix': 'Coach',
      'exclamations': [
        'Amazing!',
        'Let\'s do this!',
        'Woo!',
        'Cool!',
        'Fantastic!',
        'Brilliant!'
      ],
    },
    // Madeline - Patient mentor
    'x7Pz9CsHMAlHFwKlPxu8': {
      'style': 0.55, // Increased from 0.4
      'stability': 0.5, // Decreased from 0.6
      'similarity_boost': 0.7,
      'speed': 1.0, // Increased from 0.95
      'prefix': 'Mentor',
      'exclamations': [
        'Wonderful!',
        'I see...',
        'Let\'s think...',
        'Interesting choice!',
        'Lovely!',
        'Delightful!'
      ],
    },
    // Haoziiiiiii - Analytical expert
    'iV5XeqzOeJzUHmdQ8FLK': {
      'style': 0.45, // Increased from 0.2
      'stability': 0.6, // Decreased from 0.7
      'similarity_boost': 0.8,
      'speed': 1.1, // Increased from 1.05
      'prefix': 'Master',
      'exclamations': [
        'Analyzing...',
        'Processing...',
        'Calculating...',
        'Interesting pattern!',
        'Fascinating!',
        'Impressive!'
      ],
    },
  };

  // List of AI thinking messages with more personality
  final List<String> _easyThinkingMessages = [
    "Hmm, where to go?",
    "Let me try this!",
    "Eeny, meeny, miny, moe...",
    "Is this good?",
    "Let's try here.",
    "This looks nice!"
  ];

  final List<String> _mediumThinkingMessages = [
    "Interesting options...",
    "Block or attack?",
    "Nice strategy!",
    "Let me think...",
    "Hmm, I see your plan.",
    "This is getting fun!"
  ];

  final List<String> _hardThinkingMessages = [
    "Calculating...",
    "I see your strategy.",
    "Analyzing the board...",
    "I need to counter that.",
    "Interesting position!",
    "Let me focus..."
  ];

  // Track used messages to avoid repetition
  final Set<String> _usedMessages = {};

  // Final short messages for game completion (2-3 sentences max)
  final List<String> _finalVictoryMessages = [
    "I win this round! Your strategy was interesting, but I found the winning move. Want to try again?",
    "Victory! You played well though. I noticed your clever moves, but I managed to create a winning sequence.",
    "Game over! I connected five! I like how you tried to block my moves, but I found an opening.",
    "That was a close one! I just managed to win. You almost had me trapped in the corner!",
    "Yay! I won! Next time, watch out for diagonal attacks - that's how I won this game!"
  ];

  final List<String> _finalDefeatMessages = [
    "You win! Well played! I tried to block your line, but you created multiple threats I couldn't defend against.",
    "Congratulations on your win! That was a clever sequence at the end. Your strategic thinking is impressive!",
    "You outplayed me! I was focused on my own line, but you were setting up that winning move all along.",
    "You got me! I didn't see that pattern forming until it was too late. Great planning!",
    "You won! The way you controlled the center of the board gave you many opportunities to attack. Good job!"
  ];

  // Final draw messages (shorter)
  final List<String> _finalDrawMessages = [
    "It's a draw! We're evenly matched. Sometimes a draw can be the most exciting result!",
    "Nobody won this time. We both had chances, but our defensive skills were too strong.",
    "Looks like a stalemate. We filled the board without either of us getting five in a row.",
    "We're tied! I thought I had a winning move several times, but you always found a way to block it.",
    "Neither of us could find the winning sequence. Games like this help us both improve!"
  ];

  // Track player's moves for pattern analysis
  List<Point<int>> playerMoves = [];
  List<Point<int>> aiMoves = [];

  // Player style detection
  bool playerIsAggressive = false;
  bool playerIsDefensive = false;
  bool playerUsesCenter = false;

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  @override
  void dispose() {
    _stopAudio();
    _audioPlayer.dispose();
    // Clear any pending messages
    _pendingAudioMessages.clear();
    _usedMessages.clear(); // Clear used messages tracking
    super.dispose();
  }

  Future<void> _stopAudio() async {
    try {
      if (_isPlayingAudio) {
        await _audioPlayer.stop();
        // Wait a moment for cleanup
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() {
          _isPlayingAudio = false;
        });
      }
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
  }

  void _resetGame() {
    // Stop any playing audio first
    _stopAudio();

    setState(() {
      board = List.generate(boardSize, (_) => List.filled(boardSize, null));
      currentPlayer = GobangPlayer.p1;
      winner = null;
      gameOver = false;
      aiThinking = false;
      message = null;
      playerMoves = [];
      aiMoves = [];
      playerIsAggressive = false;
      playerIsDefensive = false;
      playerUsesCenter = false;
      _usedMessages.clear(); // Clear used messages when starting a new game
      _pendingAudioMessages.clear();
    });
    if (mode == GobangMode.vsAI && currentPlayer == GobangPlayer.p2) {
      _aiMove();
    }
  }

  void _setMode(GobangMode newMode) {
    setState(() {
      mode = newMode;
    });
    _resetGame();
  }

  void _setAIDifficulty(GobangAIDifficulty diff) {
    setState(() {
      aiDifficulty = diff;
    });
    _resetGame();
  }

  void _setBoardSize(int size) {
    setState(() {
      boardSize = size;
    });
    _resetGame();
  }

  void _setVoiceId(String voiceId) {
    setState(() {
      _selectedVoiceId = voiceId;
    });
  }

  void _toggleVoiceCommentary(bool value) {
    setState(() {
      _useVoiceCommentary = value;
    });

    if (!_useVoiceCommentary) {
      _stopAudio();
    }
  }

  void _handleTap(int x, int y) async {
    if (gameOver ||
        board[x][y] != null ||
        (mode == GobangMode.vsAI && currentPlayer == GobangPlayer.p2)) {
      return;
    }

    setState(() {
      board[x][y] = currentPlayer;
      // Record player's move
      if (currentPlayer == GobangPlayer.p1) {
        playerMoves.add(Point(x, y));
        // Analyze player's style after a few moves
        if (playerMoves.length >= 3) {
          _analyzePlayerStyle();
        }
      }
    });

    _checkWinner(x, y);
    if (!gameOver) {
      setState(() {
        currentPlayer = currentPlayer == GobangPlayer.p1
            ? GobangPlayer.p2
            : GobangPlayer.p1;
      });
      if (mode == GobangMode.vsAI && currentPlayer == GobangPlayer.p2) {
        await Future.delayed(const Duration(milliseconds: 400));
        _aiMove();
      }
    }
  }

  void _analyzePlayerStyle() {
    final center = boardSize ~/ 2;
    int centerProximityCount = 0;
    int attackMoveCount = 0;
    int defensiveMoveCount = 0;

    // Check if player prefers center
    for (var move in playerMoves) {
      // Count moves near center
      if ((move.x - center).abs() <= 2 && (move.y - center).abs() <= 2) {
        centerProximityCount++;
      }

      // Check if player makes aggressive moves (creating sequences)
      bool isAttacking = _isAttackingMove(move.x, move.y, GobangPlayer.p1);
      if (isAttacking) attackMoveCount++;

      // Check if player makes defensive moves (blocking AI sequences)
      bool isDefending = _isDefensiveMove(move.x, move.y);
      if (isDefending) defensiveMoveCount++;
    }

    // Determine player style
    playerUsesCenter = centerProximityCount / playerMoves.length > 0.5;
    playerIsAggressive = attackMoveCount / playerMoves.length > 0.4;
    playerIsDefensive = defensiveMoveCount / playerMoves.length > 0.4;
  }

  bool _isAttackingMove(int x, int y, GobangPlayer player) {
    // Save the current board state
    GobangPlayer? originalState = board[x][y];

    // Check if this move creates a sequence of 3 or more
    board[x][y] = player;

    bool isAttacking = false;
    List<List<int>> directions = [
      [1, 0],
      [0, 1],
      [1, 1],
      [1, -1]
    ];

    for (var dir in directions) {
      int dx = dir[0], dy = dir[1];
      int count = _countConsecutive(x, y, dx, dy, player) +
          _countConsecutive(x, y, -dx, -dy, player) -
          1;

      if (count >= 3) {
        isAttacking = true;
        break;
      }
    }

    // Restore the original board state
    board[x][y] = originalState;
    return isAttacking;
  }

  bool _isDefensiveMove(int x, int y) {
    // Save the current board state
    GobangPlayer? originalState = board[x][y];

    // Check if this move blocks a potential AI winning line
    bool isDefensive = false;

    // Temporarily place AI stone to see if it would create a strong threat
    board[x][y] = GobangPlayer.p2;

    List<List<int>> directions = [
      [1, 0],
      [0, 1],
      [1, 1],
      [1, -1]
    ];
    for (var dir in directions) {
      int dx = dir[0], dy = dir[1];
      int count = _countConsecutive(x, y, dx, dy, GobangPlayer.p2) +
          _countConsecutive(x, y, -dx, -dy, GobangPlayer.p2) -
          1;

      if (count >= 3) {
        isDefensive = true;
        break;
      }
    }

    // Restore the original board state
    board[x][y] = originalState;
    return isDefensive;
  }

  void _aiMove() async {
    setState(() {
      aiThinking = true;
    });

    // Select a thinking message based on difficulty
    if (_useVoiceCommentary) {
      String message;
      List<String> messageList;

      switch (aiDifficulty) {
        case GobangAIDifficulty.easy:
          messageList = _easyThinkingMessages;
          break;
        case GobangAIDifficulty.medium:
          messageList = _mediumThinkingMessages;
          break;
        case GobangAIDifficulty.hard:
          messageList = _hardThinkingMessages;
          break;
      }

      // Get a unique message that hasn't been used recently
      message = _getUniqueMessage(messageList);

      // Add thinking message to queue
      _playAIVoiceMessage(message);

      // Don't wait for voice messages to complete, just add a small delay
      // based on difficulty to simulate thinking
      switch (aiDifficulty) {
        case GobangAIDifficulty.easy:
          await Future.delayed(const Duration(milliseconds: 200));
          break;
        case GobangAIDifficulty.medium:
          await Future.delayed(const Duration(milliseconds: 400));
          break;
        case GobangAIDifficulty.hard:
          await Future.delayed(const Duration(milliseconds: 700));
          break;
      }
    } else {
      // If no voice commentary, just add a small delay
      switch (aiDifficulty) {
        case GobangAIDifficulty.easy:
          await Future.delayed(const Duration(milliseconds: 200));
          break;
        case GobangAIDifficulty.medium:
          await Future.delayed(const Duration(milliseconds: 400));
          break;
        case GobangAIDifficulty.hard:
          await Future.delayed(const Duration(milliseconds: 700));
          break;
      }
    }

    late Point<int> move;
    switch (aiDifficulty) {
      case GobangAIDifficulty.easy:
        move = _easyAIMove();
        break;
      case GobangAIDifficulty.medium:
        move = _mediumAIMove();
        break;
      case GobangAIDifficulty.hard:
        move = _adaptiveAIMove();
        break;
    }

    // Make the move and hide the AI thinking popup immediately
    // even if voice is still playing
    setState(() {
      board[move.x][move.y] = GobangPlayer.p2;
      aiMoves.add(move);
      aiThinking = false;
    });

    _checkWinner(move.x, move.y);
    if (!gameOver) {
      setState(() {
        currentPlayer = GobangPlayer.p1;
      });
    }
  }

  Future<void> _playAIVoiceMessage(String textToSpeak) async {
    if (!_useVoiceCommentary) return;

    // Add message to the queue
    _pendingAudioMessages.add(textToSpeak);

    // Start processing the queue if not already doing so
    if (!_processingAudioQueue) {
      _processAudioQueue();
    }
  }

  // New method to process audio messages in sequence
  Future<void> _processAudioQueue() async {
    if (_pendingAudioMessages.isEmpty) {
      _processingAudioQueue = false;
      return;
    }

    _processingAudioQueue = true;

    try {
      await _stopAudio();

      // Get the next message from the queue
      String textToSpeak = _pendingAudioMessages.removeAt(0);
      _tempAudioCounter++;
      int storyId =
          99999 + _tempAudioCounter; // Using high numbers to avoid conflicts

      debugPrint('Generating audio for AI message: $textToSpeak');

      // Get personality settings for the selected voice
      final personality = _voicePersonalities[_selectedVoiceId] ??
          {
            'style': 0.5,
            'stability': 0.5,
            'similarity_boost': 0.8,
            'speed': 1.0,
            'prefix': 'AI',
            'exclamations': ['Hmm...'],
          };

      // Add personality prefix to message for more character if the message doesn't already start with an exclamation
      String enhancedText = textToSpeak;
      if (!textToSpeak.contains('!') && !textToSpeak.contains('?')) {
        // 70% chance to add an exclamation for more personality (increased from 40%)
        if (Random().nextDouble() < 0.7) {
          final exclamations = personality['exclamations'] as List<String>;
          final exclamation =
              exclamations[Random().nextInt(exclamations.length)];
          enhancedText = "$exclamation $textToSpeak";
        }
      }

      if (mounted) {
        setState(() {
          _isPlayingAudio = true;
        });
      }

      final settings = {
        'stability': personality['stability'],
        'similarity_boost': personality['similarity_boost'],
        // Increase style parameter to make the voice more expressive
        'style': (personality['style'] as double) + 0.2,
        // Slightly increase speed for a more energetic feel
        'speed': (personality['speed'] as double) + 0.05,
      };

      // First check if we have cached audio for this message
      String? audioPath =
          await _checkCachedAudio(enhancedText, _selectedVoiceId);

      // If no cache, generate new audio
      if (audioPath == null) {
        final result = await _elevenLabsService.generateAudioWithSettings(
          enhancedText,
          storyId,
          voiceId: _selectedVoiceId,
          voiceSettings: settings,
        );

        if (result == null) {
          if (mounted) {
            setState(() {
              _isPlayingAudio = false;
            });
          }
          // Process the next message in the queue
          _processAudioQueue();
          return;
        }

        audioPath = result;

        // Cache this audio for future use
        await _cacheAudio(enhancedText, _selectedVoiceId, audioPath);
      }

      if (mounted) {
        await _audioPlayer.setFilePath(audioPath);
        _audioPlayer.play();

        _audioPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            if (mounted) {
              setState(() {
                _isPlayingAudio = false;
              });
            }

            // Process the next message in the queue after this one completes
            _processAudioQueue();
          }
        });
      }
    } catch (e) {
      debugPrint('Error playing AI voice message: $e');
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
      // Try to process the next message even if this one failed
      _processAudioQueue();
    }
  }

  // Cache management methods
  Future<String?> _checkCachedAudio(String text, String voiceId) async {
    try {
      final hash = text.hashCode.toString() + voiceId;
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/gobang_audio_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final cacheFile = File('${cacheDir.path}/$hash.mp3');
      if (await cacheFile.exists()) {
        debugPrint('Using cached audio for: $text');
        return cacheFile.path;
      }
    } catch (e) {
      debugPrint('Error checking cache: $e');
    }
    return null;
  }

  Future<void> _cacheAudio(
      String text, String voiceId, String audioPath) async {
    try {
      final hash = text.hashCode.toString() + voiceId;
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/gobang_audio_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final cacheFile = File('${cacheDir.path}/$hash.mp3');
      final originalFile = File(audioPath);

      if (await originalFile.exists()) {
        await originalFile.copy(cacheFile.path);
        debugPrint('Cached audio for: $text');
      }
    } catch (e) {
      debugPrint('Error caching audio: $e');
    }
  }

  Point<int> _randomMove() {
    final empty = <Point<int>>[];
    for (int x = 0; x < boardSize; x++) {
      for (int y = 0; y < boardSize; y++) {
        if (board[x][y] == null) empty.add(Point(x, y));
      }
    }
    return empty[Random().nextInt(empty.length)];
  }

  // Improved Easy AI - not completely random but makes some mistakes
  Point<int> _easyAIMove() {
    // 30% chance to make a completely random move (mistake)
    if (Random().nextDouble() < 0.3) {
      return _randomMove();
    }

    // Always try to win if possible
    Point<int>? winningMove = _findWinningMove(GobangPlayer.p2);
    if (winningMove != null) return winningMove;

    // 70% chance to block immediate threats (sometimes misses blocks)
    Point<int>? blockingMove = _findWinningMove(GobangPlayer.p1);
    if (blockingMove != null && Random().nextDouble() < 0.7) {
      return blockingMove;
    }

    // Try to make adjacent moves or center moves
    Point<int>? adjacentMove = _findAdjacentMove();
    if (adjacentMove != null) return adjacentMove;

    Point<int>? centerMove = _findStrategicMove();
    if (centerMove != null) return centerMove;

    return _randomMove();
  }

  // Improved Medium AI - more strategic but not perfect
  Point<int> _mediumAIMove() {
    // Always try to win
    Point<int>? winningMove = _findWinningMove(GobangPlayer.p2);
    if (winningMove != null) return winningMove;

    // Always block immediate threats
    Point<int>? blockingMove = _findWinningMove(GobangPlayer.p1);
    if (blockingMove != null) return blockingMove;

    // Look for fork opportunities (creating multiple threats)
    Point<int>? forkMove = _findForkMove(GobangPlayer.p2);
    if (forkMove != null) return forkMove;

    // Block opponent's fork attempts
    Point<int>? blockForkMove = _findForkMove(GobangPlayer.p1);
    if (blockForkMove != null) return blockForkMove;

    // Look for strong attack moves (3 in a row with open ends)
    Point<int>? attackMove = _findAttackMove(preferOpenEnded: true);
    if (attackMove != null) return attackMove;

    // Block opponent's strong attacks
    Point<int>? blockAttackMove = _findOpponentAttackMove();
    if (blockAttackMove != null) return blockAttackMove;

    // Make strategic positional moves
    Point<int>? strategicMove = _findStrategicMove();
    if (strategicMove != null) return strategicMove;

    Point<int>? adjacentMove = _findAdjacentMove();
    if (adjacentMove != null) return adjacentMove;

    return _randomMove();
  }

  Point<int> _bestMove() {
    // Priority 1: Win immediately
    Point<int>? winningMove = _findWinningMove(GobangPlayer.p2);
    if (winningMove != null) return winningMove;

    // Priority 2: Block immediate threats
    Point<int>? blockingMove = _findWinningMove(GobangPlayer.p1);
    if (blockingMove != null) return blockingMove;

    // Priority 3: Create multiple threats (fork)
    Point<int>? forkMove = _findForkMove(GobangPlayer.p2);
    if (forkMove != null) return forkMove;

    // Priority 4: Block opponent's fork attempts
    Point<int>? blockForkMove = _findForkMove(GobangPlayer.p1);
    if (blockForkMove != null) return blockForkMove;

    // Priority 5: Create double threats
    Point<int>? doubleThreatMove = _findDoubleThreatMove();
    if (doubleThreatMove != null) return doubleThreatMove;

    // Priority 6: Block opponent's double threats
    Point<int>? blockDoubleThreatMove =
        _findDoubleThreatMove(forOpponent: true);
    if (blockDoubleThreatMove != null) return blockDoubleThreatMove;

    // Priority 7: Block opponent's strong attacks
    Point<int>? blockAttackMove = _findOpponentAttackMove();
    if (blockAttackMove != null) return blockAttackMove;

    // Priority 8: Create strong attacks (open-ended sequences)
    Point<int>? attackMove = _findAttackMove(preferOpenEnded: true);
    if (attackMove != null) return attackMove;

    // Priority 9: Make strategic positional moves
    Point<int>? strategicMove = _findBestPositionalMove();
    if (strategicMove != null) return strategicMove;

    // Priority 10: Make adjacent moves
    Point<int>? adjacentMove = _findAdjacentMove();
    if (adjacentMove != null) return adjacentMove;

    return _randomMove();
  }

  Point<int>? _findWinningMove(GobangPlayer player) {
    for (int x = 0; x < boardSize; x++) {
      for (int y = 0; y < boardSize; y++) {
        if (board[x][y] != null) continue;

        // Save the current board state
        GobangPlayer? originalState = board[x][y];

        // Try placing a stone here to see if it wins
        board[x][y] = player;

        bool isWinning = _countConsecutive(x, y, 1, 0, player) +
                    _countConsecutive(x, y, -1, 0, player) -
                    1 >=
                5 ||
            _countConsecutive(x, y, 0, 1, player) +
                    _countConsecutive(x, y, 0, -1, player) -
                    1 >=
                5 ||
            _countConsecutive(x, y, 1, 1, player) +
                    _countConsecutive(x, y, -1, -1, player) -
                    1 >=
                5 ||
            _countConsecutive(x, y, 1, -1, player) +
                    _countConsecutive(x, y, -1, 1, player) -
                    1 >=
                5;

        // Restore the original board state
        board[x][y] = originalState;

        if (isWinning) {
          return Point(x, y);
        }
      }
    }
    return null;
  }

  Point<int>? _findDoubleThreatMove({bool forOpponent = false}) {
    final player = forOpponent ? GobangPlayer.p1 : GobangPlayer.p2;
    final potentialThreats = <Point<int>, int>{};

    // Check each empty cell
    for (int x = 0; x < boardSize; x++) {
      for (int y = 0; y < boardSize; y++) {
        if (board[x][y] != null) continue;

        // Save the current board state
        GobangPlayer? originalState = board[x][y];

        // Place a test stone
        board[x][y] = player;

        // Count threats in different directions
        int threatCount = 0;
        List<List<int>> directions = [
          [1, 0],
          [0, 1],
          [1, 1],
          [1, -1]
        ];

        for (var dir in directions) {
          int dx = dir[0], dy = dir[1];
          int forward = _countOpenEndedRun(x, y, dx, dy, player);
          int backward = _countOpenEndedRun(x, y, -dx, -dy, player);

          // If we have 3 or 4 in a row with open ends, it's a threat
          if (forward + backward - 1 == 3 || forward + backward - 1 == 4) {
            threatCount++;
          }
        }

        // Restore the original board state
        board[x][y] = originalState;

        // Store this position if it creates at least one threat
        if (threatCount >= 1) {
          potentialThreats[Point(x, y)] = threatCount;
        }
      }
    }

    // Find the move with the most threats
    Point<int>? bestMove;
    int maxThreats = 1; // Start at 1 for normal threats, 2+ for double threats

    potentialThreats.forEach((pos, threats) {
      if (threats > maxThreats) {
        maxThreats = threats;
        bestMove = pos;
      }
    });

    // Only return if we found a double threat (or any threat if checking for opponent)
    if (bestMove != null && (maxThreats >= 2 || forOpponent)) {
      return bestMove;
    }

    return null;
  }

  int _countOpenEndedRun(int x, int y, int dx, int dy, GobangPlayer player) {
    int count = 1;
    int i = x + dx, j = y + dy;

    while (i >= 0 &&
        i < boardSize &&
        j >= 0 &&
        j < boardSize &&
        board[i][j] == player) {
      count++;
      i += dx;
      j += dy;
    }

    bool isOpenEnded = i >= 0 &&
        i < boardSize &&
        j >= 0 &&
        j < boardSize &&
        board[i][j] == null;

    return isOpenEnded ? count : 0;
  }

  Point<int>? _findAttackMove({bool preferOpenEnded = false}) {
    List<Point<int>> goodMoves = [];
    List<Point<int>> bestMoves = [];

    for (int x = 0; x < boardSize; x++) {
      for (int y = 0; y < boardSize; y++) {
        if (board[x][y] != null) continue;

        // Save the current board state
        GobangPlayer? originalState = board[x][y];

        // Try placing a stone here
        board[x][y] = GobangPlayer.p2;

        // Calculate the best consecutive stones in any direction
        int bestLine = 0;
        bool hasOpenEnds = false;
        List<List<int>> directions = [
          [1, 0],
          [0, 1],
          [1, 1],
          [1, -1]
        ];

        for (var direction in directions) {
          int dx = direction[0], dy = direction[1];
          int consecutiveStones =
              _countConsecutive(x, y, dx, dy, GobangPlayer.p2) +
                  _countConsecutive(x, y, -dx, -dy, GobangPlayer.p2) -
                  1;

          if (consecutiveStones > bestLine) {
            bestLine = consecutiveStones;

            // Check if both ends are open
            int i1 = x + dx * _countConsecutive(x, y, dx, dy, GobangPlayer.p2);
            int j1 = y + dy * _countConsecutive(x, y, dx, dy, GobangPlayer.p2);
            int i2 =
                x - dx * _countConsecutive(x, y, -dx, -dy, GobangPlayer.p2);
            int j2 =
                y - dy * _countConsecutive(x, y, -dx, -dy, GobangPlayer.p2);

            bool isOpen1 = _isValidPosition(i1, j1) && board[i1][j1] == null;
            bool isOpen2 = _isValidPosition(i2, j2) && board[i2][j2] == null;

            hasOpenEnds = isOpen1 && isOpen2;
          }
        }

        // Restore the original board state
        board[x][y] = originalState;

        // If this creates 3 or 4 in a row, it's a good attacking move
        if (bestLine >= 3) {
          if (hasOpenEnds && preferOpenEnded) {
            bestMoves.add(Point(x, y));
          } else {
            goodMoves.add(Point(x, y));
          }
        }
      }
    }

    // Prefer open-ended moves if available and requested
    if (bestMoves.isNotEmpty && preferOpenEnded) {
      return bestMoves[Random().nextInt(bestMoves.length)];
    }

    // Otherwise use any good move
    if (goodMoves.isNotEmpty) {
      return goodMoves[Random().nextInt(goodMoves.length)];
    }

    return null;
  }

  // Find fork moves - positions that create multiple threats
  Point<int>? _findForkMove(GobangPlayer player) {
    for (int x = 0; x < boardSize; x++) {
      for (int y = 0; y < boardSize; y++) {
        if (board[x][y] != null) continue;

        // Save the current board state
        GobangPlayer? originalState = board[x][y];
        board[x][y] = player;

        int threatCount = 0;
        List<List<int>> directions = [
          [1, 0],
          [0, 1],
          [1, 1],
          [1, -1]
        ];

        // Count how many directions create a threat (3+ in a row with open ends)
        for (var dir in directions) {
          int dx = dir[0], dy = dir[1];
          int count = _countConsecutive(x, y, dx, dy, player) +
              _countConsecutive(x, y, -dx, -dy, player) -
              1;

          if (count >= 3) {
            // Check if at least one end is open
            int forwardX = x + dx * _countConsecutive(x, y, dx, dy, player);
            int forwardY = y + dy * _countConsecutive(x, y, dx, dy, player);
            int backwardX = x - dx * _countConsecutive(x, y, -dx, -dy, player);
            int backwardY = y - dy * _countConsecutive(x, y, -dx, -dy, player);

            bool forwardOpen = _isValidPosition(forwardX, forwardY) &&
                board[forwardX][forwardY] == null;
            bool backwardOpen = _isValidPosition(backwardX, backwardY) &&
                board[backwardX][backwardY] == null;

            if (forwardOpen || backwardOpen) {
              threatCount++;
            }
          }
        }

        // Restore the original board state
        board[x][y] = originalState;

        // If this move creates 2+ threats, it's a fork
        if (threatCount >= 2) {
          return Point(x, y);
        }
      }
    }
    return null;
  }

  // Find opponent's strong attack moves to block
  Point<int>? _findOpponentAttackMove() {
    for (int x = 0; x < boardSize; x++) {
      for (int y = 0; y < boardSize; y++) {
        if (board[x][y] != null) continue;

        // Save the current board state
        GobangPlayer? originalState = board[x][y];
        board[x][y] = GobangPlayer.p1;

        // Check if this creates a strong threat (3+ in a row with open ends)
        bool isStrongThreat = false;
        List<List<int>> directions = [
          [1, 0],
          [0, 1],
          [1, 1],
          [1, -1]
        ];

        for (var dir in directions) {
          int dx = dir[0], dy = dir[1];
          int count = _countConsecutive(x, y, dx, dy, GobangPlayer.p1) +
              _countConsecutive(x, y, -dx, -dy, GobangPlayer.p1) -
              1;

          if (count >= 3) {
            // Check if both ends are open (very dangerous)
            int forwardX =
                x + dx * _countConsecutive(x, y, dx, dy, GobangPlayer.p1);
            int forwardY =
                y + dy * _countConsecutive(x, y, dx, dy, GobangPlayer.p1);
            int backwardX =
                x - dx * _countConsecutive(x, y, -dx, -dy, GobangPlayer.p1);
            int backwardY =
                y - dy * _countConsecutive(x, y, -dx, -dy, GobangPlayer.p1);

            bool forwardOpen = _isValidPosition(forwardX, forwardY) &&
                board[forwardX][forwardY] == null;
            bool backwardOpen = _isValidPosition(backwardX, backwardY) &&
                board[backwardX][backwardY] == null;

            if (forwardOpen && backwardOpen) {
              isStrongThreat = true;
              break;
            }
          }
        }

        // Restore the original board state
        board[x][y] = originalState;

        if (isStrongThreat) {
          return Point(x, y);
        }
      }
    }
    return null;
  }

  Point<int>? _findStrategicMove() {
    final center = boardSize ~/ 2;
    final centerPositions = <Point<int>>[];
    final nearCenterPositions = <Point<int>>[];

    if (board[center][center] == null) {
      return Point(center, center);
    }

    for (int x = center - 1; x <= center + 1; x++) {
      for (int y = center - 1; y <= center + 1; y++) {
        if (x >= 0 &&
            x < boardSize &&
            y >= 0 &&
            y < boardSize &&
            board[x][y] == null) {
          centerPositions.add(Point(x, y));
        }
      }
    }

    for (int x = center - 2; x <= center + 2; x++) {
      for (int y = center - 2; y <= center + 2; y++) {
        if (x >= 0 &&
            x < boardSize &&
            y >= 0 &&
            y < boardSize &&
            board[x][y] == null &&
            !centerPositions.contains(Point(x, y))) {
          nearCenterPositions.add(Point(x, y));
        }
      }
    }

    if (centerPositions.isNotEmpty) {
      return centerPositions[Random().nextInt(centerPositions.length)];
    }

    if (nearCenterPositions.isNotEmpty) {
      return nearCenterPositions[Random().nextInt(nearCenterPositions.length)];
    }

    return null;
  }

  // Advanced positional evaluation for hard AI
  Point<int>? _findBestPositionalMove() {
    Point<int>? bestMove;
    int bestScore = -1000;

    for (int x = 0; x < boardSize; x++) {
      for (int y = 0; y < boardSize; y++) {
        if (board[x][y] != null) continue;

        int score = _evaluatePosition(x, y);
        if (score > bestScore) {
          bestScore = score;
          bestMove = Point(x, y);
        }
      }
    }

    return bestMove;
  }

  // Evaluate the strategic value of a position
  int _evaluatePosition(int x, int y) {
    int score = 0;
    final center = boardSize ~/ 2;

    // Center control bonus
    int distanceFromCenter = (x - center).abs() + (y - center).abs();
    score += (10 - distanceFromCenter).clamp(0, 10);

    // Evaluate potential in all directions
    List<List<int>> directions = [
      [1, 0],
      [0, 1],
      [1, 1],
      [1, -1]
    ];

    for (var dir in directions) {
      int dx = dir[0], dy = dir[1];

      // Check potential for AI stones
      int aiPotential =
          _evaluateDirectionPotential(x, y, dx, dy, GobangPlayer.p2);
      score += aiPotential * 2;

      // Check blocking potential against opponent
      int blockPotential =
          _evaluateDirectionPotential(x, y, dx, dy, GobangPlayer.p1);
      score += blockPotential;
    }

    // Bonus for being adjacent to existing stones
    int adjacentBonus = 0;
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        if (dx == 0 && dy == 0) continue;
        int nx = x + dx, ny = y + dy;
        if (_isValidPosition(nx, ny)) {
          if (board[nx][ny] == GobangPlayer.p2) {
            adjacentBonus += 3;
          } else if (board[nx][ny] == GobangPlayer.p1) {
            adjacentBonus += 1;
          }
        }
      }
    }
    score += adjacentBonus;

    return score;
  }

  // Evaluate potential in a specific direction
  int _evaluateDirectionPotential(
      int x, int y, int dx, int dy, GobangPlayer player) {
    int potential = 0;
    int consecutiveSpaces = 0;
    int friendlyStones = 0;
    int enemyStones = 0;

    // Check 4 positions in each direction
    for (int step = 1; step <= 4; step++) {
      int fx = x + dx * step, fy = y + dy * step;
      int bx = x - dx * step, by = y - dy * step;

      // Forward direction
      if (_isValidPosition(fx, fy)) {
        if (board[fx][fy] == player) {
          friendlyStones++;
        } else if (board[fx][fy] == null) {
          consecutiveSpaces++;
        } else {
          enemyStones++;
        }
      }

      // Backward direction
      if (_isValidPosition(bx, by)) {
        if (board[bx][by] == player) {
          friendlyStones++;
        } else if (board[bx][by] == null) {
          consecutiveSpaces++;
        } else {
          enemyStones++;
        }
      }
    }

    // Calculate potential based on friendly stones and available space
    if (enemyStones == 0) {
      // No blocking stones
      potential = friendlyStones * 3 + consecutiveSpaces;
    } else {
      potential = friendlyStones; // Reduced potential if blocked
    }

    return potential;
  }

  Point<int>? _findAdjacentMove() {
    final adjacentPositions = <Point<int>>[];

    for (int x = 0; x < boardSize; x++) {
      for (int y = 0; y < boardSize; y++) {
        if (board[x][y] != null) continue;

        bool isAdjacent = false;
        for (int dx = -1; dx <= 1; dx++) {
          for (int dy = -1; dy <= 1; dy++) {
            if (dx == 0 && dy == 0) continue;

            int nx = x + dx;
            int ny = y + dy;

            if (nx >= 0 &&
                nx < boardSize &&
                ny >= 0 &&
                ny < boardSize &&
                board[nx][ny] != null) {
              isAdjacent = true;
              break;
            }
          }
          if (isAdjacent) break;
        }

        if (isAdjacent) {
          adjacentPositions.add(Point(x, y));
        }
      }
    }

    if (adjacentPositions.isNotEmpty) {
      return adjacentPositions[Random().nextInt(adjacentPositions.length)];
    }

    return null;
  }

  void _checkWinner(int x, int y) {
    final player = board[x][y];
    if (player == null) return;
    if (_countConsecutive(x, y, 1, 0, player) +
                _countConsecutive(x, y, -1, 0, player) -
                1 >=
            5 ||
        _countConsecutive(x, y, 0, 1, player) +
                _countConsecutive(x, y, 0, -1, player) -
                1 >=
            5 ||
        _countConsecutive(x, y, 1, 1, player) +
                _countConsecutive(x, y, -1, -1, player) -
                1 >=
            5 ||
        _countConsecutive(x, y, 1, -1, player) +
                _countConsecutive(x, y, -1, 1, player) -
                1 >=
            5) {
      setState(() {
        winner = player;
        gameOver = true;
        message = player == GobangPlayer.p1 ? 'Blue wins! 🎉' : 'Pink wins! 🎉';
      });

      // Play final victory/defeat message
      if (_useVoiceCommentary) {
        final finalMessage = player == GobangPlayer.p1
            ? _getUniqueMessage(_finalDefeatMessages)
            : _getUniqueMessage(_finalVictoryMessages);
        _playAIVoiceMessage(finalMessage);
      }
    } else if (board.expand((row) => row).every((cell) => cell != null)) {
      setState(() {
        gameOver = true;
        message = 'It\'s a draw!';
      });

      // Play final draw message
      if (_useVoiceCommentary) {
        final finalMessage = _getUniqueMessage(_finalDrawMessages);
        _playAIVoiceMessage(finalMessage);
      }
    }
  }

  int _countConsecutive(int x, int y, int dx, int dy, GobangPlayer player) {
    int count = 0;
    int i = x, j = y;
    while (i >= 0 &&
        i < boardSize &&
        j >= 0 &&
        j < boardSize &&
        board[i][j] == player) {
      count++;
      i += dx;
      j += dy;
    }
    return count;
  }

  // Enhanced adaptive AI move function that counters player's style
  Point<int> _adaptiveAIMove() {
    // Priority 1: Always try to win immediately
    Point<int>? winningMove = _findWinningMove(GobangPlayer.p2);
    if (winningMove != null) return winningMove;

    // Priority 2: Always block immediate threats
    Point<int>? blockingMove = _findWinningMove(GobangPlayer.p1);
    if (blockingMove != null) return blockingMove;

    // Priority 3: Look for critical threats (4 in a row that need immediate blocking)
    Point<int>? criticalBlock = _findCriticalThreat();
    if (criticalBlock != null) return criticalBlock;

    // Adaptive strategy based on player behavior
    if (playerIsAggressive) {
      // Against aggressive players: prioritize defense and counter-attacks

      // Block potential threats more aggressively
      Point<int>? blockThreatMove = _findPlayerThreatMove();
      if (blockThreatMove != null) return blockThreatMove;

      // Block fork attempts
      Point<int>? blockForkMove = _findForkMove(GobangPlayer.p1);
      if (blockForkMove != null) return blockForkMove;

      // Create our own threats to force defensive play
      Point<int>? counterAttack = _findForkMove(GobangPlayer.p2);
      if (counterAttack != null) return counterAttack;
    }

    if (playerIsDefensive) {
      // Against defensive players: create multiple threats they can't all block

      // Create fork moves (multiple threats)
      Point<int>? forkMove = _findForkMove(GobangPlayer.p2);
      if (forkMove != null) return forkMove;

      // Create double threats
      Point<int>? doubleThreatMove = _findDoubleThreatMove();
      if (doubleThreatMove != null) return doubleThreatMove;

      // Create indirect threats that are harder to defend
      Point<int>? indirectThreatMove = _findIndirectThreatMove();
      if (indirectThreatMove != null) return indirectThreatMove;
    }

    if (playerUsesCenter && !_isCenterControlled()) {
      // Challenge for center control against center-focused players
      Point<int>? centerControlMove = _findCenterControlMove();
      if (centerControlMove != null) return centerControlMove;
    }

    // Continue with the enhanced best move algorithm as fallback
    return _bestMove();
  }

  // Find critical threats that need immediate attention (4 in a row)
  Point<int>? _findCriticalThreat() {
    for (int x = 0; x < boardSize; x++) {
      for (int y = 0; y < boardSize; y++) {
        if (board[x][y] != null) continue;

        // Check if opponent placing here would create 4 in a row
        board[x][y] = GobangPlayer.p1;

        List<List<int>> directions = [
          [1, 0],
          [0, 1],
          [1, 1],
          [1, -1]
        ];

        for (var dir in directions) {
          int dx = dir[0], dy = dir[1];
          int count = _countConsecutive(x, y, dx, dy, GobangPlayer.p1) +
              _countConsecutive(x, y, -dx, -dy, GobangPlayer.p1) -
              1;

          if (count >= 4) {
            board[x][y] = null; // Restore
            return Point(x, y); // Critical block needed
          }
        }

        board[x][y] = null; // Restore
      }
    }
    return null;
  }

  // Detect and block specific player threat patterns
  Point<int>? _findPlayerThreatMove() {
    if (playerMoves.isEmpty) return null;

    // Check the areas around player's most recent moves for potential threats
    // Focus on the last 3 moves as they indicate current strategy
    List<Point<int>> recentMoves = playerMoves.length <= 3
        ? playerMoves
        : playerMoves.sublist(playerMoves.length - 3);

    // Detect patterns in player's moves (e.g., consecutive stones)
    for (var move in recentMoves) {
      // Look for empty cells around this move that would enable a sequence
      List<Point<int>> threatSpots = [];

      // Check 2 cells in each direction for potential threats
      List<List<int>> directions = [
        [1, 0],
        [0, 1],
        [1, 1],
        [1, -1]
      ];
      for (var dir in directions) {
        int dx = dir[0], dy = dir[1];

        // Calculate forward and backward from this move
        for (int step = 1; step <= 2; step++) {
          // Forward check
          int fx = move.x + dx * step;
          int fy = move.y + dy * step;
          if (_isValidPosition(fx, fy) && board[fx][fy] == null) {
            if (_wouldCreatePlayerThreat(fx, fy)) {
              threatSpots.add(Point(fx, fy));
            }
          }

          // Backward check
          int bx = move.x - dx * step;
          int by = move.y - dy * step;
          if (_isValidPosition(bx, by) && board[bx][by] == null) {
            if (_wouldCreatePlayerThreat(bx, by)) {
              threatSpots.add(Point(bx, by));
            }
          }
        }
      }

      // If threats found, block the most severe one
      if (threatSpots.isNotEmpty) {
        int bestThreatValue = 0;
        Point<int>? bestThreatBlock;

        for (var spot in threatSpots) {
          int threatValue = _evaluateThreatSeverity(spot.x, spot.y);
          if (threatValue > bestThreatValue) {
            bestThreatValue = threatValue;
            bestThreatBlock = spot;
          }
        }

        if (bestThreatBlock != null) {
          return bestThreatBlock;
        }
      }
    }

    return null;
  }

  bool _isValidPosition(int x, int y) {
    return x >= 0 && x < boardSize && y >= 0 && y < boardSize;
  }

  bool _wouldCreatePlayerThreat(int x, int y) {
    // Save the current board state
    GobangPlayer? originalState = board[x][y];

    // Check if player placing a stone here would create a significant threat
    board[x][y] = GobangPlayer.p1;

    bool isThreat = false;
    List<List<int>> directions = [
      [1, 0],
      [0, 1],
      [1, 1],
      [1, -1]
    ];

    for (var dir in directions) {
      int dx = dir[0], dy = dir[1];
      int count = _countConsecutive(x, y, dx, dy, GobangPlayer.p1) +
          _countConsecutive(x, y, -dx, -dy, GobangPlayer.p1) -
          1;

      // Check if it would create a sequence of 3 or more with open ends
      if (count >= 3) {
        // Check if at least one end is open
        int forwardX =
            x + dx * _countConsecutive(x, y, dx, dy, GobangPlayer.p1);
        int forwardY =
            y + dy * _countConsecutive(x, y, dx, dy, GobangPlayer.p1);
        int backwardX =
            x - dx * _countConsecutive(x, y, -dx, -dy, GobangPlayer.p1);
        int backwardY =
            y - dy * _countConsecutive(x, y, -dx, -dy, GobangPlayer.p1);

        bool forwardOpen = _isValidPosition(forwardX, forwardY) &&
            board[forwardX][forwardY] == null;
        bool backwardOpen = _isValidPosition(backwardX, backwardY) &&
            board[backwardX][backwardY] == null;

        if (forwardOpen || backwardOpen) {
          isThreat = true;
          break;
        }
      }
    }

    // Restore the original board state
    board[x][y] = originalState;
    return isThreat;
  }

  int _evaluateThreatSeverity(int x, int y) {
    // Save the current board state
    GobangPlayer? originalState = board[x][y];

    // Calculate how severe a threat would be at this position
    board[x][y] = GobangPlayer.p1;

    int maxThreat = 0;
    List<List<int>> directions = [
      [1, 0],
      [0, 1],
      [1, 1],
      [1, -1]
    ];

    for (var dir in directions) {
      int dx = dir[0], dy = dir[1];
      int count = _countConsecutive(x, y, dx, dy, GobangPlayer.p1) +
          _countConsecutive(x, y, -dx, -dy, GobangPlayer.p1) -
          1;

      // Check openness of the ends
      int forwardX = x + dx * _countConsecutive(x, y, dx, dy, GobangPlayer.p1);
      int forwardY = y + dy * _countConsecutive(x, y, dx, dy, GobangPlayer.p1);
      int backwardX =
          x - dx * _countConsecutive(x, y, -dx, -dy, GobangPlayer.p1);
      int backwardY =
          y - dy * _countConsecutive(x, y, -dx, -dy, GobangPlayer.p1);

      bool forwardOpen = _isValidPosition(forwardX, forwardY) &&
          board[forwardX][forwardY] == null;
      bool backwardOpen = _isValidPosition(backwardX, backwardY) &&
          board[backwardX][backwardY] == null;

      // Calculate threat value based on sequence length and openness
      int threatValue = count;
      if (forwardOpen) threatValue += 2;
      if (backwardOpen) threatValue += 2;
      if (forwardOpen && backwardOpen) {
        threatValue += 3; // Double-open is extra dangerous
      }

      maxThreat = max(maxThreat, threatValue);
    }

    // Restore the original board state
    board[x][y] = originalState;
    return maxThreat;
  }

  bool _isCenterControlled() {
    final center = boardSize ~/ 2;

    // Check if the exact center is already taken
    if (board[center][center] != null) return true;

    // Count player's and AI's stones in the center 3x3 area
    int playerStones = 0;
    int aiStones = 0;

    for (int x = center - 1; x <= center + 1; x++) {
      for (int y = center - 1; y <= center + 1; y++) {
        if (!_isValidPosition(x, y)) continue;

        if (board[x][y] == GobangPlayer.p1) {
          playerStones++;
        } else if (board[x][y] == GobangPlayer.p2) {
          aiStones++;
        }
      }
    }

    // Center is controlled if more than 3 stones of either player are there
    return playerStones > 3 || aiStones > 3;
  }

  Point<int>? _findCenterControlMove() {
    final center = boardSize ~/ 2;

    // If center is empty, take it
    if (board[center][center] == null) {
      return Point(center, center);
    }

    // Find the best empty spot in the center 3x3 area
    List<Point<int>> centerSpots = [];

    for (int x = center - 1; x <= center + 1; x++) {
      for (int y = center - 1; y <= center + 1; y++) {
        if (_isValidPosition(x, y) && board[x][y] == null) {
          centerSpots.add(Point(x, y));
        }
      }
    }

    if (centerSpots.isNotEmpty) {
      // Evaluate each center spot for strategic value
      Point<int>? bestSpot;
      int bestValue = -1;

      for (var spot in centerSpots) {
        // Calculate value based on adjacency to our stones and distance to center
        int value = _evaluateCenterSpot(spot.x, spot.y, center);
        if (value > bestValue) {
          bestValue = value;
          bestSpot = spot;
        }
      }

      return bestSpot;
    }

    return null;
  }

  int _evaluateCenterSpot(int x, int y, int center) {
    int value = 10 -
        ((x - center).abs() + (y - center).abs()); // Value proximity to center

    // Add value for adjacent friendly stones
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        if (dx == 0 && dy == 0) continue;

        int nx = x + dx;
        int ny = y + dy;

        if (_isValidPosition(nx, ny)) {
          if (board[nx][ny] == GobangPlayer.p2) {
            value += 3; // Our stone
          } else if (board[nx][ny] == GobangPlayer.p1) {
            value += 1; // Opponent stone - still has some value for defense
          }
        }
      }
    }

    return value;
  }

  Point<int>? _findIndirectThreatMove() {
    // Look for moves that create multiple potential threats, even if not immediate
    List<Point<int>> candidates = [];

    for (int x = 0; x < boardSize; x++) {
      for (int y = 0; y < boardSize; y++) {
        if (board[x][y] != null) continue;

        // Evaluate this position for creating multiple "proto-threats"
        int threatPotential = _evaluateIndirectThreatPotential(x, y);
        if (threatPotential >= 3) {
          // At least 3 potential lines
          candidates.add(Point(x, y));
        }
      }
    }

    if (candidates.isNotEmpty) {
      return candidates[Random().nextInt(candidates.length)];
    }

    return null;
  }

  int _evaluateIndirectThreatPotential(int x, int y) {
    // Save the current board state
    GobangPlayer? originalState = board[x][y];

    // Count how many directions have potential for future threats
    board[x][y] = GobangPlayer.p2;
    int potentialCount = 0;

    List<List<int>> directions = [
      [1, 0],
      [0, 1],
      [1, 1],
      [1, -1]
    ];
    for (var dir in directions) {
      int dx = dir[0], dy = dir[1];

      // Look 2 steps in each direction for potential
      bool hasPotential = false;

      // Forward check
      for (int step = 1; step <= 2; step++) {
        int fx = x + dx * step;
        int fy = y + dy * step;
        if (_isValidPosition(fx, fy) &&
            (board[fx][fy] == null || board[fx][fy] == GobangPlayer.p2)) {
          hasPotential = true;
        } else {
          hasPotential = false;
          break;
        }
      }

      if (hasPotential) {
        potentialCount++;
        continue;
      }

      // Backward check
      hasPotential = true;
      for (int step = 1; step <= 2; step++) {
        int bx = x - dx * step;
        int by = y - dy * step;
        if (_isValidPosition(bx, by) &&
            (board[bx][by] == null || board[bx][by] == GobangPlayer.p2)) {
          hasPotential = true;
        } else {
          hasPotential = false;
          break;
        }
      }

      if (hasPotential) {
        potentialCount++;
      }
    }

    // Restore the original board state
    board[x][y] = originalState;
    return potentialCount;
  }

  // Method to get a random message that hasn't been used recently
  String _getUniqueMessage(List<String> messageList) {
    // If we've used all messages or nearly all, reset the used messages
    if (_usedMessages.length >= messageList.length - 1) {
      _usedMessages.clear();
    }

    // Find messages we haven't used yet
    final unusedMessages =
        messageList.where((msg) => !_usedMessages.contains(msg)).toList();

    // If all messages have been used (shouldn't happen with the reset above but just in case)
    if (unusedMessages.isEmpty) {
      _usedMessages.clear(); // Reset used messages
      final message = messageList[Random().nextInt(messageList.length)];
      _usedMessages.add(message);
      return message;
    }

    // Pick a random unused message
    final message = unusedMessages[Random().nextInt(unusedMessages.length)];
    _usedMessages.add(message);
    return message;
  }

  // Helper method to get a thinking verb for variety
  String _getThinkingVerb() {
    final verbs = [
      'thinking',
      'pondering',
      'calculating',
      'planning',
      'strategizing',
      'contemplating'
    ];
    return verbs[Random().nextInt(verbs.length)];
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = context.watch<ThemeService>().config;
    
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = MediaQuery.of(context).size.width;
              final screenHeight = MediaQuery.of(context).size.height;
              final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
              final shortestSide = min(screenWidth, screenHeight);
              final isTablet = shortestSide > 600 ||
                  (shortestSide > 500 && devicePixelRatio < 2.5);
              final isLandscape = screenWidth > screenHeight;
              final isSmallPhoneLandscape =
                  isLandscape && !isTablet && screenHeight < 380;

              // Responsive sizing
              final horizontalPadding = isTablet
                  ? 24.0
                  : (isSmallPhoneLandscape ? 8.0 : (isLandscape ? 12.0 : 18.0));
              final verticalPadding = isTablet
                  ? 18.0
                  : (isSmallPhoneLandscape ? 6.0 : (isLandscape ? 8.0 : 12.0));
              final titleFontSize = isTablet
                  ? 32.0
                  : (isSmallPhoneLandscape
                      ? 20.0
                      : (isLandscape ? 24.0 : 32.0));
              final iconSize = isTablet
                  ? 32.0
                  : (isSmallPhoneLandscape
                      ? 20.0
                      : (isLandscape ? 24.0 : 32.0));
              final dropdownFontSize = isTablet
                  ? 16.0
                  : (isSmallPhoneLandscape
                      ? 12.0
                      : (isLandscape ? 14.0 : 16.0));
              final buttonFontSize = isTablet
                  ? 22.0
                  : (isSmallPhoneLandscape
                      ? 14.0
                      : (isLandscape ? 16.0 : 22.0));

              return isLandscape
                  ? _buildLandscapeLayout(
                      horizontalPadding,
                      verticalPadding,
                      titleFontSize,
                      iconSize,
                      dropdownFontSize,
                      buttonFontSize,
                      isTablet,
                      isSmallPhoneLandscape,
                      constraints)
                  : _buildPortraitLayout(
                      horizontalPadding,
                      verticalPadding,
                      titleFontSize,
                      iconSize,
                      dropdownFontSize,
                      buttonFontSize,
                      isTablet,
                      isSmallPhoneLandscape,
                      constraints);
            },
          ),
        ),
      ),
    );
  }

  // Landscape layout with two panels
  Widget _buildLandscapeLayout(
      double horizontalPadding,
      double verticalPadding,
      double titleFontSize,
      double iconSize,
      double dropdownFontSize,
      double buttonFontSize,
      bool isTablet,
      bool isSmallPhoneLandscape,
      BoxConstraints constraints) {
    return Column(
      children: [
        // Top bar
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding, vertical: verticalPadding * 0.5),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF00B8D4),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x3300B8D4),
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
                'Gobang',
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: titleFontSize * 0.9,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF00B8D4),
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
              // Left panel: Controls/settings
              SizedBox(
                width:
                    isTablet ? 240.0 : (isSmallPhoneLandscape ? 160.0 : 190.0),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding * 0.75,
                      vertical: verticalPadding * 0.5),
                  child: Column(
                    children: [
                      // Game modes and settings
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
                                    fontSize: dropdownFontSize * 0.85,
                                    color: const Color(0xFF00B8D4))),
                            SizedBox(height: verticalPadding * 0.25),
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: ChoiceChip(
                                        label: Text('2 Players',
                                            style: TextStyle(
                                                fontFamily: 'Baloo2',
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                                fontSize:
                                                    dropdownFontSize * 0.7)),
                                        selected: mode == GobangMode.twoPlayer,
                                        onSelected: (_) =>
                                            _setMode(GobangMode.twoPlayer),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: verticalPadding * 0.25),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ChoiceChip(
                                        label: Text('vs ChatGPT',
                                            style: TextStyle(
                                                fontFamily: 'Baloo2',
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                                fontSize:
                                                    dropdownFontSize * 0.7)),
                                        selected: mode == GobangMode.vsAI,
                                        onSelected: (_) =>
                                            _setMode(GobangMode.vsAI),
                                      ),
                                    ),
                                  ],
                                ),
                                if (mode == GobangMode.vsAI) ...[
                                  SizedBox(height: verticalPadding * 0.25),
                                  DropdownButton<GobangAIDifficulty>(
                                    value: aiDifficulty,
                                    onChanged: (v) => _setAIDifficulty(v!),
                                    style: TextStyle(
                                        fontSize: dropdownFontSize * 0.75,
                                        color: Colors.black),
                                    isExpanded: true,
                                    isDense: true,
                                    items: const [
                                      DropdownMenuItem(
                                        value: GobangAIDifficulty.easy,
                                        child: Text('Easy',
                                            style:
                                                TextStyle(color: Colors.black)),
                                      ),
                                      DropdownMenuItem(
                                        value: GobangAIDifficulty.medium,
                                        child: Text('Medium',
                                            style:
                                                TextStyle(color: Colors.black)),
                                      ),
                                      DropdownMenuItem(
                                        value: GobangAIDifficulty.hard,
                                        child: Text('Hard',
                                            style:
                                                TextStyle(color: Colors.black)),
                                      ),
                                    ],
                                  ),
                                ],
                                SizedBox(height: verticalPadding * 0.25),
                                DropdownButton<int>(
                                  value: boardSize,
                                  onChanged: (v) => _setBoardSize(v!),
                                  style: TextStyle(
                                      fontSize: dropdownFontSize * 0.75,
                                      color: Colors.black),
                                  isExpanded: true,
                                  isDense: true,
                                  items: boardSizes
                                      .map((size) => DropdownMenuItem(
                                            value: size,
                                            child: Text('${size}x$size',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: dropdownFontSize *
                                                        0.75)),
                                          ))
                                      .toList(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Voice settings (only visible in AI mode)
                      if (mode == GobangMode.vsAI) ...[
                        SizedBox(height: verticalPadding * 0.75),
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
                              Text('Voice',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: dropdownFontSize * 0.85,
                                      color: const Color(0xFF00B8D4))),
                              SizedBox(height: verticalPadding * 0.25),
                              DropdownButton<String>(
                                value: _selectedVoiceId,
                                onChanged: (v) => _setVoiceId(v!),
                                style: TextStyle(
                                    fontSize: dropdownFontSize * 0.75,
                                    color: Colors.black),
                                isExpanded: true,
                                isDense: true,
                                items: ElevenLabsService.availableVoices
                                    .map((voice) => DropdownMenuItem(
                                          value: voice['id'],
                                          child: Text(voice['name']!,
                                              style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize:
                                                      dropdownFontSize * 0.75)),
                                        ))
                                    .toList(),
                              ),
                              SizedBox(height: verticalPadding * 0.25),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Transform.scale(
                                    scale: isTablet
                                        ? 0.8
                                        : (isSmallPhoneLandscape ? 0.6 : 0.7),
                                    child: Switch(
                                      value: _useVoiceCommentary,
                                      onChanged: _toggleVoiceCommentary,
                                      activeThumbColor: const Color(0xFF00B8D4),
                                    ),
                                  ),
                                  SizedBox(width: verticalPadding * 0.25),
                                  Text('Commentary',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: dropdownFontSize * 0.75)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Game status
                      if (message != null) ...[
                        SizedBox(height: verticalPadding * 0.75),
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
                                fontSize: dropdownFontSize * 0.9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00B8D4),
                                fontFamily: 'Baloo2'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      if (gameOver) ...[
                        SizedBox(height: verticalPadding * 0.75),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00B8D4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28)),
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                          onPressed: _resetGame,
                          child: Text('Play Again',
                              style: TextStyle(
                                  fontSize: dropdownFontSize * 0.9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Baloo2')),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Right panel: Game board
              Expanded(
                child: LayoutBuilder(
                  builder: (context, rightPanelConstraints) {
                    return Padding(
                      padding: EdgeInsets.all(horizontalPadding * 0.5),
                      child: _buildBoardPanel(
                          rightPanelConstraints,
                          isTablet,
                          isSmallPhoneLandscape,
                          verticalPadding,
                          buttonFontSize),
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
  Widget _buildPortraitLayout(
      double horizontalPadding,
      double verticalPadding,
      double titleFontSize,
      double iconSize,
      double dropdownFontSize,
      double buttonFontSize,
      bool isTablet,
      bool isSmallPhoneLandscape,
      BoxConstraints constraints) {
    return Column(
      children: [
        const SizedBox(height: 18),
        Row(
          children: [
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF00B8D4),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x3300B8D4),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 32),
              ),
            ),
            const Spacer(),
            const Text(
              'Gobang',
              style: TextStyle(
                fontFamily: 'Baloo2',
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF00B8D4),
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 18),
        _buildControlsPanel(dropdownFontSize, buttonFontSize, verticalPadding),
        const SizedBox(height: 18),
        Expanded(
          child: _buildBoardPanel(constraints, isTablet, isSmallPhoneLandscape,
              verticalPadding, buttonFontSize),
        ),
      ],
    );
  }

  // Controls/settings panel (mode, difficulty, board size, voice, etc.)
  Widget _buildControlsPanel(
      double dropdownFontSize, double buttonFontSize, double verticalPadding,
      [bool isSmallPhoneLandscape = false]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Game modes and settings
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          children: [
            ChoiceChip(
              label: const Text('2 Players',
                  style: TextStyle(
                      fontFamily: 'Baloo2',
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              selected: mode == GobangMode.twoPlayer,
              onSelected: (_) => _setMode(GobangMode.twoPlayer),
            ),
            ChoiceChip(
              label: const Text('Play vs ChatGPT',
                  style: TextStyle(
                      fontFamily: 'Baloo2',
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              selected: mode == GobangMode.vsAI,
              onSelected: (_) => _setMode(GobangMode.vsAI),
            ),
            if (mode == GobangMode.vsAI) ...[
              const SizedBox(width: 8),
              DropdownButton<GobangAIDifficulty>(
                value: aiDifficulty,
                onChanged: (v) => _setAIDifficulty(v!),
                style:
                    TextStyle(fontSize: dropdownFontSize, color: Colors.black),
                dropdownColor: Colors.white,
                items: const [
                  DropdownMenuItem(
                    value: GobangAIDifficulty.easy,
                    child: Text('Easy', style: TextStyle(color: Colors.black)),
                  ),
                  DropdownMenuItem(
                    value: GobangAIDifficulty.medium,
                    child:
                        Text('Medium', style: TextStyle(color: Colors.black)),
                  ),
                  DropdownMenuItem(
                    value: GobangAIDifficulty.hard,
                    child: Text('Hard', style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            ],
            const SizedBox(width: 6),
            DropdownButton<int>(
              value: boardSize,
              onChanged: (v) => _setBoardSize(v!),
              style: TextStyle(fontSize: dropdownFontSize, color: Colors.black),
              dropdownColor: Colors.white,
              items: boardSizes
                  .map((size) => DropdownMenuItem(
                        value: size,
                        child: Text('${size}x$size',
                            style: TextStyle(color: Colors.black)),
                      ))
                  .toList(),
            ),
          ],
        ),
        // Voice settings (only visible in AI mode)
        if (mode == GobangMode.vsAI) ...[
          SizedBox(height: verticalPadding * 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('AI Voice:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedVoiceId,
                onChanged: (v) => _setVoiceId(v!),
                style:
                    TextStyle(fontSize: dropdownFontSize, color: Colors.black),
                dropdownColor: Colors.white,
                items: ElevenLabsService.availableVoices
                    .map((voice) => DropdownMenuItem(
                          value: voice['id'],
                          child: Text(voice['name']!,
                              style: TextStyle(color: Colors.black)),
                        ))
                    .toList(),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Voice Commentary:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontSize: isSmallPhoneLandscape
                        ? dropdownFontSize * 0.95
                        : dropdownFontSize,
                  ),
                ),
                const SizedBox(width: 4),
                Transform.scale(
                  scale: isSmallPhoneLandscape ? 0.7 : 0.85,
                  child: Switch(
                    value: _useVoiceCommentary,
                    onChanged: _toggleVoiceCommentary,
                    activeThumbColor: const Color(0xFF00B8D4),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (message != null) ...[
          SizedBox(height: verticalPadding * 0.5),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              message!,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00B8D4),
                  fontFamily: 'Baloo2'),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        if (gameOver)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B8D4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _resetGame,
              child: Text('Play Again',
                  style: TextStyle(
                      fontSize: buttonFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Baloo2')),
            ),
          ),
      ],
    );
  }

  // Board panel (game board, overlays, audio indicator)
  Widget _buildBoardPanel(
      BoxConstraints constraints,
      bool isTablet,
      bool isSmallPhoneLandscape,
      double verticalPadding,
      double buttonFontSize) {
    // Calculate board size based on available space
    final double availableWidth = constraints.maxWidth - 32; // padding
    final double availableHeight = constraints.maxHeight - 32; // padding
    final double maxBoard =
        min(availableWidth, availableHeight).clamp(200.0, 600.0);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: maxBoard,
            height: maxBoard,
            decoration: BoxDecoration(
              color: const Color(0xFFB3E5FC),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFF00B8D4), width: 5),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: boardSize,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                childAspectRatio: 1.0,
              ),
              itemCount: boardSize * boardSize,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, idx) {
                final x = idx ~/ boardSize;
                final y = idx % boardSize;
                return GestureDetector(
                  onTap: () => _handleTap(x, y),
                  child: LayoutBuilder(
                    builder: (context, cellConstraints) {
                      final cellSize = min(
                          cellConstraints.maxWidth, cellConstraints.maxHeight);
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(cellSize / 2.5),
                          border: Border.all(
                              color: const Color(0xFFB3E5FC), width: 2),
                        ),
                        child: Center(
                          child: board[x][y] == null
                              ? const SizedBox.shrink()
                              : AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  width: cellSize * 0.7,
                                  height: cellSize * 0.7,
                                  decoration: BoxDecoration(
                                    color: board[x][y] == GobangPlayer.p1
                                        ? const Color(0xFF00B8D4)
                                        : const Color(0xFFFF80AB),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: board[x][y] == GobangPlayer.p1
                                            ? Colors.cyanAccent
                                                .withValues(alpha: 0.18)
                                            : Colors.pinkAccent
                                                .withValues(alpha: 0.18),
                                        blurRadius: 12,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: board[x][y] == GobangPlayer.p1
                                          ? const Color(0xFFB2EBF2)
                                          : const Color(0xFFFFC1E3),
                                      width: 4,
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          if (aiThinking)
            Container(
              width: maxBoard,
              height: maxBoard,
              color: Colors.black.withValues(alpha: 0.18),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      '${ElevenLabsService.getVoiceNameById(_selectedVoiceId)} is ${_getThinkingVerb()}...',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00B8D4),
                        fontFamily: 'Baloo2',
                        shadows: [Shadow(color: Colors.white, blurRadius: 8)],
                      ),
                    ),
                    const SizedBox(height: 10),
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF00B8D4)),
                    ),
                  ],
                ),
              ),
            ),
          if (_isPlayingAudio && !aiThinking)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF00B8D4)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${ElevenLabsService.getVoiceNameById(_selectedVoiceId)} is speaking...',
                      style: const TextStyle(
                        color: Color(0xFF00B8D4),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
