import 'package:shared_preferences/shared_preferences.dart';

class AiParentalControls {
  final bool callEnabled;
  final bool bedtimeLockEnabled;
  final int bedtimeStartHour; // 0-23
  final int bedtimeEndHour; // 0-23
  final int? maxCallMinutesOverride;

  const AiParentalControls({
    required this.callEnabled,
    required this.bedtimeLockEnabled,
    required this.bedtimeStartHour,
    required this.bedtimeEndHour,
    required this.maxCallMinutesOverride,
  });

  const AiParentalControls.defaults()
      : callEnabled = true,
        bedtimeLockEnabled = false,
        bedtimeStartHour = 21,
        bedtimeEndHour = 7,
        maxCallMinutesOverride = null;

  AiParentalControls copyWith({
    bool? callEnabled,
    bool? bedtimeLockEnabled,
    int? bedtimeStartHour,
    int? bedtimeEndHour,
    int? maxCallMinutesOverride,
    bool clearMaxCallMinutesOverride = false,
  }) {
    return AiParentalControls(
      callEnabled: callEnabled ?? this.callEnabled,
      bedtimeLockEnabled: bedtimeLockEnabled ?? this.bedtimeLockEnabled,
      bedtimeStartHour: bedtimeStartHour ?? this.bedtimeStartHour,
      bedtimeEndHour: bedtimeEndHour ?? this.bedtimeEndHour,
      maxCallMinutesOverride: clearMaxCallMinutesOverride
          ? null
          : (maxCallMinutesOverride ?? this.maxCallMinutesOverride),
    );
  }

  bool isCallBlockedByBedtime(DateTime now) {
    if (!bedtimeLockEnabled) return false;
    final hour = now.hour;
    if (bedtimeStartHour == bedtimeEndHour) {
      return true;
    }
    // Overnight window, e.g. 21 -> 7.
    if (bedtimeStartHour > bedtimeEndHour) {
      return hour >= bedtimeStartHour || hour < bedtimeEndHour;
    }
    // Same-day window, e.g. 13 -> 16.
    return hour >= bedtimeStartHour && hour < bedtimeEndHour;
  }

  String bedtimeRangeLabel() {
    String fmt(int hour) {
      final period = hour >= 12 ? 'PM' : 'AM';
      final normalized = hour % 12 == 0 ? 12 : hour % 12;
      return '$normalized$period';
    }

    return '${fmt(bedtimeStartHour)} - ${fmt(bedtimeEndHour)}';
  }
}

class AiParentalControlService {
  static const String _keyPrefix = 'ai_parental_controls_profile_';

  String _key(String suffix, int profileId) =>
      '$_keyPrefix${profileId}_$suffix';

  Future<AiParentalControls> getControls(int profileId) async {
    final prefs = await SharedPreferences.getInstance();
    return AiParentalControls(
      callEnabled: prefs.getBool(_key('call_enabled', profileId)) ?? true,
      bedtimeLockEnabled:
          prefs.getBool(_key('bedtime_enabled', profileId)) ?? false,
      bedtimeStartHour: prefs.getInt(_key('bedtime_start', profileId)) ?? 21,
      bedtimeEndHour: prefs.getInt(_key('bedtime_end', profileId)) ?? 7,
      maxCallMinutesOverride:
          prefs.getInt(_key('max_call_minutes_override', profileId)),
    );
  }

  Future<void> saveControls(int profileId, AiParentalControls controls) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key('call_enabled', profileId), controls.callEnabled);
    await prefs.setBool(
      _key('bedtime_enabled', profileId),
      controls.bedtimeLockEnabled,
    );
    await prefs.setInt(
      _key('bedtime_start', profileId),
      controls.bedtimeStartHour.clamp(0, 23),
    );
    await prefs.setInt(
      _key('bedtime_end', profileId),
      controls.bedtimeEndHour.clamp(0, 23),
    );

    if (controls.maxCallMinutesOverride == null) {
      await prefs.remove(_key('max_call_minutes_override', profileId));
    } else {
      await prefs.setInt(
        _key('max_call_minutes_override', profileId),
        controls.maxCallMinutesOverride!.clamp(1, 30),
      );
    }
  }
}
