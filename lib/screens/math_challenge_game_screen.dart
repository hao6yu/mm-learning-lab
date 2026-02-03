import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'math_challenge_result_screen.dart';

class MathChallengeGameScreen extends StatefulWidget {
  final Set<String> selectedOps;
  final String selectedGrade;
  final int selectedNumQuestions;
  final int selectedTimeLimit; // in minutes

  const MathChallengeGameScreen({
    super.key,
    required this.selectedOps,
    required this.selectedGrade,
    required this.selectedNumQuestions,
    required this.selectedTimeLimit,
  });

  @override
  State<MathChallengeGameScreen> createState() => _MathChallengeGameScreenState();
}

class _MathChallengeGameScreenState extends State<MathChallengeGameScreen> {
  late List<_MathQuestion> questions;
  late List<String?> userAnswers;
  int currentIndex = 0;
  late int secondsLeft;
  Timer? timer;
  bool quizEnded = false;
  bool timeUpDialogShown = false;
  int timeUsed = 0;

  @override
  void initState() {
    super.initState();
    questions = _generateQuestions();
    userAnswers = List.filled(widget.selectedNumQuestions, null);
    secondsLeft = widget.selectedTimeLimit * 60;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft > 0 && !quizEnded) {
        setState(() {
          secondsLeft--;
        });
      } else {
        _endQuiz();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _endQuiz() {
    setState(() {
      quizEnded = true;
      timer?.cancel();
      if (secondsLeft == 0 && !timeUpDialogShown) {
        timeUpDialogShown = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Time\'s up!'),
            content: const Text('The quiz is over. Let\'s see how you did!'),
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          _goToResultScreen();
        });
      } else {
        _goToResultScreen();
      }
    });
  }

  void _goToResultScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MathChallengeResultScreen(
          questions: questions,
          userAnswers: userAnswers,
          grade: widget.selectedGrade,
          operations: widget.selectedOps.join(','),
          timeLimit: widget.selectedTimeLimit,
          timeUsed: widget.selectedTimeLimit * 60 - secondsLeft,
        ),
      ),
    );
  }

  List<_MathQuestion> _generateQuestions() {
    final rand = math.Random();
    final List<_MathQuestion> qs = [];
    while (qs.length < widget.selectedNumQuestions) {
      final op = widget.selectedOps.elementAt(rand.nextInt(widget.selectedOps.length));
      int a = 0, b = 0, answer = 0;
      switch (op) {
        case '+':
          a = _randForDifficulty(rand);
          b = _randForDifficulty(rand);
          answer = a + b;
          break;
        case '−':
          a = _randForDifficulty(rand);
          b = _randForDifficulty(rand);
          if (a < b) {
            final tmp = a;
            a = b;
            b = tmp;
          }
          answer = a - b;
          break;
        case '×':
          a = _randForDifficulty(rand, mult: true);
          b = _randForDifficulty(rand, mult: true);
          answer = a * b;
          break;
        case '÷':
          b = _randForDifficulty(rand, mult: true, min: 1);
          answer = _randForDifficulty(rand, mult: true);
          a = b * answer;
          break;
      }
      qs.add(_MathQuestion(a, op, b, answer));
    }
    return qs;
  }

  int _randForDifficulty(math.Random rand, {bool mult = false, int min = 0}) {
    switch (widget.selectedGrade) {
      case 'Pre-K':
        return min + rand.nextInt(mult ? 1 : 6 - min); // Only +, 0-5
      case 'K':
        return min + rand.nextInt(mult ? 1 : 11 - min); // Only +/-, 0-10
      case '1st':
        return min + rand.nextInt(mult ? 1 : 21 - min); // Only +/-, 0-20
      case '2nd':
        return min + rand.nextInt(mult ? 1 : 101 - min); // Only +/-, 0-100
      case '3rd':
        return min + rand.nextInt(mult ? 11 : 101 - min); // ×: 0-10, +/−: 0-100
      case '4th':
        return min + rand.nextInt(mult ? 13 : 101 - min); // ×/÷: 0-12, +/−: 0-100
      default:
        return min + rand.nextInt(11 - min);
    }
  }

  void _input(String val) {
    setState(() {
      userAnswers[currentIndex] = (userAnswers[currentIndex] ?? '') + val;
    });
  }

  void _backspace() {
    setState(() {
      final ans = userAnswers[currentIndex] ?? '';
      if (ans.isNotEmpty) {
        userAnswers[currentIndex] = ans.substring(0, ans.length - 1);
      }
    });
  }

  void _clear() {
    setState(() {
      userAnswers[currentIndex] = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    // Enhanced device detection
    final shortestSide = math.min(screenWidth, screenHeight);
    final isTablet = shortestSide > 600 || (shortestSide > 500 && devicePixelRatio < 2.5);
    final isLandscape = screenWidth > screenHeight;
    // Only trigger small phone landscape for very small screens (like iPhone SE)
    final isSmallPhoneLandscape = isLandscape && !isTablet && screenHeight < 380;

    // Enhanced responsive sizing with better regular phone landscape support (20% larger)
    final horizontalPadding = isTablet ? 24.0 : (isSmallPhoneLandscape ? 8.0 : (isLandscape ? 19.0 : 20.0));
    final verticalPadding = isTablet ? 16.0 : (isSmallPhoneLandscape ? 4.0 : (isLandscape ? 10.0 : 12.0));
    final borderRadius = isTablet ? 24.0 : (isSmallPhoneLandscape ? 8.0 : (isLandscape ? 19.0 : 20.0));
    final iconSize = isTablet ? 28.0 : (isSmallPhoneLandscape ? 14.0 : (isLandscape ? 24.0 : 24.0));
    final titleFontSize = isTablet ? 24.0 : (isSmallPhoneLandscape ? 12.0 : (isLandscape ? 22.0 : 20.0));
    final questionFontSize = isTablet ? 48.0 : (isSmallPhoneLandscape ? 20.0 : (isLandscape ? 28.0 : 40.0));
    final buttonSize = isTablet ? 64.0 : (isSmallPhoneLandscape ? 24.0 : (isLandscape ? 43.0 : 56.0));
    final buttonFontSize = isTablet ? 28.0 : (isSmallPhoneLandscape ? 16.0 : (isLandscape ? 22.0 : 24.0));
    final spacing = isTablet ? 12.0 : (isSmallPhoneLandscape ? 1.0 : (isLandscape ? 5.0 : 8.0));
    final topBarHeight = isTablet ? 60.0 : (isSmallPhoneLandscape ? 24.0 : (isLandscape ? 48.0 : 50.0));

    if (quizEnded) {
      return const SizedBox.shrink();
    }
    final q = questions[currentIndex];
    final ans = userAnswers[currentIndex] ?? '';
    final min = secondsLeft ~/ 60;
    final sec = secondsLeft % 60;

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
          child: isLandscape
              ? Row(
                  children: [
                    // Left side: Question display
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: EdgeInsets.all(horizontalPadding),
                        child: Column(
                          children: [
                            // Top bar
                            SizedBox(
                              height: topBarHeight,
                              child: Row(
                                children: [
                                  // Back button
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8E6CFF),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0x338E6CFF),
                                            blurRadius: 6.0,
                                            offset: const Offset(0, 3.0),
                                          ),
                                        ],
                                      ),
                                      padding: EdgeInsets.all(8.0),
                                      child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: iconSize),
                                    ),
                                  ),
                                  const Spacer(),
                                  // Timer
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                    decoration: BoxDecoration(
                                      color: secondsLeft <= 60 ? const Color(0xFFFF6B6B) : const Color(0xFF8E6CFF),
                                      borderRadius: BorderRadius.circular(borderRadius),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (secondsLeft <= 60 ? const Color(0xFFFF6B6B) : const Color(0xFF8E6CFF)).withOpacity(0.3),
                                          blurRadius: 4.0,
                                          offset: const Offset(0, 2.0),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.timer, color: Colors.white, size: 12.0),
                                        const SizedBox(width: 3.0),
                                        Text(
                                          '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontSize: 10.0,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontFamily: 'Baloo2',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Progress indicator moved below timer
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(borderRadius),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 3.0,
                                    offset: const Offset(0, 1.5),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${currentIndex + 1}/${widget.selectedNumQuestions}',
                                style: TextStyle(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF8E6CFF),
                                  fontFamily: 'Baloo2',
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Question display
                            Container(
                              padding: EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(borderRadius),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 6.0,
                                    offset: const Offset(0, 3.0),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Question
                                  Text(
                                    '${q.a} ${q.op} ${q.b} = ?',
                                    style: TextStyle(
                                      fontSize: questionFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF8E6CFF),
                                      fontFamily: 'Baloo2',
                                    ),
                                  ),
                                  SizedBox(height: 8.0),
                                  // Answer input
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F9FA),
                                      borderRadius: BorderRadius.circular(borderRadius * 0.75),
                                      border: Border.all(color: const Color(0xFF8E6CFF).withOpacity(0.3), width: 2),
                                    ),
                                    child: Text(
                                      ans.isEmpty ? 'Your answer...' : ans,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold,
                                        color: ans.isEmpty ? Colors.grey : const Color(0xFF8E6CFF),
                                        fontFamily: 'Baloo2',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                    // Right side: Number pad and navigation
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: EdgeInsets.all(horizontalPadding),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              SizedBox(height: 8.0),
                              // Number pad
                              Container(
                                padding: EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(borderRadius),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4.0,
                                      offset: const Offset(0, 2.0),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Number buttons
                                    for (int row = 0; row < 3; row++)
                                      Padding(
                                        padding: EdgeInsets.only(bottom: spacing),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            for (int col = 0; col < 3; col++) _buildNumberButton('${7 - row * 3 + col}', buttonSize, buttonFontSize),
                                          ],
                                        ),
                                      ),
                                    // Bottom row: 0, Clear, Backspace
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildNumberButton('0', buttonSize, buttonFontSize),
                                        _buildActionButton('Clear', Icons.clear, const Color(0xFFFF9F43), buttonSize, buttonFontSize),
                                        _buildActionButton('⌫', Icons.backspace, const Color(0xFFFF6B6B), buttonSize, buttonFontSize),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 8.0),
                              // Navigation buttons
                              Row(
                                children: [
                                  // Previous button
                                  if (currentIndex > 0)
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            currentIndex--;
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(vertical: 4.0),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE3F2FD),
                                            borderRadius: BorderRadius.circular(borderRadius),
                                            border: Border.all(color: const Color(0xFF8E6CFF).withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.arrow_back, color: const Color(0xFF8E6CFF), size: iconSize * 0.8),
                                              const SizedBox(width: 2.0),
                                              Text(
                                                'Prev',
                                                style: TextStyle(
                                                  fontSize: buttonFontSize * 0.9,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFF8E6CFF),
                                                  fontFamily: 'Baloo2',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (currentIndex > 0) SizedBox(width: spacing),
                                  // Next/Finish button
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        if (currentIndex < widget.selectedNumQuestions - 1) {
                                          setState(() {
                                            currentIndex++;
                                          });
                                        } else {
                                          _endQuiz();
                                        }
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: 4.0),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF8E6CFF), Color(0xFF7C4DFF)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(borderRadius),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF8E6CFF).withOpacity(0.3),
                                              blurRadius: 3.0,
                                              offset: const Offset(0, 1.5),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              currentIndex < widget.selectedNumQuestions - 1 ? 'Next' : 'Finish',
                                              style: TextStyle(
                                                fontSize: buttonFontSize * 0.9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                fontFamily: 'Baloo2',
                                              ),
                                            ),
                                            const SizedBox(width: 2.0),
                                            Icon(
                                              currentIndex < widget.selectedNumQuestions - 1 ? Icons.arrow_forward : Icons.check,
                                              color: Colors.white,
                                              size: iconSize * 0.8,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8.0),
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                )
              : Column(
                  children: [
                    // Top bar
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                      child: SizedBox(
                        height: topBarHeight,
                        child: Row(
                          children: [
                            // Back button
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8E6CFF),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0x338E6CFF),
                                      blurRadius: isTablet ? 10.0 : 8.0,
                                      offset: Offset(0, isTablet ? 5.0 : 4.0),
                                    ),
                                  ],
                                ),
                                padding: EdgeInsets.all(isTablet ? 14.0 : 12.0),
                                child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: iconSize),
                              ),
                            ),
                            const Spacer(),
                            // Timer
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: isTablet ? 20.0 : 16.0, vertical: isTablet ? 12.0 : 10.0),
                              decoration: BoxDecoration(
                                color: secondsLeft <= 60 ? const Color(0xFFFF6B6B) : const Color(0xFF8E6CFF),
                                borderRadius: BorderRadius.circular(borderRadius),
                                boxShadow: [
                                  BoxShadow(
                                    color: (secondsLeft <= 60 ? const Color(0xFFFF6B6B) : const Color(0xFF8E6CFF)).withOpacity(0.3),
                                    blurRadius: isTablet ? 8.0 : 6.0,
                                    offset: Offset(0, isTablet ? 4.0 : 3.0),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.timer, color: Colors.white, size: isTablet ? 22.0 : 20.0),
                                  SizedBox(width: isTablet ? 8.0 : 6.0),
                                  Text(
                                    '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: isTablet ? 20.0 : 18.0,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontFamily: 'Baloo2',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // Progress indicator
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: isTablet ? 16.0 : 12.0, vertical: isTablet ? 10.0 : 8.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(borderRadius),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: isTablet ? 6.0 : 4.0,
                                    offset: Offset(0, isTablet ? 3.0 : 2.0),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${currentIndex + 1}/${widget.selectedNumQuestions}',
                                style: TextStyle(
                                  fontSize: isTablet ? 18.0 : 16.0,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF8E6CFF),
                                  fontFamily: 'Baloo2',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: isTablet ? 12.0 : 8.0),

                    // Question display
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      padding: EdgeInsets.all(isTablet ? 32.0 : 24.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(borderRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: isTablet ? 12.0 : 8.0,
                            offset: Offset(0, isTablet ? 6.0 : 4.0),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Question
                          Text(
                            '${q.a} ${q.op} ${q.b} = ?',
                            style: TextStyle(
                              fontSize: questionFontSize,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF8E6CFF),
                              fontFamily: 'Baloo2',
                            ),
                          ),
                          SizedBox(height: isTablet ? 24.0 : 20.0),
                          // Answer input
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: isTablet ? 20.0 : 16.0, horizontal: isTablet ? 24.0 : 20.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(borderRadius * 0.75),
                              border: Border.all(color: const Color(0xFF8E6CFF).withOpacity(0.3), width: 2),
                            ),
                            child: Text(
                              ans.isEmpty ? 'Your answer...' : ans,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isTablet ? 32.0 : 28.0,
                                fontWeight: FontWeight.bold,
                                color: ans.isEmpty ? Colors.grey : const Color(0xFF8E6CFF),
                                fontFamily: 'Baloo2',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Number pad
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      padding: EdgeInsets.all(isTablet ? 20.0 : 16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(borderRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: isTablet ? 8.0 : 6.0,
                            offset: Offset(0, isTablet ? 4.0 : 3.0),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Number buttons
                          for (int row = 0; row < 3; row++)
                            Padding(
                              padding: EdgeInsets.only(bottom: spacing),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  for (int col = 0; col < 3; col++) _buildNumberButton('${7 - row * 3 + col}', buttonSize, buttonFontSize),
                                ],
                              ),
                            ),
                          // Bottom row: 0, Clear, Backspace
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildNumberButton('0', buttonSize, buttonFontSize),
                              _buildActionButton('Clear', Icons.clear_all, const Color(0xFFFF9F43), buttonSize, isTablet ? 16.0 : 14.0),
                              _buildActionButton('⌫', Icons.backspace, const Color(0xFFFF6B6B), buttonSize, buttonFontSize),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isTablet ? 8.0 : 4.0),

                    // Navigation buttons
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Row(
                        children: [
                          // Previous button
                          if (currentIndex > 0)
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    currentIndex--;
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 4.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE3F2FD),
                                    borderRadius: BorderRadius.circular(borderRadius),
                                    border: Border.all(color: const Color(0xFF8E6CFF).withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.arrow_back, color: const Color(0xFF8E6CFF), size: isTablet ? 20.0 : 16.0),
                                      const SizedBox(width: 2.0),
                                      Text(
                                        'Prev',
                                        style: TextStyle(
                                          fontSize: isTablet ? 18.0 : 16.0,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF8E6CFF),
                                          fontFamily: 'Baloo2',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (currentIndex > 0) SizedBox(width: spacing),
                          // Next/Finish button
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (currentIndex < widget.selectedNumQuestions - 1) {
                                  setState(() {
                                    currentIndex++;
                                  });
                                } else {
                                  _endQuiz();
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 4.0),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF8E6CFF), Color(0xFF7C4DFF)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(borderRadius),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF8E6CFF).withOpacity(0.3),
                                      blurRadius: 3.0,
                                      offset: const Offset(0, 1.5),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      currentIndex < widget.selectedNumQuestions - 1 ? 'Next' : 'Finish',
                                      style: TextStyle(
                                        fontSize: isTablet ? 18.0 : 16.0,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontFamily: 'Baloo2',
                                      ),
                                    ),
                                    const SizedBox(width: 2.0),
                                    Icon(
                                      currentIndex < widget.selectedNumQuestions - 1 ? Icons.arrow_forward : Icons.check,
                                      color: Colors.white,
                                      size: isTablet ? 20.0 : 16.0,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number, double size, double fontSize) {
    return GestureDetector(
      onTap: () => _input(number),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(size * 0.3),
          border: Border.all(color: const Color(0xFF8E6CFF).withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4.0,
              offset: const Offset(0, 2.0),
            ),
          ],
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF8E6CFF),
              fontFamily: 'Baloo2',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, double size, double fontSize) {
    return GestureDetector(
      onTap: () {
        if (label == 'Clear') {
          _clear();
        } else {
          _backspace();
        }
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(size * 0.3),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 4.0,
              offset: const Offset(0, 2.0),
            ),
          ],
        ),
        child: Center(
          child: label == '⌫'
              ? Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFamily: 'Baloo2',
                  ),
                )
              : Icon(
                  icon,
                  color: color,
                  size: fontSize,
                ),
        ),
      ),
    );
  }
}

class _MathQuestion {
  final int a, b, answer;
  final String op;
  _MathQuestion(this.a, this.op, this.b, this.answer);
}
