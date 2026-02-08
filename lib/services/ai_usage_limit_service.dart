import 'dart:math';

import 'database_service.dart';

enum AiCountFeature {
  chatMessage,
  storyGeneration,
}

class AiQuotaCheckResult {
  final bool allowed;
  final int dailyLimit;
  final int weeklyLimit;
  final int usedToday;
  final int usedThisWeek;
  final String featureLabel;

  const AiQuotaCheckResult({
    required this.allowed,
    required this.dailyLimit,
    required this.weeklyLimit,
    required this.usedToday,
    required this.usedThisWeek,
    required this.featureLabel,
  });

  int get remainingToday => max(0, dailyLimit - usedToday);
  int get remainingThisWeek => max(0, weeklyLimit - usedThisWeek);

  String buildBlockedMessage({required bool isPremium}) {
    final tierText = isPremium ? 'Premium' : 'Free';
    return '$tierText limit reached for $featureLabel. '
        'Remaining: $remainingToday today, $remainingThisWeek this week.';
  }
}

class AiCallAllowance {
  final bool allowed;
  final int perCallLimitSeconds;
  final int remainingTodaySeconds;
  final int remainingThisWeekSeconds;
  final int remainingForThisCallSeconds;
  final int usedTodaySeconds;
  final int usedThisWeekSeconds;

  const AiCallAllowance({
    required this.allowed,
    required this.perCallLimitSeconds,
    required this.remainingTodaySeconds,
    required this.remainingThisWeekSeconds,
    required this.remainingForThisCallSeconds,
    required this.usedTodaySeconds,
    required this.usedThisWeekSeconds,
  });
}

class AiQuotaReservation {
  final int usageEventId;
  final AiQuotaCheckResult statusAfterReserve;

  const AiQuotaReservation({
    required this.usageEventId,
    required this.statusAfterReserve,
  });
}

class AIUsageLimitService {
  static const String _featureChatMessage = 'ai_chat_message';
  static const String _featureStoryGeneration = 'ai_story_generation';

  static const int _freeChatDaily = 30;
  static const int _freeChatWeekly = 120;
  static const int _freeStoriesDaily = 2;
  static const int _freeStoriesWeekly = 10;
  static const int _freeCallPerCallSeconds = 4 * 60;
  static const int _freeCallDailySeconds = 12 * 60;
  static const int _freeCallWeeklySeconds = 45 * 60;

  static const int _premiumChatDaily = 300;
  static const int _premiumChatWeekly = 1200;
  static const int _premiumStoriesDaily = 12;
  static const int _premiumStoriesWeekly = 60;
  static const int _premiumCallPerCallSeconds = 12 * 60;
  static const int _premiumCallDailySeconds = 60 * 60;
  static const int _premiumCallWeeklySeconds = 300 * 60;

  final DatabaseService _databaseService;

  AIUsageLimitService({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService();

  Future<AiQuotaCheckResult> getCountQuotaStatus({
    required int profileId,
    required bool isPremium,
    required AiCountFeature feature,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final startOfDay = _startOfDay(current);
    final startOfWeek = _startOfWeek(current);

    final featureKey = _featureToKey(feature);
    final dailyLimit = _dailyCountLimit(isPremium: isPremium, feature: feature);
    final weeklyLimit =
        _weeklyCountLimit(isPremium: isPremium, feature: feature);

    final usedToday = await _databaseService.getAiUsageUnitsSince(
      profileId: profileId,
      feature: featureKey,
      since: startOfDay,
    );
    final usedThisWeek = await _databaseService.getAiUsageUnitsSince(
      profileId: profileId,
      feature: featureKey,
      since: startOfWeek,
    );

    return AiQuotaCheckResult(
      allowed: usedToday < dailyLimit && usedThisWeek < weeklyLimit,
      dailyLimit: dailyLimit,
      weeklyLimit: weeklyLimit,
      usedToday: usedToday,
      usedThisWeek: usedThisWeek,
      featureLabel: _featureLabel(feature),
    );
  }

  Future<AiQuotaCheckResult> tryConsumeCountQuota({
    required int profileId,
    required bool isPremium,
    required AiCountFeature feature,
    int units = 1,
    DateTime? now,
  }) async {
    final status = await getCountQuotaStatus(
      profileId: profileId,
      isPremium: isPremium,
      feature: feature,
      now: now,
    );
    if (!status.allowed) {
      return status;
    }

    await _databaseService.insertAiUsageEvent(
      profileId: profileId,
      feature: _featureToKey(feature),
      units: units,
      timestamp: now ?? DateTime.now(),
    );

    return getCountQuotaStatus(
      profileId: profileId,
      isPremium: isPremium,
      feature: feature,
      now: now,
    );
  }

  Future<AiQuotaReservation?> reserveCountQuota({
    required int profileId,
    required bool isPremium,
    required AiCountFeature feature,
    int units = 1,
    DateTime? now,
  }) async {
    final status = await getCountQuotaStatus(
      profileId: profileId,
      isPremium: isPremium,
      feature: feature,
      now: now,
    );
    if (!status.allowed) {
      return null;
    }

    final eventId = await _databaseService.insertAiUsageEvent(
      profileId: profileId,
      feature: _featureToKey(feature),
      units: units,
      timestamp: now ?? DateTime.now(),
    );

    final statusAfter = await getCountQuotaStatus(
      profileId: profileId,
      isPremium: isPremium,
      feature: feature,
      now: now,
    );

    return AiQuotaReservation(
      usageEventId: eventId,
      statusAfterReserve: statusAfter,
    );
  }

  Future<void> releaseCountQuotaReservation(int usageEventId) async {
    await _databaseService.deleteAiUsageEventById(usageEventId);
  }

  Future<AiCallAllowance> getVoiceCallAllowance({
    required int profileId,
    required bool isPremium,
    DateTime? now,
  }) async {
    await recoverOpenVoiceCallSessions(
      profileId: profileId,
      now: now,
    );

    final current = now ?? DateTime.now();
    final startOfDay = _startOfDay(current);
    final startOfWeek = _startOfWeek(current);

    final perCallLimitSeconds =
        isPremium ? _premiumCallPerCallSeconds : _freeCallPerCallSeconds;
    final dailyLimitSeconds =
        isPremium ? _premiumCallDailySeconds : _freeCallDailySeconds;
    final weeklyLimitSeconds =
        isPremium ? _premiumCallWeeklySeconds : _freeCallWeeklySeconds;

    final usedTodaySeconds =
        await _databaseService.getAiCallDurationSecondsSince(
      profileId: profileId,
      since: startOfDay,
      until: current,
    );
    final usedThisWeekSeconds =
        await _databaseService.getAiCallDurationSecondsSince(
      profileId: profileId,
      since: startOfWeek,
      until: current,
    );

    final remainingTodaySeconds = max(0, dailyLimitSeconds - usedTodaySeconds);
    final remainingThisWeekSeconds =
        max(0, weeklyLimitSeconds - usedThisWeekSeconds);
    final remainingForThisCallSeconds = min(
      perCallLimitSeconds,
      min(remainingTodaySeconds, remainingThisWeekSeconds),
    );

    return AiCallAllowance(
      allowed: remainingForThisCallSeconds > 0,
      perCallLimitSeconds: perCallLimitSeconds,
      remainingTodaySeconds: remainingTodaySeconds,
      remainingThisWeekSeconds: remainingThisWeekSeconds,
      remainingForThisCallSeconds: remainingForThisCallSeconds,
      usedTodaySeconds: usedTodaySeconds,
      usedThisWeekSeconds: usedThisWeekSeconds,
    );
  }

  Future<int> startVoiceCallSession({
    required int profileId,
    required bool isPremium,
    required String model,
    DateTime? startedAt,
  }) {
    return _databaseService.insertAiCallSession(
      profileId: profileId,
      tier: isPremium ? 'premium' : 'free',
      model: model,
      startedAt: startedAt ?? DateTime.now(),
    );
  }

  Future<void> endVoiceCallSession({
    required int sessionId,
    required int durationSeconds,
    required String endReason,
    DateTime? endedAt,
  }) async {
    final safeDurationSeconds = max(0, durationSeconds);
    await _databaseService.closeAiCallSession(
      sessionId: sessionId,
      endedAt: endedAt ?? DateTime.now(),
      durationSeconds: safeDurationSeconds,
      endReason: endReason,
    );
  }

  Future<void> recoverOpenVoiceCallSessions({
    required int profileId,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final openSessions = await _databaseService.getOpenAiCallSessions(
      profileId: profileId,
    );

    for (final row in openSessions) {
      final sessionId = row['id'];
      final startedAtRaw = row['started_at'] as String?;
      final tier = (row['tier'] as String?) ?? 'free';
      if (sessionId is! int || startedAtRaw == null) {
        continue;
      }

      final startedAt = DateTime.tryParse(startedAtRaw) ?? current;
      final elapsedSeconds = max(0, current.difference(startedAt).inSeconds);
      final perCallCapSeconds = tier == 'premium'
          ? _premiumCallPerCallSeconds
          : _freeCallPerCallSeconds;
      final recoveredDuration = min(elapsedSeconds, perCallCapSeconds);

      await _databaseService.closeAiCallSession(
        sessionId: sessionId,
        endedAt: current,
        durationSeconds: recoveredDuration,
        endReason: 'recovered_after_interrupt',
      );
    }
  }

  String formatDurationShort(int totalSeconds) {
    final safeSeconds = max(0, totalSeconds);
    final minutes = safeSeconds ~/ 60;
    final seconds = safeSeconds % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remMinutes = minutes % 60;
      return '${hours}h ${remMinutes}m';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  int _dailyCountLimit({
    required bool isPremium,
    required AiCountFeature feature,
  }) {
    if (feature == AiCountFeature.chatMessage) {
      return isPremium ? _premiumChatDaily : _freeChatDaily;
    }
    return isPremium ? _premiumStoriesDaily : _freeStoriesDaily;
  }

  int _weeklyCountLimit({
    required bool isPremium,
    required AiCountFeature feature,
  }) {
    if (feature == AiCountFeature.chatMessage) {
      return isPremium ? _premiumChatWeekly : _freeChatWeekly;
    }
    return isPremium ? _premiumStoriesWeekly : _freeStoriesWeekly;
  }

  String _featureToKey(AiCountFeature feature) {
    switch (feature) {
      case AiCountFeature.chatMessage:
        return _featureChatMessage;
      case AiCountFeature.storyGeneration:
        return _featureStoryGeneration;
    }
  }

  String _featureLabel(AiCountFeature feature) {
    switch (feature) {
      case AiCountFeature.chatMessage:
        return 'AI Chat';
      case AiCountFeature.storyGeneration:
        return 'AI Stories';
    }
  }

  DateTime _startOfDay(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  DateTime _startOfWeek(DateTime dateTime) {
    final startOfToday = _startOfDay(dateTime);
    final daysFromMonday = startOfToday.weekday - DateTime.monday;
    return startOfToday.subtract(Duration(days: daysFromMonday));
  }
}
