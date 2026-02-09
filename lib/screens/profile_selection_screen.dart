import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:io';
import '../config/app_theme.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_card.dart';
import '../widgets/add_profile_modal.dart';
import '../widgets/quick_avatar_update_modal.dart';
import '../widgets/theme_picker.dart';
import '../widgets/valentine_decorations.dart';
import '../services/subscription_service.dart';
import '../services/activity_progress_service.dart';
import '../services/theme_service.dart';
import '../models/profile.dart';
import '../utils/activity_launcher.dart';
import 'math_game_selection_screen.dart';

class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> {
  static const String _aiLimitsHintSeenKey = 'ai_limits_hint_seen_v1';
  final ActivityProgressService _activityProgressService =
      ActivityProgressService();
  static const AssetImage _homeBackgroundImage =
      AssetImage('assets/images/homepage-background.png');
  final Map<int, Future<ActivityProgress?>> _lastActivityFutures = {};
  bool _didPrecacheBackground = false;
  bool _showAiLimitsHint = false;
  bool _didShowAiLimitsHint = false;

  @override
  void initState() {
    super.initState();
    // Load profiles as soon as this screen is initialized.
    context.read<ProfileProvider>().loadProfiles();
    _loadAiLimitsHintState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrecacheBackground) {
      _didPrecacheBackground = true;
      // ignore: discarded_futures
      precacheImage(_homeBackgroundImage, context);
    }
  }

  Future<ActivityProgress?> _lastActivityFutureFor(int profileId) {
    return _lastActivityFutures.putIfAbsent(
      profileId,
      () => _activityProgressService.getLastActivity(profileId),
    );
  }

  void _refreshLastActivityFuture(int profileId) {
    _lastActivityFutures[profileId] =
        _activityProgressService.getLastActivity(profileId);
  }

  void _openProgressScreen() {
    Navigator.pushNamed(context, '/progress');
  }

  void _openAiLimitsScreen() {
    _dismissAiLimitsHint();
    Navigator.pushNamed(context, '/ai-limits');
  }

  void _showThemePicker(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(context).viewPadding.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ThemePicker(isTablet: isTablet),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadAiLimitsHintState() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_aiLimitsHintSeenKey) ?? false;
    if (!mounted) return;
    setState(() {
      _showAiLimitsHint = !seen;
    });
    if (!seen) {
      _showAiLimitsHintSnackBarIfNeeded();
    }
  }

  Future<void> _dismissAiLimitsHint() async {
    if (!_showAiLimitsHint) return;
    setState(() {
      _showAiLimitsHint = false;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aiLimitsHintSeenKey, true);
  }

  void _showAiLimitsHintSnackBarIfNeeded() {
    if (_didShowAiLimitsHint || !_showAiLimitsHint || !mounted) return;
    _didShowAiLimitsHint = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('Tip: Manage AI chat/story/call limits in AI Limits.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Open',
            onPressed: _openAiLimitsScreen,
          ),
        ),
      );
    });
  }

  // Helper method to get avatar color
  Color _getAvatarColor(String avatar) {
    switch (avatar) {
      case '👧':
        return const Color(0xFFFFE066); // Yellow for Madeline
      case '👦':
        return const Color(0xFFB3E0FF); // Blue for Matthew
      default:
        return const Color(0xFFFFD3B6); // Default peachy color
    }
  }

  String _formatLastPlayed(DateTime playedAt) {
    final now = DateTime.now();
    final difference = now.difference(playedAt);

    if (difference.inDays >= 1) {
      return difference.inDays == 1
          ? 'Played yesterday'
          : 'Played ${difference.inDays} days ago';
    }

    if (difference.inHours >= 1) {
      return 'Played ${difference.inHours}h ago';
    }

    return 'Played just now';
  }

  Widget _buildQuickResumeCard(
    Profile selected, {
    required bool isTablet,
    required bool isLandscape,
    required themeConfig,
  }) {
    final profileId = selected.id;
    if (profileId == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<ActivityProgress?>(
      key: ValueKey<int>(profileId),
      future: _lastActivityFutureFor(profileId),
      builder: (context, snapshot) {
        final activity = snapshot.data;
        final cardPadding = isTablet ? 16.0 : (isLandscape ? 10.0 : 12.0);
        final iconSize = isTablet ? 28.0 : 24.0;
        final titleSize = isTablet ? 18.0 : 16.0;
        final subtitleSize = isTablet ? 14.0 : 12.0;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: EdgeInsets.symmetric(
              vertical: cardPadding,
              horizontal: cardPadding,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const SizedBox(
              height: 20,
              width: 20,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2.0),
              ),
            ),
          );
        }

        if (activity == null) {
          return Container(
            width: isLandscape ? 240.0 : double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: cardPadding,
              horizontal: cardPadding,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF8FD6FF), width: 1.4),
            ),
            child: Text(
              'Pick any game to start quick resume.',
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: subtitleSize,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4B6584),
              ),
            ),
          );
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isLandscape ? 320.0 : (isTablet ? 460.0 : 360.0),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: cardPadding,
              horizontal: cardPadding,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF8FD6FF), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      activityIcon(activity.activityId),
                      size: iconSize,
                      color: themeConfig.cardPuzzle,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Continue ${activity.activityTitle}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.baloo2(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF3E3E3E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatLastPlayed(activity.playedAt),
                  style: GoogleFonts.baloo2(
                    fontSize: subtitleSize,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6C7A89),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF43C465),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    await _activityProgressService.saveLastActivity(
                      profileId: profileId,
                      activityId: activity.activityId,
                      activityTitle: activity.activityTitle,
                    );
                    if (mounted) {
                      setState(() {
                        _refreshLastActivityFuture(profileId);
                      });
                    }
                    if (!context.mounted) return;
                    await launchActivity(
                      context,
                      activity.activityId,
                      profileName: selected.name,
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    'Resume',
                    style: GoogleFonts.baloo2(
                      fontWeight: FontWeight.w800,
                      fontSize: subtitleSize + 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to show avatar update modal
  void _showAvatarUpdateModal(Profile profile) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => QuickAvatarUpdateModal(profile: profile),
    );
  }

  // Helper method to build tappable avatar
  Widget _buildTappableAvatar(Profile profile, double avatarRadius,
      double avatarFontSize, bool isLandscape, bool isTablet) {
    return GestureDetector(
      onTap: () => _showAvatarUpdateModal(profile),
      child: Stack(
        children: [
          Container(
            width: avatarRadius * 2,
            height: avatarRadius * 2,
            decoration: BoxDecoration(
              color: profile.avatarType == 'photo'
                  ? Colors.transparent
                  : _getAvatarColor(profile.avatar),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: isLandscape ? 6.0 : (isTablet ? 20.0 : 15.0),
                  offset: isLandscape
                      ? const Offset(0, 2.0)
                      : Offset(0, isTablet ? 8.0 : 6.0),
                ),
              ],
            ),
            child: profile.avatarType == 'photo'
                ? ClipOval(
                    child: Image.file(
                      File(profile.avatar),
                      width: avatarRadius * 2,
                      height: avatarRadius * 2,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to emoji if photo fails to load
                        return Container(
                          width: avatarRadius * 2,
                          height: avatarRadius * 2,
                          decoration: BoxDecoration(
                            color: _getAvatarColor('👦'),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            CupertinoIcons.person,
                            size: avatarFontSize * 0.7,
                            color: Colors.black54,
                          ),
                        );
                      },
                    ),
                  )
                : Container(
                    alignment: Alignment.center,
                    child: Text(
                      profile.avatar,
                      style: TextStyle(
                        fontSize: avatarFontSize,
                        height: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
          // Edit icon overlay
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: isTablet ? 32.0 : 28.0,
              height: isTablet ? 32.0 : 28.0,
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: isTablet ? 3.0 : 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4.0,
                    offset: const Offset(0, 2.0),
                  ),
                ],
              ),
              child: Icon(
                CupertinoIcons.pencil,
                color: Colors.white,
                size: isTablet ? 16.0 : 14.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    final themeService = context.watch<ThemeService>();
    final themeConfig = themeService.config;
    final isValentine = themeService.currentTheme == AppThemeType.valentine;
    
    Widget content = Stack(
      children: [
        // Background gradient
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: themeConfig.screenGradient,
              ),
            ),
          ),
        ),

        // Main content
        SafeArea(
          child: Consumer<ProfileProvider>(
            builder: (context, profileProvider, child) {
              Profile? selected;
              if (profileProvider.profiles.isNotEmpty &&
                  profileProvider.selectedProfileId != null) {
                selected = profileProvider.profiles.firstWhere(
                  (p) => p.id == profileProvider.selectedProfileId,
                  orElse: () => profileProvider.profiles.first,
                );
              }

              if (selected != null) {
                // Show welcome screen
                return _buildWelcomeScreen(selected);
              } else {
                // Show profile selection
                return _buildProfileSelection(profileProvider);
              }
            },
          ),
        ),
      ],
    );
    
    // Wrap with floating hearts and sparkles for Valentine theme
    if (isValentine) {
      return FloatingHeartsOverlay(
        heartCount: 12,
        child: FloatingSparklesOverlay(
          sparkleCount: 8,
          child: content,
        ),
      );
    }
    
    return content;
  }

  Widget _buildWelcomeScreen(Profile selected) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final themeService = context.watch<ThemeService>();
    final themeConfig = themeService.config;
    final isValentine = themeService.currentTheme == AppThemeType.valentine;

    // Better tablet detection: consider both dimensions and pixel density
    final shortestSide = math.min(screenWidth, screenHeight);
    final isTablet =
        shortestSide > 600 || (shortestSide > 500 && devicePixelRatio < 2.5);

    final isLandscape = screenWidth > screenHeight;
    final isSmallScreen = screenWidth < 400;

    // Enhanced responsive sizing for landscape - better phone landscape support
    final avatarRadius =
        isTablet ? 70.0 : (isLandscape ? 35.0 : (isSmallScreen ? 45.0 : 56.0));
    final avatarFontSize =
        isTablet ? 70.0 : (isLandscape ? 45.0 : (isSmallScreen ? 45.0 : 56.0));
    final welcomeFontSize =
        isTablet ? 48.0 : (isLandscape ? 28.0 : (isSmallScreen ? 28.0 : 36.0));
    final backButtonPadding = isTablet ? 12.0 : (isLandscape ? 6.0 : 10.0);
    final backButtonIconSize = isTablet ? 28.0 : (isLandscape ? 24.0 : 24.0);
    final topPadding = isTablet ? 20.0 : (isLandscape ? 4.0 : 12.0);
    final horizontalPadding = isTablet ? 48.0 : (isLandscape ? 12.0 : 24.0);
    final verticalSpacing = isTablet ? 32.0 : (isLandscape ? 8.0 : 24.0);
    final buttonSpacing = isTablet ? 48.0 : (isLandscape ? 16.0 : 40.0);

    return Stack(
      children: [
        // Main content
        Column(
          children: [
            // Top row with back button and premium button
            Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  Padding(
                    padding: EdgeInsets.only(left: isTablet ? 24.0 : 16.0),
                    child: GestureDetector(
                      onTap: () {
                        context.read<ProfileProvider>().selectProfile(null);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: themeConfig.cardStory,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0x33FF9F43),
                              blurRadius: isTablet ? 12.0 : 10.0,
                              offset: Offset(0, isTablet ? 6.0 : 4.0),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(backButtonPadding),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: backButtonIconSize,
                        ),
                      ),
                    ),
                  ),
                  // Theme + Premium buttons
                  Padding(
                    padding: EdgeInsets.only(right: isTablet ? 24.0 : 16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Theme button
                        Consumer<ThemeService>(
                          builder: (context, themeService, child) {
                            return GestureDetector(
                              onTap: () => _showThemePicker(context),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  themeService.config.emoji,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        // Premium button
                        Consumer<SubscriptionService>(
                          builder: (context, subscriptionService, child) {
                            final isSubscribed = subscriptionService.isSubscribed;

                            return GestureDetector(
                              onTap: () =>
                                  Navigator.pushNamed(context, '/subscription'),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSubscribed
                                      ? Colors.green
                                      : const Color(0xFF8E6CFF),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSubscribed
                                          ? Colors.green.withValues(alpha: 0.3)
                                          : const Color(0x668E6CFF),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSubscribed
                                          ? Icons.check_circle
                                          : Icons.workspace_premium,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isSubscribed ? 'Premium' : 'Subscribe',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: isLandscape ? 4.0 : (isTablet ? 32.0 : 16.0),
                ),
                child: isLandscape
                    ? Row(
                        children: [
                          // Left side: Avatar and welcome text
                          Expanded(
                            flex: 2,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Avatar
                                _buildTappableAvatar(selected, avatarRadius,
                                    avatarFontSize, isLandscape, isTablet),
                                SizedBox(height: verticalSpacing),
                                Text(
                                  isValentine
                                      ? (isLandscape ? '💕 Hi ${selected.name}!' : '💕\nHi ${selected.name}!')
                                      : (isLandscape ? 'Welcome, ${selected.name}' : 'Welcome,\n${selected.name}'),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.baloo2(
                                    fontSize: welcomeFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.15),
                                        blurRadius: 4.0,
                                        offset: const Offset(0, 2.0),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: isTablet ? 20.0 : 12.0),
                                _buildQuickResumeCard(
                                  selected,
                                  isTablet: isTablet,
                                  isLandscape: isLandscape,
                                  themeConfig: themeConfig,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: horizontalPadding * 0.5),
                          // Right side: Buttons
                          Expanded(
                            flex: 3,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _HomeButton(
                                  label: 'AI Friends',
                                  color: themeConfig.cardStory,
                                  onTap: () => Navigator.pushNamed(
                                      context, '/ai-friends'),
                                  isTablet: isTablet,
                                  isLandscape: isLandscape,
                                ),
                                const SizedBox(height: 6),
                                _HomeButton(
                                  label: '123',
                                  color: themeConfig.cardMath,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            MathGameSelectionScreen(
                                                profileName: selected.name)),
                                  ),
                                  isTablet: isTablet,
                                  isLandscape: isLandscape,
                                ),
                                const SizedBox(height: 6),
                                _HomeButton(
                                  label: 'Games',
                                  color: themeConfig.cardPuzzle,
                                  onTap: () =>
                                      Navigator.pushNamed(context, '/games'),
                                  isTablet: isTablet,
                                  isLandscape: isLandscape,
                                ),
                                SizedBox(height: isTablet ? 14.0 : 10.0),
                                _buildProgressAndLimitsRow(
                                  isTablet: isTablet,
                                  isLandscape: isLandscape,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Avatar
                          _buildTappableAvatar(selected, avatarRadius,
                              avatarFontSize, isLandscape, isTablet),
                          SizedBox(height: verticalSpacing),
                          Text(
                            isValentine
                                ? (isLandscape ? '💕 Hi ${selected.name}!' : '💕\nHi ${selected.name}!')
                                : (isLandscape ? 'Welcome, ${selected.name}' : 'Welcome,\n${selected.name}'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.baloo2(
                              fontSize: welcomeFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 4.0,
                                  offset: const Offset(0, 2.0),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isTablet ? 18.0 : 12.0),
                          _buildQuickResumeCard(
                            selected,
                            isTablet: isTablet,
                            isLandscape: isLandscape,
                            themeConfig: themeConfig,
                          ),
                          SizedBox(height: buttonSpacing * 0.65),
                          // Buttons with responsive layout
                          isTablet
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _HomeButton(
                                      label: 'AI Friends',
                                      color: themeConfig.cardStory,
                                      onTap: () => Navigator.pushNamed(
                                          context, '/ai-friends'),
                                      isTablet: isTablet,
                                    ),
                                    const SizedBox(width: 32),
                                    _HomeButton(
                                      label: '123',
                                      color: themeConfig.cardMath,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                MathGameSelectionScreen(
                                                    profileName:
                                                        selected.name)),
                                      ),
                                      isTablet: isTablet,
                                    ),
                                    const SizedBox(width: 32),
                                    _HomeButton(
                                      label: 'Games',
                                      color: themeConfig.cardPuzzle,
                                      onTap: () => Navigator.pushNamed(
                                          context, '/games'),
                                      isTablet: isTablet,
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _HomeButton(
                                          label: 'AI Friends',
                                          color: themeConfig.cardStory,
                                          onTap: () => Navigator.pushNamed(
                                              context, '/ai-friends'),
                                          isTablet: isTablet,
                                        ),
                                        const SizedBox(width: 20),
                                        _HomeButton(
                                          label: '123',
                                          color: themeConfig.cardMath,
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    MathGameSelectionScreen(
                                                        profileName:
                                                            selected.name)),
                                          ),
                                          isTablet: isTablet,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    _HomeButton(
                                      label: 'Games',
                                      color: themeConfig.cardPuzzle,
                                      onTap: () => Navigator.pushNamed(
                                          context, '/games'),
                                      isTablet: isTablet,
                                    ),
                                  ],
                                ),
                          SizedBox(height: isTablet ? 14.0 : 10.0),
                          _buildProgressAndLimitsRow(
                            isTablet: isTablet,
                            isLandscape: isLandscape,
                          ),
                        ],
                      ),
              ),
            ),
            // Bottom padding to avoid banner overlap - reduced for landscape
            SizedBox(height: isLandscape ? 8.0 : (isTablet ? 80.0 : 60.0)),
          ],
        ),

        // Trial status banner at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Consumer<SubscriptionService>(
            builder: (context, subscriptionService, child) {
              if (subscriptionService.isSubscribed) {
                return const SizedBox.shrink();
              }
              return Container(
                width: double.infinity,
                color: Colors.blue.withValues(alpha: 0.75),
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                child: const Text(
                  'Free plan active: learning games are unlocked. AI features have daily and weekly limits.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressButton({
    required bool isTablet,
    required bool isLandscape,
  }) {
    return FilledButton.icon(
      onPressed: _openProgressScreen,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF5AA9FF),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 18 : (isLandscape ? 14 : 16),
          vertical: isTablet ? 12 : 10,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      icon: const Icon(Icons.auto_awesome_rounded),
      label: Text(
        'My Progress',
        style: GoogleFonts.baloo2(
          fontWeight: FontWeight.w800,
          fontSize: isTablet ? 17 : 15,
        ),
      ),
    );
  }

  Widget _buildAiLimitsButton({
    required bool isTablet,
    required bool isLandscape,
  }) {
    return OutlinedButton.icon(
      onPressed: _openAiLimitsScreen,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF355C7D),
        side: const BorderSide(color: Color(0xFF8E6CFF), width: 1.8),
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 18 : (isLandscape ? 14 : 16),
          vertical: isTablet ? 12 : 10,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      icon: const Icon(Icons.settings_suggest_rounded),
      label: Text(
        'AI Limits',
        style: GoogleFonts.baloo2(
          fontWeight: FontWeight.w800,
          fontSize: isTablet ? 17 : 15,
        ),
      ),
    );
  }

  Widget _buildProgressAndLimitsRow({
    required bool isTablet,
    required bool isLandscape,
  }) {
    final spacing = isTablet ? 14.0 : (isLandscape ? 10.0 : 12.0);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 8.0 : 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: _buildProgressButton(
              isTablet: isTablet,
              isLandscape: isLandscape,
            ),
          ),
          SizedBox(width: spacing),
          Flexible(
            child: _buildAiLimitsButton(
              isTablet: isTablet,
              isLandscape: isLandscape,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSelection(ProfileProvider profileProvider) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    // Better tablet detection: consider both dimensions and pixel density
    final shortestSide = math.min(screenWidth, screenHeight);
    final isTablet =
        shortestSide > 600 || (shortestSide > 500 && devicePixelRatio < 2.5);

    final isLandscape = screenWidth > screenHeight;
    final isSmallScreen = screenWidth < 400;

    // Enhanced responsive sizing for landscape
    final titleFontSize =
        isTablet ? 48.0 : (isLandscape ? 28.0 : (isSmallScreen ? 24.0 : 36.0));
    final descFontSize =
        isTablet ? 18.0 : (isLandscape ? 14.0 : (isSmallScreen ? 14.0 : 16.0));
    final maxContentWidth = isTablet ? 800.0 : (isLandscape ? 700.0 : 500.0);
    final topPadding = isLandscape ? 10.0 : 20.0;

    return Stack(
      children: [
        // Main content
        SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxContentWidth,
                minHeight: MediaQuery.of(context).size.height,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24.0 : 16.0, vertical: 26.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(
                        height:
                            MediaQuery.of(context).padding.top + topPadding),

                    // Title
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'M&M Learning Lab',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFF6B6B),
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.white,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Subtitle
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Choose your profile to start learning!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: descFontSize,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF24924B),
                          shadows: [
                            Shadow(
                              color: Colors.white,
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: isLandscape ? 24 : (isTablet ? 48 : 32)),

                    // Profile cards with responsive grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth =
                            isTablet ? 180.0 : (isLandscape ? 140.0 : 160.0);
                        final spacing =
                            isTablet ? 20.0 : (isLandscape ? 12.0 : 14.0);

                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          alignment: WrapAlignment.center,
                          children: [
                            ...profileProvider.profiles
                                .map((profile) => SizedBox(
                                      width: cardWidth,
                                      child: ProfileCard(
                                        profile: profile,
                                        isSelected: profile.id ==
                                            profileProvider.selectedProfileId,
                                        onTap: () => profileProvider
                                            .selectProfile(profile.id!),
                                      ),
                                    )),
                            SizedBox(
                              width: cardWidth,
                              child: AddProfileCard(
                                onTap: () => showCupertinoModalPopup(
                                  context: context,
                                  builder: (context) => const AddProfileModal(),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: isLandscape ? 40 : 80),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Subscription button - positioned absolutely with proper alignment
        Positioned(
          top: topPadding,
          right: isTablet ? 24.0 : 16.0,
          child: Consumer<SubscriptionService>(
            builder: (context, subscriptionService, child) {
              final isSubscribed = subscriptionService.isSubscribed;

              return GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/subscription'),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        isSubscribed ? Colors.green : const Color(0xFF8E6CFF),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: isSubscribed
                            ? Colors.green.withValues(alpha: 0.3)
                            : const Color(0x668E6CFF),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSubscribed
                            ? Icons.check_circle
                            : Icons.workspace_premium,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isSubscribed ? 'Premium' : 'Subscribe',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Trial status banner at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Consumer<SubscriptionService>(
            builder: (context, subscriptionService, child) {
              if (subscriptionService.isSubscribed) {
                return const SizedBox.shrink();
              }
              return Container(
                width: double.infinity,
                color: Colors.blue.withValues(alpha: 0.75),
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                child: const Text(
                  'Free plan active: learning games are unlocked. AI features have daily and weekly limits.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Home button widget
class _HomeButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isTablet;
  final bool isLandscape;

  const _HomeButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.isTablet = false,
    this.isLandscape = false,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isTablet ? 56.0 : (isLandscape ? 32.0 : 40.0);
    final verticalPadding = isTablet ? 20.0 : (isLandscape ? 12.0 : 16.0);
    final borderRadius = isTablet ? 28.0 : (isLandscape ? 16.0 : 20.0);
    final fontSize = isTablet ? 24.0 : (isLandscape ? 24.0 : 24.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding, vertical: verticalPadding),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: isTablet ? 16.0 : 12.0,
              offset: Offset(0, isTablet ? 6.0 : 4.0),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.baloo2(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
