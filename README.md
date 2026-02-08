# M&M Learning Lab 🎓

A playful Flutter app for early literacy and math learning. Built for kids, designed to make education fun.

## Features

### 🔢 Math Games
- **Math Buddy** - AI-powered math tutor with friendly characters
- **Math Challenge** - Timed quizzes with difficulty levels
- **Kids Calculator** - Visual calculator for learning arithmetic
- **Number Pop** - Pop bubbles to practice counting
- **Sudoku** - Kid-friendly puzzle solving

### 📖 Literacy
- **Letter Tracing** - Learn to write letters with guided tracing
- **Phonics** - Sound out letters and words
- **Story Adventure** - AI-generated interactive stories
- **Create Story** - Kids create their own stories with AI help

### 🧩 Puzzle Games
- **Memory Match** - Classic memory card game
- **Bubble Pop** - Fun bubble popping with learning elements
- **Tic Tac Toe** - Classic game against AI
- **Chess** - Learn chess basics
- **Gobang (Five in a Row)** - Strategy board game
- **Chess Maze** - Chess piece movement puzzles

### 🎙️ AI Features
- **Voice Conversations** - Talk to AI tutors (OpenAI Realtime)
- **Text-to-Speech** - Stories read aloud (ElevenLabs)
- **AI Chat** - Ask questions, get kid-friendly answers

### 👨‍👩‍👧‍👦 Family Features
- **Multiple Profiles** - Each child gets their own profile
- **Progress Tracking** - Quiz history and achievements
- **Customizable Avatars** - Fun profile customization

## Tech Stack

- **Framework:** Flutter 3.x
- **State Management:** Provider
- **Database:** SQLite (local)
- **AI:** OpenAI API
- **Voice:** ElevenLabs TTS
- **Platforms:** iOS, Android

## Getting Started

### Prerequisites

- Flutter SDK 3.0+
- Dart SDK
- Xcode (for iOS)
- Android Studio (for Android)

### Installation

```bash
# Clone the repo
git clone https://github.com/hao6yu/mm-learning-lab.git
cd mm-learning-lab

# Install dependencies
flutter pub get

# Copy environment template
cp env.example .env
```

### Environment Setup

Edit `.env` with proxy settings (recommended):

```env
AI_PROXY_BASE_URL=https://your-proxy.example.com
AI_PROXY_TOKEN=your_proxy_token
AI_PROXY_REQUIRED=true
AI_ALLOW_DIRECT_FALLBACK=false
```

For local development only, you can optionally enable direct fallback with provider keys:

```env
AI_PROXY_REQUIRED=false
AI_ALLOW_DIRECT_FALLBACK=true
OPENAI_API_KEY=your_openai_api_key
ELEVENLABS_API_KEY=your_elevenlabs_api_key
```

Fallback behavior:
- If proxy is configured, the app tries proxy endpoints first.
- If proxy fails, direct provider fallback is allowed only when `AI_ALLOW_DIRECT_FALLBACK=true`.
- In release builds, direct fallback is blocked when `AI_PROXY_REQUIRED=true`.
- If both proxy and direct fallback are unavailable, AI calls fail gracefully and the app keeps running.

### Run

```bash
# iOS
flutter run -d ios

# Android
flutter run -d android
```

## Building for Release

See the included guides:
- `ANDROID_RELEASE_GUIDE.md` - Android Play Store deployment
- `APP_STORE_SUBMISSION_GUIDE.md` - iOS App Store deployment
- `AI_PROXY_DEPLOYMENT_GUIDE.md` - backend proxy deployment for OpenAI/ElevenLabs
- `NEXT_RELEASE_CHANGELOG.md` - release summary
- `RELEASE_SMOKE_TEST_CHECKLIST.md` - phone/tablet release QA checklist

## Support

☕ [Buy me a coffee](https://buymeacoffee.com/haoy)

## License

MIT License - feel free to use for your own learning projects!
