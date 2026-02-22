import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Debug flag to bypass subscription validation for development
const bool kBypassSubscriptionForDebug =
    false; // Set to true to bypass subscription checks

// Debug flag to ignore restored purchases for testing
bool _debugIgnoreRestoredPurchases = false;

// Debug flag for temporarily bypassing subscription (separate from production)
bool _debugBypassActive = false;

class SubscriptionService with ChangeNotifier, WidgetsBindingObserver {
  static final SubscriptionService _instance = SubscriptionService._internal();

  factory SubscriptionService() => _instance;

  SubscriptionService._internal() {
    // Initialize the subscription service
    _initialize();
  }

  // Product IDs
  static const String monthlySubscriptionId =
      'com.hyu.LearningLab.premium.monthly';
  static const String _isSubscribedKey = 'isSubscribed';
  static const String _subscriptionValidUntilMsKey =
      'subscription_valid_until_ms';
  static const String _familySharedSubscriptionKey = 'familySharedSubscription';
  static const String _firstLaunchTimeKey = 'first_launch_time';
  static const int _freeTrialDurationDays = 14;
  // Used for Google Play cache expiry estimation and fallback heuristic
  static const int _subscriptionCycleDays = 31;
  static const int _subscriptionGraceDays = 7;
  static const int _defaultValidatedCacheHours = 24;
  // Minimum interval between full platform store checks (app-resume throttle)
  static const Duration _minCheckInterval = Duration(hours: 1);

  // Stream subscription for purchase updates
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // In-app purchase instance
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  // Subscription status
  bool _isSubscribed = false;
  bool get isSubscribed => _isSubscribed;

  // List of available products
  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  // Loading states
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  // Error message
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isRestoringPurchases = false;
  bool _foundSubscriptionDuringRestore = false;
  Completer<bool>? _restoreCompleter;

  // Sequential purchase processing — prevents async interleaving
  bool _processingPurchases = false;
  final List<List<PurchaseDetails>> _pendingPurchaseLists = [];

  // Throttle: tracks when the last full platform check completed
  DateTime? _lastFullCheckTime;
  bool _isCheckingStatus = false;

  // Initialize the subscription service
  Future<void> _initialize() async {
    WidgetsBinding.instance.addObserver(this);

    // Set up the in-app purchase listener
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;

    _subscription = purchaseUpdated.listen(
      _listenToPurchaseUpdated,
      onDone: () {
        _subscription.cancel();
      },
      onError: (error) {
        _errorMessage = "Purchase stream error: $error";
        notifyListeners();
      },
    );

    // Load products and check subscription status
    await _loadProducts();
    await checkSubscriptionStatus();

    _isLoading = false;
    notifyListeners();
  }

  // Load available products from the store, with up to 3 attempts on failure.
  Future<void> _loadProducts({int attempt = 1}) async {
    const maxAttempts = 3;
    try {
      final Set<String> productIds = {monthlySubscriptionId};
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(productIds);

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint("Products not found: ${response.notFoundIDs}");
        _errorMessage =
            "Some products could not be found: ${response.notFoundIDs.join(", ")}";
      }

      _products = response.productDetails;
      debugPrint("Products loaded: ${_products.length}");

      if (_products.isNotEmpty) {
        for (var product in _products) {
          debugPrint(
              "Product: ${product.id} - ${product.title} - ${product.price}");
        }
        _errorMessage = null;
      } else {
        debugPrint("No products found (attempt $attempt/$maxAttempts)");
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(seconds: attempt * 2));
          return _loadProducts(attempt: attempt + 1);
        }
        _errorMessage = "No subscription products found";
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Error loading products (attempt $attempt/$maxAttempts): $e");
      if (attempt < maxAttempts) {
        await Future.delayed(Duration(seconds: attempt * 2));
        return _loadProducts(attempt: attempt + 1);
      }
      _errorMessage = "Error loading products: $e";
      notifyListeners();
    }
  }

  /// Allows the UI to trigger a fresh product load after a failure.
  Future<void> retryLoadProducts() async {
    _errorMessage = null;
    notifyListeners();
    await _loadProducts();
  }

  // ---------------------------------------------------------------------------
  // Subscription status check — uses platform-native APIs
  // ---------------------------------------------------------------------------

  /// Full platform-store check. Use [checkSubscriptionStatusThrottled] from
  /// app-resume to avoid hitting the store on every foreground event.
  Future<bool> checkSubscriptionStatus() async {
    if (kBypassSubscriptionForDebug || _debugBypassActive) {
      _isSubscribed = true;
      debugPrint("🧪 DEBUG: Subscription bypassed (debug mode active)");
      return true;
    }

    // Prevent overlapping checks
    if (_isCheckingStatus) {
      debugPrint("Subscription check already in progress, skipping");
      return _isSubscribed;
    }
    _isCheckingStatus = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final previousStatus = _isSubscribed;

      // Start from clean state — guilty until proven innocent.
      _isSubscribed = false;

      bool hasActiveSubscription = false;

      // Primary check: ask the platform store directly
      if (Platform.isIOS) {
        hasActiveSubscription = await _verifyViaStoreKit2();
      } else if (Platform.isAndroid) {
        hasActiveSubscription = await _verifyViaGooglePlay();
      }

      // Offline fallback: use cached entitlement if platform check returned false
      if (!hasActiveSubscription) {
        hasActiveSubscription = await _hasCachedValidatedEntitlement(prefs);
        if (hasActiveSubscription) {
          debugPrint("Using cached entitlement (offline/error fallback)");
        }
      }

      _isSubscribed = hasActiveSubscription;
      await prefs.setBool(_isSubscribedKey, hasActiveSubscription);

      // Remove legacy sticky Family Sharing flag
      if (prefs.containsKey(_familySharedSubscriptionKey)) {
        await prefs.remove(_familySharedSubscriptionKey);
      }

      if (previousStatus != _isSubscribed) {
        debugPrint(
            "Subscription status changed: $previousStatus -> $_isSubscribed");
      }

      _lastFullCheckTime = DateTime.now();
      notifyListeners();
      return _isSubscribed;
    } catch (e) {
      debugPrint("Error checking subscription status: $e");
      _isSubscribed = false;
      notifyListeners();
      return false;
    } finally {
      _isCheckingStatus = false;
    }
  }

  /// Throttled variant — skips the platform store query if the last full check
  /// was less than [_minCheckInterval] ago. Used by app-resume lifecycle.
  Future<bool> checkSubscriptionStatusThrottled() async {
    if (_lastFullCheckTime != null &&
        DateTime.now().difference(_lastFullCheckTime!) < _minCheckInterval) {
      debugPrint("Subscription check throttled "
          "(last check ${DateTime.now().difference(_lastFullCheckTime!).inMinutes} min ago)");
      return _isSubscribed;
    }
    return checkSubscriptionStatus();
  }

  // ---------------------------------------------------------------------------
  // iOS: StoreKit 2 verification via SK2Transaction.transactions()
  // ---------------------------------------------------------------------------

  Future<bool> _verifyViaStoreKit2() async {
    try {
      debugPrint("SK2: Querying transactions...");
      final transactions = await SK2Transaction.transactions();
      debugPrint("SK2: Found ${transactions.length} transactions");

      DateTime? latestExpiry;

      for (final t in transactions) {
        if (t.productId != monthlySubscriptionId) continue;

        final expStr = t.expirationDate;
        if (expStr == null) {
          debugPrint("SK2: Transaction has no expirationDate, skipping");
          continue;
        }

        // StoreKit 2 pigeon bridge sends dates as epoch-ms strings
        final expMs = int.tryParse(expStr);
        DateTime? expDate;
        if (expMs != null) {
          expDate = DateTime.fromMillisecondsSinceEpoch(expMs);
        } else {
          expDate = DateTime.tryParse(expStr);
        }
        if (expDate == null) {
          debugPrint("SK2: Could not parse expirationDate: $expStr");
          continue;
        }

        // Track the latest expiration across all transactions for this product
        if (latestExpiry == null || expDate.isAfter(latestExpiry)) {
          latestExpiry = expDate;
        }
      }

      final prefs = await SharedPreferences.getInstance();

      if (latestExpiry != null && latestExpiry.isAfter(DateTime.now())) {
        debugPrint("SK2: Active subscription, expires $latestExpiry");
        await _setValidatedEntitlementCache(prefs,
            expiresAtMs: latestExpiry.millisecondsSinceEpoch);
        return true;
      }

      if (latestExpiry != null) {
        debugPrint("SK2: Subscription expired on $latestExpiry");
      } else {
        debugPrint("SK2: No subscription transactions found");
      }
      await _clearValidatedEntitlementCache(prefs);
      return false;
    } catch (e) {
      debugPrint("SK2 verification error: $e");
      return false; // Caller falls back to cached entitlement
    }
  }

  // ---------------------------------------------------------------------------
  // Android: Google Play Billing verification via queryPastPurchases()
  // ---------------------------------------------------------------------------

  Future<bool> _verifyViaGooglePlay() async {
    try {
      debugPrint("Google Play: Querying past purchases...");
      final androidAddition = _inAppPurchase
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();

      // queryPastPurchases calls BillingClient.queryPurchases for both
      // inapp and subs. Google Play only returns currently active purchases.
      final result = await androidAddition.queryPastPurchases();

      if (result.error != null) {
        debugPrint("Google Play query error: ${result.error}");
      }

      for (final purchase in result.pastPurchases) {
        if (purchase.productID != monthlySubscriptionId) continue;

        final gpPurchase = purchase as GooglePlayPurchaseDetails;
        final billingPurchase = gpPurchase.billingClientPurchase;

        // Google only returns this purchase if it's currently active
        debugPrint("Google Play: Active subscription found "
            "(autoRenewing=${billingPurchase.isAutoRenewing})");

        // Cache entitlement — estimate expiry from now + cycle + grace.
        // We use now() because purchaseTime is the *original* purchase date,
        // not the latest renewal, so it would already be in the past for
        // long-running subscriptions.
        final expMs = DateTime.now().millisecondsSinceEpoch +
            const Duration(days: _subscriptionCycleDays + _subscriptionGraceDays)
                .inMilliseconds;
        final prefs = await SharedPreferences.getInstance();
        await _setValidatedEntitlementCache(prefs, expiresAtMs: expMs);
        return true;
      }

      debugPrint("Google Play: No active subscription found");
      final prefs = await SharedPreferences.getInstance();
      await _clearValidatedEntitlementCache(prefs);
      return false;
    } catch (e) {
      debugPrint("Google Play verification error: $e");
      return false; // Caller falls back to cached entitlement
    }
  }

  // ---------------------------------------------------------------------------
  // Free trial
  // ---------------------------------------------------------------------------

  Future<int> getDaysLeftInTrial() async {
    final prefs = await SharedPreferences.getInstance();

    int? firstLaunchTime = prefs.getInt(_firstLaunchTimeKey);
    if (firstLaunchTime == null) {
      firstLaunchTime = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_firstLaunchTimeKey, firstLaunchTime);
      return _freeTrialDurationDays;
    }

    final firstLaunchDate =
        DateTime.fromMillisecondsSinceEpoch(firstLaunchTime);
    final elapsedDays = DateTime.now().difference(firstLaunchDate).inDays;
    final daysRemaining = _freeTrialDurationDays - elapsedDays;

    return daysRemaining > 0 ? daysRemaining : 0;
  }

  Future<bool> isInFreeTrial() async {
    return (await getDaysLeftInTrial()) > 0;
  }

  // Single source of truth for whether app access should be granted.
  Future<bool> hasActiveAccess({bool refreshSubscription = false}) async {
    final isSubscribed =
        refreshSubscription ? await checkSubscriptionStatus() : _isSubscribed;
    if (isSubscribed) return true;
    return isInFreeTrial();
  }

  // ---------------------------------------------------------------------------
  // Restore purchases (used by "Restore Purchases" button, not by status check)
  // ---------------------------------------------------------------------------

  Future<bool> restorePurchases() async {
    try {
      debugPrint("Restoring purchases...");
      _isRestoringPurchases = true;
      _foundSubscriptionDuringRestore = false;
      _restoreCompleter = Completer<bool>();

      await _inAppPurchase.restorePurchases();
      debugPrint("Restore purchases initiated — waiting for stream...");

      // Completes early as soon as a valid subscription is confirmed.
      // Falls back to _foundSubscriptionDuringRestore after 10 s if the
      // platform sends no further events (e.g. no active subscription).
      return await _restoreCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => _foundSubscriptionDuringRestore,
      );
    } catch (e) {
      debugPrint("Error restoring purchases: $e");
      return false;
    } finally {
      _isRestoringPurchases = false;
      _restoreCompleter = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Purchase flow
  // ---------------------------------------------------------------------------

  Future<void> subscribe() async {
    try {
      if (_products.isEmpty) {
        _errorMessage = "No products available to purchase";
        notifyListeners();
        return;
      }

      final productDetails = _products.firstWhere(
        (product) => product.id == monthlySubscriptionId,
        orElse: () => throw Exception("Monthly subscription product not found"),
      );

      debugPrint("Starting purchase for: ${productDetails.id}");

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
      );

      final bool success =
          await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      if (!success) {
        _errorMessage = "Failed to initiate purchase. Please try again.";
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error starting subscription: $e");
      _errorMessage = "Error starting subscription: $e";
      notifyListeners();
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Purchase stream listener
  // ---------------------------------------------------------------------------

  // Enqueue incoming purchase events and drain sequentially so that async
  // handlers (completePurchase, handleSubscriptionPurchase) never interleave.
  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    debugPrint(
        "Purchase update received: ${purchaseDetailsList.length} purchases");
    _pendingPurchaseLists.add(purchaseDetailsList);
    _drainPurchaseQueue();
  }

  Future<void> _drainPurchaseQueue() async {
    if (_processingPurchases) return;
    _processingPurchases = true;
    try {
      while (_pendingPurchaseLists.isNotEmpty) {
        final list = _pendingPurchaseLists.removeAt(0);
        for (final purchaseDetails in list) {
          await _processSinglePurchase(purchaseDetails);
        }
      }
    } finally {
      _processingPurchases = false;
    }
  }

  Future<void> _processSinglePurchase(PurchaseDetails purchaseDetails) async {
    debugPrint(
        "Purchase status: ${purchaseDetails.status} for ${purchaseDetails.productID}");

    if (purchaseDetails.status == PurchaseStatus.pending) {
      debugPrint("Purchase is pending");
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      debugPrint("Purchase error: ${purchaseDetails.error}");
      _errorMessage =
          "Purchase error: ${purchaseDetails.error?.message ?? 'Unknown error'}";
      notifyListeners();
    } else if (purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored) {
      if (purchaseDetails.productID == monthlySubscriptionId) {
        if (purchaseDetails.status == PurchaseStatus.restored &&
            _debugIgnoreRestoredPurchases) {
          debugPrint("🧪 DEBUG: Ignoring restored purchase for testing");
          // Still complete the purchase below
        } else {
          await _handleSubscriptionPurchase(purchaseDetails);
        }
      }
    }

    // Complete the purchase — important!
    if (purchaseDetails.pendingCompletePurchase) {
      debugPrint("Completing purchase for ${purchaseDetails.productID}");
      await _inAppPurchase.completePurchase(purchaseDetails);
    }
  }

  Future<void> _handleSubscriptionPurchase(
      PurchaseDetails purchaseDetails) async {
    try {
      debugPrint("Handling purchase for ${purchaseDetails.productID}");
      final isEntitled =
          await _validateSubscriptionEntitlement(purchaseDetails);

      _isSubscribed = isEntitled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isSubscribedKey, isEntitled);

      if (isEntitled) {
        if (purchaseDetails.status == PurchaseStatus.purchased) {
          // Immediate 24h cache so the user isn't blocked
          await _setValidatedEntitlementCache(prefs);
          // Fire-and-forget: update cache with real expiry from platform API
          _updateCacheWithRealExpiry();
        }
        _foundSubscriptionDuringRestore = true;
        // Resolve restorePurchases() early — no need to wait for the timeout.
        if (!(_restoreCompleter?.isCompleted ?? true)) {
          _restoreCompleter!.complete(true);
        }
        debugPrint("Subscription entitlement confirmed");
      } else {
        await _clearValidatedEntitlementCache(prefs);
        debugPrint("Subscription entitlement not active");
      }

      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      debugPrint("Error handling purchase: $e");
      _errorMessage = "Error processing purchase: $e";
      notifyListeners();
    }
  }

  Future<bool> _validateSubscriptionEntitlement(
      PurchaseDetails purchaseDetails) async {
    // Fresh purchase (not a restore): trusted immediately — Apple/Google
    // already validated it. We check the status directly because
    // _isRestoringPurchases may not be set when the subscription screen
    // calls InAppPurchase.instance.restorePurchases() directly.
    if (purchaseDetails.status == PurchaseStatus.purchased &&
        !_isRestoringPurchases) {
      return true;
    }

    // Restored purchase (or purchase during active restore): verify with the
    // platform store API to check expiry.
    if (Platform.isIOS) {
      return _verifyViaStoreKit2();
    } else if (Platform.isAndroid) {
      return _verifyViaGooglePlay();
    }

    // Unknown platform fallback
    return _isLikelyActiveByTransactionDate(purchaseDetails);
  }

  // ---------------------------------------------------------------------------
  // Entitlement cache (offline fallback)
  // ---------------------------------------------------------------------------

  Future<bool> _hasCachedValidatedEntitlement(SharedPreferences prefs) async {
    final validUntilMs = prefs.getInt(_subscriptionValidUntilMsKey);
    if (validUntilMs == null) {
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch < validUntilMs;
  }

  Future<void> _setValidatedEntitlementCache(SharedPreferences prefs,
      {int? expiresAtMs}) async {
    final fallbackValidUntil = DateTime.now()
        .add(const Duration(hours: _defaultValidatedCacheHours))
        .millisecondsSinceEpoch;
    await prefs.setInt(
      _subscriptionValidUntilMsKey,
      expiresAtMs ?? fallbackValidUntil,
    );
  }

  Future<void> _clearValidatedEntitlementCache(SharedPreferences prefs) async {
    await prefs.remove(_subscriptionValidUntilMsKey);
  }

  /// Background call to replace the 24h fallback cache with the real expiry
  /// from the platform store. Called after a fresh purchase is trusted.
  void _updateCacheWithRealExpiry() {
    Future<void> doUpdate() async {
      try {
        if (Platform.isIOS) {
          await _verifyViaStoreKit2();
        } else if (Platform.isAndroid) {
          await _verifyViaGooglePlay();
        }
      } catch (e) {
        debugPrint("Background cache update failed (non-fatal): $e");
      }
    }

    doUpdate();
  }

  // ---------------------------------------------------------------------------
  // Last-resort fallback: transaction date heuristic (unknown platforms only)
  // ---------------------------------------------------------------------------

  bool _isLikelyActiveByTransactionDate(PurchaseDetails purchaseDetails) {
    final transactionDateRaw = purchaseDetails.transactionDate;
    if (transactionDateRaw == null || transactionDateRaw.isEmpty) {
      debugPrint('Missing transaction date for local subscription fallback');
      return false;
    }

    final transactionMs = int.tryParse(transactionDateRaw);
    if (transactionMs == null) {
      debugPrint('Invalid transaction date for local subscription fallback');
      return false;
    }

    final transactionTime =
        DateTime.fromMillisecondsSinceEpoch(transactionMs, isUtc: true)
            .toLocal();
    final daysSinceTransaction =
        DateTime.now().difference(transactionTime).inDays;
    final activeWindowDays = _subscriptionCycleDays + _subscriptionGraceDays;
    final isActive = daysSinceTransaction <= activeWindowDays;
    debugPrint(
        'Local fallback: days=$daysSinceTransaction window=$activeWindowDays active=$isActive');
    return isActive;
  }

  // ---------------------------------------------------------------------------
  // Developer testing methods
  // ---------------------------------------------------------------------------

  Future<void> resetSubscriptionForTesting() async {
    assert(kDebugMode, 'resetSubscriptionForTesting() must only be called in debug builds');
    if (!kDebugMode) return;
    try {
      debugPrint("🧪 DEBUG: Resetting subscription for testing...");

      _debugIgnoreRestoredPurchases = true;
      _isSubscribed = false;
      _errorMessage = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_isSubscribedKey);
      await prefs.remove(_subscriptionValidUntilMsKey);
      await prefs.remove(_familySharedSubscriptionKey);
      await prefs.remove(_firstLaunchTimeKey);

      debugPrint("🧪 DEBUG: Subscription state reset complete");
      debugPrint("🧪 DEBUG: isSubscribed = $_isSubscribed");

      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint("🧪 DEBUG: Error resetting subscription: $e");
      _errorMessage = "Debug reset error: $e";
      notifyListeners();
    }
  }

  Future<void> forceRefreshSubscriptionStatus() async {
    assert(kDebugMode, 'forceRefreshSubscriptionStatus() must only be called in debug builds');
    if (!kDebugMode) return;
    try {
      debugPrint("🧪 DEBUG: Force refreshing subscription status...");
      _isSubscribed = false;
      await checkSubscriptionStatus();
      debugPrint(
          "🧪 DEBUG: Force refresh complete, isSubscribed = $_isSubscribed");
    } catch (e) {
      debugPrint("🧪 DEBUG: Error force refreshing: $e");
    }
  }

  Future<void> enableNormalSubscriptionChecking() async {
    assert(kDebugMode, 'enableNormalSubscriptionChecking() must only be called in debug builds');
    if (!kDebugMode) return;
    debugPrint("🧪 DEBUG: Re-enabling normal subscription checking...");
    _debugIgnoreRestoredPurchases = false;
    await checkSubscriptionStatus();
    debugPrint(
        "🧪 DEBUG: Normal subscription checking restored, isSubscribed = $_isSubscribed");
  }

  Future<void> debugSkipSubscription() async {
    assert(kDebugMode, 'debugSkipSubscription() must only be called in debug builds');
    if (!kDebugMode) return;
    try {
      debugPrint("🧪 DEBUG: Bypassing subscription validation for testing...");

      _debugBypassActive = true;
      _isSubscribed = true;
      _errorMessage = null;

      debugPrint(
          "🧪 DEBUG: Debug bypass activated - isSubscribed = $_isSubscribed");

      notifyListeners();
    } catch (e) {
      debugPrint("🧪 DEBUG: Error activating debug bypass: $e");
      _errorMessage = "Debug bypass error: $e";
      notifyListeners();
      rethrow;
    }
  }

  Future<void> debugClearBypass() async {
    assert(kDebugMode, 'debugClearBypass() must only be called in debug builds');
    if (!kDebugMode) return;
    try {
      debugPrint("🧪 DEBUG: Clearing debug bypass...");

      _debugBypassActive = false;
      _errorMessage = null;

      await checkSubscriptionStatus();

      debugPrint(
          "🧪 DEBUG: Debug bypass cleared, isSubscribed = $_isSubscribed");
    } catch (e) {
      debugPrint("🧪 DEBUG: Error clearing debug bypass: $e");
      _errorMessage = "Error clearing debug bypass: $e";
      notifyListeners();
    }
  }

  bool get isDebugBypassActive => _debugBypassActive;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkSubscriptionStatusThrottled();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription.cancel();
    super.dispose();
  }
}
