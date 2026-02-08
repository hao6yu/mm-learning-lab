import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../providers/profile_provider.dart';
import '../services/adaptive_difficulty_service.dart';

class MathChallengeResultScreen extends StatefulWidget {
  final List questions;
  final List userAnswers;
  final int timeUsed;
  final String grade;
  final String operations;
  final int timeLimit;
  const MathChallengeResultScreen(
      {super.key,
      required this.questions,
      required this.userAnswers,
      required this.timeUsed,
      required this.grade,
      required this.operations,
      required this.timeLimit});

  @override
  State<MathChallengeResultScreen> createState() =>
      _MathChallengeResultScreenState();
}

class _MathChallengeResultScreenState extends State<MathChallengeResultScreen> {
  bool _logged = false;
  String? _nextRecommendationText;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_logged) {
      _logged = true;
      _logAttemptAndLoadRecommendation();
    }
  }

  Future<void> _logAttemptAndLoadRecommendation() async {
    final correct = _countCorrect();
    final selectedProfileId = context.read<ProfileProvider>().selectedProfileId;
    if (selectedProfileId == null) {
      return;
    }

    await DatabaseService().insertMathQuizAttempt(
      grade: widget.grade,
      operations: widget.operations,
      numQuestions: widget.questions.length,
      timeLimit: widget.timeLimit,
      numCorrect: correct,
      timeUsed: widget.timeUsed,
      profileId: selectedProfileId,
    );

    final recommendation =
        await AdaptiveDifficultyService().getMathRecommendation(
      profileId: selectedProfileId,
      baseGrade: widget.grade,
    );

    if (!mounted) return;
    setState(() {
      if (recommendation.hasRecommendationChange) {
        _nextRecommendationText =
            'Next challenge: try ${recommendation.recommendedGrade} level.';
      } else {
        _nextRecommendationText =
            'Next challenge: keep practicing ${recommendation.baseGrade}.';
      }
    });
  }

  int _countCorrect() {
    int correct = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      if (widget.userAnswers[i] != null &&
          widget.userAnswers[i].toString() ==
              widget.questions[i].answer.toString()) {
        correct++;
      }
    }
    return correct;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    // Enhanced device detection (same as game screen)
    final shortestSide = math.min(screenWidth, screenHeight);
    final isTablet =
        shortestSide > 600 || (shortestSide > 500 && devicePixelRatio < 2.5);
    final isLandscape = screenWidth > screenHeight;
    final isSmallPhoneLandscape =
        isLandscape && !isTablet && screenHeight < 380;

    // Enhanced responsive sizing with better regular phone landscape support
    final horizontalPadding = isTablet
        ? 24.0
        : (isSmallPhoneLandscape ? 8.0 : (isLandscape ? 16.0 : 20.0));
    final verticalPadding = isTablet
        ? 16.0
        : (isSmallPhoneLandscape ? 4.0 : (isLandscape ? 8.0 : 12.0));
    final borderRadius = isTablet
        ? 24.0
        : (isSmallPhoneLandscape ? 8.0 : (isLandscape ? 16.0 : 20.0));
    final titleFontSize = isTablet
        ? 28.0
        : (isSmallPhoneLandscape ? 16.0 : (isLandscape ? 20.0 : 24.0));
    final subtitleFontSize = isTablet
        ? 18.0
        : (isSmallPhoneLandscape ? 12.0 : (isLandscape ? 14.0 : 16.0));
    final bodyFontSize = isTablet
        ? 16.0
        : (isSmallPhoneLandscape ? 10.0 : (isLandscape ? 12.0 : 14.0));
    final questionFontSize = isTablet
        ? 20.0
        : (isSmallPhoneLandscape ? 14.0 : (isLandscape ? 16.0 : 18.0));
    final emojiSize = isTablet
        ? 36.0
        : (isSmallPhoneLandscape ? 20.0 : (isLandscape ? 28.0 : 32.0));
    final spacing = isTablet
        ? 12.0
        : (isSmallPhoneLandscape ? 4.0 : (isLandscape ? 8.0 : 10.0));
    final cardSpacing = isTablet
        ? 8.0
        : (isSmallPhoneLandscape ? 2.0 : (isLandscape ? 4.0 : 6.0));

    final questions = widget.questions;
    final userAnswers = widget.userAnswers;
    final timeUsed = widget.timeUsed;
    int correct = _countCorrect();
    final timeStr = timeUsed > 0
        ? '${(timeUsed ~/ 60).toString().padLeft(2, '0')}:${(timeUsed % 60).toString().padLeft(2, '0')}'
        : "Time's up!";

    // Choose playful colors and emoji
    Color resultColor;
    String emoji;
    Color resultTextColor;
    if (correct == questions.length) {
      resultColor = const Color(0xFFE6F9ED); // pale green
      emoji = '🎉';
      resultTextColor = const Color(0xFF24924B); // strong green
    } else if (correct >= (questions.length * 0.7).ceil()) {
      resultColor = const Color(0xFFFFFBEA); // very pale yellow
      emoji = '⭐️';
      resultTextColor = const Color(0xFFFF9F43); // strong orange
    } else {
      resultColor = const Color(0xFFFFF3F3); // very pale pink
      emoji = '😊';
      resultTextColor = const Color(0xFFFF6B6B); // strong red
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8FD6FF), Color(0xFFFFE6E6), Color(0xFFFFF3E0)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding, vertical: verticalPadding),
            child: isLandscape
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Emoji
                          Padding(
                            padding: EdgeInsets.only(right: spacing),
                            child: Text(
                              emoji,
                              style: TextStyle(fontSize: emojiSize),
                            ),
                          ),
                          // Centered result text
                          Expanded(
                            child: Center(
                              child: Text(
                                correct == questions.length
                                    ? 'Perfect!'
                                    : (correct >=
                                            (questions.length * 0.7).ceil()
                                        ? 'Great Job!'
                                        : 'You Did It!'),
                                style: TextStyle(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: resultTextColor,
                                  fontFamily: 'Baloo2',
                                  shadows: [
                                    Shadow(
                                        color: Colors.white,
                                        blurRadius: isTablet ? 8.0 : 6.0,
                                        offset: Offset(0, isTablet ? 1.5 : 1.0))
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Score and time
                          Padding(
                            padding: EdgeInsets.only(left: spacing),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You got $correct out of ${questions.length} correct!',
                                  style: TextStyle(
                                      fontSize: subtitleFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF8E6CFF),
                                      fontFamily: 'Baloo2'),
                                ),
                                SizedBox(height: isTablet ? 4.0 : 3.0),
                                Text(
                                  'Time: $timeStr',
                                  style: TextStyle(
                                      fontSize: bodyFontSize,
                                      color: const Color(0xFFFF9F43),
                                      fontFamily: 'Baloo2'),
                                ),
                                if (_nextRecommendationText != null) ...[
                                  SizedBox(height: isTablet ? 6.0 : 4.0),
                                  Text(
                                    _nextRecommendationText!,
                                    style: TextStyle(
                                      fontSize: bodyFontSize,
                                      color: const Color(0xFF4B6584),
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Baloo2',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: spacing),
                      Expanded(
                        child: ListView.builder(
                          itemCount: questions.length,
                          itemBuilder: (context, i) {
                            final q = questions[i];
                            final userAns = userAnswers[i]?.toString() ?? '';
                            final isCorrect = userAns == q.answer.toString();
                            return Container(
                              margin: EdgeInsets.symmetric(
                                  vertical: cardSpacing,
                                  horizontal: isTablet ? 10.0 : 8.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(borderRadius),
                                border: Border.all(
                                  color: isCorrect
                                      ? const Color(0xFF43C465)
                                      : const Color(0xFFFF6B6B),
                                  width: isTablet ? 2.5 : 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isCorrect
                                            ? const Color(0xFF43C465)
                                            : const Color(0xFFFF6B6B))
                                        .withValues(alpha: 0.10),
                                    blurRadius: isTablet ? 8.0 : 6.0,
                                    offset: Offset(0, isTablet ? 4.0 : 3.0),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: isTablet ? 16.0 : 14.0,
                                  vertical: isTablet ? 14.0 : 12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '${q.a} ${q.op} ${q.b} = ?',
                                        style: TextStyle(
                                            fontSize: questionFontSize,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Baloo2',
                                            color: isCorrect
                                                ? const Color(0xFF24924B)
                                                : const Color(0xFFFF6B6B)),
                                      ),
                                      SizedBox(width: isTablet ? 10.0 : 8.0),
                                      isCorrect
                                          ? Text('✅',
                                              style: TextStyle(
                                                  fontSize: questionFontSize))
                                          : Text('❌',
                                              style: TextStyle(
                                                  fontSize: questionFontSize)),
                                    ],
                                  ),
                                  SizedBox(height: isTablet ? 8.0 : 6.0),
                                  Row(
                                    children: [
                                      Text('Your answer: ',
                                          style: TextStyle(
                                              fontSize: bodyFontSize,
                                              fontFamily: 'Baloo2',
                                              color: Colors.black)),
                                      Text(
                                        userAns.isEmpty ? '...' : userAns,
                                        style: TextStyle(
                                          fontSize: subtitleFontSize,
                                          fontWeight: FontWeight.bold,
                                          color: isCorrect
                                              ? const Color(0xFF43C465)
                                              : const Color(0xFFFF6B6B),
                                          fontFamily: 'Baloo2',
                                        ),
                                      ),
                                      if (!isCorrect) ...[
                                        SizedBox(width: isTablet ? 10.0 : 8.0),
                                        Text('Correct:',
                                            style: TextStyle(
                                                fontSize: bodyFontSize,
                                                color: const Color(0xFF8E6CFF),
                                                fontFamily: 'Baloo2')),
                                        SizedBox(width: isTablet ? 6.0 : 4.0),
                                        Text(
                                          '${q.answer}',
                                          style: TextStyle(
                                              fontSize: subtitleFontSize,
                                              color: const Color(0xFF8E6CFF),
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Baloo2'),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (!isCorrect)
                                    Padding(
                                      padding: EdgeInsets.only(
                                          top: isTablet ? 10.0 : 8.0),
                                      child: Text(
                                        _getExplanation(q),
                                        style: TextStyle(
                                          fontSize: isTablet ? 14.0 : 12.0,
                                          color: const Color(0xFF8E6CFF),
                                          fontFamily: 'Baloo2',
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      // Bottom buttons for landscape
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8E6CFF),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(borderRadius)),
                                padding: EdgeInsets.symmetric(
                                    vertical: isTablet
                                        ? 16.0
                                        : (isSmallPhoneLandscape
                                            ? 8.0
                                            : (isLandscape ? 10.0 : 14.0))),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text(
                                'Try Again',
                                style: TextStyle(
                                    fontSize: subtitleFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Baloo2'),
                              ),
                            ),
                          ),
                          SizedBox(width: spacing),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF9F43),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(borderRadius)),
                                padding: EdgeInsets.symmetric(
                                    vertical: isTablet
                                        ? 16.0
                                        : (isSmallPhoneLandscape
                                            ? 8.0
                                            : (isLandscape ? 10.0 : 14.0))),
                              ),
                              onPressed: () {
                                Navigator.popUntil(
                                    context, (route) => route.isFirst);
                              },
                              child: Text(
                                'Home',
                                style: TextStyle(
                                    fontSize: subtitleFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Baloo2'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    children: [
                      // Portrait layout
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
                        decoration: BoxDecoration(
                          color: resultColor,
                          borderRadius: BorderRadius.circular(borderRadius),
                          border: Border.all(
                              color: resultTextColor,
                              width: isTablet ? 3.0 : 2.0),
                          boxShadow: [
                            BoxShadow(
                              color: resultTextColor.withValues(alpha: 0.15),
                              blurRadius: isTablet ? 12.0 : 8.0,
                              offset: Offset(0, isTablet ? 6.0 : 4.0),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(emoji,
                                style: TextStyle(
                                    fontSize: isTablet ? 48.0 : 40.0)),
                            SizedBox(height: isTablet ? 16.0 : 12.0),
                            Text(
                              correct == questions.length
                                  ? 'Perfect!'
                                  : (correct >= (questions.length * 0.7).ceil()
                                      ? 'Great Job!'
                                      : 'You Did It!'),
                              style: TextStyle(
                                fontSize: isTablet ? 32.0 : 28.0,
                                fontWeight: FontWeight.bold,
                                color: resultTextColor,
                                fontFamily: 'Baloo2',
                                shadows: [
                                  Shadow(
                                      color: Colors.white,
                                      blurRadius: isTablet ? 8.0 : 6.0,
                                      offset: Offset(0, isTablet ? 2.0 : 1.0))
                                ],
                              ),
                            ),
                            SizedBox(height: isTablet ? 16.0 : 12.0),
                            Text(
                              'You got $correct out of ${questions.length} correct!',
                              style: TextStyle(
                                  fontSize: isTablet ? 20.0 : 18.0,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF8E6CFF),
                                  fontFamily: 'Baloo2'),
                            ),
                            SizedBox(height: isTablet ? 8.0 : 6.0),
                            Text(
                              'Time: $timeStr',
                              style: TextStyle(
                                  fontSize: subtitleFontSize,
                                  color: const Color(0xFFFF9F43),
                                  fontFamily: 'Baloo2'),
                            ),
                            if (_nextRecommendationText != null) ...[
                              SizedBox(height: isTablet ? 8.0 : 6.0),
                              Text(
                                _nextRecommendationText!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: bodyFontSize,
                                  color: const Color(0xFF4B6584),
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Baloo2',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: isTablet ? 20.0 : 16.0),
                      Expanded(
                        child: ListView.builder(
                          itemCount: questions.length,
                          itemBuilder: (context, i) {
                            final q = questions[i];
                            final userAns = userAnswers[i]?.toString() ?? '';
                            final isCorrect = userAns == q.answer.toString();
                            return Container(
                              margin:
                                  EdgeInsets.symmetric(vertical: cardSpacing),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(borderRadius),
                                border: Border.all(
                                  color: isCorrect
                                      ? const Color(0xFF43C465)
                                      : const Color(0xFFFF6B6B),
                                  width: isTablet ? 2.5 : 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isCorrect
                                            ? const Color(0xFF43C465)
                                            : const Color(0xFFFF6B6B))
                                        .withValues(alpha: 0.10),
                                    blurRadius: isTablet ? 8.0 : 6.0,
                                    offset: Offset(0, isTablet ? 4.0 : 3.0),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(isTablet ? 16.0 : 14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '${q.a} ${q.op} ${q.b} = ?',
                                        style: TextStyle(
                                            fontSize: questionFontSize,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Baloo2',
                                            color: isCorrect
                                                ? const Color(0xFF24924B)
                                                : const Color(0xFFFF6B6B)),
                                      ),
                                      const Spacer(),
                                      isCorrect
                                          ? Text('✅',
                                              style: TextStyle(
                                                  fontSize: questionFontSize))
                                          : Text('❌',
                                              style: TextStyle(
                                                  fontSize: questionFontSize)),
                                    ],
                                  ),
                                  SizedBox(height: isTablet ? 12.0 : 10.0),
                                  Row(
                                    children: [
                                      Text('Your answer: ',
                                          style: TextStyle(
                                              fontSize: bodyFontSize,
                                              fontFamily: 'Baloo2',
                                              color: Colors.black)),
                                      Text(
                                        userAns.isEmpty ? '...' : userAns,
                                        style: TextStyle(
                                          fontSize: subtitleFontSize,
                                          fontWeight: FontWeight.bold,
                                          color: isCorrect
                                              ? const Color(0xFF43C465)
                                              : const Color(0xFFFF6B6B),
                                          fontFamily: 'Baloo2',
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!isCorrect) ...[
                                    SizedBox(height: isTablet ? 8.0 : 6.0),
                                    Row(
                                      children: [
                                        Text('Correct answer: ',
                                            style: TextStyle(
                                                fontSize: bodyFontSize,
                                                color: const Color(0xFF8E6CFF),
                                                fontFamily: 'Baloo2')),
                                        Text(
                                          '${q.answer}',
                                          style: TextStyle(
                                              fontSize: subtitleFontSize,
                                              color: const Color(0xFF8E6CFF),
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Baloo2'),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isTablet ? 8.0 : 6.0),
                                    Text(
                                      _getExplanation(q),
                                      style: TextStyle(
                                        fontSize: isTablet ? 14.0 : 12.0,
                                        color: const Color(0xFF8E6CFF),
                                        fontFamily: 'Baloo2',
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: isTablet ? 20.0 : 16.0),
                      // Bottom buttons for portrait
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8E6CFF),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(borderRadius)),
                                padding: EdgeInsets.symmetric(
                                    vertical: isTablet
                                        ? 16.0
                                        : (isSmallPhoneLandscape
                                            ? 8.0
                                            : (isLandscape ? 10.0 : 14.0))),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text(
                                'Try Again',
                                style: TextStyle(
                                    fontSize: subtitleFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Baloo2'),
                              ),
                            ),
                          ),
                          SizedBox(width: spacing),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF9F43),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(borderRadius)),
                                padding: EdgeInsets.symmetric(
                                    vertical: isTablet ? 16.0 : 14.0),
                              ),
                              onPressed: () {
                                Navigator.popUntil(
                                    context, (route) => route.isFirst);
                              },
                              child: Text(
                                'Home',
                                style: TextStyle(
                                    fontSize: subtitleFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Baloo2'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _getExplanation(dynamic q) {
    switch (q.op) {
      case '+':
        return 'Add ${q.a} and ${q.b} together: ${q.a} + ${q.b} = ${q.answer}';
      case '−':
        return 'Subtract ${q.b} from ${q.a}: ${q.a} - ${q.b} = ${q.answer}';
      case '×':
        return 'Multiply ${q.a} by ${q.b}: ${q.a} × ${q.b} = ${q.answer}';
      case '÷':
        return 'Divide ${q.a} by ${q.b}: ${q.a} ÷ ${q.b} = ${q.answer}';
      default:
        return '';
    }
  }
}
