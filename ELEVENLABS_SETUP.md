# ElevenLabs AI Voice Integration Setup

This guide explains how to set up the ElevenLabs AI voice integration for the MM Learning Lab app.

## Prerequisites

1. A backend proxy that stores provider API keys securely (recommended for production)
2. Optional for local development only: an ElevenLabs API key

## Setup Steps

### 1. Create an `.env` file

Create a file named `.env` in the root of your project with proxy settings:

```
AI_PROXY_BASE_URL=https://your-proxy.example.com
AI_PROXY_TOKEN=your_proxy_token
AI_PROXY_REQUIRED=true
AI_ALLOW_DIRECT_FALLBACK=false
```

For local development fallback (not recommended for production), you can use:

```
AI_PROXY_REQUIRED=false
AI_ALLOW_DIRECT_FALLBACK=true
ELEVENLABS_API_KEY=your_api_key_here
```

### 2. Update Dependencies

Make sure your `pubspec.yaml` file includes these dependencies:

```yaml
dependencies:
  flutter_dotenv: ^5.1.0
  http: ^1.1.0
  path_provider: ^2.1.1
  just_audio: ^0.9.35
```

Run `flutter pub get` to install the dependencies.

### 3. Initialize in main.dart

Update your `main.dart` file to initialize the ElevenLabs service:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/welcome_screen.dart';
import 'services/elevenlabs_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize ElevenLabs service
  await ElevenLabsService.initialize();
  
  runApp(const MyApp());
}
```

### Proxy Routes Required

Your proxy should expose:

- `GET /elevenlabs/voices`
- `POST /elevenlabs/text-to-speech/:voiceId`
- `POST /elevenlabs/text-to-speech/:voiceId/with-timestamps`

### Fallback Rules

- App always attempts proxy first when `AI_PROXY_BASE_URL` is set.
- Direct ElevenLabs fallback is only used when `AI_ALLOW_DIRECT_FALLBACK=true` and `ELEVENLABS_API_KEY` is present.
- In release builds, direct fallback is blocked when `AI_PROXY_REQUIRED=true`.
- If both proxy and direct fallback fail, the app falls back to built-in voice metadata and returns null for audio generation (no crash).

## Customizing Voice Selection

To use a specific voice from your ElevenLabs account:

1. Visit [elevenlabs.io/voice-library](https://elevenlabs.io/voice-library) to find voice IDs
2. Copy the ID of your preferred voice
3. Update the `_voiceId` in `lib/services/elevenlabs_service.dart`

Example:
```dart
static String _voiceId = 'your-preferred-voice-id';
```

Alternatively, you can use the `getVoices()` method to fetch available voices from your account through the proxy and let users choose.

## How It Works

1. When a user selects "AI Storyteller" mode for a story, the app first checks if audio already exists locally.
2. If no audio is found, it calls your proxy, which then calls ElevenLabs to generate narration.
3. The generated audio is saved locally and linked to the story in the database.
4. Subsequent readings use the cached audio file (no API calls needed).

This approach minimizes API usage and enables offline playback while providing a premium storytelling experience.

## Troubleshooting

- **Audio not generating**: Check proxy health, proxy auth token, and internet connection
- **Voice selection issues**: Verify the voice ID exists in your ElevenLabs account
- **Playback problems**: Ensure the just_audio plugin is properly initialized

For more help, visit [elevenlabs.io/docs](https://elevenlabs.io/docs). 
