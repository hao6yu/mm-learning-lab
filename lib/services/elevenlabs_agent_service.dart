import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

enum ElevenLabsVoicePreset {
  male,
  female,
}

/// Service for managing ElevenLabs Conversational AI Agent connections.
///
/// This follows the stable `agentId` call path used by howai-agent:
/// `ConversationClient.startSession(agentId: ...)`.
class ElevenLabsAgentService {
  static const String _directLiveKitTokenEndpoint =
      'https://api.elevenlabs.io/v1/convai/conversation/get-signed-url';

  final String? _apiKey;
  final String? _legacyAgentId;
  final String? _maleAgentId;
  final String? _femaleAgentId;

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final normalized = value?.trim();
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  ElevenLabsAgentService({
    String? apiKey,
    String? agentId,
    String? maleAgentId,
    String? femaleAgentId,
  })  : _apiKey = _firstNonEmpty([
          apiKey,
          dotenv.env['ELEVENLABS_API_KEY'],
          dotenv.env['XI_API_KEY'],
        ]),
        _legacyAgentId = _firstNonEmpty([
          agentId,
          dotenv.env['ELEVENLABS_AGENT_ID'],
          dotenv.env['ELEVENLABS_CONVAI_AGENT_ID'],
          dotenv.env['ELEVENLABS_CONVERSATIONAL_AGENT_ID'],
          dotenv.env['ELEVENLABS_CONVERSATIONAL_AI_AGENT_ID'],
        ]),
        _maleAgentId = _firstNonEmpty([
          maleAgentId,
          dotenv.env['ELEVENLABS_AGENT_ID_MALE'],
          dotenv.env['ELEVENLABS_MALE_AGENT_ID'],
        ]),
        _femaleAgentId = _firstNonEmpty([
          femaleAgentId,
          dotenv.env['ELEVENLABS_AGENT_ID_FEMALE'],
          dotenv.env['ELEVENLABS_FEMALE_AGENT_ID'],
        ]);

  bool get _hasAnyVoiceSpecificAgent =>
      _maleAgentId != null || _femaleAgentId != null;

  String? _voiceSpecificAgentId(ElevenLabsVoicePreset voice) {
    return switch (voice) {
      ElevenLabsVoicePreset.male => _maleAgentId,
      ElevenLabsVoicePreset.female => _femaleAgentId,
    };
  }

  /// The configured default agent ID (for backwards compatibility).
  ///
  /// For voice-specific selection, use [agentIdForVoice].
  String? get agentId => agentIdForVoice(voice: ElevenLabsVoicePreset.male);

  /// Agent ID resolved for a given voice.
  ///
  /// Resolution order:
  /// 1) voice-specific env var (`_MALE` / `_FEMALE`)
  /// 2) legacy single-agent env var (`ELEVENLABS_AGENT_ID`) only when no
  ///    voice-specific IDs are configured at all.
  String? agentIdForVoice({required ElevenLabsVoicePreset voice}) {
    final specific = _voiceSpecificAgentId(voice);
    if (specific != null) return specific;

    // When one of the new keys is present, require explicit config per voice.
    if (_hasAnyVoiceSpecificAgent) return null;

    return _legacyAgentId;
  }

  /// Whether the chosen voice has a usable agent configuration.
  bool isConfiguredForVoice({required ElevenLabsVoicePreset voice}) =>
      agentIdForVoice(voice: voice) != null;

  /// Whether any voice call agent is configured.
  bool get hasAgentId =>
      isConfiguredForVoice(voice: ElevenLabsVoicePreset.male) ||
      isConfiguredForVoice(voice: ElevenLabsVoicePreset.female);

  /// Whether an ElevenLabs API key is configured.
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  /// Whether the service is properly configured for voice calls.
  ///
  /// The SDK call path in this app only requires `agentId`.
  bool get isConfigured => hasAgentId;

  /// Human-readable missing configuration summary for debugging.
  String? get configurationIssue {
    if (!hasAgentId) {
      return 'Missing agent id (ELEVENLABS_AGENT_ID or ELEVENLABS_AGENT_ID_MALE/FEMALE)';
    }
    return null;
  }

  String? configurationIssueForVoice({required ElevenLabsVoicePreset voice}) {
    if (isConfiguredForVoice(voice: voice)) return null;

    if (_hasAnyVoiceSpecificAgent) {
      return switch (voice) {
        ElevenLabsVoicePreset.male =>
          'Missing male agent id (ELEVENLABS_AGENT_ID_MALE)',
        ElevenLabsVoicePreset.female =>
          'Missing female agent id (ELEVENLABS_AGENT_ID_FEMALE)',
      };
    }

    return 'Missing agent id (ELEVENLABS_AGENT_ID)';
  }

  /// Resolve a signed URL for connecting to the ElevenLabs agent.
  ///
  /// Returns a signed WebSocket URL that can be used with the SDK,
  /// or null if resolution fails.
  Future<String?> resolveSignedUrl({
    ElevenLabsVoicePreset voice = ElevenLabsVoicePreset.male,
    String? agentId,
  }) async {
    final resolvedAgentId =
        _firstNonEmpty([agentId, agentIdForVoice(voice: voice)]);
    if (resolvedAgentId == null || !hasApiKey) {
      debugPrint(
          'ElevenLabsAgentService: Not configured for signed URL (missing API key or agent ID)');
      return null;
    }

    try {
      final uri = Uri.parse(_directLiveKitTokenEndpoint)
          .replace(queryParameters: {'agent_id': resolvedAgentId});

      final response = await http.get(
        uri,
        headers: {
          'xi-api-key': _apiKey!,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
            'ElevenLabsAgentService: Failed to get signed URL - ${response.statusCode}');
        return null;
      }

      return _extractSignedUrl(response.body);
    } catch (e) {
      debugPrint('ElevenLabsAgentService: Error resolving signed URL - $e');
      return null;
    }
  }

  String? _extractSignedUrl(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final candidates = [
        decoded['signed_url']?.toString(),
        decoded['websocket_url']?.toString(),
        decoded['url']?.toString(),
      ];

      for (final candidate in candidates) {
        if (candidate != null && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }
    } catch (e) {
      debugPrint(
          'ElevenLabsAgentService: Error parsing signed URL response - $e');
    }
    return null;
  }
}
