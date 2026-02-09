import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../services/elevenlabs_service.dart';
import '../services/theme_service.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class MemoryMatchScreen extends StatefulWidget {
  const MemoryMatchScreen({super.key});

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  // Available grid sizes (square grids for clean progression)
  static const List<Map<String, int>> gridSizes = [
    {'rows': 4, 'cols': 4, 'pairs': 8}, // 4x4 = 16 cards, 8 pairs (Easy)
    {'rows': 6, 'cols': 6, 'pairs': 18}, // 6x6 = 36 cards, 18 pairs (Medium)
    {'rows': 8, 'cols': 8, 'pairs': 32}, // 8x8 = 64 cards, 32 pairs (Hard)
  ];

  int _currentGridIndex = 0; // Default to 4x4
  int get gridRows => gridSizes[_currentGridIndex]['rows']!;
  int get gridCols => gridSizes[_currentGridIndex]['cols']!;
  int get totalPairs => gridSizes[_currentGridIndex]['pairs']!;
  int get totalCards => gridRows * gridCols;

  late List<_CardData> cards;
  int moves = 0;
  int pairsFound = 0;
  int? firstFlipped;
  int? secondFlipped;
  bool waiting = false;
  String? feedbackEmoji;

  // Voice and audio related variables
  final ElevenLabsService _elevenLabsService = ElevenLabsService();
  String _selectedVoiceId = '9BWtsMINqrJLrRacOk9x'; // Default voice: Aria
  bool _useVoiceCommentary = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;
  int _tempAudioCounter = 0;
  final List<String> _pendingAudioMessages = [];
  bool _processingAudioQueue = false;
  final Set<String> _usedMessages = {};

  // Voice personalities with fun settings
  final Map<String, Map<String, dynamic>> _voicePersonalities = {
    // Mary - Friendly teacher
    'mlFsujxZWlk6xPyQJgMb': {
      'style': 0.6,
      'stability': 0.45,
      'similarity_boost': 0.75,
      'speed': 1.1,
      'name': 'Mary',
      'exclamations': [
        'Interesting!',
        'Let me see...',
        'Oh!',
        'Wonderful!',
        'Great!'
      ],
    },
    // Callum - Playful buddy
    'N2lVS1w4EtoT3dr4eOWO': {
      'style': 0.8,
      'stability': 0.35,
      'similarity_boost': 0.8,
      'speed': 1.2,
      'name': 'Callum',
      'exclamations': ['Awesome!', 'Got it!', 'Alright!', 'Sweet!', 'Cool!'],
    },
    // Aria - Enthusiastic coach
    '9BWtsMINqrJLrRacOk9x': {
      'style': 0.8,
      'stability': 0.3,
      'similarity_boost': 0.7,
      'speed': 1.15,
      'name': 'Aria',
      'exclamations': [
        'Amazing!',
        'Let\'s do this!',
        'Woo!',
        'Fantastic!',
        'Brilliant!'
      ],
    },
  };

  // Commentary message collections
  final List<String> _matchFoundMessages = [
    "Great match!",
    "You found a pair!",
    "Nice memory skills!",
    "Perfect match!",
    "That's a pair!",
    "You're getting good at this!",
    "Excellent matching!",
  ];

  final List<String> _noMatchMessages = [
    "Not quite!",
    "Try again!",
    "Almost there!",
    "Keep trying!",
    "Those don't match, but you're getting closer!",
    "Remember where that one was!",
  ];

  final List<String> _victoryMessages = [
    "Congratulations! You found all the pairs!",
    "You've completed the memory challenge! Well done!",
    "Amazing job! Your memory skills are top-notch!",
    "Victory! You matched all the pairs perfectly!",
    "Great work! You've mastered this memory game!",
  ];

  @override
  void initState() {
    super.initState();
    // Initialize ElevenLabs service
    ElevenLabsService.initialize();
    _resetGame();
  }

  @override
  void dispose() {
    _stopAudio();
    _audioPlayer.dispose();
    _pendingAudioMessages.clear();
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

    const List<String> emojiPool = [
      '🐶',
      '🐱',
      '🐭',
      '🦊',
      '🐻',
      '🐼',
      '🐨',
      '🦁',
      '🐯',
      '🐸',
      '🐵',
      '🐷',
      '🐰',
      '🦄',
      '🐔',
      '🐧',
      '🐢',
      '🐙',
      '🐞',
      '🦋',
      '🦉',
      '🦓',
      '🦒',
      '🦘',
      '🐺',
      '🦅',
      '🐠',
      '🦈',
      '🐙',
      '🦀',
      '🦞',
      '🐌',
      '🦗',
      '🕷️',
      '🐝',
      '🐛',
      '🦄',
      '🐉',
      '🦕',
      '🦖'
    ];
    final rand = math.Random();
    final Set<String> picked = {};

    // Pick the required number of unique emojis for current grid size
    while (picked.length < totalPairs) {
      picked.add(emojiPool[rand.nextInt(emojiPool.length)]);
    }

    final List<String> values = picked.toList();
    assert(values.length == totalPairs && values.toSet().length == totalPairs,
        'Must have $totalPairs unique emojis');

    // Create pairs by duplicating each emoji
    final allValues = [...values, ...values];
    allValues.shuffle(rand);

    // Validation
    final Map<String, int> emojiCount = {};
    for (final e in allValues) {
      emojiCount[e] = (emojiCount[e] ?? 0) + 1;
    }
    assert(emojiCount.values.every((count) => count == 2),
        'Each emoji must appear exactly twice: $emojiCount');
    assert(allValues.length == totalCards,
        'Total cards must equal grid size: ${allValues.length} != $totalCards');

    cards = List.generate(totalCards, (i) => _CardData(value: allValues[i]));
    moves = 0;
    pairsFound = 0;
    firstFlipped = null;
    secondFlipped = null;
    waiting = false;
    feedbackEmoji = null;
    _pendingAudioMessages.clear();
    _usedMessages.clear();

    // Play a welcome message with 50% probability
    if (_useVoiceCommentary && math.Random().nextBool()) {
      _playVoiceMessage(
          "Let's play Memory Match! Find all the matching pairs!");
    }

    setState(() {});
  }

  void _onCardTap(int idx) async {
    if (waiting ||
        cards[idx].isMatched ||
        idx == firstFlipped ||
        idx == secondFlipped) {
      return;
    }
    setState(() {
      if (firstFlipped == null) {
        firstFlipped = idx;
      } else if (secondFlipped == null) {
        secondFlipped = idx;
        moves++;
        waiting = true;
      }
    });
    if (firstFlipped != null && secondFlipped != null) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (cards[firstFlipped!].value == cards[secondFlipped!].value) {
        setState(() {
          cards[firstFlipped!].isMatched = true;
          cards[secondFlipped!].isMatched = true;
          pairsFound = cards.where((c) => c.isMatched).length ~/ 2;
          feedbackEmoji = '🎉';
        });

        // Play match found message with 40% probability
        if (_useVoiceCommentary && math.Random().nextDouble() < 0.4) {
          _playVoiceMessage(_getUniqueMessage(_matchFoundMessages));
        }

        // Special progress messages at certain milestones
        final halfwayPoint = totalPairs ~/ 2;
        final almostDonePoint = totalPairs - 1;

        if (_useVoiceCommentary && pairsFound == halfwayPoint) {
          // Always play halfway message
          final remaining = totalPairs - pairsFound;
          _playVoiceMessage(
              "You're halfway there! $remaining more pairs to go!");
        } else if (_useVoiceCommentary && pairsFound == almostDonePoint) {
          // Always play almost done message
          _playVoiceMessage("Just one more pair to find!");
        } else if (_useVoiceCommentary && pairsFound == totalPairs) {
          // Always play victory message
          _playVoiceMessage(_getUniqueMessage(_victoryMessages));
        }

        // Show victory popup when all pairs are found
        if (pairsFound == totalPairs) {
          // Delay the popup slightly to let the final match animation complete
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              _showVictoryPopup();
            }
          });
        }
      } else {
        setState(() {
          feedbackEmoji = '😅';
        });

        // Play no match message with 25% probability
        if (_useVoiceCommentary && math.Random().nextDouble() < 0.25) {
          _playVoiceMessage(_getUniqueMessage(_noMatchMessages));
        }
      }
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        firstFlipped = null;
        secondFlipped = null;
        waiting = false;
        feedbackEmoji = null;
      });
    }
  }

  // Helper method to get a unique message that hasn't been used recently
  String _getUniqueMessage(List<String> messageList) {
    // If we've used all or nearly all messages, reset the used set
    if (_usedMessages.length >= messageList.length - 1) {
      _usedMessages.clear();
    }

    // Find a message we haven't used yet
    String message;
    do {
      message = messageList[math.Random().nextInt(messageList.length)];
    } while (_usedMessages.contains(message) &&
        _usedMessages.length < messageList.length);

    // Mark this message as used
    _usedMessages.add(message);
    return message;
  }

  Future<void> _playVoiceMessage(String textToSpeak) async {
    if (!_useVoiceCommentary) return;

    // Add message to the queue
    _pendingAudioMessages.add(textToSpeak);

    // Start processing the queue if not already doing so
    if (!_processingAudioQueue) {
      _processAudioQueue();
    }
  }

  // Process audio messages in sequence
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

      debugPrint('Generating audio for message: $textToSpeak');

      // Get personality settings for the selected voice
      final personality = _voicePersonalities[_selectedVoiceId] ??
          {
            'style': 0.6,
            'stability': 0.5,
            'similarity_boost': 0.8,
            'speed': 1.1,
            'name': 'Voice',
            'exclamations': ['Oh!'],
          };

      // Add a random exclamation occasionally
      String enhancedText = textToSpeak;
      if (!textToSpeak.contains('!') &&
          !textToSpeak.contains('?') &&
          math.Random().nextDouble() < 0.4) {
        final exclamations = personality['exclamations'] as List<String>;
        final exclamation =
            exclamations[math.Random().nextInt(exclamations.length)];
        enhancedText = "$exclamation $textToSpeak";
      }

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
      debugPrint('Error playing voice message: $e');
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
      final cacheDir = Directory('${dir.path}/memory_match_audio_cache');
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
      final cacheDir = Directory('${dir.path}/memory_match_audio_cache');
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

  void _toggleVoiceCommentary(bool value) {
    setState(() {
      _useVoiceCommentary = value;
    });

    if (!_useVoiceCommentary) {
      _stopAudio();
    } else {
      // Play a toggle-on message
      _playVoiceMessage("Voice commentary enabled. Let's continue!");
    }
  }

  void _setVoiceId(String voiceId) {
    if (_selectedVoiceId != voiceId) {
      setState(() {
        _selectedVoiceId = voiceId;
      });

      if (_useVoiceCommentary) {
        // Play a voice change message
        final name = _voicePersonalities[voiceId]?['name'] ?? 'Voice';
        _playVoiceMessage("Hello! I'm $name, your new memory game companion!");
      }
    }
  }

  void _setGridSize(int gridIndex) {
    if (_currentGridIndex != gridIndex) {
      setState(() {
        _currentGridIndex = gridIndex;
      });
      _resetGame();
    }
  }

  void _showVictoryPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Celebration emoji
                const Text('🎉', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),

                // Victory title
                const Text(
                  'Congratulations!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF43C465),
                    fontFamily: 'Baloo2',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Victory message
                const Text(
                  'You found all pairs!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666666),
                    fontFamily: 'Baloo2',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Game stats
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(
                            '$moves',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF43C465),
                              fontFamily: 'Baloo2',
                            ),
                          ),
                          const Text(
                            'Moves',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF666666),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: const Color(0xFFE0E0E0),
                      ),
                      Column(
                        children: [
                          Text(
                            '$totalPairs',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF9F43),
                              fontFamily: 'Baloo2',
                            ),
                          ),
                          const Text(
                            'Pairs',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF666666),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: const Color(0xFFE0E0E0),
                      ),
                      Column(
                        children: [
                          Text(
                            '$gridRows×$gridCols',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B5CF6),
                              fontFamily: 'Baloo2',
                            ),
                          ),
                          const Text(
                            'Grid',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF666666),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE5E7EB),
                          foregroundColor: const Color(0xFF374151),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop(); // Go back to main menu
                        },
                        child: const Text(
                          'Main Menu',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Baloo2',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF43C465),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _resetGame();
                        },
                        child: const Text(
                          'Play Again',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Baloo2',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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

              // Enhanced device detection (same as other screens)
              final shortestSide = math.min(screenWidth, screenHeight);
              final isTablet = shortestSide > 600 ||
                  (shortestSide > 500 && devicePixelRatio < 2.5);
              final isLandscape = screenWidth > screenHeight;
              final isSmallPhoneLandscape =
                  isLandscape && !isTablet && screenHeight < 380;

              // Enhanced responsive sizing with three-tier system
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
                      : (isLandscape ? 24.0 : 28.0));
              final iconSize = isTablet
                  ? 32.0
                  : (isSmallPhoneLandscape
                      ? 20.0
                      : (isLandscape ? 24.0 : 28.0));
              final statsFontSize = isTablet
                  ? 20.0
                  : (isSmallPhoneLandscape
                      ? 14.0
                      : (isLandscape ? 16.0 : 18.0));
              final dropdownFontSize = isTablet
                  ? 16.0
                  : (isSmallPhoneLandscape
                      ? 12.0
                      : (isLandscape ? 14.0 : 16.0));
              final emojiFontSize = isTablet
                  ? 44.0
                  : (isSmallPhoneLandscape
                      ? 28.0
                      : (isLandscape ? 32.0 : 40.0));

              final double availableWidth =
                  constraints.maxWidth - (horizontalPadding * 2);
              final double availableHeight =
                  constraints.maxHeight - (isLandscape ? 180 : 220);
              final double maxBoardSize = math
                  .min(availableWidth, availableHeight)
                  .clamp(
                      isTablet
                          ? 220.0
                          : (isSmallPhoneLandscape
                              ? 160.0
                              : (isLandscape ? 180.0 : 200.0)),
                      isTablet
                          ? 520.0
                          : (isSmallPhoneLandscape
                              ? 300.0
                              : (isLandscape ? 380.0 : 450.0)));
              final double cardSize =
                  (maxBoardSize - 16) / math.max(gridRows, gridCols);
              return isLandscape
                  ? _buildLandscapeLayout(
                      horizontalPadding,
                      verticalPadding,
                      titleFontSize,
                      iconSize,
                      statsFontSize,
                      dropdownFontSize,
                      emojiFontSize,
                      maxBoardSize,
                      cardSize,
                      isTablet,
                      isSmallPhoneLandscape)
                  : _buildPortraitLayout(
                      horizontalPadding,
                      verticalPadding,
                      titleFontSize,
                      iconSize,
                      statsFontSize,
                      dropdownFontSize,
                      emojiFontSize,
                      maxBoardSize,
                      cardSize,
                      isTablet,
                      isSmallPhoneLandscape);
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
      double statsFontSize,
      double dropdownFontSize,
      double emojiFontSize,
      double maxBoardSize,
      double cardSize,
      bool isTablet,
      bool isSmallPhoneLandscape) {
    return Column(children: [
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
                  color: Color(0xFF43C465),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x3343C465),
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
              'Memory Match',
              style: TextStyle(
                fontFamily: 'Baloo2',
                fontSize: titleFontSize * 0.9,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF43C465),
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            SizedBox(
                width: isTablet ? 40.0 : (isSmallPhoneLandscape ? 20.0 : 28.0)),
          ],
        ),
      ),
      // Two-panel layout
      Expanded(
        child: Row(
          children: [
            // Left panel - Controls (compact and scrollable)
            SizedBox(
              width: isTablet ? 220.0 : (isSmallPhoneLandscape ? 160.0 : 180.0),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding * 0.75,
                    vertical: verticalPadding * 0.5),
                child: Column(
                  children: [
                    // Grid size selector
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
                          Text('Grid Size',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: dropdownFontSize * 0.85,
                                  color: const Color(0xFF43C465))),
                          SizedBox(height: verticalPadding * 0.25),
                          DropdownButton<int>(
                            value: _currentGridIndex,
                            onChanged: (v) => _setGridSize(v!),
                            style: TextStyle(
                                fontSize: dropdownFontSize * 0.75,
                                color: Colors.black),
                            isExpanded: true,
                            isDense: true,
                            items: gridSizes.asMap().entries.map((entry) {
                              final index = entry.key;
                              final size = entry.value;
                              return DropdownMenuItem(
                                value: index,
                                child: Text(
                                    '${size['rows']}×${size['cols']} (${size['pairs']} pairs)',
                                    style: TextStyle(
                                        fontSize: dropdownFontSize * 0.75)),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: verticalPadding * 0.75),
                    // Voice settings
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
                                  color: const Color(0xFF43C465))),
                          SizedBox(height: verticalPadding * 0.25),
                          DropdownButton<String>(
                            value: _selectedVoiceId,
                            onChanged: (v) => _setVoiceId(v!),
                            style: TextStyle(
                                fontSize: dropdownFontSize * 0.75,
                                color: Colors.black),
                            isExpanded: true,
                            isDense: true,
                            items: [
                              DropdownMenuItem(
                                  value: 'mlFsujxZWlk6xPyQJgMb',
                                  child: Text('Mary',
                                      style: TextStyle(
                                          fontSize: dropdownFontSize * 0.75))),
                              DropdownMenuItem(
                                  value: 'N2lVS1w4EtoT3dr4eOWO',
                                  child: Text('Callum',
                                      style: TextStyle(
                                          fontSize: dropdownFontSize * 0.75))),
                              DropdownMenuItem(
                                  value: '9BWtsMINqrJLrRacOk9x',
                                  child: Text('Aria',
                                      style: TextStyle(
                                          fontSize: dropdownFontSize * 0.75))),
                            ],
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
                                  activeThumbColor: const Color(0xFF43C465),
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
                    SizedBox(height: verticalPadding * 0.75),
                    // Game stats
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
                          Text('Stats',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: dropdownFontSize * 0.85,
                                  color: const Color(0xFF43C465))),
                          SizedBox(height: verticalPadding * 0.25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                children: [
                                  Text('$moves',
                                      style: TextStyle(
                                          fontSize: statsFontSize * 0.8,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF43C465),
                                          fontFamily: 'Baloo2')),
                                  Text('Moves',
                                      style: TextStyle(
                                          fontSize: dropdownFontSize * 0.65,
                                          color: Colors.grey[600])),
                                ],
                              ),
                              Column(
                                children: [
                                  Text('$pairsFound/$totalPairs',
                                      style: TextStyle(
                                          fontSize: statsFontSize * 0.8,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFFF9F43),
                                          fontFamily: 'Baloo2')),
                                  Text('Pairs',
                                      style: TextStyle(
                                          fontSize: dropdownFontSize * 0.65,
                                          color: Colors.grey[600])),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Feedback emoji
                    SizedBox(height: verticalPadding * 0.75),
                    SizedBox(
                      height: emojiFontSize * 0.6 + 8,
                      child: Center(
                        child: feedbackEmoji != null
                            ? Text(feedbackEmoji!,
                                style: TextStyle(fontSize: emojiFontSize * 0.6))
                            : null,
                      ),
                    ),
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
                  final optimalBoardSize = math
                      .min(availableWidth, availableHeight)
                      .clamp(
                          isTablet
                              ? 300.0
                              : (isSmallPhoneLandscape ? 200.0 : 250.0),
                          isTablet
                              ? 600.0
                              : (isSmallPhoneLandscape ? 400.0 : 500.0));
                  final optimalCardSize = (optimalBoardSize -
                          (isTablet
                              ? 16.0
                              : (isSmallPhoneLandscape ? 8.0 : 12.0))) /
                      math.max(gridRows, gridCols);

                  return Container(
                    padding: EdgeInsets.all(horizontalPadding * 0.5),
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: optimalBoardSize,
                            height: optimalBoardSize * (gridRows / gridCols),
                            padding: EdgeInsets.all(isTablet
                                ? 8.0
                                : (isSmallPhoneLandscape ? 4.0 : 6.0)),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(isTablet
                                  ? 24.0
                                  : (isSmallPhoneLandscape ? 12.0 : 18.0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.teal.withValues(alpha: 0.08),
                                  blurRadius: isTablet ? 8.0 : 6.0,
                                  offset: Offset(0, isTablet ? 2.0 : 1.5),
                                ),
                              ],
                            ),
                            child: GridView.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: gridCols,
                                crossAxisSpacing: isTablet
                                    ? 8.0
                                    : (isSmallPhoneLandscape ? 3.0 : 5.0),
                                mainAxisSpacing: isTablet
                                    ? 8.0
                                    : (isSmallPhoneLandscape ? 3.0 : 5.0),
                                childAspectRatio: 1.0,
                              ),
                              itemCount: totalCards,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemBuilder: (context, idx) {
                                return _MemoryCard(
                                  value: cards[idx].value,
                                  isFlipped: idx == firstFlipped ||
                                      idx == secondFlipped ||
                                      cards[idx].isMatched,
                                  onTap: () => _onCardTap(idx),
                                  matched: cards[idx].isMatched,
                                  size: optimalCardSize,
                                );
                              },
                            ),
                          ),
                          // Audio indicator
                          if (_isPlayingAudio)
                            Positioned(
                              top: isTablet
                                  ? 16.0
                                  : (isSmallPhoneLandscape ? 8.0 : 12.0),
                              right: isTablet
                                  ? 16.0
                                  : (isSmallPhoneLandscape ? 8.0 : 12.0),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: isTablet
                                        ? 12.0
                                        : (isSmallPhoneLandscape ? 6.0 : 8.0),
                                    vertical: isTablet
                                        ? 8.0
                                        : (isSmallPhoneLandscape ? 4.0 : 6.0)),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(isTablet
                                      ? 20.0
                                      : (isSmallPhoneLandscape ? 12.0 : 16.0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.1),
                                      blurRadius: isTablet ? 4.0 : 3.0,
                                      offset: Offset(0, isTablet ? 2.0 : 1.5),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: isTablet
                                          ? 18.0
                                          : (isSmallPhoneLandscape
                                              ? 12.0
                                              : 15.0),
                                      height: isTablet
                                          ? 18.0
                                          : (isSmallPhoneLandscape
                                              ? 12.0
                                              : 15.0),
                                      child: CircularProgressIndicator(
                                        strokeWidth: isTablet ? 2.0 : 1.5,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                                Color(0xFF43C465)),
                                      ),
                                    ),
                                    SizedBox(
                                        width: isTablet
                                            ? 8.0
                                            : (isSmallPhoneLandscape
                                                ? 4.0
                                                : 6.0)),
                                    Text(
                                      '${_voicePersonalities[_selectedVoiceId]?['name'] ?? 'Voice'} is speaking...',
                                      style: TextStyle(
                                        color: const Color(0xFF43C465),
                                        fontWeight: FontWeight.bold,
                                        fontSize: isTablet
                                            ? 14.0
                                            : (isSmallPhoneLandscape
                                                ? 10.0
                                                : 12.0),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      )
    ]);
  }

  // Portrait layout (original single-column layout)
  Widget _buildPortraitLayout(
      double horizontalPadding,
      double verticalPadding,
      double titleFontSize,
      double iconSize,
      double statsFontSize,
      double dropdownFontSize,
      double emojiFontSize,
      double maxBoardSize,
      double cardSize,
      bool isTablet,
      bool isSmallPhoneLandscape) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: verticalPadding),
            Row(
              children: [
                SizedBox(width: horizontalPadding * 0.67),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF43C465),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x3343C465),
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
                  'Memory Match',
                  style: TextStyle(
                    fontFamily: 'Baloo2',
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF43C465),
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                SizedBox(width: isTablet ? 48.0 : 40.0),
              ],
            ),
            SizedBox(height: verticalPadding),
            // Grid size selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Grid Size:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: dropdownFontSize)),
                SizedBox(width: isTablet ? 8.0 : 6.0),
                DropdownButton<int>(
                  value: _currentGridIndex,
                  onChanged: (v) => _setGridSize(v!),
                  style: TextStyle(
                      fontSize: dropdownFontSize, color: Colors.black),
                  items: gridSizes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final size = entry.value;
                    return DropdownMenuItem(
                      value: index,
                      child: Text(
                          '${size['rows']}×${size['cols']} (${size['pairs']} pairs)'),
                    );
                  }).toList(),
                ),
              ],
            ),
            SizedBox(height: verticalPadding * 0.67),
            // Voice settings
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Voice:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: dropdownFontSize)),
                    SizedBox(width: isTablet ? 8.0 : 6.0),
                    DropdownButton<String>(
                      value: _selectedVoiceId,
                      onChanged: (v) => _setVoiceId(v!),
                      style: TextStyle(
                          fontSize: dropdownFontSize, color: Colors.black),
                      items: [
                        DropdownMenuItem(
                            value: 'mlFsujxZWlk6xPyQJgMb', child: Text('Mary')),
                        DropdownMenuItem(
                            value: 'N2lVS1w4EtoT3dr4eOWO',
                            child: Text('Callum')),
                        DropdownMenuItem(
                            value: '9BWtsMINqrJLrRacOk9x', child: Text('Aria')),
                      ],
                    ),
                    SizedBox(width: isTablet ? 16.0 : 12.0),
                    Transform.scale(
                      scale: isTablet ? 1.0 : 0.9,
                      child: Switch(
                        value: _useVoiceCommentary,
                        onChanged: _toggleVoiceCommentary,
                        activeThumbColor: const Color(0xFF43C465),
                      ),
                    ),
                    Text('Commentary',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: dropdownFontSize)),
                  ],
                ),
              ],
            ),
            SizedBox(height: verticalPadding),
            // Moves and pairs
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Moves: $moves',
                    style: TextStyle(
                        fontSize: statsFontSize,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF43C465),
                        fontFamily: 'Baloo2')),
                SizedBox(width: isTablet ? 32.0 : 24.0),
                Text('Pairs: $pairsFound/$totalPairs',
                    style: TextStyle(
                        fontSize: statsFontSize,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFF9F43),
                        fontFamily: 'Baloo2')),
              ],
            ),
            SizedBox(height: verticalPadding),
            // Feedback emoji area (fixed height to prevent layout shift)
            SizedBox(
              height:
                  emojiFontSize + 8, // Responsive height based on emoji size
              child: Center(
                child: feedbackEmoji != null
                    ? Text(feedbackEmoji!,
                        style: TextStyle(fontSize: emojiFontSize))
                    : null,
              ),
            ),
            // Responsive Board
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: maxBoardSize,
                    height: maxBoardSize * (gridRows / gridCols),
                    padding: EdgeInsets.all(isTablet ? 8.0 : 6.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(isTablet ? 24.0 : 18.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.withValues(alpha: 0.08),
                          blurRadius: isTablet ? 8.0 : 6.0,
                          offset: Offset(0, isTablet ? 2.0 : 1.5),
                        ),
                      ],
                    ),
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridCols,
                        crossAxisSpacing: isTablet ? 8.0 : 5.0,
                        mainAxisSpacing: isTablet ? 8.0 : 5.0,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: totalCards,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, idx) {
                        return _MemoryCard(
                          value: cards[idx].value,
                          isFlipped: idx == firstFlipped ||
                              idx == secondFlipped ||
                              cards[idx].isMatched,
                          onTap: () => _onCardTap(idx),
                          matched: cards[idx].isMatched,
                          size: cardSize,
                        );
                      },
                    ),
                  ),
                  // Show a small indicator when audio is playing
                  if (_isPlayingAudio)
                    Positioned(
                      top: isTablet ? 16.0 : 12.0,
                      right: isTablet ? 16.0 : 12.0,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 12.0 : 8.0,
                            vertical: isTablet ? 8.0 : 6.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius:
                              BorderRadius.circular(isTablet ? 20.0 : 16.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: isTablet ? 4.0 : 3.0,
                              offset: Offset(0, isTablet ? 2.0 : 1.5),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: isTablet ? 18.0 : 15.0,
                              height: isTablet ? 18.0 : 15.0,
                              child: CircularProgressIndicator(
                                strokeWidth: isTablet ? 2.0 : 1.5,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF43C465)),
                              ),
                            ),
                            SizedBox(width: isTablet ? 8.0 : 6.0),
                            Text(
                              '${_voicePersonalities[_selectedVoiceId]?['name'] ?? 'Voice'} is speaking...',
                              style: TextStyle(
                                color: const Color(0xFF43C465),
                                fontWeight: FontWeight.bold,
                                fontSize: isTablet ? 14.0 : 12.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: verticalPadding),
          ],
        ),
      ),
    );
  }
}

class _CardData {
  final String value;
  bool isMatched = false;
  _CardData({required this.value});
}

class _MemoryCard extends StatelessWidget {
  final String value;
  final bool isFlipped;
  final bool matched;
  final VoidCallback onTap;
  final double? size;
  const _MemoryCard(
      {required this.value,
      required this.isFlipped,
      required this.onTap,
      required this.matched,
      this.size});
  @override
  Widget build(BuildContext context) {
    final double cardSize = size ?? 54;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    // Enhanced device detection (same as other screens)
    final shortestSide = math.min(screenWidth, screenHeight);
    final isTablet =
        shortestSide > 600 || (shortestSide > 500 && devicePixelRatio < 2.5);
    final isLandscape = screenWidth > screenHeight;
    final isSmallPhoneLandscape =
        isLandscape && !isTablet && screenHeight < 380;

    final borderRadius = isTablet ? 16.0 : (isSmallPhoneLandscape ? 8.0 : 12.0);
    final shadowBlur = isTablet ? 6.0 : (isSmallPhoneLandscape ? 3.0 : 4.0);
    final borderWidth = isTablet ? 2.0 : (isSmallPhoneLandscape ? 1.5 : 2.0);

    return GestureDetector(
      onTap: isFlipped ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: cardSize,
        height: cardSize * 1.35,
        decoration: BoxDecoration(
          color: isFlipped ? Colors.white : const Color(0xFFB2F2E9),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.withValues(alpha: 0.10),
              blurRadius: shadowBlur,
              offset: Offset(0, isTablet ? 2.0 : 1.5),
            ),
          ],
          border: Border.all(
              color: matched ? const Color(0xFF43C465) : Colors.teal.shade100,
              width: borderWidth),
        ),
        child: Center(
          child: isFlipped
              ? Text(value, style: TextStyle(fontSize: cardSize * 0.6))
              : Text('⭐',
                  style: TextStyle(
                      fontSize: cardSize * 0.5,
                      color: const Color(0xFF43C465))),
        ),
      ),
    );
  }
}
