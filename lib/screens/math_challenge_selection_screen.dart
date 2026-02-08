import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'math_challenge_game_screen.dart';
import 'math_quiz_history_screen.dart';
import '../providers/profile_provider.dart';
import '../services/adaptive_difficulty_service.dart';

class MathChallengeSelectionScreen extends StatefulWidget {
  final String profileName;
  const MathChallengeSelectionScreen({super.key, required this.profileName});

  @override
  State<MathChallengeSelectionScreen> createState() =>
      _MathChallengeSelectionScreenState();
}

class _MathChallengeSelectionScreenState
    extends State<MathChallengeSelectionScreen> {
  final Set<String> selectedOps = {'+', '−'};
  String selectedGrade = '2nd';
  int selectedNumQuestions = 10;
  int selectedTimeLimit = 3;
  final AdaptiveDifficultyService _adaptiveDifficultyService =
      AdaptiveDifficultyService();
  AdaptiveMathRecommendation? _adaptiveRecommendation;
  bool _loadingAdaptive = true;
  bool _autoAppliedAdaptiveGrade = false;

  final List<Map<String, dynamic>> operations = [
    {'label': 'Add', 'symbol': '+', 'color': Color(0xFFFF9F43)},
    {'label': 'Subtract', 'symbol': '−', 'color': Color(0xFF43C465)},
    {'label': 'Multiply', 'symbol': '×', 'color': Color(0xFF8E6CFF)},
    {'label': 'Divide', 'symbol': '÷', 'color': Color(0xFFFF6B6B)},
  ];

  final List<String> grades = ['Pre-K', 'K', '1st', '2nd', '3rd', '4th'];
  final List<int> numQuestionsOptions = [10, 15, 20];
  final List<int> timeLimitOptions = [1, 2, 3, 5];

  // Grade to allowed operations mapping
  final Map<String, Set<String>> gradeOps = {
    'Pre-K': {'+'},
    'K': {'+', '−'},
    '1st': {'+', '−'},
    '2nd': {'+', '−'},
    '3rd': {'+', '−', '×'},
    '4th': {'+', '−', '×', '÷'},
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAdaptiveRecommendation(autoApply: true);
    });
  }

  Future<void> _refreshAdaptiveRecommendation({bool autoApply = false}) async {
    final profileId = context.read<ProfileProvider>().selectedProfileId;
    if (profileId == null) {
      if (!mounted) return;
      setState(() {
        _loadingAdaptive = false;
        _adaptiveRecommendation = null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loadingAdaptive = true;
      });
    }

    final recommendation =
        await _adaptiveDifficultyService.getMathRecommendation(
      profileId: profileId,
      baseGrade: selectedGrade,
    );

    if (!mounted) return;
    setState(() {
      _adaptiveRecommendation = recommendation;
      _loadingAdaptive = false;
    });

    if (autoApply &&
        !_autoAppliedAdaptiveGrade &&
        recommendation.hasRecommendationChange &&
        selectedGrade == '2nd') {
      _applyAdaptiveGradeRecommendation();
      _autoAppliedAdaptiveGrade = true;
    }
  }

  void _applyAdaptiveGradeRecommendation() {
    final recommendation = _adaptiveRecommendation;
    if (recommendation == null) {
      return;
    }
    setState(() {
      selectedGrade = recommendation.recommendedGrade;
      selectedOps
        ..clear()
        ..addAll(gradeOps[selectedGrade]!);
      _autoAppliedAdaptiveGrade = true;
    });
    _refreshAdaptiveRecommendation();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    // Enhanced device detection (same as game and result screens)
    final shortestSide = math.min(screenWidth, screenHeight);
    final isTablet =
        shortestSide > 600 || (shortestSide > 500 && devicePixelRatio < 2.5);
    final isLandscape = screenWidth > screenHeight;
    final isSmallPhoneLandscape =
        isLandscape && !isTablet && screenHeight < 380;

    // Enhanced responsive sizing with three-tier system
    final horizontalPadding = isTablet
        ? 24.0
        : (isSmallPhoneLandscape ? 8.0 : (isLandscape ? 16.0 : 20.0));
    final verticalPadding = isTablet
        ? 20.0
        : (isSmallPhoneLandscape ? 4.0 : (isLandscape ? 10.0 : 16.0));
    final borderRadius = isTablet
        ? 24.0
        : (isSmallPhoneLandscape ? 8.0 : (isLandscape ? 16.0 : 20.0));
    final iconSize = isTablet
        ? 32.0
        : (isSmallPhoneLandscape ? 18.0 : (isLandscape ? 24.0 : 28.0));
    final titleFontSize = isTablet
        ? 30.0
        : (isSmallPhoneLandscape ? 16.0 : (isLandscape ? 22.0 : 26.0));
    final subtitleFontSize = isTablet
        ? 20.0
        : (isSmallPhoneLandscape ? 12.0 : (isLandscape ? 16.0 : 18.0));
    final buttonFontSize = isTablet
        ? 18.0
        : (isSmallPhoneLandscape ? 10.0 : (isLandscape ? 14.0 : 16.0));
    final spacing = isTablet
        ? 24.0
        : (isSmallPhoneLandscape ? 8.0 : (isLandscape ? 16.0 : 20.0));
    final smallSpacing = isTablet
        ? 16.0
        : (isSmallPhoneLandscape ? 4.0 : (isLandscape ? 8.0 : 12.0));
    final buttonPadding = isTablet
        ? 18.0
        : (isSmallPhoneLandscape ? 6.0 : (isLandscape ? 12.0 : 16.0));

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding, vertical: verticalPadding),
          child: isLandscape
              ? Row(
                  children: [
                    // Left side: Header and controls
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Back button
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF9F43),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0x33FF9F43),
                                        blurRadius: 6.0,
                                        offset: const Offset(0, 3.0),
                                      ),
                                    ],
                                  ),
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white,
                                    size: iconSize,
                                  ),
                                ),
                              ),
                              // History button
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          MathQuizHistoryScreen(),
                                    ),
                                  );
                                },
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
                                  child: Icon(
                                    Icons.emoji_events_rounded,
                                    color: Colors.white,
                                    size: iconSize,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: smallSpacing * 0.5),
                          // Title
                          Text(
                            'Math Timed Challenge',
                            style: TextStyle(
                              fontFamily: 'Baloo2',
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFFF6B6B),
                              letterSpacing: 1.0,
                              shadows: [
                                Shadow(
                                  color: Colors.white,
                                  blurRadius: 4.0,
                                  offset: const Offset(0, 1.0),
                                ),
                                Shadow(
                                  color: Colors.black12,
                                  blurRadius: 4.0,
                                  offset: const Offset(0, 2.0),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: smallSpacing * 0.25),
                          Text(
                            'Choose your challenge, ${widget.profileName}!',
                            style: TextStyle(
                              fontSize: subtitleFontSize,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF24924B),
                              fontFamily: 'Baloo2',
                            ),
                          ),
                          SizedBox(height: smallSpacing),
                          _buildAdaptiveRecommendationCard(
                            isTablet: isTablet,
                            isLandscape: isLandscape,
                            borderRadius: borderRadius,
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                    SizedBox(width: horizontalPadding * 0.5),
                    // Right side: Selection options
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildGradeSelection(
                                isTablet,
                                isLandscape,
                                isSmallPhoneLandscape,
                                borderRadius,
                                buttonFontSize,
                                buttonPadding,
                                smallSpacing),
                            SizedBox(height: smallSpacing * 0.75),
                            _buildOperationSelection(
                                isTablet,
                                isLandscape,
                                isSmallPhoneLandscape,
                                borderRadius,
                                buttonFontSize,
                                buttonPadding,
                                smallSpacing),
                            SizedBox(height: smallSpacing * 0.75),
                            _buildQuestionSelection(
                                isTablet,
                                isLandscape,
                                isSmallPhoneLandscape,
                                borderRadius,
                                buttonFontSize,
                                buttonPadding,
                                smallSpacing,
                                subtitleFontSize),
                            SizedBox(height: smallSpacing * 0.75),
                            _buildTimeSelection(
                                isTablet,
                                isLandscape,
                                isSmallPhoneLandscape,
                                borderRadius,
                                buttonFontSize,
                                buttonPadding,
                                smallSpacing,
                                subtitleFontSize),
                            SizedBox(height: spacing * 0.75),
                            _buildStartButton(isTablet, isLandscape,
                                isSmallPhoneLandscape, borderRadius, spacing),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Playful back button and history button row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back button
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9F43),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0x33FF9F43),
                                  blurRadius: isTablet ? 10.0 : 8.0,
                                  offset: Offset(0, isTablet ? 5.0 : 4.0),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.all(isTablet ? 14.0 : 12.0),
                            margin: EdgeInsets.only(
                                top: isTablet ? 10.0 : 8.0, left: 0),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: iconSize,
                            ),
                          ),
                        ),
                        // History button
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MathQuizHistoryScreen(),
                              ),
                            );
                          },
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
                            margin: EdgeInsets.only(
                                top: isTablet ? 10.0 : 8.0, right: 0),
                            child: Icon(
                              Icons
                                  .emoji_events_rounded, // trophy icon for history/records
                              color: Colors.white,
                              size: iconSize,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing),
                    Text(
                      'Math Timed Challenge',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Baloo2',
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFFF6B6B),
                        letterSpacing: 1.0,
                        shadows: [
                          Shadow(
                            color: Colors.white,
                            blurRadius: isTablet ? 5.0 : 4.0,
                            offset: Offset(0, isTablet ? 1.5 : 1.0),
                          ),
                          Shadow(
                            color: Colors.black12,
                            blurRadius: isTablet ? 5.0 : 4.0,
                            offset: Offset(0, isTablet ? 2.5 : 2.0),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: smallSpacing),
                    Text(
                      'Choose your challenge, ${widget.profileName}!',
                      style: TextStyle(
                        fontSize: subtitleFontSize,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF24924B),
                        fontFamily: 'Baloo2',
                      ),
                    ),
                    SizedBox(height: smallSpacing),
                    _buildAdaptiveRecommendationCard(
                      isTablet: isTablet,
                      isLandscape: isLandscape,
                      borderRadius: borderRadius,
                    ),
                    SizedBox(height: spacing),
                    _buildGradeSelection(
                        isTablet,
                        isLandscape,
                        isSmallPhoneLandscape,
                        borderRadius,
                        buttonFontSize,
                        buttonPadding,
                        smallSpacing),
                    SizedBox(height: spacing),
                    _buildOperationSelection(
                        isTablet,
                        isLandscape,
                        isSmallPhoneLandscape,
                        borderRadius,
                        buttonFontSize,
                        buttonPadding,
                        smallSpacing),
                    SizedBox(height: spacing),
                    _buildQuestionSelection(
                        isTablet,
                        isLandscape,
                        isSmallPhoneLandscape,
                        borderRadius,
                        buttonFontSize,
                        buttonPadding,
                        smallSpacing,
                        subtitleFontSize),
                    SizedBox(height: spacing),
                    _buildTimeSelection(
                        isTablet,
                        isLandscape,
                        isSmallPhoneLandscape,
                        borderRadius,
                        buttonFontSize,
                        buttonPadding,
                        smallSpacing,
                        subtitleFontSize),
                    const Spacer(),
                    _buildStartButton(isTablet, isLandscape,
                        isSmallPhoneLandscape, borderRadius, spacing),
                    SizedBox(height: isTablet ? 32.0 : 24.0),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAdaptiveRecommendationCard({
    required bool isTablet,
    required bool isLandscape,
    required double borderRadius,
  }) {
    if (_loadingAdaptive) {
      return const SizedBox(
        height: 28,
        width: 28,
        child: CircularProgressIndicator(strokeWidth: 2.2),
      );
    }

    final recommendation = _adaptiveRecommendation;
    if (recommendation == null) {
      return const SizedBox.shrink();
    }

    final compact = isLandscape && !isTablet;
    return Semantics(
      container: true,
      label: 'Adaptive difficulty recommendation',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 14 : 10,
          vertical: isTablet ? 10 : 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(borderRadius * 0.85),
          border: Border.all(
            color: const Color(0xFF8E6CFF).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF8E6CFF),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    recommendation.message,
                    style: TextStyle(
                      fontSize: compact ? 11.5 : (isTablet ? 14.5 : 13),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3A3A3A),
                      fontFamily: 'Baloo2',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              recommendation.hasRecommendationChange
                  ? 'Suggested grade: ${recommendation.recommendedGrade} (from ${recommendation.baseGrade})'
                  : 'Suggested grade: stay at ${recommendation.baseGrade}',
              style: TextStyle(
                fontSize: compact ? 10.5 : (isTablet ? 13 : 12),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4B6584),
                fontFamily: 'Baloo2',
              ),
            ),
            if (recommendation.hasRecommendationChange) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  label:
                      'Apply adaptive recommendation ${recommendation.recommendedGrade}',
                  child: OutlinedButton.icon(
                    onPressed: _applyAdaptiveGradeRecommendation,
                    icon: const Icon(Icons.trending_up_rounded, size: 16),
                    label: const Text('Apply Suggestion'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 40),
                      foregroundColor: const Color(0xFF8E6CFF),
                      side: const BorderSide(color: Color(0xFF8E6CFF)),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Baloo2',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGradeSelection(
      bool isTablet,
      bool isLandscape,
      bool isSmallPhoneLandscape,
      double borderRadius,
      double buttonFontSize,
      double buttonPadding,
      double smallSpacing) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: grades.map((grade) {
          final isSelected = selectedGrade == grade;
          final Color color = isSelected
              ? const Color(0xFF42A5F5)
              : const Color.fromARGB(255, 2, 44, 63); // blue
          return Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 6.0 : (isLandscape ? 3.0 : 4.0)),
            child: Semantics(
              button: true,
              selected: isSelected,
              label: 'Select grade $grade',
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    selectedGrade = grade;
                    selectedOps.clear();
                    selectedOps.addAll(gradeOps[grade]!);
                    _autoAppliedAdaptiveGrade = true;
                  });
                  _refreshAdaptiveRecommendation();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.symmetric(
                      horizontal: buttonPadding,
                      vertical: isTablet ? 12.0 : (isLandscape ? 8.0 : 10.0)),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.white,
                    borderRadius: BorderRadius.circular(borderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.18),
                        blurRadius: isTablet ? 8.0 : 6.0,
                        offset: Offset(0, isTablet ? 3.0 : 2.0),
                      ),
                    ],
                    border: Border.all(
                      color: color,
                      width: isTablet ? 2.5 : 2.0,
                    ),
                  ),
                  child: Text(
                    grade,
                    style: TextStyle(
                      fontSize: buttonFontSize,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : color,
                      fontFamily: 'Baloo2',
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOperationSelection(
      bool isTablet,
      bool isLandscape,
      bool isSmallPhoneLandscape,
      double borderRadius,
      double buttonFontSize,
      double buttonPadding,
      double smallSpacing) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: operations.map((op) {
          final isSelected = selectedOps.contains(op['symbol']);
          final isAllowed = gradeOps[selectedGrade]!.contains(op['symbol']);
          final Color color = isSelected
              ? const Color(0xFF8E6CFF)
              : const Color.fromARGB(255, 63, 2, 63); // purple
          return Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 6.0 : (isLandscape ? 3.0 : 4.0)),
            child: Semantics(
              button: true,
              enabled: isAllowed,
              selected: isSelected,
              label: '${op['label']} operation',
              child: GestureDetector(
                onTap: isAllowed
                    ? () {
                        setState(() {
                          if (isSelected) {
                            selectedOps.remove(op['symbol']);
                          } else {
                            selectedOps.add(op['symbol']);
                          }
                        });
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.symmetric(
                      horizontal: buttonPadding,
                      vertical: isTablet ? 12.0 : (isLandscape ? 8.0 : 10.0)),
                  decoration: BoxDecoration(
                    color: isAllowed
                        ? (isSelected ? color : Colors.white)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(borderRadius),
                    boxShadow: isAllowed
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.18),
                              blurRadius: isTablet ? 8.0 : 6.0,
                              offset: Offset(0, isTablet ? 3.0 : 2.0),
                            ),
                          ]
                        : null,
                    border: Border.all(
                      color: isAllowed ? color : Colors.grey.shade400,
                      width: isTablet ? 2.5 : 2.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        op['symbol'],
                        style: TextStyle(
                          fontSize: isTablet
                              ? 20.0
                              : (isSmallPhoneLandscape
                                  ? 14.0
                                  : (isLandscape ? 16.0 : 18.0)),
                          fontWeight: FontWeight.bold,
                          color: isAllowed
                              ? (isSelected ? Colors.white : color)
                              : Colors.grey.shade500,
                          fontFamily: 'Baloo2',
                        ),
                      ),
                      SizedBox(
                          width: isTablet
                              ? 8.0
                              : (isSmallPhoneLandscape
                                  ? 3.0
                                  : (isLandscape ? 5.0 : 6.0))),
                      Text(
                        op['label'],
                        style: TextStyle(
                          fontSize: buttonFontSize,
                          fontWeight: FontWeight.bold,
                          color: isAllowed
                              ? (isSelected ? Colors.white : color)
                              : Colors.grey.shade500,
                          fontFamily: 'Baloo2',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuestionSelection(
      bool isTablet,
      bool isLandscape,
      bool isSmallPhoneLandscape,
      double borderRadius,
      double buttonFontSize,
      double buttonPadding,
      double smallSpacing,
      double subtitleFontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Questions: ',
          style: TextStyle(
            fontSize: subtitleFontSize,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF24924B),
            fontFamily: 'Baloo2',
          ),
        ),
        SizedBox(width: isTablet ? 12.0 : (isLandscape ? 6.0 : 8.0)),
        ...numQuestionsOptions.map((questionCount) {
          final isSelected = selectedNumQuestions == questionCount;
          final Color color = isSelected
              ? const Color(0xFF43C465)
              : const Color.fromARGB(255, 2, 63, 18); // green
          return Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 6.0 : (isLandscape ? 3.0 : 4.0)),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedNumQuestions = questionCount;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(
                    horizontal: buttonPadding,
                    vertical: isTablet ? 12.0 : (isLandscape ? 8.0 : 10.0)),
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.white,
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.18),
                      blurRadius: isTablet ? 8.0 : 6.0,
                      offset: Offset(0, isTablet ? 3.0 : 2.0),
                    ),
                  ],
                  border: Border.all(
                    color: color,
                    width: isTablet ? 2.5 : 2.0,
                  ),
                ),
                child: Text(
                  '$num',
                  style: TextStyle(
                    fontSize: buttonFontSize,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : color,
                    fontFamily: 'Baloo2',
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTimeSelection(
      bool isTablet,
      bool isLandscape,
      bool isSmallPhoneLandscape,
      double borderRadius,
      double buttonFontSize,
      double buttonPadding,
      double smallSpacing,
      double subtitleFontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Time: ',
          style: TextStyle(
            fontSize: subtitleFontSize,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFF9F43),
            fontFamily: 'Baloo2',
          ),
        ),
        SizedBox(width: isTablet ? 12.0 : (isLandscape ? 6.0 : 8.0)),
        ...timeLimitOptions.map((time) {
          final isSelected = selectedTimeLimit == time;
          final Color color = isSelected
              ? const Color(0xFFFF9F43)
              : const Color.fromARGB(255, 63, 39, 2); // orange
          return Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 6.0 : (isLandscape ? 3.0 : 4.0)),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedTimeLimit = time;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(
                    horizontal: buttonPadding,
                    vertical: isTablet ? 12.0 : (isLandscape ? 8.0 : 10.0)),
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.white,
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.18),
                      blurRadius: isTablet ? 8.0 : 6.0,
                      offset: Offset(0, isTablet ? 3.0 : 2.0),
                    ),
                  ],
                  border: Border.all(
                    color: color,
                    width: isTablet ? 2.5 : 2.0,
                  ),
                ),
                child: Text(
                  '${time}m',
                  style: TextStyle(
                    fontSize: buttonFontSize,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : color,
                    fontFamily: 'Baloo2',
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStartButton(bool isTablet, bool isLandscape,
      bool isSmallPhoneLandscape, double borderRadius, double spacing) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(
          horizontal: isTablet ? 40.0 : (isLandscape ? 20.0 : 20.0)),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: selectedOps.isNotEmpty
              ? const Color(0xFFFF6B6B)
              : Colors.grey.shade400,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius)),
          padding: EdgeInsets.symmetric(
              vertical: isTablet
                  ? 20.0
                  : (isSmallPhoneLandscape
                      ? 10.0
                      : (isLandscape ? 14.0 : 16.0))),
          elevation: selectedOps.isNotEmpty ? 8 : 2,
          shadowColor: selectedOps.isNotEmpty
              ? const Color(0xFFFF6B6B).withValues(alpha: 0.3)
              : Colors.transparent,
        ),
        onPressed: selectedOps.isNotEmpty
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MathChallengeGameScreen(
                      selectedOps: selectedOps,
                      selectedGrade: selectedGrade,
                      selectedNumQuestions: selectedNumQuestions,
                      selectedTimeLimit: selectedTimeLimit,
                      adaptiveDifficultySeed:
                          _adaptiveRecommendation?.liveDifficultySeed ?? 0,
                    ),
                  ),
                );
              }
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: isTablet
                  ? 32.0
                  : (isSmallPhoneLandscape
                      ? 20.0
                      : (isLandscape ? 24.0 : 28.0)),
            ),
            SizedBox(
                width: isTablet
                    ? 12.0
                    : (isSmallPhoneLandscape
                        ? 4.0
                        : (isLandscape ? 6.0 : 8.0))),
            Text(
              'Start Challenge!',
              style: TextStyle(
                fontSize: isTablet
                    ? 24.0
                    : (isSmallPhoneLandscape
                        ? 14.0
                        : (isLandscape ? 18.0 : 20.0)),
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Baloo2',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
