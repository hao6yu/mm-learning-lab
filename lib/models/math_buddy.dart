import 'dart:math';
import '../services/elevenlabs_service.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';

class MathBuddy {
  final String name;
  final String imageAsset;
  final String voiceId;
  final String personality;
  final Map<String, dynamic> voiceSettings;
  final String specialty; // What this buddy is especially good at teaching
  final List<String> uniquePhrases; // Special phrases only this buddy uses
  final Color themeColor; // Theme color for this buddy's UI elements

  // Audio related variables
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _isPlayingAudio = false;
  static int _tempAudioCounter = 0;
  static final List<String> _pendingAudioMessages = [];
  static bool _processingAudioQueue = false;
  static final Set<String> _usedMessages = {};
  static bool _useVoice = true;
  static final ElevenLabsService _elevenLabsService = ElevenLabsService();
  static StreamSubscription<PlayerState>? _playerStateSubscription;
  static bool _disposed = false;

  MathBuddy({
    required this.name,
    required this.imageAsset,
    required this.voiceId,
    required this.personality,
    required this.voiceSettings,
    required this.specialty,
    required this.uniquePhrases,
    required this.themeColor,
  });

  static final Map<String, Set<String>> gradeOperations = {
    'Pre-K': {'+'},
    'K': {'+', '-'},
    '1st': {'+', '-'},
    '2nd': {'+', '-'},
    '3rd': {'+', '-', '×'},
    '4th': {'+', '-', '×', '÷'},
  };

  static final List<String> grades = ['Pre-K', 'K', '1st', '2nd', '3rd', '4th'];

  static final Map<String, Map<String, int>> gradeDifficultyRanges = {
    'Pre-K': {
      'min': 1,
      'max': 5,
    },
    'K': {
      'min': 1,
      'max': 10,
    },
    '1st': {
      'min': 1,
      'max': 20,
    },
    '2nd': {
      'min': 1,
      'max': 50,
    },
    '3rd': {
      'min': 1,
      'max': 100,
    },
    '4th': {
      'min': 1,
      'max': 200,
    },
  };

  // Initialize the voice system
  static void initialize() {
    _disposed = false;
    debugPrint("Initializing Math Buddy audio system");
    ElevenLabsService.initialize();
    _setupAudioPlayerListener();
    debugPrint("Math Buddy audio system initialized");
  }

  static void _setupAudioPlayerListener() {
    // Cancel existing subscription if any
    _playerStateSubscription?.cancel();
    _playerStateSubscription = null;

    debugPrint("Setting up audio player listener");

    // Create a new subscription
    _playerStateSubscription = _audioPlayer.playerStateStream.listen(
      (state) {
        debugPrint(
            "Audio player state change: ${state.processingState}, playing: ${state.playing}");

        bool previousPlayingState = _isPlayingAudio;

        if (state.processingState == ProcessingState.completed) {
          _isPlayingAudio = false;
          debugPrint('Math buddy audio playback completed');

          // Process the next message in the queue
          _processNextAudioMessage();
        } else if (state.processingState == ProcessingState.idle &&
            _isPlayingAudio) {
          // Check if we were previously playing - this could indicate an error
          debugPrint('Audio playback ended unexpectedly (idle state)');
          _isPlayingAudio = false;
          _processNextAudioMessage();
        } else if (state.processingState == ProcessingState.ready &&
            state.playing) {
          _isPlayingAudio = true;
          debugPrint('Audio playback is active');
        }

        // If playing state changed, trigger a notification
        if (previousPlayingState != _isPlayingAudio) {
          debugPrint(
              'Broadcasting audio playing state change: $_isPlayingAudio');
          // Force notifying listeners about this change by using additional methods
          _notifyAudioStateChange();
        }
      },
      onError: (error) {
        // Handle errors in the stream itself
        debugPrint('Error in audio player stream: $error');
        _isPlayingAudio = false;
        _notifyAudioStateChange();
        _processNextAudioMessage();
      },
    );

    // Also listen to position updates as a sanity check
    _audioPlayer.positionStream.listen((position) {
      if (position.inMilliseconds > 0 && _isPlayingAudio) {
        debugPrint("Audio playback position: ${position.inSeconds}s");
      }
    });
  }

  // Add a notification method to ensure UI updates
  static final List<VoidCallback> _audioStateListeners = [];

  static void addAudioStateListener(VoidCallback listener) {
    _audioStateListeners.add(listener);
  }

  static void removeAudioStateListener(VoidCallback listener) {
    _audioStateListeners.remove(listener);
  }

  static void _notifyAudioStateChange() {
    for (final listener in _audioStateListeners) {
      try {
        listener();
      } catch (e) {
        debugPrint('Error in audio state listener: $e');
      }
    }
  }

  static void _processNextAudioMessage() {
    if (_pendingAudioMessages.isNotEmpty) {
      // Use the first character as the default buddy
      // The actual voice ID will be determined by the queue message
      Future.microtask(
          () => _processAudioQueue(MathBuddyCharacters.characters.first));
    } else {
      _processingAudioQueue = false;
    }
  }

  // Getter for voice preference
  static bool get useVoice => _useVoice;

  // Set voice usage preference
  static void setUseVoice(bool useVoice) {
    _useVoice = useVoice;
    debugPrint("MathBuddy voice setting changed to: $_useVoice");
    if (!_useVoice) {
      stopAudio();
    }
  }

  // Audio control methods
  static Future<void> stopAudio() async {
    if (_disposed) return;
    try {
      if (_isPlayingAudio) {
        debugPrint("Stopping audio playback");
        // Cancel the current audio player state subscription if it exists
        _playerStateSubscription?.cancel();

        // Stop the audio player
        await _audioPlayer.stop();

        // Reset the player state
        _audioPlayer.seek(Duration.zero);

        // Just wait a moment for cleanup instead of trying to clear the source
        await Future.delayed(const Duration(milliseconds: 200));

        _isPlayingAudio = false;
        debugPrint("Audio playback stopped successfully");
      }
    } catch (e) {
      debugPrint('Error stopping audio: $e');
      // Force reset audio state in case of error
      _isPlayingAudio = false;
    }
  }

  // Clean up resources
  static void dispose() {
    _disposed = true;

    // Stop any playing audio first
    stopAudio();

    // Cancel all subscriptions
    _playerStateSubscription?.cancel();
    _playerStateSubscription = null;

    // Properly dispose the audio player
    _audioPlayer.dispose();

    // Clear any pending messages
    _pendingAudioMessages.clear();
    _usedMessages.clear();

    // Reset all state
    _processingAudioQueue = false;
    _isPlayingAudio = false;

    debugPrint("Math Buddy resources disposed properly");
  }

  // Main method to speak a message
  Future<void> speak(String message, {bool addExclamation = false}) async {
    debugPrint("Speak method called with useVoice=$_useVoice");
    if (!_useVoice) {
      debugPrint("Voice is disabled, not speaking: $message");
      return;
    }

    // Add personality touch with unique phrases occasionally
    String finalMessage = message;
    if (addExclamation && Random().nextDouble() < 0.4) {
      // 40% chance to add a unique phrase from this buddy
      String phrase = uniquePhrases[Random().nextInt(uniquePhrases.length)];
      finalMessage = "$phrase $message";
    }

    debugPrint("Adding message to audio queue: $finalMessage");
    // Add message to the queue
    _pendingAudioMessages.add(finalMessage);

    // Start processing the queue if not already doing so
    if (!_processingAudioQueue) {
      debugPrint("Starting audio queue processing");
      _processAudioQueue(this);
    } else {
      debugPrint("Audio queue already processing");
    }
  }

  // Process audio messages in sequence
  static Future<void> _processAudioQueue(MathBuddy buddy) async {
    if (_disposed) return;
    if (_pendingAudioMessages.isEmpty) {
      _processingAudioQueue = false;
      _isPlayingAudio = false;
      _notifyAudioStateChange();
      debugPrint("Audio queue empty - processing complete");
      return;
    }

    _processingAudioQueue = true;

    try {
      await stopAudio();
      if (_disposed) return;
      String textToSpeak = _pendingAudioMessages.removeAt(0);
      _tempAudioCounter++;
      int storyId = 99999 + _tempAudioCounter;
      debugPrint('Generating math buddy audio: $textToSpeak');
      debugPrint(
          'Current voice state: useVoice=$_useVoice, isPlaying=$_isPlayingAudio');

      // Check if running on iOS simulator
      bool isIosSimulator = false;
      if (Platform.isIOS) {
        // This is a heuristic to detect simulator - actual device paths typically don't have "CoreSimulator"
        String documentsPath = (await getApplicationDocumentsDirectory()).path;
        isIosSimulator = documentsPath.contains('CoreSimulator');
        if (isIosSimulator) {
          debugPrint(
              '⚠️ WARNING: Running on iOS simulator - audio may not play correctly');
        }
      }

      String? audioPath = await _checkCachedAudio(textToSpeak, buddy.voiceId);
      if (_disposed) return;
      if (audioPath == null) {
        debugPrint('No cached audio found, generating new audio file');
        final result = await _elevenLabsService.generateAudio(
          textToSpeak,
          storyId,
          voiceId: buddy.voiceId,
        );
        if (_disposed) return;
        if (result == null) {
          debugPrint('Failed to generate audio');
          _isPlayingAudio = false;
          _notifyAudioStateChange();
          if (!_disposed) {
            Future.delayed(const Duration(milliseconds: 300), () {
              _processNextAudioMessage();
            });
          }
          return;
        }
        audioPath = result;
        debugPrint('Successfully generated audio file at: $audioPath');
        await _cacheAudio(textToSpeak, buddy.voiceId, audioPath);
        if (_disposed) return;
      }
      Timer? timeoutTimer = Timer(const Duration(seconds: 30), () {
        debugPrint('Playback timeout triggered');
        _isPlayingAudio = false;
        _notifyAudioStateChange();
        if (!_disposed) _processNextAudioMessage();
      });
      try {
        debugPrint('Setting file path: $audioPath');
        final audioFile = File(audioPath);
        if (!audioFile.existsSync()) {
          debugPrint('Audio file does not exist: $audioPath');
          _isPlayingAudio = false;
          _notifyAudioStateChange();
          if (!_disposed) _processNextAudioMessage();
          timeoutTimer.cancel();
          return;
        }

        debugPrint('Audio file exists, size: ${audioFile.lengthSync()} bytes');
        await _audioPlayer.setFilePath(audioPath);
        debugPrint('File path set, starting playback');
        if (_disposed) {
          timeoutTimer.cancel();
          return;
        }
        _isPlayingAudio = true;
        _notifyAudioStateChange();
        debugPrint('Calling play()');

        // Special handling for iOS simulator
        if (isIosSimulator) {
          // On iOS simulator, fake playback completion after a delay
          debugPrint('iOS simulator detected - faking audio playback');
          await Future.delayed(Duration(milliseconds: 500));
          debugPrint(
              'Simulating audio playback - duration would be ${_audioPlayer.duration}');

          // Still try to play in case audio actually works
          await _audioPlayer.play();

          // Schedule a fake completion after calculated duration
          final duration = _audioPlayer.duration ?? Duration(seconds: 3);
          Future.delayed(duration, () {
            debugPrint('iOS simulator - faking playback completion');
            if (_isPlayingAudio) {
              _isPlayingAudio = false;
              _notifyAudioStateChange();
              _processNextAudioMessage();
            }
            timeoutTimer.cancel();
          });
        } else {
          // Normal playback on real devices
          await _audioPlayer.play();
        }

        debugPrint('Playback started');
        timeoutTimer.cancel();
      } catch (playbackError) {
        debugPrint('Error during audio playback setup: $playbackError');
        timeoutTimer.cancel();
        _isPlayingAudio = false;
        _notifyAudioStateChange();
        if (!_disposed) _processNextAudioMessage();
      }
    } catch (e) {
      debugPrint('Error playing math buddy audio: $e');
      _isPlayingAudio = false;
      _notifyAudioStateChange();
      if (!_disposed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _processNextAudioMessage();
        });
      }
    }
  }

  // Cache management methods
  static Future<String?> _checkCachedAudio(String text, String voiceId) async {
    try {
      final hash = text.hashCode.toString() + voiceId;
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/math_buddy_audio_cache');
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

  static Future<void> _cacheAudio(
      String text, String voiceId, String audioPath) async {
    try {
      final hash = text.hashCode.toString() + voiceId;
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/math_buddy_audio_cache');
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

  // Helper method to get a unique message that hasn't been used recently
  String _getUniqueMessage(List<String> messageList) {
    // If we've used all or nearly all messages, reset the used set
    if (_usedMessages.length >= messageList.length - 1) {
      _usedMessages.clear();
    }

    // Find a message we haven't used yet
    String message;
    do {
      message = messageList[Random().nextInt(messageList.length)];
    } while (_usedMessages.contains(message) &&
        _usedMessages.length < messageList.length);

    // Mark this message as used
    _usedMessages.add(message);
    return message;
  }

  static final List<String> _encouragementPhrases = [
    "You're doing great!",
    "Awesome job!",
    "You're so smart!",
    "Keep it up!",
    "I'm impressed!",
    "You're a math star!",
    "Amazing work!",
    "You're crushing it!",
    "Fantastic job!",
    "You're on fire!",
  ];

  static final List<String> _correctResponsePhrases = [
    "That's correct!",
    "You got it right!",
    "Perfect answer!",
    "Spot on!",
    "That's exactly right!",
    "Well done!",
    "Great work!",
    "You nailed it!",
    "Correct answer!",
    "You're right!",
  ];

  static final List<String> _incorrectResponsePhrases = [
    "Not quite, let's try again!",
    "Hmm, that's not right. Let's think...",
    "Close, but not quite there.",
    "Let's double-check our work.",
    "Actually, there's another answer.",
    "I think we need to recalculate.",
    "Let me help you with this one.",
    "Let's try a different approach.",
    "We'll get it next time!",
    "Let's see where we went wrong.",
  ];

  static final List<String> _hintPhrases = [
    "Think about regrouping the numbers.",
    "Try counting on your fingers.",
    "What if we break this down into smaller steps?",
    "Remember, addition means we're combining amounts.",
    "Subtraction means we're taking away.",
    "Think of multiplication as repeated addition.",
    "Let's draw this out to visualize it better.",
    "Can we use a number line to help?",
    "What strategy would work best here?",
    "Let's try using objects to count.",
  ];

  static final List<String> _thinkingPhrases = [
    "Let me think about this...",
    "Hmm, working it out...",
    "Calculating...",
    "I'm solving this in my head...",
    "Thinking...",
    "Let's see...",
    "Working through this...",
    "Just a moment...",
    "Almost got it...",
    "Figuring it out...",
  ];

  Future<void> sayEncouragement() async {
    final message = _getUniqueMessage(_encouragementPhrases);
    await speak(message, addExclamation: true);
  }

  Future<void> sayCorrectResponse() async {
    final message = _getUniqueMessage(_correctResponsePhrases);
    await speak(message, addExclamation: true);
  }

  Future<void> sayIncorrectResponse() async {
    final message = _getUniqueMessage(_incorrectResponsePhrases);
    await speak(message, addExclamation: false);
  }

  Future<void> sayHint() async {
    final message = _getUniqueMessage(_hintPhrases);
    await speak(message, addExclamation: false);
  }

  Future<void> sayThinking() async {
    final message = _getUniqueMessage(_thinkingPhrases);
    await speak(message, addExclamation: false);
  }

  Future<void> explainAddition(int num1, int num2) async {
    final explanation =
        "To add $num1 and $num2, I count $num1 and then add $num2 more. That gives me ${num1 + num2}.";
    await speak(explanation, addExclamation: false);
  }

  Future<void> explainSubtraction(int num1, int num2) async {
    final explanation =
        "To subtract $num2 from $num1, I start at $num1 and count back $num2. That gives me ${num1 - num2}.";
    await speak(explanation, addExclamation: false);
  }

  Future<void> explainMultiplication(int num1, int num2) async {
    final explanation =
        "To multiply $num1 by $num2, I can add $num1 together $num2 times: ${List.filled(num2, num1).join(' + ')} = ${num1 * num2}.";
    await speak(explanation, addExclamation: false);
  }

  Future<void> explainDivision(int num1, int num2) async {
    final result = num1 ~/ num2;
    final remainder = num1 % num2;

    String explanation;
    if (remainder == 0) {
      explanation =
          "To divide $num1 by $num2, I can see how many groups of $num2 fit into $num1. That gives me $result.";
    } else {
      explanation =
          "To divide $num1 by $num2, I get $result with a remainder of $remainder.";
    }

    await speak(explanation, addExclamation: false);
  }

  Future<void> explainProblem(String operation, int num1, int num2) async {
    switch (operation) {
      case '+':
        await explainAddition(num1, num2);
        break;
      case '-':
        await explainSubtraction(num1, num2);
        break;
      case '×':
        await explainMultiplication(num1, num2);
        break;
      case '÷':
        await explainDivision(num1, num2);
        break;
      default:
        await speak("Let's solve this step by step.", addExclamation: false);
    }
  }

  Future<void> introduceYourself({String? profileName}) async {
    String introduction;
    if (profileName != null && profileName.isNotEmpty) {
      introduction =
          "Hi there, $profileName! I'm $name, your math buddy! $personality I love helping with $specialty. Let's have fun with math!";
    } else {
      introduction =
          "Hi there! I'm $name, your math buddy! $personality I love helping with $specialty. Let's have fun with math!";
    }
    await speak(introduction, addExclamation: true);
  }

  Future<void> sayGoodbye() async {
    final goodbye =
        "Thanks for learning with me today! You did an awesome job. Come back soon for more math fun!";
    await speak(goodbye, addExclamation: true);
  }

  // Method to simulate thinking and respond to a complete problem
  Future<void> solveCompleteProblem(String question) async {
    // First, say a thinking phrase
    await sayThinking();

    // Extract numbers and operation from the question (e.g., "5 + 3 = ?")
    final parts = question.split(' ');
    if (parts.length >= 3) {
      try {
        final num1 = int.parse(parts[0]);
        final operation = parts[1];
        final num2 = int.parse(parts[2]);

        // Explain the problem and solution
        await explainProblem(operation, num1, num2);
      } catch (e) {
        await speak(
            "I'm not sure how to solve this problem. Can you show me a different way?",
            addExclamation: false);
      }
    } else {
      await speak(
          "Could you please show me the problem in a format like '5 + 3 = ?'?",
          addExclamation: false);
    }
  }

  // Get audio playing status
  static bool get isPlayingAudio => _isPlayingAudio;
}

class MathBuddyCharacters {
  static final List<MathBuddy> characters = [
    // Mary - The patient teacher
    MathBuddy(
      name: "Professor Aria",
      imageAsset: "assets/images/math_buddy/cosmo.png",
      voiceId: "9BWtsMINqrJLrRacOk9x", // Aria voice
      personality: "I'm a patient and clear teacher who breaks down each step.",
      voiceSettings: {
        'stability': 0.5,
        'similarity_boost': 0.75,
        'style': 0.6,
        'speed': 1.0,
      },
      specialty: "explaining complex concepts simply",
      uniquePhrases: [
        "Wonderful!",
        "Let's look at this carefully.",
        "Think about it step by step.",
        "Let me show you a helpful trick.",
        "Remember the pattern we learned!",
      ],
      themeColor: Colors.blue,
    ),

    // Callum - The fun and energetic coach
    MathBuddy(
      name: "Coach Callum",
      imageAsset: "assets/images/math_buddy/luna.png",
      voiceId: "N2lVS1w4EtoT3dr4eOWO", // Callum voice
      personality:
          "I'm an energetic coach who makes math feel like a fun game!",
      voiceSettings: {
        'stability': 0.35,
        'similarity_boost': 0.8,
        'style': 0.8,
        'speed': 1.2,
      },
      specialty: "making math fun and engaging",
      uniquePhrases: [
        "Let's rock this!",
        "Math challenge accepted!",
        "You've got this, math champion!",
        "Time for some math magic!",
        "That's the way to crush those numbers!",
      ],
      themeColor: Colors.orange,
    ),

    // Aria - The supportive and encouraging friend
    MathBuddy(
      name: "Aria Star",
      imageAsset: "assets/images/math_buddy/pi.png",
      voiceId: "9BWtsMINqrJLrRacOk9x", // Aria voice
      personality:
          "I'm your supportive math friend who believes you can solve anything!",
      voiceSettings: {
        'stability': 0.4,
        'similarity_boost': 0.7,
        'style': 0.7,
        'speed': 1.1,
      },
      specialty: "building math confidence through positive reinforcement",
      uniquePhrases: [
        "I believe in you!",
        "You're growing your math brain!",
        "Every problem you try makes you stronger!",
        "That's the kind of thinking that solves problems!",
        "Your effort is what matters most!",
      ],
      themeColor: Colors.purple,
    ),
  ];

  static MathBuddy getRandomBuddy() {
    // Always return Professor Mary as the default voice
    return characters[2]; // Professor Mary is the first character in the list
  }

  static MathBuddy getBuddyByName(String name) {
    return characters.firstWhere(
      (buddy) => buddy.name == name,
      orElse: () => characters[0],
    );
  }

  static MathBuddy getBuddyByVoiceId(String voiceId) {
    return characters.firstWhere(
      (buddy) => buddy.voiceId == voiceId,
      orElse: () => characters[0],
    );
  }
}
