// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/database_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/story.dart';
import '../widgets/word_card.dart';
import 'create_story_screen.dart';
import '../services/elevenlabs_service.dart';
import '../services/theme_service.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:math';
import '../providers/profile_provider.dart';
import '../services/ai_usage_limit_service.dart';
import '../services/subscription_service.dart';

class StoryAdventureScreen extends StatefulWidget {
  const StoryAdventureScreen({super.key});

  @override
  State<StoryAdventureScreen> createState() => _StoryAdventureScreenState();
}

class _StoryAdventureScreenState extends State<StoryAdventureScreen>
    with SingleTickerProviderStateMixin {
  List<Story> _stories = [];
  Story? _selectedStory;
  bool _loading = true;
  late FlutterTts _flutterTts;
  List<dynamic> _voices = [];
  dynamic _selectedVoice;
  double _speechRate = 0.25;
  bool _isPlaying = false;
  bool _isPaused = false;
  String _selectedCategory = 'All';
  String _selectedDifficulty = 'All';
  late AnimationController _animationController;
  // ignore: unused_field
  late Animation<double> _scaleAnimation;
  List<Map<String, dynamic>> _wordList = [];

  // ElevenLabs integration
  final ElevenLabsService _elevenLabsService = ElevenLabsService();
  AudioPlayer? _audioPlayer;
  bool _isUsingElevenLabs = false; // Toggle between Flutter TTS and ElevenLabs
  bool _isGeneratingAudio = false; // Loading state for audio generation
  bool _audioGenerationFailed = false; // Error state for audio generation
  bool _aiVoiceAvailable =
      false; // Whether AI voice is available for this story
  String _selectedVoiceId =
      ElevenLabsService.getCurrentVoiceId(); // Selected ElevenLabs voice ID

  // Word highlighting for AI voice
  int _currentWordIndex = -1; // Currently highlighted word index
  Timer? _wordHighlightTimer; // Timer for word highlighting
  // ignore: unused_field
  Duration _totalAudioDuration = Duration.zero; // Total audio duration
  List<Map<String, dynamic>> _wordTimestamps = []; // ElevenLabs word timestamps

  final List<String> _categories = [
    'All',
    'Adventure',
    'Animals',
    'Space',
    'Fantasy',
    'Nature'
  ];
  final List<String> _difficulties = ['All', 'Easy', 'Medium', 'Hard'];

  // First, add a new state variable to track whether to show only user-created stories
  // Add this with the other state variables at the top of the class
  bool _showOnlyMyStories = false;
  final AIUsageLimitService _aiUsageLimitService = AIUsageLimitService();
  AiQuotaCheckResult? _storyQuotaStatus;
  int? _quotaProfileId;
  bool _isPremiumUser = false;

  bool get _canCreateStory {
    final status = _storyQuotaStatus;
    if (status == null) return true;
    return status.allowed;
  }

  @override
  void initState() {
    super.initState();
    debugPrint("StoryAdventureScreen initState called");
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _flutterTts = FlutterTts();
    debugPrint("FlutterTts initialized");
    _flutterTts.setLanguage("en-US");
    _flutterTts.setSpeechRate(_speechRate);
    _flutterTts.setPitch(1.0);
    _initVoices();
    _fetchStories();
    // Initialize ElevenLabs service
    ElevenLabsService.initialize();

    // Setup FlutterTTS event handlers
    _setupTtsEventHandlers();
  }

  void _setupTtsEventHandlers() {
    _flutterTts.setStartHandler(() {
      debugPrint("TTS start handler called");
      if (mounted) {
        setState(() {
          _isPlaying = true;
          _isPaused = false;
        });
      }
    });

    _flutterTts.setCompletionHandler(() {
      debugPrint("TTS completion handler called");
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isPaused = false;
        });
      }
    });

    _flutterTts.setCancelHandler(() {
      debugPrint("TTS cancel handler called");
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isPaused = false;
        });
      }
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint("TTS error handler called: $msg");
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isPaused = false;
        });
      }
    });

    _flutterTts
        .setProgressHandler((String text, int start, int end, String word) {
      debugPrint("TTS PROGRESS: '$word' at position $start-$end");
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final selectedProfileId =
        context.watch<ProfileProvider>().selectedProfileId;
    final isPremium = context.watch<SubscriptionService>().isSubscribed;
    if (_quotaProfileId == selectedProfileId && _isPremiumUser == isPremium) {
      return;
    }
    _quotaProfileId = selectedProfileId;
    _isPremiumUser = isPremium;
    _refreshStoryQuota();
  }

  @override
  void dispose() {
    debugPrint("StoryAdventureScreen dispose called");

    // Stop all audio first
    if (_isPlaying || _isPaused) {
      _stopAllAudio();
    }

    // Cancel word highlighting timer
    _wordHighlightTimer?.cancel();

    // Immediately clean up event handlers to prevent callback issues
    _flutterTts.setCompletionHandler(() {});
    _flutterTts.setCancelHandler(() {});
    _flutterTts.setProgressHandler((_, __, ___, ____) {});
    _flutterTts.setStartHandler(() {});
    _flutterTts.setErrorHandler((_) {});

    // Dispose animation controller
    _animationController.dispose();

    // Clear the word list
    _wordList.clear();

    debugPrint("StoryAdventureScreen resources disposed");
    super.dispose();
  }

  Future<void> _fetchStories() async {
    setState(() {
      _loading = true;
    });

    final selectedProfileId = context.read<ProfileProvider>().selectedProfileId;
    if (selectedProfileId == null) {
      if (mounted) {
        setState(() {
          _stories = [];
          _loading = false;
          _storyQuotaStatus = null;
        });
      }
      return;
    }

    final stories =
        await DatabaseService().getStories(profileId: selectedProfileId);

    // Check if there are any user-created stories
    final hasUserStories = stories.any((s) => s.isUserCreated);

    if (mounted) {
      setState(() {
        _stories = stories;
        _loading = false;

        // If there are no user stories but the filter is on, turn it off
        if (!hasUserStories && _showOnlyMyStories) {
          _showOnlyMyStories = false;
        }
      });
    }
  }

  Future<void> _refreshStoryQuota() async {
    final profileId = _quotaProfileId;
    if (profileId == null) {
      if (mounted) {
        setState(() {
          _storyQuotaStatus = null;
        });
      }
      return;
    }

    final status = await _aiUsageLimitService.getCountQuotaStatus(
      profileId: profileId,
      isPremium: _isPremiumUser,
      feature: AiCountFeature.storyGeneration,
    );
    if (!mounted) return;
    setState(() {
      _storyQuotaStatus = status;
    });
  }

  // Update the _filteredStories getter to include the new filter
  List<Story> get _filteredStories {
    return _stories.where((story) {
      final categoryMatch =
          _selectedCategory == 'All' || story.category == _selectedCategory;
      final difficultyMatch = _selectedDifficulty == 'All' ||
          story.difficulty == _selectedDifficulty;
      final myStoriesMatch = !_showOnlyMyStories || story.isUserCreated;
      return categoryMatch && difficultyMatch && myStoriesMatch;
    }).toList();
  }

  Future<void> _initVoices() async {
    final voices = await _flutterTts.getVoices;

    // Debug: print all available voices for troubleshooting
    // debugPrint('Available voices:');
    // for (var v in voices) {
    //   debugPrint(v);
    // }

    // Filter voices to only include those with explicit gender and locale specification
    final filteredVoices = voices.where((voice) {
      final gender = (voice['gender'] ?? '').toString().toLowerCase().trim();
      final locale = (voice['locale'] ?? '').toString().toLowerCase().trim();

      // Must have explicit gender and a valid locale
      return (gender == 'female' || gender == 'male') &&
          locale.contains('-') && // Must have a region/country
          locale.length >= 5; // Must be a valid locale format (e.g., en-us)
    }).toList();

    // Sort voices to prioritize English and female voices
    final sortedVoices = List<dynamic>.from(filteredVoices);
    sortedVoices.sort((a, b) {
      final aLocale = (a['locale'] ?? '').toString().toLowerCase().trim();
      final bLocale = (b['locale'] ?? '').toString().toLowerCase().trim();
      final aGender = (a['gender'] ?? '').toString().toLowerCase().trim();
      final bGender = (b['gender'] ?? '').toString().toLowerCase().trim();

      // Check if either is English
      final aIsEnglish = aLocale.startsWith('en-');
      final bIsEnglish = bLocale.startsWith('en-');

      // Check if either is female
      final aIsFemale = aGender == 'female';
      final bIsFemale = bGender == 'female';

      // First sort by English
      if (aIsEnglish && !bIsEnglish) return -1;
      if (!aIsEnglish && bIsEnglish) return 1;

      // If both are English, prioritize female voices
      if (aIsEnglish && bIsEnglish) {
        if (aIsFemale && !bIsFemale) return -1;
        if (!aIsFemale && bIsFemale) return 1;

        // If both are female or both are male, prioritize US English
        if (aLocale == 'en-us') return -1;
        if (bLocale == 'en-us') return 1;
      }

      // Then sort by locale
      return aLocale.compareTo(bLocale);
    });

    // 1. Prefer female US English voice with name containing 'samantha'
    dynamic femaleUSSamantha = sortedVoices.firstWhere(
      (v) =>
          (v['locale']?.toString().toLowerCase().trim() == 'en-us') &&
          (v['gender']?.toString().toLowerCase().trim() == 'female') &&
          (v['name']?.toString().toLowerCase().contains('samantha') ?? false),
      orElse: () => null,
    );
    // 2. If not found, prefer any female US English voice
    dynamic femaleUSVoice = sortedVoices.firstWhere(
      (v) =>
          (v['locale']?.toString().toLowerCase().trim() == 'en-us') &&
          (v['gender']?.toString().toLowerCase().trim() == 'female'),
      orElse: () => null,
    );
    // 3. If not found, prefer any female English voice
    dynamic femaleEnglishVoice = sortedVoices.firstWhere(
      (v) =>
          (v['locale']?.toString().toLowerCase().trim().startsWith('en-') ??
              false) &&
          (v['gender']?.toString().toLowerCase().trim() == 'female'),
      orElse: () => null,
    );

    setState(() {
      _voices = sortedVoices;
      if (femaleUSSamantha != null) {
        _selectedVoice = femaleUSSamantha;
        _flutterTts.setVoice(Map<String, String>.from(_selectedVoice));
      } else if (femaleUSVoice != null) {
        _selectedVoice = femaleUSVoice;
        _flutterTts.setVoice(Map<String, String>.from(_selectedVoice));
      } else if (femaleEnglishVoice != null) {
        _selectedVoice = femaleEnglishVoice;
        _flutterTts.setVoice(Map<String, String>.from(_selectedVoice));
      } else if (sortedVoices.isNotEmpty) {
        _selectedVoice = sortedVoices.first;
        _flutterTts.setVoice(Map<String, String>.from(_selectedVoice));
      }
    });
  }

  String _getVoiceDescription(dynamic voice) {
    final name = voice['name'] ?? '';
    final locale = voice['locale'] ?? '';
    final gender = voice['gender']?.toLowerCase() ?? '';
    final quality = voice['quality']?.toLowerCase() ?? '';

    String description = '';

    // Add gender (we know it's explicitly set due to filtering)
    description += gender == 'female' ? 'Female' : 'Male';

    // Add quality if available
    if (quality.contains('enhanced')) {
      description += ' | 🎯 Enhanced';
    } else if (quality.contains('premium')) {
      description += ' | ⭐ Premium';
    }

    // Add locale with proper formatting
    if (locale.toLowerCase() == 'en-us') {
      description += ' | 🇺🇸 US English';
    } else if (locale.toLowerCase() == 'en-gb') {
      description += ' | 🇬🇧 British English';
    } else if (locale.toLowerCase() == 'en-au') {
      description += ' | 🇦🇺 Australian English';
    } else if (locale.contains('-')) {
      // For other locales, show the full locale
      final parts = locale.split('-');
      if (parts.length >= 2) {
        description += ' | ${parts[0].toUpperCase()}-${parts[1].toUpperCase()}';
      }
    }

    // Add name if not already included
    if (!description.contains(name)) {
      description += ' | $name';
    }

    return description;
  }

  void _buildWordList(String text) {
    _wordList.clear();
    final wordRegex = RegExp(r"[\w'']+");
    final matches = wordRegex.allMatches(text);
    int sequentialPosition = 0;

    for (final match in matches) {
      _wordList.add({
        'word': match
            .group(0)!
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]'), ''), // Remove punctuation
        'originalWord': match.group(0), // Keep original for reference
        'start': match.start,
        'position': sequentialPosition, // Sequential position for tracking
        'id':
            '${match.start}_${match.group(0)!.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')}' // Unique ID using start position and word
      });
      sequentialPosition++;
    }
    debugPrint('Built word list with ${_wordList.length} words');
  }

  Future<void> _selectStory(Story story) async {
    debugPrint("_selectStory called for: ${story.title}");
    await _flutterTts.stop();
    // Stop any playing audio
    await _audioPlayer?.stop();

    setState(() {
      _selectedStory = story;
      _isPaused = false;
      _isPlaying = false;
      _wordList = [];
      _isGeneratingAudio = false;
      _audioGenerationFailed = false;
      _aiVoiceAvailable = false;
      _isUsingElevenLabs = true; // Default to AI reading mode
      _currentWordIndex = -1; // Reset word highlighting
      _wordTimestamps = []; // Clear previous timestamps
    });

    // Build word list immediately after selecting story
    // We need to include both title and content in the same sequence
    _buildWordList('${story.title}. ${story.content}');
    debugPrint("Word list built, length: ${_wordList.length}");

    // Check if this story has an AI voice audio file
    if (story.id != null) {
      // Check if we have a stored audio path
      if (story.audioPath != null) {
        // Check if the audio file exists
        bool hasFile = await _elevenLabsService.hasAudioFile(story.id!);
        setState(() {
          _aiVoiceAvailable = hasFile;
        });
      }
    }
  }

  // Unified method to stop all audio playback
  Future<void> _stopAllAudio() async {
    debugPrint("_stopAllAudio called");

    // Cancel word highlighting timer
    _wordHighlightTimer?.cancel();

    // Stop TTS if it's playing
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint("Error stopping TTS: $e");
    }

    // Stop audio player if it exists
    if (_audioPlayer != null) {
      try {
        // Important: stop first, then dispose
        await _audioPlayer!.stop();
        await Future.delayed(Duration(milliseconds: 100));
        await _audioPlayer!.dispose();
        _audioPlayer = null;
      } catch (e) {
        debugPrint("Error stopping audio player: $e");
        // Force null even if there was an error
        _audioPlayer = null;
      }
    }

    if (mounted) {
      setState(() {
        _isPlaying = false;
        _isPaused = false;
        _currentWordIndex = -1; // Reset word highlighting
        // Keep _wordTimestamps for reuse
      });
    }
  }

  // Play device TTS voice
  Future<void> _playDeviceTTS() async {
    debugPrint("_playDeviceTTS called");
    if (_selectedStory == null) return;

    // Stop any playing audio first
    await _stopAllAudio();

    try {
      setState(() {
        _isPlaying = true;
        _isPaused = false;
      });

      final storyText = '${_selectedStory!.title}. ${_selectedStory!.content}';
      debugPrint(
          "About to call TTS speak with text: '${storyText.substring(0, min(50, storyText.length))}...'");

      // Begin playback with device TTS
      var result = await _flutterTts.speak(storyText);
      debugPrint("TTS speak called, result: $result");
    } catch (e) {
      debugPrint("Error playing device TTS: $e");
      setState(() {
        _isPlaying = false;
        _isPaused = false;
      });
    }
  }

  // Pause device TTS voice
  Future<void> _pauseDeviceTTS() async {
    debugPrint("_pauseDeviceTTS called");
    try {
      var result = await _flutterTts.pause();
      debugPrint("TTS pause result: $result");

      setState(() {
        _isPlaying = false;
        _isPaused = true;
      });
    } catch (e) {
      debugPrint("Error pausing device TTS: $e");
      // Try to stop if pause fails
      await _flutterTts.stop();
      setState(() {
        _isPlaying = false;
        _isPaused = false;
      });
    }
  }

  // Resume device TTS voice
  Future<void> _resumeDeviceTTS() async {
    debugPrint("_resumeDeviceTTS called");
    try {
      setState(() {
        _isPaused = false;
        _isPlaying = true;
      });

      if (_selectedStory != null) {
        debugPrint("About to resume speaking content");
        await _flutterTts.speak(_selectedStory!.content);
        debugPrint("TTS speak called for resume");
      }
    } catch (e) {
      debugPrint("Error resuming device TTS: $e");
      setState(() {
        _isPlaying = false;
        _isPaused = false;
      });
    }
  }

  // Method to play AI voice audio
  Future<void> _playAIVoiceAudio() async {
    debugPrint("_playAIVoiceAudio called");
    if (_selectedStory == null || _selectedStory!.id == null) {
      debugPrint("Cannot play AI audio: story or story ID is null");
      return;
    }

    final storyId = _selectedStory!.id!;
    final storyText = '${_selectedStory!.title}. ${_selectedStory!.content}';

    // Stop any existing audio first
    await _stopAllAudio();

    if (mounted) {
      setState(() {
        _isPlaying = true;
        _isPaused = false;
        _isUsingElevenLabs = true;
      });
    }

    try {
      // Check if audio file exists for the selected voice
      debugPrint(
          "Checking if audio file exists for story $storyId with voice $_selectedVoiceId");
      bool hasAudioFile = await _elevenLabsService.hasAudioFile(storyId,
          voiceId: _selectedVoiceId);
      debugPrint("Audio file exists: $hasAudioFile");

      if (!hasAudioFile) {
        // Need to generate audio
        if (mounted) {
          setState(() {
            _isGeneratingAudio = true;
            _audioGenerationFailed = false;
          });
        }

        debugPrint(
            "Generating audio for story $storyId with voice $_selectedVoiceId");
        try {
          // Generate audio with timestamps for word highlighting
          final result = await _elevenLabsService.generateAudioWithTimestamps(
              text: storyText, storyId: storyId, voiceId: _selectedVoiceId);

          if (result == null) {
            debugPrint("Audio generation failed: no result returned");
            if (mounted) {
              setState(() {
                _isGeneratingAudio = false;
                _audioGenerationFailed = true;
                _isPlaying = false;
              });
            }
            return;
          }

          debugPrint("Audio generated successfully");

          // Load the timestamps for word highlighting
          final timestamps =
              result['timestamps'] as List<Map<String, dynamic>>? ?? [];

          // Set state to show we have an audio file now
          if (mounted) {
            setState(() {
              _isGeneratingAudio = false;
              _aiVoiceAvailable = true;
              _wordTimestamps = timestamps;
            });
          }
        } catch (e) {
          debugPrint("Error generating audio: $e");
          if (mounted) {
            setState(() {
              _isGeneratingAudio = false;
              _audioGenerationFailed = true;
              _isPlaying = false;
              _isPaused = false;
            });
          }
          return;
        }
      }

      // Load timestamps if they exist
      if (_wordTimestamps.isEmpty) {
        _wordTimestamps = await _elevenLabsService.getTimestampData(storyId,
            voiceId: _selectedVoiceId);
        debugPrint("Loaded ${_wordTimestamps.length} word timestamps");
      }

      // Now play the audio file
      await _playAudioFile(storyId);
    } catch (e) {
      debugPrint("Error in _playAIVoiceAudio: $e");
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isPaused = false;
          _audioGenerationFailed = true;
        });
      }
    }
  }

  // ignore: unused_element
  void _buildWordSequence(String text) {
    _wordList.clear();
    final wordRegex = RegExp(r"[\w'']+");
    final matches = wordRegex.allMatches(text);
    _wordList = matches
        .map((m) => {'word': m.group(0)!.toLowerCase(), 'start': m.start})
        .toList();
    debugPrint('Built word sequence: $_wordList'); // Debug print
  }

  Future<void> _backToSelection() async {
    debugPrint("_backToSelection called");

    // Stop audio first before changing state
    if (_isPlaying || _isPaused) {
      await _stopAllAudio();
    }

    // Small delay to ensure cleanup is complete
    await Future.delayed(Duration(milliseconds: 50));

    if (mounted) {
      setState(() {
        _selectedStory = null;
        _isPaused = false;
        _isPlaying = false;
        _isUsingElevenLabs = false;
        _isGeneratingAudio = false;
        _audioGenerationFailed = false;
        _wordList.clear();
      });
    }
  }

  // Start word highlighting for AI voice
  void _startWordHighlighting() {
    if (_wordTimestamps.isEmpty) {
      debugPrint("Cannot start word highlighting: no timestamp data available");
      return;
    }

    debugPrint(
        "Starting timestamp-based word highlighting for ${_wordTimestamps.length} words");

    // Reset current word index
    setState(() {
      _currentWordIndex = 0;
    });
  }

  // Update word highlighting based on audio position using ElevenLabs timestamps
  void _updateWordHighlighting(Duration position) {
    if (_wordTimestamps.isEmpty) return;

    final currentSeconds = position.inMilliseconds / 1000.0;

    // Find the word that should be highlighted at this time
    int newWordIndex = -1;

    for (int i = 0; i < _wordTimestamps.length; i++) {
      final timestamp = _wordTimestamps[i];
      final startTime = timestamp['start'] as double;
      final endTime = timestamp['end'] as double;

      if (currentSeconds >= startTime && currentSeconds <= endTime) {
        newWordIndex = i;
        break;
      }
    }

    // If no exact match, find the closest word that has started
    if (newWordIndex == -1) {
      for (int i = _wordTimestamps.length - 1; i >= 0; i--) {
        final startTime = _wordTimestamps[i]['start'] as double;
        if (currentSeconds >= startTime) {
          newWordIndex = i;
          break;
        }
      }
    }

    // Only update if the word index has changed and is valid
    if (newWordIndex != _currentWordIndex && newWordIndex >= 0 && mounted) {
      setState(() {
        _currentWordIndex = newWordIndex;
      });

      // Debug logging
      if (_currentWordIndex < _wordTimestamps.length) {
        final currentWord = _wordTimestamps[_currentWordIndex]['originalWord'];
        debugPrint(
            "Highlighting word $newWordIndex: '$currentWord' at ${position.inSeconds}s");
      }
    }
  }

  // Map timestamp word index to UI word index
  // This maps the ElevenLabs timestamp index to the visual word position in the UI
  bool _isWordHighlighted(int uiWordIndex, bool isTitle) {
    if (!_isUsingElevenLabs ||
        _currentWordIndex == -1 ||
        _wordTimestamps.isEmpty) {
      return false;
    }

    if (_selectedStory == null) return false;

    // Count ONLY actual words (not punctuation) in title
    final wordOnlyRegex = RegExp(r"[\w'']+");
    final titleWords = wordOnlyRegex.allMatches(_selectedStory!.title).toList();
    final numTitleWords = titleWords.length;

    if (isTitle) {
      // For title words, check if current timestamp index is within title range
      return _currentWordIndex < numTitleWords &&
          _currentWordIndex == uiWordIndex;
    } else {
      // For content words, adjust the index by subtracting title words
      final adjustedTimestampIndex = _currentWordIndex - numTitleWords;
      return adjustedTimestampIndex >= 0 &&
          adjustedTimestampIndex == uiWordIndex;
    }
  }

  // Calculate line position and word index for a given character position
  // ignore: unused_element
  void _calculateLineAndWordPosition(int start, int end, String cleanWord) {
    if (_selectedStory == null) return;

    final title = _selectedStory!.title;
    final content = _selectedStory!.content;
    final contentLines = content.split('\n');

    debugPrint(
        'DEBUG: Trying to find word "$cleanWord" at position $start in ${_wordList.length} words');

    // Try multiple matching approaches
    int wordListIndex = -1;

    // Approach 1: Exact match by start position and word
    wordListIndex = _wordList
        .indexWhere((w) => w['start'] == start && w['word'] == cleanWord);

    // Approach 2: Match by start position only
    if (wordListIndex == -1 && cleanWord.isNotEmpty) {
      wordListIndex = _wordList.indexWhere((w) => w['start'] == start);
      if (wordListIndex != -1) {
        debugPrint(
            'DEBUG: Found by start position only: ${_wordList[wordListIndex]}');
      }
    }

    // Approach 3: Match by word only (for common words)
    if (wordListIndex == -1 && cleanWord.isNotEmpty) {
      wordListIndex = _wordList.indexWhere((w) => w['word'] == cleanWord);
      if (wordListIndex != -1) {
        debugPrint('DEBUG: Found by word only: ${_wordList[wordListIndex]}');
      }
    }

    // Approach 4: Match by approximate position
    if (wordListIndex == -1 && cleanWord.isNotEmpty) {
      for (int i = 0; i < _wordList.length; i++) {
        final entry = _wordList[i];
        final entryStart = entry['start'] as int;
        final entryWord = entry['word'] as String;
        if ((start - entryStart).abs() <= 2 && entryWord.contains(cleanWord)) {
          wordListIndex = i;
          debugPrint(
              'DEBUG: Found by approximate position: ${_wordList[wordListIndex]}');
          break;
        }
      }
    }

    if (wordListIndex == -1) {
      debugPrint('DEBUG: No match found for "$cleanWord" at position $start');
      return;
    }

    // Count how many words are in the title
    final wordRegex = RegExp(r"[\w'']+");
    final titleMatches = wordRegex.allMatches(title).toList();
    final numTitleWords = titleMatches.length;

    if (wordListIndex < numTitleWords) {
      // It's in the title
      debugPrint(
          'Word in title: "$cleanWord" at position $start, word index $wordListIndex');
      return;
    }

    // It's in the content
    // Find which line contains this word
    int foundLine = -1;
    int wordIndexInLine = -1;
    int wordsSeen = numTitleWords;
    for (int i = 0; i < contentLines.length; i++) {
      final line = contentLines[i];
      final matches = wordRegex.allMatches(line).toList();
      if (wordListIndex < wordsSeen + matches.length) {
        foundLine = i;
        wordIndexInLine = wordListIndex - wordsSeen;
        break;
      }
      wordsSeen += matches.length;
    }

    debugPrint(
        'Calculated position for "$cleanWord" - Line: $foundLine, Word Index: $wordIndexInLine');
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = context.watch<ThemeService>().config;
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // Handle system back button
        debugPrint("System back button pressed");
        if (_selectedStory != null) {
          // If in story reader, go back to selection
          if (_isPlaying || _isPaused) {
            await _stopAllAudio();
            // Small delay to ensure cleanup is complete
            await Future.delayed(Duration(milliseconds: 50));
          }
          _backToSelection();
          return;
        }
        // Otherwise, allow normal back behavior but make sure to cleanup first
        if (_isPlaying || _isPaused) {
          await _stopAllAudio();
        }
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: themeConfig.screenGradient,
            ),
          ),
          child: SafeArea(
            child: _selectedStory == null
                ? _buildStorySelection(context)
                : _buildStoryReader(context, _selectedStory!),
          ),
        ),
      ),
    );
  }

  Widget _buildStorySelection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    // Responsive sizing
    final horizontalPadding = isTablet ? 24.0 : 16.0;
    final verticalPadding = isTablet ? 16.0 : 12.0;
    final borderRadius = isTablet ? 24.0 : 20.0;
    final iconSize = isTablet ? 28.0 : 24.0;
    final titleFontSize = isTablet ? 28.0 : 24.0;
    final spacing = isTablet ? 16.0 : 12.0;

    return Column(
      children: [
        // App Bar
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding, vertical: verticalPadding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(borderRadius),
              bottomRight: Radius.circular(borderRadius),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8.0,
                offset: const Offset(0, 4.0),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: isTablet ? 108.0 : 92.0,
                child: Row(
                  children: [
                    // Animated back button with bounce effect
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: 0.8 + (value * 0.2),
                          child: child,
                        );
                      },
                      child: GestureDetector(
                        onTap: () {
                          _stopAllAudio();
                          Navigator.pop(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF8E6CFF),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x338E6CFF),
                                blurRadius: 8.0,
                                offset: const Offset(0, 4.0),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(isTablet ? 12.0 : 10.0),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: isTablet ? 24.0 : 22.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Animated title with icon
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: Duration(milliseconds: 800),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_stories_rounded,
                      color: const Color(0xFF8E6CFF),
                      size: iconSize,
                    ),
                    SizedBox(width: isTablet ? 8.0 : 6.0),
                    Text(
                      'Story Adventure',
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF8E6CFF),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(width: isTablet ? 108.0 : 92.0),
            ],
          ),
        ),
        SizedBox(height: spacing),

        // Create Story button and My Stories filter in one row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Create Story button with bounce effect on hover
            Expanded(
              flex: 3,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _canCreateStory
                      ? () => _navigateToCreateStory(context)
                      : _showStoryLimitBlockedMessage,
                  child: Container(
                    margin: EdgeInsets.only(
                        left: isTablet ? 24.0 : 20.0,
                        right: isTablet ? 8.0 : 5.0),
                    padding: EdgeInsets.symmetric(
                        vertical: isTablet ? 16.0 : 12.0,
                        horizontal: isTablet ? 18.0 : 14.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _canCreateStory
                            ? [Color(0xFF8E6CFF), Color(0xFF7C4DFF)]
                            : [Color(0xFFB0BEC5), Color(0xFF90A4AE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius:
                          BorderRadius.circular(isTablet ? 20.0 : 18.0),
                      boxShadow: [
                        BoxShadow(
                          color: _canCreateStory
                              ? const Color(0xFF8E6CFF).withValues(alpha: 0.3)
                              : const Color(0xFF607D8B).withValues(alpha: 0.2),
                          blurRadius: isTablet ? 8.0 : 6.0,
                          offset: Offset(0, isTablet ? 6.0 : 4.0),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated pencil icon
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: Duration(milliseconds: 500),
                          builder: (context, value, child) {
                            return Transform.rotate(
                              angle: (1 - value) * 0.4,
                              child: Icon(
                                Icons.create,
                                color: Colors.white,
                                size: isTablet ? 20.0 : 18.0,
                              ),
                            );
                          },
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Create Story',
                          style: TextStyle(
                            fontSize: isTablet ? 16.0 : 14.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(
                                alpha: _canCreateStory ? 1.0 : 0.88),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // My Stories filter with animated badge
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showOnlyMyStories = !_showOnlyMyStories;
                  });
                },
                child: Container(
                  margin: EdgeInsets.only(left: 6, right: 24),
                  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color:
                        _showOnlyMyStories ? Color(0xFFFFF3E0) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _showOnlyMyStories
                          ? Colors.orange
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showOnlyMyStories
                            ? Icons.bookmark
                            : Icons.bookmark_outline,
                        color: _showOnlyMyStories ? Colors.orange : Colors.grey,
                        size: 16, // Slightly smaller icon
                      ),
                      SizedBox(width: 2), // Reduced spacing
                      Flexible(
                        child: Text(
                          'My Stories',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _showOnlyMyStories
                                ? Colors.orange
                                : Colors.grey.shade700,
                            fontWeight: _showOnlyMyStories
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 12, // Smaller font size
                          ),
                        ),
                      ),
                      SizedBox(width: 2), // Reduced spacing
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.8, end: 1.2),
                        duration: Duration(milliseconds: 800),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: _showOnlyMyStories
                                ? (0.9 + (value * 0.1))
                                : 1.0,
                            child: child,
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1), // Smaller padding
                          decoration: BoxDecoration(
                            color: _showOnlyMyStories
                                ? Colors.orange
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$_userCreatedStoriesCount',
                            style: TextStyle(
                              color: _showOnlyMyStories
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontSize: 10, // Smaller font
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (_storyQuotaStatus != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF8E6CFF).withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                _isPremiumUser
                    ? 'Premium stories left: ${_storyQuotaStatus!.remainingToday}/${_storyQuotaStatus!.dailyLimit} today • ${_storyQuotaStatus!.remainingThisWeek}/${_storyQuotaStatus!.weeklyLimit} this week'
                    : 'Free stories left: ${_storyQuotaStatus!.remainingToday}/${_storyQuotaStatus!.dailyLimit} today • ${_storyQuotaStatus!.remainingThisWeek}/${_storyQuotaStatus!.weeklyLimit} this week',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF355C7D),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Improve the category filter chips with icons
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _categories.map((category) {
              final isSelected = category == _selectedCategory;

              // Get icon based on category
              IconData iconData;
              switch (category) {
                case 'Adventure':
                  iconData = Icons.explore;
                  break;
                case 'Animals':
                  iconData = Icons.pets;
                  break;
                case 'Space':
                  iconData = Icons.rocket_launch;
                  break;
                case 'Fantasy':
                  iconData = Icons.auto_fix_high;
                  break;
                case 'Nature':
                  iconData = Icons.park;
                  break;
                default:
                  iconData = Icons.category;
              }

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (category != 'All') ...[
                        Icon(
                          iconData,
                          size: 16,
                          color: isSelected
                              ? const Color(0xFF8E6CFF)
                              : const Color(0xFF26324A).withValues(alpha: 0.6),
                        ),
                        SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          category,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF8E6CFF)
                                : const Color(0xFF26324A),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = selected ? category : 'All';
                    });
                  },
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xFF8E6CFF).withValues(alpha: 0.2),
                  checkmarkColor: const Color(0xFF8E6CFF),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? const Color(0xFF8E6CFF)
                        : const Color(0xFF26324A),
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  elevation: 1,
                  pressElevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color:
                          isSelected ? Color(0xFF8E6CFF) : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // Improve the difficulty filter chips with icons
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _difficulties.map((difficulty) {
              final isSelected = difficulty == _selectedDifficulty;

              // Function to get difficulty color
              Color getDifficultyColor(String diff) {
                switch (diff) {
                  case 'Easy':
                    return Color(0xFF4CAF50); // Green
                  case 'Medium':
                    return Color(0xFFFFA000); // Amber
                  case 'Hard':
                    return Color(0xFFF44336); // Red
                  default:
                    return Color(0xFF8E6CFF); // Purple
                }
              }

              // Get icon based on difficulty
              IconData iconData;
              switch (difficulty) {
                case 'Easy':
                  iconData = Icons.sentiment_very_satisfied;
                  break;
                case 'Medium':
                  iconData = Icons.sentiment_satisfied;
                  break;
                case 'Hard':
                  iconData = Icons.sentiment_satisfied_alt;
                  break;
                default:
                  iconData = Icons.filter_list;
              }

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (difficulty != 'All') ...[
                        Icon(
                          iconData,
                          size: 16,
                          color: isSelected
                              ? getDifficultyColor(difficulty)
                              : const Color(0xFF26324A).withValues(alpha: 0.6),
                        ),
                        SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          difficulty,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? getDifficultyColor(difficulty)
                                : const Color(0xFF26324A),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedDifficulty = selected ? difficulty : 'All';
                    });
                  },
                  backgroundColor: Colors.white,
                  selectedColor: isSelected
                      ? getDifficultyColor(difficulty).withValues(alpha: 0.2)
                      : null,
                  checkmarkColor: getDifficultyColor(difficulty),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? getDifficultyColor(difficulty)
                        : const Color(0xFF26324A),
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  elevation: 1,
                  pressElevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? getDifficultyColor(difficulty)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        // Stories List
        Expanded(
          child: _loading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Fun animated loading indicator
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF8E6CFF).withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Rotating book icon
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 2 * 3.14159),
                              duration: Duration(seconds: 2),
                              builder: (context, value, child) {
                                return Transform.rotate(
                                  angle: value,
                                  child: child,
                                );
                              },
                              child: Icon(
                                Icons.auto_stories,
                                color: Color(0xFF8E6CFF),
                                size: 64,
                              ),
                            ),
                            // Pulsing circle around it
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.8, end: 1.2),
                              duration: Duration(milliseconds: 1500),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Color(0xFF8E6CFF)
                                            .withValues(alpha: 0.5),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Loading exciting stories...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8E6CFF),
                        ),
                      ),
                    ],
                  ),
                )
              : _filteredStories.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      itemCount: _filteredStories.length,
                      itemBuilder: (context, i) {
                        final story = _filteredStories[i];
                        return _buildStoryCard(story, context);
                      },
                    ),
        ),
      ],
    );
  }

  // Helper method to build each story card
  Widget _buildStoryCard(Story story, BuildContext context) {
    // Function to get difficulty color
    Color getDifficultyColor(String diff) {
      switch (diff) {
        case 'Easy':
          return Color(0xFF4CAF50); // Green
        case 'Medium':
          return Color(0xFFFFA000); // Amber
        case 'Hard':
          return Color(0xFFF44336); // Red
        default:
          return Color(0xFF8E6CFF); // Purple
      }
    }

    // Get category icon
    IconData getCategoryIcon(String category) {
      switch (category) {
        case 'Adventure':
          return Icons.explore;
        case 'Animals':
          return Icons.pets;
        case 'Space':
          return Icons.rocket_launch;
        case 'Fantasy':
          return Icons.auto_fix_high;
        case 'Nature':
          return Icons.park;
        default:
          return Icons.category;
      }
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.95, end: 1.0),
      duration: Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: () => _selectStory(story),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                splashColor: Color(0xFF8E6CFF).withValues(alpha: 0.1),
                highlightColor: Color(0xFF8E6CFF).withValues(alpha: 0.05),
                onTap: () => _selectStory(story),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Animated emoji with colorful background
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: Duration(milliseconds: 800),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: 0.8 + (value * 0.2),
                            child: child,
                          );
                        },
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Color(0xFFE3F2FD),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF90CAF9).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              story.emoji,
                              style: const TextStyle(fontSize: 40),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Story details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title with optional "My Story" indicator
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    story.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF26324A),
                                    ),
                                  ),
                                ),
                                if (story.isUserCreated)
                                  Icon(
                                    Icons.bookmark,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Tags row
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                // Category tag with icon
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8E6CFF)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        getCategoryIcon(story.category),
                                        color: Color(0xFF8E6CFF),
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          story.category,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF8E6CFF),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Difficulty tag with icon
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: getDifficultyColor(story.difficulty)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        story.difficulty == 'Easy'
                                            ? Icons.sentiment_very_satisfied
                                            : story.difficulty == 'Medium'
                                                ? Icons.sentiment_satisfied
                                                : Icons.sentiment_satisfied_alt,
                                        color: getDifficultyColor(
                                            story.difficulty),
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          story.difficulty,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: getDifficultyColor(
                                                story.difficulty),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // My Story tag (if user created)
                                if (story.isUserCreated)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.edit,
                                          size: 14,
                                          color: Colors.orange,
                                        ),
                                        SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            "My Story",
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Edit/Delete buttons for user-created stories with animated icon
                      if (story.isUserCreated) ...[
                        Column(
                          children: [
                            // Edit button with bounce effect
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.9, end: 1.0),
                              duration: Duration(milliseconds: 500),
                              curve: Curves.elasticOut,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: child,
                                );
                              },
                              child: IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Color(0xFF8E6CFF)),
                                tooltip: 'Edit Story',
                                onPressed: () => _editStory(story),
                              ),
                            ),

                            // Delete button with bounce effect
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.9, end: 1.0),
                              duration: Duration(
                                  milliseconds: 600), // Slightly delayed
                              curve: Curves.elasticOut,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: child,
                                );
                              },
                              child: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Delete Story',
                                onPressed: () => _deleteStory(story),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Animated arrow icon for non-user-created stories
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset((1 - value) * 8, 0),
                              child: child,
                            );
                          },
                          child: Icon(
                            Icons.arrow_forward_ios,
                            color: Color(0xFF8E6CFF),
                            size: 20,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // New method to show help dialog
  void _showHelpAndInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline, color: Color(0xFF8E6CFF)),
            SizedBox(width: 8),
            Text('How to Use'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Story Adventure helps children practice reading:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              _buildHelpItem(
                icon: Icons.filter_list,
                text: 'Filter stories by category and difficulty level',
              ),
              _buildHelpItem(
                icon: Icons.menu_book,
                text: 'Tap any story to start reading',
              ),
              _buildHelpItem(
                icon: Icons.record_voice_over,
                text: 'Choose between AI Storyteller or Device Voice',
              ),
              _buildHelpItem(
                icon: Icons.touch_app,
                text: 'Tap any word to hear it spoken',
              ),
              _buildHelpItem(
                icon: Icons.play_arrow,
                text: 'Use Play, Pause, and Stop to control reading',
              ),
              _buildHelpItem(
                icon: Icons.speed,
                text:
                    'Adjust reading speed with the slider (Device Voice only)',
              ),
              _buildHelpItem(
                icon: Icons.create,
                text:
                    'Create your own stories with the "Create Your Own Story" button',
              ),
              _buildHelpItem(
                icon: Icons.edit,
                text: 'Edit or delete your created stories',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Color(0xFF8E6CFF),
            ),
            child: Text('Got it!'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // Helper method to build help items
  Widget _buildHelpItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Color(0xFF8E6CFF), size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }

  // The existing methods remain unchanged below:
  Widget _buildStoryReader(BuildContext context, Story story) {
    // If word list is empty, build it
    if (_wordList.isEmpty) {
      _buildWordList('${story.title}. ${story.content}');
    }

    final wordRegex = RegExp(r"[\w'']+|[.,!?;:]");
    final titleWords =
        wordRegex.allMatches(story.title).map((m) => m.group(0)!).toList();
    final contentLines = story.content.split('\n');

    // Check if this is a tablet-sized screen
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    // Responsive sizing
    final horizontalPadding = isTablet ? 24.0 : 16.0;
    final verticalPadding = isTablet ? 16.0 : 12.0;
    final borderRadius = isTablet ? 24.0 : 20.0;
    final iconSize = isTablet ? 28.0 : 24.0;
    final titleFontSize = isTablet ? 20.0 : 18.0;
    final bodyFontSize = isTablet ? 18.0 : 16.0;
    final spacing = isTablet ? 16.0 : 12.0;

    return Column(
      children: [
        // Enhanced App Bar
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding, vertical: verticalPadding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(borderRadius),
              bottomRight: Radius.circular(borderRadius),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8.0,
                offset: const Offset(0, 4.0),
              ),
            ],
          ),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () {
                  // Make sure to stop audio when going back to selection
                  _stopAllAudio();
                  _backToSelection();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E6CFF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x338E6CFF),
                        blurRadius: 8.0,
                        offset: const Offset(0, 4.0),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(isTablet ? 12.0 : 10.0),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
              ),
              SizedBox(width: spacing),

              // Story title with emoji
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isTablet ? 8.0 : 6.0),
                      decoration: BoxDecoration(
                        color: Color(0xFFE3F2FD),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        story.emoji,
                        style: TextStyle(fontSize: isTablet ? 20.0 : 18.0),
                      ),
                    ),
                    SizedBox(width: isTablet ? 12.0 : 8.0),
                    Flexible(
                      child: Text(
                        story.title,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8E6CFF),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),

              // Help button
              IconButton(
                icon: Icon(Icons.help_outline,
                    color: Color(0xFF8E6CFF), size: iconSize),
                tooltip: 'How to use',
                onPressed: () {
                  _showHelpAndInfoDialog(context);
                },
              ),
            ],
          ),
        ),

        // Story Content Area - optimized for tablets
        Expanded(
          child: Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(
                horizontal: horizontalPadding, vertical: isTablet ? 8.0 : 12.0),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF90CAF9).withValues(alpha: 0.2),
                  blurRadius: 6.0,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background decorations for the story content
                Positioned(
                  top: -20.0,
                  right: -20.0,
                  child: Container(
                    width: 80.0,
                    height: 80.0,
                    decoration: BoxDecoration(
                      color: Color(0xFF90CAF9).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -25.0,
                  left: -25.0,
                  child: Container(
                    width: 120.0,
                    height: 120.0,
                    decoration: BoxDecoration(
                      color: Color(0xFF90CAF9).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                // Scrollable story content
                SingleChildScrollView(
                  padding: EdgeInsets.all(horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Story metadata card - more compact on tablets
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(bottom: isTablet ? 12.0 : 16.0),
                        padding: EdgeInsets.all(isTablet ? 12.0 : 16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(isTablet ? 16.0 : 14.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 3.0,
                              offset: const Offset(0, 2.0),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title section
                            Center(
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: isTablet ? 6.0 : 4.0,
                                runSpacing: isTablet ? 6.0 : 4.0,
                                children: () {
                                  List<Widget> titleWidgets = [];
                                  int actualWordIndex =
                                      0; // Only count actual words, not punctuation

                                  for (int i = 0; i < titleWords.length; i++) {
                                    if (titleWords[i]
                                        .contains(RegExp(r"[\w'']+"))) {
                                      // This is an actual word
                                      titleWidgets.add(WordCard(
                                        word: titleWords[i],
                                        isTitle: true,
                                        flutterTts: _flutterTts,
                                        isCurrentWord: _isWordHighlighted(
                                            actualWordIndex, true),
                                        onTap: () async {
                                          debugPrint(
                                              'Title word tapped: "${titleWords[i]}" at word index $actualWordIndex');
                                          await _flutterTts.stop();
                                          await _flutterTts
                                              .speak(titleWords[i]);
                                        },
                                      ));
                                      actualWordIndex++; // Only increment for actual words
                                    } else {
                                      // This is punctuation
                                      titleWidgets.add(Text(
                                        titleWords[i],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: titleFontSize,
                                          color: Color(0xFF8E6CFF),
                                        ),
                                      ));
                                    }
                                  }
                                  return titleWidgets;
                                }(),
                              ),
                            ),

                            Divider(
                                height: isTablet ? 20.0 : 24.0,
                                thickness: 1,
                                color: Color(0xFFE0E0E0)),

                            // Category and difficulty badges
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: isTablet ? 10.0 : 8.0,
                              runSpacing: isTablet ? 8.0 : 6.0,
                              children: [
                                _buildInfoBadge(
                                  icon: Icons.category,
                                  label: story.category,
                                  color: Color(0xFF8E6CFF),
                                ),
                                _buildInfoBadge(
                                  icon: Icons.signal_cellular_alt,
                                  label: story.difficulty,
                                  color: _getDifficultyColor(story.difficulty),
                                ),
                                if (story.isUserCreated)
                                  _buildInfoBadge(
                                    icon: Icons.edit,
                                    label: "My Story",
                                    color: Colors.orange,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Story content - more compact spacing on tablets
                      for (int lineIdx = 0;
                          lineIdx < contentLines.length;
                          lineIdx++)
                        Padding(
                          padding:
                              EdgeInsets.only(bottom: isTablet ? 6.0 : 8.0),
                          child: Builder(
                            builder: (context) {
                              final words = wordRegex
                                  .allMatches(contentLines[lineIdx])
                                  .map((m) => m.group(0)!)
                                  .toList();
                              List<Widget> widgets = [];

                              // Track content word index (excluding title words and punctuation)
                              int contentWordIndex = 0;
                              for (int i = 0; i < lineIdx; i++) {
                                final lineWordsOnly = RegExp(r"[\w'']+")
                                    .allMatches(contentLines[i])
                                    .toList();
                                contentWordIndex += lineWordsOnly.length;
                              }

                              // Track actual word count within this line (excluding punctuation)
                              int actualWordIndexInLine = 0;

                              for (int wordIdx = 0;
                                  wordIdx < words.length;
                                  wordIdx++) {
                                final word = words[wordIdx];
                                if (word.contains(RegExp(r"[\w'']+"))) {
                                  final currentContentWordIndex =
                                      contentWordIndex + actualWordIndexInLine;
                                  widgets.add(WordCard(
                                    word: word,
                                    isTitle: false,
                                    flutterTts: _flutterTts,
                                    isCurrentWord: _isWordHighlighted(
                                        currentContentWordIndex, false),
                                    onTap: () async {
                                      debugPrint(
                                          'Word tapped: "$word" at line $lineIdx, content word index $currentContentWordIndex');
                                      await _flutterTts.stop();
                                      await _flutterTts.speak(word);
                                    },
                                  ));
                                  actualWordIndexInLine++; // Only increment for actual words
                                } else {
                                  widgets.add(Text(
                                    word,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: bodyFontSize,
                                      color: Color(0xFF26324A),
                                    ),
                                  ));
                                }
                              }
                              return Wrap(
                                alignment: WrapAlignment.start,
                                spacing: isTablet ? 8.0 : 6.0,
                                runSpacing: isTablet ? 6.0 : 4.0,
                                children: widgets,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Controls section with responsive height based on device type
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(borderRadius),
              topRight: Radius.circular(borderRadius),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8.0,
                offset: const Offset(0, -4.0),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
              spacing, isTablet ? 12.0 : 16.0, spacing, isTablet ? 16.0 : 20.0),
          constraints: BoxConstraints(maxHeight: isTablet ? 180.0 : 280.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reading mode toggle - more compact on tablets
                Container(
                  padding: EdgeInsets.symmetric(
                      vertical: isTablet ? 8.0 : 10.0, horizontal: spacing),
                  decoration: BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Reading Mode:',
                        style: TextStyle(
                          fontSize: isTablet ? 12.0 : 14.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF26324A),
                        ),
                      ),
                      SizedBox(height: isTablet ? 6.0 : 8.0),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // AI Storyteller button
                          _buildReadingModeButton(
                            isSelected: _isUsingElevenLabs,
                            icon: Icons.auto_awesome,
                            text: 'AI Storyteller',
                            color: Color(0xFFFF9800),
                            showDownloadIcon:
                                !_aiVoiceAvailable && _isUsingElevenLabs,
                            onTap: () {
                              setState(() {
                                _isUsingElevenLabs = true;
                              });
                            },
                          ),
                          SizedBox(width: isTablet ? 8.0 : 6.0),
                          // Device Voice button
                          _buildReadingModeButton(
                            isSelected: !_isUsingElevenLabs,
                            icon: Icons.phone_android,
                            text: 'Device Voice',
                            color: Color(0xFF8E6CFF),
                            onTap: () {
                              setState(() {
                                _isUsingElevenLabs = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: isTablet ? 8.0 : 12.0),

                // Play controls - different based on selected voice mode
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _isUsingElevenLabs
                      ? _buildAIVoiceControls()
                      : _buildDeviceVoiceControls(),
                ),

                // Only show slider for device voice (FlutterTTS) - more compact on tablets
                if (!_isUsingElevenLabs) ...[
                  SizedBox(height: isTablet ? 8.0 : 12.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Slow icon
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.slow_motion_video,
                              color: Color(0xFF26324A),
                              size: isTablet ? 18.0 : 20.0),
                          Text('Slow',
                              style: TextStyle(
                                  fontSize: isTablet ? 11.0 : 12.0,
                                  color: Color(0xFF26324A))),
                        ],
                      ),

                      // Slider
                      SizedBox(
                        width: isTablet ? 160.0 : 200.0,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: isTablet ? 4.0 : 6.0,
                            thumbShape: RoundSliderThumbShape(
                                enabledThumbRadius: isTablet ? 10.0 : 12.0),
                            overlayShape: RoundSliderOverlayShape(
                                overlayRadius: isTablet ? 18.0 : 22.0),
                            valueIndicatorTextStyle: TextStyle(
                                fontSize: isTablet ? 12.0 : 14.0,
                                fontWeight: FontWeight.bold),
                          ),
                          child: Slider(
                            value: _speechRate,
                            min: 0.2,
                            max: 0.6,
                            divisions: 8,
                            label: _speechRate.toStringAsFixed(2),
                            onChanged: (v) async {
                              setState(() => _speechRate = v);
                              await _flutterTts.setSpeechRate(v);
                            },
                            activeColor: Color(0xFF8E6CFF),
                            inactiveColor:
                                Color(0xFF8E6CFF).withValues(alpha: 0.2),
                          ),
                        ),
                      ),

                      // Fast icon
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.speed,
                              color: Color(0xFF26324A),
                              size: isTablet ? 18.0 : 20.0),
                          Text('Fast',
                              style: TextStyle(
                                  fontSize: isTablet ? 11.0 : 12.0,
                                  color: Color(0xFF26324A))),
                        ],
                      ),
                    ],
                  ),
                ],

                // Only show voice selector for device voice (FlutterTTS) - more compact on tablets
                if (!_isUsingElevenLabs && _voices.isNotEmpty) ...[
                  SizedBox(height: isTablet ? 8.0 : 12.0),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: spacing, vertical: isTablet ? 6.0 : 8.0),
                    decoration: BoxDecoration(
                      color: Color(0xFFF5F5F5),
                      borderRadius:
                          BorderRadius.circular(isTablet ? 12.0 : 10.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.record_voice_over,
                            color: Color(0xFF8E6CFF),
                            size: isTablet ? 16.0 : 18.0),
                        SizedBox(width: isTablet ? 8.0 : 6.0),
                        Text(
                          'Voice:',
                          style: TextStyle(
                              fontSize: isTablet ? 12.0 : 13.0,
                              color: Color(0xFF26324A),
                              fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: isTablet ? 8.0 : 6.0),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 10.0 : 8.0,
                              vertical: isTablet ? 4.0 : 3.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(isTablet ? 10.0 : 8.0),
                            border: Border.all(
                                color: const Color(0xFF8E6CFF)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: DropdownButton<dynamic>(
                            value: _selectedVoice,
                            items: _voices.map((voice) {
                              return DropdownMenuItem(
                                value: voice,
                                child: Text(
                                  _getVoiceDescription(voice),
                                  style: TextStyle(
                                      fontSize: isTablet ? 11.0 : 12.0,
                                      color: Color(0xFF26324A)),
                                ),
                              );
                            }).toList(),
                            onChanged: (voice) async {
                              setState(() => _selectedVoice = voice);
                              await _flutterTts
                                  .setVoice(Map<String, String>.from(voice));
                            },
                            underline: const SizedBox(),
                            icon: Icon(Icons.arrow_drop_down,
                                color: Color(0xFF8E6CFF),
                                size: isTablet ? 18.0 : 16.0),
                            dropdownColor: Colors.white,
                            style: TextStyle(color: Color(0xFF26324A)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Helper method for difficulty colors
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return Color(0xFF4CAF50); // Green
      case 'Medium':
        return Color(0xFFFFA000); // Amber
      case 'Hard':
        return Color(0xFFF44336); // Red
      default:
        return Color(0xFF8E6CFF); // Purple
    }
  }

  // Helper method to build info badges
  Widget _buildInfoBadge(
      {required IconData icon, required String label, required Color color}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 10.0 : 8.0, vertical: isTablet ? 6.0 : 4.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(isTablet ? 14.0 : 12.0),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isTablet ? 14.0 : 12.0, color: color),
          SizedBox(width: isTablet ? 6.0 : 4.0),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: isTablet ? 12.0 : 11.0,
            ),
          ),
        ],
      ),
    );
  }

  // Build controls for AI voice (ElevenLabs)
  List<Widget> _buildAIVoiceControls() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    if (_isGeneratingAudio) {
      return [
        Container(
          padding: EdgeInsets.all(isTablet ? 20.0 : 16.0),
          decoration: BoxDecoration(
            color: Color(0xFFFFE0B2),
            borderRadius: BorderRadius.circular(isTablet ? 16.0 : 14.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6.0,
                offset: const Offset(0, 3.0),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Loading animation
              SizedBox(
                height: isTablet ? 60.0 : 50.0,
                width: isTablet ? 60.0 : 50.0,
                child: Stack(
                  children: [
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFFF9800)),
                      strokeWidth: isTablet ? 5.0 : 4.0,
                    ),
                    Center(
                      child: Icon(
                        Icons.auto_awesome,
                        color: Color(0xFFFF9800),
                        size: isTablet ? 28.0 : 24.0,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isTablet ? 16.0 : 12.0),
              Text(
                'Generating AI Narration...',
                style: TextStyle(
                  fontSize: isTablet ? 16.0 : 14.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF26324A),
                ),
              ),
              SizedBox(height: isTablet ? 8.0 : 6.0),
              Text(
                'This may take a minute',
                style: TextStyle(
                  fontSize: isTablet ? 12.0 : 11.0,
                  color: Color(0xFF26324A).withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    if (_audioGenerationFailed) {
      return [
        Container(
          padding: EdgeInsets.all(isTablet ? 20.0 : 16.0),
          decoration: BoxDecoration(
            color: Color(0xFFFFDDDD),
            borderRadius: BorderRadius.circular(isTablet ? 16.0 : 14.0),
            border: Border.all(color: Colors.red.shade300),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: isTablet ? 36.0 : 32.0,
              ),
              SizedBox(height: isTablet ? 16.0 : 12.0),
              Text(
                'Failed to generate AI voice',
                style: TextStyle(
                  fontSize: isTablet ? 16.0 : 14.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF26324A),
                ),
              ),
              SizedBox(height: isTablet ? 8.0 : 6.0),
              Text(
                'Please try again or switch to device voice',
                style: TextStyle(
                  fontSize: isTablet ? 12.0 : 11.0,
                  color: Color(0xFF26324A).withValues(alpha: 0.7),
                ),
              ),
              SizedBox(height: isTablet ? 16.0 : 12.0),
              ElevatedButton.icon(
                onPressed: _playAIVoiceAudio,
                icon: Icon(Icons.refresh,
                    color: Colors.white, size: isTablet ? 18.0 : 16.0),
                label: Text('Try Again',
                    style: TextStyle(
                        color: Colors.white, fontSize: isTablet ? 14.0 : 12.0)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(isTablet ? 12.0 : 10.0)),
                  padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20.0 : 16.0,
                      vertical: isTablet ? 10.0 : 8.0),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    // Normal AI voice controls with voice selection
    return [
      Column(
        children: [
          // Compact voice selection and play button in one row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Voice selection dropdown (compact)
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 10.0 : 8.0,
                    vertical: isTablet ? 6.0 : 4.0),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(isTablet ? 12.0 : 10.0),
                  border: Border.all(
                      color: Color(0xFFFF9800).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.record_voice_over,
                      color: Color(0xFFFF9800),
                      size: isTablet ? 14.0 : 12.0,
                    ),
                    SizedBox(width: isTablet ? 4.0 : 3.0),
                    DropdownButton<String>(
                      value: _selectedVoiceId,
                      underline: SizedBox(),
                      icon: Icon(Icons.arrow_drop_down,
                          color: Color(0xFFFF9800),
                          size: isTablet ? 16.0 : 14.0),
                      style: TextStyle(
                        color: Color(0xFF26324A),
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 11.0 : 10.0,
                      ),
                      isDense: true,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedVoiceId = newValue;
                            if (_selectedStory != null &&
                                _selectedStory!.id != null) {
                              _elevenLabsService
                                  .hasAudioFile(_selectedStory!.id!,
                                      voiceId: newValue)
                                  .then((exists) {
                                setState(() {
                                  _aiVoiceAvailable = exists;
                                });
                              });
                            }
                          });
                        }
                      },
                      items: ElevenLabsService.availableVoices
                          .map<DropdownMenuItem<String>>(
                              (Map<String, String> voice) {
                        return DropdownMenuItem<String>(
                          value: voice['id'],
                          child: Text(voice['name']!,
                              style:
                                  TextStyle(fontSize: isTablet ? 11.0 : 10.0)),
                        );
                      }).toList(),
                    ),
                    if (!_aiVoiceAvailable) ...[
                      SizedBox(width: isTablet ? 3.0 : 2.0),
                      Icon(
                        Icons.cloud_download,
                        color: Color(0xFFFF9800),
                        size: isTablet ? 14.0 : 12.0,
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(width: isTablet ? 10.0 : 8.0),

              // Play button (compact)
              if (!_isPlaying)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(isTablet ? 14.0 : 12.0),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFFF9800).withValues(alpha: 0.3),
                        blurRadius: 4.0,
                        offset: const Offset(0, 2.0),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _playAIVoiceAudio,
                    icon: Icon(Icons.smart_toy,
                        size: isTablet ? 16.0 : 14.0, color: Colors.white),
                    label: Text(
                      'Read',
                      style: TextStyle(
                        fontSize: isTablet ? 12.0 : 11.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(isTablet ? 14.0 : 12.0)),
                      padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 14.0 : 12.0,
                          vertical: isTablet ? 10.0 : 8.0),
                      elevation: 0,
                    ),
                  ),
                ),

              // Playback control buttons (compact)
              if (_isPlaying || _isPaused) ...[
                // Control buttons container
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 10.0 : 8.0,
                      vertical: isTablet ? 6.0 : 4.0),
                  decoration: BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(isTablet ? 14.0 : 12.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pause/Resume button
                      if (_isPlaying && !_isPaused)
                        GestureDetector(
                          onTap: _pauseAIVoiceAudio,
                          child: Container(
                            padding: EdgeInsets.all(isTablet ? 6.0 : 4.0),
                            decoration: BoxDecoration(
                              color: Color(0xFFE3F2FD),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.pause_rounded,
                                size: isTablet ? 16.0 : 14.0,
                                color: Color(0xFF26324A)),
                          ),
                        ),

                      if (_isPaused)
                        GestureDetector(
                          onTap: _resumeAIVoiceAudio,
                          child: Container(
                            padding: EdgeInsets.all(isTablet ? 6.0 : 4.0),
                            decoration: BoxDecoration(
                              color: Color(0xFFE3F2FD),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.play_arrow_rounded,
                                size: isTablet ? 16.0 : 14.0,
                                color: Color(0xFF26324A)),
                          ),
                        ),

                      SizedBox(width: isTablet ? 8.0 : 6.0),

                      // Stop button
                      GestureDetector(
                        onTap: _stopAIVoiceAudio,
                        child: Container(
                          padding: EdgeInsets.all(isTablet ? 6.0 : 4.0),
                          decoration: BoxDecoration(
                            color: Color(0xFFFFCDD2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.stop_rounded,
                              size: isTablet ? 16.0 : 14.0,
                              color: Color(0xFF26324A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ];
  }

  // Build controls for device voice (FlutterTTS)
  List<Widget> _buildDeviceVoiceControls() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return [
      // Play button with gradient
      if (!_isPlaying)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8E6CFF), Color(0xFF7C4DFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(isTablet ? 20.0 : 18.0),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF8E6CFF).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _playDeviceTTS,
            icon: Icon(Icons.volume_up_rounded,
                size: isTablet ? 32.0 : 28.0, color: Colors.white),
            label: Text(
              'Read Aloud',
              style: TextStyle(
                fontSize: isTablet ? 20.0 : 18.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isTablet ? 20.0 : 18.0)),
              padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 28.0 : 24.0,
                  vertical: isTablet ? 16.0 : 14.0),
              elevation: 0,
            ),
          ),
        ),

      // Playback control buttons
      if (_isPlaying || _isPaused) ...[
        // Control buttons container
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20.0 : 16.0,
              vertical: isTablet ? 10.0 : 8.0),
          decoration: BoxDecoration(
            color: Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(isTablet ? 28.0 : 24.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pause/Resume button
              if (_isPlaying && !_isPaused)
                IconButton(
                  onPressed: _pauseDeviceTTS,
                  icon: Container(
                    padding: EdgeInsets.all(isTablet ? 10.0 : 8.0),
                    decoration: BoxDecoration(
                      color: Color(0xFFE3F2FD),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.pause_rounded,
                        size: isTablet ? 30.0 : 26.0, color: Color(0xFF26324A)),
                  ),
                  tooltip: 'Pause',
                  iconSize: isTablet ? 50.0 : 42.0,
                ),

              if (_isPaused)
                IconButton(
                  onPressed: _resumeDeviceTTS,
                  icon: Container(
                    padding: EdgeInsets.all(isTablet ? 10.0 : 8.0),
                    decoration: BoxDecoration(
                      color: Color(0xFFE3F2FD),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.play_arrow_rounded,
                        size: isTablet ? 30.0 : 26.0, color: Color(0xFF26324A)),
                  ),
                  tooltip: 'Resume',
                  iconSize: isTablet ? 50.0 : 42.0,
                ),

              SizedBox(width: isTablet ? 20.0 : 16.0),

              // Stop button
              IconButton(
                onPressed: _stopAllAudio,
                icon: Container(
                  padding: EdgeInsets.all(isTablet ? 10.0 : 8.0),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFCDD2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.stop_rounded,
                      size: isTablet ? 30.0 : 26.0, color: Color(0xFF26324A)),
                ),
                tooltip: 'Stop',
                iconSize: isTablet ? 50.0 : 42.0,
              ),
            ],
          ),
        ),
      ],
    ];
  }

  int findWordStartPosition(String wordToFind) {
    // Look for exact match in word list
    for (var entry in _wordList) {
      if (entry['originalWord'].toString() == wordToFind) {
        return entry['start'] as int;
      }
    }
    return -1;
  }

  void _navigateToCreateStory(BuildContext context) async {
    // Navigate to the create story screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateStoryScreen()),
    );

    // If the user created a story successfully, refresh the story list
    if (result == true) {
      // Enable the My Stories filter to show their new story
      setState(() {
        _showOnlyMyStories = true;
      });
      _fetchStories();
      _refreshStoryQuota();
    }
  }

  void _showStoryLimitBlockedMessage() {
    final status = _storyQuotaStatus;
    final message = status == null
        ? 'Story limit reached right now. Please try again later.'
        : status.buildBlockedMessage(isPremium: _isPremiumUser);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Add edit and delete methods
  void _editStory(Story story) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => CreateStoryScreen(storyToEdit: story)),
    );

    if (result == true) {
      _fetchStories();
      _refreshStoryQuota();
    }
  }

  void _deleteStory(Story story) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Story'),
        content: Text(
            'Are you sure you want to delete "${story.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                if (story.id == null) {
                  throw Exception('Story ID is null');
                }
                final selectedProfileId =
                    context.read<ProfileProvider>().selectedProfileId;
                if (selectedProfileId == null) {
                  throw Exception('No profile selected');
                }

                // Delete all associated audio files for all voices
                await _elevenLabsService.deleteAllAudioFiles(story.id!);

                // Delete the story from the database
                await DatabaseService().deleteStory(
                  story.id!,
                  profileId: selectedProfileId,
                );

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Story deleted successfully')),
                );
                _fetchStories();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting story: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _playAudioFile(int storyId) async {
    try {
      // Get and play the audio file with the selected voice
      final file = await _elevenLabsService.getAudioFile(storyId,
          voiceId: _selectedVoiceId);

      if (file == null || !await file.exists()) {
        debugPrint("Audio file not found or doesn't exist");
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _isPaused = false;
            _audioGenerationFailed = true;
          });
        }
        return;
      }

      // Clean up any existing player first
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        await Future.delayed(Duration(milliseconds: 50));
        await _audioPlayer!.dispose();
        _audioPlayer = null;
      }

      // Create a new player and play the file
      _audioPlayer = AudioPlayer();
      debugPrint("Created new AudioPlayer");

      // Set the audio source first
      debugPrint("Setting audio source from file: ${file.path}");
      await _audioPlayer!.setFilePath(file.path);

      // Get audio duration for word highlighting
      final duration = _audioPlayer!.duration;
      if (duration != null) {
        _totalAudioDuration = duration;
        debugPrint("Audio duration: ${duration.inSeconds} seconds");
      }

      // Store subscriptions to cancel them when needed
      StreamSubscription? stateSubscription;
      StreamSubscription? errorSubscription;
      StreamSubscription? processingSubscription;
      StreamSubscription? positionSubscription;

      // Configure player state change listener
      stateSubscription = _audioPlayer!.playerStateStream.listen((playerState) {
        debugPrint(
            "AudioPlayer state changed: ${playerState.processingState}, playing: ${playerState.playing}");

        if (mounted) {
          setState(() {
            // Update UI based on player state
            if (playerState.processingState == ProcessingState.completed) {
              _isPlaying = false;
              _isPaused = false;
              _currentWordIndex = -1; // Reset highlighting
              _wordHighlightTimer?.cancel();
              debugPrint("Playback completed");
            } else {
              _isPlaying = playerState.playing;
              _isPaused = !playerState.playing &&
                  playerState.processingState != ProcessingState.completed;

              // Start word highlighting when playing starts
              if (playerState.playing && _currentWordIndex == -1) {
                _startWordHighlighting();
              }
            }
          });
        }
      });

      // Configure position listener for word highlighting
      positionSubscription = _audioPlayer!.positionStream.listen((position) {
        _updateWordHighlighting(position);
      });

      // Configure error listener
      errorSubscription = _audioPlayer!.playbackEventStream.listen((event) {
        // debugPrint("Playback event: $event");
      }, onError: (error) {
        debugPrint("Playback error: $error");
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _isPaused = false;
            _audioGenerationFailed = true;
            _currentWordIndex = -1;
          });
        }
        _wordHighlightTimer?.cancel();
      });

      // Make sure subscriptions are cleaned up when the player is done or disposed
      processingSubscription =
          _audioPlayer!.processingStateStream.listen((state) {
        if (state == ProcessingState.idle) {
          stateSubscription?.cancel();
          errorSubscription?.cancel();
          processingSubscription?.cancel();
          positionSubscription?.cancel();
          _wordHighlightTimer?.cancel();
        }

        if (state == ProcessingState.completed) {
          debugPrint("Playback completed");
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _isPaused = false;
              _currentWordIndex = -1;
            });
          }
          _wordHighlightTimer?.cancel();
        }
      });

      // Start playback
      debugPrint("Starting audio playback");
      await _audioPlayer!.play();
    } catch (e) {
      debugPrint("Error in _playAudioFile: $e");
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isPaused = false;
          _audioGenerationFailed = true;
          _currentWordIndex = -1;
        });
      }
      _wordHighlightTimer?.cancel();
    }
  }

  // Method to pause AI voice playback
  Future<void> _pauseAIVoiceAudio() async {
    debugPrint("_pauseAIVoiceAudio called");
    if (_audioPlayer != null) {
      try {
        debugPrint("Pausing audio player");
        await _audioPlayer!.pause();
        // Don't cancel word highlighting timer, just pause it
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _isPaused = true;
          });
        }
        debugPrint("Audio player paused successfully");
      } catch (e) {
        debugPrint("Error pausing AI audio: $e");
        // Try to recover by stopping
        try {
          await _audioPlayer!.stop();
        } catch (_) {}
        _wordHighlightTimer?.cancel();
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _isPaused = false;
            _currentWordIndex = -1;
          });
        }
      }
    } else {
      debugPrint("Cannot pause: audio player is null");
    }
  }

  // Method to resume AI voice playback
  Future<void> _resumeAIVoiceAudio() async {
    debugPrint("_resumeAIVoiceAudio called");
    if (_audioPlayer != null) {
      try {
        debugPrint("Resuming audio player");
        final position = _audioPlayer!.position;
        final duration = _audioPlayer!.duration;

        // Check if we're at the end of the track
        if (duration != null && position >= duration) {
          debugPrint("At end of track, seeking to beginning");
          await _audioPlayer!.seek(Duration.zero);
        }

        debugPrint("Calling play()");
        await _audioPlayer!.play();
        if (mounted) {
          setState(() {
            _isPlaying = true;
            _isPaused = false;
          });
        }
        debugPrint("Audio player resumed successfully");
      } catch (e) {
        debugPrint("Error resuming AI audio: $e");
        // If resume fails, try playing from beginning
        debugPrint("Trying to play from beginning instead");
        _playAIVoiceAudio();
      }
    } else {
      debugPrint("Cannot resume: audio player is null, starting new playback");
      // If audio player is null, start fresh
      _playAIVoiceAudio();
    }
  }

  // Method to stop AI voice playback
  Future<void> _stopAIVoiceAudio() async {
    debugPrint("_stopAIVoiceAudio called");

    // Cancel word highlighting
    _wordHighlightTimer?.cancel();

    if (_audioPlayer != null) {
      try {
        debugPrint("Stopping audio player");
        await _audioPlayer!.stop();
        await _audioPlayer!.dispose();
        _audioPlayer = null;
        debugPrint("Audio player stopped successfully");
      } catch (e) {
        debugPrint("Error stopping AI audio: $e");
      }
    } else {
      debugPrint("Cannot stop: audio player is null");
    }

    if (mounted) {
      setState(() {
        _isPlaying = false;
        _isPaused = false;
        _currentWordIndex = -1; // Reset word highlighting
      });
    }
  }

  // Add a getter to count how many user-created stories exist
  int get _userCreatedStoriesCount {
    return _stories.where((story) => story.isUserCreated).length;
  }

  // Update empty state in the story list
  // Add this method just before the build method or where appropriate
  Widget _buildEmptyState() {
    if (_showOnlyMyStories) {
      // Empty state for "My Stories" filter
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated empty stories illustration
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Book icon
                    Icon(
                      Icons.book,
                      size: 80,
                      color: Colors.orange.withValues(alpha: 0.5),
                    ),
                    // Pencil icon
                    Positioned(
                      top: 40,
                      right: 36,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: Duration(milliseconds: 1200),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.rotate(
                            angle: (1 - value) * 0.5,
                            child: Transform.translate(
                              offset: Offset(0, (1 - value) * 20),
                              child: child,
                            ),
                          );
                        },
                        child: Icon(
                          Icons.edit,
                          size: 40,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Animated text
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 20),
                    child: child,
                  ),
                );
              },
              child: Text(
                'No stories created yet',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),

            SizedBox(height: 12),

            // Animated description
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 20),
                    child: child,
                  ),
                );
              },
              child: Text(
                'Create your own adventures!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Animated button (with delayed appearance using FutureBuilder)
            FutureBuilder(
              future: Future.delayed(Duration(milliseconds: 400)),
              builder: (context, snapshot) {
                return AnimatedOpacity(
                  opacity: snapshot.connectionState == ConnectionState.done
                      ? 1.0
                      : 0.0,
                  duration: Duration(milliseconds: 400),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.8, end: 1.0),
                    duration: Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: child,
                      );
                    },
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToCreateStory(context),
                      icon: Icon(Icons.add, color: Colors.white),
                      label: Text('Start Writing',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding:
                            EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    } else {
      // Empty state for general search (no stories matching filters)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated empty search illustration
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: Color(0xFF8E6CFF).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Book icon
                    Icon(
                      Icons.menu_book,
                      size: 80,
                      color: Color(0xFF8E6CFF).withValues(alpha: 0.5),
                    ),
                    // Magnifying glass
                    Positioned(
                      bottom: 40,
                      right: 36,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: Duration(milliseconds: 1200),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.rotate(
                            angle: (1 - value) * -0.5,
                            child: Transform.translate(
                              offset: Offset((1 - value) * 20, 0),
                              child: child,
                            ),
                          );
                        },
                        child: Icon(
                          Icons.search,
                          size: 40,
                          color: Color(0xFF8E6CFF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Animated text
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 20),
                    child: child,
                  ),
                );
              },
              child: Text(
                'No stories found',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8E6CFF),
                ),
              ),
            ),

            SizedBox(height: 12),

            // Animated description
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 20),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Text(
                  'Try choosing different categories or difficulty levels',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),

            SizedBox(height: 24),

            // Reset filters button (with delayed appearance using FutureBuilder)
            FutureBuilder(
              future: Future.delayed(Duration(milliseconds: 400)),
              builder: (context, snapshot) {
                return AnimatedOpacity(
                  opacity: snapshot.connectionState == ConnectionState.done
                      ? 1.0
                      : 0.0,
                  duration: Duration(milliseconds: 400),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.8, end: 1.0),
                    duration: Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: child,
                      );
                    },
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedCategory = 'All';
                          _selectedDifficulty = 'All';
                        });
                      },
                      icon: Icon(Icons.filter_list_off, color: Colors.white),
                      label: Text('Reset Filters',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF8E6CFF),
                        padding:
                            EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }
  }

  // Helper method to build a reading mode button (for smaller screens)
  Widget _buildReadingModeButton({
    required bool isSelected,
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onTap,
    bool showDownloadIcon = false,
  }) {
    // Check if this is a tablet-sized screen
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
            vertical: isTablet ? 6.0 : 8.0, horizontal: isTablet ? 8.0 : 10.0),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(isTablet ? 12.0 : 10.0),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color:
                  isSelected ? color : Color(0xFF26324A).withValues(alpha: 0.5),
              size: isTablet ? 14.0 : 16.0,
            ),
            SizedBox(width: isTablet ? 4.0 : 6.0),
            Text(
              text,
              style: TextStyle(
                fontSize: isTablet ? 11.0 : 12.0,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? color
                    : Color(0xFF26324A).withValues(alpha: 0.5),
              ),
            ),
            if (showDownloadIcon)
              Padding(
                padding: EdgeInsets.only(left: isTablet ? 4.0 : 6.0),
                child: Tooltip(
                  message: "First time will download AI narration",
                  child: Icon(
                    Icons.cloud_download,
                    color: color,
                    size: isTablet ? 12.0 : 14.0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
