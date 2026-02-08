import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../services/activity_progress_service.dart';
import '../utils/activity_launcher.dart';
import '../utils/kid_layout_tokens.dart';
import '../widgets/kid_game_card.dart';
import '../widgets/kid_screen_header.dart';

class PuzzleGameSelectionScreen extends StatelessWidget {
  const PuzzleGameSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = KidSelectionLayout.fromContext(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAF6FF), Color(0xFFF3E8FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              KidScreenHeader(
                title: 'Puzzle Games',
                isTablet: layout.isTablet,
                onBack: () => Navigator.pop(context),
                onHome: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: layout.horizontalPadding,
                ),
                child: Text(
                  'Challenge your brain with one puzzle game.',
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
                child: _buildGameGrid(context, layout),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameGrid(BuildContext context, KidSelectionLayout layout) {
    final games = [
      _GameData(
        title: 'Sudoku',
        subtitle: 'Fill the grid with logic',
        color: const Color(0xFFE91E63),
        icon: Icons.grid_4x4,
        route: ActivityIds.sudoku,
        isNew: true,
      ),
      _GameData(
        title: 'Memory Match',
        subtitle: 'Find all matching pairs',
        color: const Color(0xFF43C465),
        icon: Icons.memory_rounded,
        route: ActivityIds.memoryMatch,
      ),
      _GameData(
        title: 'Tic-Tac-Toe',
        subtitle: 'Get 3 in a row',
        color: const Color(0xFFFF9F43),
        icon: Icons.grid_3x3,
        route: ActivityIds.ticTacToe,
      ),
      _GameData(
        title: 'Gobang',
        subtitle: 'Build 5 in a row',
        color: const Color(0xFF00B8D4),
        icon: Icons.blur_circular,
        route: ActivityIds.gobang,
      ),
      _GameData(
        title: 'Chess',
        subtitle: 'Plan smart moves',
        color: const Color(0xFF8E6CFF),
        icon: Icons.emoji_events,
        route: ActivityIds.chess,
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: layout.horizontalPadding,
        vertical: layout.verticalPadding,
      ),
      child: layout.isLandscape
          ? _buildLandscapeGrid(games, layout)
          : _buildPortraitGrid(context, games, layout),
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
        return KidGameCard(
          title: game.title,
          subtitle: game.subtitle,
          color: game.color,
          icon: game.icon,
          isNew: game.isNew,
          onTap: () => _navigateToGame(context, game.route),
          isTablet: layout.isTablet,
          isLandscape: true,
        );
      },
    );
  }

  Widget _buildPortraitGrid(
      BuildContext context, List<_GameData> games, KidSelectionLayout layout) {
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
            child: KidGameCard(
              title: game.title,
              subtitle: game.subtitle,
              color: game.color,
              icon: game.icon,
              isNew: game.isNew,
              onTap: () => _navigateToGame(context, game.route),
              isTablet: layout.isTablet,
              isLandscape: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _navigateToGame(BuildContext context, String activityId) async {
    final profileProvider = context.read<ProfileProvider>();
    final selectedProfileId = profileProvider.selectedProfileId;
    final profileName = profileProvider.profiles
        .where((profile) => profile.id == selectedProfileId)
        .map((profile) => profile.name)
        .firstWhere(
          (name) => name.isNotEmpty,
          orElse: () => 'Learner',
        );
    final activityService = ActivityProgressService();

    if (selectedProfileId != null) {
      await activityService.saveLastActivity(
        profileId: selectedProfileId,
        activityId: activityId,
        activityTitle: activityTitle(activityId),
      );
    }

    if (!context.mounted) return;
    await launchActivity(
      context,
      activityId,
      profileName: profileName,
    );
  }
}

class _GameData {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final String route;
  final bool isNew;

  _GameData({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.route,
    this.isNew = false,
  });
}
