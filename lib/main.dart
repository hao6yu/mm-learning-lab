import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

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
import 'services/subscription_service.dart';
import 'widgets/subscription_guard.dart';
import 'screens/subscription_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure debug logging
  DateTime startTime = DateTime.now();
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message == null) return;
    String timestamp = DateTime.now().difference(startTime).toString().padLeft(10);
    String formattedMessage = '[$timestamp] $message';
    print(formattedMessage);
  };
  print('====== MM LEARNING LAB APP STARTED ======');

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Check database integrity and repair if needed
  try {
    print("Checking database integrity...");
    final dbService = DatabaseService();
    final wasRepaired = await dbService.checkAndRepairDatabase();
    if (wasRepaired) {
      print("Database was reset due to integrity issues");
    }
  } catch (e) {
    print("Error during database check: $e");
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
              // Remove any debug overlays
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
                child: child!,
              );
            },
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
              textTheme: GoogleFonts.nunitoTextTheme(),
              useMaterial3: true,
              // Disable debug indicators
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            initialRoute: '/',
            routes: {
              '/': (context) => const SubscriptionGuard(child: ProfileSelectionScreen()),
              '/games': (context) => const SubscriptionGuard(child: GameSelectionScreen()),
              '/tracing': (context) => const SubscriptionGuard(child: LetterTracingScreen()),
              '/phonics': (context) => const SubscriptionGuard(child: PhonicsScreen()),
              '/bubble-pop': (context) => const SubscriptionGuard(child: BubblePopScreen()),
              '/story-adventure': (context) => const SubscriptionGuard(child: StoryAdventureScreen()),
              '/ai-chat': (context) => const SubscriptionGuard(child: AiChatScreen()),
              '/subscription': (context) => const SubscriptionScreen(),
            },
          );
        },
      ),
    );
  }
}
