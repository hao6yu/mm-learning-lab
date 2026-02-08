import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../screens/chess_screen.dart';
import '../screens/gobang_screen.dart';
import '../screens/kids_calculator_screen.dart';
import '../screens/math_buddy_screen.dart';
import '../screens/math_challenge_selection_screen.dart';
import '../screens/memory_match_screen.dart';
import '../screens/number_pop_screen.dart';
import '../screens/sudoku_screen.dart';
import '../screens/tic_tac_toe_screen.dart';

class ActivityIds {
  static const String storyAdventure = 'story_adventure';
  static const String aiChat = 'ai_chat';
  static const String letterTracing = 'letter_tracing';
  static const String bubblePop = 'bubble_pop';
  static const String phonics = 'phonics';
  static const String mathBuddy = 'math_buddy';
  static const String mathChallenge = 'math_challenge';
  static const String kidsCalculator = 'kids_calculator';
  static const String numberPop = 'number_pop';
  static const String sudoku = 'sudoku';
  static const String memoryMatch = 'memory_match';
  static const String ticTacToe = 'tic_tac_toe';
  static const String gobang = 'gobang';
  static const String chess = 'chess';
}

String activityTitle(String activityId) {
  switch (activityId) {
    case ActivityIds.storyAdventure:
      return 'AI Story Time';
    case ActivityIds.aiChat:
      return 'Talk with AI';
    case ActivityIds.letterTracing:
      return 'Letter Tracing';
    case ActivityIds.bubblePop:
      return 'Bubble Pop';
    case ActivityIds.phonics:
      return 'Phonics';
    case ActivityIds.mathBuddy:
      return 'Math Buddy';
    case ActivityIds.mathChallenge:
      return 'Timed Math Challenge';
    case ActivityIds.kidsCalculator:
      return "Kid's Calculator";
    case ActivityIds.numberPop:
      return 'Number Pop';
    case ActivityIds.sudoku:
      return 'Sudoku';
    case ActivityIds.memoryMatch:
      return 'Memory Match';
    case ActivityIds.ticTacToe:
      return 'Tic-Tac-Toe';
    case ActivityIds.gobang:
      return 'Gobang';
    case ActivityIds.chess:
      return 'Chess';
    default:
      return 'Learning Activity';
  }
}

IconData activityIcon(String activityId) {
  switch (activityId) {
    case ActivityIds.storyAdventure:
      return CupertinoIcons.wand_stars;
    case ActivityIds.aiChat:
      return CupertinoIcons.chat_bubble_fill;
    case ActivityIds.letterTracing:
      return CupertinoIcons.pencil;
    case ActivityIds.bubblePop:
      return CupertinoIcons.circle_grid_3x3;
    case ActivityIds.phonics:
      return CupertinoIcons.textformat_abc;
    case ActivityIds.mathBuddy:
      return Icons.emoji_people_rounded;
    case ActivityIds.mathChallenge:
      return Icons.timer_rounded;
    case ActivityIds.kidsCalculator:
      return Icons.calculate_rounded;
    case ActivityIds.numberPop:
      return Icons.bubble_chart;
    case ActivityIds.sudoku:
      return Icons.grid_4x4;
    case ActivityIds.memoryMatch:
      return Icons.memory_rounded;
    case ActivityIds.ticTacToe:
      return Icons.grid_3x3;
    case ActivityIds.gobang:
      return Icons.blur_circular;
    case ActivityIds.chess:
      return Icons.emoji_events;
    default:
      return Icons.extension_rounded;
  }
}

Future<bool> launchActivity(
  BuildContext context,
  String activityId, {
  required String profileName,
}) async {
  switch (activityId) {
    case ActivityIds.storyAdventure:
      await Navigator.pushNamed(context, '/story-adventure');
      return true;
    case ActivityIds.aiChat:
      await Navigator.pushNamed(context, '/ai-chat');
      return true;
    case ActivityIds.letterTracing:
      await Navigator.pushNamed(context, '/tracing');
      return true;
    case ActivityIds.bubblePop:
      await Navigator.pushNamed(context, '/bubble-pop');
      return true;
    case ActivityIds.phonics:
      await Navigator.pushNamed(context, '/phonics');
      return true;
    case ActivityIds.mathBuddy:
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MathBuddyScreen(profileName: profileName),
        ),
      );
      return true;
    case ActivityIds.mathChallenge:
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              MathChallengeSelectionScreen(profileName: profileName),
        ),
      );
      return true;
    case ActivityIds.kidsCalculator:
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const KidsCalculatorScreen(),
        ),
      );
      return true;
    case ActivityIds.numberPop:
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const NumberPopScreen(),
        ),
      );
      return true;
    case ActivityIds.sudoku:
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SudokuScreen(),
        ),
      );
      return true;
    case ActivityIds.memoryMatch:
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MemoryMatchScreen(),
        ),
      );
      return true;
    case ActivityIds.ticTacToe:
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const TicTacToeScreen(),
        ),
      );
      return true;
    case ActivityIds.gobang:
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const GobangScreen(),
        ),
      );
      return true;
    case ActivityIds.chess:
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ChessScreen(),
        ),
      );
      return true;
    default:
      return false;
  }
}
