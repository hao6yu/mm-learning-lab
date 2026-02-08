import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../services/activity_progress_service.dart';
import '../utils/activity_launcher.dart';
import '../utils/kid_layout_tokens.dart';
import '../widgets/kid_screen_header.dart';
import '../widgets/kid_game_card.dart';

class GameSelectionScreen extends StatefulWidget {
  const GameSelectionScreen({super.key});

  @override
  State<GameSelectionScreen> createState() => _GameSelectionScreenState();
}

class _GameSelectionScreenState extends State<GameSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final ActivityProgressService _activityProgressService =
      ActivityProgressService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = KidSelectionLayout.fromContext(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8FD6FF), Color(0xFFFFF3E0)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              KidScreenHeader(
                title: 'Learning Games',
                isTablet: layout.isTablet,
                onBack: () => Navigator.pop(context),
                onHome: _goHome,
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: layout.horizontalPadding,
                ),
                child: Text(
                  'Pick one activity to start learning now.',
                  style: TextStyle(
                    fontSize: layout.subtitleFontSize,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF355C7D),
                    fontFamily: 'Baloo2',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: layout.sectionSpacing),

              // Game cards with responsive layout
              Expanded(
                child: _buildGameGrid(layout),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _selectedProfileName() {
    final profileProvider = context.read<ProfileProvider>();
    final selectedProfileId = profileProvider.selectedProfileId;
    if (selectedProfileId == null) {
      return 'Learner';
    }

    for (final profile in profileProvider.profiles) {
      if (profile.id == selectedProfileId) {
        return profile.name;
      }
    }

    return 'Learner';
  }

  Future<void> _openActivity(String activityId) async {
    final profileProvider = context.read<ProfileProvider>();
    final selectedProfileId = profileProvider.selectedProfileId;
    final profileName = _selectedProfileName();

    if (selectedProfileId != null) {
      await _activityProgressService.saveLastActivity(
        profileId: selectedProfileId,
        activityId: activityId,
        activityTitle: activityTitle(activityId),
      );
    }

    if (!mounted) return;
    await launchActivity(
      context,
      activityId,
      profileName: profileName,
    );
  }

  Widget _buildGameGrid(KidSelectionLayout layout) {
    final games = [
      _GameData(
        title: 'AI Story Time',
        subtitle: 'Create and read stories',
        color: const Color(0xFF8E6CFF),
        icon: CupertinoIcons.wand_stars,
        isNew: true,
        onTap: () => _openActivity(ActivityIds.storyAdventure),
      ),
      _GameData(
        title: 'Talk with AI',
        subtitle: 'Practice speaking and listening',
        color: const Color(0xFF3ED6C1),
        icon: CupertinoIcons.chat_bubble_fill,
        isNew: true,
        onTap: () => _openActivity(ActivityIds.aiChat),
      ),
      _GameData(
        title: 'Letter Tracing',
        subtitle: 'Trace letters with your finger',
        color: const Color(0xFFFF9F43),
        icon: CupertinoIcons.pencil,
        onTap: () => _openActivity(ActivityIds.letterTracing),
      ),
      _GameData(
        title: 'Bubble Pop',
        subtitle: 'Pop the right letters fast',
        color: const Color(0xFF3ED6C1),
        icon: CupertinoIcons.circle_grid_3x3,
        onTap: () => _openActivity(ActivityIds.bubblePop),
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: layout.horizontalPadding,
        vertical: layout.verticalPadding,
      ),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return layout.isLandscape
              ? _buildLandscapeGrid(games, layout)
              : _buildPortraitGrid(games, layout);
        },
      ),
    );
  }

  Widget _buildLandscapeGrid(List<_GameData> games, KidSelectionLayout layout) {
    final crossAxisCount = layout.columnsForLandscape(games.length);
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: layout.gridSpacing,
        mainAxisSpacing: layout.gridSpacing,
        childAspectRatio: layout.landscapeAspectRatio(crossAxisCount),
      ),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        return _buildAnimatedCard(
          index,
          KidGameCard(
            title: game.title,
            subtitle: game.subtitle,
            color: game.color,
            icon: game.icon,
            isNew: game.isNew,
            onTap: game.onTap,
            isTablet: layout.isTablet,
            isLandscape: true,
          ),
        );
      },
    );
  }

  Widget _buildPortraitGrid(List<_GameData> games, KidSelectionLayout layout) {
    final cardHeight = layout.portraitCardHeight(games.length);
    return SingleChildScrollView(
      child: Column(
        children: games.asMap().entries.map((entry) {
          final index = entry.key;
          final game = entry.value;
          final isLast = index == games.length - 1;

          return Container(
            height: cardHeight,
            margin: EdgeInsets.only(
              bottom: isLast ? 0 : layout.gridSpacing,
            ),
            child: _buildAnimatedCard(
              index,
              KidGameCard(
                title: game.title,
                subtitle: game.subtitle,
                color: game.color,
                icon: game.icon,
                isNew: game.isNew,
                onTap: game.onTap,
                isTablet: layout.isTablet,
                isLandscape: false,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnimatedCard(int index, Widget child) {
    final delay = index * 0.2;
    final start = delay;
    final end = (start + 0.6).clamp(0.0, 1.0);
    final fadeInInterval = Interval(start, end, curve: Curves.easeOutBack);

    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: fadeInInterval,
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: fadeInInterval,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _GameData {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final bool isNew;
  final VoidCallback onTap;

  _GameData({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
    this.isNew = false,
  });
}
