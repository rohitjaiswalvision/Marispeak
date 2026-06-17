import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:marispeaks/screens/IAPs/SubscriptionPage.dart';
import 'package:marispeaks/screens/home/CustomBottomSection.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IAPControllers extends GetxController {
  final InAppPurchase _iap = InAppPurchase.instance;
  final RxList<ProductDetails> products = <ProductDetails>[].obs;
  final RxBool isAvailable = false.obs;
  final RxBool purchasePending = false.obs;
   String selectedPlanKey = "free";

  final List<String> _productIds = ['monthly_subscription', 'yearly_subscription'];

  @override
  void onInit() {
    super.onInit();
    initialize();
  }
 
   
  Future<void> saveSelectedPlan(String key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_plan', key);
    selectedPlanKey = key;
    update(); // Notify GetBuilder widgets
  }

  Future<void> loadSelectedPlan() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    selectedPlanKey = prefs.getString('selected_plan') ?? "free";
    update(); // Notify UI
  }

void initialize() async {
  final available = await _iap.isAvailable();
  isAvailable.value = available;
  print("IAP Available: $available");
  loadSelectedPlan();


  if (!available) {
    Get.snackbar("IAP Not Available", "In-App Purchases are not available on this device.");
    return;
  }

  ProductDetailsResponse response = await _iap.queryProductDetails(_productIds.toSet());

  if (response.notFoundIDs.isNotEmpty) {
    print("❌ Missing products: ${response.notFoundIDs}");
    Get.snackbar(
      "Missing Products",
      "Products not found: ${response.notFoundIDs.join(', ')}",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFB00020),
      colorText: const Color(0xFFFFFFFF),
    );
  }

  if (response.productDetails.isEmpty) {
    print("⚠️ No valid products returned.");
    Get.snackbar("No Products", "No available IAP products were found.");
  } else {
    print("✅ Loaded Products:");
    for (var product in response.productDetails) {
      print("🔹 ID: ${product.id}, Title: ${product.title}, Price: ${product.price}");
    }
  }

  products.value = response.productDetails;

  _iap.purchaseStream.listen(_listenToPurchaseUpdated, onDone: () {
    print("Purchase Stream Done");
  }, onError: (error) {
    print("Purchase Stream Error: $error");
  });
}


 void buyProduct(String productId) {
  print("🛒 Attempting to buy: $productId");

  purchasePending.value = true; // Start loading
print("Available products:");
for (var p in products) {
  print("🔹 ID: '${p.id}'");
}
print("Looking for ID: '$productId'");

  final productDetails = products.firstWhereOrNull((p) => p.id == productId);
  if (productDetails != null) {
    print("✅ Product found, launching purchase");
    final purchaseParam = PurchaseParam(productDetails: productDetails);
    _iap.buyNonConsumable(purchaseParam: purchaseParam);
  } else {
    print("❌ Product not found: $productId");
  }

  
  purchasePending.value = false; // Stop loading
}


  Future<void> _setSubscribed(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_subscribed', value);
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
        }
        // ✅ Grant access and store locally
        print("Purchase success: ${purchase.productID}");
        _onSuccessfulPurchase(purchase.productID);
      }
    }
  }


Future<void> restorePurchases() async {
  print("🔄 Attempting to restore purchases...");
  try {
    final bool available = await _iap.isAvailable();
    if (!available) {
      Get.snackbar("Unavailable", "In-App Purchases are not available on this device.");
      return;
    }

    purchasePending.value = true;

    await _iap.restorePurchases(); // This triggers _listenToPurchaseUpdated()
    print("🔁 Restore initiated.");
  } catch (e) {
    Get.snackbar("Restore Failed", e.toString());
  } finally {
    purchasePending.value = false;
    Get.snackbar("Restore Purchase:", "Success");

  }
}

 

  void _onSuccessfulPurchase(String productId) async {
    final plan = productId.contains("monthly") ? "monthly" : "yearly";
    print("Selected plan: $plan");
   // Get.snackbar("Success", "You've successfully subscribed!");
    FirebaseAnalytics.instance.logEvent(
                          name: productId,
                          parameters: {
                            "screen": "PurchasedSuccess",
                            "type": "Subscription"
                          },
                        );
    _setSubscribed(true);
    saveSelectedPlan(plan);
    customBottomSection.currentState?.PttInit();
    loadSelectedPlan();
  //  await SubscriptionPageState().saveSelectedPlan(plan);
  //   await SubscriptionPageState().loadSelectedPlan();
  }
}
