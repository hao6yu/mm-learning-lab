import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiRequestContext {
  final int profileId;
  final bool isPremium;
  final String feature;
  final int units;
  final int? callReserveSeconds;

  const AiRequestContext({
    required this.profileId,
    required this.isPremium,
    required this.feature,
    this.units = 1,
    this.callReserveSeconds,
  });
}

class AiProxyConfig {
  final String? baseUrl;
  final String? token;
  final bool requireProxy;
  final bool allowDirectFallback;

  const AiProxyConfig({
    required this.baseUrl,
    required this.token,
    required this.requireProxy,
    required this.allowDirectFallback,
  });

  factory AiProxyConfig.fromEnv() {
    final baseUrl = dotenv.env['AI_PROXY_BASE_URL']?.trim();
    final token = dotenv.env['AI_PROXY_TOKEN']?.trim();
    final requireProxy = _parseBool(
      dotenv.env['AI_PROXY_REQUIRED'],
      defaultValue: kReleaseMode,
    );
    final allowDirectFallback = _parseBool(
      dotenv.env['AI_ALLOW_DIRECT_FALLBACK'],
      defaultValue: !kReleaseMode,
    );

    return AiProxyConfig(
      baseUrl: (baseUrl == null || baseUrl.isEmpty) ? null : baseUrl,
      token: (token == null || token.isEmpty) ? null : token,
      requireProxy: requireProxy,
      allowDirectFallback: allowDirectFallback,
    );
  }

  bool get hasProxy => baseUrl != null && baseUrl!.isNotEmpty;

  Uri proxyUri(String endpointPath) {
    final normalizedBase = (baseUrl ?? '').replaceAll(RegExp(r'/+$'), '');
    final normalizedPath =
        endpointPath.startsWith('/') ? endpointPath : '/$endpointPath';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  Map<String, String> proxyHeaders({
    bool json = true,
    AiRequestContext? requestContext,
  }) {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
      headers['Accept'] = 'application/json';
    }
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      headers['X-Proxy-Token'] = token!;
    }
    if (requestContext != null) {
      headers['X-Child-Profile-Id'] = requestContext.profileId.toString();
      headers['X-User-Tier'] = requestContext.isPremium ? 'premium' : 'free';
      headers['X-AI-Feature'] = requestContext.feature;
      if (requestContext.units > 0) {
        headers['X-AI-Units'] = requestContext.units.toString();
      }
      if (requestContext.callReserveSeconds != null &&
          requestContext.callReserveSeconds! > 0) {
        headers['X-AI-Call-Reserve-Seconds'] =
            requestContext.callReserveSeconds.toString();
      }
    }
    return headers;
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
