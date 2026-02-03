# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

M&M Learning Lab is an educational Flutter app for children providing interactive learning experiences including AI-generated stories, voice conversations, letter tracing, math challenges, puzzle games, and more. The app uses OpenAI and ElevenLabs APIs for AI features and includes subscription-based access via Apple and Google in-app purchases.

## Essential Commands

### Development
```bash
# Install dependencies
flutter pub get

# Run the app (requires .env file)
flutter run

# Clean build artifacts
flutter clean

# Run on specific device
flutter devices                    # List available devices
flutter run -d <device-id>        # Run on specific device
```

### Building

**iOS:**
```bash
# Debug build
flutter build ios --debug

# Release build (requires signing configured in Xcode)
flutter build ios --release

# Generate app icons
flutter pub run flutter_launcher_icons
```

**Android:**
```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# Release App Bundle (for Play Store)
flutter build appbundle --release
```

### Testing
```bash
# Run tests
flutter test

# Run specific test file
flutter test test/<test_file>.dart
```

## Environment Setup

1. **Create `.env` file** in project root with:
   ```
   OPENAI_API_KEY=your_openai_api_key_here
   OPENAI_CHAT_MODEL=gpt-4o
   OPENAI_CHAT_MINI_MODEL=gpt-4o
   OPENAI_REALTIME_MODEL=gpt-4o-realtime-preview-2024-12-17
   ELEVENLABS_API_KEY=your_elevenlabs_api_key_here
   ```

2. **iOS Setup:**
   - Open `ios/Runner.xcworkspace` in Xcode
   - Configure signing & capabilities
   - Add In-App Purchase capability if needed
   - See `APP_STORE_SUBMISSION_GUIDE.md` for submission details

3. **Android Setup:**
   - Create keystore: `keytool -genkey -v -keystore android/app/keys/mm-learning-lab.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
   - Configure `android/key.properties`
   - See `ANDROID_RELEASE_GUIDE.md` for release details

## Architecture

### Core Structure

```
lib/
├── main.dart                    # App entry point, provider setup
├── models/                      # Data models (Profile, Story, ChatMessage, etc.)
├── providers/                   # State management (ProfileProvider)
├── screens/                     # UI screens (30+ screens for games/features)
├── services/                    # Business logic & external APIs
│   ├── database_service.dart    # SQLite database (profiles, stories, chat)
│   ├── openai_service.dart      # OpenAI API integration
│   ├── elevenlabs_service.dart  # Text-to-speech
│   ├── subscription_service.dart # In-app purchase management
│   └── audio_recorder_service.dart # Voice recording
├── widgets/                     # Reusable UI components
└── utils/                       # Helper utilities (screen utils, responsive config)
```

### Key Architectural Patterns

**State Management:**
- Uses `provider` package for global state
- `ProfileProvider` manages user profiles across the app
- `SubscriptionService` extends `ChangeNotifier` for subscription state
- All screens wrapped in `SubscriptionGuard` widget to enforce subscription

**Database:**
- SQLite via `sqflite` package
- Singleton `DatabaseService` manages all DB operations
- Database version: 6 (uses migration system via `onUpgrade`)
- Tables: `profiles`, `game_progress`, `math_quiz_attempts`, `stories`, `chat_messages`
- Supports profile avatars (emoji or image), user-created stories, and chat history

**Navigation:**
- Uses named routes defined in `main.dart`
- All routes (except `/subscription`) wrapped in `SubscriptionGuard`
- Main routes: `/`, `/games`, `/tracing`, `/phonics`, `/bubble-pop`, `/story-adventure`, `/ai-chat`

**Responsive Design:**
- Uses `responsive_sizer` package for cross-device layouts
- Custom utilities in `lib/utils/screen_utils.dart` and `responsive_config.dart`
- Supports both phones and tablets

### Service Integration

**OpenAI Service** (`lib/services/openai_service.dart`):
- Singleton pattern with static initialization
- Model configuration via environment variables
- Methods:
  - `generateStory()` - Full story generation with metadata
  - `generateStoryFromTitle()` - Story from given title/theme
  - `generateTitleSuggestion()` - AI title generation
  - `generateChatResponse()` - Child-friendly AI chat
  - `transcribeAudio()` - Whisper API speech-to-text
- Age-appropriate content filtering built-in

**Subscription Service** (`lib/services/subscription_service.dart`):
- Product ID: `com.hyu.LearningLab.premium.monthly`
- Handles both direct purchases and Family Sharing (iOS)
- Debug bypass flag: `kBypassSubscriptionForDebug` (set to `false` for production)
- Persistent storage via `SharedPreferences`
- Purchase flow managed via `InAppPurchase` stream
- Testing methods: `resetSubscriptionForTesting()`, `debugSkipSubscription()`

**Database Service** (`lib/services/database_service.dart`):
- Auto-repairs database on integrity issues via `checkAndRepairDatabase()`
- Called during app startup in `main.dart`
- Preloads default stories (13 stories across Easy/Medium/Hard difficulties)
- Profile CRUD: `insertProfile()`, `getProfiles()`, `updateProfile()`, `deleteProfile()`
- Chat message CRUD with audio path support
- Math quiz history tracking

### Important Implementation Details

**App Initialization Flow** (`lib/main.dart`):
1. Custom debug logging with timestamps
2. Load environment variables from `.env`
3. Check and repair database integrity
4. Initialize ElevenLabs service
5. Initialize OpenAI service
6. Launch app with `MultiProvider` (ProfileProvider, SubscriptionService)
7. All routes wrapped in `SubscriptionGuard` except subscription screen

**Profile System:**
- Supports multiple child profiles (name, age, avatar)
- Avatar types: emoji or image (stored as file path)
- Profile selection is first screen user sees
- Selected profile stored in `ProfileProvider`

**Subscription Guard:**
- Wraps all main app routes
- Checks `SubscriptionService.isSubscribed`
- Redirects to subscription screen if not subscribed
- Shows loading state while checking subscription

**Voice Features:**
- Uses WebSocket connection to OpenAI Realtime API for voice conversations
- Speech-to-text via OpenAI Whisper API
- Text-to-speech via ElevenLabs API
- Audio recording via `flutter_sound` package
- Requires microphone permissions

## Development Workflows

### Adding a New Feature

1. **Create models** in `lib/models/` if needed
2. **Add database tables** in `database_service.dart`:
   - Update `_createDb()` for new installations
   - Update `_onUpgrade()` for existing users
   - Increment database version number
3. **Create service** in `lib/services/` for business logic
4. **Create screen** in `lib/screens/`
5. **Add route** in `main.dart` routes map
6. **Wrap in SubscriptionGuard** if feature requires subscription
7. **Add navigation** from game selection or appropriate screen

### Modifying Database Schema

1. Increment version in `_initDatabase()` (currently version 6)
2. Add migration logic in `_onUpgrade()` for specific version
3. Add corresponding CRUD methods at bottom of `DatabaseService`
4. Test migration from previous version

### Working with AI Features

- All AI prompts include child safety filters
- Age-appropriate content enforced in `OpenAIService`
- Story generation includes difficulty levels (Easy/Medium/Hard)
- Chat responses limited to 250 tokens for conciseness
- Always handle API failures gracefully with user-friendly messages

### Subscription Testing

**Bypass subscription for development:**
```dart
// In lib/services/subscription_service.dart
const bool kBypassSubscriptionForDebug = true;  // Change to true
```

**Reset subscription state for testing:**
```dart
// Call from debug UI or code
await subscriptionService.resetSubscriptionForTesting();
```

**Test Family Sharing:**
- Family Sharing detected via error messages from StoreKit
- Automatically grants access if error contains "family", "shared", or "already purchased"

## Platform-Specific Notes

### iOS
- Minimum iOS version determined by Flutter SDK
- Requires microphone, camera permissions in Info.plist
- Uses StoreKit 1 for in-app purchases
- App Store requires Terms of Use and Privacy Policy links (see `APP_STORE_SUBMISSION_GUIDE.md`)

### Android
- Min SDK: 24 (Android 7.0) - required by `flutter_sound`
- Target SDK: Latest
- Package: `com.hyu.mm_learning_lab`
- NDK version: 27.0.12077973
- ProGuard enabled for release builds
- Permissions: INTERNET, CAMERA, RECORD_AUDIO, BLUETOOTH, etc.

## Debugging

**Enable verbose logging:**
- Custom debug print with timestamps already enabled in `main.dart`
- All services include detailed logging
- Look for these prefixes in logs:
  - `======== OPENAI SERVICE:` - OpenAI API calls
  - `🧪 DEBUG:` - Subscription testing/debug
  - `✅` - Success states
  - `❌` - Error states

**Common issues:**
- Database corruption: Auto-repaired on startup
- Subscription not working: Check `kBypassSubscriptionForDebug` flag
- API failures: Verify `.env` file exists and keys are valid
- Build failures: Run `flutter clean` and `flutter pub get`

## Release Checklist

### Before Release
- [ ] Set `kBypassSubscriptionForDebug = false`
- [ ] Remove any debug code/testing methods
- [ ] Update version in `pubspec.yaml`
- [ ] Test subscription flow on real devices
- [ ] Verify all API keys in `.env` are production keys
- [ ] Test database migrations from previous version
- [ ] Verify Privacy Policy and Terms of Use links

### iOS
- [ ] Update version/build number in Xcode
- [ ] Configure signing with distribution certificate
- [ ] Add App Store Connect metadata
- [ ] Include subscription information in description
- [ ] Upload screenshots

### Android
- [ ] Update `versionCode` and `versionName` in `android/app/build.gradle`
- [ ] Build signed AAB
- [ ] Upload to Play Console
- [ ] Complete content rating questionnaire
