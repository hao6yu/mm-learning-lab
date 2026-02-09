import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mm_learning_lab/models/profile.dart';
import 'package:mm_learning_lab/providers/profile_provider.dart';
import 'package:mm_learning_lab/screens/ai_limits_screen.dart';
import 'package:mm_learning_lab/screens/profile_selection_screen.dart';
import 'package:mm_learning_lab/services/ai_parental_control_service.dart';
import 'package:mm_learning_lab/services/ai_usage_limit_service.dart';
import 'package:mm_learning_lab/services/database_service.dart';
import 'package:mm_learning_lab/services/subscription_service.dart';
import 'package:mm_learning_lab/services/theme_service.dart';

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

  testWidgets('AI Limits button opens AI limits route from profile home',
      (tester) async {
    final profileProvider = _FakeProfileProvider(
      profiles: [Profile(id: 1, name: 'Ava', age: 7, avatar: '👧')],
      selectedProfileId: 1,
    );
    final subscription = _FakeSubscriptionService(subscribed: true);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
          ChangeNotifierProvider<SubscriptionService>.value(
            value: subscription,
          ),
          ChangeNotifierProvider<ThemeService>(
            create: (_) => ThemeService(),
          ),
        ],
        child: MaterialApp(
          home: const ProfileSelectionScreen(),
          routes: {
            '/ai-limits': (context) =>
                const Scaffold(body: Center(child: Text('AI Limits Route'))),
          },
        ),
      ),
    );

    await _pumpFrames(tester, count: 10);
    expect(find.text('AI Limits'), findsOneWidget);

    await tester.tap(find.text('AI Limits'));
    await _pumpFrames(tester, count: 6);

    expect(find.text('AI Limits Route'), findsOneWidget);
  });

  testWidgets('parent call toggle persists from AI limits screen',
      (tester) async {
    const profileId = 7;
    final profileProvider = _FakeProfileProvider(
      profiles: [Profile(id: profileId, name: 'Milo', age: 8, avatar: '👦')],
      selectedProfileId: profileId,
    );
    final subscription = _FakeSubscriptionService(subscribed: false);
    final parentalService = AiParentalControlService();
    var controls = await parentalService.getControls(profileId);

    Future<AiLimitsScreenData> loadData(int _, bool isPremium) async {
      return AiLimitsScreenData(
        profileName: 'Milo',
        chatQuota: const AiQuotaCheckResult(
          allowed: true,
          dailyLimit: 30,
          weeklyLimit: 120,
          usedToday: 3,
          usedThisWeek: 9,
          featureLabel: 'AI Chat',
        ),
        storyQuota: const AiQuotaCheckResult(
          allowed: true,
          dailyLimit: 2,
          weeklyLimit: 10,
          usedToday: 1,
          usedThisWeek: 4,
          featureLabel: 'AI Stories',
        ),
        callAllowance: const AiCallAllowance(
          allowed: true,
          perCallLimitSeconds: 240,
          remainingTodaySeconds: 600,
          remainingThisWeekSeconds: 2400,
          remainingForThisCallSeconds: 240,
          usedTodaySeconds: 120,
          usedThisWeekSeconds: 480,
        ),
        controls: controls,
      );
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
          ChangeNotifierProvider<SubscriptionService>.value(
            value: subscription,
          ),
          ChangeNotifierProvider<ThemeService>(
            create: (_) => ThemeService(),
          ),
        ],
        child: MaterialApp(
          home: AiLimitsScreen(
            loadData: loadData,
            saveControls: (profileId, next) async {
              controls = next;
              await parentalService.saveControls(profileId, next);
            },
          ),
          routes: {
            '/subscription': (context) => const Scaffold(),
          },
        ),
      ),
    );

    await _pumpFrames(tester, count: 12);
    expect(find.text('Allow AI calls'), findsOneWidget);

    await tester.ensureVisible(find.text('Allow AI calls'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(Switch).first);
    await _pumpFrames(tester, count: 8);

    final savedControls = await parentalService.getControls(profileId);
    expect(savedControls.callEnabled, isFalse);
  });
}
