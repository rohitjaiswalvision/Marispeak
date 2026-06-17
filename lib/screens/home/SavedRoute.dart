import 'package:hive/hive.dart';
import 'LatLngPoint.dart';

part 'SavedRoute.g.dart';

@HiveType(typeId: 1)
class SavedRoute extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<LatLngPoint> points;

  @HiveField(2)
  DateTime dateTime;  // new field

  @HiveField(3)
  double distance;    // new field

  SavedRoute({
    required this.name,
    required this.points,
    required this.dateTime,
    required this.distance,
  });
}
