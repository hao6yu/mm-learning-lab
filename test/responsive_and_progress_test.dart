import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mm_learning_lab/models/profile.dart';
import 'package:mm_learning_lab/providers/profile_provider.dart';
import 'package:mm_learning_lab/screens/kid_progress_screen.dart';
import 'package:mm_learning_lab/screens/profile_selection_screen.dart';
import 'package:mm_learning_lab/services/subscription_service.dart';
import 'package:mm_learning_lab/utils/activity_launcher.dart';

class _FakeSubscriptionService extends ChangeNotifier
    implements SubscriptionService {
  _FakeSubscriptionService({required this.subscribed});

  final bool subscribed;

  @override
  bool get isSubscribed => subscribed;

  @override
  bool get isLoading => false;

  @override
  List<ProductDetails> get products => const [];

  @override
  String? get errorMessage => null;

  @override
  bool get isDebugBypassActive => false;

  @override
  Future<bool> hasActiveAccess({bool refreshSubscription = true}) async {
    return subscribed;
  }

  @override
  Future<int> getDaysLeftInTrial() async {
    return 14;
  }

  @override
  Future<void> subscribe() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _FakeProfileProvider extends ChangeNotifier implements ProfileProvider {
  _FakeProfileProvider({
    required List<Profile> profiles,
    required int? selectedProfileId,
  })  : _profiles = profiles,
        _selectedProfileId = selectedProfileId;

  final List<Profile> _profiles;
  int? _selectedProfileId;

  @override
  List<Profile> get profiles => _profiles;

  @override
  int? get selectedProfileId => _selectedProfileId;

  @override
  Future<void> loadProfiles() async {}

  @override
  void selectProfile(int? id) {
    _selectedProfileId = id;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

Future<void> _pumpFrames(WidgetTester tester,
    {int count = 8, Duration step = const Duration(milliseconds: 100)}) async {
  for (int i = 0; i < count; i++) {
    await tester.pump(step);
  }
}

Widget _buildProfileSelectionHarness({
  required ProfileProvider profileProvider,
  required SubscriptionService subscriptionService,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
      ChangeNotifierProvider<SubscriptionService>.value(
          value: subscriptionService),
    ],
    child: const MaterialApp(
      home: ProfileSelectionScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile selection supports phone portrait layout',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    const profileId = 1;
    SharedPreferences.setMockInitialValues({
      'last_activity_profile_$profileId': jsonEncode({
        'activity_id': ActivityIds.letterTracing,
        'activity_title': activityTitle(ActivityIds.letterTracing),
        'played_at': DateTime.now().toIso8601String(),
      }),
    });

    final profileProvider = _FakeProfileProvider(
      profiles: [
        Profile(id: profileId, name: 'Ava', age: 7, avatar: '👧'),
      ],
      selectedProfileId: profileId,
    );

    final subscription = _FakeSubscriptionService(subscribed: true);

    await tester.pumpWidget(
      _buildProfileSelectionHarness(
        profileProvider: profileProvider,
        subscriptionService: subscription,
      ),
    );
    await _pumpFrames(tester, count: 10);

    expect(find.textContaining('Welcome'), findsOneWidget);
    expect(find.text('My Progress'), findsOneWidget);
    expect(find.text('ABC'), findsOneWidget);
    expect(find.text('123'), findsOneWidget);
    expect(find.text('Games'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile selection supports tablet landscape layout',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    const profileId = 1;
    SharedPreferences.setMockInitialValues({
      'last_activity_profile_$profileId': jsonEncode({
        'activity_id': ActivityIds.letterTracing,
        'activity_title': activityTitle(ActivityIds.letterTracing),
        'played_at': DateTime.now().toIso8601String(),
      }),
    });

    final profileProvider = _FakeProfileProvider(
      profiles: [
        Profile(id: profileId, name: 'Ava', age: 7, avatar: '👧'),
      ],
      selectedProfileId: profileId,
    );

    final subscription = _FakeSubscriptionService(subscribed: true);

    await tester.pumpWidget(
      _buildProfileSelectionHarness(
        profileProvider: profileProvider,
        subscriptionService: subscription,
      ),
    );
    await _pumpFrames(tester, count: 10);

    expect(find.text('Welcome, Ava'), findsOneWidget);
    expect(find.text('My Progress'), findsOneWidget);
    expect(find.text('Continue Letter Tracing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress screen supports phone portrait layout', (tester) async {
    Future<KidProgressSummary> fakeSummaryLoader(int profileId) async {
      return const KidProgressSummary(
        stars: 42,
        level: 2,
        mathAttempts: 6,
        storiesCreated: 2,
        aiChats: 8,
        averageMathScore: 84,
        lastActivity: null,
        badgeMathExplorer: true,
        badgeStoryMaker: true,
        badgeAiBuddy: true,
        newlyUnlockedBadges: [],
        weeklyActivity: [1, 2, 1, 3, 2, 1, 4],
        leveledUp: false,
      );
    }

    final provider = _FakeProfileProvider(
      profiles: [
        Profile(id: 1, name: 'Ava', age: 7, avatar: '👧'),
      ],
      selectedProfileId: 1,
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<ProfileProvider>.value(
        value: provider,
        child: MaterialApp(
          home: KidProgressScreen(loadSummary: fakeSummaryLoader),
        ),
      ),
    );
    await _pumpFrames(tester, count: 8);

    expect(find.text('My Progress'), findsOneWidget);
    expect(find.textContaining('Star Board'), findsOneWidget);
    expect(find.text('Math Quizzes'), findsOneWidget);
    expect(find.text('Badges'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress screen supports tablet landscape layout',
      (tester) async {
    Future<KidProgressSummary> fakeSummaryLoader(int profileId) async {
      return const KidProgressSummary(
        stars: 42,
        level: 2,
        mathAttempts: 6,
        storiesCreated: 2,
        aiChats: 8,
        averageMathScore: 84,
        lastActivity: null,
        badgeMathExplorer: true,
        badgeStoryMaker: true,
        badgeAiBuddy: true,
        newlyUnlockedBadges: [],
        weeklyActivity: [1, 2, 1, 3, 2, 1, 4],
        leveledUp: false,
      );
    }

    final provider = _FakeProfileProvider(
      profiles: [
        Profile(id: 1, name: 'Ava', age: 7, avatar: '👧'),
      ],
      selectedProfileId: 1,
    );

    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<ProfileProvider>.value(
        value: provider,
        child: MaterialApp(
          home: KidProgressScreen(loadSummary: fakeSummaryLoader),
        ),
      ),
    );
    await _pumpFrames(tester, count: 8);

    expect(find.text('My Progress'), findsOneWidget);
    expect(find.text('Math Quizzes'), findsOneWidget);
    expect(find.text('Average Score'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
