import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:marispeaks/screens/IAPs/Controller/iAPController.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';


class SubscriptionPage extends StatefulWidget {
  @override
  State<SubscriptionPage> createState() => SubscriptionPageState();
}

class SubscriptionPageState extends State<SubscriptionPage> {
  int _currentPage = 0;

  final IAPControllers iapController = Get.put(IAPControllers());

  @override
  void initState() {
    super.initState();
  }

 
@override
Widget build(BuildContext context) {
  if (iapController.purchasePending.value) {
    return const Center(child: CircularProgressIndicator());
  }

  return Scaffold(
    backgroundColor: const Color(0xFFDAF4FF),
    body: GetBuilder<IAPControllers>(
      builder: (controller) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            children: [
              const SizedBox(height: 35),
              Row(
                children: [
                  const BackButton(),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Pick a Subscription",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const Opacity(opacity: 0, child: BackButton()),
                ],
              ),
              const SizedBox(height: 10),

              /// Toggle Image
              Center(
                child: Image.asset(
                  _currentPage == 1
                      ? 'assets/maris/monthly.png'
                      : 'assets/maris/yearly.png',
                  width: 180,
                  height: 50,
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 16),
              

              /// Label and Swipe Hint
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text("Select a plan"),
                  Row(
                    children: [
                      Text("Swipe"),
                      Icon(Icons.arrow_forward_ios, size: 14),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              /// PageView
              Expanded(
                child: PageView(
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                      print("Current page: $_currentPage");
                    });
                  },
                  children: [
  _buildPlanCard(
  title: "Free Plan",
  planKey: "free",
  price: "\$0",
  priceSuffix: "/Year",
  description: "Subject to daily usage limits. Limits reset every 24 hours.",
  includedFeatures: 7,
  totalFeatures: 7,
  buttonColor: Colors.blue,
  badge: null,
  featuresList: [
    "Basic Map with OpenStreetMap",
    "Basic Messenger (Audio/Vid & Chat)",
    "Push-to-Talk — 5 uses / day",
    "AI Voice Assistant — 5 queries / day",
    "Weather Forecast — Standard access",
    "Chart Plotter — 20 minutes / day",
    "P2P Map Contacts — Limited range",
    "Sea Depths — 30 minutes / day",
  ],
  allFeatures: [
    "Basic Map with OpenStreetMap",
    "Basic Messenger (Audio/Vid & Chat)",
    "Push-to-Talk — 5 uses / day",
    "AI Voice Assistant — 5 queries / day",
    "Weather Forecast — Standard access",
    "Chart Plotter — 20 minutes / day",
    "P2P Map Contacts — Limited range",
    "Sea Depths — 30 minutes / day",
  ],
  isFreePlan: true,
  selectedPlanKey: controller.selectedPlanKey,
  iapController: controller,
),
                    _buildPlanCard(
                      title: "Monthly plan",
                      planKey: "monthly",
                      price: "\$14.99",
                      priceSuffix: "/Month",
                      description:
                          "Enjoy complete access to Marispeak Premium features for a monthly subscription.",
                      includedFeatures: 7,
                      totalFeatures: 7,
                      buttonColor: Colors.blue,
                      badge: "Save 20% on Yearly",
                      featuresList: [
                        "Map with OpenStreetMap",
                        "Messenger (Audio/Vid & Chat)",
                        "Push-to-Talk — Unlimited",
                        "AI Voice Assistant — Unlimited",
                        "Weather Forecast — Full access",
                        "Chart Plotter — Unlimited usage",
                        "P2P Map Contacts — Extended range",
                        "Sea Depths — Unlimited",
                      ],
                      allFeatures: [
                        "Map with OpenStreetMap",
                        "Messenger (Audio/Vid & Chat)",
                        "Push-to-Talk — Unlimited",
                        "AI Voice Assistant — Unlimited",
                        "Weather Forecast — Full access",
                        "Chart Plotter — Unlimited usage",
                        "P2P Map Contacts — Extended range",
                        "Sea Depths — Unlimited",
                      ],
                      isFreePlan: false,
                      selectedPlanKey: controller.selectedPlanKey,
                      iapController: controller,
                    ),
                    _buildPlanCard(
                      title: "Yearly plan",
                      planKey: "yearly",
                      price: "\$99.00",
                      priceSuffix: "/Year",
                      description:
                          "Enjoy complete access to Marispeak Premium features for a yearly subscription.",
                      includedFeatures: 5,
                      totalFeatures: 5,
                      buttonColor: Colors.blue,
                      badge: "BEST PLAN",
                      featuresList: [
                        "Map with OpenStreetMap",
                        "Messenger (Audio/Vid & Chat)",
                        "Push-to-Talk — Unlimited",
                        "AI Voice Assistant — Unlimited",
                        "Weather Forecast — Full access",
                        "Chart Plotter — Unlimited usage",
                        "P2P Map Contacts — Extended range",
                        "Sea Depths — Unlimited",
                      ],
                      allFeatures: [
                        "Map with OpenStreetMap",
                        "Messenger (Audio/Vid & Chat)",
                        "Push-to-Talk — Unlimited",
                        "AI Voice Assistant — Unlimited",
                        "Weather Forecast — Full access",
                        "Chart Plotter — Unlimited usage",
                        "P2P Map Contacts — Extended range",
                        "Sea Depths — Unlimited",
                      ],
                      isFreePlan: false,
                      selectedPlanKey: controller.selectedPlanKey,
                      iapController: controller,
                    ),
                  ],
                ),
              ),

              /// Terms and Privacy
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      _launchURL('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/');
                    },
                    child: const Text("Terms of Use"),
                  ),
                  TextButton(
                    onPressed: () {
                      _launchURL('https://www.marispeak.com/privacy-policy');
                    },
                    child: const Text("Privacy Policy"),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        "Auto-renews unless canceled 24h before. Manage in Apple ID settings.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () async {
                      controller.restorePurchases();
                    },
                    child: Text(
                      "Restore Purchase",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }


Widget _buildPlanCard({
  required String title,
  required String planKey,
  required String price,
  required String priceSuffix,
  required String description,
  required int includedFeatures,
  required int totalFeatures,
  required Color buttonColor,
  String? badge,
  required List<String> featuresList,
  required List<String> allFeatures,
  bool isFreePlan = false,
  required String selectedPlanKey,
  required IAPControllers iapController,
}) {
  final isSelected = selectedPlanKey == planKey;

  return Container(
    margin: EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.blue, width: 2),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                  //  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    RichText(
  text: TextSpan(
    children: [
      TextSpan(
        text: title.contains('—') ? title.split('—')[0].trim() : title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      if (title.contains('—'))
        TextSpan(
          text: ' — ${title.split('—')[1].trim()}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: Colors.grey[600],
          ),
        ),
    ],
  ),
),
                    Spacer(),
                    if (badge != null)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badge == "BEST PLAN" ? Colors.blue : Colors.lightBlueAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 16),
                RichText(
                  text: TextSpan(
                    text: price,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                    children: [
                      TextSpan(
                        text: ' $priceSuffix',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                Text(description, style: TextStyle(color: Colors.grey[700])),
                SizedBox(height: 16),
                Text("What's Included", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 8),

                // Features with limitation text after '—' in grey
                ...featuresList.map((feature) {
                  List<String> parts = feature.split('—');
                  String mainText = parts[0].trim();
                  String limitationText = parts.length > 1 ? ' — ${parts[1].trim()}' : '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Flexible(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: mainText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                ),
                                TextSpan(
                                  text: limitationText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: isSelected
                ? null
                : () {
                    if (planKey == "free") {
                      iapController.saveSelectedPlan(planKey);
                      _setSubscribed(false);
                    } else if (planKey == "monthly") {
                      FirebaseAnalytics.instance.logEvent(
                        name: "UserTrySubscribeMonthly",
                        parameters: {"screen": "IAPPage", "type": "Monthly_button"},
                      );
                      iapController.buyProduct('monthly_subscription');
                    } else if (planKey == "yearly") {
                      FirebaseAnalytics.instance.logEvent(
                        name: "UserTrySubscribeYearly",
                        parameters: {"screen": "IAPPage", "type": "Yearly_button"},
                      );
                      iapController.buyProduct('yearly_subscription');
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: isSelected ? Colors.grey : buttonColor,
              minimumSize: Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isSelected ? "Selected" : "Select This Plan",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}
  
  Future<void> _setSubscribed(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_subscribed', value);
    
  }
}
