import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mm_learning_lab/models/profile.dart';
import 'package:mm_learning_lab/services/adaptive_difficulty_service.dart';
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

  test('returns neutral recommendation when there are no attempts', () async {
    final db = DatabaseService();
    final profileId = await db.insertProfile(
      Profile(name: 'Ava', age: 7, avatar: '👧'),
    );

    final recommendation = await AdaptiveDifficultyService()
        .getMathRecommendation(profileId: profileId, baseGrade: '2nd');

    expect(recommendation.recommendedGrade, '2nd');
    expect(recommendation.gradeOffset, 0);
    expect(recommendation.sampleSize, 0);
    expect(recommendation.liveDifficultySeed, 0);
  });

  test('recommends harder grade for consistently high performance', () async {
    final db = DatabaseService();
    final profileId = await db.insertProfile(
      Profile(name: 'Noah', age: 8, avatar: '👦'),
    );

    await db.insertMathQuizAttempt(
      grade: '2nd',
      operations: '+,−',
      numQuestions: 10,
      timeLimit: 3,
      numCorrect: 10,
      timeUsed: 110,
      profileId: profileId,
    );
    await db.insertMathQuizAttempt(
      grade: '2nd',
      operations: '+,−',
      numQuestions: 10,
      timeLimit: 3,
      numCorrect: 9,
      timeUsed: 120,
      profileId: profileId,
    );

    final recommendation = await AdaptiveDifficultyService()
        .getMathRecommendation(profileId: profileId, baseGrade: '2nd');

    expect(recommendation.gradeOffset, greaterThan(0));
    expect(recommendation.recommendedGrade, '4th');
    expect(recommendation.liveDifficultySeed, 1);
  });

  test('recommends easier grade when recent accuracy is low', () async {
    final db = DatabaseService();
    final profileId = await db.insertProfile(
      Profile(name: 'Mia', age: 9, avatar: '🧒'),
    );

    for (int i = 0; i < 3; i++) {
      await db.insertMathQuizAttempt(
        grade: '3rd',
        operations: '+,−,×',
        numQuestions: 10,
        timeLimit: 3,
        numCorrect: 3,
        timeUsed: 170,
        profileId: profileId,
      );
    }

    final recommendation = await AdaptiveDifficultyService()
        .getMathRecommendation(profileId: profileId, baseGrade: '3rd');

    expect(recommendation.gradeOffset, lessThan(0));
    expect(recommendation.recommendedGrade, '1st');
    expect(recommendation.liveDifficultySeed, -1);
  });
}
