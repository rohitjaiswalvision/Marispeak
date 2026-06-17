// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/cupertino.dart';

class Weather with ChangeNotifier {
  final double temp;
  final double tempMax;
  final double tempMin;
  final double lat;
  final double long;
  final double feelsLike;
  final int pressure;
  final String description;
  final String weatherCategory;
  final int humidity;
  final double windSpeed;
  String city;
  final String countryCode;

  Weather({
    required this.temp,
    required this.tempMax,
    required this.tempMin,
    required this.lat,
    required this.long,
    required this.feelsLike,
    required this.pressure,
    required this.description,
    required this.weatherCategory,
    required this.humidity,
    required this.windSpeed,
    required this.city,
    required this.countryCode,
  });

  factory Weather.fromOneCall(Map<String, dynamic> json, {
  required String city,
  required String countryCode,
}) {
  final current = json['current'];
  if (current == null || current['weather'] == null || current['weather'].isEmpty) {
    print("Error: No 'current' weather data found.");
    print("City: $city, Country: $countryCode"); // Debugging line to check the city and country values
    return Weather(
      temp: 0.0,
      tempMax: 0.0,
      tempMin: 0.0,
      lat: json['lat'] ?? 0.0,
      long: json['lon'] ?? 0.0,
      feelsLike: 0.0,
      pressure: 0,
      description: "Unknown",
      weatherCategory: "Unknown",
      humidity: 0,
      windSpeed: 0.0,
      city: city,
      countryCode: countryCode,
    );
  }

  final dailyData = json['daily'];
  final dailyTemp = dailyData != null && dailyData.isNotEmpty ? dailyData[0]['temp'] : null;

  print("Weather fetched for: $city, $countryCode"); // Debugging line to check city and country

  return Weather(
    temp: (current['temp'] ?? 0.0).toDouble(),
    tempMax: (dailyTemp?['max'] ?? 0.0).toDouble(),
    tempMin: (dailyTemp?['min'] ?? 0.0).toDouble(),
    lat: json['lat'] ?? 0.0,
    long: json['lon'] ?? 0.0,
    feelsLike: (current['feels_like'] ?? 0.0).toDouble(),
    pressure: current['pressure'] ?? 0,
    weatherCategory: current['weather']?[0]['main'] ?? 'Unknown',
    description: current['weather']?[0]['description'] ?? 'No description available',
    humidity: current['humidity'] ?? 0,
    windSpeed: (current['wind_speed'] ?? 0.0).toDouble(),
    city: city,
    countryCode: countryCode,
  );
}


}
