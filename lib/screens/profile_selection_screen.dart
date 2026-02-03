import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:io';
import '../providers/profile_provider.dart';
import '../widgets/profile_card.dart';
import '../widgets/add_profile_modal.dart';
import '../widgets/quick_avatar_update_modal.dart';
import '../services/subscription_service.dart';
import '../models/profile.dart';
import 'math_challenge_selection_screen.dart';
import 'math_game_selection_screen.dart';
import 'puzzle_game_selection_screen.dart';
import 'openai_realtime_voice_conversation_screen.dart';

class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> {
  // Track the first time the app is used for free trial
  static const String _firstLaunchTimeKey = 'first_launch_time';
  static const int _freeTrialDurationDays = 14;

  @override
  void initState() {
    super.initState();
    // Load profiles when the screen is first built
    Future.microtask(() => context.read<ProfileProvider>().loadProfiles());

    // Check subscription status and navigate to subscription if necessary
    Future.microtask(() async {
      final subscriptionService = context.read<SubscriptionService>();
      final isSubscribed = await subscriptionService.checkSubscriptionStatus();

      if (!isSubscribed) {
        // Delay slightly to ensure screen is fully built
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          Navigator.pushNamed(context, '/subscription');
        }
      }
    });
  }

  // Calculate days left in trial
  Future<int> _getDaysLeftInTrial() async {
    final prefs = await SharedPreferences.getInstance();

    // Get the first launch time, or set it if it doesn't exist
    int? firstLaunchTime = prefs.getInt(_firstLaunchTimeKey);
    if (firstLaunchTime == null) {
      // If first time launching, set current time and return full trial period
      firstLaunchTime = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_firstLaunchTimeKey, firstLaunchTime);
      return _freeTrialDurationDays;
    }

    // Calculate how many days since first launch
    final firstLaunchDate = DateTime.fromMillisecondsSinceEpoch(firstLaunchTime);
    final today = DateTime.now();
    final difference = today.difference(firstLaunchDate).inDays;

    // Print for debugging
    print('Days since first launch: $difference');

    // Calculate days remaining
    final daysRemaining = _freeTrialDurationDays - difference;

    // Return days left (minimum 0)
    return daysRemaining > 0 ? daysRemaining : 0;
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

  // Helper method to show avatar update modal
  void _showAvatarUpdateModal(Profile profile) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => QuickAvatarUpdateModal(profile: profile),
    );
  }

  // Helper method to build tappable avatar
  Widget _buildTappableAvatar(Profile profile, double avatarRadius, double avatarFontSize, bool isLandscape, bool isTablet) {
    return GestureDetector(
      onTap: () => _showAvatarUpdateModal(profile),
      child: Stack(
        children: [
          Container(
            width: avatarRadius * 2,
            height: avatarRadius * 2,
            decoration: BoxDecoration(
              color: profile.avatarType == 'photo' ? Colors.transparent : _getAvatarColor(profile.avatar),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: isLandscape ? 6.0 : (isTablet ? 20.0 : 15.0),
                  offset: isLandscape ? const Offset(0, 2.0) : Offset(0, isTablet ? 8.0 : 6.0),
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
                    color: Colors.black.withOpacity(0.2),
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
      body: Consumer<SubscriptionService>(
        builder: (context, subscriptionService, child) {
          // If not subscribed, show a blocking overlay
          if (!subscriptionService.isSubscribed) {
            // Show nothing, as navigation will occur immediately
            return const SizedBox.shrink();
          }

          // Normal app content
          return _buildMainContent();
        },
      ),
    );
  }

  Widget _buildMainContent() {
    return Stack(
      children: [
        // Background image
        Positioned.fill(
          child: Image.asset(
            'assets/images/homepage-background.png',
            fit: BoxFit.cover,
          ),
        ),

        // Main content
        SafeArea(
          child: Consumer<ProfileProvider>(
            builder: (context, profileProvider, child) {
              Profile? selected;
              if (profileProvider.profiles.isNotEmpty && profileProvider.selectedProfileId != null) {
                selected = profileProvider.profiles.firstWhere(
                  (p) => p.id == profileProvider.selectedProfileId,
                  orElse: () => profileProvider.profiles.first,
                );
              } else {
                selected = null;
              }
              final hasSelected = selected != null;
              if (hasSelected) {
                // Show welcome screen
                return _buildWelcomeScreen(selected!);
              } else {
                // Show profile selection
                return _buildProfileSelection(profileProvider);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeScreen(Profile selected) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    // Better tablet detection: consider both dimensions and pixel density
    final shortestSide = math.min(screenWidth, screenHeight);
    final longestSide = math.max(screenWidth, screenHeight);
    final isTablet = shortestSide > 600 || (shortestSide > 500 && devicePixelRatio < 2.5);

    final isLandscape = screenWidth > screenHeight;
    final isSmallScreen = screenWidth < 400;

    // Enhanced responsive sizing for landscape - better phone landscape support
    final avatarRadius = isTablet ? 70.0 : (isLandscape ? 35.0 : (isSmallScreen ? 45.0 : 56.0));
    final avatarFontSize = isTablet ? 70.0 : (isLandscape ? 45.0 : (isSmallScreen ? 45.0 : 56.0));
    final welcomeFontSize = isTablet ? 48.0 : (isLandscape ? 28.0 : (isSmallScreen ? 28.0 : 36.0));
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
                          color: const Color(0xFFFF9F43),
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
                  // Premium button
                  Padding(
                    padding: EdgeInsets.only(right: isTablet ? 24.0 : 16.0),
                    child: Consumer<SubscriptionService>(
                      builder: (context, subscriptionService, child) {
                        final isSubscribed = subscriptionService.isSubscribed;

                        return GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/subscription'),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSubscribed ? Colors.green : const Color(0xFF8E6CFF),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: isSubscribed ? Colors.green.withOpacity(0.3) : const Color(0x668E6CFF),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSubscribed ? Icons.check_circle : Icons.workspace_premium,
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
                                _buildTappableAvatar(selected, avatarRadius, avatarFontSize, isLandscape, isTablet),
                                SizedBox(height: verticalSpacing),
                                Text(
                                  isLandscape ? 'Welcome, ${selected.name}' : 'Welcome,\n${selected.name}',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.baloo2(
                                    fontSize: welcomeFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 4.0,
                                        offset: const Offset(0, 2.0),
                                      ),
                                    ],
                                  ),
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
                                  label: 'ABC',
                                  color: const Color(0xFFFF9F43),
                                  onTap: () => Navigator.pushNamed(context, '/games'),
                                  isTablet: isTablet,
                                  isLandscape: isLandscape,
                                ),
                                const SizedBox(height: 6),
                                _HomeButton(
                                  label: '123',
                                  color: const Color(0xFF43C465),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => MathGameSelectionScreen(profileName: selected.name)),
                                  ),
                                  isTablet: isTablet,
                                  isLandscape: isLandscape,
                                ),
                                const SizedBox(height: 6),
                                _HomeButton(
                                  label: 'Games',
                                  color: const Color(0xFF8E6CFF),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const PuzzleGameSelectionScreen()),
                                  ),
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
                          _buildTappableAvatar(selected, avatarRadius, avatarFontSize, isLandscape, isTablet),
                          SizedBox(height: verticalSpacing),
                          Text(
                            isLandscape ? 'Welcome, ${selected.name}' : 'Welcome,\n${selected.name}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.baloo2(
                              fontSize: welcomeFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 4.0,
                                  offset: const Offset(0, 2.0),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: buttonSpacing),
                          // Buttons with responsive layout
                          isTablet
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _HomeButton(
                                      label: 'ABC',
                                      color: const Color(0xFFFF9F43),
                                      onTap: () => Navigator.pushNamed(context, '/games'),
                                      isTablet: isTablet,
                                    ),
                                    const SizedBox(width: 32),
                                    _HomeButton(
                                      label: '123',
                                      color: const Color(0xFF43C465),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => MathGameSelectionScreen(profileName: selected.name)),
                                      ),
                                      isTablet: isTablet,
                                    ),
                                    const SizedBox(width: 32),
                                    _HomeButton(
                                      label: 'Games',
                                      color: const Color(0xFF8E6CFF),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const PuzzleGameSelectionScreen()),
                                      ),
                                      isTablet: isTablet,
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _HomeButton(
                                          label: 'ABC',
                                          color: const Color(0xFFFF9F43),
                                          onTap: () => Navigator.pushNamed(context, '/games'),
                                          isTablet: isTablet,
                                        ),
                                        const SizedBox(width: 20),
                                        _HomeButton(
                                          label: '123',
                                          color: const Color(0xFF43C465),
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => MathGameSelectionScreen(profileName: selected.name)),
                                          ),
                                          isTablet: isTablet,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    _HomeButton(
                                      label: 'Games',
                                      color: const Color(0xFF8E6CFF),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const PuzzleGameSelectionScreen()),
                                      ),
                                      isTablet: isTablet,
                                    ),
                                  ],
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

              return FutureBuilder<int>(
                future: _getDaysLeftInTrial(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final daysLeft = snapshot.data!;

                  if (daysLeft <= 0) {
                    return Container(
                      width: double.infinity,
                      color: Colors.red.withOpacity(0.8),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                      child: const Text(
                        'Your free trial has ended. Subscribe to continue learning!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    );
                  } else if (daysLeft <= 3) {
                    return Container(
                      width: double.infinity,
                      color: Colors.orange.withOpacity(0.8),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                      child: Text(
                        'Only $daysLeft ${daysLeft == 1 ? 'day' : 'days'} left in your free trial!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    );
                  } else {
                    return Container(
                      width: double.infinity,
                      color: Colors.blue.withOpacity(0.7),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                      child: Text(
                        daysLeft == 14 ? 'Free trial started! 14 days of unlimited learning.' : 'Free trial: $daysLeft days remaining',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSelection(ProfileProvider profileProvider) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    // Better tablet detection: consider both dimensions and pixel density
    final shortestSide = math.min(screenWidth, screenHeight);
    final longestSide = math.max(screenWidth, screenHeight);
    final isTablet = shortestSide > 600 || (shortestSide > 500 && devicePixelRatio < 2.5);

    final isLandscape = screenWidth > screenHeight;
    final isSmallScreen = screenWidth < 400;

    // Enhanced responsive sizing for landscape
    final titleFontSize = isTablet ? 48.0 : (isLandscape ? 28.0 : (isSmallScreen ? 24.0 : 36.0));
    final descFontSize = isTablet ? 18.0 : (isLandscape ? 14.0 : (isSmallScreen ? 14.0 : 16.0));
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
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 24.0 : 16.0, vertical: 26.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(height: MediaQuery.of(context).padding.top + topPadding),

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
                              color: Colors.black.withOpacity(0.10),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
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
                        final cardWidth = isTablet ? 180.0 : (isLandscape ? 140.0 : 160.0);
                        final spacing = isTablet ? 20.0 : (isLandscape ? 12.0 : 14.0);

                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          alignment: WrapAlignment.center,
                          children: [
                            ...profileProvider.profiles.map((profile) => SizedBox(
                                  width: cardWidth,
                                  child: ProfileCard(
                                    profile: profile,
                                    isSelected: profile.id == profileProvider.selectedProfileId,
                                    onTap: () => profileProvider.selectProfile(profile.id!),
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
                    color: isSubscribed ? Colors.green : const Color(0xFF8E6CFF),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: isSubscribed ? Colors.green.withOpacity(0.3) : const Color(0x668E6CFF),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSubscribed ? Icons.check_circle : Icons.workspace_premium,
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

              return FutureBuilder<int>(
                future: _getDaysLeftInTrial(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final daysLeft = snapshot.data!;

                  if (daysLeft <= 0) {
                    return Container(
                      width: double.infinity,
                      color: Colors.red.withOpacity(0.8),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                      child: const Text(
                        'Your free trial has ended. Subscribe to continue learning!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    );
                  } else if (daysLeft <= 3) {
                    return Container(
                      width: double.infinity,
                      color: Colors.orange.withOpacity(0.8),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                      child: Text(
                        'Only $daysLeft ${daysLeft == 1 ? 'day' : 'days'} left in your free trial!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    );
                  } else {
                    return Container(
                      width: double.infinity,
                      color: Colors.blue.withOpacity(0.7),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                      child: Text(
                        daysLeft == 14 ? 'Free trial started! 14 days of unlimited learning.' : 'Free trial: $daysLeft days remaining',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                },
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
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
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
