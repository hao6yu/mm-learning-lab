import 'package:flutter/material.dart';
import '../models/math_buddy.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class MathBuddyScreen extends StatefulWidget {
  final String profileName;
  const MathBuddyScreen({super.key, required this.profileName});

  @override
  State<MathBuddyScreen> createState() => _MathBuddyScreenState();
}

class _MathBuddyScreenState extends State<MathBuddyScreen> with SingleTickerProviderStateMixin {
  late MathBuddy _mathBuddy;
  String _selectedGrade = '1st';
  late Set<String> _availableOperations;
  late MathProblem _currentProblem;
  String? _selectedAnswer;
  bool _isCorrect = false;
  bool _showResult = false;
  bool _buddyThinking = false;
  String _buddyMessage = '';
  late AnimationController _messageAnimationController;
  late Animation<double> _messageAnimation;
  Timer? _speechTimer;
  bool _shouldShowWelcomeMessage = true;
  static const String _welcomeMessageCacheKey = 'math_buddy_welcome_shown';

  @override
  void initState() {
    super.initState();

    // Initialize the ElevenLabs service
    MathBuddy.initialize();

    _mathBuddy = MathBuddyCharacters.getRandomBuddy();
    _availableOperations = MathBuddy.gradeOperations[_selectedGrade]!;
    _currentProblem = _generateProblem();

    _messageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _messageAnimation = CurvedAnimation(
      parent: _messageAnimationController,
      curve: Curves.easeInOut,
    );

    // Register for audio state changes
    MathBuddy.addAudioStateListener(_onAudioStateChanged);

    // Check if welcome message was shown in the last 24 hours
    _checkWelcomeMessageStatus();
  }

  void _onAudioStateChanged() {
    if (mounted) {
      setState(() {
        // This will update the UI based on MathBuddy.isPlayingAudio
        print("Audio state changed in UI: isPlaying=${MathBuddy.isPlayingAudio}");
      });
    }
  }

  // Check if we should show the welcome message
  Future<void> _checkWelcomeMessageStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastShown = prefs.getInt(_welcomeMessageCacheKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // If last shown more than 24 hours ago (or never shown)
      _shouldShowWelcomeMessage = (now - lastShown) > 24 * 60 * 60 * 1000;

      // Introduce the math buddy when the screen loads
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_shouldShowWelcomeMessage) {
          _mathBuddy.introduceYourself(profileName: widget.profileName);
          prefs.setInt(_welcomeMessageCacheKey, now);
        }

        setState(() {
          _buddyMessage = "Hi there, ${widget.profileName}! I'm ${_mathBuddy.name}, your math buddy!";
          _messageAnimationController.forward();
        });
      });
    } catch (e) {
      // If there's an error, just show the welcome message
      print('Error checking welcome message status: $e');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mathBuddy.introduceYourself(profileName: widget.profileName);
        setState(() {
          _buddyMessage = "Hi there, ${widget.profileName}! I'm ${_mathBuddy.name}, your math buddy!";
          _messageAnimationController.forward();
        });
      });
    }
  }

  @override
  void dispose() {
    _messageAnimationController.dispose();
    _speechTimer?.cancel();

    // Remove our audio state listener
    MathBuddy.removeAudioStateListener(_onAudioStateChanged);

    MathBuddy.dispose();
    super.dispose();
  }

  MathProblem _generateProblem() {
    final rand = math.Random();

    // Get difficulty range for the selected grade
    final difficultyRange = MathBuddy.gradeDifficultyRanges[_selectedGrade]!;
    final min = difficultyRange['min']!;
    final max = difficultyRange['max']!;

    // Randomly select an operation from available ones
    final operations = _availableOperations.toList();
    var operation = operations[rand.nextInt(operations.length)];

    int num1, num2, answer;

    // Ensure appropriate problem based on operation
    if (operation == '+') {
      num1 = min + rand.nextInt(max - min);
      num2 = min + rand.nextInt(max - min);
      answer = num1 + num2;
    } else if (operation == '-') {
      // Ensure no negative answers for subtraction
      num1 = min + rand.nextInt(max - min);
      num2 = min + rand.nextInt(num1 - min + 1); // num2 <= num1
      answer = num1 - num2;
    } else if (operation == '×') {
      // For multiplication in lower grades, use smaller numbers
      final factor = _selectedGrade == '3rd' ? 12 : 10;
      num1 = min + rand.nextInt(factor - min);
      num2 = min + rand.nextInt(factor - min);
      answer = num1 * num2;
    } else if (operation == '÷') {
      // For division, ensure clean division without remainders
      num2 = min + rand.nextInt(10 - min); // Divisor between min and 10
      final possibleMultiples = List.generate((max ~/ num2) - ((min - 1) ~/ num2), (i) => (i + ((min - 1) ~/ num2) + 1) * num2);
      num1 = possibleMultiples[rand.nextInt(possibleMultiples.length)];
      answer = num1 ~/ num2;
    } else {
      // Default to addition if operation not recognized
      num1 = min + rand.nextInt(max - min);
      num2 = min + rand.nextInt(max - min);
      answer = num1 + num2;
      operation = '+';
    }

    // Generate 3 plausible wrong answers
    final List<int> wrongAnswers = _generateWrongAnswers(answer, operation, min, max);

    // Add the correct answer and shuffle
    final List<String> options = [...wrongAnswers.map((e) => e.toString()), answer.toString()];
    options.shuffle();

    return MathProblem(
      question: '$num1 $operation $num2 = ?',
      answer: answer.toString(),
      options: options,
    );
  }

  // Helper method to generate plausible wrong answers
  List<int> _generateWrongAnswers(int correctAnswer, String operation, int min, int max) {
    final Set<int> wrongAnswers = {};
    final rand = math.Random();

    // Common mistakes to make wrong answers plausible
    if (operation == '+') {
      // Off-by-one errors are common
      wrongAnswers.add(correctAnswer + 1);
      wrongAnswers.add(correctAnswer - 1);

      // Another common error is to be off by 10
      if (correctAnswer > 10) wrongAnswers.add(correctAnswer - 10);
      if (correctAnswer + 10 < max * 2) wrongAnswers.add(correctAnswer + 10);
    } else if (operation == '-') {
      // Common subtraction errors
      wrongAnswers.add(correctAnswer + 1);
      wrongAnswers.add(correctAnswer - 1);

      // Reversed operation (addition instead of subtraction)
      if (correctAnswer + 2 * min < max * 2) wrongAnswers.add(correctAnswer + 2 * min);
    } else if (operation == '×') {
      // Common multiplication errors
      wrongAnswers.add(correctAnswer + 1);
      wrongAnswers.add(correctAnswer - 1);

      // Off by factor of 2
      if (correctAnswer > 2) wrongAnswers.add(correctAnswer ~/ 2);
      if (correctAnswer * 2 < max * max) wrongAnswers.add(correctAnswer * 2);
    } else if (operation == '÷') {
      // Common division errors
      wrongAnswers.add(correctAnswer + 1);
      wrongAnswers.add(correctAnswer - 1);

      // Reversed operation
      if (correctAnswer * correctAnswer < max * max) wrongAnswers.add(correctAnswer * correctAnswer);
    }

    // Fill with random plausible answers if needed
    while (wrongAnswers.length < 3) {
      final offset = rand.nextInt(5) + 1;
      int wrongAnswer = rand.nextBool() ? correctAnswer + offset : correctAnswer - offset;

      // Ensure positive numbers
      if (wrongAnswer < 0) wrongAnswer = offset;

      // Add some randomness but keep it reasonable
      if (wrongAnswer != correctAnswer) {
        wrongAnswers.add(wrongAnswer);
      }
    }

    return wrongAnswers.take(3).toList();
  }

  void _selectGrade(String grade) {
    setState(() {
      _selectedGrade = grade;
      _availableOperations = MathBuddy.gradeOperations[grade]!;
      _currentProblem = _generateProblem();
      _selectedAnswer = null;
      _showResult = false;
    });

    // Have the math buddy acknowledge the grade change
    _mathBuddy.speak("Let's try some ${_selectedGrade} grade math problems!");
    setState(() {
      _buddyMessage = "Let's try some ${_selectedGrade} grade math problems!";
      _messageAnimationController.reset();
      _messageAnimationController.forward();
    });
  }

  void _selectBuddy(MathBuddy buddy) {
    setState(() {
      _mathBuddy = buddy;
    });

    // Introduce the new buddy
    _mathBuddy.introduceYourself(profileName: widget.profileName);
    setState(() {
      _buddyMessage = "Hi there, ${widget.profileName}! I'm ${_mathBuddy.name}, your math buddy!";
      _messageAnimationController.reset();
      _messageAnimationController.forward();
    });
  }

  void _newProblem() {
    setState(() {
      _currentProblem = _generateProblem();
      _selectedAnswer = null;
      _showResult = false;
    });

    // Have the math buddy say a random encouragement
    _mathBuddy.sayEncouragement();
    setState(() {
      _buddyMessage = "Let's try this one!";
      _messageAnimationController.reset();
      _messageAnimationController.forward();
    });
  }

  void _selectAnswer(String answer) {
    if (_showResult) return; // Prevent selecting after showing result

    setState(() {
      _selectedAnswer = answer;
    });
  }

  void _checkAnswer() {
    if (_selectedAnswer == null) return;

    setState(() {
      _showResult = true;
      _isCorrect = _selectedAnswer == _currentProblem.answer;

      // Display message and speak it
      if (_isCorrect) {
        _mathBuddy.sayCorrectResponse();
        _buddyMessage = "That's correct!";
      } else {
        _mathBuddy.sayIncorrectResponse();
        _buddyMessage = "Not quite. The answer is ${_currentProblem.answer}.";
      }

      _messageAnimationController.reset();
      _messageAnimationController.forward();
    });
  }

  void _showWorkingOut() {
    setState(() {
      _buddyThinking = true;
      _buddyMessage = "Let me think about this...";
      _messageAnimationController.reset();
      _messageAnimationController.forward();
    });

    // Use the new solveCompleteProblem method
    _mathBuddy.solveCompleteProblem(_currentProblem.question);

    // Simulate the buddy thinking for UI feedback
    _speechTimer = Timer(const Duration(milliseconds: 1500), () {
      final parts = _currentProblem.question.split(' ');
      if (parts.length >= 3) {
        try {
          final num1 = int.parse(parts[0]);
          final operation = parts[1];
          final num2 = int.parse(parts[2]);

          String explanation = "";
          if (operation == '+') {
            explanation = "To add $num1 and $num2, I count $num1 and then add $num2 more. That gives me ${num1 + num2}.";
          } else if (operation == '-') {
            explanation = "To subtract $num2 from $num1, I start at $num1 and count back $num2. That gives me ${num1 - num2}.";
          } else if (operation == '×') {
            explanation = "To multiply $num1 by $num2, I can add $num1 together $num2 times. That gives me ${num1 * num2}.";
          } else if (operation == '÷') {
            explanation = "To divide $num1 by $num2, I see how many groups of $num2 fit into $num1. That gives me ${num1 ~/ num2}.";
          }

          setState(() {
            _buddyThinking = false;
            _buddyMessage = explanation;
            _messageAnimationController.reset();
            _messageAnimationController.forward();
          });
        } catch (e) {
          setState(() {
            _buddyThinking = false;
            _buddyMessage = "I'm having trouble with this problem.";
            _messageAnimationController.reset();
            _messageAnimationController.forward();
          });
        }
      }
    });
  }

  void _giveHint() {
    _mathBuddy.sayHint();
    setState(() {
      _buddyMessage = "Try breaking this down into smaller steps.";
      _messageAnimationController.reset();
      _messageAnimationController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Enhanced responsive detection
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    // Better tablet detection: consider both dimensions and pixel density
    final shortestSide = math.min(screenWidth, screenHeight);
    final isTablet = shortestSide > 600 || (shortestSide > 500 && devicePixelRatio < 2.5);
    final isLandscape = screenWidth > screenHeight;
    final isPhoneLandscape = isLandscape && !isTablet;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _mathBuddy.themeColor.withOpacity(0.2),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App bar with back button and title - more compact for phone landscape
              SizedBox(height: isPhoneLandscape ? 4.0 : 12.0),
              Row(
                children: [
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _mathBuddy.themeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _mathBuddy.themeColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 32),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Math Buddy',
                    style: TextStyle(
                      fontFamily: 'Baloo2',
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: _mathBuddy.themeColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),

              // Controls section - more compact for phone landscape
              SizedBox(height: isPhoneLandscape ? 4.0 : 8.0),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: isPhoneLandscape ? 4.0 : 8.0,
                runSpacing: isPhoneLandscape ? 4.0 : 8.0,
                children: [
                  // Voice buddy dropdown
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Buddy:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _mathBuddy.themeColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<MathBuddy>(
                        value: _mathBuddy,
                        onChanged: (buddy) {
                          if (buddy != null) _selectBuddy(buddy);
                        },
                        items: MathBuddyCharacters.characters
                            .map((buddy) => DropdownMenuItem(
                                  value: buddy,
                                  child: Text(buddy.name),
                                ))
                            .toList(),
                      ),
                    ],
                  ),

                  const SizedBox(width: 16),

                  // Grade selection
                  ...MathBuddy.grades.map((grade) {
                    return ChoiceChip(
                      label: Text(grade),
                      selected: _selectedGrade == grade,
                      onSelected: (selected) {
                        if (selected) _selectGrade(grade);
                      },
                      backgroundColor: Colors.white,
                      selectedColor: _mathBuddy.themeColor,
                      labelStyle: TextStyle(
                        color: _selectedGrade == grade ? Colors.white : _mathBuddy.themeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList(),

                  const SizedBox(width: 16),

                  // Voice toggle switch
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Voice:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _mathBuddy.themeColor,
                        ),
                      ),
                      Switch(
                        value: MathBuddy.useVoice,
                        onChanged: (value) {
                          setState(() {
                            MathBuddy.setUseVoice(value);
                            _buddyMessage = value ? "Voice on!" : "Voice off.";
                            _messageAnimationController.reset();
                            _messageAnimationController.forward();
                          });
                        },
                        activeColor: _mathBuddy.themeColor,
                      ),
                    ],
                  ),
                ],
              ),

              // Make the rest of the content scrollable to handle small screens
              Expanded(
                child: isLandscape ? _buildLandscapeLayout(context, isPhoneLandscape, isTablet) : _buildPortraitLayout(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Layout for portrait mode
  Widget _buildPortraitLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Buddy avatar and message bubble
          _buildBuddyConversation(),

          const SizedBox(height: 20),

          // Problem and answers container
          _buildProblemContainer(context),

          const SizedBox(height: 16),

          // Helper buttons
          _buildHelperButtonsRow(context),
        ],
      ),
    );
  }

  // Layout for landscape mode - reorganized for horizontal orientation
  Widget _buildLandscapeLayout(BuildContext context, bool isPhoneLandscape, bool isTablet) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isPhoneLandscape ? 8.0 : 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side: Buddy conversation - more compact for phone landscape
          Flexible(
            flex: isPhoneLandscape ? 2 : 2,
            child: Column(
              children: [
                _buildBuddyConversation(isPhoneLandscape),
                SizedBox(height: isPhoneLandscape ? 4.0 : 12.0),
                // Place helper buttons below the buddy in landscape
                _buildHelperButtonsRow(context, isPhoneLandscape),
              ],
            ),
          ),

          SizedBox(width: isPhoneLandscape ? 6.0 : 16.0),

          // Right side: Problem and answers - takes more space on phone landscape
          Flexible(
            flex: isPhoneLandscape ? 3 : 3,
            child: _buildProblemContainer(context, isPhoneLandscape),
          ),
        ],
      ),
    );
  }

  // Buddy avatar and message
  Widget _buildBuddyConversation([bool isPhoneLandscape = false]) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Buddy avatar - make it responsive
        Container(
          width: isPhoneLandscape ? 60.0 : 80.0, // Even smaller for phone landscape
          height: isPhoneLandscape ? 60.0 : 80.0, // Even smaller for phone landscape
          decoration: BoxDecoration(
            color: _mathBuddy.themeColor.withOpacity(0.3),
            shape: BoxShape.circle,
            border: Border.all(
              color: _mathBuddy.themeColor,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: _mathBuddy.themeColor.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              _mathBuddy.name.substring(0, 1),
              style: TextStyle(
                fontSize: isPhoneLandscape ? 24.0 : 32.0, // Even smaller for phone landscape
                fontWeight: FontWeight.bold,
                color: _mathBuddy.themeColor,
              ),
            ),
          ),
        ),

        SizedBox(width: isPhoneLandscape ? 8.0 : 16.0),

        // Message bubble
        Expanded(
          child: Stack(
            children: [
              // Message content
              FadeTransition(
                opacity: _messageAnimation,
                child: Container(
                  padding: EdgeInsets.all(isPhoneLandscape ? 12.0 : 16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _mathBuddy.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _mathBuddy.themeColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buddyThinking
                          ? Row(
                              children: [
                                Text('Thinking', style: TextStyle(color: _mathBuddy.themeColor)),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(_mathBuddy.themeColor),
                                  ),
                                ),
                              ],
                            )
                          : Text(_buddyMessage),
                    ],
                  ),
                ),
              ),

              // Show a small floating indicator when audio is playing
              if (MathBuddy.isPlayingAudio)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(_mathBuddy.themeColor),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Speaking...',
                          style: TextStyle(
                            color: _mathBuddy.themeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Problem container with question and answer options
  Widget _buildProblemContainer(BuildContext context, [bool isPhoneLandscape = false]) {
    return LayoutBuilder(builder: (context, constraints) {
      // Calculate the appropriate size for the options grid
      final isSmallScreen = constraints.maxWidth < 500;
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      final shortestSide = math.min(screenWidth, screenHeight);
      final isTablet = shortestSide > 600 || (shortestSide > 500 && devicePixelRatio < 2.5);
      final isLandscape = screenWidth > screenHeight;
      final isPhoneLandscapeLocal = isLandscape && !isTablet;

      // For phone landscape, use 2x2 grid to fit all options
      // For other cases, use appropriate layout
      final crossAxisCount = isPhoneLandscapeLocal
          ? 2
          : (isLandscape && isSmallScreen)
              ? 1
              : 2;

      return Container(
        padding: EdgeInsets.all(isPhoneLandscape ? 12.0 : 16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _currentProblem.question,
              style: TextStyle(
                fontSize: isPhoneLandscapeLocal ? 24 : (isSmallScreen ? 28 : 32),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isPhoneLandscapeLocal ? 12 : 24),

            // Multiple choice options grid
            GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              mainAxisSpacing: isPhoneLandscapeLocal ? 4 : 12,
              crossAxisSpacing: isPhoneLandscapeLocal ? 4 : 12,
              childAspectRatio: isPhoneLandscapeLocal ? 4.0 : (isLandscape ? 3 : (isSmallScreen ? 4 : 2.5)),
              physics: const NeverScrollableScrollPhysics(),
              children: _currentProblem.options.map((option) {
                bool isSelected = _selectedAnswer == option;
                bool isCorrectAnswer = _showResult && option == _currentProblem.answer;
                bool isWrongAnswer = _showResult && isSelected && !isCorrectAnswer;

                return GestureDetector(
                  onTap: () => _selectAnswer(option),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCorrectAnswer
                          ? Colors.green.shade100
                          : isWrongAnswer
                              ? Colors.red.shade100
                              : isSelected
                                  ? _mathBuddy.themeColor.withOpacity(0.2)
                                  : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(isPhoneLandscapeLocal ? 8 : 12),
                      border: Border.all(
                        color: isCorrectAnswer
                            ? Colors.green
                            : isWrongAnswer
                                ? Colors.red
                                : isSelected
                                    ? _mathBuddy.themeColor
                                    : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            option,
                            style: TextStyle(
                              fontSize: isPhoneLandscapeLocal ? 16 : (isSmallScreen ? 22 : 24),
                              fontWeight: FontWeight.bold,
                              color: isCorrectAnswer
                                  ? Colors.green
                                  : isWrongAnswer
                                      ? Colors.red
                                      : isSelected
                                          ? _mathBuddy.themeColor
                                          : Colors.black,
                            ),
                          ),
                          if (_showResult) ...[
                            const SizedBox(width: 8),
                            Icon(
                              isCorrectAnswer
                                  ? Icons.check_circle
                                  : isWrongAnswer
                                      ? Icons.cancel
                                      : null,
                              color: isCorrectAnswer ? Colors.green : Colors.red,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            SizedBox(height: isPhoneLandscapeLocal ? 8 : 20),

            // Check answer button
            ElevatedButton(
              onPressed: _selectedAnswer != null && !_showResult ? _checkAnswer : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _mathBuddy.themeColor,
                padding: EdgeInsets.symmetric(vertical: isPhoneLandscapeLocal ? 8 : 12, horizontal: isPhoneLandscapeLocal ? 16 : 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: Text(
                'Check',
                style: TextStyle(
                  fontSize: isPhoneLandscapeLocal ? 16 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // Helper buttons row/wrap
  Widget _buildHelperButtonsRow(BuildContext context, [bool isPhoneLandscape = false]) {
    if (isPhoneLandscape) {
      // For phone landscape, use a column layout to save horizontal space
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildHelperButton(
                  icon: Icons.lightbulb_outline,
                  label: 'Hint',
                  onTap: _giveHint,
                  isPhoneLandscape: isPhoneLandscape,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildHelperButton(
                  icon: Icons.calculate,
                  label: 'Explain',
                  onTap: _showWorkingOut,
                  isPhoneLandscape: isPhoneLandscape,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildHelperButton(
            icon: Icons.refresh,
            label: 'New Problem',
            onTap: _newProblem,
            isPhoneLandscape: isPhoneLandscape,
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      alignment: WrapAlignment.center,
      children: [
        _buildHelperButton(
          icon: Icons.lightbulb_outline,
          label: 'Hint',
          onTap: _giveHint,
          isPhoneLandscape: isPhoneLandscape,
        ),
        _buildHelperButton(
          icon: Icons.calculate,
          label: 'Explain',
          onTap: _showWorkingOut,
          isPhoneLandscape: isPhoneLandscape,
        ),
        _buildHelperButton(
          icon: Icons.refresh,
          label: 'New Problem',
          onTap: _newProblem,
          isPhoneLandscape: isPhoneLandscape,
        ),
      ],
    );
  }

  Widget _buildHelperButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPhoneLandscape = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isPhoneLandscape ? 8.0 : 16.0, vertical: isPhoneLandscape ? 6.0 : 12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isPhoneLandscape ? 8 : 12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: _mathBuddy.themeColor.withOpacity(0.5),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: _mathBuddy.themeColor,
              size: isPhoneLandscape ? 18.0 : 24.0,
            ),
            SizedBox(height: isPhoneLandscape ? 2.0 : 4.0),
            Text(
              label,
              style: TextStyle(
                color: _mathBuddy.themeColor,
                fontWeight: FontWeight.bold,
                fontSize: isPhoneLandscape ? 10.0 : 14.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MathProblem {
  final String question;
  final String answer;
  final List<String> options;

  MathProblem({
    required this.question,
    required this.answer,
    required this.options,
  });
}
