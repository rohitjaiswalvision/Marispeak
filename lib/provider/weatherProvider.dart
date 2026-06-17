import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:marispeaks/helpers/settings_provider.dart';
import 'package:marispeaks/models/additionalWeatherData.dart';
import 'package:marispeaks/models/geocode.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import '../models/dailyWeather.dart';
import '../models/hourlyWeather.dart';
import '../models/weather.dart';

class WeatherProvider with ChangeNotifier {
  String apiKey = '6a4381e12731aa8d38731d8994505143';
  late Weather weather;
  late AdditionalWeatherData additionalWeatherData = AdditionalWeatherData(
    precipitation: '0',
    uvi: 0.0,
    clouds: 0,
  );
  LatLng? currentLocation;
  List<HourlyWeather> hourlyWeather = [];
  List<DailyWeather> dailyWeather = [];
  bool isLoading = false;
  bool isRequestError = false;
  bool isSearchError = false;
  bool isLocationserviceEnabled = false;
  LocationPermission? locationPermission;
  bool isCelsius = true;
 double? _latitude;
  double? _longitude;

  double get latitude => _latitude ?? 0.0;
  double get longitude => _longitude ?? 0.0;

  void updateLocation(double lat, double lon) {
    _latitude = lat;
    _longitude = lon;
    notifyListeners();
  }
  
  String get measurementUnit => isCelsius ? '°C' : '°F';

  Future<Position?> requestLocation(BuildContext context) async {
    isLocationserviceEnabled = await Geolocator.isLocationServiceEnabled();
    notifyListeners();

    if (!isLocationserviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location service disabled')),
      );
      return Future.error('Location services are disabled.');
    }

    locationPermission = await Geolocator.checkPermission();
    if (locationPermission == LocationPermission.denied) {
      isLoading = false;
      notifyListeners();
      locationPermission = await Geolocator.requestPermission();
      if (locationPermission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Permission denied'),
        ));
        return Future.error('Location permissions are denied');
      }
    }

    if (locationPermission == LocationPermission.deniedForever) {
      isLoading = false;
      notifyListeners();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Location permissions are permanently denied, Please enable manually from app settings',
        ),
      ));
      return Future.error('Location permissions are permanently denied');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> getWeatherData(
    BuildContext context, {
    bool notify = false,
  }) async {
    isLoading = true;
    isRequestError = false;
    isSearchError = false;
    if (notify) notifyListeners();

    Position? locData = await requestLocation(context);

    if (locData == null) {
      isLoading = false;
      notifyListeners();
      return;
    }

    try {
      currentLocation = LatLng(locData.latitude, locData.longitude);
      await getWeatherFromOneCall(currentLocation!);
    } catch (e) {
      print(e);
      isRequestError = true;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getWeatherFromOneCall(LatLng location) async {
    Uri url = Uri.parse(
      'https://api.openweathermap.org/data/3.0/onecall?lat=${location.latitude}&lon=${location.longitude}&units=metric&exclude=minutely&appid=$apiKey',
    );
    updateLocation(location.latitude, location.longitude);
    try {
      final response = await http.get(url);
      final extractedData = json.decode(response.body) as Map<String, dynamic>;

      // Log the API response
      print('API Response: ${response.body}'); // For debugging

      // Handle error if current data is missing
      if (extractedData['current'] == null) {
        print("Error: No 'current' weather data found.");
        print("DEBUG full JSON: ${jsonEncode(extractedData)}");
        isRequestError = true;
        return;
      }

      // Get the city and country from geocoding
      String city = 'Unknown City';
      String countryCode = 'Unknown Country';

      // Try to use reverse geocoding API to get city and country
      final geocodeData = await locationToLatLng('${location.latitude},${location.longitude}');
      if (geocodeData != null) {
        city = geocodeData.name ?? 'Unknown City';
        countryCode = geocodeData.country ?? 'Unknown Country';
      }

      // Now pass the correct city and countryCode
      weather = Weather.fromOneCall(
        extractedData,
        city: city,
        countryCode: countryCode,
      );
      print('Fetched Weather for: ${weather.city}/${weather.countryCode}');
      
      await getDailyWeather(extractedData);
      await getHourlyWeather(extractedData);
    } catch (error) {
      print(error);
      isRequestError = true;
    }
  }

  Future<void> getDailyWeather(Map<String, dynamic> data) async {
    List dailyList = data['daily'];
    dailyWeather = dailyList
        .map((item) => DailyWeather.fromDailyJson(item))
        .toList();
  }

  Future<void> getHourlyWeather(Map<String, dynamic> data) async {
    List hourlyList = data['hourly'];
    hourlyWeather = hourlyList
        .map((item) => HourlyWeather.fromJson(item))
        .toList()
        .take(24)
        .toList();
  }


Future<GeocodeData?> locationToLatLng(String location) async {
  try {
    print('Requesting geocoding for location: $location');
    
    // Use geocoding to get place details
    List<Location> locations = await locationFromAddress(location);
    
    if (locations.isEmpty) {
      print('Error: No data found for location');
      return null;
    }
    
    // Assuming you want the first result
    Location loc = locations.first;

    // You can extract the city and country from the result
    List<Placemark> placemarks = await placemarkFromCoordinates(loc.latitude, loc.longitude);
    
    if (placemarks.isEmpty) {
      print('Error: No placemarks found for coordinates');
      return null;
    }
    
    // Use the first placemark's details
    Placemark placemark = placemarks.first;
    String city = placemark.locality ?? 'Unknown City';
    String country = placemark.country ?? 'Unknown Country';

    // Return a GeocodeData object with city, country, latitude, and longitude
    return GeocodeData(
      name: city,
      country: country,
      latLng: LatLng(loc.latitude, loc.longitude),
    );
  } catch (e) {
    print('Error during geocoding request: $e');
    return null;
  }
}

  Future<void> searchWeather(String location) async {
    isLoading = true;
    notifyListeners();
    isRequestError = false;
    print('search');
    try {
      GeocodeData? geocodeData;
      geocodeData = await locationToLatLng(location);
      if (geocodeData == null) throw Exception('Unable to Find Location');
      await getWeatherFromOneCall(geocodeData.latLng);
      // replace location name with data from geocode
      // because data from certain lat long might return local area name
      weather.city = geocodeData.name ?? 'Unknown City';
    } catch (e) {
      print(e);
      isSearchError = true;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }


String formatTemp(double tempCelsius) {
  if (isCelsius) {
    return tempCelsius.toStringAsFixed(1);
  } else {
    return ((tempCelsius * 9 / 5) + 32).toStringAsFixed(1);
  }
}

 

 void switchTempUnit(BuildContext context) {
  final settings = Provider.of<SettingsProvider>(context, listen: false);

  // Toggle local state
  isCelsius = !isCelsius;

  // Update SettingsProvider so it persists
  settings.settempUnit(isCelsius ? "C" : "F");

  notifyListeners();
}

}
