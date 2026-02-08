import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service.dart';
import '../screens/subscription_screen.dart';

class SubscriptionGuard extends StatefulWidget {
  final Widget child;

  const SubscriptionGuard({super.key, required this.child});

  @override
  State<SubscriptionGuard> createState() => _SubscriptionGuardState();
}

class _SubscriptionGuardState extends State<SubscriptionGuard> {
  bool _showPaywall = false;
  bool _isCheckingAccess = true;

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      final subscriptionService =
          Provider.of<SubscriptionService>(context, listen: false);
      final hasAccess =
          await subscriptionService.hasActiveAccess(refreshSubscription: false);

      if (!mounted) return;

      setState(() {
        _showPaywall = !hasAccess;
        _isCheckingAccess = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _showPaywall = false;
        _isCheckingAccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionService>(
      builder: (context, subscriptionService, child) {
        if (_isCheckingAccess || subscriptionService.isLoading) {
          return const ColoredBox(
            color: Colors.white,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Show the child if subscribed or not showing paywall yet
        if (subscriptionService.isSubscribed || !_showPaywall) {
          return widget.child;
        }

        // Otherwise show subscription screen
        return SubscriptionScreen(
          onSubscribed: () {
            setState(() {
              _showPaywall = false;
            });
          },
        );
      },
    );
  }
}
