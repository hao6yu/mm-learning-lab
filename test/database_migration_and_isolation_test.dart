import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mm_learning_lab/models/profile.dart';
import 'package:mm_learning_lab/models/story.dart';
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

  test('v6 -> v7 migration backfills legacy data to existing first profile',
      () async {
    final dbPath = join(await getDatabasesPath(), 'mm_learning_lab.db');

    final legacyDb = await openDatabase(
      dbPath,
      version: 6,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE profiles(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            age INTEGER NOT NULL,
            avatar TEXT NOT NULL,
            avatar_type TEXT DEFAULT 'emoji',
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE math_quiz_attempts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            datetime TEXT NOT NULL,
            grade TEXT NOT NULL,
            operations TEXT NOT NULL,
            num_questions INTEGER NOT NULL,
            time_limit INTEGER NOT NULL,
            num_correct INTEGER NOT NULL,
            time_used INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE stories(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            emoji TEXT,
            category TEXT NOT NULL,
            difficulty TEXT NOT NULL,
            word_of_day TEXT,
            is_user_created INTEGER DEFAULT 0,
            audio_path TEXT
          )
        ''');
      },
    );

    final legacyProfileId = await legacyDb.insert('profiles', {
      'name': 'Legacy Kid',
      'age': 7,
      'avatar': '👦',
      'avatar_type': 'emoji',
      'created_at': DateTime.now().toIso8601String(),
    });

    await legacyDb.insert('math_quiz_attempts', {
      'datetime': DateTime.now().toIso8601String(),
      'grade': '2nd',
      'operations': '+',
      'num_questions': 10,
      'time_limit': 3,
      'num_correct': 9,
      'time_used': 95,
    });

    await legacyDb.insert('stories', {
      'title': 'Legacy Custom Story',
      'content': 'Once upon a time',
      'emoji': '📘',
      'category': 'Adventure',
      'difficulty': 'Easy',
      'is_user_created': 1,
    });

    await legacyDb.insert('stories', {
      'title': 'Default Shared Story',
      'content': 'Shared story',
      'emoji': '📖',
      'category': 'Adventure',
      'difficulty': 'Easy',
      'is_user_created': 0,
    });

    await legacyDb.close();

    final upgradedDb = await DatabaseService().database;

    final mathColumns =
        await upgradedDb.rawQuery('PRAGMA table_info(math_quiz_attempts)');
    final storyColumns =
        await upgradedDb.rawQuery('PRAGMA table_info(stories)');

    expect(
      mathColumns.any((column) => column['name'] == 'profile_id'),
      isTrue,
    );
    expect(
      storyColumns.any((column) => column['name'] == 'profile_id'),
      isTrue,
    );

    final migratedMath = await upgradedDb.query('math_quiz_attempts');
    expect(migratedMath.single['profile_id'], legacyProfileId);

    final migratedCustomStory = await upgradedDb.query(
      'stories',
      where: 'title = ?',
      whereArgs: ['Legacy Custom Story'],
    );
    expect(migratedCustomStory.single['profile_id'], legacyProfileId);

    final migratedDefaultStory = await upgradedDb.query(
      'stories',
      where: 'title = ?',
      whereArgs: ['Default Shared Story'],
    );
    expect(migratedDefaultStory.single['profile_id'], isNull);
  });

  test('migration creates fallback profile when legacy DB has none', () async {
    final dbPath = join(await getDatabasesPath(), 'mm_learning_lab.db');

    final legacyDb = await openDatabase(
      dbPath,
      version: 6,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE profiles(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            age INTEGER NOT NULL,
            avatar TEXT NOT NULL,
            avatar_type TEXT DEFAULT 'emoji',
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE math_quiz_attempts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            datetime TEXT NOT NULL,
            grade TEXT NOT NULL,
            operations TEXT NOT NULL,
            num_questions INTEGER NOT NULL,
            time_limit INTEGER NOT NULL,
            num_correct INTEGER NOT NULL,
            time_used INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE stories(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            emoji TEXT,
            category TEXT NOT NULL,
            difficulty TEXT NOT NULL,
            word_of_day TEXT,
            is_user_created INTEGER DEFAULT 0,
            audio_path TEXT
          )
        ''');
      },
    );

    await legacyDb.insert('math_quiz_attempts', {
      'datetime': DateTime.now().toIso8601String(),
      'grade': '2nd',
      'operations': '+',
      'num_questions': 5,
      'time_limit': 2,
      'num_correct': 5,
      'time_used': 40,
    });

    await legacyDb.insert('stories', {
      'title': 'Orphan Legacy Story',
      'content': 'Legacy text',
      'emoji': '📘',
      'category': 'Adventure',
      'difficulty': 'Easy',
      'is_user_created': 1,
    });

    await legacyDb.close();

    final upgradedDb = await DatabaseService().database;

    final profiles = await upgradedDb.query('profiles');
    expect(profiles, isNotEmpty);

    final fallbackProfile = profiles.first;
    expect(fallbackProfile['name'], 'Legacy Learner');
    final fallbackId = fallbackProfile['id'];

    final migratedMath = await upgradedDb.query('math_quiz_attempts');
    expect(migratedMath.single['profile_id'], fallbackId);

    final migratedStory = await upgradedDb.query(
      'stories',
      where: 'title = ?',
      whereArgs: ['Orphan Legacy Story'],
    );
    expect(migratedStory.single['profile_id'], fallbackId);
  });

  test('v7 -> v8 migration creates profile_progress for existing profiles',
      () async {
    final dbPath = join(await getDatabasesPath(), 'mm_learning_lab.db');

    final legacyDb = await openDatabase(
      dbPath,
      version: 7,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE profiles(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            age INTEGER NOT NULL,
            avatar TEXT NOT NULL,
            avatar_type TEXT DEFAULT 'emoji',
            created_at TEXT NOT NULL
          )
        ''');
      },
    );

    final p1 = await legacyDb.insert('profiles', {
      'name': 'Kid One',
      'age': 6,
      'avatar': '👧',
      'avatar_type': 'emoji',
      'created_at': DateTime.now().toIso8601String(),
    });
    final p2 = await legacyDb.insert('profiles', {
      'name': 'Kid Two',
      'age': 8,
      'avatar': '👦',
      'avatar_type': 'emoji',
      'created_at': DateTime.now().toIso8601String(),
    });

    await legacyDb.close();

    final upgradedDb = await DatabaseService().database;
    final progressRows = await upgradedDb.query('profile_progress');
    expect(progressRows.length, 2);

    final byProfile = {
      for (final row in progressRows) row['profile_id'] as int: row,
    };

    expect(byProfile.containsKey(p1), isTrue);
    expect(byProfile.containsKey(p2), isTrue);
    expect(byProfile[p1]!['stars'], 0);
    expect(byProfile[p2]!['stars'], 0);
    expect(byProfile[p1]!['level'], 1);
    expect(byProfile[p2]!['level'], 1);
    expect(byProfile[p1]!['badge_math_explorer'], 0);
    expect(byProfile[p2]!['badge_ai_buddy'], 0);
  });

  test('service methods enforce per-profile data isolation', () async {
    final service = DatabaseService();

    final profile1Id = await service.insertProfile(
      Profile(name: 'Kid One', age: 6, avatar: '👧'),
    );
    final profile2Id = await service.insertProfile(
      Profile(name: 'Kid Two', age: 8, avatar: '👦'),
    );

    final story1Id = await service.insertStory(
      Story(
        title: 'P1 Story',
        content: 'Only for profile 1',
        emoji: '📗',
        category: 'Adventure',
        difficulty: 'Easy',
        isUserCreated: true,
        profileId: profile1Id,
      ),
    );

    await service.insertStory(
      Story(
        title: 'P2 Story',
        content: 'Only for profile 2',
        emoji: '📘',
        category: 'Adventure',
        difficulty: 'Easy',
        isUserCreated: true,
        profileId: profile2Id,
      ),
    );

    final p1Stories = await service.getStories(profileId: profile1Id);
    final p2Stories = await service.getStories(profileId: profile2Id);

    expect(p1Stories.any((story) => story.title == 'P1 Story'), isTrue);
    expect(p1Stories.any((story) => story.title == 'P2 Story'), isFalse);
    expect(p2Stories.any((story) => story.title == 'P2 Story'), isTrue);
    expect(p2Stories.any((story) => story.title == 'P1 Story'), isFalse);

    final wrongUpdateCount = await service.updateStory(
      Story(
        id: story1Id,
        title: 'Wrong Update',
        content: 'Should not update',
        emoji: '📙',
        category: 'Adventure',
        difficulty: 'Easy',
        isUserCreated: true,
        profileId: profile1Id,
      ),
      profileId: profile2Id,
    );
    expect(wrongUpdateCount, 0);

    final wrongDeleteCount =
        await service.deleteStory(story1Id, profileId: profile2Id);
    expect(wrongDeleteCount, 0);

    final correctDeleteCount =
        await service.deleteStory(story1Id, profileId: profile1Id);
    expect(correctDeleteCount, 1);

    await service.insertMathQuizAttempt(
      grade: '2nd',
      operations: '+',
      numQuestions: 10,
      timeLimit: 3,
      numCorrect: 8,
      timeUsed: 88,
      profileId: profile1Id,
    );
    await service.insertMathQuizAttempt(
      grade: '2nd',
      operations: '−',
      numQuestions: 10,
      timeLimit: 3,
      numCorrect: 7,
      timeUsed: 92,
      profileId: profile2Id,
    );

    final p1Attempts = await service.getMathQuizAttempts(profileId: profile1Id);
    final p2Attempts = await service.getMathQuizAttempts(profileId: profile2Id);

    expect(p1Attempts, isNotEmpty);
    expect(p2Attempts, isNotEmpty);
    expect(
      p1Attempts.every((attempt) => attempt['profile_id'] == profile1Id),
      isTrue,
    );
    expect(
      p2Attempts.every((attempt) => attempt['profile_id'] == profile2Id),
      isTrue,
    );
  });
}
