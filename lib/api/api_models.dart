import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class Vehicle {
  final String id;
  final double lat;
  final double lon;
  final double bearing;
  final String? tripId;
  final String? routeId;
  final String? routeShortName;
  final Color? routeColor;
  final String? headsign;
  final String? nextStopId;
  final String? nextStopName;
  final int? nextStopEtaSec;
  final String? shapeId;

  const Vehicle({
    required this.id,
    required this.lat,
    required this.lon,
    required this.bearing,
    this.tripId,
    this.routeId,
    this.routeShortName,
    this.routeColor,
    this.headsign,
    this.nextStopId,
    this.nextStopName,
    this.nextStopEtaSec,
    this.shapeId,
  });

  LatLng get position => LatLng(lat, lon);

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id']?.toString() ?? '',
      lat: (json['latitude'] as num).toDouble(),
      lon: (json['longitude'] as num).toDouble(),
      bearing: (json['bearing'] as num).toDouble(),
      tripId: json['trip_id'] as String?,
      routeId: json['route_id'] as String?,
      routeShortName: json['route_short_name'] as String?,
      routeColor: parseHexColor(json['route_color'] as String?),
      headsign: json['headsign'] as String?,
      nextStopId: json['next_stop_id'] as String?,
      nextStopName: json['next_stop_name'] as String?,
      nextStopEtaSec: (json['next_stop_eta_sec'] as num?)?.toInt(),
      shapeId: json['shape_id'] as String?,
    );
  }
}

class DirectedStop {
  final String stopId;
  final String name;
  final LatLng point;
  final double bearing;
  final String iconPath;

  const DirectedStop({
    required this.stopId,
    required this.name,
    required this.point,
    required this.bearing,
    required this.iconPath,
  });
}

Color? parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final h = hex.startsWith('#') ? hex.substring(1) : hex;
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  if (v == null) return null;
  return Color(0xFF000000 | v);
}
