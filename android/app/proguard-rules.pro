# Flutter specific
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Dart classes
-keepattributes *Annotation*
-keepattributes Signature

# In-app purchase specific
-keep class com.android.vending.billing.**

# Google Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# SQLite
-keep class io.flutter.plugins.sqflite.** { *; }

# Audio packages
-keep class xyz.canardoux.fluttersound.** { *; }
-keep class com.dooboolab.** { *; }

# Speech to text
-keep class io.csdcorp.speech_to_text.** { *; }

# Google Play Core (for deferred components)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Keep all Play Core classes if they exist
-keep class com.google.android.play.core.** { *; } 