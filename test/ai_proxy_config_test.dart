import 'package:flutter_test/flutter_test.dart';
import 'package:mm_learning_lab/services/ai_proxy_config.dart';

void main() {
  const config = AiProxyConfig(
    baseUrl: 'https://proxy.example.com',
    token: 'proxy-token',
    requireProxy: true,
    allowDirectFallback: false,
  );

  test('proxy headers include explicit request context', () {
    const requestContext = AiRequestContext(
      profileId: 7,
      isPremium: false,
      feature: 'chat_message',
      units: 2,
      callReserveSeconds: 180,
    );

    final headers = config.proxyHeaders(requestContext: requestContext);
    expect(headers['X-Child-Profile-Id'], '7');
    expect(headers['X-User-Tier'], 'free');
    expect(headers['X-AI-Feature'], 'chat_message');
    expect(headers['X-AI-Units'], '2');
    expect(headers['X-AI-Call-Reserve-Seconds'], '180');
  });

  test('proxy headers do not include runtime ai context when omitted', () {
    final headers = config.proxyHeaders();
    expect(headers.containsKey('X-Child-Profile-Id'), isFalse);
    expect(headers.containsKey('X-User-Tier'), isFalse);
    expect(headers.containsKey('X-AI-Feature'), isFalse);
    expect(headers.containsKey('X-AI-Units'), isFalse);
    expect(headers.containsKey('X-AI-Call-Reserve-Seconds'), isFalse);
  });
}
