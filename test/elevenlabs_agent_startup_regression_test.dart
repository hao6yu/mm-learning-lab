import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('voice conversation screen starts ElevenLabs session with agentId only',
      () {
    final source = File(
      'lib/screens/elevenlabs_agent_voice_conversation_screen.dart',
    ).readAsStringSync();

    final startSessionCall = RegExp(
      r'startSession\s*\([\s\S]*?agentId\s*:\s*agentId',
      multiLine: true,
    );
    expect(
      startSessionCall.hasMatch(source),
      isTrue,
      reason: 'Expected startSession to pass agentId in startup path.',
    );

    expect(
      source.contains('conversationToken:'),
      isFalse,
      reason: 'conversationToken path should not be used in startup anymore.',
    );
  });

  test('agent service does not expose token-based startup resolver', () {
    final source =
        File('lib/services/elevenlabs_agent_service.dart').readAsStringSync();

    expect(
      source.contains('resolveConversationToken'),
      isFalse,
      reason: 'Token-based resolver should remain removed after migration.',
    );
  });
}
