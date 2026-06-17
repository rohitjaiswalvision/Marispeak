// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:latlong2/latlong.dart';

class GeocodeData {
  String name;
  String country; // Add this line
  LatLng latLng;

  GeocodeData({
    required this.name,
    required this.country, // Initialize country in the constructor
    required this.latLng,
  });

  factory GeocodeData.fromJson(Map<String, dynamic> json) {
    return GeocodeData(
      name: json['name'],
      country: json['country'], // Get country from API response
      latLng: LatLng(json['lat'], json['lon']),
    );
  }
}
