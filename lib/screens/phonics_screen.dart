import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../services/activity_progress_service.dart';
import '../services/theme_service.dart';
import '../utils/activity_launcher.dart';
import '../widgets/kid_screen_header.dart';
import '../widgets/letter_bubble.dart';

class PhonicsScreen extends StatefulWidget {
  const PhonicsScreen({super.key});

  @override
  State<PhonicsScreen> createState() => _PhonicsScreenState();
}

class _PhonicsScreenState extends State<PhonicsScreen> {
  static const int _totalRounds = 10;
  static const List<String> _letters = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  final math.Random _random = math.Random();
  final ActivityProgressService _activityProgressService =
      ActivityProgressService();

  int _roundNumber = 1;
  int _score = 0;
  int _streak = 0;
  int _correctCount = 0;

  _PhonicsRound _currentRound = const _PhonicsRound(
    targetLetter: 'A',
    options: ['A', 'B', 'C', 'D'],
  );
  String? _selectedLetter;
  _RoundFeedback? _feedback;
  bool _isSessionCompleted = false;

  @override
  void initState() {
    super.initState();
    _startSession();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowOnboarding();
      _recordLastPlayed();
    });
  }

  Future<void> _recordLastPlayed() async {
    final profileProvider = context.read<ProfileProvider>();
    final selectedProfileId = profileProvider.selectedProfileId;
    if (selectedProfileId == null) {
      return;
    }

    await _activityProgressService.saveLastActivity(
      profileId: selectedProfileId,
      activityId: ActivityIds.phonics,
      activityTitle: activityTitle(ActivityIds.phonics),
    );
  }

  Future<void> _maybeShowOnboarding() async {
    final hasSeen =
        await _activityProgressService.hasSeenOnboarding(ActivityIds.phonics);

    if (hasSeen || !mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text(
            'How To Play',
            textAlign: TextAlign.center,
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('1. Tap the letter that matches the prompt.'),
              SizedBox(height: 8),
              Text('2. Keep your streak going for more points.'),
              SizedBox(height: 8),
              Text('3. Finish 10 rounds to see your reward card.'),
            ],
          ),
          actions: [
            Center(
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Let's Play"),
              ),
            ),
          ],
        );
      },
    );

    await _activityProgressService.markOnboardingSeen(ActivityIds.phonics);
  }

  void _startSession() {
    setState(() {
      _roundNumber = 1;
      _score = 0;
      _streak = 0;
      _correctCount = 0;
      _selectedLetter = null;
      _feedback = null;
      _isSessionCompleted = false;
      _currentRound = _generateRound();
    });
  }

  _PhonicsRound _generateRound() {
    final targetLetter = _letters[_random.nextInt(_letters.length)];
    final options = <String>{targetLetter};

    while (options.length < 4) {
      options.add(_letters[_random.nextInt(_letters.length)]);
    }

    final shuffledOptions = options.toList()..shuffle(_random);
    return _PhonicsRound(
      targetLetter: targetLetter,
      options: shuffledOptions,
    );
  }

  void _onLetterTap(String letter) {
    if (_feedback != null || _isSessionCompleted) {
      return;
    }

    final isCorrect = letter == _currentRound.targetLetter;

    setState(() {
      _selectedLetter = letter;
      _feedback = isCorrect ? _RoundFeedback.correct : _RoundFeedback.incorrect;

      if (isCorrect) {
        _correctCount += 1;
        _streak += 1;
        _score += 10 + ((_streak - 1) * 2);
      } else {
        _streak = 0;
      }
    });
  }

  void _retryCurrentRound() {
    if (_isSessionCompleted) {
      return;
    }

    setState(() {
      _selectedLetter = null;
      _feedback = null;
    });
  }

  void _nextRound() {
    if (_roundNumber >= _totalRounds) {
      setState(() {
        _isSessionCompleted = true;
      });
      return;
    }

    setState(() {
      _roundNumber += 1;
      _selectedLetter = null;
      _feedback = null;
      _currentRound = _generateRound();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final shortestSide = math.min(size.width, size.height);
    final isTablet = shortestSide >= 600;
    final isLandscape = size.width > size.height;
    final themeConfig = context.watch<ThemeService>().config;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: themeConfig.screenGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              KidScreenHeader(
                title: 'Phonics Fun',
                isTablet: isTablet,
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _isSessionCompleted
                      ? _buildSessionSummary(isTablet: isTablet)
                      : _buildActiveSession(
                          isTablet: isTablet,
                          isLandscape: isLandscape,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSession({
    required bool isTablet,
    required bool isLandscape,
  }) {
    if (isTablet && isLandscape) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildRoundPanel(isTablet: true, isLandscape: true),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 220,
              child: _buildTabletSidePanel(),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isTablet ? 28 : 16,
        8,
        isTablet ? 28 : 16,
        isTablet ? 20 : 14,
      ),
      child: Column(
        children: [
          _buildProgressHeader(isTablet: isTablet),
          const SizedBox(height: 12),
          Expanded(
            child: _buildRoundPanel(isTablet: isTablet, isLandscape: false),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressHeader({required bool isTablet}) {
    final progress = _roundNumber / _totalRounds;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _MiniStatChip(
                label: 'Round',
                value: '$_roundNumber/$_totalRounds',
                color: const Color(0xFF8E6CFF),
              ),
              const SizedBox(width: 8),
              _MiniStatChip(
                label: 'Score',
                value: '$_score',
                color: const Color(0xFF43C465),
              ),
              const SizedBox(width: 8),
              _MiniStatChip(
                label: 'Streak',
                value: '$_streak',
                color: const Color(0xFFFF9F43),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: isTablet ? 10 : 8,
              value: progress,
              backgroundColor: const Color(0xFFDCEAF8),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF8E6CFF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundPanel({required bool isTablet, required bool isLandscape}) {
    final bubbleSize =
        isTablet ? (isLandscape ? 112.0 : 104.0) : (isLandscape ? 80.0 : 90.0);

    return Container(
      key: ValueKey<int>(_roundNumber),
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 20 : 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(isTablet ? 28 : 24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Find the letter:',
            style: TextStyle(
              fontFamily: 'Baloo2',
              fontSize: isTablet ? 30 : 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF6A5ACD),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 22 : 18,
              vertical: isTablet ? 12 : 9,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE066),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              _currentRound.targetLetter,
              style: TextStyle(
                fontFamily: 'Baloo2',
                fontSize: isTablet ? 58 : 46,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF9E6C00),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: isTablet ? 22 : 14,
            runSpacing: isTablet ? 22 : 14,
            alignment: WrapAlignment.center,
            children: _currentRound.options.map((letter) {
              final showResult = _feedback != null;
              final isCorrectTarget =
                  showResult && letter == _currentRound.targetLetter;
              final isWrongSelection = showResult &&
                  _feedback == _RoundFeedback.incorrect &&
                  letter == _selectedLetter;

              return LetterBubble(
                letter: letter,
                size: bubbleSize,
                enabled: _feedback == null,
                isSelected: _selectedLetter == letter,
                showResult: showResult,
                isCorrectTarget: isCorrectTarget,
                isWrongSelection: isWrongSelection,
                onTap: () => _onLetterTap(letter),
              );
            }).toList(),
          ),
          const Spacer(),
          _buildFeedbackArea(isTablet: isTablet),
        ],
      ),
    );
  }

  Widget _buildFeedbackArea({required bool isTablet}) {
    if (_feedback == null) {
      return Text(
        'Tap one bubble to answer',
        style: TextStyle(
          fontFamily: 'Baloo2',
          fontSize: isTablet ? 18 : 16,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF607D8B),
        ),
      );
    }

    final isCorrect = _feedback == _RoundFeedback.correct;
    final title = isCorrect ? 'Great job!' : 'Nice try!';
    final message = isCorrect
        ? 'You found the right letter.'
        : 'The right letter is ${_currentRound.targetLetter}.';

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color:
                isCorrect ? const Color(0xFFE1F8E8) : const Color(0xFFFFE7E7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isCorrect ? const Color(0xFF6DD28D) : const Color(0xFFFF8A8A),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isCorrect ? Icons.celebration_rounded : Icons.lightbulb_rounded,
                color: isCorrect
                    ? const Color(0xFF2F9A54)
                    : const Color(0xFFC45151),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Baloo2',
                        fontSize: isTablet ? 20 : 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF2F3A4D),
                      ),
                    ),
                    Text(
                      message,
                      style: TextStyle(
                        fontFamily: 'Baloo2',
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF556070),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isCorrect ? _startSession : _retryCurrentRound,
                icon: Icon(
                    isCorrect ? Icons.replay_rounded : Icons.refresh_rounded),
                label: Text(isCorrect ? 'Play Again' : 'Try Again'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _nextRound,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8E6CFF),
                  foregroundColor: Colors.white,
                ),
                icon: Icon(
                  _roundNumber == _totalRounds
                      ? Icons.flag_rounded
                      : Icons.arrow_forward_rounded,
                ),
                label: Text(
                  _roundNumber == _totalRounds ? 'Finish' : 'Next',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabletSidePanel() {
    final progress = _roundNumber / _totalRounds;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress',
            style: TextStyle(
              fontFamily: 'Baloo2',
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF6A5ACD),
            ),
          ),
          const SizedBox(height: 10),
          _SidePanelStat(
              label: 'Round', value: '$_roundNumber / $_totalRounds'),
          _SidePanelStat(label: 'Score', value: '$_score'),
          _SidePanelStat(label: 'Streak', value: '$_streak'),
          _SidePanelStat(label: 'Correct', value: '$_correctCount'),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 12,
              value: progress,
              backgroundColor: const Color(0xFFDCEAF8),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF8E6CFF)),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/games'),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Switch Game'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _startSession,
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Restart'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionSummary({required bool isTablet}) {
    final accuracy = (_correctCount / _totalRounds * 100).round();

    return Center(
      key: const ValueKey<String>('summary'),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 16),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 560),
          padding: EdgeInsets.all(isTablet ? 26 : 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Great Learning!',
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: isTablet ? 44 : 36,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF6A5ACD),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Score: $_score  •  Accuracy: $accuracy%',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: isTablet ? 22 : 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF3E4A5F),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _startSession,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Play Again'),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/games'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF43C465),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Switch Game'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Home'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Baloo2',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Baloo2',
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidePanelStat extends StatelessWidget {
  final String label;
  final String value;

  const _SidePanelStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Baloo2',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF607D8B),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Baloo2',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF37474F),
            ),
          ),
        ],
      ),
    );
  }
}

enum _RoundFeedback { correct, incorrect }

class _PhonicsRound {
  final String targetLetter;
  final List<String> options;

  const _PhonicsRound({
    required this.targetLetter,
    required this.options,
  });
}
