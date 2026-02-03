import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'dart:math';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../services/elevenlabs_service.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ChessScreen extends StatefulWidget {
  const ChessScreen({super.key});

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

enum ChessMode { twoPlayer, vsAI }

enum ChessAIDifficulty { easy, medium, hard }

class _ChessScreenState extends State<ChessScreen> {
  static const List<Map<String, Color>> themes = [
    {
      'light': Color(0xFFFFF8E1),
      'dark': Color(0xFFB2DFDB),
      'highlight': Color(0xFFFFF59D),
    },
    {
      'light': Color(0xFFFFF3E0),
      'dark': Color(0xFFFFCCBC),
      'highlight': Color(0xFFFFF59D),
    },
    {
      'light': Color(0xFFE1F5FE),
      'dark': Color(0xFFB3E5FC),
      'highlight': Color(0xFFFFF59D),
    },
  ];
  int themeIdx = 0;
  late chess_lib.Chess game;
  ChessMode mode = ChessMode.vsAI;
  ChessAIDifficulty aiDifficulty = ChessAIDifficulty.hard;
  bool aiThinking = false;
  String? message;
  List<String> legalMoves = [];
  String? selectedSquare;

  // Voice and audio related variables
  final ElevenLabsService _elevenLabsService = ElevenLabsService();
  String _selectedVoiceId = '9BWtsMINqrJLrRacOk9x'; // Default voice: Aria
  bool _useVoiceCommentary = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentAIMessage;
  bool _isPlayingAudio = false;
  int _tempAudioCounter = 0;
  final Set<String> _usedMessages = {};
  // Create a queue for pending audio messages
  final List<String> _pendingAudioMessages = [];
  bool _processingAudioQueue = false;

  // Voice personalities
  final Map<String, Map<String, dynamic>> _voicePersonalities = {
    // Mary - Friendly teacher
    'mlFsujxZWlk6xPyQJgMb': {
      'style': 0.5,
      'stability': 0.45,
      'similarity_boost': 0.75,
      'speed': 1.05,
      'prefix': 'Teacher',
      'exclamations': ['Interesting!', 'Let me see...', 'Hmm...', 'Oh!', 'Wonderful!', 'Great!'],
      'name': 'Mary',
    },
    // Callum - Playful buddy
    'N2lVS1w4EtoT3dr4eOWO': {
      'style': 0.7,
      'stability': 0.35,
      'similarity_boost': 0.8,
      'speed': 1.2,
      'prefix': 'Coach',
      'exclamations': ['Awesome!', 'Got it!', 'Alright!', 'Let\'s go!', 'Sweet!', 'Cool!'],
      'name': 'Callum',
    },
    // Aria - Enthusiastic coach
    '9BWtsMINqrJLrRacOk9x': {
      'style': 0.8,
      'stability': 0.3,
      'similarity_boost': 0.7,
      'speed': 1.15,
      'prefix': 'Coach',
      'exclamations': ['Amazing!', 'Let\'s do this!', 'Woo!', 'Cool!', 'Fantastic!', 'Brilliant!'],
      'name': 'Aria',
    },
    // Madeline - Patient mentor
    'x7Pz9CsHMAlHFwKlPxu8': {
      'style': 0.55,
      'stability': 0.5,
      'similarity_boost': 0.7,
      'speed': 1.0,
      'prefix': 'Mentor',
      'exclamations': ['Wonderful!', 'I see...', 'Let\'s think...', 'Interesting choice!', 'Lovely!', 'Delightful!'],
      'name': 'Madeline',
    },
    // Haoziiiiiii - Analytical expert
    'iV5XeqzOeJzUHmdQ8FLK': {
      'style': 0.45,
      'stability': 0.6,
      'similarity_boost': 0.8,
      'speed': 1.1,
      'prefix': 'Master',
      'exclamations': ['Analyzing...', 'Processing...', 'Calculating...', 'Interesting pattern!', 'Fascinating!', 'Impressive!'],
      'name': 'Haoziiiiiii',
    },
  };

  // AI thinking messages
  final List<String> _easyThinkingMessages = ["Hmm, where to move?", "Let me try this!", "Is this a good move?", "Let's try here.", "This looks interesting!", "Maybe this piece?"];

  final List<String> _mediumThinkingMessages = ["Interesting position...", "I see several options.", "Nice strategy!", "Let me think...", "Hmm, I need to be careful.", "This is getting fun!"];

  final List<String> _hardThinkingMessages = ["Calculating...", "I see your strategy.", "Analyzing the board...", "I need to counter that.", "Interesting position!", "Let me focus..."];

  // Final victory/defeat messages
  final List<String> _finalVictoryMessages = [
    "Checkmate! I win this round. Your strategy was interesting, but I found the winning sequence.",
    "That's checkmate! Good game though. I enjoyed your creative moves in the middle game.",
    "Game over! I've won this time. You defended well, but I managed to break through.",
    "Checkmate! That was a close match. Maybe try a different opening next time?",
    "I win! You almost had me trapped earlier. Your attack was quite clever!"
  ];

  final List<String> _finalDefeatMessages = [
    "Checkmate! Well played! Your strategy was excellent. I didn't see that coming.",
    "You win! That was brilliant. Your piece coordination was impressive.",
    "Checkmate to you! I was too focused on attack and missed your defensive trap.",
    "You got me! That was a great game. Your endgame technique was superb.",
    "Congratulations on the win! I should have been more careful with my king's position."
  ];

  // Final draw messages
  final List<String> _finalDrawMessages = [
    "It's a draw! We're evenly matched. That was an intense battle of minds!",
    "Stalemate! Neither of us could find the decisive advantage. Well played!",
    "Draw by repetition. We both played cautiously. Good defensive skills!",
    "It's a tie! That was a strategic battle right to the end.",
    "Draw! Great defensive play from both of us. Should we try again?"
  ];

  @override
  void initState() {
    super.initState();
    game = chess_lib.Chess();
    legalMoves = game.moves({'verbose': true}).map((m) => m['to'].toString()).toList();

    // Initialize ElevenLabs service
    ElevenLabsService.initialize();

    _resetGame();
  }

  @override
  void dispose() {
    // Clean up audio resources
    _stopAudio();
    _audioPlayer.dispose();
    // Clear any pending messages
    _pendingAudioMessages.clear();
    super.dispose();
  }

  // Method to stop any playing audio
  Future<void> _stopAudio() async {
    if (_isPlayingAudio) {
      try {
        await _audioPlayer.stop();
        // Wait a moment for cleanup
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('Error stopping audio: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
          });
        }
      }
    }
  }

  // Helper method to get random message avoiding repetition
  String _getRandomUnusedMessage(List<String> messageList) {
    // If we've used all messages, clear the used set
    if (_usedMessages.length >= messageList.length) {
      _usedMessages.clear();
    }

    // Find an unused message
    String message;
    do {
      message = messageList[Random().nextInt(messageList.length)];
    } while (_usedMessages.contains(message) && _usedMessages.length < messageList.length);

    // Mark this message as used
    _usedMessages.add(message);
    return message;
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
      int storyId = 99999 + _tempAudioCounter; // Using high numbers to avoid conflicts

      print('Generating audio for AI message: $textToSpeak');

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

      // Remove prefix and just use the direct message
      final fullText = textToSpeak;

      if (mounted) {
        setState(() {
          _isPlayingAudio = true;
        });
      }

      final settings = {
        'stability': personality['stability'],
        'similarity_boost': personality['similarity_boost'],
        'style': personality['style'],
        'speed': personality['speed'],
      };

      // First check if we have cached audio for this message
      String? audioPath = await _checkCachedAudio(fullText, _selectedVoiceId);

      // If no cache, generate new audio
      if (audioPath == null) {
        final result = await _elevenLabsService.generateAudioWithSettings(fullText, storyId, voiceId: _selectedVoiceId, voiceSettings: settings);

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
        await _cacheAudio(fullText, _selectedVoiceId, audioPath);
      }

      // Play the audio
      await _audioPlayer.setFilePath(audioPath);
      _audioPlayer.play();

      // Set up completion listener to update state and process next message
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
    } catch (e) {
      print('Error playing AI message: $e');
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
      final cacheDir = Directory('${dir.path}/chess_audio_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final cacheFile = File('${cacheDir.path}/$hash.mp3');
      if (await cacheFile.exists()) {
        print('Using cached audio for: $text');
        return cacheFile.path;
      }
    } catch (e) {
      print('Error checking cache: $e');
    }
    return null;
  }

  Future<void> _cacheAudio(String text, String voiceId, String audioPath) async {
    try {
      final hash = text.hashCode.toString() + voiceId;
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/chess_audio_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final cacheFile = File('${cacheDir.path}/$hash.mp3');
      final originalFile = File(audioPath);

      if (await originalFile.exists()) {
        await originalFile.copy(cacheFile.path);
        print('Cached audio for: $text');
      }
    } catch (e) {
      print('Error caching audio: $e');
    }
  }

  void _resetGame() {
    // Stop any playing audio first
    _stopAudio();

    setState(() {
      game = chess_lib.Chess();
      aiThinking = false;
      message = null;
      selectedSquare = null;
      legalMoves = [];
      _currentAIMessage = null;
      _isPlayingAudio = false;
      _usedMessages.clear();
      _tempAudioCounter = 0;
    });

    if (mode == ChessMode.vsAI && game.turn == chess_lib.Color.BLACK) {
      _aiMove();
    }
  }

  void _setMode(ChessMode newMode) {
    setState(() {
      mode = newMode;
    });
    _resetGame();
  }

  void _setAIDifficulty(ChessAIDifficulty diff) {
    setState(() {
      aiDifficulty = diff;
    });
    _resetGame();
  }

  void _setTheme(int idx) {
    setState(() {
      themeIdx = idx;
    });
  }

  void _onSquareTap(String square) async {
    if (game.game_over) return;
    if (selectedSquare == null) {
      // Select piece
      if (game.get(square) != null && ((mode == ChessMode.twoPlayer) || (mode == ChessMode.vsAI && game.turn == chess_lib.Color.WHITE))) {
        setState(() {
          selectedSquare = square;
          legalMoves = game.moves({'square': square, 'verbose': true}).map<String>((m) => m['to'] as String).toList();
        });
      }
    } else {
      // Get the piece at destination before move attempt
      final destPiece = game.get(square);
      final isCapture = destPiece != null && destPiece.color == chess_lib.Color.BLACK;
      final capturedType = isCapture ? destPiece.type.toString().toLowerCase() : null;

      // Try move
      final moveResult = game.move({'from': selectedSquare, 'to': square, 'promotion': 'q'});
      if (moveResult != null) {
        setState(() {
          selectedSquare = null;
          legalMoves = [];
        });

        // Check for player's interesting moves (captures, checks, etc.)
        if (mode == ChessMode.vsAI && _useVoiceCommentary) {
          String? commentary;

          if (isCapture && capturedType != null) {
            switch (capturedType) {
              case 'q':
                commentary = "You captured my queen! That's a major advantage for you.";
                break;
              case 'r':
                commentary = "Good capture of my rook!";
                break;
              case 'n':
              case 'b':
                commentary = "Nice capture!";
                break;
              case 'p':
                commentary = "You took one of my pawns.";
                break;
            }
          } else if (game.in_check) {
            commentary = "Check! I need to protect my king.";
          }

          // Play commentary if applicable
          if (commentary != null) {
            await _playAIVoiceMessage(commentary);
          }
        }

        _checkGameOver();
        if (!game.game_over && mode == ChessMode.vsAI && game.turn == chess_lib.Color.BLACK) {
          await Future.delayed(const Duration(milliseconds: 400));
          _aiMove();
        }
      } else {
        setState(() {
          selectedSquare = null;
          legalMoves = [];
        });
      }
    }
  }

  void _aiMove() async {
    setState(() {
      aiThinking = true;
    });

    // Select a thinking message based on difficulty
    if (_useVoiceCommentary) {
      String message;
      switch (aiDifficulty) {
        case ChessAIDifficulty.easy:
          message = _getRandomUnusedMessage(_easyThinkingMessages);
          break;
        case ChessAIDifficulty.medium:
          message = _getRandomUnusedMessage(_mediumThinkingMessages);
          break;
        case ChessAIDifficulty.hard:
          message = _getRandomUnusedMessage(_hardThinkingMessages);
          break;
      }

      setState(() {
        _currentAIMessage = message;
      });

      // Add thinking message to queue - it will play after any previous messages
      if (_currentAIMessage != null) {
        _playAIVoiceMessage(_currentAIMessage!);
      }

      // Wait until all voice messages have finished playing
      while (_processingAudioQueue || _isPlayingAudio) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } else {
      // If no voice commentary, just add a small delay
      await Future.delayed(const Duration(milliseconds: 200));
    }

    String? move;
    switch (aiDifficulty) {
      case ChessAIDifficulty.easy:
        move = _randomAIMove();
        break;
      case ChessAIDifficulty.medium:
        move = _materialAIMove();
        break;
      case ChessAIDifficulty.hard:
        move = _materialAIMove(); // Placeholder for minimax
        break;
    }

    if (move != null) {
      game.move(move);
    }

    setState(() {
      aiThinking = false;
      _currentAIMessage = null;
    });

    _checkGameOver();
  }

  String? _randomAIMove() {
    final moves = game.moves();
    if (moves.isEmpty) return null;
    return moves[Random().nextInt(moves.length)];
  }

  String? _materialAIMove() {
    // Pick the move that wins the most material (very basic)
    final moves = game.moves({'verbose': true});
    if (moves.isEmpty) return null;
    moves.shuffle();
    moves.sort((a, b) => _pieceValue(b['captured']?.toString().toLowerCase()) - _pieceValue(a['captured']?.toString().toLowerCase()));
    return moves.first['san'];
  }

  int _pieceValue(String? piece) {
    switch (piece) {
      case 'p':
        return 1;
      case 'n':
      case 'b':
        return 3;
      case 'r':
        return 5;
      case 'q':
        return 9;
      default:
        return 0;
    }
  }

  void _checkGameOver() {
    String finalMessage = "";
    bool gameOver = false;

    if (game.in_checkmate) {
      gameOver = true;
      if (game.turn == chess_lib.Color.WHITE) {
        // Black wins (AI wins)
        finalMessage = _getRandomUnusedMessage(_finalVictoryMessages);
        setState(() {
          message = 'Black wins! 🎉';
        });
      } else {
        // White wins (Player wins)
        finalMessage = _getRandomUnusedMessage(_finalDefeatMessages);
        setState(() {
          message = 'White wins! 🎉';
        });
      }
    } else if (game.in_stalemate || game.in_draw) {
      gameOver = true;
      finalMessage = _getRandomUnusedMessage(_finalDrawMessages);
      setState(() {
        message = 'Draw!';
      });
    }

    // Play final voice message if game is over
    if (gameOver && _useVoiceCommentary && finalMessage.isNotEmpty) {
      _playAIVoiceMessage(finalMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = themes[themeIdx];
    // Get profile name
    String profileName = 'You';
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    if (profileProvider.selectedProfileId != null && profileProvider.profiles.isNotEmpty) {
      final profile = profileProvider.profiles.firstWhere(
        (p) => p.id == profileProvider.selectedProfileId,
        orElse: () => profileProvider.profiles.first,
      );
      profileName = profile.name;
    }
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme['light']!, theme['dark']!],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final screenHeight = MediaQuery.of(context).size.height;
                  final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
                  final shortestSide = min(screenWidth, screenHeight);
                  final isTablet = shortestSide > 600 || (shortestSide > 500 && devicePixelRatio < 2.5);
                  final isLandscape = screenWidth > screenHeight;
                  final isSmallPhoneLandscape = isLandscape && !isTablet && screenHeight < 380;

                  // Responsive sizing
                  final horizontalPadding = isTablet ? 24.0 : (isSmallPhoneLandscape ? 8.0 : (isLandscape ? 12.0 : 18.0));
                  final verticalPadding = isTablet ? 18.0 : (isSmallPhoneLandscape ? 6.0 : (isLandscape ? 8.0 : 12.0));
                  final titleFontSize = isTablet ? 32.0 : (isSmallPhoneLandscape ? 20.0 : (isLandscape ? 24.0 : 32.0));
                  final iconSize = isTablet ? 32.0 : (isSmallPhoneLandscape ? 20.0 : (isLandscape ? 24.0 : 32.0));
                  final dropdownFontSize = isTablet ? 16.0 : (isSmallPhoneLandscape ? 12.0 : (isLandscape ? 14.0 : 16.0));
                  final buttonFontSize = isTablet ? 22.0 : (isSmallPhoneLandscape ? 14.0 : (isLandscape ? 16.0 : 22.0));

                  return isLandscape
                      ? _buildLandscapeLayout(horizontalPadding, verticalPadding, titleFontSize, iconSize, dropdownFontSize, buttonFontSize, isTablet, isSmallPhoneLandscape, theme, profileName, constraints)
                      : _buildPortraitLayout(horizontalPadding, verticalPadding, titleFontSize, iconSize, dropdownFontSize, buttonFontSize, isTablet, isSmallPhoneLandscape, theme, profileName, constraints);
                },
              ),
            ),
          ),
          // Floating info button
          Positioned(
            top: 18,
            right: 18,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(32),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => _ChessInstructionsDialog(),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E6CFF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x338E6CFF),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: const Text('?', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Baloo2')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Landscape layout with two panels
  Widget _buildLandscapeLayout(
      double horizontalPadding, double verticalPadding, double titleFontSize, double iconSize, double dropdownFontSize, double buttonFontSize, bool isTablet, bool isSmallPhoneLandscape, Map<String, Color> theme, String profileName, BoxConstraints constraints) {
    return Column(
      children: [
        // Top bar
        Container(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding * 0.5),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme['dark'],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme['dark']!.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(isTablet ? 12.0 : (isSmallPhoneLandscape ? 6.0 : 8.0)),
                  child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: iconSize * 0.7),
                ),
              ),
              const Spacer(),
              Text(
                'Chess',
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: titleFontSize * 0.9,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF8E6CFF),
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              SizedBox(width: isTablet ? 40.0 : (isSmallPhoneLandscape ? 20.0 : 28.0)),
            ],
          ),
        ),
        // Two-panel layout
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left panel: Controls/settings
              Container(
                width: isTablet ? 240.0 : (isSmallPhoneLandscape ? 160.0 : 190.0),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding * 0.75, vertical: verticalPadding * 0.5),
                  child: Column(
                    children: [
                      // Legend
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: verticalPadding * 0.75, vertical: verticalPadding * 0.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(isTablet ? 12.0 : 8.0),
                        ),
                        child: Column(
                          children: [
                            Text('Players', style: TextStyle(fontWeight: FontWeight.bold, fontSize: dropdownFontSize * 0.85, color: const Color(0xFF8E6CFF))),
                            SizedBox(height: verticalPadding * 0.25),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.circle, color: Colors.black, size: 16),
                                SizedBox(width: 4),
                                Text('You', style: TextStyle(fontSize: 14, fontFamily: 'Baloo2', color: Colors.black)),
                                SizedBox(width: 12),
                                Icon(Icons.circle_outlined, color: Colors.orange, size: 16),
                                SizedBox(width: 4),
                                Text('AI', style: TextStyle(fontSize: 14, fontFamily: 'Baloo2', color: Colors.orange)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: verticalPadding * 0.75),
                      // Game modes and settings
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: verticalPadding * 0.75, vertical: verticalPadding * 0.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(isTablet ? 12.0 : 8.0),
                        ),
                        child: Column(
                          children: [
                            Text('Game Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: dropdownFontSize * 0.85, color: const Color(0xFF8E6CFF))),
                            SizedBox(height: verticalPadding * 0.25),
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: ChoiceChip(
                                        label: Text('2 Players', style: TextStyle(fontFamily: 'Baloo2', fontWeight: FontWeight.bold, color: Colors.black, fontSize: dropdownFontSize * 0.7)),
                                        selected: mode == ChessMode.twoPlayer,
                                        onSelected: (_) => _setMode(ChessMode.twoPlayer),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: verticalPadding * 0.25),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ChoiceChip(
                                        label: Text('vs chatGPT', style: TextStyle(fontFamily: 'Baloo2', fontWeight: FontWeight.bold, color: Colors.black, fontSize: dropdownFontSize * 0.7)),
                                        selected: mode == ChessMode.vsAI,
                                        onSelected: (_) => _setMode(ChessMode.vsAI),
                                      ),
                                    ),
                                  ],
                                ),
                                if (mode == ChessMode.vsAI) ...[
                                  SizedBox(height: verticalPadding * 0.25),
                                  DropdownButton<ChessAIDifficulty>(
                                    value: aiDifficulty,
                                    onChanged: (v) => _setAIDifficulty(v!),
                                    style: TextStyle(fontSize: dropdownFontSize * 0.75, color: Colors.black),
                                    isExpanded: true,
                                    isDense: true,
                                    items: const [
                                      DropdownMenuItem(
                                        value: ChessAIDifficulty.easy,
                                        child: Text('Easy', style: TextStyle(color: Colors.black)),
                                      ),
                                      DropdownMenuItem(
                                        value: ChessAIDifficulty.medium,
                                        child: Text('Medium', style: TextStyle(color: Colors.black)),
                                      ),
                                      DropdownMenuItem(
                                        value: ChessAIDifficulty.hard,
                                        child: Text('Hard', style: TextStyle(color: Colors.black)),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Voice settings (only visible in AI mode)
                      if (mode == ChessMode.vsAI) ...[
                        SizedBox(height: verticalPadding * 0.75),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: verticalPadding * 0.75, vertical: verticalPadding * 0.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(isTablet ? 12.0 : 8.0),
                          ),
                          child: Column(
                            children: [
                              Text('Voice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: dropdownFontSize * 0.85, color: const Color(0xFF8E6CFF))),
                              SizedBox(height: verticalPadding * 0.25),
                              DropdownButton<String>(
                                value: _selectedVoiceId,
                                onChanged: (v) => setState(() => _selectedVoiceId = v!),
                                style: TextStyle(fontSize: dropdownFontSize * 0.75, color: Colors.black),
                                isExpanded: true,
                                isDense: true,
                                items: [
                                  DropdownMenuItem(value: 'mlFsujxZWlk6xPyQJgMb', child: Text('Mary', style: TextStyle(color: Colors.black, fontSize: dropdownFontSize * 0.75))),
                                  DropdownMenuItem(value: 'N2lVS1w4EtoT3dr4eOWO', child: Text('Callum', style: TextStyle(color: Colors.black, fontSize: dropdownFontSize * 0.75))),
                                  DropdownMenuItem(value: '9BWtsMINqrJLrRacOk9x', child: Text('Aria', style: TextStyle(color: Colors.black, fontSize: dropdownFontSize * 0.75))),
                                  DropdownMenuItem(value: 'x7Pz9CsHMAlHFwKlPxu8', child: Text('Madeline', style: TextStyle(color: Colors.black, fontSize: dropdownFontSize * 0.75))),
                                  DropdownMenuItem(value: 'iV5XeqzOeJzUHmdQ8FLK', child: Text('Haoziiiiiii', style: TextStyle(color: Colors.black, fontSize: dropdownFontSize * 0.75))),
                                ],
                              ),
                              SizedBox(height: verticalPadding * 0.25),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Transform.scale(
                                    scale: isTablet ? 0.8 : (isSmallPhoneLandscape ? 0.6 : 0.7),
                                    child: Switch(
                                      value: _useVoiceCommentary,
                                      onChanged: (value) {
                                        setState(() {
                                          _useVoiceCommentary = value;
                                          if (!value) _stopAudio();
                                        });
                                      },
                                      activeColor: const Color(0xFF8E6CFF),
                                    ),
                                  ),
                                  SizedBox(width: verticalPadding * 0.25),
                                  Text('Commentary', style: TextStyle(fontWeight: FontWeight.w600, fontSize: dropdownFontSize * 0.75)),
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
                          padding: EdgeInsets.symmetric(horizontal: verticalPadding * 0.75, vertical: verticalPadding * 0.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(isTablet ? 12.0 : 8.0),
                          ),
                          child: Text(
                            _getWinMessage(message, profileName),
                            style: TextStyle(fontSize: dropdownFontSize * 0.9, fontWeight: FontWeight.bold, color: Color(0xFF8E6CFF), fontFamily: 'Baloo2'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      if (game.game_over) ...[
                        SizedBox(height: verticalPadding * 0.75),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8E6CFF),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          onPressed: _resetGame,
                          child: Text('Play Again', style: TextStyle(fontSize: dropdownFontSize * 0.9, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Baloo2')),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Right panel: Chess board
              Expanded(
                child: LayoutBuilder(
                  builder: (context, rightPanelConstraints) {
                    return Padding(
                      padding: EdgeInsets.all(horizontalPadding * 0.5),
                      child: _buildBoardPanel(rightPanelConstraints, isTablet, isSmallPhoneLandscape, verticalPadding, buttonFontSize, theme),
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
      double horizontalPadding, double verticalPadding, double titleFontSize, double iconSize, double dropdownFontSize, double buttonFontSize, bool isTablet, bool isSmallPhoneLandscape, Map<String, Color> theme, String profileName, BoxConstraints constraints) {
    return Column(
      children: [
        const SizedBox(height: 18),
        Row(
          children: [
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                decoration: BoxDecoration(
                  color: theme['dark'],
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme['dark']!.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 32),
              ),
            ),
            const Spacer(),
            const Text(
              'Chess',
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
        const SizedBox(height: 10),
        _buildLegend(theme),
        const SizedBox(height: 8),
        _buildControlsPanel(dropdownFontSize, buttonFontSize, verticalPadding, isSmallPhoneLandscape, theme, profileName),
        const SizedBox(height: 10),
        Expanded(
          child: _buildBoardPanel(constraints, isTablet, isSmallPhoneLandscape, verticalPadding, buttonFontSize, theme),
        ),
        const SizedBox(height: 18),
        if (message != null)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              _getWinMessage(message, profileName),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF8E6CFF), fontFamily: 'Baloo2'),
            ),
          ),
        if (game.game_over)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8E6CFF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 18),
            ),
            onPressed: _resetGame,
            child: const Text('Play Again', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Baloo2')),
          ),
        const SizedBox(height: 18),
      ],
    );
  }

  // Legend for player/AI colors
  Widget _buildLegend(Map<String, Color> theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.circle, color: Colors.black, size: 18),
        SizedBox(width: 6),
        Text('You', style: TextStyle(fontSize: 16, fontFamily: 'Baloo2', color: Colors.black)),
        SizedBox(width: 18),
        Icon(Icons.circle_outlined, color: Colors.orange, size: 18),
        SizedBox(width: 6),
        Text('chatGPT', style: TextStyle(fontSize: 16, fontFamily: 'Baloo2', color: Colors.orange)),
      ],
    );
  }

  // Controls/settings panel (mode, difficulty, voice, etc.)
  Widget _buildControlsPanel(double dropdownFontSize, double buttonFontSize, double verticalPadding, bool isSmallPhoneLandscape, Map<String, Color> theme, [String profileName = 'You']) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLegend(theme),
        SizedBox(height: verticalPadding * 0.5),
        // Game modes and settings
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          children: [
            ChoiceChip(
              label: const Text('2 Players', style: TextStyle(fontFamily: 'Baloo2', fontWeight: FontWeight.bold, color: Colors.black)),
              selected: mode == ChessMode.twoPlayer,
              onSelected: (_) => _setMode(ChessMode.twoPlayer),
            ),
            ChoiceChip(
              label: const Text('Play vs chatGPT', style: TextStyle(fontFamily: 'Baloo2', fontWeight: FontWeight.bold, color: Colors.black)),
              selected: mode == ChessMode.vsAI,
              onSelected: (_) => _setMode(ChessMode.vsAI),
            ),
            if (mode == ChessMode.vsAI) ...[
              const SizedBox(width: 8),
              DropdownButton<ChessAIDifficulty>(
                value: aiDifficulty,
                onChanged: (v) => _setAIDifficulty(v!),
                style: TextStyle(fontSize: dropdownFontSize, color: Colors.black),
                dropdownColor: Colors.white,
                items: const [
                  DropdownMenuItem(
                    value: ChessAIDifficulty.easy,
                    child: Text('Easy', style: TextStyle(color: Colors.black)),
                  ),
                  DropdownMenuItem(
                    value: ChessAIDifficulty.medium,
                    child: Text('Medium', style: TextStyle(color: Colors.black)),
                  ),
                  DropdownMenuItem(
                    value: ChessAIDifficulty.hard,
                    child: Text('Hard', style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            ],
          ],
        ),
        SizedBox(height: verticalPadding * 0.5),
        // Voice settings (only visible in AI mode)
        if (mode == ChessMode.vsAI) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('AI Voice:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedVoiceId,
                onChanged: (v) => setState(() => _selectedVoiceId = v!),
                style: TextStyle(fontSize: dropdownFontSize, color: Colors.black),
                dropdownColor: Colors.white,
                items: [
                  DropdownMenuItem(value: 'mlFsujxZWlk6xPyQJgMb', child: Text('Mary', style: TextStyle(color: Colors.black))),
                  DropdownMenuItem(value: 'N2lVS1w4EtoT3dr4eOWO', child: Text('Callum', style: TextStyle(color: Colors.black))),
                  DropdownMenuItem(value: '9BWtsMINqrJLrRacOk9x', child: Text('Aria', style: TextStyle(color: Colors.black))),
                  DropdownMenuItem(value: 'x7Pz9CsHMAlHFwKlPxu8', child: Text('Madeline', style: TextStyle(color: Colors.black))),
                  DropdownMenuItem(value: 'iV5XeqzOeJzUHmdQ8FLK', child: Text('Haoziiiiiii', style: TextStyle(color: Colors.black))),
                ],
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
                    fontSize: isSmallPhoneLandscape ? dropdownFontSize * 0.95 : dropdownFontSize,
                  ),
                ),
                const SizedBox(width: 4),
                Transform.scale(
                  scale: isSmallPhoneLandscape ? 0.7 : 0.85,
                  child: Switch(
                    value: _useVoiceCommentary,
                    onChanged: (value) {
                      setState(() {
                        _useVoiceCommentary = value;
                        if (!value) _stopAudio();
                      });
                    },
                    activeColor: const Color(0xFF8E6CFF),
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
              _getWinMessage(message, profileName),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF8E6CFF), fontFamily: 'Baloo2'),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        if (game.game_over)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E6CFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _resetGame,
              child: Text('Play Again', style: TextStyle(fontSize: buttonFontSize, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Baloo2')),
            ),
          ),
      ],
    );
  }

  // Board panel (chess board, overlays, audio indicator)
  Widget _buildBoardPanel(BoxConstraints constraints, bool isTablet, bool isSmallPhoneLandscape, double verticalPadding, double buttonFontSize, Map<String, Color> theme) {
    // Calculate board size based on available space
    final double availableWidth = constraints.maxWidth - 32; // padding
    final double availableHeight = constraints.maxHeight - 32; // padding
    final double maxBoard = min(availableWidth, availableHeight).clamp(200.0, 600.0);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: maxBoard,
            height: maxBoard,
            decoration: BoxDecoration(
              color: theme['dark'],
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: theme['highlight']!, width: 5),
              boxShadow: [
                BoxShadow(
                  color: theme['highlight']!.withOpacity(0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: 1.0,
              ),
              itemCount: 64,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, idx) {
                final rank = 8 - (idx ~/ 8);
                final file = String.fromCharCode('a'.codeUnitAt(0) + (idx % 8));
                final square = '$file$rank';
                final piece = game.get(square);
                final isLight = ((idx ~/ 8) + (idx % 8)) % 2 == 0;
                final isSelected = selectedSquare == square;
                final isLegal = legalMoves.contains(square);
                return GestureDetector(
                  onTap: () => _onSquareTap(square),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme['highlight']
                          : isLegal
                              ? theme['highlight']!.withOpacity(0.7)
                              : isLight
                                  ? theme['light']
                                  : theme['dark'],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme['highlight']!.withOpacity(0.18), width: 2),
                    ),
                    child: Center(
                      child: piece == null
                          ? const SizedBox.shrink()
                          : Text(
                              piece.color == chess_lib.Color.WHITE ? _playerPieceSymbol(piece.type.toString().toLowerCase()) : _aiPieceSymbol(piece.type.toString().toLowerCase()),
                              style: TextStyle(
                                fontSize: maxBoard / 10,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Baloo2',
                                color: piece.color == chess_lib.Color.WHITE ? Colors.black : Colors.orange,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 4,
                                    offset: const Offset(1, 2),
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
          // Centered AI thinking indicator overlay
          if (aiThinking)
            Container(
              width: maxBoard,
              height: maxBoard,
              color: Colors.black.withOpacity(0.18),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${_getSelectedVoiceName()} is ${_getThinkingVerb()}...',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Baloo2',
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
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

  String _playerPieceSymbol(String type) {
    // Solid black Unicode for user
    switch (type) {
      case 'p':
        return '♟';
      case 'r':
        return '♜';
      case 'n':
        return '♞';
      case 'b':
        return '♝';
      case 'q':
        return '♛';
      case 'k':
        return '♚';
      default:
        return '?';
    }
  }

  String _aiPieceSymbol(String type) {
    // Outlined white Unicode for AI
    switch (type) {
      case 'p':
        return '♙';
      case 'r':
        return '♖';
      case 'n':
        return '♘';
      case 'b':
        return '♗';
      case 'q':
        return '♕';
      case 'k':
        return '♔';
      default:
        return '?';
    }
  }

  // Helper method to get the voice name
  String _getSelectedVoiceName() {
    return _voicePersonalities[_selectedVoiceId]?['name'] ?? 'AI';
  }

  // Helper method to get a thinking verb
  String _getThinkingVerb() {
    final verbs = ['thinking', 'pondering', 'calculating', 'planning', 'strategizing', 'contemplating'];
    return verbs[Random().nextInt(verbs.length)];
  }
}

// Add the playful instructions dialog widget:
class _ChessInstructionsDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      backgroundColor: const Color(0xFFF3E8FF),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('How to Play Chess', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF8E6CFF), fontFamily: 'Baloo2')),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('♚', style: TextStyle(fontSize: 32)),
                  SizedBox(width: 8),
                  Text('♛', style: TextStyle(fontSize: 32)),
                  SizedBox(width: 8),
                  Text('♜', style: TextStyle(fontSize: 32)),
                  SizedBox(width: 8),
                  Text('♝', style: TextStyle(fontSize: 32)),
                  SizedBox(width: 8),
                  Text('♞', style: TextStyle(fontSize: 32)),
                  SizedBox(width: 8),
                  Text('♟', style: TextStyle(fontSize: 32)),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Move your pieces to try to checkmate the orange king!', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontFamily: 'Baloo2')),
              const SizedBox(height: 18),
              Row(
                children: const [
                  Text('♟', style: TextStyle(fontSize: 28)),
                  SizedBox(width: 8),
                  Expanded(child: Text('Pawns move forward, capture diagonally.', style: TextStyle(fontSize: 16, fontFamily: 'Baloo2'))),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: const [
                  Text('♜', style: TextStyle(fontSize: 28)),
                  SizedBox(width: 8),
                  Expanded(child: Text('Rooks move in straight lines.', style: TextStyle(fontSize: 16, fontFamily: 'Baloo2'))),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: const [
                  Text('♞', style: TextStyle(fontSize: 28)),
                  SizedBox(width: 8),
                  Expanded(child: Text('Knights jump in an L-shape.', style: TextStyle(fontSize: 16, fontFamily: 'Baloo2'))),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: const [
                  Text('♝', style: TextStyle(fontSize: 28)),
                  SizedBox(width: 8),
                  Expanded(child: Text('Bishops move diagonally.', style: TextStyle(fontSize: 16, fontFamily: 'Baloo2'))),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: const [
                  Text('♛', style: TextStyle(fontSize: 28)),
                  SizedBox(width: 8),
                  Expanded(child: Text('The Queen can go any direction!', style: TextStyle(fontSize: 16, fontFamily: 'Baloo2'))),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: const [
                  Text('♚', style: TextStyle(fontSize: 28)),
                  SizedBox(width: 8),
                  Expanded(child: Text('Protect your King! If he is trapped, you lose.', style: TextStyle(fontSize: 16, fontFamily: 'Baloo2'))),
                ],
              ),
              const SizedBox(height: 18),
              const Text('Tip: Try to control the center squares and work together with your pieces!', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontFamily: 'Baloo2', color: Color(0xFF43C465))),
              const SizedBox(height: 18),
              const Text('Have fun and good luck! 🎉', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Baloo2', color: Color(0xFFFF9F43))),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8E6CFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 14),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Baloo2')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper to convert win message
String _getWinMessage(String? msg, String profileName) {
  if (msg == null) return '';
  if (msg.contains('White wins')) return '$profileName wins! 🎉';
  if (msg.contains('Black wins')) return 'AI wins! 🎉';
  if (msg.contains('Draw')) return "It's a draw!";
  return msg;
}
