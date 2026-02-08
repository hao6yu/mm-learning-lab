import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'package:auto_size_text/auto_size_text.dart';

class SubscriptionScreen extends StatefulWidget {
  final VoidCallback? onSubscribed;

  const SubscriptionScreen({super.key, this.onSubscribed});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Privacy Policy'),
          content: SingleChildScrollView(
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
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FF),
      body: Consumer<SubscriptionService>(
        builder: (context, subscriptionService, child) {
          if (subscriptionService.isSubscribed) {
            // If this screen was reached after a new purchase, show confirmation and auto-pop
            if (ModalRoute.of(context)?.settings.arguments ==
                'justSubscribed') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (widget.onSubscribed != null) {
                  widget.onSubscribed!();
                }
                // Capture navigator reference before async operation
                final navigator = Navigator.of(context);
                Future.delayed(const Duration(milliseconds: 1500), () {
                  if (mounted && navigator.canPop()) {
                    navigator.pop();
                  }
                });
              });
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 80),
                    SizedBox(height: 16),
                    Text(
                      'You are subscribed!',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('Enjoy all premium features.'),
                  ],
                ),
              );
            }
            // Otherwise, show subscription status page
            final product = subscriptionService.products.isNotEmpty
                ? subscriptionService.products.first
                : null;
            // Try to get trial info from purchase details if available
            // (You may need to adapt this if you store trial/renewal info elsewhere)
            String? trialInfo;
            String? renewalInfo;
            // TODO: If you have access to PurchaseDetails, extract trial/renewal info here
            // For now, show generic message
            trialInfo = null; // e.g., '7 days left in your free trial'
            renewalInfo = null; // e.g., 'Renews on 2024-07-01'
            return SafeArea(
              child: Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.blue.shade100.withValues(alpha: 0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(Icons.close,
                                    color: Color(0xFF8E6CFF), size: 32),
                                onPressed: () => Navigator.of(context).pop(),
                                tooltip: 'Close',
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(Icons.workspace_premium,
                                      color: Color(0xFF8E6CFF), size: 60),
                                  const SizedBox(height: 16),
                                  Text(
                                    'You are a Premium Member!',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF24924B),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  if (trialInfo != null)
                                    Text(
                                      trialInfo,
                                      style: TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFF8E6CFF),
                                          fontWeight: FontWeight.w600),
                                      textAlign: TextAlign.center,
                                    ),
                                  if (renewalInfo != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        renewalInfo,
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.black54),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  if (product != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Plan: ${product.price} per month',
                                        style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.black87),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  const SizedBox(height: 18),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      final url = Uri.parse(
                                          'https://apps.apple.com/account/subscriptions');
                                      if (await launcher.canLaunchUrl(url)) {
                                        await launcher.launchUrl(url,
                                            mode: launcher.LaunchMode
                                                .externalApplication);
                                      } else {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Could not open subscription management page.')),
                                          );
                                        }
                                      }
                                    },
                                    label: const Text('Manage Subscription'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF8E6CFF),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 14),
                                      textStyle: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Thank you for supporting M&M Learning Lab and helping us bring amazing AI-powered learning to kids everywhere!',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF24924B),
                                        fontStyle: FontStyle.italic),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 18),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.close,
                                        color: Colors.white),
                                    label: const Text('Close',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF8E6CFF),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 18, vertical: 10),
                                      textStyle: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = MediaQuery.of(context).size.width;
                final screenHeight = MediaQuery.of(context).size.height;
                final isLandscape = screenWidth > screenHeight;
                final isPhoneLandscape = isLandscape && screenHeight < 500;

                // Responsive spacing and sizing
                final horizontalPadding = isPhoneLandscape ? 12.0 : 20.0;
                final verticalPadding = isPhoneLandscape ? 4.0 : 16.0;
                final containerPadding = isPhoneLandscape ? 12.0 : 24.0;
                final containerVerticalPadding = isPhoneLandscape ? 8.0 : 28.0;
                final borderRadius = isPhoneLandscape ? 16.0 : 36.0;

                return Column(
                  children: [
                    // Main content scrollable
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                              vertical: verticalPadding),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(borderRadius),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.shade100
                                      .withValues(alpha: 0.3),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: containerPadding,
                                  vertical: containerVerticalPadding),
                              child: isPhoneLandscape
                                  ? _buildPhoneLandscapeLayout(
                                      subscriptionService)
                                  : _buildPortraitLayout(
                                      subscriptionService, isPhoneLandscape),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Fixed bottom area
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          isPhoneLandscape ? 16 : 24,
                          isPhoneLandscape ? 4 : 8,
                          isPhoneLandscape ? 16 : 24,
                          isPhoneLandscape ? 8 : 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: subscriptionService.products.isEmpty ||
                                      _isLoading
                                  ? null
                                  : () async {
                                      setState(() {
                                        _isLoading = true;
                                      });
                                      try {
                                        await subscriptionService.subscribe();
                                      } catch (e) {
                                        debugPrint(
                                            "Error during subscription: $e");
                                      } finally {
                                        if (mounted) {
                                          setState(() {
                                            _isLoading = false;
                                          });
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF8E6CFF),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                    vertical: isPhoneLandscape ? 6 : 14),
                                textStyle: TextStyle(
                                    fontSize: isPhoneLandscape ? 16 : 20,
                                    fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 4,
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: isPhoneLandscape ? 20 : 24,
                                      height: isPhoneLandscape ? 20 : 24,
                                      child: CircularProgressIndicator(
                                          color: Colors.white),
                                    )
                                  : subscriptionService.products.isNotEmpty
                                      ? isPhoneLandscape
                                          ? Text(
                                              '${subscriptionService.products.first.price}/month - First month free',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold),
                                            )
                                          : Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '${subscriptionService.products.first.price}/month',
                                                  style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                Text(
                                                  'First month free',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.normal),
                                                ),
                                              ],
                                            )
                                      : Text('Subscribe'),
                            ),
                          ),
                          //SizedBox(height: isPhoneLandscape ? 2 : 6),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    setState(() {
                                      _isLoading = true;
                                    });
                                    try {
                                      await InAppPurchase.instance
                                          .restorePurchases();
                                    } catch (e) {
                                      debugPrint(
                                          "Error restoring purchases: $e");
                                    } finally {
                                      if (mounted) {
                                        setState(() {
                                          _isLoading = false;
                                        });
                                      }
                                    }
                                  },
                            child: const Text(
                              'Restore Purchases',
                              style: TextStyle(
                                  color: Color(0xFF8E6CFF),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          // Debug button - only show in debug mode
                          if (kDebugMode) ...[
                            //if (1 == 2) ...[
                            //SizedBox(height: isPhoneLandscape ? 2 : 8),
                            // Show debug status if bypass is active
                            if (subscriptionService.isDebugBypassActive)
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.orange, width: 1),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.bug_report,
                                            color: Colors.orange, size: 16),
                                        SizedBox(width: 4),
                                        Text(
                                          'DEBUG MODE ACTIVE',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // SizedBox(height: 4),
                                    Text(
                                      'Subscription validation bypassed for testing',
                                      style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontSize: 10,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            //if (subscriptionService.isDebugBypassActive) SizedBox(height: isPhoneLandscape ? 2 : 8),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () async {
                                        if (subscriptionService
                                            .isDebugBypassActive) {
                                          // Clear debug bypass
                                          final confirm =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: Row(
                                                children: [
                                                  Icon(Icons.refresh,
                                                      color: Colors.blue),
                                                  SizedBox(width: 8),
                                                  Text('Clear Debug Mode',
                                                      style: TextStyle(
                                                          color: Colors.blue)),
                                                ],
                                              ),
                                              content: Text(
                                                  'This will clear debug bypass and restore normal subscription validation.'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(ctx)
                                                          .pop(false),
                                                  child: Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.of(ctx)
                                                          .pop(true),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.blue),
                                                  child: Text('Clear Debug'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm == true) {
                                            setState(() {
                                              _isLoading = true;
                                            });
                                            try {
                                              await subscriptionService
                                                  .debugClearBypass();
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Row(
                                                    children: [
                                                      Icon(Icons.refresh,
                                                          color: Colors.white),
                                                      SizedBox(width: 8),
                                                      Text(
                                                          'Debug mode cleared - normal validation restored'),
                                                    ],
                                                  ),
                                                  backgroundColor: Colors.blue,
                                                  duration:
                                                      Duration(seconds: 2),
                                                ),
                                              );
                                            } catch (e) {
                                              debugPrint(
                                                  "Error clearing debug mode: $e");
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Error clearing debug mode: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            } finally {
                                              if (context.mounted) {
                                                setState(() {
                                                  _isLoading = false;
                                                });
                                              }
                                            }
                                          }
                                        } else {
                                          // Activate debug bypass
                                          final confirm =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: Row(
                                                children: [
                                                  Icon(Icons.bug_report,
                                                      color: Colors.orange),
                                                  SizedBox(width: 8),
                                                  Text('Debug Mode',
                                                      style: TextStyle(
                                                          color:
                                                              Colors.orange)),
                                                ],
                                              ),
                                              content: Text(
                                                  'This will temporarily bypass subscription validation for testing. This does NOT affect production subscription logic.'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(ctx)
                                                          .pop(false),
                                                  child: Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.of(ctx)
                                                          .pop(true),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.orange),
                                                  child:
                                                      Text('Skip Validation'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm == true) {
                                            setState(() {
                                              _isLoading = true;
                                            });
                                            try {
                                              await subscriptionService
                                                  .debugSkipSubscription();
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Row(
                                                    children: [
                                                      Icon(Icons.check_circle,
                                                          color: Colors.white),
                                                      SizedBox(width: 8),
                                                      Text(
                                                          'Debug: Subscription validation bypassed!'),
                                                    ],
                                                  ),
                                                  backgroundColor: Colors.green,
                                                  duration:
                                                      Duration(seconds: 2),
                                                ),
                                              );

                                              if (widget.onSubscribed != null) {
                                                widget.onSubscribed!();
                                              }

                                              final navigator =
                                                  Navigator.of(context);
                                              Future.delayed(
                                                  Duration(milliseconds: 1000),
                                                  () {
                                                if (mounted &&
                                                    navigator.canPop()) {
                                                  navigator.pop();
                                                }
                                              });
                                            } catch (e) {
                                              debugPrint(
                                                  "Error in debug skip: $e");
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content:
                                                      Text('Debug error: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            } finally {
                                              if (context.mounted) {
                                                setState(() {
                                                  _isLoading = false;
                                                });
                                              }
                                            }
                                          }
                                        }
                                      },
                                style: TextButton.styleFrom(
                                  backgroundColor: subscriptionService
                                          .isDebugBypassActive
                                      ? Colors.blue.withValues(alpha: 0.1)
                                      : Colors.orange.withValues(alpha: 0.1),
                                  side: BorderSide(
                                      color: subscriptionService
                                              .isDebugBypassActive
                                          ? Colors.blue
                                          : Colors.orange,
                                      width: 1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                //for local testing only
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                        subscriptionService.isDebugBypassActive
                                            ? Icons.refresh
                                            : Icons.bug_report,
                                        color: subscriptionService
                                                .isDebugBypassActive
                                            ? Colors.blue
                                            : Colors.orange,
                                        size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      subscriptionService.isDebugBypassActive
                                          ? 'DEBUG: Clear Bypass'
                                          : 'DEBUG: Skip Subscription',
                                      style: TextStyle(
                                          color: subscriptionService
                                                  .isDebugBypassActive
                                              ? Colors.blue
                                              : Colors.orange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          //SizedBox(height: isPhoneLandscape ? 3 : 12),
                          // Required links for App Store approval
                          Column(
                            children: [
                              Text(
                                'By subscribing, you agree to our:',
                                style: TextStyle(
                                    fontSize: isPhoneLandscape ? 10 : 12,
                                    color: Colors.black54),
                                textAlign: TextAlign.center,
                              ),
                              //SizedBox(height: isPhoneLandscape ? 1 : 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: () async {
                                      final url = Uri.parse(
                                          'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/');
                                      if (await launcher.canLaunchUrl(url)) {
                                        await launcher.launchUrl(url,
                                            mode: launcher.LaunchMode
                                                .externalApplication);
                                      }
                                    },
                                    child: Text(
                                      'Terms of Use',
                                      style: TextStyle(
                                        fontSize: isPhoneLandscape ? 10 : 12,
                                        color: Color(0xFF8E6CFF),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    ' • ',
                                    style: TextStyle(
                                        fontSize: isPhoneLandscape ? 10 : 12,
                                        color: Colors.black54),
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      final url = Uri.parse(
                                          'https://haoyu.io/mm-privacy.html');
                                      final canLaunch =
                                          await launcher.canLaunchUrl(url);
                                      if (!context.mounted) return;
                                      if (canLaunch) {
                                        await launcher.launchUrl(url,
                                            mode: launcher.LaunchMode
                                                .externalApplication);
                                      } else {
                                        // Fallback to in-app dialog if can't open browser
                                        _showPrivacyPolicy(context);
                                      }
                                    },
                                    child: Text(
                                      'Privacy Policy',
                                      style: TextStyle(
                                        fontSize: isPhoneLandscape ? 10 : 12,
                                        color: Color(0xFF8E6CFF),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              //SizedBox(height: isPhoneLandscape ? 2 : 8),
                              Text(
                                'If you are part of a Family Sharing group and already have a subscription, tap "Restore Purchases" to unlock premium features.',
                                style: TextStyle(
                                    fontSize: isPhoneLandscape ? 8 : 10,
                                    color: Colors.black45),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Cancel anytime in Settings.',
                                style: TextStyle(
                                    fontSize: isPhoneLandscape ? 8 : 10,
                                    color: Colors.black45),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                          if (subscriptionService.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Column(
                                children: [
                                  // Check if this might be a family sharing issue
                                  if (subscriptionService.errorMessage!
                                          .toLowerCase()
                                          .contains('family') ||
                                      subscriptionService.errorMessage!
                                          .toLowerCase()
                                          .contains('shared') ||
                                      subscriptionService.errorMessage!
                                          .toLowerCase()
                                          .contains('member'))
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.orange.shade200),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(Icons.family_restroom,
                                              color: Colors.orange, size: 32),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Family Sharing Detected',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange.shade800),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'A family member has already purchased this subscription. Please restart the app to access premium features.',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.orange.shade700),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                          ElevatedButton(
                                            onPressed: () async {
                                              // Force refresh subscription status
                                              await subscriptionService
                                                  .checkSubscriptionStatus();
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                            ),
                                            child: Text('Refresh Status'),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    // Regular error message
                                    Text(
                                      subscriptionService.errorMessage!,
                                      style: const TextStyle(color: Colors.red),
                                      textAlign: TextAlign.center,
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  // Phone landscape layout with two columns
  Widget _buildPhoneLandscapeLayout(SubscriptionService subscriptionService) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        AutoSizeText(
          'Welcome to M&M Learning Lab!',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFFFF6B6B),
            fontFamily: 'Comic Sans MS',
            letterSpacing: 1.2,
          ),
          textAlign: TextAlign.center,
          minFontSize: 14,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 6),
        // Two-column layout
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column: What's Inside (for kids)
            Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFF8E6CFF).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text('🌟 ', style: TextStyle(fontSize: 16)),
                        Expanded(
                          child: AutoSizeText(
                            "What's Inside",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8E6CFF),
                            ),
                            minFontSize: 12,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    // SizedBox(height: 4),
                    _KidFeature(
                        icon: '🤖', text: 'Chat with our friendly AI buddy!'),
                    _KidFeature(
                        icon: '📚', text: 'Create and read amazing stories!'),
                    _KidFeature(
                        icon: '🎮', text: 'Play fun games and puzzles!'),
                    _KidFeature(
                        icon: '🎯', text: 'Solve exciting math challenges!'),
                  ],
                ),
              ),
            ),
            SizedBox(width: 8),
            // Right column: Why a Subscription (for parents)
            Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFF24924B).withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AutoSizeText(
                      'Why a Subscription?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8E6CFF),
                        fontSize: 14,
                      ),
                      minFontSize: 10,
                      maxLines: 1,
                    ),
                    SizedBox(height: 3),
                    AutoSizeText(
                      'We use advanced AI for:',
                      style: TextStyle(
                          fontSize: 11, color: Colors.black87, height: 1.3),
                      minFontSize: 9,
                      maxLines: 1,
                    ),
                    SizedBox(height: 3),
                    _ParentBullet(icon: '📖', text: 'AI-powered story reading'),
                    _ParentBullet(icon: '🤖', text: 'Friendly AI chat'),
                    _ParentBullet(icon: '➗', text: 'Math buddy'),
                    _ParentBullet(icon: '♟️', text: 'AI games'),
                    _ParentBullet(
                        icon: '🛡️', text: 'Safe, ad-free environment'),
                    SizedBox(height: 1),
                    _ParentBullet(
                      icon: '💵',
                      text: subscriptionService.products.isNotEmpty
                          ? '${subscriptionService.products.first.price}/month - First month free'
                          : 'Loading...',
                      isHighlighted: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Portrait layout (original layout)
  Widget _buildPortraitLayout(
      SubscriptionService subscriptionService, bool isPhoneLandscape) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoSizeText(
          'Welcome to M&M Learning Lab!',
          style: TextStyle(
            fontSize: isPhoneLandscape ? 22 : 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFFFF6B6B),
            fontFamily: 'Comic Sans MS',
            letterSpacing: 1.2,
          ),
          textAlign: TextAlign.center,
          minFontSize: 16,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        //SizedBox(height: isPhoneLandscape ? 4 : 12),
        // What's Inside (for kids)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Color(0xFF8E6CFF).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(isPhoneLandscape ? 16 : 20),
          ),
          padding: EdgeInsets.all(isPhoneLandscape ? 6 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('🌟 ', style: TextStyle(fontSize: 22)),
                  AutoSizeText(
                    "What's Inside",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8E6CFF),
                    ),
                    minFontSize: 16,
                    maxLines: 1,
                  ),
                ],
              ),
              SizedBox(height: isPhoneLandscape ? 3 : 10),
              _KidFeature(icon: '🤖', text: 'Chat with our friendly AI buddy!'),
              _KidFeature(icon: '📚', text: 'Create and read amazing stories!'),
              _KidFeature(icon: '🎮', text: 'Play fun games and puzzles!'),
              _KidFeature(icon: '🎯', text: 'Solve exciting math challenges!'),
            ],
          ),
        ),
        SizedBox(height: isPhoneLandscape ? 4 : 12),
        // Divider
        Row(
          children: [
            Expanded(
                child: Divider(
                    color: Color(0xFF8E6CFF).withValues(alpha: 0.2),
                    thickness: 2)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text('👨‍👩‍👧 For Parents',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF24924B))),
            ),
            Expanded(
                child: Divider(
                    color: Color(0xFF8E6CFF).withValues(alpha: 0.2),
                    thickness: 2)),
          ],
        ),
        SizedBox(height: isPhoneLandscape ? 3 : 10),
        // Parent Info
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Color(0xFF24924B).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(isPhoneLandscape ? 12 : 16),
          ),
          padding: EdgeInsets.all(isPhoneLandscape ? 6 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AutoSizeText(
                'Why a Subscription?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8E6CFF),
                  fontSize: isPhoneLandscape ? 16 : 18,
                ),
                minFontSize: 12,
                maxLines: 1,
              ),
              SizedBox(height: isPhoneLandscape ? 3 : 8),
              AutoSizeText(
                'To provide your child with the best learning experience, we use advanced AI for:',
                style: TextStyle(
                    fontSize: isPhoneLandscape ? 12 : 14,
                    color: Colors.black87,
                    height: 1.4),
                minFontSize: 10,
                maxLines: 2,
              ),
              SizedBox(height: isPhoneLandscape ? 3 : 10),
              _ParentBullet(icon: '📖', text: 'AI-powered story reading'),
              _ParentBullet(
                  icon: '🤖', text: 'Friendly AI chat and conversation'),
              _ParentBullet(
                  icon: '➗', text: 'Math buddy for help and practice'),
              _ParentBullet(
                  icon: '♟️',
                  text: 'Competing with AI in games like Gobang and Chess'),
              _ParentBullet(
                  icon: '🛡️', text: 'Safe, ad-free, and private environment'),
              SizedBox(height: isPhoneLandscape ? 2 : 6),
              _ParentBullet(
                icon: '💵',
                text: subscriptionService.products.isNotEmpty
                    ? 'Monthly subscription: ${subscriptionService.products.first.price}/month with first month free'
                    : 'Loading pricing details...',
                isHighlighted: true,
              ),
              SizedBox(height: isPhoneLandscape ? 2 : 6),
              _ParentBullet(
                  icon: '🚀',
                  text:
                      'We are always adding new features to help your child grow and learn!'),
              SizedBox(height: isPhoneLandscape ? 2 : 6),
              AutoSizeText(
                'Thank you for supporting our mission to make learning fun and effective for every child!',
                style: TextStyle(
                    fontSize: isPhoneLandscape ? 10 : 12,
                    color: Color(0xFF24924B),
                    fontStyle: FontStyle.italic,
                    height: 1.3),
                minFontSize: 8,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KidFeature extends StatelessWidget {
  final String icon;
  final String text;
  const _KidFeature({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = screenWidth > screenHeight;
    final isPhoneLandscape = isLandscape && screenHeight < 500;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isPhoneLandscape ? 0 : 1),
      child: Row(
        children: [
          Text(icon, style: TextStyle(fontSize: isPhoneLandscape ? 18 : 22)),
          SizedBox(width: isPhoneLandscape ? 8 : 10),
          Expanded(
            child: AutoSizeText(
              text,
              style: TextStyle(
                  fontSize: isPhoneLandscape ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
              minFontSize: isPhoneLandscape ? 10 : 12,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentBullet extends StatelessWidget {
  final String icon;
  final String text;
  final bool isHighlighted;

  const _ParentBullet(
      {required this.icon, required this.text, this.isHighlighted = false});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = screenWidth > screenHeight;
    final isPhoneLandscape = isLandscape && screenHeight < 500;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isPhoneLandscape ? 0.5 : 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: TextStyle(fontSize: isPhoneLandscape ? 16 : 18)),
          SizedBox(width: isPhoneLandscape ? 6 : 8),
          Expanded(
            child: AutoSizeText(
              text,
              style: TextStyle(
                fontSize: isHighlighted
                    ? (isPhoneLandscape ? 14 : 16)
                    : (isPhoneLandscape ? 12 : 14),
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                color: isHighlighted ? Color(0xFF24924B) : Colors.black87,
                height: 1.4,
              ),
              minFontSize: isPhoneLandscape ? 8 : 10,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
