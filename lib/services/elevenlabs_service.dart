import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'package:just_audio/just_audio.dart';
import 'dart:math';

class ElevenLabsService {
  static const String _baseUrl = 'https://api.elevenlabs.io/v1';
  static String? _apiKey;
  static String _voiceId = '9BWtsMINqrJLrRacOk9x'; // Default voice

  // Available voice options
  static final List<Map<String, String>> availableVoices = [
    {'id': '9BWtsMINqrJLrRacOk9x', 'name': 'Aria'},
    {'id': 'N2lVS1w4EtoT3dr4eOWO', 'name': 'Callum'},
    {'id': 'iV5XeqzOeJzUHmdQ8FLK', 'name': 'Haoziiiiiii'},
    {'id': 'mlFsujxZWlk6xPyQJgMb', 'name': 'Mary'},
    {'id': 'x7Pz9CsHMAlHFwKlPxu8', 'name': 'Madeline'},
  ];

  // Initialize with env variables or direct values
  static Future<void> initialize({String? apiKey, String? voiceId}) async {
    _apiKey = apiKey ?? dotenv.env['ELEVENLABS_API_KEY'];

    // Fallback for testing - WARNING: Remove in production
    if (_apiKey == null || _apiKey!.isEmpty) {
      _apiKey = 'YOUR_ELEVENLABS_API_KEY_HERE'; // Replace with your actual API key if needed
      print('Warning: Using fallback ElevenLabs API key. Please set ELEVENLABS_API_KEY in .env file.');
    }

    if (voiceId != null) {
      _voiceId = voiceId;
    }
  }

  // Get the local directory for storing audio files
  Future<Directory> get _audioDirectory async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${appDir.path}/story_audio');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }
      return audioDir;
    } catch (e) {
      print('Error getting audio directory: $e');
      rethrow;
    }
  }

  // Generate audio file path for a story with specific voice
  Future<String> _getAudioFilePath(int storyId, {String? voiceId}) async {
    try {
      final audioDir = await _audioDirectory;
      final effectiveVoiceId = voiceId ?? _voiceId;
      return path.join(audioDir.path, 'story_${storyId}_voice_$effectiveVoiceId.mp3');
    } catch (e) {
      print('Error generating audio file path: $e');
      rethrow;
    }
  }

  // Check if audio file exists for a story with specific voice
  Future<bool> hasAudioFile(int storyId, {String? voiceId}) async {
    try {
      final filePath = await _getAudioFilePath(storyId, voiceId: voiceId);
      return File(filePath).exists();
    } catch (e) {
      print('Error checking audio file: $e');
      return false;
    }
  }

  // Get available voices from ElevenLabs
  Future<List<Map<String, dynamic>>?> getVoices() async {
    if (_apiKey == null) {
      print('Error: ElevenLabs API key not found');
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/voices'),
        headers: {
          'Accept': 'application/json',
          'xi-api-key': _apiKey!,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['voices']);
      } else {
        print('Error getting voices: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception getting voices: $e');
      return null;
    }
  }

  // Set voice ID
  static void setVoiceId(String voiceId) {
    _voiceId = voiceId;
  }

  // Get current voice ID
  static String getCurrentVoiceId() {
    return _voiceId;
  }

  // Get voice name by ID
  static String getVoiceNameById(String voiceId) {
    final voice = availableVoices.firstWhere(
      (voice) => voice['id'] == voiceId,
      orElse: () => {'id': voiceId, 'name': 'Unknown Voice'},
    );
    return voice['name']!;
  }

  // Generate audio for a story using ElevenLabs API
  Future<String?> generateAudio(String text, int storyId, {String? voiceId}) async {
    print('======== ELEVENLABS SERVICE: GENERATE AUDIO ========');
    print('Text length: ${text.length} characters');
    print('Text preview: "${text.substring(0, min(50, text.length))}${text.length > 50 ? '...' : ''}"');
    print('Story ID: $storyId');

    final effectiveVoiceId = voiceId ?? _voiceId;
    print('Voice ID: $effectiveVoiceId (${getVoiceNameById(effectiveVoiceId)})');

    try {
      // Check if API key is available
      if (_apiKey == null || _apiKey == 'YOUR_ELEVENLABS_API_KEY_HERE') {
        print('⚠️ ElevenLabsService: No valid API key available. Creating placeholder file.');

        // Create placeholder file so the app doesn't keep trying to generate
        final filePath = await _getAudioFilePath(storyId, voiceId: effectiveVoiceId);
        print('Creating placeholder file at: $filePath');
        final file = File(filePath);
        if (!await file.exists()) {
          await file.create();
          print('Placeholder file created');
        } else {
          print('Placeholder file already exists');
        }

        return filePath;
      }

      print('🔄 Sending request to ElevenLabs API endpoint: $_baseUrl/text-to-speech/$effectiveVoiceId');
      print('Request parameters:');
      print('  - Model: eleven_multilingual_v2');
      print('  - Stability: 0.35');
      print('  - Similarity boost: 1.00');

      final stopwatch = Stopwatch()..start();

      final response = await http.post(
        Uri.parse('$_baseUrl/text-to-speech/$effectiveVoiceId'),
        headers: {
          'Accept': 'audio/mpeg',
          'Content-Type': 'application/json',
          'xi-api-key': _apiKey!,
        },
        body: jsonEncode({
          'text': text,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': {
            'stability': 0.35,
            'similarity_boost': 1.00,
            'style': 0,
            'use_speaker_boost': true,
          },
        }),
      );

      final elapsed = stopwatch.elapsedMilliseconds;
      print('Response received in ${elapsed}ms');

      if (response.statusCode == 200) {
        print('✅ Success - Status code: ${response.statusCode}');
        print('Response content type: ${response.headers['content-type']}');
        print('Audio size: ${response.bodyBytes.length} bytes');

        final filePath = await _getAudioFilePath(storyId, voiceId: effectiveVoiceId);
        print('Saving audio to file: $filePath');

        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        print('Audio file saved successfully');
        print('======== ELEVENLABS SERVICE: AUDIO GENERATION COMPLETE ========');
        return filePath;
      } else {
        print('❌ Error - Status code: ${response.statusCode}');
        print('Error response: ${response.body.substring(0, min(200, response.body.length))}${response.body.length > 200 ? '...' : ''}');
        print('======== ELEVENLABS SERVICE: AUDIO GENERATION FAILED ========');
        return null;
      }
    } catch (e) {
      print('❌ Exception generating audio: $e');
      print('Stack trace: ${StackTrace.current}');
      print('======== ELEVENLABS SERVICE: ERROR ========');
      return null;
    }
  }

  // Get audio file for a story
  Future<File?> getAudioFile(int storyId, {String? voiceId}) async {
    try {
      final filePath = await _getAudioFilePath(storyId, voiceId: voiceId);
      final file = File(filePath);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      print('Error getting audio file: $e');
      return null;
    }
  }

  // Delete audio file for a story and voice
  Future<bool> deleteAudioFile(int storyId, {String? voiceId}) async {
    try {
      final filePath = await _getAudioFilePath(storyId, voiceId: voiceId);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting audio file: $e');
      return false;
    }
  }

  // Delete all audio files for a story (all voices)
  Future<bool> deleteAllAudioFiles(int storyId) async {
    bool allDeleted = true;
    try {
      for (final voice in availableVoices) {
        final success = await deleteAudioFile(storyId, voiceId: voice['id']);
        if (!success) {
          allDeleted = false;
        }
      }
      return allDeleted;
    } catch (e) {
      print('Error deleting all audio files: $e');
      return false;
    }
  }

  // Helper to play audio file
  Future<AudioPlayer?> playAudio(int storyId, {String? voiceId}) async {
    try {
      print('ElevenLabsService: Getting audio file for story $storyId with voice ${voiceId ?? _voiceId}');
      final file = await getAudioFile(storyId, voiceId: voiceId);
      if (file != null) {
        print('ElevenLabsService: Found audio file at ${file.path}');

        // Create a new player each time
        final player = AudioPlayer();
        print('ElevenLabsService: Created new AudioPlayer');

        // Set file path first
        print('ElevenLabsService: Setting audio source to ${file.path}');
        await player.setFilePath(file.path);

        // Start playback
        print('ElevenLabsService: Starting playback');
        await player.play();

        // Return the playing player instance
        print('ElevenLabsService: Audio playback started successfully');
        return player;
      }
      print('ElevenLabsService: Audio file not found for story $storyId with voice ${voiceId ?? _voiceId}');
      return null;
    } catch (e) {
      print('ElevenLabsService: Error playing audio: $e');
      return null;
    }
  }

  // Generate audio with character-level timestamp data for word highlighting
  Future<Map<String, dynamic>?> generateAudioWithTimestamps({
    required String text,
    required int storyId,
    String? voiceId,
  }) async {
    final effectiveVoiceId = voiceId ?? _voiceId;

    try {
      print('ElevenLabsService: Generating audio with timestamps for story $storyId with voice $effectiveVoiceId');

      // Check if API key is available
      if (_apiKey == null || _apiKey == 'YOUR_ELEVENLABS_API_KEY_HERE') {
        print('ElevenLabsService: No valid API key available. Creating placeholder files.');

        // Create placeholder files so the app doesn't keep trying to generate
        final filePath = await _getAudioFilePath(storyId, voiceId: effectiveVoiceId);
        final file = File(filePath);
        if (!await file.exists()) {
          await file.create();
        }

        return {
          'audioPath': filePath,
          'timestamps': [],
        };
      }

      // Generate audio with timestamps using the /with-timestamps endpoint
      print('ElevenLabsService: Calling /with-timestamps endpoint');
      final response = await http.post(
        Uri.parse('$_baseUrl/text-to-speech/$effectiveVoiceId/with-timestamps'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'xi-api-key': _apiKey!,
        },
        body: jsonEncode({
          'text': text,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': {
            'stability': 0.6,
            'similarity_boost': 0.85,
            'style': 0,
            'use_speaker_boost': true,
          },
        }),
      );

      if (response.statusCode != 200) {
        print('Error generating audio with timestamps: ${response.statusCode} - ${response.reasonPhrase}');
        return null;
      }

      final responseData = jsonDecode(response.body);

      // Extract audio data and save to file
      final audioBase64 = responseData['audio_base64'] as String;
      final audioBytes = base64Decode(audioBase64);

      final filePath = await _getAudioFilePath(storyId, voiceId: effectiveVoiceId);
      final file = File(filePath);
      await file.writeAsBytes(audioBytes);
      print('ElevenLabsService: Audio file saved to $filePath');

      // Extract character-level timing data
      final alignment = responseData['alignment'];
      if (alignment != null) {
        final characters = List<String>.from(alignment['characters']);
        final startTimes = List<double>.from(alignment['character_start_times_seconds']);
        final endTimes = List<double>.from(alignment['character_end_times_seconds']);

        // Convert character-level timestamps to word-level timestamps
        final wordTimestamps = _convertCharacterTimesToWordTimes(text, characters, startTimes, endTimes);

        // Save timestamps to file for future use
        await _saveTimestampData(storyId, wordTimestamps, voiceId: effectiveVoiceId);

        print('ElevenLabsService: Generated ${wordTimestamps.length} word timestamps');

        return {
          'audioPath': filePath,
          'timestamps': wordTimestamps,
        };
      } else {
        print('ElevenLabsService: No alignment data in response');
        return {
          'audioPath': filePath,
          'timestamps': [],
        };
      }
    } catch (e) {
      print('Exception generating audio with timestamps: $e');
      return null;
    }
  }

  // Convert character-level timestamps to word-level timestamps
  List<Map<String, dynamic>> _convertCharacterTimesToWordTimes(String originalText, List<String> characters, List<double> startTimes, List<double> endTimes) {
    final wordTimestamps = <Map<String, dynamic>>[];
    final wordRegex = RegExp(r"[\w'']+");
    final matches = wordRegex.allMatches(originalText).toList();

    for (final match in matches) {
      final word = match.group(0)!;
      final wordStart = match.start;
      final wordEnd = match.end;

      // Find the character indices that correspond to this word
      int charStartIndex = -1;
      int charEndIndex = -1;

      // Map original text positions to character array positions
      int charArrayPos = 0;
      for (int textPos = 0; textPos < originalText.length && charArrayPos < characters.length; textPos++) {
        if (textPos == wordStart && charStartIndex == -1) {
          charStartIndex = charArrayPos;
        }
        if (textPos == wordEnd - 1 && charEndIndex == -1) {
          charEndIndex = charArrayPos;
        }

        // Only advance if the character matches (accounting for normalization)
        if (charArrayPos < characters.length && originalText[textPos].toLowerCase() == characters[charArrayPos].toLowerCase()) {
          charArrayPos++;
        }
      }

      // If we found valid character indices, extract timing
      if (charStartIndex >= 0 && charStartIndex < startTimes.length) {
        final wordStartTime = startTimes[charStartIndex];
        final wordEndTime = charEndIndex >= 0 && charEndIndex < endTimes.length ? endTimes[charEndIndex] : (charStartIndex < endTimes.length ? endTimes[charStartIndex] : wordStartTime + 0.1);

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

  // Save timestamp data to file
  Future<void> _saveTimestampData(int storyId, List<Map<String, dynamic>> timestamps, {String? voiceId}) async {
    try {
      final timestampPath = await _getTimestampFilePath(storyId, voiceId: voiceId);
      final file = File(timestampPath);
      await file.writeAsString(jsonEncode(timestamps));
      print('ElevenLabsService: Timestamp data saved to $timestampPath');
    } catch (e) {
      print('Error saving timestamp data: $e');
    }
  }

  // Load timestamp data from file
  Future<List<Map<String, dynamic>>> getTimestampData(int storyId, {String? voiceId}) async {
    try {
      final timestampPath = await _getTimestampFilePath(storyId, voiceId: voiceId);
      final file = File(timestampPath);

      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> data = jsonDecode(content);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('Error loading timestamp data: $e');
    }
    return [];
  }

  // Check if timestamp data exists for a story
  Future<bool> hasTimestampData(int storyId, {String? voiceId}) async {
    try {
      final timestampPath = await _getTimestampFilePath(storyId, voiceId: voiceId);
      final file = File(timestampPath);
      return await file.exists();
    } catch (e) {
      print('Error checking timestamp data: $e');
      return false;
    }
  }

  // Get timestamp file path
  Future<String> _getTimestampFilePath(int storyId, {String? voiceId}) async {
    final directory = await getApplicationDocumentsDirectory();
    final effectiveVoiceId = voiceId ?? _voiceId;
    return '${directory.path}/story_${storyId}_${effectiveVoiceId}_timestamps.json';
  }

  // Generate audio with custom voice settings
  Future<String?> generateAudioWithSettings(String text, int storyId, {String? voiceId, Map<String, dynamic>? voiceSettings}) async {
    print('======== ELEVENLABS SERVICE: GENERATE AUDIO WITH CUSTOM SETTINGS ========');
    print('Text length: ${text.length} characters');
    print('Text preview: "${text.substring(0, min(50, text.length))}${text.length > 50 ? '...' : ''}"');
    print('Story ID: $storyId');

    final effectiveVoiceId = voiceId ?? _voiceId;
    print('Voice ID: $effectiveVoiceId (${getVoiceNameById(effectiveVoiceId)})');

    if (voiceSettings != null) {
      print('Custom voice settings: $voiceSettings');
    }

    try {
      // Check if API key is available
      if (_apiKey == null || _apiKey == 'YOUR_ELEVENLABS_API_KEY_HERE') {
        print('⚠️ ElevenLabsService: No valid API key available. Creating placeholder file.');

        // Create placeholder file so the app doesn't keep trying to generate
        final filePath = await _getAudioFilePath(storyId, voiceId: effectiveVoiceId);
        print('Creating placeholder file at: $filePath');
        final file = File(filePath);
        if (!await file.exists()) {
          await file.create();
          print('Placeholder file created');
        } else {
          print('Placeholder file already exists');
        }

        return filePath;
      }

      print('🔄 Sending request to ElevenLabs API endpoint: $_baseUrl/text-to-speech/$effectiveVoiceId');
      print('Request parameters:');
      print('  - Model: eleven_multilingual_v2');

      if (voiceSettings != null) {
        print('  - Stability: ${voiceSettings['stability'] ?? 0.35}');
        print('  - Similarity boost: ${voiceSettings['similarity_boost'] ?? 1.00}');
        print('  - Speed: ${voiceSettings['speed'] ?? 'default'}');
      } else {
        print('  - Using default voice settings');
      }

      final stopwatch = Stopwatch()..start();

      // Set default voice settings if none provided
      final Map<String, dynamic> effectiveSettings = {
        'stability': 0.35,
        'similarity_boost': 1.00,
        'style': 0,
        'use_speaker_boost': true,
      };

      // Override with custom settings if provided
      if (voiceSettings != null) {
        effectiveSettings.addAll(voiceSettings);
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/text-to-speech/$effectiveVoiceId'),
        headers: {
          'Accept': 'audio/mpeg',
          'Content-Type': 'application/json',
          'xi-api-key': _apiKey!,
        },
        body: jsonEncode({
          'text': text,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': effectiveSettings,
        }),
      );

      final elapsed = stopwatch.elapsedMilliseconds;
      print('Response received in ${elapsed}ms');

      if (response.statusCode == 200) {
        print('✅ Success - Status code: ${response.statusCode}');
        print('Response content type: ${response.headers['content-type']}');
        print('Audio size: ${response.bodyBytes.length} bytes');

        final filePath = await _getAudioFilePath(storyId, voiceId: effectiveVoiceId);
        print('Saving audio to file: $filePath');

        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        print('Audio file saved successfully');
        print('======== ELEVENLABS SERVICE: AUDIO GENERATION COMPLETE ========');
        return filePath;
      } else {
        print('❌ Error - Status code: ${response.statusCode}');
        print('Error response: ${response.body.substring(0, min(200, response.body.length))}${response.body.length > 200 ? '...' : ''}');
        print('======== ELEVENLABS SERVICE: AUDIO GENERATION FAILED ========');
        return null;
      }
    } catch (e) {
      print('❌ Exception generating audio: $e');
      print('Stack trace: ${StackTrace.current}');
      print('======== ELEVENLABS SERVICE: ERROR ========');
      return null;
    }
  }
}
