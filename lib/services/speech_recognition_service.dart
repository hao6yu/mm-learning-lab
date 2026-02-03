import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart' show kIsWeb;

class SpeechRecognitionService {
  static final SpeechRecognitionService _instance = SpeechRecognitionService._internal();

  factory SpeechRecognitionService() => _instance;

  SpeechRecognitionService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech recognition status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
        onError: (error) {
          debugPrint('Speech recognition error: $error');
          _isListening = false;
        },
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('Error initializing speech recognition: $e');
      _isInitialized = false;
      return false;
    }
  }

  Future<bool> startListening({
    required Function(String text) onResult,
    String? localeId,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (_isListening) {
      await stopListening();
    }

    try {
      _isListening = await _speech.listen(
        onResult: (result) {
          final recognizedWords = result.recognizedWords;
          if (recognizedWords.isNotEmpty) {
            onResult(recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: localeId,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
      return _isListening;
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      return false;
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  bool get isAvailable => _isInitialized;
  bool get isListening => _isListening;

  Future<List<stt.LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return [];
    }

    try {
      return _speech.locales();
    } catch (e) {
      debugPrint('Error getting available locales: $e');
      return [];
    }
  }

  Future<void> cancelListening() async {
    if (_isListening) {
      await _speech.cancel();
      _isListening = false;
    }
  }
}
