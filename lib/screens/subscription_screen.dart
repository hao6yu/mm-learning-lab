import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../services/ai_usage_limit_service.dart';
import '../services/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  final VoidCallback? onSubscribed;

  const SubscriptionScreen({super.key, this.onSubscribed});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  static const Color _backgroundColor = Color(0xFFEAF6FF);
  static const Color _primary = Color(0xFF6F5BFF);
  static const Color _secondary = Color(0xFF2E9B5E);
  static const Color _ink = Color(0xFF2C3E57);

  bool _isLoading = false;
  bool _didSchedulePostSubscribeDismiss = false;

  bool get _canNavigateBack => Navigator.of(context).canPop();

  void _handleBackPressed() {
    if (!_canNavigateBack) return;
    Navigator.of(context).pop();
  }

  Future<void> _openExternalUrl(Uri url) async {
    final canLaunch = await launcher.canLaunchUrl(url);
    if (!mounted) return;

    if (!canLaunch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open link right now.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await launcher.launchUrl(url,
        mode: launcher.LaunchMode.externalApplication);
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Privacy Policy'),
          content: const SingleChildScrollView(
            child: Text(
              'M&M Learning Lab Privacy Policy\n\n'
              'We collect information to provide personalized learning experiences:\n\n'
              '• Personal Information: Name, email, profile information\n'
              '• Learning Data: Progress, completion rates, performance metrics\n'
              '• Device Information: Device type, operating system, identifiers\n'
              '• Usage Information: Features accessed, time spent, interaction patterns\n\n'
              'We use this information to:\n'
              '• Provide and improve educational services\n'
              '• Personalize learning experiences\n'
              '• Track learning progress\n'
              '• Ensure service security\n\n'
              'We do not sell your personal information. We implement appropriate security measures to protect your data.\n\n'
              'Full privacy policy: https://haoyu.io/mm-privacy.html\n'
              'Contact: support@mmlearninglab.com',
              style: TextStyle(fontSize: 14),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _schedulePostSubscribeDismiss() {
    if (_didSchedulePostSubscribeDismiss) {
      return;
    }
    _didSchedulePostSubscribeDismiss = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onSubscribed?.call();
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (!mounted) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        }
      });
    });
  }

  Future<void> _startSubscription(
      SubscriptionService subscriptionService) async {
    if (_isLoading || subscriptionService.products.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await subscriptionService.subscribe();
    } catch (e) {
      debugPrint('Error during subscription: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchase failed. Please try again. $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restorePurchases() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not restore purchases. $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _manageSubscription() async {
    await _openExternalUrl(
      Uri.parse('https://apps.apple.com/account/subscriptions'),
    );
  }

  bool _looksLikeFamilySharingIssue(String? message) {
    if (message == null || message.isEmpty) {
      return false;
    }
    final normalized = message.toLowerCase();
    return normalized.contains('family') ||
        normalized.contains('shared') ||
        normalized.contains('member') ||
        normalized.contains('already purchased');
  }

  Future<void> _setDebugBypass(
    SubscriptionService subscriptionService,
    bool enabled,
  ) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (enabled) {
        await subscriptionService.debugSkipSubscription();
        widget.onSubscribed?.call();
      } else {
        await subscriptionService.debugClearBypass();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Debug bypass enabled.'
                : 'Debug bypass disabled. Normal checks restored.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Error toggling debug bypass: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Debug action failed. $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _canNavigateBack ? _handleBackPressed : null,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'M&M Premium',
          style: TextStyle(
            color: _ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Consumer<SubscriptionService>(
        builder: (context, subscriptionService, child) {
          if (subscriptionService.isSubscribed) {
            final justSubscribed =
                ModalRoute.of(context)?.settings.arguments == 'justSubscribed';
            if (justSubscribed) {
              _schedulePostSubscribeDismiss();
              return _buildJustSubscribedState();
            }
            return _buildSubscribedState(subscriptionService);
          }

          return _buildPaywallState(subscriptionService);
        },
      ),
    );
  }

  Widget _buildJustSubscribedState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 86),
            SizedBox(height: 16),
            Text(
              'You are subscribed!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Premium limits are now active for chat, stories, and AI calls.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscribedState(SubscriptionService subscriptionService) {
    final product = subscriptionService.products.isNotEmpty
        ? subscriptionService.products.first
        : null;
    final limits = AIUsageLimitService.premiumTierUsageLimits;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6F5BFF), Color(0xFF53A8FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.workspace_premium,
                            color: Colors.white, size: 26),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Premium is Active',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Thanks for supporting a safe, AI-powered learning experience for kids.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current premium limits per profile',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _TierLimitLine(
                      label: 'AI Chat',
                      value:
                          '${limits.chatDaily}/day, ${limits.chatWeekly}/week',
                    ),
                    _TierLimitLine(
                      label: 'AI Stories',
                      value:
                          '${limits.storiesDaily}/day, ${limits.storiesWeekly}/week',
                    ),
                    _TierLimitLine(
                      label: 'AI Call',
                      value:
                          '${limits.callPerCallMinutes} min/call, ${limits.callDailyMinutes} min/day, ${limits.callWeeklyMinutes} min/week',
                    ),
                    if (product != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Plan: ${product.price}/month',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _secondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _manageSubscription,
                      icon: const Icon(Icons.settings),
                      label: const Text('Manage Subscription'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/ai-limits'),
                      icon: const Icon(Icons.tune),
                      label: const Text('View AI Limits & Controls'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _ink,
                        side: const BorderSide(color: Color(0xFFCAD7E5)),
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 10),
                      _buildDebugTools(subscriptionService),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaywallState(SubscriptionService subscriptionService) {
    final freeLimits = AIUsageLimitService.freeTierUsageLimits;
    final premiumLimits = AIUsageLimitService.premiumTierUsageLimits;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeroCard(subscriptionService),
                          const SizedBox(height: 12),
                          _buildKidsFeaturesCard(),
                          const SizedBox(height: 12),
                          _buildPlanComparisonCard(
                            freeLimits: freeLimits,
                            premiumLimits: premiumLimits,
                            isWide: isWide,
                          ),
                          const SizedBox(height: 12),
                          _buildParentsInfoCard(),
                          if (subscriptionService.errorMessage != null) ...[
                            const SizedBox(height: 12),
                            _buildErrorCard(subscriptionService),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _buildBottomActions(subscriptionService),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroCard(SubscriptionService subscriptionService) {
    final priceLabel = subscriptionService.products.isNotEmpty
        ? '${subscriptionService.products.first.price}/month'
        : 'Monthly plan';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6F5BFF), Color(0xFF4EA8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Learning, with Healthy Limits',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Free tier stays forever. Premium gives higher chat, story, and AI call limits plus stronger parent controls.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.call_rounded,
                label: 'New: AI Calls',
                color: Colors.white,
              ),
              _InfoChip(
                icon: Icons.chat_rounded,
                label: 'Friendly AI Chat',
                color: Colors.white,
              ),
              _InfoChip(
                icon: Icons.auto_stories_rounded,
                label: 'Story Maker',
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$priceLabel • First month free',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKidsFeaturesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What Kids Can Do',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          SizedBox(height: 10),
          _FeatureLine(icon: '🤖', text: 'Chat with a friendly AI buddy'),
          _FeatureLine(icon: '📚', text: 'Create and read AI stories'),
          _FeatureLine(icon: '📞', text: 'Practice speaking with AI calls'),
          _FeatureLine(icon: '🎮', text: 'Play games and puzzles'),
          _FeatureLine(icon: '🎯', text: 'Solve fun math challenges'),
        ],
      ),
    );
  }

  Widget _buildPlanComparisonCard({
    required AiTierUsageLimits freeLimits,
    required AiTierUsageLimits premiumLimits,
    required bool isWide,
  }) {
    final cardWidth = isWide ? 460.0 : double.infinity;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plan Limits (Per Child Profile)',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Both plans include the same core app experience. Premium mainly increases AI usage limits.',
            style: TextStyle(
              color: Colors.black87,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: cardWidth,
                child: _TierCard(
                  title: 'Free',
                  subtitle: 'Permanent free tier',
                  accent: const Color(0xFF4ECDC4),
                  limits: freeLimits,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _TierCard(
                  title: 'Premium',
                  subtitle: 'Higher daily & weekly limits',
                  accent: _primary,
                  limits: premiumLimits,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParentsInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF9F2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'For Parents',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          SizedBox(height: 10),
          _FeatureLine(
            icon: '🛡️',
            text: 'Safe, ad-free, privacy-focused environment',
          ),
          _FeatureLine(
            icon: '⏱️',
            text: 'Built-in call session/day/week caps to prevent overuse',
          ),
          _FeatureLine(
            icon: '🌙',
            text: 'Bedtime lock and custom AI call duration controls',
          ),
          _FeatureLine(
            icon: '📊',
            text: 'AI limits can be monitored from the AI Limits screen',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(SubscriptionService subscriptionService) {
    final hasProduct = subscriptionService.products.isNotEmpty;
    final price = hasProduct ? subscriptionService.products.first.price : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: const BoxDecoration(
        color: _backgroundColor,
        border: Border(
          top: BorderSide(color: Color(0x22A9B9CD)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading || !hasProduct
                  ? null
                  : () => _startSubscription(subscriptionService),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(58),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasProduct ? '$price/month' : 'Loading plan...',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        const Text(
                          'First month free • Cancel anytime',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _isLoading ? null : _restorePurchases,
            child: const Text(
              'Restore Purchases',
              style: TextStyle(
                color: _primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 4),
            _buildDebugTools(subscriptionService),
          ],
          const SizedBox(height: 6),
          _buildLegalLinks(),
        ],
      ),
    );
  }

  Widget _buildDebugTools(SubscriptionService subscriptionService) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }
    final active = subscriptionService.isDebugBypassActive;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.bug_report_rounded, color: Colors.orange),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'DEBUG: Simulate Premium',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              Switch(
                value: active,
                onChanged: _isLoading
                    ? null
                    : (value) => _setDebugBypass(subscriptionService, value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          active
              ? 'Debug mode ON: app behaves as Premium for testing.'
              : 'Debug mode OFF: normal subscription validation.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? Colors.blue : Colors.black54,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        if (_isLoading) ...[
          const SizedBox(height: 6),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ],
    );
  }

  Widget _buildLegalLinks() {
    return Column(
      children: [
        const Text(
          'By subscribing, you agree to our:',
          style: TextStyle(fontSize: 12, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                _openExternalUrl(
                  Uri.parse(
                    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
                  ),
                );
              },
              child: const Text(
                'Terms of Use',
                style: TextStyle(
                  fontSize: 12,
                  color: _primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const Text(' • ',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            GestureDetector(
              onTap: () async {
                final privacyUrl =
                    Uri.parse('https://haoyu.io/mm-privacy.html');
                final canLaunch = await launcher.canLaunchUrl(privacyUrl);
                if (!mounted) return;
                if (canLaunch) {
                  await launcher.launchUrl(
                    privacyUrl,
                    mode: launcher.LaunchMode.externalApplication,
                  );
                } else {
                  _showPrivacyPolicy(context);
                }
              },
              child: const Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 12,
                  color: _primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Family Sharing users: tap "Restore Purchases" to unlock premium access.',
          style: TextStyle(fontSize: 10, color: Colors.black45),
          textAlign: TextAlign.center,
        ),
        const Text(
          'Subscription renews automatically unless cancelled at least 24 hours before the current period ends.',
          style: TextStyle(fontSize: 10, color: Colors.black45),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildErrorCard(SubscriptionService subscriptionService) {
    final message = subscriptionService.errorMessage;
    if (_looksLikeFamilySharingIssue(message)) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.family_restroom,
                color: Colors.orange.shade700, size: 30),
            const SizedBox(height: 6),
            Text(
              'Family Sharing detected. Try Restore Purchases, then refresh status.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.orange.shade800,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => subscriptionService.checkSubscriptionStatus(),
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Refresh Status'),
            ),
          ],
        ),
      );
    }

    return Text(
      message ?? '',
      style: const TextStyle(color: Colors.red),
      textAlign: TextAlign.center,
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.limits,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final AiTierUsageLimits limits;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          _TierLimitLine(
            label: 'AI Chat',
            value: '${limits.chatDaily}/day • ${limits.chatWeekly}/week',
          ),
          _TierLimitLine(
            label: 'AI Stories',
            value: '${limits.storiesDaily}/day • ${limits.storiesWeekly}/week',
          ),
          _TierLimitLine(
            label: 'Call Max',
            value: '${limits.callPerCallMinutes} min per call',
          ),
          _TierLimitLine(
            label: 'Call Total',
            value:
                '${limits.callDailyMinutes} min/day • ${limits.callWeeklyMinutes} min/week',
          ),
        ],
      ),
    );
  }
}

class _TierLimitLine extends StatelessWidget {
  const _TierLimitLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2C3E57),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
