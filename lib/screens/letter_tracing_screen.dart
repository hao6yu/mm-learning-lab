import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../services/activity_progress_service.dart';
import '../services/theme_service.dart';
import '../utils/activity_launcher.dart';
import '../widgets/kid_screen_header.dart';
import '../widgets/tracing_canvas.dart';

class LetterTracingScreen extends StatefulWidget {
  const LetterTracingScreen({super.key});

  @override
  State<LetterTracingScreen> createState() => _LetterTracingScreenState();
}

class _LetterTracingScreenState extends State<LetterTracingScreen> {
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

  final ActivityProgressService _activityProgressService =
      ActivityProgressService();

  int _currentLetterIndex = 0;
  int _completedLetters = 0;
  int _streak = 0;
  bool _showGuide = true;
  bool _animateDemo = false;
  bool _isUpperCase = true;
  bool _showSuccessCard = false;
  Key _canvasKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordLastPlayed();
      _maybeShowOnboarding();
    });
  }

  Future<void> _recordLastPlayed() async {
    final selectedProfileId = context.read<ProfileProvider>().selectedProfileId;
    if (selectedProfileId == null) {
      return;
    }

    await _activityProgressService.saveLastActivity(
      profileId: selectedProfileId,
      activityId: ActivityIds.letterTracing,
      activityTitle: activityTitle(ActivityIds.letterTracing),
    );
  }

  Future<void> _maybeShowOnboarding() async {
    final hasSeen = await _activityProgressService
        .hasSeenOnboarding(ActivityIds.letterTracing);

    if (hasSeen || !mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tracing Tips'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Follow the big guide letter with your finger.'),
            SizedBox(height: 8),
            Text('2. Use Demo when you want help.'),
            SizedBox(height: 8),
            Text('3. Keep tracing to grow your streak!'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    await _activityProgressService
        .markOnboardingSeen(ActivityIds.letterTracing);
  }

  String get _currentLetter {
    final letter = _letters[_currentLetterIndex];
    return _isUpperCase ? letter : letter.toLowerCase();
  }

  void _triggerDemo() {
    if (_showSuccessCard) {
      return;
    }

    setState(() {
      _animateDemo = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _animateDemo = true;
      });
    });
  }

  void _onDemoComplete() {
    if (!mounted) return;
    setState(() {
      _animateDemo = false;
    });
  }

  void _switchLetter(int newIndex) {
    final boundedIndex = newIndex.clamp(0, _letters.length - 1);
    setState(() {
      _currentLetterIndex = boundedIndex;
      _animateDemo = false;
      _showSuccessCard = false;
      _canvasKey = UniqueKey();
    });
  }

  void _resetCanvas() {
    setState(() {
      _animateDemo = false;
      _showSuccessCard = false;
      _canvasKey = UniqueKey();
    });
  }

  void _toggleCase() {
    setState(() {
      _isUpperCase = !_isUpperCase;
      _animateDemo = false;
      _showSuccessCard = false;
      _canvasKey = UniqueKey();
    });
  }

  void _onTracingCompleted() {
    if (_showSuccessCard) {
      return;
    }

    setState(() {
      _completedLetters += 1;
      _streak += 1;
      _showSuccessCard = true;
    });
  }

  void _nextLetter() {
    if (_currentLetterIndex >= _letters.length - 1) {
      _resetCanvas();
      return;
    }

    _switchLetter(_currentLetterIndex + 1);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final shortestSide = math.min(media.size.width, media.size.height);
    final isTablet = shortestSide >= 600;
    final isLandscape = media.size.width > media.size.height;
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
                title: 'Letter Tracing',
                isTablet: isTablet,
                onBack: () => Navigator.pop(context),
                trailing: _HeaderControls(
                  showGuide: _showGuide,
                  isUpperCase: _isUpperCase,
                  onToggleGuide: () {
                    setState(() {
                      _showGuide = !_showGuide;
                    });
                  },
                  onToggleCase: _toggleCase,
                  isTablet: isTablet,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 24 : 14,
                    8,
                    isTablet ? 24 : 14,
                    isTablet ? 20 : 12,
                  ),
                  child: isTablet && isLandscape
                      ? _buildTabletLandscapeLayout()
                      : _buildMainLayout(isTablet: isTablet),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletLandscapeLayout() {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: _buildMainLayout(isTablet: true),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 230,
          child: _buildSidePanel(),
        ),
      ],
    );
  }

  Widget _buildMainLayout({required bool isTablet}) {
    return Column(
      children: [
        Row(
          children: [
            _StatBadge(
              label: 'Letter',
              value: '${_currentLetterIndex + 1}/${_letters.length}',
              color: const Color(0xFF8E6CFF),
            ),
            const SizedBox(width: 8),
            _StatBadge(
              label: 'Completed',
              value: '$_completedLetters',
              color: const Color(0xFF43C465),
            ),
            const SizedBox(width: 8),
            _StatBadge(
              label: 'Streak',
              value: '$_streak',
              color: const Color(0xFFFF9F43),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Trace this letter',
          style: TextStyle(
            fontFamily: 'Baloo2',
            fontSize: isTablet ? 26 : 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF5F6FD6),
          ),
        ),
        Text(
          _currentLetter,
          style: TextStyle(
            fontFamily: 'Baloo2',
            fontSize: isTablet ? 108 : 92,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF8E6CFF),
            height: 1,
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTablet ? 430 : 340,
                maxHeight: isTablet ? 540 : 420,
              ),
              child: AspectRatio(
                aspectRatio: 0.75,
                child: TracingCanvas(
                  key: _canvasKey,
                  letter: _currentLetter,
                  showGuide: _showGuide,
                  animateDemo: _animateDemo,
                  onDemoComplete: _onDemoComplete,
                  onCompleted: _onTracingCompleted,
                ),
              ),
            ),
          ),
        ),
        if (_showSuccessCard) _buildSuccessCard(isTablet: isTablet),
        if (!_showSuccessCard)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildActionRow(isTablet: isTablet),
          ),
      ],
    );
  }

  Widget _buildActionRow({required bool isTablet}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _currentLetterIndex > 0
              ? () => _switchLetter(_currentLetterIndex - 1)
              : null,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Prev'),
        ),
        OutlinedButton.icon(
          onPressed: _resetCanvas,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reset'),
        ),
        FilledButton.icon(
          onPressed: _triggerDemo,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF9F43),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.play_circle_fill_rounded),
          label: const Text('Demo'),
        ),
        FilledButton.icon(
          onPressed:
              _currentLetterIndex < _letters.length - 1 ? _nextLetter : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF8E6CFF),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text(
            _currentLetterIndex < _letters.length - 1 ? 'Next' : 'Done',
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessCard({required bool isTablet}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 16 : 12,
        vertical: isTablet ? 12 : 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F8EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF57C47D), width: 1.2),
      ),
      child: Column(
        children: [
          Text(
            'Great tracing! 🎉',
            style: TextStyle(
              fontFamily: 'Baloo2',
              fontSize: isTablet ? 22 : 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF2B8F50),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _resetCanvas,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Play Again'),
              ),
              FilledButton.icon(
                onPressed: _nextLetter,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8E6CFF),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  _currentLetterIndex < _letters.length - 1
                      ? 'Next Letter'
                      : 'Finish',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
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
              color: const Color(0xFF8E6CFF),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Current: $_currentLetter',
            style: const TextStyle(
              fontFamily: 'Baloo2',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4E5C6A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Completed: $_completedLetters',
            style: const TextStyle(
              fontFamily: 'Baloo2',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4E5C6A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Streak: $_streak',
            style: const TextStyle(
              fontFamily: 'Baloo2',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4E5C6A),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _triggerDemo,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF9F43),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.play_circle_fill_rounded),
              label: const Text('Demo'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _resetCanvas,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reset'),
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
        ],
      ),
    );
  }
}

class _HeaderControls extends StatelessWidget {
  final bool showGuide;
  final bool isUpperCase;
  final VoidCallback onToggleGuide;
  final VoidCallback onToggleCase;
  final bool isTablet;

  const _HeaderControls({
    required this.showGuide,
    required this.isUpperCase,
    required this.onToggleGuide,
    required this.onToggleCase,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final iconButtonSize = isTablet ? 44.0 : 40.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onToggleGuide,
          borderRadius: BorderRadius.circular(99),
          child: Container(
            width: iconButtonSize,
            height: iconButtonSize,
            decoration: BoxDecoration(
              color: const Color(0xFFFF9F43),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0x33FF9F43),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              showGuide
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: Colors.white,
              size: isTablet ? 24 : 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onToggleCase,
          borderRadius: BorderRadius.circular(99),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF43C465),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x3343C465),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              isUpperCase ? 'A/a' : 'a/A',
              style: TextStyle(
                fontFamily: 'Baloo2',
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Baloo2',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Baloo2',
                fontSize: 13,
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
