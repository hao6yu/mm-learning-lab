import 'package:flutter_test/flutter_test.dart';
import 'package:mm_learning_lab/services/ai_proxy_config.dart';

void main() {
  const config = AiProxyConfig(
    baseUrl: 'https://proxy.example.com',
    token: 'proxy-token',
    requireProxy: true,
    allowDirectFallback: false,
  );

  setUp(() {
    AiProxyConfig.clearRequestContext();
  });

  test('proxy headers include runtime request context', () {
    AiProxyConfig.setRequestContext(
      profileId: 7,
      isPremium: false,
      feature: 'chat_message',
      units: 2,
      callReserveSeconds: 180,
    );

    final headers = config.proxyHeaders();
    expect(headers['X-Child-Profile-Id'], '7');
    expect(headers['X-User-Tier'], 'free');
    expect(headers['X-AI-Feature'], 'chat_message');
    expect(headers['X-AI-Units'], '2');
    expect(headers['X-AI-Call-Reserve-Seconds'], '180');
  });

  test('withRequestContext restores previous context after action', () async {
    AiProxyConfig.setRequestContext(
      profileId: 1,
      isPremium: true,
      feature: 'voice_call',
      units: 1,
      callReserveSeconds: 600,
    );

    await AiProxyConfig.withRequestContext(
      profileId: 2,
      isPremium: false,
      feature: 'story_generation',
      units: 3,
      callReserveSeconds: 120,
      action: () async {
        final scopedHeaders = config.proxyHeaders();
        expect(scopedHeaders['X-Child-Profile-Id'], '2');
        expect(scopedHeaders['X-User-Tier'], 'free');
        expect(scopedHeaders['X-AI-Feature'], 'story_generation');
      },
    );

    final restoredHeaders = config.proxyHeaders();
    expect(restoredHeaders['X-Child-Profile-Id'], '1');
    expect(restoredHeaders['X-User-Tier'], 'premium');
    expect(restoredHeaders['X-AI-Feature'], 'voice_call');
    expect(restoredHeaders['X-AI-Call-Reserve-Seconds'], '600');
  });
}
