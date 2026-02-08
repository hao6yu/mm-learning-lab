import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../services/activity_progress_service.dart';
import '../services/ai_parental_control_service.dart';
import '../services/ai_usage_limit_service.dart';
import '../services/database_service.dart';
import '../services/subscription_service.dart';
import '../widgets/kid_screen_header.dart';

class AiUsageSnapshot {
  final bool isPremiumTier;
  final int chatUsedToday;
  final int chatDailyLimit;
  final int chatUsedThisWeek;
  final int chatWeeklyLimit;
  final int storyUsedToday;
  final int storyDailyLimit;
  final int storyUsedThisWeek;
  final int storyWeeklyLimit;
  final int callUsedTodaySeconds;
  final int callDailyLimitSeconds;
  final int callUsedThisWeekSeconds;
  final int callWeeklyLimitSeconds;
  final int callPerSessionLimitSeconds;
  final int callRemainingForNextSessionSeconds;

  const AiUsageSnapshot({
    required this.isPremiumTier,
    required this.chatUsedToday,
    required this.chatDailyLimit,
    required this.chatUsedThisWeek,
    required this.chatWeeklyLimit,
    required this.storyUsedToday,
    required this.storyDailyLimit,
    required this.storyUsedThisWeek,
    required this.storyWeeklyLimit,
    required this.callUsedTodaySeconds,
    required this.callDailyLimitSeconds,
    required this.callUsedThisWeekSeconds,
    required this.callWeeklyLimitSeconds,
    required this.callPerSessionLimitSeconds,
    required this.callRemainingForNextSessionSeconds,
  });

  const AiUsageSnapshot.empty()
      : isPremiumTier = false,
        chatUsedToday = 0,
        chatDailyLimit = 0,
        chatUsedThisWeek = 0,
        chatWeeklyLimit = 0,
        storyUsedToday = 0,
        storyDailyLimit = 0,
        storyUsedThisWeek = 0,
        storyWeeklyLimit = 0,
        callUsedTodaySeconds = 0,
        callDailyLimitSeconds = 0,
        callUsedThisWeekSeconds = 0,
        callWeeklyLimitSeconds = 0,
        callPerSessionLimitSeconds = 0,
        callRemainingForNextSessionSeconds = 0;
}

class KidProgressSummary {
  final int stars;
  final int level;
  final int mathAttempts;
  final int storiesCreated;
  final int aiChats;
  final double averageMathScore;
  final ActivityProgress? lastActivity;
  final bool badgeMathExplorer;
  final bool badgeStoryMaker;
  final bool badgeAiBuddy;
  final List<String> newlyUnlockedBadges;
  final List<int> weeklyActivity;
  final bool leveledUp;
  final AiUsageSnapshot aiUsage;

  const KidProgressSummary({
    required this.stars,
    required this.level,
    required this.mathAttempts,
    required this.storiesCreated,
    required this.aiChats,
    required this.averageMathScore,
    required this.lastActivity,
    required this.badgeMathExplorer,
    required this.badgeStoryMaker,
    required this.badgeAiBuddy,
    required this.newlyUnlockedBadges,
    required this.weeklyActivity,
    required this.leveledUp,
    this.aiUsage = const AiUsageSnapshot.empty(),
  });
}

typedef KidProgressSummaryLoader = Future<KidProgressSummary> Function(
  int profileId,
);

class KidProgressScreen extends StatefulWidget {
  const KidProgressScreen({
    super.key,
    this.loadSummary,
  });

  final KidProgressSummaryLoader? loadSummary;

  @override
  State<KidProgressScreen> createState() => _KidProgressScreenState();
}

class _KidProgressScreenState extends State<KidProgressScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final ActivityProgressService _activityProgressService =
      ActivityProgressService();
  final AIUsageLimitService _aiUsageLimitService = AIUsageLimitService();
  final AiParentalControlService _aiParentalControlService =
      AiParentalControlService();

  int? _selectedProfileId;
  bool _isPremiumUser = false;
  Future<KidProgressSummary>? _summaryFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextProfileId = context.read<ProfileProvider>().selectedProfileId;
    bool nextPremiumState = false;
    try {
      final service = Provider.of<SubscriptionService>(context, listen: false);
      nextPremiumState = service.isSubscribed;
    } catch (_) {
      nextPremiumState = false;
    }
    if (_selectedProfileId == nextProfileId &&
        _isPremiumUser == nextPremiumState) {
      return;
    }

    _selectedProfileId = nextProfileId;
    _isPremiumUser = nextPremiumState;
    if (nextProfileId == null) {
      _summaryFuture = null;
      return;
    }

    final loader = widget.loadSummary ?? _loadSummary;
    _summaryFuture = loader(nextProfileId);
  }

  Future<KidProgressSummary> _loadSummary(int profileId) async {
    final isPremium = _isPremiumUser;
    final results = await Future.wait<dynamic>([
      _databaseService.getMathQuizAttemptCount(profileId: profileId),
      _databaseService.getMathQuizAverageScorePercent(profileId: profileId),
      _databaseService.getUserCreatedStoryCount(profileId: profileId),
      _databaseService.getChatMessageCount(profileId: profileId),
      _activityProgressService.getLastActivity(profileId),
      _databaseService.getProfileProgress(profileId: profileId),
      _databaseService.getWeeklyLearningActivityCounts(profileId: profileId),
      _aiUsageLimitService.getCountQuotaStatus(
        profileId: profileId,
        isPremium: isPremium,
        feature: AiCountFeature.chatMessage,
      ),
      _aiUsageLimitService.getCountQuotaStatus(
        profileId: profileId,
        isPremium: isPremium,
        feature: AiCountFeature.storyGeneration,
      ),
      _aiUsageLimitService.getVoiceCallAllowance(
        profileId: profileId,
        isPremium: isPremium,
      ),
      _aiParentalControlService.getControls(profileId),
    ]);

    final mathAttempts = results[0] as int;
    final averageMathScore = results[1] as double;
    final storiesCreated = results[2] as int;
    final aiChats = results[3] as int;
    final lastActivity = results[4] as ActivityProgress?;
    final stored = results[5] as Map<String, dynamic>;
    final weeklyActivity = (results[6] as List<int>);
    final chatQuota = results[7] as AiQuotaCheckResult;
    final storyQuota = results[8] as AiQuotaCheckResult;
    final callAllowance = results[9] as AiCallAllowance;
    final controls = results[10] as AiParentalControls;
    final overrideSeconds = controls.maxCallMinutesOverride == null
        ? null
        : controls.maxCallMinutesOverride! * 60;
    final effectivePerSessionCap = overrideSeconds == null
        ? callAllowance.perCallLimitSeconds
        : math.min(callAllowance.perCallLimitSeconds, overrideSeconds);
    final effectiveRemainingForNextCall = math.min(
        callAllowance.remainingForThisCallSeconds, effectivePerSessionCap);

    final storedStars = _asInt(stored['stars'], fallback: 0);
    final storedLevel = _asInt(stored['level'], fallback: 1);
    final storedMathBadge = _asInt(stored['badge_math_explorer']) == 1;
    final storedStoryBadge = _asInt(stored['badge_story_maker']) == 1;
    final storedAiBadge = _asInt(stored['badge_ai_buddy']) == 1;

    final computedStars = _calculateStars(
      mathAttempts: mathAttempts,
      storiesCreated: storiesCreated,
      aiChats: aiChats,
      averageMathScore: averageMathScore,
    );

    final computedMathBadge = mathAttempts >= 3;
    final computedStoryBadge = storiesCreated >= 1;
    final computedAiBadge = aiChats >= 5;

    final badgeMathExplorer = storedMathBadge || computedMathBadge;
    final badgeStoryMaker = storedStoryBadge || computedStoryBadge;
    final badgeAiBuddy = storedAiBadge || computedAiBadge;

    final newlyUnlockedBadges = <String>[];
    if (computedMathBadge && !storedMathBadge) {
      newlyUnlockedBadges.add('Math Explorer');
    }
    if (computedStoryBadge && !storedStoryBadge) {
      newlyUnlockedBadges.add('Story Maker');
    }
    if (computedAiBadge && !storedAiBadge) {
      newlyUnlockedBadges.add('AI Buddy');
    }

    final stars = math.max(storedStars, computedStars);
    final level = math.max(storedLevel, 1 + (stars ~/ 25));
    final leveledUp = level > storedLevel;

    final shouldPersist = stars != storedStars ||
        level != storedLevel ||
        badgeMathExplorer != storedMathBadge ||
        badgeStoryMaker != storedStoryBadge ||
        badgeAiBuddy != storedAiBadge;

    if (shouldPersist) {
      await _databaseService.upsertProfileProgress(
        profileId: profileId,
        stars: stars,
        level: level,
        badgeMathExplorer: badgeMathExplorer,
        badgeStoryMaker: badgeStoryMaker,
        badgeAiBuddy: badgeAiBuddy,
      );
    }

    return KidProgressSummary(
      stars: stars,
      level: level,
      mathAttempts: mathAttempts,
      storiesCreated: storiesCreated,
      aiChats: aiChats,
      averageMathScore: averageMathScore,
      lastActivity: lastActivity,
      badgeMathExplorer: badgeMathExplorer,
      badgeStoryMaker: badgeStoryMaker,
      badgeAiBuddy: badgeAiBuddy,
      newlyUnlockedBadges: newlyUnlockedBadges,
      weeklyActivity: _normalizeWeeklySeries(weeklyActivity),
      leveledUp: leveledUp,
      aiUsage: AiUsageSnapshot(
        isPremiumTier: isPremium,
        chatUsedToday: chatQuota.usedToday,
        chatDailyLimit: chatQuota.dailyLimit,
        chatUsedThisWeek: chatQuota.usedThisWeek,
        chatWeeklyLimit: chatQuota.weeklyLimit,
        storyUsedToday: storyQuota.usedToday,
        storyDailyLimit: storyQuota.dailyLimit,
        storyUsedThisWeek: storyQuota.usedThisWeek,
        storyWeeklyLimit: storyQuota.weeklyLimit,
        callUsedTodaySeconds: callAllowance.usedTodaySeconds,
        callDailyLimitSeconds: callAllowance.usedTodaySeconds +
            callAllowance.remainingTodaySeconds,
        callUsedThisWeekSeconds: callAllowance.usedThisWeekSeconds,
        callWeeklyLimitSeconds: callAllowance.usedThisWeekSeconds +
            callAllowance.remainingThisWeekSeconds,
        callPerSessionLimitSeconds: effectivePerSessionCap,
        callRemainingForNextSessionSeconds: effectiveRemainingForNextCall,
      ),
    );
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  List<int> _normalizeWeeklySeries(List<int> source) {
    if (source.length == 7) {
      return source;
    }

    final copy = List<int>.filled(7, 0);
    for (int i = 0; i < math.min(source.length, 7); i++) {
      copy[i] = source[i];
    }
    return copy;
  }

  int _calculateStars({
    required int mathAttempts,
    required int storiesCreated,
    required int aiChats,
    required double averageMathScore,
  }) {
    final scoreBonus = (averageMathScore / 10).round();
    final total =
        (mathAttempts * 2) + (storiesCreated * 3) + aiChats + scoreBonus;
    return total.clamp(0, 999);
  }

  String _profileName() {
    final provider = context.read<ProfileProvider>();
    final selectedId = provider.selectedProfileId;
    if (selectedId == null) {
      return 'Learner';
    }

    for (final profile in provider.profiles) {
      if (profile.id == selectedId) {
        return profile.name;
      }
    }

    return 'Learner';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final isTablet = math.min(size.width, size.height) >= 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFB6E6FF), Color(0xFFFFF8D6)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              KidScreenHeader(
                title: 'My Progress',
                isTablet: isTablet,
                onBack: () => Navigator.pop(context),
                onHome: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
              Expanded(
                child: _buildBody(isTablet: isTablet, isLandscape: isLandscape),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody({required bool isTablet, required bool isLandscape}) {
    if (_selectedProfileId == null || _summaryFuture == null) {
      return Center(
        child: Text(
          'Pick a profile first to see progress.',
          style: TextStyle(
            fontFamily: 'Baloo2',
            fontSize: isTablet ? 24 : 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF4A5D73),
          ),
        ),
      );
    }

    return FutureBuilder<KidProgressSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load progress right now.',
              style: TextStyle(
                fontFamily: 'Baloo2',
                fontSize: isTablet ? 22 : 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4A5D73),
              ),
            ),
          );
        }

        final summary = snapshot.data!;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24 : 14,
            vertical: isTablet ? 16 : 10,
          ),
          child: isTablet && isLandscape
              ? _buildLandscapeContent(summary, isTablet: isTablet)
              : _buildPortraitContent(summary, isTablet: isTablet),
        );
      },
    );
  }

  Widget _buildLandscapeContent(KidProgressSummary summary,
      {required bool isTablet}) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: _buildHeroCard(summary, isTablet: isTablet),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            child: _buildStatsAndBadges(summary, isTablet: isTablet),
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitContent(KidProgressSummary summary,
      {required bool isTablet}) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeroCard(summary, isTablet: isTablet),
          const SizedBox(height: 12),
          _buildStatsAndBadges(summary, isTablet: isTablet),
        ],
      ),
    );
  }

  Widget _buildHeroCard(KidProgressSummary summary, {required bool isTablet}) {
    final starsToNextLevel = 25 - (summary.stars % 25);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 20 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E6CFF).withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '${_profileName()}\'s Star Board',
            style: TextStyle(
              fontFamily: 'Baloo2',
              fontSize: isTablet ? 28 : 22,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF8E6CFF),
            ),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: (summary.stars - 10).clamp(0, 999).toDouble(),
              end: summary.stars.toDouble(),
            ),
            duration: Duration(milliseconds: summary.leveledUp ? 950 : 500),
            builder: (context, animatedStars, child) {
              final scaleEnd = summary.leveledUp ? 1.07 : 1.0;
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.94, end: scaleEnd),
                duration: const Duration(milliseconds: 600),
                builder: (context, scale, content) {
                  return Transform.scale(scale: scale, child: content);
                },
                child: Text(
                  '⭐ ${animatedStars.round()} Stars   •   Level ${summary.level}',
                  style: TextStyle(
                    fontFamily: 'Baloo2',
                    fontSize: isTablet ? 22 : 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFF9F43),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Only $starsToNextLevel more stars to the next level!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Baloo2',
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4A5D73),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: LinearProgressIndicator(
              minHeight: isTablet ? 16 : 12,
              value: (summary.stars % 25) / 25,
              backgroundColor: const Color(0xFFEDECFD),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF43C465)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsAndBadges(KidProgressSummary summary,
      {required bool isTablet}) {
    final statItems = [
      _StatData(
        title: 'Math Quizzes',
        value: '${summary.mathAttempts}',
        subtitle: 'completed',
        color: const Color(0xFF43C465),
      ),
      _StatData(
        title: 'Average Score',
        value: '${summary.averageMathScore.round()}%',
        subtitle: 'math accuracy',
        color: const Color(0xFFFF9F43),
      ),
      _StatData(
        title: 'Stories Made',
        value: '${summary.storiesCreated}',
        subtitle: 'created by you',
        color: const Color(0xFF8E6CFF),
      ),
      _StatData(
        title: 'AI Chats',
        value: '${summary.aiChats}',
        subtitle: 'conversations',
        color: const Color(0xFF3ED6C1),
      ),
    ];

    return Column(
      children: [
        if (summary.leveledUp || summary.newlyUnlockedBadges.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CelebrationCard(
              isTablet: isTablet,
              leveledUp: summary.leveledUp,
              newBadges: summary.newlyUnlockedBadges,
            ),
          ),
        GridView.builder(
          itemCount: statItems.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: isTablet ? 12 : 10,
            mainAxisSpacing: isTablet ? 12 : 10,
            mainAxisExtent: isTablet ? 128 : 112,
          ),
          itemBuilder: (context, index) {
            final stat = statItems[index];
            return _StatCard(
              title: stat.title,
              value: stat.value,
              subtitle: stat.subtitle,
              color: stat.color,
            );
          },
        ),
        const SizedBox(height: 12),
        _AiUsageCard(summary: summary, isTablet: isTablet),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.center,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/ai-limits'),
            icon: const Icon(Icons.settings_suggest_rounded),
            label: const Text('Open Full AI Limits'),
          ),
        ),
        const SizedBox(height: 12),
        _WeeklyActivityCard(
          isTablet: isTablet,
          series: summary.weeklyActivity,
        ),
        const SizedBox(height: 12),
        _BadgesCard(summary: summary, isTablet: isTablet),
        if (summary.lastActivity != null) ...[
          const SizedBox(height: 12),
          Text(
            'Last played: ${summary.lastActivity!.activityTitle}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Baloo2',
              fontSize: isTablet ? 17 : 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4A5D73),
            ),
          ),
        ],
      ],
    );
  }
}

class _CelebrationCard extends StatelessWidget {
  final bool isTablet;
  final bool leveledUp;
  final List<String> newBadges;

  const _CelebrationCard({
    required this.isTablet,
    required this.leveledUp,
    required this.newBadges,
  });

  @override
  Widget build(BuildContext context) {
    final text = <String>[];
    if (leveledUp) {
      text.add('Level up!');
    }
    if (newBadges.isNotEmpty) {
      text.add('New badge: ${newBadges.join(', ')}');
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.92, end: 1.0),
      duration: const Duration(milliseconds: 450),
      builder: (context, scale, child) {
        return Opacity(
          opacity: scale,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 14 : 10,
          vertical: isTablet ? 10 : 8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0CC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFC96B), width: 1.3),
        ),
        child: Row(
          children: [
            const Icon(Icons.celebration_rounded, color: Color(0xFFFF9F43)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text.join(' • '),
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: isTablet ? 15 : 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF8A5A00),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyActivityCard extends StatelessWidget {
  final bool isTablet;
  final List<int> series;

  const _WeeklyActivityCard({
    required this.isTablet,
    required this.series,
  });

  @override
  Widget build(BuildContext context) {
    final maxCount = series.fold<int>(1, (maxValue, item) {
      return item > maxValue ? item : maxValue;
    });

    final now = DateTime.now();
    final labels = List<String>.generate(7, (index) {
      final day = now.subtract(Duration(days: 6 - index));
      const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      return names[day.weekday - 1];
    });

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 12 : 10,
        vertical: isTablet ? 10 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This Week',
            style: TextStyle(
              fontFamily: 'Baloo2',
              fontSize: isTablet ? 19 : 16,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF5B6B7F),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: isTablet ? 92 : 76,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final count = series[index];
                final ratio = count / maxCount;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isTablet) ...[
                          Text(
                            '$count',
                            style: const TextStyle(
                              fontFamily: 'Baloo2',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6F7C8C),
                            ),
                          ),
                          const SizedBox(height: 3),
                        ],
                        Container(
                          height: (isTablet ? 50 : 46) * ratio.clamp(0.0, 1.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5AA9FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          labels[index],
                          style: TextStyle(
                            fontFamily: 'Baloo2',
                            fontSize: isTablet ? 12 : 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF6F7C8C),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 130;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: color.withValues(alpha: 0.45), width: 1.4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF4A5D73),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: compact ? 20 : 24,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: compact ? 10 : 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6E7B8A),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatData {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _StatData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });
}

class _AiUsageCard extends StatelessWidget {
  final KidProgressSummary summary;
  final bool isTablet;

  const _AiUsageCard({
    required this.summary,
    required this.isTablet,
  });

  String _formatDurationMinutes(int seconds) {
    final minutes = (seconds / 60).floor();
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final usage = summary.aiUsage;
    final titleColor =
        usage.isPremiumTier ? const Color(0xFF1D8B5A) : const Color(0xFF5B6B7F);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 14 : 10,
        vertical: isTablet ? 12 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights_rounded,
                color: titleColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  usage.isPremiumTier ? 'Premium AI Usage' : 'Free AI Usage',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Baloo2',
                    fontSize: isTablet ? 20 : 16,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AiUsageLine(
            isTablet: isTablet,
            label: 'AI Chat',
            todayText: '${usage.chatUsedToday}/${usage.chatDailyLimit} today',
            weekText:
                '${usage.chatUsedThisWeek}/${usage.chatWeeklyLimit} this week',
            ratioToday: usage.chatDailyLimit == 0
                ? 0
                : usage.chatUsedToday / usage.chatDailyLimit,
            color: const Color(0xFF3ED6C1),
          ),
          const SizedBox(height: 8),
          _AiUsageLine(
            isTablet: isTablet,
            label: 'AI Stories',
            todayText: '${usage.storyUsedToday}/${usage.storyDailyLimit} today',
            weekText:
                '${usage.storyUsedThisWeek}/${usage.storyWeeklyLimit} this week',
            ratioToday: usage.storyDailyLimit == 0
                ? 0
                : usage.storyUsedToday / usage.storyDailyLimit,
            color: const Color(0xFF8E6CFF),
          ),
          const SizedBox(height: 8),
          _AiUsageLine(
            isTablet: isTablet,
            label: 'AI Calls',
            todayText:
                '${_formatDurationMinutes(usage.callUsedTodaySeconds)}/${_formatDurationMinutes(usage.callDailyLimitSeconds)} today',
            weekText:
                '${_formatDurationMinutes(usage.callUsedThisWeekSeconds)}/${_formatDurationMinutes(usage.callWeeklyLimitSeconds)} this week',
            ratioToday: usage.callDailyLimitSeconds == 0
                ? 0
                : usage.callUsedTodaySeconds / usage.callDailyLimitSeconds,
            color: const Color(0xFF5AA9FF),
          ),
          const SizedBox(height: 10),
          Text(
            'Next call max: ${_formatDurationMinutes(usage.callRemainingForNextSessionSeconds)} '
            '(session cap ${_formatDurationMinutes(usage.callPerSessionLimitSeconds)})',
            style: TextStyle(
              fontFamily: 'Baloo2',
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4A5D73),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiUsageLine extends StatelessWidget {
  final bool isTablet;
  final String label;
  final String todayText;
  final String weekText;
  final double ratioToday;
  final Color color;

  const _AiUsageLine({
    required this.isTablet,
    required this.label,
    required this.todayText,
    required this.weekText,
    required this.ratioToday,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final clampedRatio = ratioToday.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF334155),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                todayText,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: isTablet ? 13 : 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4A5D73),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            minHeight: isTablet ? 8 : 7,
            value: clampedRatio,
            backgroundColor: const Color(0xFFE6EEF8),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          weekText,
          style: TextStyle(
            fontFamily: 'Baloo2',
            fontSize: isTablet ? 12 : 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6E7B8A),
          ),
        ),
      ],
    );
  }
}

class _BadgesCard extends StatelessWidget {
  final KidProgressSummary summary;
  final bool isTablet;

  const _BadgesCard({required this.summary, required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final newBadgeSet = summary.newlyUnlockedBadges.toSet();
    final badges = [
      _BadgeData(
        label: 'Math Explorer',
        unlocked: summary.badgeMathExplorer,
        color: const Color(0xFF43C465),
        isNew: newBadgeSet.contains('Math Explorer'),
      ),
      _BadgeData(
        label: 'Story Maker',
        unlocked: summary.badgeStoryMaker,
        color: const Color(0xFF8E6CFF),
        isNew: newBadgeSet.contains('Story Maker'),
      ),
      _BadgeData(
        label: 'AI Buddy',
        unlocked: summary.badgeAiBuddy,
        color: const Color(0xFF3ED6C1),
        isNew: newBadgeSet.contains('AI Buddy'),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 14 : 10,
        vertical: isTablet ? 12 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            'Badges',
            style: TextStyle(
              fontFamily: 'Baloo2',
              fontSize: isTablet ? 20 : 17,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF8E6CFF),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: badges
                .map(
                  (badge) => Chip(
                    backgroundColor: badge.unlocked
                        ? badge.color.withValues(alpha: 0.2)
                        : const Color(0xFFE6EBF2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity:
                        const VisualDensity(horizontal: -2, vertical: -2),
                    side: BorderSide(
                      color: badge.unlocked
                          ? badge.color.withValues(alpha: 0.65)
                          : const Color(0xFFC4CED9),
                    ),
                    avatar: Icon(
                      badge.unlocked ? Icons.verified : Icons.lock_outline,
                      size: 16,
                      color: badge.unlocked
                          ? badge.color
                          : const Color(0xFF8B97A7),
                    ),
                    label: Text(
                      badge.isNew ? '${badge.label} +' : badge.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Baloo2',
                        fontWeight: FontWeight.w800,
                        color: badge.unlocked
                            ? const Color(0xFF334155)
                            : const Color(0xFF8B97A7),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _BadgeData {
  final String label;
  final bool unlocked;
  final Color color;
  final bool isNew;

  const _BadgeData({
    required this.label,
    required this.unlocked,
    required this.color,
    this.isNew = false,
  });
}
