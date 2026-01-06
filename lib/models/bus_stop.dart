import 'package:latlong2/latlong.dart';

class BusStop {
  final LatLng position;
  final String direction; // up, down, left, right

  BusStop({
    required this.position,
    required this.direction,
  });
}