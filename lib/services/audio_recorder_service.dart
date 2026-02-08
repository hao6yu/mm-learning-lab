import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorderService {
  static final AudioRecorderService _instance =
      AudioRecorderService._internal();

  factory AudioRecorderService() => _instance;

  AudioRecorderService._internal();

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;
  String? _recordingPath;

  Future<void> initialize() async {
    if (_isRecorderInitialized) return;

    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception('Microphone permission not granted');
      }

      // For iOS, we need to make sure the audio session is properly configured
      if (Platform.isIOS) {
        // Try to properly reset the recorder state first
        try {
          await _recorder.closeRecorder();
        } catch (e) {
          // Ignore errors during closing - might not be open yet
          debugPrint('Info: Attempted pre-initialization cleanup: $e');
        }
      }

      // Open the recorder with a timeout to prevent hanging
      bool recorderOpened = false;
      try {
        await _recorder.openRecorder();
        recorderOpened = true;
        debugPrint('Recorder opened successfully');
      } catch (e) {
        debugPrint('Error opening recorder: $e');
        if (Platform.isIOS) {
          // On iOS, try once more with a delay
          await Future.delayed(const Duration(milliseconds: 800));
          await _recorder.openRecorder();
          recorderOpened = true;
          debugPrint('Recorder opened successfully on second attempt');
        } else {
          rethrow;
        }
      }

      if (!recorderOpened) {
        throw Exception('Failed to open audio recorder');
      }

      _isRecorderInitialized = true;
    } catch (e) {
      debugPrint('Error initializing audio recorder: $e');
      // Clean up if initialization failed
      try {
        await _recorder.closeRecorder();
      } catch (_) {}
      _isRecorderInitialized = false;
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (_isRecorderInitialized) {
      await _recorder.closeRecorder();
      _isRecorderInitialized = false;
    }
  }

  Future<String?> startRecording() async {
    try {
      if (!_isRecorderInitialized) {
        await initialize();
      }

      // Create temp directory for recordings
      final tempDir = await getTemporaryDirectory();
      final recordingsDir = Directory('${tempDir.path}/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      // Create a unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${recordingsDir.path}/recording_$timestamp.wav';

      // On iOS, make sure the recorder is in a good state
      if (Platform.isIOS && _recorder.isRecording) {
        try {
          await _recorder.stopRecorder();
          debugPrint(
              'Stopped existing recording session before starting new one');
        } catch (e) {
          debugPrint('Error stopping existing recording: $e');
          // Continue anyway
        }
      }

      // Start recording to the file
      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
      );

      debugPrint('Recording started successfully to path: $_recordingPath');
      return _recordingPath;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      // Try to re-initialize if recording fails
      if (_isRecorderInitialized) {
        try {
          await dispose();
          await Future.delayed(const Duration(milliseconds: 500));
          await initialize();
        } catch (reinitError) {
          debugPrint('Failed to reinitialize recorder: $reinitError');
        }
      }
      return null;
    }
  }

  Future<String?> stopRecording() async {
    if (!_isRecorderInitialized || !_recorder.isRecording) {
      return null;
    }

    await _recorder.stopRecorder();
    return _recordingPath;
  }

  Future<List<int>?> getRecordingBytes() async {
    if (_recordingPath == null) return null;

    final file = File(_recordingPath!);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  bool get isRecording => _recorder.isRecording;

  Future<void> deleteRecording() async {
    if (_recordingPath != null) {
      final file = File(_recordingPath!);
      if (await file.exists()) {
        await file.delete();
      }
      _recordingPath = null;
    }
  }

  Future<void> cancelRecording() async {
    if (_isRecorderInitialized && _recorder.isRecording) {
      await _recorder.stopRecorder();
      debugPrint('Recording canceled and stopped');
    }

    await deleteRecording();

    _recordingPath = null;
  }

  Future<void> cleanupOldRecordings({Duration? olderThan}) async {
    final tempDir = await getTemporaryDirectory();
    final recordingsDir = Directory('${tempDir.path}/recordings');

    if (!await recordingsDir.exists()) {
      return;
    }

    final cutoffTime =
        DateTime.now().subtract(olderThan ?? const Duration(days: 1));

    try {
      final files = await recordingsDir.list().toList();
      for (final entity in files) {
        if (entity is File && entity.path.contains('recording_')) {
          final fileStat = await entity.stat();
          if (fileStat.modified.isBefore(cutoffTime)) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up old recordings: $e');
    }
  }
}
