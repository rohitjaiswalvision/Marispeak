import 'package:flutter/material.dart';
import 'package:marispeaks/helper/extensions.dart';
import 'package:marispeaks/models/dailyWeather.dart';
import 'package:marispeaks/provider/weatherProvider.dart';
import 'package:marispeaks/theme/colors.dart';
import 'package:marispeaks/theme/textStyle.dart';
import 'package:marispeaks/widgets/customShimmer.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../helper/utils.dart';


class SevenDayForecast extends StatelessWidget {
  Future<void> openWeatherTab(double lat, double lon) async {
    final url = Uri.parse(
        "https://openweathermap.org/weathermap?basemap=map&cities=false&layer=radar&lat=$lat&lon=$lon&zoom=10");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.inAppWebView);
    } else {
      throw 'Could not launch $url';
    }
  }

  

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              PhosphorIcon(PhosphorIconsRegular.calendar),
              const SizedBox(width: 4.0),
              Text(
                '7-Day Forecast',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              Consumer<WeatherProvider>(
               builder: (context, weatherProv, _) {
              return TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  textStyle: mediumText.copyWith(fontSize: 14.0),
                  foregroundColor: const Color.fromARGB(255, 0, 75, 150),
                  side: const BorderSide(color: Colors.red, width: 1.5), // 🔴 Red border
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6), // optional rounded corners
                  ),
                ),
                child: const Text('Click for Weather Map 🌦️🗺️'),
                onPressed: weatherProv.isLoading
                    ? null
                    : () {
                        final lat = weatherProv.latitude;
                        final lon = weatherProv.longitude;
                        openWeatherTab(lat, lon);
                      },
              );
            },

              )
            ],
          ),
        ),
        const SizedBox(height: 8.0),
        Container(
          child: Consumer<WeatherProvider>(
            builder: (context, weatherProv, _) {
              if (weatherProv.isLoading) {
                return ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: 7,
                  itemBuilder: (context, index) => CustomShimmer(
                    height: 82.0,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: weatherProv.dailyWeather.length,
                itemBuilder: (context, index) {
                  final DailyWeather weather = weatherProv.dailyWeather[index];
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.0),
                      color: index.isEven ? backgroundWhite : Colors.white,
                    ),
                    padding: const EdgeInsets.all(12.0),
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: MediaQuery.sizeOf(context).width / 4,
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              index == 0
                                  ? 'Today'
                                  : DateFormat('EEEE').format(weather.date),
                              style: semiboldText,
                              maxLines: 1,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 36.0,
                              width: 36.0,
                              child: Image.asset(
                                getWeatherImage(weather.weatherCategory),
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              weather.weatherCategory,
                              style: lightText,
                            ),
                          ],
                        ),
                        SizedBox(
                          width: MediaQuery.sizeOf(context).width / 5,
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              weatherProv.isCelsius
                                  ? '${weather.tempMax.toStringAsFixed(0)}°/${weather.tempMin.toStringAsFixed(0)}°'
                                  : '${weather.tempMax.toFahrenheit().toStringAsFixed(0)}°/${weather.tempMin.toFahrenheit().toStringAsFixed(0)}°',
                              style: semiboldText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
