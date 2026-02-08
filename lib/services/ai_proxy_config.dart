import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  static int? _runtimeProfileId;
  static String? _runtimeTier;
  static String? _runtimeFeature;
  static int? _runtimeUnits;
  static int? _runtimeCallReserveSeconds;

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

  Map<String, String> proxyHeaders({bool json = true}) {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
      headers['Accept'] = 'application/json';
    }
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      headers['X-Proxy-Token'] = token!;
    }
    if (_runtimeProfileId != null) {
      headers['X-Child-Profile-Id'] = _runtimeProfileId.toString();
    }
    if (_runtimeTier != null && _runtimeTier!.isNotEmpty) {
      headers['X-User-Tier'] = _runtimeTier!;
    }
    if (_runtimeFeature != null && _runtimeFeature!.isNotEmpty) {
      headers['X-AI-Feature'] = _runtimeFeature!;
    }
    if (_runtimeUnits != null && _runtimeUnits! > 0) {
      headers['X-AI-Units'] = _runtimeUnits.toString();
    }
    if (_runtimeCallReserveSeconds != null && _runtimeCallReserveSeconds! > 0) {
      headers['X-AI-Call-Reserve-Seconds'] =
          _runtimeCallReserveSeconds.toString();
    }
    return headers;
  }

  static void setRequestContext({
    required int profileId,
    required bool isPremium,
    required String feature,
    int units = 1,
    int? callReserveSeconds,
  }) {
    _runtimeProfileId = profileId;
    _runtimeTier = isPremium ? 'premium' : 'free';
    _runtimeFeature = feature;
    _runtimeUnits = units;
    _runtimeCallReserveSeconds = callReserveSeconds;
  }

  static void clearRequestContext() {
    _runtimeProfileId = null;
    _runtimeTier = null;
    _runtimeFeature = null;
    _runtimeUnits = null;
    _runtimeCallReserveSeconds = null;
  }

  static Future<T> withRequestContext<T>({
    required int profileId,
    required bool isPremium,
    required String feature,
    int units = 1,
    int? callReserveSeconds,
    required Future<T> Function() action,
  }) async {
    final previousProfileId = _runtimeProfileId;
    final previousTier = _runtimeTier;
    final previousFeature = _runtimeFeature;
    final previousUnits = _runtimeUnits;
    final previousCallReserveSeconds = _runtimeCallReserveSeconds;

    setRequestContext(
      profileId: profileId,
      isPremium: isPremium,
      feature: feature,
      units: units,
      callReserveSeconds: callReserveSeconds,
    );

    try {
      return await action();
    } finally {
      _runtimeProfileId = previousProfileId;
      _runtimeTier = previousTier;
      _runtimeFeature = previousFeature;
      _runtimeUnits = previousUnits;
      _runtimeCallReserveSeconds = previousCallReserveSeconds;
    }
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
