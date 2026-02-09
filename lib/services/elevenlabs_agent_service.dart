import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'ai_proxy_config.dart';

class ElevenLabsAgentService {
  static const String _directSignedUrlEndpoint =
      'https://api.elevenlabs.io/v1/convai/conversation/get-signed-url';
  static const String _directLiveKitTokenEndpoint =
      'https://api.elevenlabs.io/v1/convai/conversation/token';
  static const String _publicWebSocketEndpoint =
      'wss://api.elevenlabs.io/v1/convai/conversation';
  static const String _proxySignedUrlPath = '/elevenlabs/convai/signed-url';
  static const String _proxyLiveKitTokenPath = '/elevenlabs/convai/token';

  final AiProxyConfig _proxyConfig;
  final String? _apiKey;
  final String? _agentId;
  final String? _overrideWebSocketUrl;
  final bool _useSignedUrl;

  ElevenLabsAgentService({
    AiProxyConfig? proxyConfig,
    String? apiKey,
    String? agentId,
    String? overrideWebSocketUrl,
    bool? useSignedUrl,
  })  : _proxyConfig = proxyConfig ?? AiProxyConfig.fromEnv(),
        _apiKey = (apiKey ?? dotenv.env['ELEVENLABS_API_KEY'])?.trim(),
        _agentId = (agentId ?? dotenv.env['ELEVENLABS_AGENT_ID'])?.trim(),
        _overrideWebSocketUrl = (overrideWebSocketUrl ??
                dotenv.env['ELEVENLABS_AGENT_WEBSOCKET_URL'])
            ?.trim(),
        _useSignedUrl = useSignedUrl ??
            _parseBool(
              dotenv.env['ELEVENLABS_AGENT_USE_SIGNED_URL'],
              defaultValue: true,
            );

  String? get agentId => _agentId;

  bool get hasAgentId => _agentId != null && _agentId!.isNotEmpty;

  bool get isConfigured =>
      _normalizeWebSocketUrl(_overrideWebSocketUrl) != null || hasAgentId;

  Future<String?> resolveConversationWebSocketUrl({
    AiRequestContext? requestContext,
  }) async {
    final override = _normalizeWebSocketUrl(_overrideWebSocketUrl);
    if (override != null) {
      return override;
    }

    if (!hasAgentId) {
      return null;
    }

    if (!_useSignedUrl) {
      return Uri.parse(_publicWebSocketEndpoint)
          .replace(queryParameters: {'agent_id': _agentId}).toString();
    }

    final proxied = await _resolveSignedUrlViaProxy(requestContext);
    if (proxied != null) {
      return proxied;
    }

    final direct = await _resolveSignedUrlDirect();
    if (direct != null) {
      return direct;
    }

    return null;
  }

  Future<String?> resolveConversationToken({
    AiRequestContext? requestContext,
  }) async {
    if (!hasAgentId) return null;

    final proxied = await _resolveLiveKitTokenViaProxy(requestContext);
    if (proxied != null) {
      return proxied;
    }

    final direct = await _resolveLiveKitTokenDirect();
    if (direct != null) {
      return direct;
    }

    return null;
  }

  Future<String?> _resolveLiveKitTokenViaProxy(
    AiRequestContext? requestContext,
  ) async {
    if (!_proxyConfig.hasProxy || !hasAgentId) {
      return null;
    }

    try {
      final uri = _proxyConfig
          .proxyUri(_proxyLiveKitTokenPath)
          .replace(queryParameters: {'agent_id': _agentId});
      final headers = _proxyConfig.proxyHeaders(
        requestContext: requestContext,
      );
      final response = await http.get(uri, headers: headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return _extractLiveKitToken(response.body);
    } catch (e) {
      debugPrint('Proxy ElevenLabs LiveKit token request failed: $e');
      return null;
    }
  }

  Future<String?> _resolveLiveKitTokenDirect() async {
    if (!_canCallDirectProvider || !hasAgentId) {
      return null;
    }

    try {
      final uri = Uri.parse(_directLiveKitTokenEndpoint)
          .replace(queryParameters: {'agent_id': _agentId});
      final response = await http.get(
        uri,
        headers: {
          'xi-api-key': _apiKey!,
          'Accept': 'application/json',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return _extractLiveKitToken(response.body);
    } catch (e) {
      debugPrint('Direct ElevenLabs LiveKit token request failed: $e');
      return null;
    }
  }

  String? _extractLiveKitToken(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final candidates = [
        decoded['token']?.toString(),
        decoded['conversation_token']?.toString(),
      ];
      for (final candidate in candidates) {
        if (candidate != null && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<String?> _resolveSignedUrlViaProxy(
    AiRequestContext? requestContext,
  ) async {
    if (!_proxyConfig.hasProxy || !hasAgentId) {
      return null;
    }

    try {
      final uri = _proxyConfig
          .proxyUri(_proxySignedUrlPath)
          .replace(queryParameters: {'agent_id': _agentId});
      final headers = _proxyConfig.proxyHeaders(
        requestContext: requestContext,
      );
      final response = await http.get(uri, headers: headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return _extractSignedWebSocketUrl(response.body);
    } catch (e) {
      debugPrint('Proxy ElevenLabs signed URL request failed: $e');
      return null;
    }
  }

  Future<String?> _resolveSignedUrlDirect() async {
    if (!_canCallDirectProvider || !hasAgentId) {
      return null;
    }

    try {
      final uri = Uri.parse(_directSignedUrlEndpoint)
          .replace(queryParameters: {'agent_id': _agentId});
      final response = await http.get(
        uri,
        headers: {
          'xi-api-key': _apiKey!,
          'Accept': 'application/json',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return _extractSignedWebSocketUrl(response.body);
    } catch (e) {
      debugPrint('Direct ElevenLabs signed URL request failed: $e');
      return null;
    }
  }

  String? _extractSignedWebSocketUrl(String body) {
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
        final normalized = _normalizeWebSocketUrl(candidate);
        if (normalized != null) {
          return normalized;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String? _normalizeWebSocketUrl(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    var uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      uri = uri.replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws');
    }
    if (uri.scheme != 'ws' && uri.scheme != 'wss') {
      return null;
    }
    if (uri.fragment.isNotEmpty) {
      uri = uri.replace(fragment: '');
    }
    return uri.toString();
  }

  bool get _canCallDirectProvider {
    final hasKey = _apiKey != null && _apiKey!.isNotEmpty;
    if (!hasKey) return false;
    if (!_proxyConfig.allowDirectFallback) return false;
    if (_proxyConfig.requireProxy && kReleaseMode) return false;
    return true;
  }

  static bool _parseBool(String? raw, {required bool defaultValue}) {
    if (raw == null) return defaultValue;
    switch (raw.trim().toLowerCase()) {
      case '1':
      case 'true':
      case 'yes':
      case 'on':
        return true;
      case '0':
      case 'false':
      case 'no':
      case 'off':
        return false;
      default:
        return defaultValue;
    }
  }
}
