// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:marispeaks/screens/IAPs/SubscriptionPage.dart';
import 'package:marispeaks/screens/home/CustomBottomSection.dart';
import 'package:marispeaks/screens/locationError.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_floating_search_bar_plus/material_floating_search_bar_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../provider/weatherProvider.dart';
import '../theme/colors.dart';
import '../theme/textStyle.dart';
import '../widgets/WeatherInfoHeader.dart';
import '../widgets/mainWeatherDetail.dart';
import '../widgets/mainWeatherInfo.dart';
import '../widgets/sevenDayForecast.dart';
import '../widgets/twentyFourHourForecast.dart';
import 'requestError.dart';

class HomeScreenWeather extends StatefulWidget {
  const HomeScreenWeather({Key? key}) : super(key: key);

  @override
  State<HomeScreenWeather> createState() => _HomeScreenWeatherState();
}

class _HomeScreenWeatherState extends State<HomeScreenWeather> {
  FloatingSearchBarController fsc = FloatingSearchBarController();

  @override
  void initState() {
    super.initState();
    requestWeather();
  }

  Future<void> requestWeather() async {
    await Provider.of<WeatherProvider>(context, listen: false)
        .getWeatherData(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<WeatherProvider>(
        builder: (context, weatherProv, _) {
          // LOCATION / PERMISSION ERRORS
          if (!weatherProv.isLoading && !weatherProv.isLocationserviceEnabled)
            return LocationServiceErrorDisplay();

          if (!weatherProv.isLoading &&
              weatherProv.locationPermission != LocationPermission.always &&
              weatherProv.locationPermission != LocationPermission.whileInUse) {
            return LocationPermissionErrorDisplay();
          }

          if (weatherProv.isRequestError) return RequestErrorDisplay();

          if (weatherProv.isSearchError) return SearchErrorDisplay(fsc: fsc);

          return Stack(
            children: [
              ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(12.0).copyWith(
                  top: kToolbarHeight +
                      MediaQuery.viewPaddingOf(context).top +
                      24.0,
                ),
                children: [
                  WeatherInfoHeader(),
                  const SizedBox(height: 16.0),

                  // ALWAYS VISIBLE (FREE CONTENT)
                  MainWeatherInfo(),
                  const SizedBox(height: 16.0),

                  // PREMIUM CONTENT CHECK
                  FutureBuilder<bool>(
                    future: customBottomSection.currentState?.isSubscribed(),
                    builder: (context, snapshot) {
                      bool hasAccess = snapshot.data ?? false;

                      if (hasAccess) {
                        // PREMIUM CONTENT
                        return Column(
                          children: [
                            MainWeatherDetail(),
                            SizedBox(height: 24.0),
                            TwentyFourHourForecast(),
                            SizedBox(height: 18.0),
                            SevenDayForecast(),
                          ],
                        );
                      } else {
                        // SHOW UNLOCK PREMIUM BUTTON
                        return UnlockPremiumButton(
                          onUnlock: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => SubscriptionPage()),
                          );
                        },
                        );
                      }
                    },
                  ),
                ],
              ),
              CustomSearchBar(fsc: fsc),
            ],
          );
        },
      ),
    );
  }
}

// ------------------- UNLOCK PREMIUM BUTTON -------------------
class UnlockPremiumButton extends StatelessWidget {
  final VoidCallback? onUnlock;

  const UnlockPremiumButton({Key? key, this.onUnlock}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryBlue, width: 1.5),
      ),
      child: Column(
        children: [
          const Text(
            "Premium Content",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          const Text(
            "Unlock Premium to access detailed weather info",
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 78, 162, 246),
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onUnlock,
            child: const Text(
              "Unlock Premium",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------- CUSTOM SEARCH BAR -------------------
class CustomSearchBar extends StatefulWidget {
  final FloatingSearchBarController fsc;
  const CustomSearchBar({
    Key? key,
    required this.fsc,
  }) : super(key: key);

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  List<String> _citiesSuggestion = [
    'New York',
    'Tokyo',
    'Dubai',
    'London',
    'Singapore',
    'Sydney',
    'Wellington'
  ];

  @override
  Widget build(BuildContext context) {
    return FloatingSearchBar(
      controller: widget.fsc,
      hint: 'Search...',
      clearQueryOnClose: false,
      scrollPadding: const EdgeInsets.only(top: 16.0, bottom: 56.0),
      transitionDuration: const Duration(milliseconds: 400),
      borderRadius: BorderRadius.circular(16.0),
      transitionCurve: Curves.easeInOut,
      accentColor: primaryBlue,
      hintStyle: regularText,
      queryStyle: regularText,
      physics: const BouncingScrollPhysics(),
      elevation: 2.0,
      debounceDelay: const Duration(milliseconds: 500),
      onQueryChanged: (query) {},
      onSubmitted: (query) async {
        widget.fsc.close();
        await Provider.of<WeatherProvider>(context, listen: false)
            .searchWeather(query);
      },
      transition: CircularFloatingSearchBarTransition(),
      actions: [
        FloatingSearchBarAction(
          showIfOpened: false,
          child: PhosphorIcon(
            PhosphorIconsBold.magnifyingGlass,
            color: primaryBlue,
          ),
        ),
        FloatingSearchBarAction.icon(
          showIfClosed: false,
          showIfOpened: true,
          icon: PhosphorIcon(
            PhosphorIconsBold.x,
            color: primaryBlue,
          ),
          onTap: () {
            if (widget.fsc.query.isEmpty) {
              widget.fsc.close();
            } else {
              widget.fsc.clear();
            }
          },
        ),
      ],
      builder: (context, transition) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Material(
            color: Colors.white,
            elevation: 4.0,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: _citiesSuggestion.length,
              itemBuilder: (context, index) {
                String data = _citiesSuggestion[index];
                return InkWell(
                  onTap: () async {
                    widget.fsc.query = data;
                    widget.fsc.close();
                    await Provider.of<WeatherProvider>(context, listen: false)
                        .searchWeather(data);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(22.0),
                    child: Row(
                      children: [
                        PhosphorIcon(PhosphorIconsFill.mapPin),
                        const SizedBox(width: 22.0),
                        Text(data, style: mediumText),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) => const Divider(
                thickness: 1.0,
                height: 0.0,
              ),
            ),
          ),
        );
      },
    );
  }
}
