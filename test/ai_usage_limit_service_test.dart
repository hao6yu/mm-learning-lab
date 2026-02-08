import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mm_learning_lab/models/profile.dart';
import 'package:mm_learning_lab/services/ai_usage_limit_service.dart';
import 'package:mm_learning_lab/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseService().deleteDatabase();
  });

  tearDown(() async {
    await DatabaseService().deleteDatabase();
  });

  Future<int> createProfile(String name) {
    return DatabaseService().insertProfile(
      Profile(
        name: name,
        age: 7,
        avatar: '🧒',
      ),
    );
  }

  test('free chat quota is enforced per profile', () async {
    final db = DatabaseService();
    final service = AIUsageLimitService(databaseService: db);
    final kidA = await createProfile('Kid A');
    final kidB = await createProfile('Kid B');
    final now = DateTime(2026, 2, 8, 10, 0);

    for (int i = 0; i < 30; i++) {
      await db.insertAiUsageEvent(
        profileId: kidA,
        feature: 'ai_chat_message',
        timestamp: now.subtract(Duration(minutes: i)),
      );
    }

    final statusA = await service.getCountQuotaStatus(
      profileId: kidA,
      isPremium: false,
      feature: AiCountFeature.chatMessage,
      now: now,
    );
    expect(statusA.allowed, isFalse);
    expect(statusA.remainingToday, 0);

    final statusB = await service.getCountQuotaStatus(
      profileId: kidB,
      isPremium: false,
      feature: AiCountFeature.chatMessage,
      now: now,
    );
    expect(statusB.allowed, isTrue);
    expect(statusB.usedToday, 0);
  });

  test('free story weekly quota resets on Monday', () async {
    final db = DatabaseService();
    final service = AIUsageLimitService(databaseService: db);
    final profileId = await createProfile('Story Kid');
    final sunday = DateTime(2026, 2, 8, 12, 0); // Sunday
    final monday = DateTime(2026, 2, 9, 9, 0); // Next Monday

    for (int i = 0; i < 10; i++) {
      await db.insertAiUsageEvent(
        profileId: profileId,
        feature: 'ai_story_generation',
        timestamp: sunday.subtract(Duration(days: i % 3)),
      );
    }

    final sundayStatus = await service.getCountQuotaStatus(
      profileId: profileId,
      isPremium: false,
      feature: AiCountFeature.storyGeneration,
      now: sunday,
    );
    expect(sundayStatus.allowed, isFalse);
    expect(sundayStatus.remainingThisWeek, 0);

    final mondayStatus = await service.getCountQuotaStatus(
      profileId: profileId,
      isPremium: false,
      feature: AiCountFeature.storyGeneration,
      now: monday,
    );
    expect(mondayStatus.allowed, isTrue);
    expect(mondayStatus.usedThisWeek, 0);
  });

  test('free voice call allowance enforces daily cap', () async {
    final db = DatabaseService();
    final service = AIUsageLimitService(databaseService: db);
    final profileId = await createProfile('Voice Kid');
    final now = DateTime(2026, 2, 8, 15, 0);

    Future<void> addClosedCall(int seconds, int offsetMinutes) async {
      final start = now.subtract(Duration(minutes: offsetMinutes));
      final id = await db.insertAiCallSession(
        profileId: profileId,
        tier: 'free',
        model: 'gpt-realtime-mini',
        startedAt: start,
      );
      await db.closeAiCallSession(
        sessionId: id,
        endedAt: start.add(Duration(seconds: seconds)),
        durationSeconds: seconds,
        endReason: 'test',
      );
    }

    await addClosedCall(240, 50);
    await addClosedCall(240, 30);

    final beforeCap = await service.getVoiceCallAllowance(
      profileId: profileId,
      isPremium: false,
      now: now,
    );
    expect(beforeCap.allowed, isTrue);
    expect(beforeCap.remainingForThisCallSeconds, 240);

    await addClosedCall(240, 10);

    final atCap = await service.getVoiceCallAllowance(
      profileId: profileId,
      isPremium: false,
      now: now,
    );
    expect(atCap.allowed, isFalse);
    expect(atCap.remainingTodaySeconds, 0);
    expect(atCap.remainingForThisCallSeconds, 0);
  });

  test('recoverOpenVoiceCallSessions caps recovered duration by tier',
      () async {
    final db = DatabaseService();
    final service = AIUsageLimitService(databaseService: db);
    final profileId = await createProfile('Recovery Kid');
    final now = DateTime(2026, 2, 8, 18, 0);

    final sessionId = await db.insertAiCallSession(
      profileId: profileId,
      tier: 'free',
      model: 'gpt-realtime-mini',
      startedAt: now.subtract(const Duration(minutes: 20)),
    );

    await service.recoverOpenVoiceCallSessions(
      profileId: profileId,
      now: now,
    );

    final openSessions = await db.getOpenAiCallSessions(profileId: profileId);
    expect(openSessions, isEmpty);

    final database = await db.database;
    final rows = await database.query(
      'ai_call_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    expect(rows.single['duration_seconds'], 240);
    expect(rows.single['end_reason'], 'recovered_after_interrupt');
  });

  test('voice usage counts overlap when call spans day boundary', () async {
    final db = DatabaseService();
    final service = AIUsageLimitService(databaseService: db);
    final profileId = await createProfile('Boundary Kid');

    final start = DateTime(2026, 2, 8, 23, 58, 0);
    final end = DateTime(2026, 2, 9, 0, 3, 0);
    final sessionId = await db.insertAiCallSession(
      profileId: profileId,
      tier: 'free',
      model: 'gpt-realtime-mini',
      startedAt: start,
    );
    await db.closeAiCallSession(
      sessionId: sessionId,
      endedAt: end,
      durationSeconds: 300,
      endReason: 'test_boundary',
    );

    final allowanceAtEndOfDay = await service.getVoiceCallAllowance(
      profileId: profileId,
      isPremium: false,
      now: DateTime(2026, 2, 8, 23, 59, 0),
    );
    // 1 minute of call should count on Feb 8.
    expect(allowanceAtEndOfDay.usedTodaySeconds, 60);

    final allowanceAtNextDay = await service.getVoiceCallAllowance(
      profileId: profileId,
      isPremium: false,
      now: DateTime(2026, 2, 9, 0, 4, 0),
    );
    // 3 minutes of call should count on Feb 9.
    expect(allowanceAtNextDay.usedTodaySeconds, 180);
  });

  test('released quota reservation restores chat availability', () async {
    final db = DatabaseService();
    final service = AIUsageLimitService(databaseService: db);
    final profileId = await createProfile('Reservation Kid');
    final now = DateTime(2026, 2, 8, 10, 0);

    for (int i = 0; i < 29; i++) {
      await db.insertAiUsageEvent(
        profileId: profileId,
        feature: 'ai_chat_message',
        timestamp: now.subtract(Duration(minutes: i + 1)),
      );
    }

    final reservation = await service.reserveCountQuota(
      profileId: profileId,
      isPremium: false,
      feature: AiCountFeature.chatMessage,
      now: now,
    );
    expect(reservation, isNotNull);

    var status = await service.getCountQuotaStatus(
      profileId: profileId,
      isPremium: false,
      feature: AiCountFeature.chatMessage,
      now: now,
    );
    expect(status.allowed, isFalse);

    await service.releaseCountQuotaReservation(reservation!.usageEventId);

    status = await service.getCountQuotaStatus(
      profileId: profileId,
      isPremium: false,
      feature: AiCountFeature.chatMessage,
      now: now,
    );
    expect(status.allowed, isTrue);
    expect(status.usedToday, 29);
  });
}
