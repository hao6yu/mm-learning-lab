import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'ai_proxy_config.dart';

class OpenAIService {
  static const String _directChatCompletionsUrl =
      'https://api.openai.com/v1/chat/completions';
  static const String _directAudioTranscriptionUrl =
      'https://api.openai.com/v1/audio/transcriptions';

  static const String _proxyChatCompletionsPath = '/openai/chat/completions';
  static const String _proxyAudioTranscriptionPath =
      '/openai/audio/transcriptions';

  static String? _apiKey;
  static String _chatModel = 'gpt-4o';
  static String _chatMiniModel = 'gpt-4o';
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
    _chatModel = dotenv.env['OPENAI_CHAT_MODEL'] ?? 'gpt-4o';
    _chatMiniModel = dotenv.env['OPENAI_CHAT_MINI_MODEL'] ?? 'gpt-4o';
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

    final response = await _postChatCompletions(
      body: {
        'model': _chatModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt}
        ],
        'temperature': 0.7,
        'response_format': {'type': 'json_object'},
      },
      purpose: 'generate story',
    );

    if (response == null) return null;
    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'];
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<String?> generateStoryFromTitle({
    required String title,
    String? category,
    String? difficulty,
    String? ageGroup = 'middle',
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

    final response = await _postChatCompletions(
      body: {
        'model': _chatMiniModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content':
                'Please create a story titled "$title" that is fun and educational for children.'
          }
        ],
        'temperature': 0.7,
      },
      purpose: 'generate story from title',
    );

    if (response == null) return null;
    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'];
  }

  Future<String?> generateTitleSuggestion({
    required String theme,
    String? category,
    String? ageGroup = 'middle',
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

    final response = await _postChatCompletions(
      body: {
        'model': _chatMiniModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content':
                "Generate a catchy title for a children's story about: $theme"
          }
        ],
        'temperature': 0.8,
        'max_tokens': 30,
      },
      purpose: 'generate title suggestion',
    );

    if (response == null) return null;
    final data = jsonDecode(response.body);
    return (data['choices'][0]['message']['content'] as String).trim();
  }

  Future<String?> generateChatResponse({
    required String message,
    required List<Map<String, String>> history,
    String? childName,
    int? childAge,
  }) async {
    final systemPrompt = """
You are a friendly, educational AI assistant for children${childName != null ? ' named $childName' : ''}${childAge != null ? ' who is $childAge years old' : ''}.

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

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...history,
      {'role': 'user', 'content': message},
    ];

    final response = await _postChatCompletions(
      body: {
        'model': _chatMiniModel,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 250,
      },
      purpose: 'generate chat response',
    );

    if (response == null) return null;
    final data = jsonDecode(response.body);
    if (data.containsKey('choices') &&
        data['choices'] is List &&
        (data['choices'] as List).isNotEmpty) {
      return data['choices'][0]['message']['content'];
    }
    return null;
  }

  Future<String?> transcribeAudio(List<int> audioBytes,
      {String? language}) async {
    final proxyResponse =
        await _transcribeViaProxy(audioBytes: audioBytes, language: language);
    if (proxyResponse != null) {
      return proxyResponse;
    }

    if (!_canCallDirectProvider) {
      return null;
    }
    return _transcribeViaDirect(audioBytes: audioBytes, language: language);
  }

  Future<http.Response?> _postChatCompletions({
    required Map<String, dynamic> body,
    required String purpose,
  }) async {
    if (_proxyConfig.hasProxy) {
      try {
        final response = await http.post(
          _proxyConfig.proxyUri(_proxyChatCompletionsPath),
          headers: _proxyConfig.proxyHeaders(),
          body: jsonEncode(body),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }
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
    } catch (_) {}
    return null;
  }

  Future<String?> _transcribeViaProxy({
    required List<int> audioBytes,
    String? language,
  }) async {
    if (!_proxyConfig.hasProxy) {
      return null;
    }
    try {
      final request = http.MultipartRequest(
        'POST',
        _proxyConfig.proxyUri(_proxyAudioTranscriptionPath),
      );
      request.headers.addAll(_proxyConfig.proxyHeaders(json: false));
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

  static bool get _canCallDirectProvider {
    final hasKey = _apiKey != null && _apiKey!.isNotEmpty;
    if (!hasKey) return false;
    if (!_proxyConfig.allowDirectFallback) return false;
    if (_proxyConfig.requireProxy && kReleaseMode) return false;
    return true;
  }
}
