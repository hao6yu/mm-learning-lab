import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ActivityProgress {
  final String activityId;
  final String activityTitle;
  final DateTime playedAt;

  const ActivityProgress({
    required this.activityId,
    required this.activityTitle,
    required this.playedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'activity_id': activityId,
      'activity_title': activityTitle,
      'played_at': playedAt.toIso8601String(),
    };
  }

  factory ActivityProgress.fromMap(Map<String, dynamic> map) {
    return ActivityProgress(
      activityId: map['activity_id'] as String,
      activityTitle: map['activity_title'] as String,
      playedAt: DateTime.tryParse(map['played_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ActivityProgressService {
  static const String _lastActivityPrefix = 'last_activity_profile_';
  static const String _onboardingPrefix = 'onboarding_seen_';

  Future<void> saveLastActivity({
    required int profileId,
    required String activityId,
    required String activityTitle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = ActivityProgress(
      activityId: activityId,
      activityTitle: activityTitle,
      playedAt: DateTime.now(),
    );

    await prefs.setString(
      '$_lastActivityPrefix$profileId',
      jsonEncode(payload.toMap()),
    );
  }

  Future<ActivityProgress?> getLastActivity(int profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('$_lastActivityPrefix$profileId');
    if (json == null || json.isEmpty) {
      return null;
    }

    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return ActivityProgress.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasSeenOnboarding(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_onboardingPrefix$gameId') ?? false;
  }

  Future<void> markOnboardingSeen(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_onboardingPrefix$gameId', true);
  }
}
