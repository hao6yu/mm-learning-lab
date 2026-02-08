import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'ai_proxy_config.dart';

class ElevenLabsService {
  static const String _directBaseUrl = 'https://api.elevenlabs.io/v1';
  static const String _proxyBasePath = '/elevenlabs';

  static String? _apiKey;
  static String _voiceId = '9BWtsMINqrJLrRacOk9x';
  static AiProxyConfig _proxyConfig = AiProxyConfig(
    baseUrl: null,
    token: null,
    requireProxy: kReleaseMode,
    allowDirectFallback: !kReleaseMode,
  );

  static final List<Map<String, String>> availableVoices = [
    {'id': '9BWtsMINqrJLrRacOk9x', 'name': 'Aria'},
    {'id': 'N2lVS1w4EtoT3dr4eOWO', 'name': 'Callum'},
    {'id': 'iV5XeqzOeJzUHmdQ8FLK', 'name': 'Haoziiiiiii'},
    {'id': 'mlFsujxZWlk6xPyQJgMb', 'name': 'Mary'},
    {'id': 'x7Pz9CsHMAlHFwKlPxu8', 'name': 'Madeline'},
  ];

  static Future<void> initialize({String? apiKey, String? voiceId}) async {
    _apiKey = apiKey ?? dotenv.env['ELEVENLABS_API_KEY'];
    if (voiceId != null) {
      _voiceId = voiceId;
    }
    _proxyConfig = AiProxyConfig.fromEnv();
  }

  Future<Directory> get _audioDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${appDir.path}/story_audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir;
  }

  Future<String> _getAudioFilePath(int storyId, {String? voiceId}) async {
    final audioDir = await _audioDirectory;
    final effectiveVoiceId = voiceId ?? _voiceId;
    return path.join(
        audioDir.path, 'story_${storyId}_voice_$effectiveVoiceId.mp3');
  }

  Future<bool> hasAudioFile(int storyId, {String? voiceId}) async {
    try {
      final filePath = await _getAudioFilePath(storyId, voiceId: voiceId);
      return File(filePath).exists();
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>?> getVoices() async {
    final proxyResponse = await _getVoicesViaProxy();
    if (proxyResponse != null) {
      return proxyResponse;
    }

    if (_canCallDirectProvider) {
      final directResponse = await _getVoicesViaDirect();
      if (directResponse != null) {
        return directResponse;
      }
    }

    return availableVoices
        .map((voice) => {
              'voice_id': voice['id'],
              'name': voice['name'],
            })
        .toList();
  }

  static void setVoiceId(String voiceId) {
    _voiceId = voiceId;
  }

  static String getCurrentVoiceId() {
    return _voiceId;
  }

  static String getVoiceNameById(String voiceId) {
    final voice = availableVoices.firstWhere(
      (item) => item['id'] == voiceId,
      orElse: () => {'id': voiceId, 'name': 'Unknown Voice'},
    );
    return voice['name']!;
  }

  Future<String?> generateAudio(String text, int storyId,
      {String? voiceId}) async {
    final effectiveVoiceId = voiceId ?? _voiceId;
    final bytes = await _generateAudioBytes(
      text: text,
      voiceId: effectiveVoiceId,
      voiceSettings: const {
        'stability': 0.35,
        'similarity_boost': 1.00,
        'style': 0,
        'use_speaker_boost': true,
      },
      withTimestamps: false,
    );
    if (bytes == null) return null;

    final filePath =
        await _getAudioFilePath(storyId, voiceId: effectiveVoiceId);
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }

  Future<File?> getAudioFile(int storyId, {String? voiceId}) async {
    try {
      final filePath = await _getAudioFilePath(storyId, voiceId: voiceId);
      final file = File(filePath);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteAudioFile(int storyId, {String? voiceId}) async {
    try {
      final filePath = await _getAudioFilePath(storyId, voiceId: voiceId);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteAllAudioFiles(int storyId) async {
    var allDeleted = true;
    for (final voice in availableVoices) {
      final success = await deleteAudioFile(storyId, voiceId: voice['id']);
      if (!success) {
        allDeleted = false;
      }
    }
    return allDeleted;
  }

  Future<AudioPlayer?> playAudio(int storyId, {String? voiceId}) async {
    try {
      final file = await getAudioFile(storyId, voiceId: voiceId);
      if (file == null) return null;

      final player = AudioPlayer();
      await player.setFilePath(file.path);
      await player.play();
      return player;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> generateAudioWithTimestamps({
    required String text,
    required int storyId,
    String? voiceId,
  }) async {
    final effectiveVoiceId = voiceId ?? _voiceId;
    final result = await _generateAudioWithTimestampsPayload(
      text: text,
      voiceId: effectiveVoiceId,
      voiceSettings: const {
        'stability': 0.6,
        'similarity_boost': 0.85,
        'style': 0,
        'use_speaker_boost': true,
      },
    );
    if (result == null) return null;

    final audioBytes = result['audioBytes'] as List<int>;
    final wordTimestamps =
        (result['timestamps'] as List<Map<String, dynamic>>?) ?? const [];

    final filePath =
        await _getAudioFilePath(storyId, voiceId: effectiveVoiceId);
    final file = File(filePath);
    await file.writeAsBytes(audioBytes);

    await _saveTimestampData(
      storyId,
      wordTimestamps,
      voiceId: effectiveVoiceId,
    );

    return {
      'audioPath': filePath,
      'timestamps': wordTimestamps,
    };
  }

  List<Map<String, dynamic>> _convertCharacterTimesToWordTimes(
    String originalText,
    List<String> characters,
    List<double> startTimes,
    List<double> endTimes,
  ) {
    final wordTimestamps = <Map<String, dynamic>>[];
    final wordRegex = RegExp(r"[\w'']+");
    final matches = wordRegex.allMatches(originalText).toList();

    for (final match in matches) {
      final word = match.group(0)!;
      final wordStart = match.start;
      final wordEnd = match.end;

      int charStartIndex = -1;
      int charEndIndex = -1;

      var charArrayPos = 0;
      for (var textPos = 0;
          textPos < originalText.length && charArrayPos < characters.length;
          textPos++) {
        if (textPos == wordStart && charStartIndex == -1) {
          charStartIndex = charArrayPos;
        }
        if (textPos == wordEnd - 1 && charEndIndex == -1) {
          charEndIndex = charArrayPos;
        }

        if (charArrayPos < characters.length &&
            originalText[textPos].toLowerCase() ==
                characters[charArrayPos].toLowerCase()) {
          charArrayPos++;
        }
      }

      if (charStartIndex >= 0 && charStartIndex < startTimes.length) {
        final wordStartTime = startTimes[charStartIndex];
        final wordEndTime = charEndIndex >= 0 && charEndIndex < endTimes.length
            ? endTimes[charEndIndex]
            : (charStartIndex < endTimes.length
                ? endTimes[charStartIndex]
                : wordStartTime + 0.1);

        wordTimestamps.add({
          'word': word.toLowerCase(),
          'start': wordStartTime,
          'end': wordEndTime,
          'originalWord': word,
          'textStart': wordStart,
          'textEnd': wordEnd,
        });
      }
    }

    return wordTimestamps;
  }

  Future<void> _saveTimestampData(
    int storyId,
    List<Map<String, dynamic>> timestamps, {
    String? voiceId,
  }) async {
    try {
      final timestampPath =
          await _getTimestampFilePath(storyId, voiceId: voiceId);
      final file = File(timestampPath);
      await file.writeAsString(jsonEncode(timestamps));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getTimestampData(
    int storyId, {
    String? voiceId,
  }) async {
    try {
      final timestampPath =
          await _getTimestampFilePath(storyId, voiceId: voiceId);
      final file = File(timestampPath);

      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> data = jsonDecode(content);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> hasTimestampData(int storyId, {String? voiceId}) async {
    try {
      final timestampPath =
          await _getTimestampFilePath(storyId, voiceId: voiceId);
      final file = File(timestampPath);
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  Future<String> _getTimestampFilePath(int storyId, {String? voiceId}) async {
    final directory = await getApplicationDocumentsDirectory();
    final effectiveVoiceId = voiceId ?? _voiceId;
    return '${directory.path}/story_${storyId}_${effectiveVoiceId}_timestamps.json';
  }

  Future<String?> generateAudioWithSettings(
    String text,
    int storyId, {
    String? voiceId,
    Map<String, dynamic>? voiceSettings,
  }) async {
    final effectiveVoiceId = voiceId ?? _voiceId;

    final effectiveSettings = <String, dynamic>{
      'stability': 0.35,
      'similarity_boost': 1.00,
      'style': 0,
      'use_speaker_boost': true,
    };
    if (voiceSettings != null) {
      effectiveSettings.addAll(voiceSettings);
    }

    final bytes = await _generateAudioBytes(
      text: text,
      voiceId: effectiveVoiceId,
      voiceSettings: effectiveSettings,
      withTimestamps: false,
    );
    if (bytes == null) return null;

    final filePath =
        await _getAudioFilePath(storyId, voiceId: effectiveVoiceId);
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }

  Future<List<Map<String, dynamic>>?> _getVoicesViaProxy() async {
    if (!_proxyConfig.hasProxy) return null;
    try {
      final response = await http.get(
        _proxyConfig.proxyUri('$_proxyBasePath/voices'),
        headers: _proxyConfig.proxyHeaders(),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic> && data['voices'] is List) {
        return List<Map<String, dynamic>>.from(data['voices']);
      }
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> _getVoicesViaDirect() async {
    if (!_canCallDirectProvider) return null;
    try {
      final response = await http.get(
        Uri.parse('$_directBaseUrl/voices'),
        headers: {
          'Accept': 'application/json',
          'xi-api-key': _apiKey!,
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['voices']);
    } catch (_) {
      return null;
    }
  }

  Future<List<int>?> _generateAudioBytes({
    required String text,
    required String voiceId,
    required Map<String, dynamic> voiceSettings,
    required bool withTimestamps,
  }) async {
    if (withTimestamps) return null;

    final proxyBytes = await _generateAudioBytesViaProxy(
      text: text,
      voiceId: voiceId,
      voiceSettings: voiceSettings,
    );
    if (proxyBytes != null) {
      return proxyBytes;
    }

    if (_canCallDirectProvider) {
      return _generateAudioBytesViaDirect(
        text: text,
        voiceId: voiceId,
        voiceSettings: voiceSettings,
      );
    }

    return null;
  }

  Future<Map<String, dynamic>?> _generateAudioWithTimestampsPayload({
    required String text,
    required String voiceId,
    required Map<String, dynamic> voiceSettings,
  }) async {
    final proxyPayload = await _generateAudioTimestampsViaProxy(
      text: text,
      voiceId: voiceId,
      voiceSettings: voiceSettings,
    );
    if (proxyPayload != null) {
      return proxyPayload;
    }

    if (_canCallDirectProvider) {
      return _generateAudioTimestampsViaDirect(
        text: text,
        voiceId: voiceId,
        voiceSettings: voiceSettings,
      );
    }
    return null;
  }

  Future<List<int>?> _generateAudioBytesViaProxy({
    required String text,
    required String voiceId,
    required Map<String, dynamic> voiceSettings,
  }) async {
    if (!_proxyConfig.hasProxy) return null;
    try {
      final response = await http.post(
        _proxyConfig.proxyUri('$_proxyBasePath/text-to-speech/$voiceId'),
        headers: {
          ..._proxyConfig.proxyHeaders(json: false),
          'Accept': 'audio/mpeg',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': voiceSettings,
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<int>?> _generateAudioBytesViaDirect({
    required String text,
    required String voiceId,
    required Map<String, dynamic> voiceSettings,
  }) async {
    if (!_canCallDirectProvider) return null;
    try {
      final response = await http.post(
        Uri.parse('$_directBaseUrl/text-to-speech/$voiceId'),
        headers: {
          'Accept': 'audio/mpeg',
          'Content-Type': 'application/json',
          'xi-api-key': _apiKey!,
        },
        body: jsonEncode({
          'text': text,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': voiceSettings,
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _generateAudioTimestampsViaProxy({
    required String text,
    required String voiceId,
    required Map<String, dynamic> voiceSettings,
  }) async {
    if (!_proxyConfig.hasProxy) return null;
    try {
      final response = await http.post(
        _proxyConfig.proxyUri(
            '$_proxyBasePath/text-to-speech/$voiceId/with-timestamps'),
        headers: _proxyConfig.proxyHeaders(),
        body: jsonEncode({
          'text': text,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': voiceSettings,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return _parseTimestampsPayload(response.body, text);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _generateAudioTimestampsViaDirect({
    required String text,
    required String voiceId,
    required Map<String, dynamic> voiceSettings,
  }) async {
    if (!_canCallDirectProvider) return null;
    try {
      final response = await http.post(
        Uri.parse('$_directBaseUrl/text-to-speech/$voiceId/with-timestamps'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'xi-api-key': _apiKey!,
        },
        body: jsonEncode({
          'text': text,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': voiceSettings,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return _parseTimestampsPayload(response.body, text);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _parseTimestampsPayload(
    String responseBody,
    String originalText,
  ) {
    final responseData = jsonDecode(responseBody);
    final audioBase64 = responseData['audio_base64'] as String?;
    if (audioBase64 == null || audioBase64.isEmpty) {
      return null;
    }
    final audioBytes = base64Decode(audioBase64);
    final alignment = responseData['alignment'];

    if (alignment == null) {
      return {
        'audioBytes': audioBytes,
        'timestamps': <Map<String, dynamic>>[],
      };
    }

    final characters = List<String>.from(alignment['characters']);
    final startTimes =
        List<double>.from(alignment['character_start_times_seconds']);
    final endTimes =
        List<double>.from(alignment['character_end_times_seconds']);
    final wordTimestamps = _convertCharacterTimesToWordTimes(
      originalText,
      characters,
      startTimes,
      endTimes,
    );

    return {
      'audioBytes': audioBytes,
      'timestamps': wordTimestamps,
    };
  }

  bool get _canCallDirectProvider {
    final hasKey = _apiKey != null && _apiKey!.isNotEmpty;
    if (!hasKey) return false;
    if (!_proxyConfig.allowDirectFallback) return false;
    if (_proxyConfig.requireProxy && kReleaseMode) return false;
    return true;
  }
}
