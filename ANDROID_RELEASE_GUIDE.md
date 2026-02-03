# Android Release Setup Guide for MM Learning Lab

This guide explains how to set up the MM Learning Lab Flutter app for Android release.

## Prerequisites

- Flutter SDK installed and configured
- Android Studio or Android SDK Command Line Tools
- JDK 11 or higher

## Current Android Configuration

The Android platform has been successfully added to this Flutter project with the following configurations:

### App Configuration
- **Package Name**: `com.hyu.mm_learning_lab`
- **App Name**: Mm Learning Lab
- **Min SDK Version**: 24 (Android 7.0)
- **Target SDK Version**: Latest Flutter SDK version
- **Version Code**: 1
- **Version Name**: 1.0.3

### Permissions Required
The following permissions are configured in `android/app/src/main/AndroidManifest.xml`:
- `INTERNET` - For API calls and online features
- `CAMERA` - For taking profile photos
- `RECORD_AUDIO` - For voice recording features
- `MODIFY_AUDIO_SETTINGS` - For audio playback
- `BLUETOOTH` - For audio device connectivity
- `BLUETOOTH_ADMIN` - For managing Bluetooth connections
- `BLUETOOTH_CONNECT` - For connecting to Bluetooth devices

## Building for Release

### 1. Create a Keystore (First Time Only)

Generate a keystore for signing your app:

```bash
keytool -genkey -v -keystore android/app/keys/mm-learning-lab.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Important**: Keep your keystore file and passwords secure. You'll need them for all future updates.

### 2. Configure Key Properties

Edit `android/key.properties` and replace the placeholders with your actual values:

```properties
storePassword=<YOUR_STORE_PASSWORD>
keyPassword=<YOUR_KEY_PASSWORD>
keyAlias=upload
storeFile=../app/keys/mm-learning-lab.jks
```

### 3. Build Release APK

```bash
flutter build apk --release
```

The APK will be generated at: `build/app/outputs/flutter-apk/app-release.apk`

### 4. Build Release App Bundle (Recommended for Play Store)

```bash
flutter build appbundle --release
```

The AAB will be generated at: `build/app/outputs/bundle/release/app-release.aab`

## Testing

### Debug Build
```bash
flutter build apk --debug
```

### Install on Device
```bash
flutter install
```

## Dependencies Notes

- **Minimum SDK 24**: Required by `flutter_sound` package
- **NDK Version**: 27.0.12077973 (required by several plugins)
- **Image Cropper**: Updated to version 8.0.2 for Android compatibility

## ProGuard Configuration

ProGuard is enabled for release builds with custom rules in `android/app/proguard-rules.pro` to ensure all plugins work correctly after code shrinking.

## Troubleshooting

### Build Issues
1. Ensure all dependencies are up to date: `flutter pub get`
2. Clean build: `flutter clean` then rebuild
3. Check Android SDK/NDK versions match requirements

### Permission Issues
If permissions aren't working on Android 6.0+, ensure runtime permissions are requested in the app code (already handled by `permission_handler` package).

## Google Play Store Submission

1. Ensure all app metadata is complete
2. Prepare screenshots for different device sizes
3. Write app description and privacy policy
4. Upload the signed AAB file
5. Complete the content rating questionnaire
6. Set up pricing and distribution

## Security Notes

- Never commit `key.properties` or keystore files to version control
- Keep backup copies of your keystore in a secure location
- Use strong passwords for keystore and key alias
- The `.gitignore` file is configured to exclude these sensitive files 