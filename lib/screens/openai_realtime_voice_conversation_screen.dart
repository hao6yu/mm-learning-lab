import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import '../services/native_audio_stream.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/ai_proxy_config.dart';
import '../services/ai_parental_control_service.dart';
import '../services/ai_usage_limit_service.dart';
import '../providers/profile_provider.dart';
import '../services/subscription_service.dart';

class OpenAIRealtimeVoiceConversationScreen extends StatefulWidget {
  const OpenAIRealtimeVoiceConversationScreen({super.key});

  @override
  State<OpenAIRealtimeVoiceConversationScreen> createState() =>
      _OpenAIRealtimeVoiceConversationScreenState();
}

class _OpenAIRealtimeVoiceConversationScreenState
    extends State<OpenAIRealtimeVoiceConversationScreen>
    with WidgetsBindingObserver {
  bool _isPaused = false;
  bool _isConnected = false;
  String? _currentTranscript;
  String? _error;
  late String _realtimeModel;
  late AiProxyConfig _proxyConfig;
  String? _openAiApiKey;

  WebSocket? _socket;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localMediaStream;
  RTCDataChannel? _dataChannel;
  bool _usingWebRtc = false;
  String _connectionModeLabel = 'Preparing';
  StreamSubscription? _recorderSubscription;
  AudioPlayer? _audioPlayer;
  final AIUsageLimitService _aiUsageLimitService = AIUsageLimitService();
  AiCallAllowance? _callAllowance;
  int? _currentProfileId;
  bool _isPremiumUser = false;
  int? _callSessionId;
  Timer? _callTimer;
  int _elapsedCallSeconds = 0;
  int _maxAllowedCallSeconds = 0;
  bool _warnedOneMinuteLeft = false;
  bool _isClosing = false;
  bool _initialized = false;
  DateTime? _wentBackgroundAt;
  bool _isQuotaBlocked = false;
  final AiParentalControlService _parentalControlService =
      AiParentalControlService();
  AiParentalControls _parentalControls = const AiParentalControls.defaults();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Get realtime model from env or use default
    _realtimeModel = dotenv.env['OPENAI_REALTIME_MODEL'] ?? 'gpt-realtime-mini';
    _proxyConfig = AiProxyConfig.fromEnv();
    _openAiApiKey = dotenv.env['OPENAI_API_KEY'];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final profileProvider = context.read<ProfileProvider>();
    final subscriptionService = context.read<SubscriptionService>();
    _currentProfileId = profileProvider.selectedProfileId;
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
      final backgroundDuration =
          DateTime.now().difference(_wentBackgroundAt!).inSeconds;
      _wentBackgroundAt = null;
      if (_isConnected && backgroundDuration > 30) {
        _closeConversation(
          endReason: 'background_timeout',
        );
      }
    }
  }

  Future<String> _writeBytesToTempFile(
      Uint8List bytes, String extension) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/openai_audio.$extension');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> _prepareAndStartConversation() async {
    final profileId = _currentProfileId;
    if (profileId == null) {
      setState(() {
        _error = 'Please select a child profile first.';
      });
      return;
    }

    _parentalControls = await _parentalControlService.getControls(profileId);
    if (!_parentalControls.callEnabled) {
      if (!mounted) return;
      setState(() {
        _isQuotaBlocked = false;
        _error = 'AI calls are turned off by parent controls.';
      });
      return;
    }
    if (_parentalControls.isCallBlockedByBedtime(DateTime.now())) {
      if (!mounted) return;
      setState(() {
        _isQuotaBlocked = false;
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

    setState(() {
      _callAllowance = allowance;
      _maxAllowedCallSeconds = remainingForThisCall;
      _isQuotaBlocked = false;
    });

    if (!allowance.allowed || remainingForThisCall <= 0) {
      final tier = _isPremiumUser ? 'Premium' : 'Free';
      setState(() {
        _isQuotaBlocked = true;
        _error =
            '$tier voice call limit reached. Try again tomorrow or next week.';
      });
      return;
    }

    await _startConversation();
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isConnected) return;
      final nextElapsed = _elapsedCallSeconds + 1;
      final remaining = _maxAllowedCallSeconds - nextElapsed;

      if (mounted) {
        setState(() {
          _elapsedCallSeconds = nextElapsed;
        });
      } else {
        _elapsedCallSeconds = nextElapsed;
      }

      if (remaining <= 60 && remaining > 0 && !_warnedOneMinuteLeft) {
        _warnedOneMinuteLeft = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('1 minute left in this AI call.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      if (remaining <= 0) {
        _closeConversation(endReason: 'max_time_reached');
      }
    });
  }

  Future<void> _startTrackedSessionIfNeeded() async {
    if (_callSessionId != null) return;
    final profileId = _currentProfileId;
    if (profileId == null) return;
    try {
      _callSessionId = await _aiUsageLimitService.startVoiceCallSession(
        profileId: profileId,
        isPremium: _isPremiumUser,
        model: _realtimeModel,
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

  Future<void> _startConversation() async {
    setState(() {
      _isConnected = false;
      _isPaused = false;
      _error = null;
      _elapsedCallSeconds = 0;
      _warnedOneMinuteLeft = false;
      _usingWebRtc = false;
      _connectionModeLabel = 'Preparing';
    });

    try {
      // First, ensure microphone permission is granted
      final initialStatus = await Permission.microphone.status;
      debugPrint('Initial microphone permission status: $initialStatus');
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        setState(() => _error =
            'Microphone permission denied. Please enable it in settings.');
        return;
      }

      final profileId = _currentProfileId;
      if (profileId == null) {
        setState(() {
          _error = 'Please select a child profile first.';
        });
        return;
      }

      final sessionData = await AiProxyConfig.withRequestContext(
        profileId: profileId,
        isPremium: _isPremiumUser,
        feature: 'voice_call',
        units: 1,
        callReserveSeconds: _maxAllowedCallSeconds,
        action: _createRealtimeSession,
      );
      if (sessionData == null) {
        setState(() {
          _error =
              'Failed to create realtime session. Check proxy config or fallback settings.';
        });
        return;
      }

      final sessionId = sessionData['id'];
      final dynamic clientSecretField = sessionData['client_secret'];
      final String? clientSecret = clientSecretField is Map<String, dynamic>
          ? clientSecretField['value'] as String?
          : clientSecretField as String?;
      final webRtcReady = await _tryStartWebRtc(
        sessionData: sessionData,
        clientSecret: clientSecret,
      );
      if (webRtcReady) {
        return;
      }

      final String? wsUrl = sessionData['ws_url'] as String? ??
          (sessionId != null
              ? 'wss://api.openai.com/v1/realtime/sessions/$sessionId'
              : null);
      if (wsUrl == null) {
        setState(() => _error = 'Missing realtime transport URL');
        return;
      }

      await _startWebSocketConversation(
        wsUrl: wsUrl,
        clientSecret: clientSecret,
      );
    } catch (e) {
      debugPrint('Unexpected error in conversation start: $e');
      setState(() => _error = 'Error: $e');
    }
  }

  Future<void> _startWebSocketConversation({
    required String wsUrl,
    String? clientSecret,
  }) async {
    try {
      final headers = <String, dynamic>{};
      if (clientSecret != null && clientSecret.isNotEmpty) {
        headers['Authorization'] = 'Bearer $clientSecret';
      }
      debugPrint('Attempting to connect to WebSocket...');
      _socket = headers.isEmpty
          ? await WebSocket.connect(wsUrl)
          : await WebSocket.connect(wsUrl, headers: headers);
      debugPrint('WebSocket connection established.');

      if (!mounted) return;
      setState(() {
        _isConnected = true;
        _usingWebRtc = false;
        _connectionModeLabel = 'WebSocket';
      });
      await _startTrackedSessionIfNeeded();
      _startCallTimer();

      _socket!.add(jsonEncode({
        "type": "start",
        "model": _realtimeModel,
      }));

      try {
        debugPrint('Starting native audio stream...');
        await NativeAudioStream.start(sampleRate: 16000);
        debugPrint('Native audio stream started successfully');

        _recorderSubscription = NativeAudioStream.audioStream.listen(
          (pcmBytes) {
            if (!_isPaused && _socket != null) {
              _socket!.add(pcmBytes);
            }
          },
          onError: (e) {
            debugPrint('Audio stream error: $e');
            if (!mounted) return;
            setState(() => _error = 'Audio stream error: $e');
          },
        );
      } catch (audioError) {
        debugPrint('Failed to start audio stream: $audioError');
        if (Platform.isIOS) {
          try {
            await Future.delayed(const Duration(seconds: 1));
            debugPrint('Retrying audio stream initialization...');
            await NativeAudioStream.start(sampleRate: 16000);

            _recorderSubscription = NativeAudioStream.audioStream.listen(
              (pcmBytes) {
                if (!_isPaused && _socket != null) {
                  _socket!.add(pcmBytes);
                }
              },
              onError: (e) {
                debugPrint('Audio stream error on retry: $e');
                if (!mounted) return;
                setState(() => _error = 'Audio error: $e');
              },
            );
          } catch (retryError) {
            debugPrint('Retry also failed: $retryError');
            if (mounted) {
              setState(() => _error =
                  'Could not access microphone. Please restart the app.');
            }
            _closeConversation(
              endReason: 'audio_start_failed',
              pop: false,
            );
            return;
          }
        } else {
          if (mounted) {
            setState(() => _error = 'Could not start audio: $audioError');
          }
          _closeConversation(
            endReason: 'audio_start_failed',
            pop: false,
          );
          return;
        }
      }

      _audioPlayer = AudioPlayer();
      _socket!.listen(
        (data) async {
          if (data is Uint8List) {
            try {
              final path = await _writeBytesToTempFile(data, 'wav');
              await _audioPlayer!.setFilePath(path);
              await _audioPlayer!.play();
            } catch (e) {
              debugPrint('Audio playback error: $e');
              if (!mounted) return;
              setState(() => _error = 'Audio playback error: $e');
            }
          } else if (data is String) {
            _handleRealtimeTextMessage(data);
          }
        },
        onError: (e) {
          debugPrint('WebSocket error: $e');
          if (mounted) {
            setState(() => _error = 'Connection error: $e');
          }
          _closeConversation(
            endReason: 'connection_error',
            pop: false,
          );
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          if (mounted) {
            setState(() => _isConnected = false);
          }
          _closeConversation(
            endReason: 'connection_closed',
            pop: false,
          );
        },
      );
    } catch (wsError) {
      debugPrint('WebSocket connection failed: $wsError');
      if (!mounted) return;
      setState(() => _error = 'Failed to connect: $wsError');
    }
  }

  Future<bool> _tryStartWebRtc({
    required Map<String, dynamic> sessionData,
    required String? clientSecret,
  }) async {
    if (clientSecret == null || clientSecret.isEmpty) {
      return false;
    }

    final bool preferWebRtc =
        dotenv.env['OPENAI_REALTIME_PREFER_WEBRTC']?.toLowerCase() != 'false';
    if (!preferWebRtc) {
      return false;
    }

    final String transport = (sessionData['transport'] ?? '').toString();
    if (transport.isNotEmpty && transport.toLowerCase() == 'websocket') {
      return false;
    }

    final webrtcEndpoint = (sessionData['webrtc_url'] as String?) ??
        (sessionData['sdp_url'] as String?) ??
        'https://api.openai.com/v1/realtime?model=$_realtimeModel';

    try {
      final pc = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      });

      final localStream =
          await navigator.mediaDevices.getUserMedia({'audio': true});
      for (final track in localStream.getTracks()) {
        await pc.addTrack(track, localStream);
      }

      final dataChannel = await pc.createDataChannel(
        'oai-events',
        RTCDataChannelInit()..ordered = true,
      );
      _bindDataChannelHandlers(dataChannel);

      pc.onDataChannel = (channel) {
        _bindDataChannelHandlers(channel);
      };

      pc.onConnectionState = (state) {
        if (!mounted) return;
        setState(() {
          switch (state) {
            case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
              _connectionModeLabel = 'WebRTC';
              break;
            case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
              _connectionModeLabel = 'Connecting (WebRTC)';
              break;
            case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
              _error = 'WebRTC connection disconnected.';
              break;
            case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
              _error = 'WebRTC connection failed. Falling back...';
              break;
            default:
              break;
          }
        });
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          _closeConversation(
            endReason: 'webrtc_connection_lost',
            pop: false,
          );
        }
      };

      final offer = await pc.createOffer({'offerToReceiveAudio': true});
      await pc.setLocalDescription(offer);
      final localDescription = await pc.getLocalDescription();
      if (localDescription?.sdp == null) {
        await localStream.dispose();
        await pc.close();
        return false;
      }

      final response = await http.post(
        Uri.parse(webrtcEndpoint),
        headers: {
          'Authorization': 'Bearer $clientSecret',
          'Content-Type': 'application/sdp',
          'Accept': 'application/sdp',
        },
        body: localDescription!.sdp!,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await localStream.dispose();
        await pc.close();
        return false;
      }

      final answerSdp = response.body;
      if (answerSdp.isEmpty) {
        await localStream.dispose();
        await pc.close();
        return false;
      }
      await pc.setRemoteDescription(
        RTCSessionDescription(answerSdp, 'answer'),
      );

      _peerConnection = pc;
      _localMediaStream = localStream;
      _dataChannel = dataChannel;
      if (mounted) {
        setState(() {
          _isConnected = true;
          _isPaused = false;
          _usingWebRtc = true;
          _connectionModeLabel = 'WebRTC';
        });
      }
      await _startTrackedSessionIfNeeded();
      _startCallTimer();
      return true;
    } catch (e) {
      debugPrint('WebRTC setup failed, using websocket fallback: $e');
      await _disposeWebRtcResources();
      return false;
    }
  }

  void _bindDataChannelHandlers(RTCDataChannel channel) {
    _dataChannel = channel;
    channel.onDataChannelState = (state) {
      if (!mounted) return;
      setState(() {
        if (state == RTCDataChannelState.RTCDataChannelOpen) {
          _connectionModeLabel = 'WebRTC';
        } else if (state == RTCDataChannelState.RTCDataChannelClosed &&
            _isConnected) {
          _error = 'WebRTC data channel closed.';
          _closeConversation(
            endReason: 'webrtc_data_channel_closed',
            pop: false,
          );
        }
      });
    };
    channel.onMessage = (message) {
      if (!message.isBinary) {
        _handleRealtimeTextMessage(message.text);
      }
    };
  }

  void _handleRealtimeTextMessage(String data) {
    try {
      final msg = jsonDecode(data);
      if (msg is! Map<String, dynamic>) {
        if (mounted) {
          setState(() => _currentTranscript = data);
        }
        return;
      }

      final eventType = msg['type']?.toString() ?? '';
      final transcriptText = _extractTranscriptText(msg);
      if (transcriptText != null && transcriptText.isNotEmpty) {
        if (mounted) {
          setState(() => _currentTranscript = transcriptText);
        }
        return;
      }
      if (eventType == 'status') {
        debugPrint('Realtime status update: $msg');
      } else if (mounted) {
        setState(() => _currentTranscript = data);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _currentTranscript = data);
      }
    }
  }

  String? _extractTranscriptText(Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? '';
    if (type == 'transcript') {
      return event['text']?.toString();
    }
    if (type == 'response.audio_transcript.delta' ||
        type == 'response.audio_transcript.done') {
      return event['delta']?.toString() ?? event['transcript']?.toString();
    }
    if (type == 'conversation.item.input_audio_transcription.completed') {
      return event['transcript']?.toString();
    }

    final output = event['output'];
    if (output is List && output.isNotEmpty) {
      final first = output.first;
      if (first is Map<String, dynamic>) {
        final content = first['content'];
        if (content is List && content.isNotEmpty) {
          final firstPart = content.first;
          if (firstPart is Map<String, dynamic>) {
            final text = firstPart['text']?.toString();
            if (text != null && text.isNotEmpty) {
              return text;
            }
          }
        }
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _createRealtimeSession() async {
    final payload = jsonEncode({
      'model': _realtimeModel,
    });

    if (_proxyConfig.hasProxy) {
      try {
        final proxyResponse = await http.post(
          _proxyConfig.proxyUri('/openai/realtime/sessions'),
          headers: _proxyConfig.proxyHeaders(),
          body: payload,
        );
        if (proxyResponse.statusCode >= 200 && proxyResponse.statusCode < 300) {
          return jsonDecode(proxyResponse.body) as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('Proxy realtime session creation failed: $e');
      }
    }

    if (!_canCallDirectProvider) {
      return null;
    }

    try {
      final directResponse = await http.post(
        Uri.parse('https://api.openai.com/v1/realtime/sessions'),
        headers: {
          'Authorization': 'Bearer $_openAiApiKey',
          'Content-Type': 'application/json',
        },
        body: payload,
      );
      if (directResponse.statusCode >= 200 && directResponse.statusCode < 300) {
        return jsonDecode(directResponse.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Direct realtime session creation failed: $e');
    }

    return null;
  }

  bool get _canCallDirectProvider {
    final hasKey = _openAiApiKey != null && _openAiApiKey!.isNotEmpty;
    if (!hasKey) return false;
    if (!_proxyConfig.allowDirectFallback) return false;
    if (_proxyConfig.requireProxy && kReleaseMode) return false;
    return true;
  }

  void _pauseConversation() async {
    if (!mounted) return;
    setState(() => _isPaused = true);
    if (_usingWebRtc) {
      for (final track in _localMediaStream?.getAudioTracks() ?? const []) {
        track.enabled = false;
      }
      return;
    }
    await _audioPlayer?.pause();
  }

  void _resumeConversation() async {
    if (!mounted) return;
    setState(() => _isPaused = false);
    if (_usingWebRtc) {
      for (final track in _localMediaStream?.getAudioTracks() ?? const []) {
        track.enabled = true;
      }
      return;
    }
    await _audioPlayer?.play();
  }

  Future<void> _disposeWebRtcResources() async {
    final dataChannel = _dataChannel;
    _dataChannel = null;
    if (dataChannel != null) {
      try {
        await dataChannel.close();
      } catch (_) {}
    }

    final localStream = _localMediaStream;
    _localMediaStream = null;
    if (localStream != null) {
      try {
        for (final track in localStream.getTracks()) {
          await track.stop();
        }
      } catch (_) {}
      try {
        await localStream.dispose();
      } catch (_) {}
    }

    final pc = _peerConnection;
    _peerConnection = null;
    if (pc != null) {
      try {
        await pc.close();
      } catch (_) {}
    }
  }

  Future<void> _closeConversation({
    String endReason = 'user_closed',
    bool pop = true,
  }) async {
    if (_isClosing) return;
    _isClosing = true;

    _callTimer?.cancel();
    if (mounted) {
      setState(() {
        _isPaused = true;
        _isConnected = false;
        _usingWebRtc = false;
        _connectionModeLabel = 'Disconnected';
      });
    }

    // Clean up resources in a safe order
    try {
      debugPrint('Closing conversation and cleaning up resources...');

      // Cancel recorder subscription first
      if (_recorderSubscription != null) {
        debugPrint('Cancelling recorder subscription');
        await _recorderSubscription!.cancel();
        _recorderSubscription = null;
      }

      // Stop native audio stream
      try {
        if (!_usingWebRtc) {
          debugPrint('Stopping native audio stream');
          await NativeAudioStream.stop();
        }
      } catch (e) {
        debugPrint('Error stopping native audio stream: $e');
        // Continue with cleanup despite errors
      }

      await _disposeWebRtcResources();

      // Stop and dispose audio player
      if (_audioPlayer != null) {
        try {
          debugPrint('Stopping audio player');
          await _audioPlayer!.stop();
          await Future.delayed(const Duration(milliseconds: 100));
          await _audioPlayer!.dispose();
        } catch (e) {
          debugPrint('Error cleaning up audio player: $e');
        }
        _audioPlayer = null;
      }

      // Close WebSocket connection last
      if (_socket != null) {
        try {
          debugPrint('Closing WebSocket connection');
          await _socket!.close();
        } catch (e) {
          debugPrint('Error closing WebSocket: $e');
        }
        _socket = null;
      }

      debugPrint('Cleanup completed');
    } catch (e) {
      debugPrint('Error during conversation cleanup: $e');
    }

    await _endTrackedSessionIfNeeded(endReason);
    _callTimer?.cancel();

    // If we're in a navigation context, pop
    if (pop && mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    _isClosing = false;
  }

  @override
  void dispose() {
    debugPrint('Disposing OpenAIRealtimeVoiceConversationScreen');
    WidgetsBinding.instance.removeObserver(this);
    // Ensure cleanup happens when widget is disposed
    _closeConversation(
      endReason: 'screen_disposed',
      pop: false,
    );
    super.dispose();
  }

  String _formatSeconds(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final minutes = safe ~/ 60;
    final seconds = safe % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final remainingSecondsRaw = _maxAllowedCallSeconds - _elapsedCallSeconds;
    final remainingSeconds = remainingSecondsRaw < 0 ? 0 : remainingSecondsRaw;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call with AI Buddy'),
        actions: [
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            tooltip: _isPaused ? 'Resume' : 'Pause',
            onPressed: !_isConnected
                ? null
                : (_isPaused ? _resumeConversation : _pauseConversation),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => _closeConversation(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_callAllowance != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _isPremiumUser
                      ? 'Premium left today: ${_aiUsageLimitService.formatDurationShort(_callAllowance!.remainingTodaySeconds)}'
                      : 'Free left today: ${_aiUsageLimitService.formatDurationShort(_callAllowance!.remainingTodaySeconds)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF355C7D),
                  ),
                ),
              ),
            if (_parentalControls.maxCallMinutesOverride != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Parent cap: ${_parentalControls.maxCallMinutesOverride} min/call',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A5D73),
                  ),
                ),
              ),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.blue[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPaused ? Icons.hearing_disabled : Icons.hearing,
                size: 64,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Call time left: ${_formatSeconds(remainingSeconds)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF355C7D),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _currentTranscript ??
                    (_isPaused
                        ? 'Paused'
                        : _isConnected
                            ? 'Say something...'
                            : 'Connecting...'),
                style: const TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_isConnected)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Transport: $_connectionModeLabel',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A5D73),
                  ),
                ),
              ),
            if (_error != null && _isQuotaBlocked && !_isPremiumUser)
              FilledButton(
                onPressed: () => Navigator.pushNamed(context, '/subscription'),
                child: const Text('Upgrade for more AI minutes'),
              ),
            const SizedBox(height: 40),
            if (!_isPaused && _isConnected)
              const Text('Listening and responding in real time...',
                  style: TextStyle(color: Colors.blueGrey)),
          ],
        ),
      ),
    );
  }
}
