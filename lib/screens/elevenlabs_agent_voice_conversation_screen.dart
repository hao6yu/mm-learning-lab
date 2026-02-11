import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/profile_provider.dart';
import '../services/ai_parental_control_service.dart';
import '../services/ai_proxy_config.dart';
import '../services/ai_usage_limit_service.dart';
import '../services/elevenlabs_agent_service.dart';
import '../services/subscription_service.dart';
import '../services/theme_service.dart';

class ElevenLabsAgentVoiceConversationScreen extends StatefulWidget {
  const ElevenLabsAgentVoiceConversationScreen({super.key});

  @override
  State<ElevenLabsAgentVoiceConversationScreen> createState() =>
      _ElevenLabsAgentVoiceConversationScreenState();
}

class _ElevenLabsAgentVoiceConversationScreenState
    extends State<ElevenLabsAgentVoiceConversationScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _isPaused = false;
  bool _isConnected = false;
  bool _isAssistantSpeaking = false;
  bool _isClosing = false;
  bool _initialized = false;
  bool _isDisposing = false;
  bool _isQuotaBlocked = false;
  bool _autoRecoveryAttempted = false;
  bool _isRecovering = false;
  bool _isStartingCall = false;
  bool _sentInitialUserActivity = false;
  bool _shouldMarkFullIntroShown = false;
  bool _fullIntroForCurrentCall = false;

  String? _currentTranscript;
  String? _error;

  final ElevenLabsAgentService _agentService = ElevenLabsAgentService();
  final AIUsageLimitService _aiUsageLimitService = AIUsageLimitService();
  final AiParentalControlService _parentalControlService =
      AiParentalControlService();

  ConversationClient? _client;

  AiParentalControls _parentalControls = const AiParentalControls.defaults();
  int? _currentProfileId;
  String? _currentProfileName;
  int? _currentProfileAge;
  bool _isPremiumUser = false;
  int? _callSessionId;
  Timer? _callTimer;
  Timer? _sessionHealthTimer;
  int _elapsedCallSeconds = 0;
  int _maxAllowedCallSeconds = 0;
  bool _warnedOneMinuteLeft = false;
  DateTime? _wentBackgroundAt;
  DateTime? _connectedAt;
  DateTime? _lastInteractionAt;
  late final AnimationController _orbPulseController;
  final ScrollController _transcriptScrollController = ScrollController();
  static const String _bellaIntroLastShownPrefix =
      'bella_intro_last_shown_profile_';
  static Future<void> _globalTeardownChain = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _orbPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _client = _buildConversationClient();
  }

  ConversationClient _buildConversationClient() {
    return ConversationClient(
      callbacks: ConversationCallbacks(
        onConnect: ({required String conversationId}) {
          _setStateIfActive(() {
            _isConnected = true;
            _error = null;
          });
          unawaited(_startTrackedSessionIfNeeded());
          _startCallTimer();
          unawaited(_configureCallAudioSession());
          _connectedAt = DateTime.now();
          _lastInteractionAt = DateTime.now();
          _startSessionHealthMonitor();
          unawaited(_kickstartConnectedSession());
        },
        onDisconnect: (details) {
          _setStateIfActive(() {
            _isConnected = false;
          });
          // Skip redundant cleanup if already closing/disposed
          if (_isClosing || _isDisposing) return;
          _callTimer?.cancel();
          _stopSessionHealthMonitor();
          unawaited(_endTrackedSessionIfNeeded('sdk_disconnect'));
        },
        onStatusChange: ({required ConversationStatus status}) {
          if (!mounted || _isDisposing) return;
          setState(() {
            if (status == ConversationStatus.disconnected ||
                status == ConversationStatus.disconnecting) {
              _isConnected = false;
            }
          });
        },
        onModeChange: ({required ConversationMode mode}) {
          _setStateIfActive(() {
            _isAssistantSpeaking = mode == ConversationMode.speaking;
          });
        },
        onMessage: ({required String message, required Role source}) {
          if (message.trim().isEmpty) return;
          _lastInteractionAt = DateTime.now();
          if (source == Role.ai && _shouldMarkFullIntroShown) {
            _shouldMarkFullIntroShown = false;
            unawaited(_markFullIntroShownToday());
          }
          _setStateIfActive(() {
            _currentTranscript = message;
            _isAssistantSpeaking = source == Role.ai;
          });
          _scrollTranscriptToTop();
        },
        onUserTranscript: ({required String transcript, required int eventId}) {
          if (transcript.trim().isEmpty) return;
          _lastInteractionAt = DateTime.now();
          _setStateIfActive(() {
            _currentTranscript = transcript;
          });
          _scrollTranscriptToTop();
        },
        onVadScore: ({required double vadScore}) {
          if (vadScore > 0) {
            _lastInteractionAt = DateTime.now();
          }
        },
        onError: (message, [context]) {
          final details = context == null ? message : '$message: $context';
          debugPrint('ElevenLabs SDK error: $details');
          _setStateIfActive(() {
            _error = details;
          });
        },
        onEndCallRequested: () {
          _closeConversation(endReason: 'agent_end_call_requested');
        },
      ),
    );
  }

  Future<void> _queueGlobalTeardown(Future<void> Function() action) {
    final completer = Completer<void>();
    _globalTeardownChain =
        _globalTeardownChain.catchError((_) {}).then((_) async {
      try {
        await action();
        if (!completer.isCompleted) completer.complete();
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> _teardownClient({required bool recreate}) async {
    final client = _client;
    _client = null;
    await _queueGlobalTeardown(() async {
      if (client != null) {
        try {
          await client.endSession();
        } catch (e) {
          debugPrint('Error ending ElevenLabs SDK session during teardown: $e');
        }
        try {
          client.dispose();
        } catch (e) {
          debugPrint('Error disposing ElevenLabs SDK client: $e');
        }
      }
    });
    if (recreate && mounted && !_isDisposing) {
      _client = _buildConversationClient();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final profileProvider = context.read<ProfileProvider>();
    final subscriptionService = context.read<SubscriptionService>();
    _currentProfileId = profileProvider.selectedProfileId;
    final selectedProfile = profileProvider.profiles
        .where((p) => p.id == _currentProfileId)
        .cast<dynamic>()
        .toList();
    if (selectedProfile.isNotEmpty) {
      final profile = selectedProfile.first;
      _currentProfileName = profile.name?.toString();
      _currentProfileAge = profile.age is int ? profile.age as int : null;
    } else {
      _currentProfileName = null;
      _currentProfileAge = null;
    }
    _isPremiumUser = subscriptionService.isSubscribed;
    _prepareAndStartConversation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _wentBackgroundAt = DateTime.now();
      return;
    }

    if (state == AppLifecycleState.resumed && _wentBackgroundAt != null) {
      final backgroundSeconds =
          DateTime.now().difference(_wentBackgroundAt!).inSeconds;
      _wentBackgroundAt = null;
      if (_isConnected && backgroundSeconds > 30) {
        _closeConversation(endReason: 'background_timeout');
      }
    }
  }

  Future<void> _prepareAndStartConversation() async {
    final profileId = _currentProfileId;
    if (profileId == null) {
      _setStateIfActive(() {
        _error = 'Please select a child profile first.';
      });
      return;
    }

    if (!_agentService.isConfigured) {
      _setStateIfActive(() {
        _error =
            'ElevenLabs Agent is not configured. Set ELEVENLABS_AGENT_ID in .env.';
      });
      return;
    }

    _parentalControls = await _parentalControlService.getControls(profileId);
    if (!_parentalControls.callEnabled) {
      _setStateIfActive(() {
        _error = 'AI calls are turned off by parent controls.';
      });
      return;
    }
    if (_parentalControls.isCallBlockedByBedtime(DateTime.now())) {
      _setStateIfActive(() {
        _error =
            'AI calls are unavailable during bedtime (${_parentalControls.bedtimeRangeLabel()}).';
      });
      return;
    }

    final allowance = await _aiUsageLimitService.getVoiceCallAllowance(
      profileId: profileId,
      isPremium: _isPremiumUser,
    );
    if (!mounted) return;

    final overrideSeconds = _parentalControls.maxCallMinutesOverride == null
        ? null
        : _parentalControls.maxCallMinutesOverride! * 60;
    final remainingForThisCall = overrideSeconds == null
        ? allowance.remainingForThisCallSeconds
        : allowance.remainingForThisCallSeconds < overrideSeconds
            ? allowance.remainingForThisCallSeconds
            : overrideSeconds;

    _setStateIfActive(() {
      _maxAllowedCallSeconds = remainingForThisCall;
      _isQuotaBlocked = false;
      _error = null;
    });

    if (!allowance.allowed || remainingForThisCall <= 0) {
      _setStateIfActive(() {
        _isQuotaBlocked = true;
        _error = _isPremiumUser
            ? 'Premium voice call limit reached. Try again tomorrow.'
            : 'Free voice call limit reached. Try again tomorrow.';
      });
      return;
    }
  }

  Future<void> _startConversation() async {
    if (_isStartingCall || _isConnected) return;
    _isStartingCall = true;
    _setStateIfActive(() {
      _isConnected = false;
      _isPaused = false;
      _isAssistantSpeaking = false;
      _currentTranscript = null;
      _error = null;
      _elapsedCallSeconds = 0;
      _warnedOneMinuteLeft = false;
      _connectedAt = null;
      _lastInteractionAt = null;
      _sentInitialUserActivity = false;
    });
    _autoRecoveryAttempted = false;

    try {
      final initialStatus = await Permission.microphone.status;
      debugPrint('Initial microphone permission status: $initialStatus');
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (status == PermissionStatus.permanentlyDenied) {
          _setStateIfActive(() {
            _error =
                'Microphone permission permanently denied. Opening Settings...';
          });
          unawaited(openAppSettings());
        } else {
          _setStateIfActive(() {
            _error =
                'Microphone permission denied. Please enable it in Settings.';
          });
        }
        return;
      }

      final profileId = _currentProfileId;
      if (profileId == null) {
        _setStateIfActive(
          () => _error = 'Please select a child profile first.',
        );
        return;
      }

      final requestContext = AiRequestContext(
        profileId: profileId,
        isPremium: _isPremiumUser,
        feature: 'voice_call',
        units: 1,
        callReserveSeconds: _maxAllowedCallSeconds,
      );

      final conversationToken = await _agentService.resolveConversationToken(
        requestContext: requestContext,
      );
      debugPrint(
        'ElevenLabs SDK auth mode: ${conversationToken != null && conversationToken.isNotEmpty ? "conversationToken" : "agentId"}',
      );

      final agentId = _agentService.agentId;
      if ((conversationToken == null || conversationToken.isEmpty) &&
          (agentId == null || agentId.isEmpty)) {
        _setStateIfActive(() {
          _error =
              'Unable to start ElevenLabs call. Verify ELEVENLABS_AGENT_ID and signed-url configuration.';
        });
        return;
      }

      // Let navigation/audio settle before starting the first SDK session.
      await Future.delayed(const Duration(milliseconds: 180));

      _fullIntroForCurrentCall = await _shouldUseFullIntroToday();
      _shouldMarkFullIntroShown = _fullIntroForCurrentCall;

      await _teardownClient(recreate: true);
      final client = _client;
      if (client == null) {
        _setStateIfActive(
          () => _error = 'Call setup interrupted. Please try again.',
        );
        return;
      }

      await _startSdkSession(
        client: client,
        conversationToken: conversationToken,
        agentId: agentId,
        profileId: profileId,
      );
    } catch (e) {
      final errorText = e.toString();
      if (errorText.contains('Session already active')) {
        final retryProfileId = _currentProfileId;
        if (retryProfileId != null) {
          try {
            debugPrint('Detected active session conflict; retrying once...');
            await _teardownClient(recreate: true);
            await Future.delayed(const Duration(milliseconds: 250));
            final retryClient = _client;
            if (retryClient != null) {
              await _startSdkSession(
                client: retryClient,
                conversationToken: await _agentService.resolveConversationToken(
                  requestContext: AiRequestContext(
                    profileId: retryProfileId,
                    isPremium: _isPremiumUser,
                    feature: 'voice_call',
                    units: 1,
                    callReserveSeconds: _maxAllowedCallSeconds,
                  ),
                ),
                agentId: _agentService.agentId,
                profileId: retryProfileId,
              );
              return;
            }
          } catch (retryError) {
            debugPrint('Retry after active session conflict failed: $retryError');
          }
        }
      }
      debugPrint('ElevenLabs SDK conversation start failed: $e');
      _setStateIfActive(() => _error = 'Failed to connect: $e');
      await _endTrackedSessionIfNeeded('start_failed');
    } finally {
      _isStartingCall = false;
    }
  }

  Future<void> _startSdkSession({
    required ConversationClient client,
    required String? conversationToken,
    required String? agentId,
    required int profileId,
  }) {
    return client.startSession(
      conversationToken:
          conversationToken != null && conversationToken.isNotEmpty
              ? conversationToken
              : null,
      agentId: (conversationToken == null || conversationToken.isEmpty)
          ? agentId
          : null,
      dynamicVariables: {
        'assistant_name': 'Bella',
        if (_currentProfileName != null && _currentProfileName!.isNotEmpty)
          'child_name': _currentProfileName!,
        if (_currentProfileAge != null)
          'child_age': _currentProfileAge.toString(),
        'intro_mode': _fullIntroForCurrentCall ? 'full' : 'quick',
        'tier': _isPremiumUser ? 'premium' : 'free',
        'child_profile_id': profileId.toString(),
      },
    );
  }

  Future<void> _configureCallAudioSession() async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.defaultToSpeaker |
                  AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ),
      );
      await session.setActive(true);
    } catch (e) {
      debugPrint('Could not configure call audio session: $e');
    }
  }

  Future<void> _startTrackedSessionIfNeeded() async {
    if (_callSessionId != null) return;
    final profileId = _currentProfileId;
    if (profileId == null) return;
    try {
      _callSessionId = await _aiUsageLimitService.startVoiceCallSession(
        profileId: profileId,
        isPremium: _isPremiumUser,
        model: 'elevenlabs-agent-sdk:${_agentService.agentId ?? "unknown"}',
      );
    } catch (e) {
      debugPrint('Unable to persist call session start: $e');
    }
  }

  Future<void> _endTrackedSessionIfNeeded(String reason) async {
    final sessionId = _callSessionId;
    if (sessionId == null) return;
    _callSessionId = null;
    try {
      await _aiUsageLimitService.endVoiceCallSession(
        sessionId: sessionId,
        durationSeconds: _elapsedCallSeconds,
        endReason: reason,
      );
    } catch (e) {
      debugPrint('Unable to persist call session end: $e');
    }
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isConnected) return;
      final nextElapsed = _elapsedCallSeconds + 1;
      final remaining = _maxAllowedCallSeconds - nextElapsed;

      if (mounted) {
        setState(() => _elapsedCallSeconds = nextElapsed);
      } else {
        _elapsedCallSeconds = nextElapsed;
      }

      if (remaining <= 60 && remaining > 0 && !_warnedOneMinuteLeft) {
        _warnedOneMinuteLeft = true;
        if (mounted && !_isDisposing) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('1 minute left in this AI call.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } catch (_) {}
        }
      }

      if (remaining <= 0) {
        _closeConversation(endReason: 'max_time_reached');
      }
    });
  }

  Future<void> _kickstartConnectedSession() async {
    if (_isClosing || _isDisposing) return;
    try {
      await _client?.setMicMuted(false);
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 250));
    if (_isClosing || _isDisposing || _isPaused || !_isConnected) return;
    if (_sentInitialUserActivity) return;
    _sentInitialUserActivity = true;
  }

  void _startSessionHealthMonitor() {
    _sessionHealthTimer?.cancel();
    _sessionHealthTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isConnected || _isClosing || _isDisposing || _isPaused) return;
      if (_isRecovering) return;
      final connectedAt = _connectedAt;
      if (connectedAt == null) return;
      final now = DateTime.now();
      final connectedFor = now.difference(connectedAt);
      final lastInteraction = _lastInteractionAt ?? connectedAt;
      final idleFor = now.difference(lastInteraction);

      // Self-heal once if the first connection is "connected" but silent/unresponsive.
      if (!_autoRecoveryAttempted &&
          connectedFor >= const Duration(seconds: 10) &&
          idleFor >= const Duration(seconds: 10) &&
          !_isAssistantSpeaking &&
          (_currentTranscript == null || _currentTranscript!.trim().isEmpty)) {
        _autoRecoveryAttempted = true;
        unawaited(_restartConversationAfterStartupStall());
      }
    });
  }

  void _stopSessionHealthMonitor() {
    _sessionHealthTimer?.cancel();
    _sessionHealthTimer = null;
  }

  Future<void> _restartConversationAfterStartupStall() async {
    if (_isRecovering || _isClosing || _isDisposing) return;
    _isRecovering = true;
    debugPrint(
      'No conversation activity detected on first session; auto-restarting call session once.',
    );
    _setStateIfActive(() {
      _error = 'Reconnecting call...';
    });

    try {
      try {
        await _teardownClient(recreate: true);
      } catch (_) {}
      await _endTrackedSessionIfNeeded('auto_restart_startup_stall');

      if (!mounted || _isDisposing) {
        return;
      }
      await _startConversation();
    } finally {
      _isRecovering = false;
    }
  }

  Future<void> _pauseConversation() async {
    if (!mounted || _isDisposing) return;
    setState(() => _isPaused = true);
    try {
      await _client?.setMicMuted(true);
    } catch (_) {}
  }

  Future<void> _resumeConversation() async {
    if (!mounted || _isDisposing) return;
    setState(() => _isPaused = false);
    try {
      await _client?.setMicMuted(false);
    } catch (_) {}
  }

  Future<void> _closeConversation({
    String endReason = 'user_closed',
    bool pop = true,
    bool allowStateUpdate = true,
  }) async {
    if (_isClosing) return;
    _isClosing = true;
    _isStartingCall = false;
    _callTimer?.cancel();
    _stopSessionHealthMonitor();

    if (allowStateUpdate && mounted && !_isDisposing) {
      setState(() {
        _isPaused = true;
        _isConnected = false;
        _isAssistantSpeaking = false;
      });
    } else {
      _isPaused = true;
      _isConnected = false;
      _isAssistantSpeaking = false;
    }

    try {
      await _teardownClient(recreate: false);

      // Deactivate audio session
      if (Platform.isIOS || Platform.isAndroid) {
        try {
          final session = await AudioSession.instance;
          await session.setActive(false);
        } catch (e) {
          debugPrint('Could not deactivate audio session: $e');
        }
      }

      await _endTrackedSessionIfNeeded(endReason);

      if (pop && mounted && !_isDisposing && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } finally {
      _isClosing = false;
    }
  }

  @override
  void dispose() {
    _isDisposing = true;
    WidgetsBinding.instance.removeObserver(this);
    _orbPulseController.dispose();
    _transcriptScrollController.dispose();
    _callTimer?.cancel();
    _stopSessionHealthMonitor();
    // End tracked session before teardown (don't rely on SDK callback during disposal)
    unawaited(_endTrackedSessionIfNeeded('disposed'));
    unawaited(_teardownClient(recreate: false));
    // Deactivate audio session
    if (Platform.isIOS || Platform.isAndroid) {
      unawaited(AudioSession.instance.then((s) => s.setActive(false)).catchError((_) => false));
    }
    super.dispose();
  }

  void _setStateIfActive(VoidCallback callback) {
    if (!mounted || _isDisposing) return;
    setState(callback);
  }

  void _scrollTranscriptToTop() {
    if (!_transcriptScrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_transcriptScrollController.hasClients) return;
      _transcriptScrollController.jumpTo(0);
    });
  }

  String _formatSeconds(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final minutes = safe ~/ 60;
    final seconds = safe % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<bool> _shouldUseFullIntroToday() async {
    final profileId = _currentProfileId;
    if (profileId == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final key = '$_bellaIntroLastShownPrefix$profileId';
    final lastShownRaw = prefs.getString(key);
    if (lastShownRaw == null || lastShownRaw.isEmpty) {
      return true;
    }

    final lastShown = DateTime.tryParse(lastShownRaw);
    if (lastShown == null) return true;
    final now = DateTime.now();
    return now.year != lastShown.year ||
        now.month != lastShown.month ||
        now.day != lastShown.day;
  }

  Future<void> _markFullIntroShownToday() async {
    final profileId = _currentProfileId;
    if (profileId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_bellaIntroLastShownPrefix$profileId';
    await prefs.setString(key, DateTime.now().toIso8601String());
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = context.watch<ThemeService>().config;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final transcriptPanelMaxHeight =
        (screenHeight * 0.22).clamp(96.0, 190.0).toDouble();
    final remainingRaw = _maxAllowedCallSeconds - _elapsedCallSeconds;
    final remaining = remainingRaw < 0 ? 0 : remainingRaw;
    final showStartCta = !_isConnected && !_isQuotaBlocked;
    final statusText = _currentTranscript ??
        (_isPaused
            ? 'Mic is muted'
            : _isConnected
                ? (_isAssistantSpeaking
                    ? 'Bella is speaking...'
                    : 'Bella is listening...')
                : (_isStartingCall ? 'Connecting...' : 'Ready when you are'));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => _closeConversation(endReason: 'back_button'),
        ),
        title: const Text('Live Call with Bella'),
        backgroundColor: themeConfig.cardVoiceCall,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isPaused ? Icons.mic_off : Icons.mic),
            tooltip: _isPaused ? 'Unmute' : 'Mute',
            onPressed: !_isConnected
                ? null
                : () async {
                    if (_isPaused) {
                      await _resumeConversation();
                    } else {
                      await _pauseConversation();
                    }
                  },
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => _closeConversation(),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  themeConfig.screenGradient.first,
                  themeConfig.screenGradient.last,
                  themeConfig.screenGradient.last.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
          Positioned(
            top: 70,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFF60A5FA).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: 130,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 16,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_parentalControls.maxCallMinutesOverride !=
                                null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'Parent cap: ${_parentalControls.maxCallMinutesOverride} min/call',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4A5D73),
                                    fontFamily: 'Baloo2',
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            AnimatedBuilder(
                              animation: _orbPulseController,
                              builder: (context, child) {
                                final t = _orbPulseController.value;
                                final pulseScale =
                                    showStartCta ? (1.0 + (t * 0.07)) : 1.0;
                                final ringScale =
                                    showStartCta ? (1.02 + (t * 0.16)) : 1.0;
                                final ringOpacity =
                                    showStartCta ? (0.14 + (t * 0.24)) : 0.08;
                                final floatY =
                                    showStartCta ? (2.0 - (t * 4.0)) : 0.0;

                                return SizedBox(
                                  width: 220,
                                  height: 205,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Transform.translate(
                                        offset: Offset(0, floatY),
                                        child: Transform.scale(
                                          scale: ringScale,
                                          child: Container(
                                            width: 178,
                                            height: 178,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF38BDF8)
                                                      .withValues(
                                                          alpha: ringOpacity),
                                                  blurRadius: 28,
                                                  spreadRadius: 10,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Transform.translate(
                                        offset: Offset(0, floatY),
                                        child: Transform.scale(
                                          scale: pulseScale,
                                          child: GestureDetector(
                                            onTap:
                                                showStartCta && !_isStartingCall
                                                    ? _startConversation
                                                    : null,
                                            child: Container(
                                              width: 172,
                                              height: 172,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: const RadialGradient(
                                                  center:
                                                      Alignment(-0.28, -0.30),
                                                  radius: 0.96,
                                                  colors: [
                                                    Color(0xFFBAF2FF),
                                                    Color(0xFF22C9F2),
                                                    Color(0xFF1478E8),
                                                    Color(0xFF0B4AB4),
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color:
                                                        const Color(0xFF0B4AB4)
                                                            .withValues(
                                                                alpha: 0.34),
                                                    blurRadius: 20,
                                                    offset: const Offset(0, 12),
                                                  ),
                                                  BoxShadow(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.24),
                                                    blurRadius: 8,
                                                    spreadRadius: -2,
                                                    offset:
                                                        const Offset(-4, -4),
                                                  ),
                                                ],
                                              ),
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Positioned(
                                                    top: 30 - (t * 4),
                                                    left: 44 + (t * 4),
                                                    child: Container(
                                                      width: 58,
                                                      height: 30,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white
                                                            .withValues(
                                                          alpha: 0.36,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                      ),
                                                    ),
                                                  ),
                                                  Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons.call_rounded,
                                                        size: 34,
                                                        color: Colors.white
                                                            .withValues(
                                                          alpha: 0.95,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        _isStartingCall
                                                            ? 'Calling...'
                                                            : 'Call Bella',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 30,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontFamily: 'Baloo2',
                                                          letterSpacing: 0.1,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Call time left: ${_formatSeconds(remaining)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF355C7D),
                                fontFamily: 'Baloo2',
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (!showStartCta)
                              Container(
                                width: double.infinity,
                                constraints: BoxConstraints(
                                  maxHeight: transcriptPanelMaxHeight,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Scrollbar(
                                  controller: _transcriptScrollController,
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: _transcriptScrollController,
                                    physics: const BouncingScrollPhysics(),
                                    child: Text(
                                      statusText,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF334155),
                                        fontFamily: 'Baloo2',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontFamily: 'Baloo2',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            if (_error != null &&
                                _isQuotaBlocked &&
                                !_isPremiumUser)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: FilledButton(
                                  onPressed: () => Navigator.pushNamed(
                                      context, '/subscription'),
                                  child: const Text(
                                    'Upgrade for more AI minutes',
                                    style: TextStyle(fontFamily: 'Baloo2'),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.78),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF93C5FD)
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              child: const Text(
                                'Try asking Bella about reading, speaking, English, other languages, math, nature, science, sports, or your school project ideas.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Baloo2',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: Color(0xFF1E3A8A),
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
