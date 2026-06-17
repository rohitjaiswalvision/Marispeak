// lib/screens/home/LatLngPoint.dart

import 'package:hive/hive.dart';

part 'LatLngPoint.g.dart'; // This is where the generated code will go

@HiveType(typeId: 0)
class LatLngPoint {
  @HiveField(0)
  final double latitude;

  @HiveField(1)
  final double longitude;

  LatLngPoint({required this.latitude, required this.longitude});
}
