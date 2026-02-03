import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _audioTranscriptionUrl = 'https://api.openai.com/v1/audio/transcriptions';
  static String? _apiKey;
  static String _chatModel = 'gpt-4o'; // Default value
  static String _chatMiniModel = 'gpt-4o'; // Default value

  // Age-appropriate story tones for different age groups
  static const Map<String, String> agePrompts = {
    'young': 'Write a very short, simple story for a 3-6 year old child with basic vocabulary and short sentences. The story should be educational, positive, and engaging for very young children.',
    'middle': 'Write a short story for a 7-9 year old child with age-appropriate vocabulary. Include a small challenge or lesson that is resolved positively.',
    'older': 'Write a story for a 10-12 year old that is engaging and includes more complex vocabulary but is still age-appropriate. The story can have a bit more complexity in plot.'
  };

  static const Map<String, String> categoryPrompts = {
    'Adventure': 'an exciting adventure with exploration and discovery',
    'Animals': 'a story featuring friendly animals as main characters',
    'Space': 'a story about space, planets, or astronauts',
    'Fantasy': 'a magical fantasy story with light fantasy elements',
    'Nature': 'a story about nature, plants, weather, or the environment'
  };

  static const Map<String, String> difficultyPrompts = {
    'Easy': 'Use simple words and short sentences for early readers.',
    'Medium': 'Use moderate vocabulary with some challenging words but mostly straightforward language.',
    'Hard': 'Include some advanced vocabulary words that help build reading skills, but still keep the content age-appropriate.'
  };

  // Initialize with env variables or direct values
  static Future<void> initialize({String? apiKey}) async {
    _apiKey = apiKey ?? dotenv.env['OPENAI_API_KEY'];
    if (_apiKey == null) {
      print('Warning: OpenAI API key not set');
    }

    // Initialize model names from .env
    _chatModel = dotenv.env['OPENAI_CHAT_MODEL'] ?? 'gpt-4o';
    _chatMiniModel = dotenv.env['OPENAI_CHAT_MINI_MODEL'] ?? 'gpt-4o';

    print('OpenAI models initialized: chat=${_chatModel}, mini=${_chatMiniModel}');
  }

  // Generate a complete story with title, category, etc.
  Future<Map<String, dynamic>?> generateStory({
    String? ageGroup = 'middle',
    String? prompt,
  }) async {
    if (_apiKey == null) {
      print('Error: OpenAI API key not found');
      return null;
    }

    String systemPrompt = """
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

    String userPrompt = prompt ?? 'Please create a fun, educational story for children.';

    try {
      print('Sending request to OpenAI API to generate a story');
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _chatMiniModel,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt}
          ],
          'temperature': 0.7,
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        print('Received story from OpenAI: ${content.substring(0, min(100, content.length))}...');

        try {
          final storyData = jsonDecode(content);
          return storyData;
        } catch (e) {
          print('Error parsing OpenAI JSON response: $e');
          return null;
        }
      } else {
        print('Error from OpenAI API: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception in OpenAI API call: $e');
      return null;
    }
  }

  // Generate just a story based on a title and category
  Future<String?> generateStoryFromTitle({
    required String title,
    String? category,
    String? difficulty,
    String? ageGroup = 'middle',
  }) async {
    if (_apiKey == null) {
      print('Error: OpenAI API key not found');
      return null;
    }

    String systemPrompt = """
You are a creative children's story writer who creates age-appropriate stories that are positive, educational, and engaging.
${agePrompts[ageGroup ?? 'middle']}
${category != null ? 'The story should be ${categoryPrompts[category] ?? "engaging and creative"}.' : ''}
${difficulty != null ? difficultyPrompts[difficulty] ?? '' : ''}

Write a story with the title: "$title"

The story should be under 500 words, have a clear beginning, middle, and end, and include a positive message.
Absolutely NO scary, violent, upsetting or inappropriate content. Keep it educational and wholesome.
""";

    try {
      print('Sending request to OpenAI API to generate a story for title: $title');
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _chatMiniModel,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': 'Please create a story titled "$title" that is fun and educational for children.'}
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        print('Received story from OpenAI: ${content.substring(0, min(100, content.length))}...');
        return content;
      } else {
        print('Error from OpenAI API: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception in OpenAI API call: $e');
      return null;
    }
  }

  // Generate a title suggestion based on a theme or idea
  Future<String?> generateTitleSuggestion({
    required String theme,
    String? category,
    String? ageGroup = 'middle',
  }) async {
    if (_apiKey == null) {
      print('Error: OpenAI API key not found');
      return null;
    }

    String systemPrompt = """
Generate a fun, catchy, and age-appropriate title for a children's story about: $theme
${category != null ? 'The story is in the ${category} category.' : ''}
${agePrompts[ageGroup ?? 'middle']}

The title should be:
- Short (2-8 words)
- Engaging
- Age-appropriate
- Creative

Return ONLY the title text with no explanation or other text.
""";

    try {
      print('Sending request to OpenAI API to generate a title about: $theme');
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _chatMiniModel,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': 'Generate a catchy title for a children\'s story about: $theme'}
          ],
          'temperature': 0.8,
          'max_tokens': 30,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final title = data['choices'][0]['message']['content'].trim();
        print('Received title from OpenAI: $title');
        return title;
      } else {
        print('Error from OpenAI API: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception in OpenAI API call: $e');
      return null;
    }
  }

  // New method for AI chat responses
  Future<String?> generateChatResponse({
    required String message,
    required List<Map<String, String>> history,
    String? childName,
    int? childAge,
  }) async {
    print('======== OPENAI SERVICE: GENERATE CHAT RESPONSE ========');
    print('Message: ${message.substring(0, min(50, message.length))}${message.length > 50 ? '...' : ''}');
    print('History length: ${history.length} messages');
    print('Child name: $childName');
    print('Child age: $childAge');
    print('Using model: $_chatMiniModel');

    if (_apiKey == null) {
      print('❌ Error: OpenAI API key not found');
      return null;
    }

    String systemPrompt = """
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

    final messages = [
      {'role': 'system', 'content': systemPrompt},
    ];

    // Add conversation history
    for (var entry in history) {
      messages.add(entry);
    }

    // Add the current message
    messages.add({'role': 'user', 'content': message});

    print('Total message count (including system and current): ${messages.length}');

    try {
      print('🔄 Sending chat request to OpenAI API endpoint: $_baseUrl');
      print('Request parameters:');
      print('  - Model: $_chatMiniModel');
      print('  - Temperature: 0.7');
      print('  - Max tokens: 250');

      final stopwatch = Stopwatch()..start();

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _chatMiniModel,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 250,
        }),
      );

      final elapsed = stopwatch.elapsedMilliseconds;
      print('Response received in ${elapsed}ms');

      if (response.statusCode == 200) {
        print('✅ Success - Status code: ${response.statusCode}');

        final data = jsonDecode(response.body);
        print('Response data structure: ${data.keys.toList()}');

        if (data.containsKey('choices') && data['choices'].isNotEmpty) {
          final content = data['choices'][0]['message']['content'];
          final model = data['model'] ?? 'unknown';
          final usage = data['usage'];

          print('Completion details:');
          print('  - Model actually used: $model');
          if (usage != null) {
            print('  - Prompt tokens: ${usage['prompt_tokens']}');
            print('  - Completion tokens: ${usage['completion_tokens']}');
            print('  - Total tokens: ${usage['total_tokens']}');
          }

          print('Response preview: "${content.substring(0, min(100, content.length))}${content.length > 100 ? '...' : ''}"');

          print('======== OPENAI SERVICE: RESPONSE COMPLETE ========');
          return content;
        } else {
          print('❌ Error: Unexpected response format - no choices found');
          print('Response body: ${response.body.substring(0, min(200, response.body.length))}...');
          return null;
        }
      } else {
        print('❌ Error - Status code: ${response.statusCode}');
        print('Error response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Exception in OpenAI API call: $e');
      print('Stack trace: ${StackTrace.current}');
      print('======== OPENAI SERVICE: ERROR ========');
      return null;
    }
  }

  // Transcribe audio using OpenAI's Whisper API
  Future<String?> transcribeAudio(List<int> audioBytes, {String? language}) async {
    print('======== OPENAI SERVICE: TRANSCRIBE AUDIO ========');
    print('Audio size: ${audioBytes.length} bytes');
    print('Language: ${language ?? 'auto'}');

    if (_apiKey == null) {
      print('❌ Error: OpenAI API key not found');
      return null;
    }

    // Create a multipart request
    final request = http.MultipartRequest('POST', Uri.parse(_audioTranscriptionUrl));
    print('Preparing request to: $_audioTranscriptionUrl');

    // Add the API key to the headers
    request.headers.addAll({
      'Authorization': 'Bearer $_apiKey',
    });

    // Add the audio file as a multipart field
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        audioBytes,
        filename: 'audio.webm', // The filename matters for the MIME type
      ),
    );
    print('Added audio file to request (${audioBytes.length} bytes)');

    // Add parameters
    request.fields['model'] = 'whisper-1';
    if (language != null) {
      request.fields['language'] = language;
    }
    print('Using Whisper model: whisper-1');

    try {
      print('🔄 Sending audio transcription request to OpenAI');
      final stopwatch = Stopwatch()..start();

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final elapsed = stopwatch.elapsedMilliseconds;
      print('Response received in ${elapsed}ms');

      if (response.statusCode == 200) {
        print('✅ Success - Status code: ${response.statusCode}');

        final data = jsonDecode(response.body);
        final transcription = data['text'];

        print('Transcription result (${transcription.length} chars): "${transcription.substring(0, min(100, transcription.length))}${transcription.length > 100 ? '...' : ''}"');
        print('======== OPENAI SERVICE: TRANSCRIPTION COMPLETE ========');
        return transcription;
      } else {
        print('❌ Error - Status code: ${response.statusCode}');
        print('Error response: ${response.body.substring(0, min(200, response.body.length))}...');
        print('======== OPENAI SERVICE: TRANSCRIPTION ERROR ========');
        return null;
      }
    } catch (e) {
      print('❌ Exception in OpenAI Whisper API call: $e');
      print('Stack trace: ${StackTrace.current}');
      print('======== OPENAI SERVICE: ERROR ========');
      return null;
    }
  }
}

// Helper function to get smaller of two integers
int min(int a, int b) {
  return a < b ? a : b;
}
