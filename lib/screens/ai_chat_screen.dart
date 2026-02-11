import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import '../models/chat_message.dart';
import '../services/database_service.dart';
import '../services/openai_service.dart';
import '../services/elevenlabs_service.dart';
import '../services/speech_recognition_service.dart';
import '../services/audio_recorder_service.dart';
import '../services/theme_service.dart';
import '../services/ai_usage_limit_service.dart';
import '../services/ai_proxy_config.dart';
import '../services/subscription_service.dart';
import '../providers/profile_provider.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DatabaseService _databaseService = DatabaseService();
  final OpenAIService _openAIService = OpenAIService();
  final ElevenLabsService _elevenLabsService = ElevenLabsService();
  final SpeechRecognitionService _speechRecognitionService =
      SpeechRecognitionService();
  final AudioRecorderService _audioRecorderService = AudioRecorderService();
  final AIUsageLimitService _aiUsageLimitService = AIUsageLimitService();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  bool _isRecording = false;
  AudioPlayer? _audioPlayer;
  int? _currentProfileId;
  String? _currentProfileName;
  int? _currentProfileAge;
  String? _currentProfileAvatar;
  String? _currentProfileAvatarType;
  bool _isPremiumUser = false;
  AiQuotaCheckResult? _chatQuotaStatus;

  bool _useVoiceResponse = true; // Whether to use ElevenLabs for AI responses
  String _selectedVoiceId = '9BWtsMINqrJLrRacOk9x'; // Default voice set to Aria

  // Animation controllers
  late AnimationController _micAnimationController;
  late AnimationController _sendButtonController;

  // Add a flag to control welcome message generation
  bool _skipWelcomeMessage = false;

  // Add new state variable for input mode
  bool _isVoiceInputMode = false;

  // Add input mode animation controller
  late AnimationController _inputModeAnimationController;

  // Add recording animation
  late AnimationController _recordingPulseController;

  // Add variables to track recording time
  int _recordingDuration = 0;
  Timer? _recordingTimer;

  // Add variables for swipe-to-cancel recording
  bool _isShowingCancelHint = false;
  bool _isCancelingRecording = false;

  // Add variable to track if we should show the help tooltip
  bool _showVoiceInputHelp = true;
  bool _isVoiceSettingsSheetOpen = false;

  @override
  void initState() {
    super.initState();

    _micAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _sendButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Initialize input mode animation controller
    _inputModeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Initialize recording pulse animation
    _recordingPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Initialize the speech recognition service
    _speechRecognitionService.initialize();

    // Initialize the audio recorder service
    _audioRecorderService.initialize();

    // Set default voice to Madeline for this screen
    ElevenLabsService.setVoiceId(_selectedVoiceId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get the current profile from the provider
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final currentProfileId = profileProvider.selectedProfileId;
    final subscriptionService =
        Provider.of<SubscriptionService>(context, listen: false);
    _isPremiumUser = subscriptionService.isSubscribed;

    if (currentProfileId != null && _currentProfileId != currentProfileId) {
      _currentProfileId = currentProfileId;
      // Fetch profile details to get name and age
      _loadProfileDetails(currentProfileId);
      _loadMessages().then((_) {
        if (mounted) {
          _addWelcomeMessageIfNeeded();
        }
      });
      _refreshChatQuota();
    } else if (currentProfileId != null) {
      _refreshChatQuota();
    }
  }

  Future<void> _loadProfileDetails(int profileId) async {
    try {
      final profile = await _databaseService.getProfile(profileId);
      if (profile != null && mounted) {
        setState(() {
          _currentProfileName = profile.name;
          _currentProfileAge = profile.age;
          _currentProfileAvatar = profile.avatar;
          _currentProfileAvatarType = profile.avatarType;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile details: $e');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _micAnimationController.dispose();
    _sendButtonController.dispose();
    _inputModeAnimationController.dispose();
    _recordingPulseController.dispose();
    _cancelRecordingTimer();

    // Stop any ongoing audio playback
    _stopAudio();

    // Cleanup
    _audioRecorderService.dispose();

    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final messages = await _databaseService.getChatMessages(
        profileId: _currentProfileId,
        limit: 50, // Load last 50 messages
      );

      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      // Scroll to bottom after messages load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      debugPrint('Error loading messages: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addWelcomeMessageIfNeeded() {
    // Only add welcome message if there are no messages and we're not skipping it
    if (_skipWelcomeMessage) {
      debugPrint('Skipping welcome message due to _skipWelcomeMessage flag');
      // Reset the flag for future app launches
      _skipWelcomeMessage = false;
      return;
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (_messages.isEmpty) {
        debugPrint('Adding welcome message, chat is empty');
        // Get the current voice name for the welcome message
        String currentVoiceName =
            ElevenLabsService.getVoiceNameById(_selectedVoiceId);

        final welcomeMessage = ChatMessage(
          message:
              "Hello${_currentProfileName != null ? ' $_currentProfileName' : ''}! I'm $currentVoiceName. You can ask me questions, and I'll do my best to help you learn new things. What would you like to talk about today?",
          isUserMessage: false,
          timestamp: DateTime.now().toIso8601String(),
          profileId: _currentProfileId,
        );

        _databaseService.insertChatMessage(welcomeMessage);

        setState(() {
          _messages.add(welcomeMessage);
        });

        // Explicitly scroll to make the welcome message visible
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        // Optionally, speak the welcome message
        if (_useVoiceResponse) {
          _generateAndPlayAudioForMessage(welcomeMessage.message);
        }
      } else {
        debugPrint(
            'Not adding welcome message, chat already has ${_messages.length} messages');
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isSending) return;

    final profileId = _currentProfileId;
    if (profileId == null) {
      _showErrorSnackBar('Please select a profile first.');
      return;
    }

    final quotaReservation = await _reserveChatQuota();
    if (quotaReservation == null) {
      return;
    }
    var shouldReleaseReservation = true;

    debugPrint('======== AI CHAT: SENDING MESSAGE ========');
    debugPrint(
        'User text: ${text.substring(0, min(50, text.length))}${text.length > 50 ? '...' : ''}');
    debugPrint('Current profile ID: $_currentProfileId');
    debugPrint('Current profile name: $_currentProfileName');

    // Add user message to the chat
    final userMessage = ChatMessage(
      message: text,
      isUserMessage: true,
      timestamp: DateTime.now().toIso8601String(),
      profileId: _currentProfileId,
    );

    setState(() {
      _messages.add(userMessage);
      _isSending = true;
      _textController.clear();
    });

    // Save user message to database
    debugPrint('Saving user message to database...');
    try {
      await _databaseService.insertChatMessage(userMessage);
      debugPrint('Successfully saved user message to database');
    } catch (e) {
      debugPrint('ERROR saving user message to database: $e');
    }

    // Scroll to bottom with a slight delay to ensure UI has updated
    Future.delayed(const Duration(milliseconds: 50), () {
      _scrollToBottom();
    });

    // Prepare conversation history
    debugPrint('Preparing conversation history...');
    final history = _messages
        .take(_messages.length > 1 ? _messages.length - 1 : 0)
        .map((msg) => {
              'role': msg.isUserMessage ? 'user' : 'assistant',
              'content': msg.message,
            })
        .toList();
    debugPrint('History length: ${history.length} messages');

    // Get AI response
    try {
      debugPrint('🔄 Calling OpenAI API for chat response...');
      debugPrint('OpenAI parameters:');
      debugPrint(
          '  - Message: ${text.substring(0, min(50, text.length))}${text.length > 50 ? '...' : ''}');
      debugPrint('  - Child name: $_currentProfileName');
      debugPrint('  - Child age: $_currentProfileAge');
      debugPrint('  - History length: ${history.length}');

      final response = await _openAIService.generateChatResponse(
        message: text,
        history: history,
        childName: _currentProfileName,
        childAge: _currentProfileAge,
        assistantName: ElevenLabsService.getVoiceNameById(_selectedVoiceId),
        requestContext: AiRequestContext(
          profileId: profileId,
          isPremium: _isPremiumUser,
          feature: 'chat_message',
          units: 1,
        ),
      );

      debugPrint('✅ OpenAI API response received');
      if (response != null) {
        debugPrint('Response length: ${response.length} chars');
        debugPrint(
            'Response preview: ${response.substring(0, min(50, response.length))}${response.length > 50 ? '...' : ''}');

        final aiMessage = ChatMessage(
          message: response,
          isUserMessage: false,
          timestamp: DateTime.now().toIso8601String(),
          profileId: _currentProfileId,
        );

        shouldReleaseReservation = false;
        setState(() {
          _messages.add(aiMessage);
        });

        // Save AI message to database
        debugPrint('Saving AI response to database...');
        final messageId = await _databaseService.insertChatMessage(aiMessage);
        debugPrint('AI message saved with ID: $messageId');

        // Scroll to bottom again after adding AI message with sufficient delay
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollToBottom();
        });

        // Generate and play audio for AI response
        if (_useVoiceResponse) {
          debugPrint('Generating audio for AI response...');
          final audioPath = await _generateAndPlayAudioForMessage(response);

          // If audio was generated successfully, update the message with the audio path
          if (audioPath != null) {
            debugPrint('Audio generated successfully at: $audioPath');
            final updatedAiMessage = ChatMessage(
              id: messageId,
              message: aiMessage.message,
              isUserMessage: aiMessage.isUserMessage,
              audioPath: audioPath,
              timestamp: aiMessage.timestamp,
              profileId: aiMessage.profileId,
            );
            await _databaseService.updateChatMessage(updatedAiMessage);
            if (mounted) {
              setState(() {
                final lastIndex = _messages.lastIndexWhere(
                  (m) =>
                      !m.isUserMessage &&
                      m.timestamp == aiMessage.timestamp &&
                      m.message == aiMessage.message,
                );
                if (lastIndex != -1) {
                  _messages[lastIndex] = updatedAiMessage;
                }
              });
            }
            debugPrint('Chat message updated with audio path');
          } else {
            debugPrint('⚠️ Failed to generate audio for AI response');
          }
        } else {
          debugPrint('Voice response disabled, skipping audio generation');
        }
      } else {
        debugPrint('❌ OpenAI API returned null response');
        _showErrorSnackBar('Sorry, I couldn\'t respond to that right now.');
      }
    } catch (e) {
      debugPrint('❌ ERROR getting AI response: $e');
      _showErrorSnackBar('Something went wrong. Please try again.');
    } finally {
      if (shouldReleaseReservation) {
        await _aiUsageLimitService.releaseCountQuotaReservation(
          quotaReservation.usageEventId,
        );
      }
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
      await _refreshChatQuota();
    }

    debugPrint('======== AI CHAT: MESSAGE PROCESSING COMPLETE ========');
  }

  Future<String?> _generateAndPlayAudioForMessage(String message) async {
    debugPrint('======== AI CHAT: GENERATING AUDIO ========');
    debugPrint('Message length: ${message.length}');
    debugPrint(
        'Voice ID: $_selectedVoiceId (${ElevenLabsService.getVoiceNameById(_selectedVoiceId)})');

    try {
      // Create a unique identifier for this message
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final messageHash = message.hashCode.abs();
      final audioId = messageHash + timestamp;
      debugPrint('Generated audio ID: $audioId');

      // Generate audio using ElevenLabs with faster speech speed
      debugPrint(
          '🔄 Calling ElevenLabs API to generate audio with faster speed...');

      // Create voice settings with faster speed (1.0)
      final voiceSettings = {
        'stability': 0.35,
        'similarity_boost': 1.0,
        'style': 0,
        'use_speaker_boost': true,
        'speed': 1.0, // Set faster speech speed
      };

      final audioPath = await _elevenLabsService.generateAudioWithSettings(
          message, audioId,
          voiceId: _selectedVoiceId, voiceSettings: voiceSettings);

      if (audioPath != null) {
        debugPrint('✅ Audio generated successfully at path: $audioPath');
        _playAudio(audioPath);
        return audioPath;
      } else {
        debugPrint('❌ Failed to generate audio for message');
        return null;
      }
    } catch (e) {
      debugPrint('❌ ERROR generating audio: $e');
      return null;
    } finally {
      debugPrint('======== AI CHAT: AUDIO GENERATION COMPLETE ========');
    }
  }

  Future<void> _playAudio(String audioPath) async {
    try {
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        _showErrorSnackBar('Audio file not found. Please ask Aria again.');
        return;
      }
      final fileLength = await audioFile.length();
      if (fileLength <= 0) {
        _showErrorSnackBar('Audio file is empty. Please ask Aria again.');
        return;
      }

      // Stop any currently playing audio
      await _stopAudio();

      // Create a new audio player
      _audioPlayer = AudioPlayer();

      // Set the audio source and play
      await _audioPlayer!.setFilePath(audioPath);

      // Play the audio
      await _audioPlayer!.play();

      // Listen for completion
      _audioPlayer!.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) {
          if (!mounted) return;
          setState(() {});
        }
      });
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  Future<void> _stopAudio() async {
    if (_audioPlayer != null) {
      try {
        await _audioPlayer!.stop();
        await _audioPlayer!.dispose();
        _audioPlayer = null;
        if (!mounted) return;
        setState(() {});
      } catch (e) {
        debugPrint('Error stopping audio: $e');
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      _isShowingCancelHint = false;
      _isCancelingRecording = false;

      // Give haptic feedback when recording starts
      HapticFeedback.mediumImpact();

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      // Start the mic animation
      _micAnimationController.repeat(reverse: true);

      // Start the recording pulse animation
      _recordingPulseController.repeat();

      // Start recording duration timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration++;
        });
      });

      // Start recording using the audio recorder service
      await _audioRecorderService.startRecording();
    } catch (e) {
      debugPrint('Error starting recording: $e');
      setState(() {
        _isRecording = false;
      });
      _micAnimationController.stop();
      _recordingPulseController.stop();
      _cancelRecordingTimer();
      _showErrorSnackBar('Could not access the microphone');
    }
  }

  Future<void> _stopRecordingAndProcess() async {
    try {
      // Give haptic feedback when recording stops
      HapticFeedback.lightImpact();

      // Stop the animations
      _micAnimationController.stop();
      _micAnimationController.reset();
      _recordingPulseController.stop();
      _recordingPulseController.reset();

      // Cancel recording timer
      _cancelRecordingTimer();

      setState(() {
        _isRecording = false;
        _recordingDuration = 0;
      });

      debugPrint('======== AI CHAT: PROCESSING VOICE INPUT ========');
      // Stop recording
      debugPrint('Stopping audio recording...');
      final recordingPath = await _audioRecorderService.stopRecording();
      debugPrint('Recording saved to: $recordingPath');

      if (recordingPath != null) {
        // Get the recording bytes
        debugPrint('Reading recording bytes...');
        final recordingBytes = await _audioRecorderService.getRecordingBytes();
        debugPrint('Recording size: ${recordingBytes?.length ?? 0} bytes');

        if (recordingBytes != null) {
          // Transcribe using OpenAI Whisper
          debugPrint('🔄 Calling OpenAI Whisper API for transcription...');
          final profileId = _currentProfileId;
          final transcription = await _openAIService.transcribeAudio(
            recordingBytes,
            requestContext: profileId == null
                ? null
                : AiRequestContext(
                    profileId: profileId,
                    isPremium: _isPremiumUser,
                    feature: 'chat_transcription',
                    units: 0,
                  ),
          );

          if (transcription != null && transcription.isNotEmpty) {
            debugPrint('✅ Transcription received: "$transcription"');

            // Send the transcribed text as a message
            await _sendMessage(transcription);
          } else {
            debugPrint('❌ No transcription received from OpenAI Whisper');
            _showErrorSnackBar(
                'I couldn\'t hear what you said. Please try again.');
          }
        } else {
          debugPrint('❌ Failed to read recording bytes');
          _showErrorSnackBar('Error processing audio. Please try again.');
        }
      } else {
        debugPrint('❌ Recording failed, no path returned');
        _showErrorSnackBar('Recording failed. Please try again.');
      }

      // Cleanup the recording file
      debugPrint('Cleaning up recording file...');
      await _audioRecorderService.deleteRecording();
      debugPrint('Recording file deleted');
    } catch (e) {
      debugPrint('❌ ERROR processing recording: $e');
      setState(() {
        _isRecording = false;
      });
      _showErrorSnackBar('Error processing your voice. Please try again.');
    } finally {
      debugPrint('======== AI CHAT: VOICE PROCESSING COMPLETE ========');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      // Use a slightly delayed scroll to ensure layout has been updated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _refreshChatQuota() async {
    final profileId = _currentProfileId;
    if (profileId == null) return;

    final status = await _aiUsageLimitService.getCountQuotaStatus(
      profileId: profileId,
      isPremium: _isPremiumUser,
      feature: AiCountFeature.chatMessage,
    );
    if (!mounted) return;
    setState(() {
      _chatQuotaStatus = status;
    });
  }

  Future<AiQuotaReservation?> _reserveChatQuota() async {
    final profileId = _currentProfileId;
    if (profileId == null) {
      _showErrorSnackBar('Please select a profile first.');
      return null;
    }

    final reservation = await _aiUsageLimitService.reserveCountQuota(
      profileId: profileId,
      isPremium: _isPremiumUser,
      feature: AiCountFeature.chatMessage,
    );
    if (reservation == null) {
      final status = await _aiUsageLimitService.getCountQuotaStatus(
        profileId: profileId,
        isPremium: _isPremiumUser,
        feature: AiCountFeature.chatMessage,
      );
      _showQuotaBlockedDialog(
        title: 'Chat limit reached',
        message: status.buildBlockedMessage(isPremium: _isPremiumUser),
      );
      return null;
    }

    if (!mounted) return reservation;
    setState(() {
      _chatQuotaStatus = reservation.statusAfterReserve;
    });
    return reservation;
  }

  void _showQuotaBlockedDialog({
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          if (!_isPremiumUser)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/subscription');
              },
              child: const Text('Upgrade'),
            ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar() {
    if (_currentProfileAvatar != null && _currentProfileAvatarType != null) {
      if (_currentProfileAvatarType == 'photo') {
        // Photo avatar
        return CircleAvatar(
          backgroundColor: Colors.orange.withValues(alpha: 0.2),
          backgroundImage: FileImage(File(_currentProfileAvatar!)),
          onBackgroundImageError: (exception, stackTrace) {
            // Fallback to default emoji if photo fails to load
            debugPrint('Error loading profile photo: $exception');
          },
          child: _currentProfileAvatar!.isEmpty
              ? const Icon(
                  Icons.person,
                  color: Colors.orange,
                  size: 20,
                )
              : null,
        );
      } else {
        // Emoji avatar
        return CircleAvatar(
          backgroundColor: _getAvatarColor(_currentProfileAvatar!),
          child: Text(
            _currentProfileAvatar!,
            style: const TextStyle(fontSize: 18),
          ),
        );
      }
    } else {
      // Fallback to default emoji
      return CircleAvatar(
        backgroundColor: Colors.orange.withValues(alpha: 0.2),
        child: const Text(
          '🧒',
          style: TextStyle(fontSize: 18),
        ),
      );
    }
  }

  // Helper method to get avatar color (same as in profile selection screen)
  Color _getAvatarColor(String avatar) {
    switch (avatar) {
      case '👧':
        return const Color(0xFFFFE066); // Yellow for Madeline
      case '👦':
        return const Color(0xFFB3E0FF); // Blue for Matthew
      default:
        return const Color(0xFFFFD3B6); // Default peachy color
    }
  }

  Future<void> _clearChat() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text(
            'Are you sure you want to delete all chat messages? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              setState(() {
                _isLoading = true;
              });

              try {
                await _databaseService.deleteAllChatMessages(
                    profileId: _currentProfileId);

                // Set flag to skip welcome message after clearing chat
                _skipWelcomeMessage = true;

                setState(() {
                  _messages = [];
                  _isLoading = false;
                });

                // This will now be skipped due to the flag
                _addWelcomeMessageIfNeeded();
              } catch (e) {
                debugPrint('Error clearing chat: $e');
                setState(() {
                  _isLoading = false;
                });
                _showErrorSnackBar('Error clearing chat history');
              }
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _showVoiceSettings() async {
    if (_isVoiceSettingsSheetOpen) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    _isVoiceSettingsSheetOpen = true;
    try {
      await showModalBottomSheet(
        context: context,
        useRootNavigator: false,
        useSafeArea: true,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: viewInsets),
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.82,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(25)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Voice Settings',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Choose a voice and listening settings.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Enable/disable voice responses
                        SwitchListTile(
                          title: const Text('Enable Voice Responses'),
                          subtitle: const Text('AI will speak its responses'),
                          value: _useVoiceResponse,
                          activeThumbColor: const Color(0xFF8E6CFF),
                          onChanged: (value) {
                            setModalState(() {
                              _useVoiceResponse = value;
                            });
                            setState(() {
                              _useVoiceResponse = value;
                            });
                          },
                        ),

                        const Divider(),

                        // Voice selection
                        const Text(
                          'Select Voice',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),

                        RadioGroup<String>(
                          groupValue: _selectedVoiceId,
                          onChanged: (value) {
                            if (value == null) return;
                            setModalState(() {
                              _selectedVoiceId = value;
                            });
                            setState(() {
                              _selectedVoiceId = value;
                              ElevenLabsService.setVoiceId(value);
                            });
                          },
                          child: Column(
                            children: ElevenLabsService.availableVoices
                                .map((voice) => RadioListTile<String>(
                                      title: Text(voice['name']!),
                                      value: voice['id']!,
                                      activeColor: const Color(0xFF8E6CFF),
                                    ))
                                .toList(),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Clear cache button
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);

                              setState(() {
                                _isLoading = true;
                              });

                              try {
                                await _databaseService
                                    .clearChatMessagesAudioFiles();

                                // Also clean up audio files in the app's directory
                                final appDir =
                                    await getApplicationDocumentsDirectory();
                                final audioDir =
                                    Directory('${appDir.path}/story_audio');

                                if (await audioDir.exists()) {
                                  final entities =
                                      await audioDir.list().toList();
                                  for (final entity in entities) {
                                    if (entity is File &&
                                        entity.path.contains('_voice_')) {
                                      await entity.delete();
                                    }
                                  }
                                }

                                if (!context.mounted) return;
                                setState(() {
                                  _isLoading = false;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Audio cache cleared'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } catch (e) {
                                debugPrint('Error clearing audio cache: $e');
                                if (!context.mounted) return;
                                setState(() {
                                  _isLoading = false;
                                });
                                _showErrorSnackBar(
                                    'Error clearing audio cache');
                              }
                            },
                            icon: const Icon(Icons.cleaning_services),
                            label: const Text('Clear Audio Cache'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
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
      );
    } finally {
      _isVoiceSettingsSheetOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = context.watch<ThemeService>().config;
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Voice Chat with Aria'),
        backgroundColor: themeConfig.cardAiChat,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Quick voice toggle button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Voice',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Switch(
                value: _useVoiceResponse,
                onChanged: (value) {
                  setState(() {
                    _useVoiceResponse = value;
                  });
                  // Show feedback to the user
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(value
                          ? 'Voice responses enabled'
                          : 'Voice responses disabled'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.green,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.grey,
              ),
            ],
          ),
          // Voice settings button
          IconButton(
            icon: Icon(
              _useVoiceResponse
                  ? Icons.record_voice_over
                  : Icons.voice_over_off,
              size: 24,
            ),
            onPressed: _showVoiceSettings,
            tooltip: _useVoiceResponse
                ? 'Voice Settings (On)'
                : 'Voice Settings (Off)',
          ),
          // Clear chat button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearChat,
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [themeConfig.cardAiChat, themeConfig.screenGradient.last],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          bottom: true,
          maintainBottomViewPadding: true,
          child: Column(
            children: [
              if (_chatQuotaStatus != null)
                Container(
                  width: double.infinity,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isPremiumUser
                        ? 'Premium AI chat left: ${_chatQuotaStatus!.remainingToday}/${_chatQuotaStatus!.dailyLimit} today'
                        : 'Free AI chat left: ${_chatQuotaStatus!.remainingToday}/${_chatQuotaStatus!.dailyLimit} today',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF355C7D),
                    ),
                  ),
                ),
              // Chat messages list
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF8E6CFF)),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          20,
                          16,
                          _isVoiceInputMode
                              ? 100
                              : 80, // More padding for voice mode
                        ),
                        itemCount: _messages.length,
                        reverse: false, // Keep chronological order
                        physics:
                            const AlwaysScrollableScrollPhysics(), // Make sure scrolling is always enabled
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return _buildMessageBubble(message);
                        },
                      ),
              ),

              // Loading indicator for AI typing
              if (_isSending)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF8E6CFF)),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'AI is thinking...',
                        style: TextStyle(
                          color: Color(0xFF8E6CFF),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

              // Chat input area
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      spreadRadius: 1,
                      blurRadius: 10,
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Voice/Keyboard toggle button with animation
                    Container(
                      height: 50,
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: _toggleInputMode,
                        child: Tooltip(
                          message: _isVoiceInputMode
                              ? 'Switch to keyboard'
                              : 'Switch to voice input',
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _isVoiceInputMode
                                  ? const Color(0xFF8E6CFF)
                                      .withValues(alpha: 0.2)
                                  : const Color(0xFF8E6CFF)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                _isVoiceInputMode
                                    ? Icons.keyboard_alt_outlined
                                    : Icons.mic,
                                key: ValueKey<bool>(_isVoiceInputMode),
                                color: const Color(0xFF8E6CFF),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Animated transition between voice and keyboard modes
                    Expanded(
                      child: _isVoiceInputMode
                          ? _buildVoiceInputButton()
                          : _buildTextInputField(),
                    ),

                    // Only show send button in text input mode
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      child: !_isVoiceInputMode
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 10),
                                AnimatedBuilder(
                                  animation: _sendButtonController,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: 1.0 +
                                          (_sendButtonController.value * 0.2),
                                      child: IconButton(
                                        icon: const Icon(Icons.send_rounded),
                                        color: const Color(0xFF8E6CFF),
                                        onPressed:
                                            _textController.text.trim().isEmpty
                                                ? null
                                                : () {
                                                    _sendButtonController
                                                        .forward()
                                                        .then((_) {
                                                      _sendButtonController
                                                          .reverse();
                                                    });
                                                    _sendMessage(
                                                        _textController.text);
                                                  },
                                      ),
                                    );
                                  },
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUserMessage = message.isUserMessage;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment:
            isUserMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI avatar for assistant messages
          if (!isUserMessage) ...[
            CircleAvatar(
              backgroundColor: const Color(0xFF8E6CFF).withValues(alpha: 0.2),
              child: const Text(
                '🤖',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Message content
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isUserMessage ? const Color(0xFF8E6CFF) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    spreadRadius: 1,
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message text
                  Text(
                    message.message,
                    style: TextStyle(
                      color: isUserMessage ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // User avatar for user messages
          if (isUserMessage) ...[
            const SizedBox(width: 8),
            _buildUserAvatar(),
          ],
        ],
      ),
    );
  }

  // Update the toggle input mode method
  void _toggleInputMode() {
    setState(() {
      _isVoiceInputMode = !_isVoiceInputMode;

      // If switching to voice mode and help hasn't been shown yet, show it
      if (_isVoiceInputMode && _showVoiceInputHelp) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showVoiceInputHelpTooltip();
        });
        _showVoiceInputHelp = false; // Only show once per session
      }
    });

    if (_isVoiceInputMode) {
      _inputModeAnimationController.forward();
    } else {
      _inputModeAnimationController.reverse();
    }

    // Scroll to bottom after toggling to ensure message visibility
    // Use a slightly longer delay to account for the animation
    Future.delayed(const Duration(milliseconds: 150), () {
      _scrollToBottom();
    });
  }

  // Build the voice input button with a hint text below it
  Widget _buildVoiceInputButton() {
    return GestureDetector(
      onLongPress: _startRecording,
      onLongPressEnd: (_) {
        if (_isCancelingRecording) {
          _cancelRecording();
        } else {
          _stopRecordingAndProcess();
        }
      },
      onLongPressCancel: () {
        if (_isRecording) {
          _stopRecordingAndProcess();
        }
      },
      // Add vertical drag handling for swipe-to-cancel
      onLongPressMoveUpdate: (details) {
        if (_isRecording) {
          final verticalDrag = details.offsetFromOrigin.dy;

          // If user swipes up more than 50 logical pixels, show cancel hint
          if (verticalDrag < -50 && !_isShowingCancelHint) {
            setState(() {
              _isShowingCancelHint = true;
            });
            // Provide light haptic feedback when cancel hint appears
            HapticFeedback.selectionClick();
          }

          // If user swipes up more than 100 logical pixels, mark as canceling
          if (verticalDrag < -100) {
            setState(() {
              _isCancelingRecording = true;
            });
          } else {
            setState(() {
              _isCancelingRecording = false;
            });
          }
        }
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: 50,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _isRecording ? Colors.red.shade50 : Colors.grey.shade100,
            gradient: _isRecording
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      Colors.grey.shade100,
                    ],
                  ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isRecording
                  ? Colors.red
                  : const Color(0xFF8E6CFF).withValues(alpha: 0.3),
              width: _isRecording ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Recording pulse animation
                if (_isRecording && !_isCancelingRecording)
                  AnimatedBuilder(
                    animation: _recordingPulseController,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.red.withValues(
                                alpha: 0.5 *
                                    (1 - _recordingPulseController.value)),
                            width: 3.0 * (1 - _recordingPulseController.value),
                          ),
                        ),
                      );
                    },
                  ),

                // Cancel indicator
                if (_isShowingCancelHint)
                  Positioned(
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isCancelingRecording
                            ? Colors.red
                            : Colors.grey.shade700,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: Text(
                        _isCancelingRecording
                            ? "Release to cancel"
                            : "↑ Swipe up to cancel",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: _isCancelingRecording
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),

                // Button content
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_isRecording)
                            Icon(
                              Icons.mic_none_rounded,
                              size: 18,
                              color: const Color(0xFF8E6CFF),
                            ),
                          if (!_isRecording) const SizedBox(width: 8),
                          Text(
                            _isRecording
                                ? _isCancelingRecording
                                    ? 'Cancel Recording'
                                    : 'Listening...'
                                : 'Hold to Talk',
                            style: TextStyle(
                              color: _isCancelingRecording
                                  ? Colors.red.shade700
                                  : _isRecording
                                      ? Colors.red
                                      : const Color(0xFF8E6CFF),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      if (!_isRecording)
                        Text(
                          'Press and hold to speak',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                        ),
                    ],
                  ),
                ),

                // Recording icon and duration timer
                if (_isRecording && !_isCancelingRecording)
                  Positioned(
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _micAnimationController,
                            builder: (context, child) {
                              return Icon(
                                Icons.mic,
                                color: Colors.red.withValues(
                                    alpha: 0.7 +
                                        0.3 * _micAnimationController.value),
                                size: 16,
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formattedRecordingTime,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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

  // Update show voice input help tooltip with more details
  void _showVoiceInputHelpTooltip() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.mic, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              const Text("Voice Input Tips"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(Icons.touch_app, color: Color(0xFF8E6CFF)),
                title: const Text("Press and hold"),
                subtitle: const Text("Hold the button to start recording"),
              ),
              ListTile(
                leading: const Icon(Icons.mic, color: Colors.red),
                title: const Text("Speak clearly"),
                subtitle: const Text("Release when you're done speaking"),
              ),
              ListTile(
                leading: const Icon(Icons.swipe, color: Colors.orange),
                title: const Text("Swipe up to cancel"),
                subtitle: const Text("If you want to cancel recording"),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.keyboard, color: Colors.blue),
                title: const Text("Switch input modes"),
                subtitle: const Text(
                    "Tap the icon on the left to switch between voice and keyboard"),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Don't show again"),
              onPressed: () {
                _showVoiceInputHelp = false;
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF8E6CFF),
                foregroundColor: Colors.white,
              ),
              child: const Text("Got it"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // New method to build text input field
  Widget _buildTextInputField() {
    return TextField(
      controller: _textController,
      decoration: InputDecoration(
        hintText: 'Type a message...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        suffixIcon: _textController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _textController.clear();
                  });
                },
              )
            : null,
      ),
      textCapitalization: TextCapitalization.sentences,
      onChanged: (value) {
        setState(() {
          // This triggers a rebuild to show/hide the clear button
        });
      },
      onSubmitted: (text) {
        if (text.trim().isNotEmpty) {
          _sendMessage(text);
        }
      },
    );
  }

  // Add method to cancel recording timer
  void _cancelRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  // Format recording time for display
  String get _formattedRecordingTime {
    final minutes = (_recordingDuration ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingDuration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Add method to cancel recording
  void _cancelRecording() {
    // Give haptic feedback for cancellation
    HapticFeedback.heavyImpact();

    // Stop the animations
    _micAnimationController.stop();
    _micAnimationController.reset();
    _recordingPulseController.stop();
    _recordingPulseController.reset();

    // Cancel recording timer
    _cancelRecordingTimer();

    setState(() {
      _isRecording = false;
      _recordingDuration = 0;
      _isShowingCancelHint = false;
      _isCancelingRecording = false;
    });

    // Cancel the recording
    _audioRecorderService.cancelRecording();
  }
}
