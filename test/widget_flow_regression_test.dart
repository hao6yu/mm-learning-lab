import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mm_learning_lab/models/profile.dart';
import 'package:mm_learning_lab/providers/profile_provider.dart';
import 'package:mm_learning_lab/screens/letter_tracing_screen.dart';
import 'package:mm_learning_lab/screens/math_quiz_history_screen.dart';
import 'package:mm_learning_lab/screens/profile_selection_screen.dart';
import 'package:mm_learning_lab/screens/subscription_screen.dart';
import 'package:mm_learning_lab/services/database_service.dart';
import 'package:mm_learning_lab/services/subscription_service.dart';
import 'package:mm_learning_lab/utils/activity_launcher.dart';
import 'package:mm_learning_lab/widgets/subscription_guard.dart';
import 'package:mm_learning_lab/widgets/tracing_canvas.dart';

class _FakeSubscriptionService extends ChangeNotifier
    implements SubscriptionService {
  _FakeSubscriptionService({
    required this.hasAccess,
    this.subscribed = false,
    this.loading = false,
    this.trialDaysLeft = 14,
  });

  final bool hasAccess;
  final bool subscribed;
  final bool loading;
  final int trialDaysLeft;

  @override
  bool get isSubscribed => subscribed;

  @override
  bool get isLoading => loading;

  @override
  List<ProductDetails> get products => const [];

  @override
  String? get errorMessage => null;

  @override
  bool get isDebugBypassActive => false;

  @override
  Future<bool> hasActiveAccess({bool refreshSubscription = true}) async {
    return hasAccess;
  }

  @override
  Future<int> getDaysLeftInTrial() async {
    return trialDaysLeft;
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
    {int count = 8, Duration step = const Duration(milliseconds: 120)}) async {
  for (int i = 0; i < count; i++) {
    await tester.pump(step);
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseService().deleteDatabase();
  });

  tearDown(() async {
    await DatabaseService().deleteDatabase();
  });

  testWidgets('subscription guard shows child when access is active',
      (tester) async {
    final fakeSubscription = _FakeSubscriptionService(
      hasAccess: true,
      subscribed: false,
      loading: false,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<SubscriptionService>.value(
        value: fakeSubscription,
        child: const MaterialApp(
          home: SubscriptionGuard(
            child: Text('Guarded Content'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Guarded Content'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('subscription guard shows paywall when access is inactive',
      (tester) async {
    final fakeSubscription = _FakeSubscriptionService(
      hasAccess: false,
      subscribed: false,
      loading: false,
      trialDaysLeft: 0,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<SubscriptionService>.value(
        value: fakeSubscription,
        child: const MaterialApp(
          home: SubscriptionGuard(
            child: Text('Should Not Show'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Should Not Show'), findsNothing);
    expect(find.byType(SubscriptionScreen), findsOneWidget);
  });

  testWidgets('quick resume card appears and opens last activity route',
      (tester) async {
    const profileId = 1;
    final profileProvider = _FakeProfileProvider(
      profiles: [
        Profile(id: profileId, name: 'Ava', age: 7, avatar: '👧'),
      ],
      selectedProfileId: profileId,
    );

    SharedPreferences.setMockInitialValues({
      'last_activity_profile_$profileId': jsonEncode({
        'activity_id': ActivityIds.letterTracing,
        'activity_title': activityTitle(ActivityIds.letterTracing),
        'played_at': DateTime.now().toIso8601String(),
      }),
    });

    final fakeSubscription = _FakeSubscriptionService(
      hasAccess: true,
      subscribed: true,
      loading: false,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
          ChangeNotifierProvider<SubscriptionService>.value(
            value: fakeSubscription,
          ),
        ],
        child: MaterialApp(
          home: const ProfileSelectionScreen(),
          routes: {
            '/tracing': (context) =>
                const Scaffold(body: Center(child: Text('Tracing Route'))),
          },
        ),
      ),
    );

    await _pumpFrames(tester);

    expect(find.text('Continue Letter Tracing'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await _pumpFrames(tester, count: 4);

    expect(find.text('Tracing Route'), findsOneWidget);
  });

  testWidgets('math quiz history uses selected profile with injected loader',
      (tester) async {
    final callProfileIds = <int>[];
    final historyByProfile = <int, List<Map<String, dynamic>>>{
      1: [
        {
          'datetime': DateTime(2025, 1, 1, 10, 30).toIso8601String(),
          'grade': '1st',
          'operations': '+',
          'num_questions': 10,
          'num_correct': 9,
          'time_used': 88,
          'time_limit': 3,
        },
      ],
      2: [
        {
          'datetime': DateTime(2025, 1, 2, 11, 45).toIso8601String(),
          'grade': '4th',
          'operations': '÷',
          'num_questions': 10,
          'num_correct': 8,
          'time_used': 92,
          'time_limit': 3,
        },
      ],
    };

    Future<List<Map<String, dynamic>>> fakeLoader(int profileId) async {
      callProfileIds.add(profileId);
      return historyByProfile[profileId] ?? const [];
    }

    final profile1Provider = _FakeProfileProvider(
      profiles: [
        Profile(id: 1, name: 'Kid 1', age: 7, avatar: '👦'),
        Profile(id: 2, name: 'Kid 2', age: 9, avatar: '👧'),
      ],
      selectedProfileId: 1,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ProfileProvider>.value(
        value: profile1Provider,
        child: MaterialApp(
          home: MathQuizHistoryScreen(
            key: const ValueKey('history-p1'),
            loadHistory: fakeLoader,
          ),
        ),
      ),
    );

    await _pumpFrames(tester, count: 6);
    expect(find.textContaining('Grade: 1st'), findsOneWidget);
    expect(find.textContaining('Grade: 4th'), findsNothing);

    final profile2Provider = _FakeProfileProvider(
      profiles: [
        Profile(id: 1, name: 'Kid 1', age: 7, avatar: '👦'),
        Profile(id: 2, name: 'Kid 2', age: 9, avatar: '👧'),
      ],
      selectedProfileId: 2,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ProfileProvider>.value(
        value: profile2Provider,
        child: MaterialApp(
          home: MathQuizHistoryScreen(
            key: const ValueKey('history-p2'),
            loadHistory: fakeLoader,
          ),
        ),
      ),
    );

    await _pumpFrames(tester, count: 6);
    expect(find.textContaining('Grade: 4th'), findsOneWidget);
    expect(find.textContaining('Grade: 1st'), findsNothing);
    expect(callProfileIds, containsAllInOrder([1, 2]));
  });

  testWidgets('tracing flow shows success card and advances to next letter',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_seen_${ActivityIds.letterTracing}': true,
    });

    final profileProvider = ProfileProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<ProfileProvider>.value(
        value: profileProvider,
        child: const MaterialApp(home: LetterTracingScreen()),
      ),
    );

    await tester.pumpAndSettle();

    TracingCanvas tracingCanvas =
        tester.widget<TracingCanvas>(find.byType(TracingCanvas));
    expect(tracingCanvas.letter, 'A');

    tracingCanvas.onCompleted();
    await tester.pumpAndSettle();

    expect(find.text('Great tracing! 🎉'), findsOneWidget);
    expect(find.text('Next Letter'), findsOneWidget);

    await tester.tap(find.text('Next Letter'));
    await tester.pumpAndSettle();

    tracingCanvas = tester.widget<TracingCanvas>(find.byType(TracingCanvas));
    expect(tracingCanvas.letter, 'B');
    expect(find.text('Great tracing! 🎉'), findsNothing);
  });
}
