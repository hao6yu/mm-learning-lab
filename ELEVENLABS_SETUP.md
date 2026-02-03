# ElevenLabs AI Voice Integration Setup

This guide explains how to set up the ElevenLabs AI voice integration for the MM Learning Lab app.

## Prerequisites

1. An ElevenLabs account (sign up at [elevenlabs.io](https://elevenlabs.io))
2. Your ElevenLabs API key

## Setup Steps

### 1. Create an `.env` file

Create a file named `.env` in the root of your project with the following content:

```
ELEVENLABS_API_KEY=your_api_key_here
```

Replace `your_api_key_here` with your actual ElevenLabs API key.

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

## Customizing Voice Selection

To use a specific voice from your ElevenLabs account:

1. Visit [elevenlabs.io/voice-library](https://elevenlabs.io/voice-library) to find voice IDs
2. Copy the ID of your preferred voice
3. Update the `_voiceId` in `lib/services/elevenlabs_service.dart`

Example:
```dart
static String _voiceId = 'your-preferred-voice-id';
```

Alternatively, you can use the `getVoices()` method to fetch available voices from your account and let users choose.

## How It Works

1. When a user selects "AI Storyteller" mode for a story, the app first checks if audio already exists locally.
2. If no audio is found, it calls the ElevenLabs API to generate high-quality narration.
3. The generated audio is saved locally and linked to the story in the database.
4. Subsequent readings use the cached audio file (no API calls needed).

This approach minimizes API usage and enables offline playback while providing a premium storytelling experience.

## Troubleshooting

- **Audio not generating**: Check your API key and internet connection
- **Voice selection issues**: Verify the voice ID exists in your ElevenLabs account
- **Playback problems**: Ensure the just_audio plugin is properly initialized

For more help, visit [elevenlabs.io/docs](https://elevenlabs.io/docs). 