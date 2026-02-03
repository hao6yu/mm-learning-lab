import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'dart:typed_data';
import '../services/native_audio_stream.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;

class OpenAIRealtimeVoiceConversationScreen extends StatefulWidget {
  const OpenAIRealtimeVoiceConversationScreen({super.key});

  @override
  State<OpenAIRealtimeVoiceConversationScreen> createState() => _OpenAIRealtimeVoiceConversationScreenState();
}

class _OpenAIRealtimeVoiceConversationScreenState extends State<OpenAIRealtimeVoiceConversationScreen> {
  bool _isPaused = false;
  bool _isConnected = false;
  String? _currentTranscript;
  String? _error;
  late String _realtimeModel;

  WebSocket? _socket;
  StreamSubscription? _recorderSubscription;
  AudioPlayer? _audioPlayer;

  @override
  void initState() {
    super.initState();
    // Get realtime model from env or use default
    _realtimeModel = dotenv.env['OPENAI_REALTIME_MODEL'] ?? 'gpt-4o-realtime-preview-2024-12-17';
    _startConversation();
  }

  Future<String> _writeBytesToTempFile(Uint8List bytes, String extension) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/openai_audio.$extension');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> _startConversation() async {
    setState(() {
      _isConnected = false;
      _isPaused = false;
      _error = null;
    });

    try {
      // First, ensure microphone permission is granted
      final initialStatus = await Permission.microphone.status;
      print('Initial microphone permission status: $initialStatus');
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        setState(() => _error = 'Microphone permission denied. Please enable it in settings.');
        return;
      }

      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null) {
        setState(() => _error = 'OpenAI API key not found.');
        return;
      }

      // Step 1: Create a session
      print('Creating OpenAI realtime session...');
      final sessionResponse = await http.post(
        Uri.parse('https://api.openai.com/v1/realtime/sessions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": _realtimeModel,
          // Add any other required params here
        }),
      );

      print('Session creation status: ${sessionResponse.statusCode}');
      if (sessionResponse.statusCode != 200) {
        setState(() => _error = 'Failed to create session: ${sessionResponse.statusCode} ${sessionResponse.body}');
        return;
      }

      final sessionData = jsonDecode(sessionResponse.body);
      print('Session response JSON: $sessionData');
      final sessionId = sessionData['id'];
      final clientSecret = sessionData['client_secret']?['value'];
      if (sessionId == null) {
        setState(() => _error = 'Missing session ID from API response');
        return;
      }

      final wsUrl = 'wss://api.openai.com/v1/realtime/sessions/$sessionId';
      print('WebSocket URL at runtime: $wsUrl');

      // Step 2: Connect to WebSocket
      try {
        final headers = {
          'Authorization': 'Bearer $clientSecret',
        };
        print('Attempting to connect to WebSocket...');
        _socket = await WebSocket.connect(wsUrl, headers: headers);
        print('WebSocket connection established.');

        setState(() => _isConnected = true);

        // Send initial start message
        _socket!.add(jsonEncode({
          "type": "start",
          "model": _realtimeModel,
        }));

        // Step 3: Initialize audio streaming with retry logic
        try {
          print('Starting native audio stream...');
          await NativeAudioStream.start(sampleRate: 16000);
          print('Native audio stream started successfully');

          _recorderSubscription = NativeAudioStream.audioStream.listen(
            (pcmBytes) {
              if (!_isPaused && _socket != null) {
                _socket!.add(pcmBytes);
              }
            },
            onError: (e) {
              print('Audio stream error: $e');
              setState(() => _error = 'Audio stream error: $e');
            },
          );
        } catch (audioError) {
          print('Failed to start audio stream: $audioError');

          // Try once more after a delay
          if (Platform.isIOS) {
            try {
              await Future.delayed(const Duration(seconds: 1));
              print('Retrying audio stream initialization...');
              await NativeAudioStream.start(sampleRate: 16000);

              _recorderSubscription = NativeAudioStream.audioStream.listen(
                (pcmBytes) {
                  if (!_isPaused && _socket != null) {
                    _socket!.add(pcmBytes);
                  }
                },
                onError: (e) {
                  print('Audio stream error on retry: $e');
                  setState(() => _error = 'Audio error: $e');
                },
              );
            } catch (retryError) {
              print('Retry also failed: $retryError');
              setState(() => _error = 'Could not access microphone. Please restart the app.');
              return;
            }
          } else {
            setState(() => _error = 'Could not start audio: $audioError');
            return;
          }
        }

        // Step 4: Initialize audio player and WebSocket listeners
        _audioPlayer = AudioPlayer();
        _socket!.listen(
          (data) async {
            if (data is Uint8List) {
              // Assume WAV format for now
              try {
                final path = await _writeBytesToTempFile(data, 'wav');
                await _audioPlayer!.setFilePath(path);
                await _audioPlayer!.play();
              } catch (e) {
                print('Audio playback error: $e');
                setState(() => _error = 'Audio playback error: $e');
              }
            } else if (data is String) {
              // Handle JSON/text messages
              try {
                final msg = jsonDecode(data);
                if (msg['type'] == 'transcript') {
                  setState(() => _currentTranscript = msg['text']);
                } else if (msg['type'] == 'status') {
                  // Optionally handle status updates
                  print('Status update: $msg');
                } else {
                  setState(() => _currentTranscript = data);
                }
              } catch (_) {
                setState(() => _currentTranscript = data);
              }
            }
          },
          onError: (e) {
            print('WebSocket error: $e');
            setState(() => _error = 'Connection error: $e');
          },
          onDone: () {
            print('WebSocket connection closed');
            setState(() => _isConnected = false);
          },
        );
      } catch (wsError) {
        print('WebSocket connection failed: $wsError');
        setState(() => _error = 'Failed to connect: $wsError');
      }
    } catch (e) {
      print('Unexpected error in conversation start: $e');
      setState(() => _error = 'Error: $e');
    }
  }

  void _pauseConversation() async {
    setState(() => _isPaused = true);
    await _audioPlayer?.pause();
  }

  void _resumeConversation() async {
    setState(() => _isPaused = false);
    await _audioPlayer?.play();
  }

  void _closeConversation() async {
    setState(() => _isPaused = true); // First pause to stop sending data

    // Clean up resources in a safe order
    try {
      print('Closing conversation and cleaning up resources...');

      // Cancel recorder subscription first
      if (_recorderSubscription != null) {
        print('Cancelling recorder subscription');
        await _recorderSubscription!.cancel();
        _recorderSubscription = null;
      }

      // Stop native audio stream
      try {
        print('Stopping native audio stream');
        await NativeAudioStream.stop();
      } catch (e) {
        print('Error stopping native audio stream: $e');
        // Continue with cleanup despite errors
      }

      // Stop and dispose audio player
      if (_audioPlayer != null) {
        try {
          print('Stopping audio player');
          await _audioPlayer!.stop();
          await Future.delayed(const Duration(milliseconds: 100));
          await _audioPlayer!.dispose();
        } catch (e) {
          print('Error cleaning up audio player: $e');
        }
        _audioPlayer = null;
      }

      // Close WebSocket connection last
      if (_socket != null) {
        try {
          print('Closing WebSocket connection');
          await _socket!.close();
        } catch (e) {
          print('Error closing WebSocket: $e');
        }
        _socket = null;
      }

      print('Cleanup completed');
    } catch (e) {
      print('Error during conversation cleanup: $e');
    }

    // If we're in a navigation context, pop
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    print('Disposing OpenAIRealtimeVoiceConversationScreen');
    // Ensure cleanup happens when widget is disposed
    _closeConversation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Chat with ChatGPT'),
        actions: [
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            tooltip: _isPaused ? 'Resume' : 'Pause',
            onPressed: _isPaused ? _resumeConversation : _pauseConversation,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: _closeConversation,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
            const SizedBox(height: 40),
            if (!_isPaused && _isConnected) const Text('Listening and responding in real time...', style: TextStyle(color: Colors.blueGrey)),
          ],
        ),
      ),
    );
  }
}
