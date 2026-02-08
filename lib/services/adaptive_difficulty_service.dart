import 'dart:math' as math;

import 'database_service.dart';

class AdaptiveMathRecommendation {
  final String baseGrade;
  final String recommendedGrade;
  final int gradeOffset;
  final int liveDifficultySeed;
  final double averageAccuracy;
  final double averagePaceRatio;
  final int sampleSize;
  final String message;

  const AdaptiveMathRecommendation({
    required this.baseGrade,
    required this.recommendedGrade,
    required this.gradeOffset,
    required this.liveDifficultySeed,
    required this.averageAccuracy,
    required this.averagePaceRatio,
    required this.sampleSize,
    required this.message,
  });

  bool get hasRecommendationChange => gradeOffset != 0;
}

class AdaptiveDifficultyService {
  static const List<String> grades = ['Pre-K', 'K', '1st', '2nd', '3rd', '4th'];

  final DatabaseService _databaseService;

  AdaptiveDifficultyService({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService();

  Future<AdaptiveMathRecommendation> getMathRecommendation({
    required int profileId,
    required String baseGrade,
  }) async {
    final grade = _normalizeGrade(baseGrade);
    final attempts =
        await _databaseService.getMathQuizAttempts(profileId: profileId);
    final recentAttempts = attempts.take(5).toList();

    if (recentAttempts.isEmpty) {
      return AdaptiveMathRecommendation(
        baseGrade: grade,
        recommendedGrade: grade,
        gradeOffset: 0,
        liveDifficultySeed: 0,
        averageAccuracy: 0,
        averagePaceRatio: 1,
        sampleSize: 0,
        message: 'Complete a few challenges to unlock adaptive coaching.',
      );
    }

    final accuracyRatios = <double>[];
    final paceRatios = <double>[];

    for (final row in recentAttempts) {
      final numQuestions = math.max(1, _asInt(row['num_questions']));
      final numCorrect = _asInt(row['num_correct']).clamp(0, numQuestions);
      final timeLimitSeconds = math.max(60, _asInt(row['time_limit']) * 60);
      final timeUsedSeconds =
          _asInt(row['time_used']).clamp(0, timeLimitSeconds);

      accuracyRatios.add(numCorrect / numQuestions);
      paceRatios.add(timeUsedSeconds / timeLimitSeconds);
    }

    final averageAccuracy =
        accuracyRatios.reduce((a, b) => a + b) / accuracyRatios.length;
    final averagePace = paceRatios.reduce((a, b) => a + b) / paceRatios.length;

    int gradeOffset = 0;
    if (recentAttempts.length >= 2) {
      if (averageAccuracy >= 0.94 && averagePace <= 0.85) {
        gradeOffset = 2;
      } else if (averageAccuracy >= 0.84 && averagePace <= 1.05) {
        gradeOffset = 1;
      } else if (averageAccuracy <= 0.42) {
        gradeOffset = -2;
      } else if (averageAccuracy <= 0.62) {
        gradeOffset = -1;
      }
    }

    if (recentAttempts.length < 3) {
      gradeOffset = gradeOffset.clamp(-1, 1);
    }

    final recentWindow =
        accuracyRatios.take(math.min(3, accuracyRatios.length)).toList();
    final recentAverage =
        recentWindow.reduce((a, b) => a + b) / recentWindow.length;
    if (recentAverage >= 0.92 && gradeOffset < 2) {
      gradeOffset += 1;
    } else if (recentAverage <= 0.50 && gradeOffset > -2) {
      gradeOffset -= 1;
    }
    gradeOffset = gradeOffset.clamp(-2, 2);

    final recommendedGrade = _gradeWithOffset(grade, gradeOffset);
    final liveDifficultySeed = gradeOffset.clamp(-1, 1);

    return AdaptiveMathRecommendation(
      baseGrade: grade,
      recommendedGrade: recommendedGrade,
      gradeOffset: gradeOffset,
      liveDifficultySeed: liveDifficultySeed,
      averageAccuracy: averageAccuracy,
      averagePaceRatio: averagePace,
      sampleSize: recentAttempts.length,
      message: _messageForOffset(gradeOffset),
    );
  }

  String _normalizeGrade(String grade) {
    return grades.contains(grade) ? grade : '2nd';
  }

  String _gradeWithOffset(String grade, int offset) {
    final normalized = _normalizeGrade(grade);
    final baseIndex = grades.indexOf(normalized);
    final nextIndex = (baseIndex + offset).clamp(0, grades.length - 1);
    return grades[nextIndex];
  }

  int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _messageForOffset(int offset) {
    if (offset >= 2) {
      return 'You are ready to level up the challenge.';
    }
    if (offset == 1) {
      return 'Nice momentum. Try a slightly harder challenge.';
    }
    if (offset == 0) {
      return 'Great pace. Keep practicing at this level.';
    }
    if (offset == -1) {
      return 'Let us reinforce this level to build confidence.';
    }
    return 'Let us step back and rebuild fundamentals first.';
  }
}
