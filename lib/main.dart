import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'dart:developer' as developer;

import 'providers/profile_provider.dart';
import 'screens/profile_selection_screen.dart';
import 'screens/game_selection_screen.dart';
import 'screens/letter_tracing_screen.dart';
import 'screens/phonics_screen.dart';
import 'screens/bubble_pop_screen.dart';
import 'screens/story_adventure_screen.dart';
import 'screens/ai_chat_screen.dart';
import 'services/elevenlabs_service.dart';
import 'services/openai_service.dart';
import 'services/database_service.dart';
import 'services/performance_warmup_service.dart';
import 'services/subscription_service.dart';
import 'widgets/subscription_guard.dart';
import 'screens/kid_progress_screen.dart';
import 'screens/subscription_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure debug logging
  DateTime startTime = DateTime.now();
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message == null) return;
    String timestamp =
        DateTime.now().difference(startTime).toString().padLeft(10);
    String formattedMessage = '[$timestamp] $message';
    developer.log(formattedMessage, name: 'MM Learning Lab');
  };
  developer.log('====== MM LEARNING LAB APP STARTED ======',
      name: 'MM Learning Lab');

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Check database integrity and repair if needed
  try {
    debugPrint("Checking database integrity...");
    final dbService = DatabaseService();
    final wasRepaired = await dbService.checkAndRepairDatabase();
    if (wasRepaired) {
      debugPrint("Database was reset due to integrity issues");
    }
  } catch (e) {
    debugPrint("Error during database check: $e");
  }

  // Initialize services
  await ElevenLabsService.initialize();
  await OpenAIService.initialize();

  runApp(const MMLearningLabApp());
}

class MMLearningLabApp extends StatelessWidget {
  const MMLearningLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionService()),
      ],
      child: ResponsiveSizer(
        builder: (context, orientation, screenType) {
          return MaterialApp(
            title: 'M&M Learning Lab',
            debugShowCheckedModeBanner: false,
            showSemanticsDebugger: false,
            builder: (context, child) {
              PerformanceWarmupService.scheduleWarmup(context);
              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: mediaQuery.textScaler.clamp(
                    minScaleFactor: 1.0,
                    maxScaleFactor: 1.35,
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
              textTheme: GoogleFonts.nunitoTextTheme(),
              useMaterial3: true,
              visualDensity: VisualDensity.adaptivePlatformDensity,
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
            initialRoute: '/',
            routes: {
              '/': (context) =>
                  const SubscriptionGuard(child: ProfileSelectionScreen()),
              '/games': (context) =>
                  const SubscriptionGuard(child: GameSelectionScreen()),
              '/tracing': (context) =>
                  const SubscriptionGuard(child: LetterTracingScreen()),
              '/phonics': (context) =>
                  const SubscriptionGuard(child: PhonicsScreen()),
              '/bubble-pop': (context) =>
                  const SubscriptionGuard(child: BubblePopScreen()),
              '/story-adventure': (context) =>
                  const SubscriptionGuard(child: StoryAdventureScreen()),
              '/ai-chat': (context) =>
                  const SubscriptionGuard(child: AiChatScreen()),
              '/progress': (context) =>
                  const SubscriptionGuard(child: KidProgressScreen()),
              '/subscription': (context) => const SubscriptionScreen(),
            },
          );
        },
      ),
    );
  }
}
