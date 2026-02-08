import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class NativeAudioStream {
  static const MethodChannel _channel = MethodChannel('native_audio_stream');
  static const EventChannel _eventChannel =
      EventChannel('native_audio_stream_events');

  static Stream<Uint8List>? _audioStream;
  static bool _isStarted = false;

  static Stream<Uint8List> get audioStream {
    _audioStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => event as Uint8List);
    return _audioStream!;
  }

  static Future<void> start({int sampleRate = 16000}) async {
    try {
      if (_isStarted) {
        debugPrint('NativeAudioStream: Already started, stopping first');
        await stop();
        // Add a small delay before restarting
        if (Platform.isIOS) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      debugPrint('NativeAudioStream: Starting with sampleRate=$sampleRate');
      await _channel.invokeMethod('start', {'sampleRate': sampleRate});
      _isStarted = true;
      debugPrint('NativeAudioStream: Successfully started');
    } catch (e) {
      debugPrint('NativeAudioStream: Error starting - $e');
      _isStarted = false;
      if (Platform.isIOS) {
        // On iOS, second attempts sometimes work better after a delay
        try {
          await Future.delayed(const Duration(seconds: 1));
          debugPrint('NativeAudioStream: Trying start again after delay');
          await _channel.invokeMethod('start', {'sampleRate': sampleRate});
          _isStarted = true;
          debugPrint(
              'NativeAudioStream: Successfully started on second attempt');
        } catch (retryError) {
          debugPrint('NativeAudioStream: Error on retry - $retryError');
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }

  static Future<void> stop() async {
    try {
      if (!_isStarted) {
        debugPrint('NativeAudioStream: Not started, nothing to stop');
        return;
      }

      debugPrint('NativeAudioStream: Stopping');
      await _channel.invokeMethod('stop');
      _isStarted = false;
      debugPrint('NativeAudioStream: Successfully stopped');
    } catch (e) {
      debugPrint('NativeAudioStream: Error stopping - $e');
      // Always mark as stopped even if the method call fails
      _isStarted = false;
    }
  }
}
