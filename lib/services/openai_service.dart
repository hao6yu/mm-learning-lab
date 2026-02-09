import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'ai_proxy_config.dart';

class OpenAIService {
  static const String _directResponsesUrl =
      'https://api.openai.com/v1/responses';
  static const String _directChatCompletionsUrl =
      'https://api.openai.com/v1/chat/completions';
  static const String _directAudioTranscriptionUrl =
      'https://api.openai.com/v1/audio/transcriptions';

  static const String _proxyResponsesPath = '/openai/responses';
  static const String _proxyChatCompletionsPath = '/openai/chat/completions';
  static const String _proxyAudioTranscriptionPath =
      '/openai/audio/transcriptions';

  static String? _apiKey;
  static String _chatModel = 'gpt-5-mini';
  static String _chatMiniModel = 'gpt-5-nano';
  static AiProxyConfig _proxyConfig = AiProxyConfig(
    baseUrl: null,
    token: null,
    requireProxy: kReleaseMode,
    allowDirectFallback: !kReleaseMode,
  );

  static const Map<String, String> agePrompts = {
    'young':
        'Write a very short, simple story for a 3-6 year old child with basic vocabulary and short sentences. The story should be educational, positive, and engaging for very young children.',
    'middle':
        'Write a short story for a 7-9 year old child with age-appropriate vocabulary. Include a small challenge or lesson that is resolved positively.',
    'older':
        'Write a story for a 10-12 year old that is engaging and includes more complex vocabulary but is still age-appropriate. The story can have a bit more complexity in plot.',
  };

  static const Map<String, String> categoryPrompts = {
    'Adventure': 'an exciting adventure with exploration and discovery',
    'Animals': 'a story featuring friendly animals as main characters',
    'Space': 'a story about space, planets, or astronauts',
    'Fantasy': 'a magical fantasy story with light fantasy elements',
    'Nature': 'a story about nature, plants, weather, or the environment',
  };

  static const Map<String, String> difficultyPrompts = {
    'Easy': 'Use simple words and short sentences for early readers.',
    'Medium':
        'Use moderate vocabulary with some challenging words but mostly straightforward language.',
    'Hard':
        'Include some advanced vocabulary words that help build reading skills, but still keep the content age-appropriate.',
  };

  static Future<void> initialize({String? apiKey}) async {
    _apiKey = apiKey ?? dotenv.env['OPENAI_API_KEY'];
    _chatModel = _normalizeModelId(
      dotenv.env['OPENAI_CHAT_MODEL'],
      fallback: 'gpt-5-mini',
    );
    _chatMiniModel = _normalizeModelId(
      dotenv.env['OPENAI_CHAT_MINI_MODEL'],
      fallback: 'gpt-5-nano',
    );
    _proxyConfig = AiProxyConfig.fromEnv();

    if (_proxyConfig.hasProxy) {
      debugPrint('OpenAIService configured for proxy: ${_proxyConfig.baseUrl}');
    } else {
      debugPrint('OpenAIService proxy is not configured.');
    }

    if (!_canCallDirectProvider) {
      debugPrint(
          'OpenAIService direct-provider fallback is disabled or unavailable.');
    }
  }

  Future<Map<String, dynamic>?> generateStory({
    String? ageGroup = 'middle',
    String? prompt,
    AiRequestContext? requestContext,
  }) async {
    final systemPrompt = """
You are a creative children's story writer who creates age-appropriate stories that are positive, educational, and engaging.
Create a story with the following structure:
1. Title: Should be fun and catchy
2. Category: Choose one from [Adventure, Animals, Space, Fantasy, Nature]
3. Difficulty: Choose one from [Easy, Medium, Hard]
4. Emoji: Select a single emoji that best represents the story theme
5. Content: The actual story text

${agePrompts[ageGroup ?? 'middle']}

The story should be under 500 words, have a clear beginning, middle, and end, and include a positive message.
Absolutely NO scary, violent, upsetting or inappropriate content. Keep it educational and wholesome.

Output ONLY in this exact JSON format:
{
  "title": "Story Title",
  "category": "Category",
  "difficulty": "Difficulty",
  "emoji": "🔍",
  "content": "The story content..."
}
""";

    final userPrompt =
        prompt ?? 'Please create a fun, educational story for children.';

    final result = await _generateTextWithFallback(
      purpose: 'generate story',
      responsesBody: {
        'model': _chatModel,
        'instructions': systemPrompt,
        'input': userPrompt,
        'max_output_tokens': 1200,
        'reasoning': {'effort': 'minimal'},
        'text': {
          'verbosity': 'low',
          'format': {
            'type': 'json_schema',
            'name': 'kids_story',
            'strict': true,
            'schema': {
              'type': 'object',
              'additionalProperties': false,
              'properties': {
                'title': {'type': 'string'},
                'category': {
                  'type': 'string',
                  'enum': [
                    'Adventure',
                    'Animals',
                    'Space',
                    'Fantasy',
                    'Nature'
                  ],
                },
                'difficulty': {
                  'type': 'string',
                  'enum': ['Easy', 'Medium', 'Hard'],
                },
                'emoji': {'type': 'string'},
                'content': {'type': 'string'},
              },
              'required': [
                'title',
                'category',
                'difficulty',
                'emoji',
                'content'
              ],
            },
          },
        },
      },
      chatCompletionsFallbackBody: {
        'model': _chatModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'max_completion_tokens': 900,
        'response_format': {'type': 'json_object'},
      },
      requestContext: requestContext,
    );

    if (result == null) return null;
    return _extractJsonObjectFromText(result.text);
  }

  Future<String?> generateStoryFromTitle({
    required String title,
    String? category,
    String? difficulty,
    String? ageGroup = 'middle',
    AiRequestContext? requestContext,
  }) async {
    final systemPrompt = """
You are a creative children's story writer who creates age-appropriate stories that are positive, educational, and engaging.
${agePrompts[ageGroup ?? 'middle']}
${category != null ? 'The story should be ${categoryPrompts[category] ?? "engaging and creative"}.' : ''}
${difficulty != null ? difficultyPrompts[difficulty] ?? '' : ''}

Write a story with the title: "$title"

The story should be under 500 words, have a clear beginning, middle, and end, and include a positive message.
Absolutely NO scary, violent, upsetting or inappropriate content. Keep it educational and wholesome.
""";

    final result = await _generateTextWithFallback(
      purpose: 'generate story from title',
      responsesBody: {
        'model': _chatMiniModel,
        'instructions': systemPrompt,
        'input':
            'Please create a story titled "$title" that is fun and educational for children.',
        'max_output_tokens': 700,
        'reasoning': {'effort': 'low'},
        'text': {'verbosity': 'medium'},
      },
      chatCompletionsFallbackBody: {
        'model': _chatMiniModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content':
                'Please create a story titled "$title" that is fun and educational for children.',
          },
        ],
        'max_completion_tokens': 700,
      },
      requestContext: requestContext,
    );

    return result?.text;
  }

  Future<String?> generateTitleSuggestion({
    required String theme,
    String? category,
    String? ageGroup = 'middle',
    AiRequestContext? requestContext,
  }) async {
    final systemPrompt = """
Generate a fun, catchy, and age-appropriate title for a children's story about: $theme
${category != null ? 'The story is in the $category category.' : ''}
${agePrompts[ageGroup ?? 'middle']}

The title should be:
- Short (2-8 words)
- Engaging
- Age-appropriate
- Creative

Return ONLY the title text with no explanation or other text.
""";

    final result = await _generateTextWithFallback(
      purpose: 'generate title suggestion',
      responsesBody: {
        'model': _chatMiniModel,
        'instructions': systemPrompt,
        'input': "Generate a catchy title for a children's story about: $theme",
        'max_output_tokens': 40,
        'reasoning': {'effort': 'minimal'},
        'text': {'verbosity': 'low'},
      },
      chatCompletionsFallbackBody: {
        'model': _chatMiniModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content':
                "Generate a catchy title for a children's story about: $theme",
          },
        ],
        'max_completion_tokens': 40,
      },
      requestContext: requestContext,
    );

    return result?.text.trim();
  }

  Future<String?> generateChatResponse({
    required String message,
    required List<Map<String, String>> history,
    String? childName,
    int? childAge,
    String assistantName = 'Aria',
    AiRequestContext? requestContext,
  }) async {
    final systemPrompt = """
You are a friendly, educational AI assistant for children.
Your name is $assistantName.
${childName != null ? "The child's name is $childName." : ''}
${childAge != null ? 'The child is $childAge years old.' : ''}

Important identity rules:
- Never say your name is the child name.
- Never roleplay as the child.
- Always refer to yourself as $assistantName.

Your responses should be:
1. Short and simple (1-3 sentences for younger children, 3-5 for older)
2. Educational and factually accurate
3. Positive and encouraging
4. Age-appropriate vocabulary
5. Creative and engaging for children

When asked to explain concepts:
- Use simple analogies
- Relate to everyday things children know
- Be fun and playful in your explanations
- Include interesting facts

If asked about sensitive topics, redirect gently to age-appropriate content.
Avoid scary, violent, or overly complex explanations.

NEVER provide any content that would be inappropriate for children.
""";

    final responseInput = <Map<String, dynamic>>[
      ...history
          .map(
        (msg) => _responsesInputItem(
          role: _normalizeResponseRole(msg['role']),
          text: msg['content'] ?? '',
        ),
      )
          .where((item) {
        final content = item['content'];
        if (content is! List || content.isEmpty) return false;
        final first = content.first;
        if (first is! Map<String, dynamic>) return false;
        return (first['text']?.toString().trim().isNotEmpty ?? false);
      }),
      _responsesInputItem(role: 'user', text: message),
    ];

    final fallbackMessages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...history,
      {'role': 'user', 'content': message},
    ];

    final result = await _generateTextWithFallback(
      purpose: 'generate chat response',
      responsesBody: {
        'model': _chatMiniModel,
        'instructions': systemPrompt,
        'input': responseInput,
        'max_output_tokens': 250,
        'reasoning': {'effort': 'minimal'},
        'text': {'verbosity': 'low'},
      },
      chatCompletionsFallbackBody: {
        'model': _chatMiniModel,
        'messages': fallbackMessages,
        'max_completion_tokens': 250,
        'reasoning_effort': 'minimal',
      },
      requestContext: requestContext,
    );

    return result?.text;
  }

  Future<String?> transcribeAudio(List<int> audioBytes,
      {String? language, AiRequestContext? requestContext}) async {
    final proxyResponse = await _transcribeViaProxy(
      audioBytes: audioBytes,
      language: language,
      requestContext: requestContext,
    );
    if (proxyResponse != null) {
      return proxyResponse;
    }

    if (!_canCallDirectProvider) {
      return null;
    }
    return _transcribeViaDirect(audioBytes: audioBytes, language: language);
  }

  Future<_TextGenResult?> _generateTextWithFallback({
    required String purpose,
    required Map<String, dynamic> responsesBody,
    required Map<String, dynamic> chatCompletionsFallbackBody,
    AiRequestContext? requestContext,
  }) async {
    final responsesResponse = await _postResponses(
      body: responsesBody,
      purpose: purpose,
      requestContext: requestContext,
    );
    if (responsesResponse != null) {
      final data = _decodeJsonObject(responsesResponse.body);
      if (data != null) {
        final text = _extractResponsesText(data);
        if (text != null && text.trim().isNotEmpty) {
          return _TextGenResult(
            text: text.trim(),
            api: 'responses',
            raw: data,
          );
        }
        debugPrint(
          'OpenAIService responses returned empty text for "$purpose": '
          'status=${data['status'] ?? 'unknown'} incomplete=${data['incomplete_details'] ?? 'none'}',
        );
      }
    }

    final fallbackResponse = await _postChatCompletionsFallback(
      body: chatCompletionsFallbackBody,
      purpose: '$purpose (legacy fallback)',
      requestContext: requestContext,
    );
    if (fallbackResponse == null) return null;

    final fallbackData = _decodeJsonObject(fallbackResponse.body);
    if (fallbackData == null) return null;

    final fallbackText = _extractChatCompletionsText(fallbackData);
    if (fallbackText == null || fallbackText.trim().isEmpty) {
      debugPrint(
        'OpenAIService chat completions fallback returned empty text for "$purpose".',
      );
      return null;
    }

    return _TextGenResult(
      text: fallbackText.trim(),
      api: 'chat_completions_fallback',
      raw: fallbackData,
    );
  }

  Future<http.Response?> _postResponses({
    required Map<String, dynamic> body,
    required String purpose,
    AiRequestContext? requestContext,
  }) async {
    if (_proxyConfig.hasProxy) {
      try {
        final response = await http.post(
          _proxyConfig.proxyUri(_proxyResponsesPath),
          headers: _proxyConfig.proxyHeaders(requestContext: requestContext),
          body: jsonEncode(body),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }
        _debugLogHttpFailure(
          api: 'responses',
          mode: 'proxy',
          statusCode: response.statusCode,
          body: response.body,
        );
      } catch (_) {}

      if (!_canCallDirectProvider) {
        return null;
      }
    } else {
      if (_proxyConfig.requireProxy && !_canCallDirectProvider) {
        debugPrint(
            'OpenAIService blocked for "$purpose": proxy required but not configured.');
        return null;
      }
      if (!_canCallDirectProvider) {
        return null;
      }
    }

    try {
      final response = await http.post(
        Uri.parse(_directResponsesUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      _debugLogHttpFailure(
        api: 'responses',
        mode: 'direct',
        statusCode: response.statusCode,
        body: response.body,
      );
    } catch (_) {}
    return null;
  }

  Future<http.Response?> _postChatCompletionsFallback({
    required Map<String, dynamic> body,
    required String purpose,
    AiRequestContext? requestContext,
  }) async {
    if (_proxyConfig.hasProxy) {
      try {
        final response = await http.post(
          _proxyConfig.proxyUri(_proxyChatCompletionsPath),
          headers: _proxyConfig.proxyHeaders(requestContext: requestContext),
          body: jsonEncode(body),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }
        _debugLogHttpFailure(
          api: 'chat_completions_fallback',
          mode: 'proxy',
          statusCode: response.statusCode,
          body: response.body,
        );
      } catch (_) {}

      if (!_canCallDirectProvider) {
        return null;
      }
    } else {
      if (_proxyConfig.requireProxy && !_canCallDirectProvider) {
        debugPrint(
            'OpenAIService blocked for "$purpose": proxy required but not configured.');
        return null;
      }
      if (!_canCallDirectProvider) {
        return null;
      }
    }

    try {
      final response = await http.post(
        Uri.parse(_directChatCompletionsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      _debugLogHttpFailure(
        api: 'chat_completions_fallback',
        mode: 'direct',
        statusCode: response.statusCode,
        body: response.body,
      );
    } catch (_) {}
    return null;
  }

  Future<String?> _transcribeViaProxy({
    required List<int> audioBytes,
    String? language,
    AiRequestContext? requestContext,
  }) async {
    if (!_proxyConfig.hasProxy) {
      return null;
    }
    try {
      final request = http.MultipartRequest(
        'POST',
        _proxyConfig.proxyUri(_proxyAudioTranscriptionPath),
      );
      request.headers.addAll(
        _proxyConfig.proxyHeaders(
          json: false,
          requestContext: requestContext,
        ),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          audioBytes,
          filename: 'audio.webm',
        ),
      );
      request.fields['model'] = 'whisper-1';
      if (language != null && language.isNotEmpty) {
        request.fields['language'] = language;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return data['text'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _transcribeViaDirect({
    required List<int> audioBytes,
    String? language,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return null;
    }
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(_directAudioTranscriptionUrl),
      );
      request.headers['Authorization'] = 'Bearer $_apiKey';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          audioBytes,
          filename: 'audio.webm',
        ),
      );
      request.fields['model'] = 'whisper-1';
      if (language != null && language.isNotEmpty) {
        request.fields['language'] = language;
      }
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return data['text'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic>? _decodeJsonObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  String? _extractResponsesText(Map<String, dynamic> data) {
    final outputText = data['output_text'];
    if (outputText is String && outputText.trim().isNotEmpty) {
      return outputText;
    }

    final output = data['output'];
    if (output is! List) return null;

    final buffer = StringBuffer();
    for (final item in output) {
      if (item is! Map<String, dynamic>) continue;
      final content = item['content'];
      if (content is! List) continue;

      for (final part in content) {
        if (part is! Map<String, dynamic>) continue;
        final type = part['type']?.toString();
        if (type == 'output_text' || type == 'text' || type == 'message_text') {
          final rawText = part['text'];
          final text = rawText is Map<String, dynamic>
              ? rawText['value']?.toString()
              : rawText?.toString();
          if (text != null && text.isNotEmpty) {
            if (buffer.isNotEmpty) buffer.write('\n');
            buffer.write(text);
          }
        }
      }
    }

    final text = buffer.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? _extractChatCompletionsText(Map<String, dynamic> data) {
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) return null;

    final first = choices.first;
    if (first is! Map<String, dynamic>) return null;

    final message = first['message'];
    if (message is! Map<String, dynamic>) return null;

    final content = message['content'];
    if (content is String && content.trim().isNotEmpty) {
      return content;
    }

    if (content is List) {
      final buffer = StringBuffer();
      for (final part in content) {
        if (part is! Map<String, dynamic>) continue;
        final text = part['text']?.toString();
        if (text != null && text.isNotEmpty) {
          if (buffer.isNotEmpty) buffer.write('\n');
          buffer.write(text);
        }
      }
      final extracted = buffer.toString().trim();
      return extracted.isEmpty ? null : extracted;
    }

    return null;
  }

  Map<String, dynamic>? _extractJsonObjectFromText(String text) {
    final cleaned = _stripCodeFence(text).trim();

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace < 0 || lastBrace <= firstBrace) {
      return null;
    }

    final candidate = cleaned.substring(firstBrace, lastBrace + 1);
    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return null;
  }

  String _stripCodeFence(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('```')) return trimmed;

    final lines = trimmed.split('\n');
    if (lines.isEmpty) return trimmed;

    final firstLine = lines.first.trim();
    if (!firstLine.startsWith('```')) return trimmed;

    final bodyLines = <String>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim() == '```') {
        break;
      }
      bodyLines.add(line);
    }
    return bodyLines.join('\n').trim();
  }

  Map<String, dynamic> _responsesInputItem({
    required String role,
    required String text,
  }) {
    final contentType = role == 'assistant' ? 'output_text' : 'input_text';
    return {
      'role': role,
      'content': [
        {
          'type': contentType,
          'text': text,
        }
      ],
    };
  }

  String _normalizeResponseRole(String? role) {
    final normalized = role?.trim().toLowerCase();
    if (normalized == 'assistant') return 'assistant';
    if (normalized == 'user') return 'user';
    return 'user';
  }

  static String _normalizeModelId(String? model, {required String fallback}) {
    final normalized = model?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return fallback;
    return normalized;
  }

  void _debugLogHttpFailure({
    required String api,
    required String mode,
    required int statusCode,
    required String body,
  }) {
    final compact = body.replaceAll('\n', ' ').trim();
    final truncated =
        compact.length > 350 ? '${compact.substring(0, 350)}...' : compact;
    debugPrint(
      'OpenAIService $api $mode failed: status=$statusCode body=$truncated',
    );
  }

  static bool get _canCallDirectProvider {
    final hasKey = _apiKey != null && _apiKey!.isNotEmpty;
    if (!hasKey) return false;
    if (!_proxyConfig.allowDirectFallback) return false;
    if (_proxyConfig.requireProxy && kReleaseMode) return false;
    return true;
  }
}

class _TextGenResult {
  final String text;
  final String api;
  final Map<String, dynamic> raw;

  const _TextGenResult({
    required this.text,
    required this.api,
    required this.raw,
  });
}
