import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service.dart';
import '../screens/subscription_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionGuard extends StatefulWidget {
  final Widget child;

  const SubscriptionGuard({Key? key, required this.child}) : super(key: key);

  @override
  State<SubscriptionGuard> createState() => _SubscriptionGuardState();
}

class _SubscriptionGuardState extends State<SubscriptionGuard> {
  // When the app first launches, we don't want to immediately show the paywall
  // We'll set this in initState after checking the free trial status
  bool _showPaywall = false;

  // Track the first time the app is used
  static const String _firstLaunchTimeKey = 'first_launch_time';
  static const int _freeTrialDurationDays = 14;

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
  }

  Future<void> _checkSubscriptionStatus() async {
    final subscriptionService = Provider.of<SubscriptionService>(context, listen: false);
    final isSubscribed = await subscriptionService.checkSubscriptionStatus();

    if (!isSubscribed) {
      final inFreeTrial = await _isInFreeTrial();

      // Only show paywall if not subscribed and not in free trial
      if (!inFreeTrial) {
        setState(() {
          _showPaywall = true;
        });
      }
    }
  }

  // Check if the user is in the free trial period
  Future<bool> _isInFreeTrial() async {
    final prefs = await SharedPreferences.getInstance();

    // Get the first launch time, or set it if it doesn't exist
    int? firstLaunchTime = prefs.getInt(_firstLaunchTimeKey);
    if (firstLaunchTime == null) {
      firstLaunchTime = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_firstLaunchTimeKey, firstLaunchTime);
      print('First launch time set: $firstLaunchTime');
      // Always in free trial on first launch
      return true;
    }

    // Calculate how many days since first launch
    final firstLaunchDate = DateTime.fromMillisecondsSinceEpoch(firstLaunchTime);
    final today = DateTime.now();
    final difference = today.difference(firstLaunchDate).inDays;

    print('Days since first launch: $difference');

    // In free trial if within the trial period
    return difference < _freeTrialDurationDays;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionService>(
      builder: (context, subscriptionService, child) {
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
