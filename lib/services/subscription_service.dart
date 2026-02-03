import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Debug flag to bypass subscription validation for development
const bool kBypassSubscriptionForDebug = false; // Set to true to bypass subscription checks

// Debug flag to ignore restored purchases for testing
bool _debugIgnoreRestoredPurchases = false;

// Debug flag for temporarily bypassing subscription (separate from production)
bool _debugBypassActive = false;

class SubscriptionService with ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();

  factory SubscriptionService() => _instance;

  SubscriptionService._internal() {
    // Initialize the subscription service
    _initialize();
  }

  // Product IDs
  static const String monthlySubscriptionId = 'com.hyu.LearningLab.premium.monthly';

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

  // Initialize the subscription service
  Future<void> _initialize() async {
    // Set up the in-app purchase listener
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;

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

  // Load available products from the store
  Future<void> _loadProducts() async {
    try {
      final Set<String> productIds = {monthlySubscriptionId};
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(productIds);

      if (response.notFoundIDs.isNotEmpty) {
        print("Products not found: ${response.notFoundIDs}");
        _errorMessage = "Some products could not be found: ${response.notFoundIDs.join(", ")}";
      }

      _products = response.productDetails;
      print("Products loaded: ${_products.length}");

      if (_products.isNotEmpty) {
        // Print product details for debugging
        for (var product in _products) {
          print("Product: ${product.id} - ${product.title} - ${product.price}");
        }
      } else {
        print("No products found");
        _errorMessage = "No subscription products found";
      }

      notifyListeners();
    } catch (e) {
      print("Error loading products: $e");
      _errorMessage = "Error loading products: $e";
      notifyListeners();
    }
  }

  // Check current subscription status
  Future<bool> checkSubscriptionStatus() async {
    // Debug bypass - completely separate from production logic
    if (kBypassSubscriptionForDebug || _debugBypassActive) {
      _isSubscribed = true;
      print("🧪 DEBUG: Subscription bypassed (debug mode active)");
      // Do NOT call notifyListeners() here to avoid build errors during initialization
      return true;
    }

    try {
      // Check local storage first for rapid UI response
      final prefs = await SharedPreferences.getInstance();
      final storedStatus = prefs.getBool('isSubscribed') ?? false;

      // Set initial status from stored values
      _isSubscribed = storedStatus;

      // Check both direct purchases and Family Sharing
      final bool validPurchase = await _verifyPreviousPurchases();
      final bool familySharing = await _checkFamilySharing();

      // User has subscription if they have direct purchase OR family sharing
      final bool hasSubscription = validPurchase || familySharing;

      // If subscription status differs from local storage, update local
      if (_isSubscribed != hasSubscription) {
        _isSubscribed = hasSubscription;
        await prefs.setBool('isSubscribed', hasSubscription);

        if (familySharing && !validPurchase) {
          print("✅ Subscription available through Family Sharing");
        }
      }

      notifyListeners();
      return _isSubscribed;
    } catch (e) {
      print("Error checking subscription status: $e");
      return false;
    }
  }

  // Check for Family Sharing subscription access (Better approach)
  Future<bool> _checkFamilySharing() async {
    try {
      print("🔍 Checking subscription entitlements...");

      // Check if we have any stored family sharing status first
      final prefs = await SharedPreferences.getInstance();
      final familySharedStatus = prefs.getBool('familySharedSubscription') ?? false;

      if (familySharedStatus) {
        print("✅ Family Sharing status found in storage");
        return true;
      }

      // For Flutter with in_app_purchase plugin (StoreKit 1),
      // the best we can do is rely on restorePurchases() and
      // check if subscription status gets updated through the purchase stream

      // Note: This is a limitation of StoreKit 1 via Flutter
      // For better Family Sharing support, consider:
      // 1. Upgrading to StoreKit 2 with native iOS code
      // 2. Server-side receipt validation
      // 3. Using a more advanced Flutter plugin

      return false;
    } catch (e) {
      print("Error checking subscription entitlements: $e");
      return false;
    }
  }

  // Method to mark subscription as family shared (called when we detect family sharing)
  Future<void> _markAsFamilyShared() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('familySharedSubscription', true);
      print("✅ Marked subscription as Family Shared");
    } catch (e) {
      print("Error marking as family shared: $e");
    }
  }

  // Verify previous purchases
  Future<bool> _verifyPreviousPurchases() async {
    try {
      print("Verifying previous purchases...");

      // On iOS, we need to check previous purchases
      final response = await _inAppPurchase.restorePurchases();
      print("Restore purchases completed");

      // The response doesn't actually contain purchases on iOS
      // The purchases come through the purchaseStream listener

      // Wait a moment for purchases to be processed by the listener
      await Future.delayed(const Duration(seconds: 1));

      return _isSubscribed;
    } catch (e) {
      print("Error verifying previous purchases: $e");
      return false;
    }
  }

  // Start the subscription purchase flow
  Future<void> subscribe() async {
    try {
      if (_products.isEmpty) {
        _errorMessage = "No products available to purchase";
        notifyListeners();
        return;
      }

      // Find the monthly subscription product
      final productDetails = _products.firstWhere(
        (product) => product.id == monthlySubscriptionId,
        orElse: () => throw Exception("Monthly subscription product not found"),
      );

      print("Starting purchase for: ${productDetails.id}");

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
      );

      // This is a subscription, so use buyNonConsumable
      final bool success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      if (!success) {
        _errorMessage = "Failed to initiate purchase. Please try again.";
        notifyListeners();
      }
    } catch (e) {
      print("Error starting subscription: $e");
      _errorMessage = "Error starting subscription: $e";
      notifyListeners();
      rethrow; // Rethrow to handle in the UI
    }
  }

  // Listen to purchase updates
  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    print("Purchase update received: ${purchaseDetailsList.length} purchases");

    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      print("Purchase status: ${purchaseDetails.status} for ${purchaseDetails.productID}");

      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show loading UI
        print("Purchase is pending");
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // Handle the error - check for Family Sharing
        print("Purchase error: ${purchaseDetails.error}");

        final errorMessage = purchaseDetails.error?.message?.toLowerCase() ?? '';
        final errorCode = purchaseDetails.error?.code ?? '';

        // Check if this error indicates Family Sharing
        // NOTE: This is a workaround for StoreKit 1 limitations in Flutter
        // For production apps, consider server-side receipt validation
        if (errorMessage.contains('family') || errorMessage.contains('shared') || errorMessage.contains('already purchased') || errorMessage.contains('member') || errorCode.contains('AlreadyOwned')) {
          print("✅ Family Sharing detected - granting access");

          // Grant subscription access through Family Sharing
          _isSubscribed = true;

          // Save subscription status
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isSubscribed', true);

          // Mark as family shared for future checks
          await _markAsFamilyShared();

          // Clear error message since this is actually success
          _errorMessage = null;

          notifyListeners();
        } else {
          // This is a real error
          _errorMessage = "Purchase error: ${purchaseDetails.error?.message ?? 'Unknown error'}";
          notifyListeners();
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
        // Check if this is our monthly subscription
        if (purchaseDetails.productID == monthlySubscriptionId) {
          // Skip restored purchases if we're in debug ignore mode
          if (purchaseDetails.status == PurchaseStatus.restored && _debugIgnoreRestoredPurchases) {
            print("🧪 DEBUG: Ignoring restored purchase for testing");
            return;
          }
          // Validate the purchase
          await _handleValidPurchase(purchaseDetails);
        }
      }

      // Complete the purchase - important!
      if (purchaseDetails.pendingCompletePurchase) {
        print("Completing purchase for ${purchaseDetails.productID}");
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  // Handle a valid purchase
  Future<void> _handleValidPurchase(PurchaseDetails purchaseDetails) async {
    try {
      print("Handling valid purchase for ${purchaseDetails.productID}");

      // For a real app, you might want to do additional validation here
      // For example, checking with Apple's server to verify the receipt

      // Set subscription status
      _isSubscribed = true;

      // Save subscription status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isSubscribed', true);

      print("Subscription activated");

      // Clear any error message
      _errorMessage = null;

      notifyListeners();
    } catch (e) {
      print("Error handling purchase: $e");
      _errorMessage = "Error processing purchase: $e";
      notifyListeners();
    }
  }

  // Developer testing methods - completely reset subscription state
  Future<void> resetSubscriptionForTesting() async {
    try {
      print("🧪 DEBUG: Resetting subscription for testing...");

      // 1. Enable debug mode to ignore restored purchases
      _debugIgnoreRestoredPurchases = true;

      // 2. Reset local subscription state
      _isSubscribed = false;
      _errorMessage = null;

      // 3. Clear persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isSubscribed');
      await prefs.remove('familySharedSubscription'); // Clear family sharing status too
      await prefs.clear(); // Clear all preferences for thorough reset

      print("🧪 DEBUG: Subscription state reset complete");
      print("🧪 DEBUG: isSubscribed = $_isSubscribed");
      print("🧪 DEBUG: Debug ignore mode enabled = $_debugIgnoreRestoredPurchases");

      // 4. Notify listeners to update UI
      notifyListeners();

      // 5. Small delay to ensure state is fully reset
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print("🧪 DEBUG: Error resetting subscription: $e");
      _errorMessage = "Debug reset error: $e";
      notifyListeners();
    }
  }

  // Force re-check subscription status (useful after reset)
  Future<void> forceRefreshSubscriptionStatus() async {
    try {
      print("🧪 DEBUG: Force refreshing subscription status...");
      print("🧪 DEBUG: Debug ignore mode = $_debugIgnoreRestoredPurchases");

      // Reset state first
      _isSubscribed = false;

      // Check with Apple again (will ignore restored purchases if debug flag is set)
      await checkSubscriptionStatus();

      print("🧪 DEBUG: Force refresh complete, isSubscribed = $_isSubscribed");
    } catch (e) {
      print("🧪 DEBUG: Error force refreshing: $e");
    }
  }

  // Re-enable normal subscription checking (turn off debug mode)
  Future<void> enableNormalSubscriptionChecking() async {
    print("🧪 DEBUG: Re-enabling normal subscription checking...");
    _debugIgnoreRestoredPurchases = false;
    await checkSubscriptionStatus();
    print("🧪 DEBUG: Normal subscription checking restored, isSubscribed = $_isSubscribed");
  }

  // Debug method to temporarily bypass subscription validation
  Future<void> debugSkipSubscription() async {
    try {
      print("🧪 DEBUG: Bypassing subscription validation for testing...");
      print("🧪 DEBUG: This does NOT affect production subscription logic!");

      // Set debug bypass flag (does NOT modify production SharedPreferences)
      _debugBypassActive = true;

      // Update UI state for debug mode
      _isSubscribed = true;

      // Clear any existing error messages
      _errorMessage = null;

      print("🧪 DEBUG: Debug bypass activated - isSubscribed = $_isSubscribed");
      print("🧪 DEBUG: Production subscription validation remains unchanged");

      // Notify listeners to update UI
      notifyListeners();
    } catch (e) {
      print("🧪 DEBUG: Error activating debug bypass: $e");
      _errorMessage = "Debug bypass error: $e";
      notifyListeners();
      rethrow;
    }
  }

  // Debug method to clear debug bypass and restore normal subscription checking
  Future<void> debugClearBypass() async {
    try {
      print("🧪 DEBUG: Clearing debug bypass - restoring normal subscription validation...");

      // Clear debug bypass flag
      _debugBypassActive = false;

      // Clear error messages
      _errorMessage = null;

      // Re-check actual subscription status from production logic
      await checkSubscriptionStatus();

      print("🧪 DEBUG: Debug bypass cleared - normal subscription checking restored");
      print("🧪 DEBUG: Current subscription status: $_isSubscribed");
    } catch (e) {
      print("🧪 DEBUG: Error clearing debug bypass: $e");
      _errorMessage = "Error clearing debug bypass: $e";
      notifyListeners();
    }
  }

  // Debug method to check if bypass is currently active
  bool get isDebugBypassActive => _debugBypassActive;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
