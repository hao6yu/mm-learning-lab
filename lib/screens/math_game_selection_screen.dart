import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../services/activity_progress_service.dart';
import '../services/theme_service.dart';
import '../utils/activity_launcher.dart';
import '../utils/kid_layout_tokens.dart';
import '../widgets/kid_game_card.dart';
import '../widgets/kid_screen_header.dart';

class MathGameSelectionScreen extends StatelessWidget {
  final String profileName;
  const MathGameSelectionScreen({super.key, required this.profileName});

  @override
  Widget build(BuildContext context) {
    final layout = KidSelectionLayout.fromContext(context);
    final themeConfig = context.watch<ThemeService>().config;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: themeConfig.screenGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              KidScreenHeader(
                title: 'Math Games',
                isTablet: layout.isTablet,
                onBack: () => Navigator.pop(context),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: layout.horizontalPadding,
                ),
                child: Text(
                  'Choose one math game to keep your streak going.',
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
        title: 'Math Buddy',
        subtitle: 'Solve quick practice rounds',
        color: const Color(0xFF8E6CFF),
        icon: Icons.emoji_people_rounded,
        isNew: true,
        route: ActivityIds.mathBuddy,
      ),
      _GameData(
        title: 'Timed Math Challenge',
        subtitle: 'Beat the clock',
        color: const Color(0xFFFF9F43),
        icon: Icons.timer_rounded,
        route: ActivityIds.mathChallenge,
      ),
      _GameData(
        title: "Kid's Calculator",
        subtitle: 'Learn with guided calculations',
        color: const Color(0xFF43C465),
        icon: Icons.calculate_rounded,
        route: ActivityIds.kidsCalculator,
      ),
      _GameData(
        title: 'Number Pop',
        subtitle: 'Tap the correct answers fast',
        color: const Color(0xFF3ED6C1),
        icon: Icons.bubble_chart,
        route: ActivityIds.numberPop,
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
  final bool isNew;
  final String route;

  _GameData({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.route,
    this.isNew = false,
  });
}
