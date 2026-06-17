import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:marispeaks/helpers/settings_provider.dart';
import 'package:marispeaks/screens/IAPs/SubscriptionPage.dart';
import 'package:marispeaks/screens/about/help.dart';
import 'package:marispeaks/screens/home/CustomBottomSection.dart';
import 'package:marispeaks/screens/home/MainScreenUI.dart';
import 'package:marispeaks/controllers/preferences_controller.dart';
import 'package:marispeaks/screens/ptt/agora_controller.dart';
import 'package:marispeaks/theme/app_theme.dart';
import 'package:marispeaks/config/theme_config.dart';

class MoreSettings extends StatefulWidget {
  @override
  _MoreSettingsState createState() => _MoreSettingsState();
}

class _MoreSettingsState extends State<MoreSettings> {
  static const double MAX_USER_RANGE = 50; // km limit for unsubscribed
  static const double MAX_AIS_RANGE = 50;

  String phoneNumber = "0";

  // AIS Range
  double _aisRange = 20;
  int _aisRangeIndex = 0;

  // User Range
  double _userRange = 10;
  int _userRangeIndex = 0;

  bool _isSubscribed = false;

  final List<double> _freeSliderValues = [
    10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 120, 150, 180, 200, 250, 300
  ];

  final List<double> _paidSliderValues = [
    10, 50, 100, 200, 300, 400, 500, 600, 800, 1000, 1200, 1500, 2000, 3000, 4000, 5000
  ];

  final AgoraController agoraController = AgoraController();
  final PreferencesController prefController = Get.find();

  final List<String> _formats = ["Km/h", "Mph", "M/s", "Knots"];
  final List<String> Wind_formats = ["m/s", "mph", "km/h", "knots"];
  final List<String> Range_formats = ["Km's", "Miles", "Nautical Miles"];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settings = Provider.of<SettingsProvider>(context, listen: false);

      if (settings.speedFormat.isEmpty) settings.setSpeedFormat(_formats.first);
      if (settings.windFormat.isEmpty) settings.setWindFormat(Wind_formats.first);
      if (settings.RangeFormat.isEmpty) settings.setRangeFormat(Range_formats.first);

      phoneNumber = customBottomSection.currentState?.userPhoneNumber ?? "0";

      await checkSubscription();
      loadAisRange(settings);
      loadUserRange(settings);

      setState(() {});
    });
  }

Future<void> checkSubscription() async {
  bool subscribed =
      await customBottomSection.currentState?.isSubscribed() ?? false;

  final settings = Provider.of<SettingsProvider>(context, listen: false);

  if (!subscribed) {
    final double minFreeValue = _freeSliderValues.first; // e.g. 10 km

    // ---- AIS RANGE ----
    if (settings.aisRange > MAX_AIS_RANGE) {
      _aisRange = minFreeValue;
      _aisRangeIndex = 0;
      settings.setAisRange(minFreeValue);
    } else {
      _aisRange = settings.aisRange;
      _aisRangeIndex = nearestIndex(_freeSliderValues, _aisRange);
    }

    // ---- USER RANGE ----
    if (settings.userRange > MAX_USER_RANGE) {
      _userRange = minFreeValue;
      _userRangeIndex = 0;
      settings.setUserRange(minFreeValue);
    } else {
      _userRange = settings.userRange;
      _userRangeIndex = nearestIndex(_freeSliderValues, _userRange);
    }
  }

  setState(() => _isSubscribed = subscribed);
}

  void loadAisRange(SettingsProvider settings) {
    double savedValue = settings.aisRange > 0 ? settings.aisRange : 20;
    _aisRange = savedValue;

    List<double> ticks = _isSubscribed ? _paidSliderValues : _freeSliderValues;
    _aisRangeIndex = nearestIndex(ticks, savedValue);
  }

  void loadUserRange(SettingsProvider settings) {
    double savedValue = settings.userRange > 0 ? settings.userRange : 10;
    _userRange = savedValue;

    List<double> ticks = _isSubscribed ? _paidSliderValues : _freeSliderValues;
    _userRangeIndex = nearestIndex(ticks, savedValue);
  }

  int nearestIndex(List<double> ticks, double value) {
    int idx = 0;
    double minDiff = double.infinity;
    for (int i = 0; i < ticks.length; i++) {
      double diff = (ticks[i] - value).abs();
      if (diff < minDiff) {
        minDiff = diff;
        idx = i;
      }
    }
    return idx;
  }

  void _showLimitPopup(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final bool isDarkMode = AppTheme.of(context).isDarkMode;
    final Color? iconColor = isDarkMode ? primaryColor : null;

    String _selectedFormat = settings.speedFormat;
    String Wind_selectedFormat = settings.windFormat;
    String Range_selectedFormat = settings.RangeFormat;

    return WillPopScope(
      onWillPop: () async {
        mainScreenKey.currentState?.listenForUserLocations();
        return true;
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            automaticallyImplyLeading: false,
            flexibleSpace: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  Theme.of(context).brightness == Brightness.dark
                      ? "assets/maris/Rectangle_red_dark.png"
                      : "assets/maris/Rectangle_red.png",
                  fit: BoxFit.fill,
                ),
              ],
            ),
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Image.asset(
                "assets/maris/marispeakback.png",
                width: 30,
                height: 30,
              ),
            ),
            title: const Text(
              "Settings",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.black),
          ),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Account info
              SizedBox(
                width: double.infinity,
                height: 40,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Image.asset(
                      "assets/maris/grey_seprator.png",
                      width: double.infinity,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 2),
                      child: Text(
                        "Account: $phoneNumber",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 46, 46, 46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Subscription Section
              GestureDetector(
               onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SubscriptionPage()),
                    );

                    await checkSubscription();

                    final settings = Provider.of<SettingsProvider>(context, listen: false);
                    loadAisRange(settings);
                    loadUserRange(settings);

                    setState(() {});
                  },
                child: Container(
                  width: double.infinity,
                  height: 70,
                  padding: const EdgeInsets.only(left: 12, right: 12, top: 15),
                  child: Row(
                    children: [
                      Image.asset(
                        "assets/maris/diamond.png",
                        width: 30,
                        height: 30,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Your Marispeak Subscription",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Explore and manage your subscription",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color.fromARGB(255, 101, 101, 101),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Image.asset(
                        "assets/maris/marispeakopen.png",
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),

              // Offer banner
              GestureDetector(
               onTap: () async {
                    await Get.to(() => SubscriptionPage(), arguments: 2);

                    await checkSubscription();

                    final settings = Provider.of<SettingsProvider>(context, listen: false);
                    loadAisRange(settings);
                    loadUserRange(settings);

                    setState(() {});
                  },
                child: Container(
                  width: double.infinity,
                  height: 80,
                  child: Image.asset(
                    "assets/maris/offer.png",
                    width: double.infinity,
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Saved Trackers
              GestureDetector(
                onTap: () => customBottomSection.currentState?.showSavedTrackersDialog(context),
                child: Container(
                  width: double.infinity,
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: Row(
                    children: [
                      Image.asset(
                        "assets/maris/saved.png",
                        width: 30,
                        height: 30,
                      ),
                      const SizedBox(width: 15),
                      const Expanded(
                        child: Text(
                          "Saved Trackers",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Image.asset(
                        "assets/maris/marispeakopen.png",
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(thickness: 0.5, color: Colors.grey),

              // Tracker Live Track
              GestureDetector(
                onTap: () async {
                  bool hasAccess = await customBottomSection.currentState?.isSubscribed() ?? false;
                  if (hasAccess) {
                    customBottomSection.currentState?.showTrackerInputDialog(context);
                  } else {
                    mainScreenKey.currentState?.showSalePopup(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('This feature is for subscribed users only.')),
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: Row(
                    children: [
                      Image.asset(
                        "assets/maris/tracker_icon.png",
                        width: 30,
                        height: 30,
                      ),
                      const SizedBox(width: 15),
                      const Expanded(
                        child: Text(
                          "Tracker Live Track",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Image.asset(
                        "assets/maris/marispeakopen.png",
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(thickness: 0.5, color: Colors.grey),

              // --- AIS Slider ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: Row(
                  children: [
                    const Text("AIS Range", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    SizedBox(
                      width: 250,
                      child: Row(
                        children: [
                          Expanded(
                            child: Slider(
                              min: 0,
                              max: (_isSubscribed
                                      ? _paidSliderValues.length - 1
                                      : _freeSliderValues.length - 1)
                                  .toDouble(),
                              divisions: (_isSubscribed
                                      ? _paidSliderValues.length - 1
                                      : _freeSliderValues.length - 1),
                              value: _aisRangeIndex.toDouble(),
                              label:
                                  "${_isSubscribed ? _paidSliderValues[_aisRangeIndex].toStringAsFixed(0) : _freeSliderValues[_aisRangeIndex].toStringAsFixed(0)} km",
                              onChanged: (index) {
                                int idx = index.round();
                                double value =
                                    _isSubscribed ? _paidSliderValues[idx] : _freeSliderValues[idx];

                                if (!_isSubscribed && value > MAX_AIS_RANGE) {
                                  mainScreenKey.currentState?.showSalePopup(context);
                                  return;
                                }

                                setState(() {
                                  _aisRangeIndex = idx;
                                  _aisRange = value;
                                });

                                settings.setAisRange(_aisRange);
                              },
                            ),
                          ),
                          Text(_aisRange.toStringAsFixed(0)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(thickness: 0.5, color: Colors.grey),

              // --- User Slider ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: Row(
                  children: [
                    const Text("Users Range", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    SizedBox(
                      width: 250,
                      child: Row(
                        children: [
                          Expanded(
                            child: Slider(
                              min: 0,
                              max: (_isSubscribed
                                      ? _paidSliderValues.length - 1
                                      : _freeSliderValues.length - 1)
                                  .toDouble(),
                              divisions: (_isSubscribed
                                      ? _paidSliderValues.length - 1
                                      : _freeSliderValues.length - 1),
                              value: _userRangeIndex.toDouble(),
                              label: (_isSubscribed
                                      ? _paidSliderValues[_userRangeIndex]
                                      : _freeSliderValues[_userRangeIndex])
                                  .toStringAsFixed(0) + " km",
                              onChanged: (index) {
                                int idx = index.round();
                                double value =
                                    _isSubscribed ? _paidSliderValues[idx] : _freeSliderValues[idx];

                                if (!_isSubscribed && value > MAX_USER_RANGE) {
                                  mainScreenKey.currentState?.showSalePopup(context);
                                  return;
                                }

                                setState(() {
                                  _userRangeIndex = idx;
                                  _userRange = value;
                                });

                                settings.setUserRange(_userRange);
                              },
                            ),
                          ),
                          Text(_userRange.toStringAsFixed(0)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(thickness: 0.5, color: Colors.grey),

              // --- Speed Format ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Speed", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        alignment: WrapAlignment.end,
                        children: _formats.map((format) {
                          final isSelected = _selectedFormat == format;
                          return ChoiceChip(
                            label: Text(
                              format,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: iconColor,
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            showCheckmark: false,
                            onSelected: (_) {
                              setState(() {
                                settings.setSpeedFormat(format);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(thickness: 0.5, color: Colors.grey),

              // --- Wind Format ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Wind Speed", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        alignment: WrapAlignment.end,
                        children: Wind_formats.map((format) {
                          final isSelected = Wind_selectedFormat == format;
                          return ChoiceChip(
                            label: Text(
                              format,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: iconColor,
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            showCheckmark: false,
                            onSelected: (_) {
                              setState(() {
                                settings.setWindFormat(format);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(thickness: 0.5, color: Colors.grey),

              // --- Range Format ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Range Format", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          children: Range_formats.map((format) {
                            final isSelected = Range_selectedFormat == format;
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: ChoiceChip(
                                label: Text(
                                  format,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected ? Colors.white : Colors.black,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: iconColor,
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                showCheckmark: false,
                                onSelected: (_) {
                                  setState(() {
                                    settings.setRangeFormat(format);
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 50), // bottom spacing
            ],
          ),
        ),
      ),
    );
  }
}