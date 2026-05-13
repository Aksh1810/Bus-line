import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../util/icon_for_bearing.dart';
import 'api_models.dart';

typedef FallbackBearingResolver = double Function(LatLng point, String name);

class TransitApi {
  TransitApi({String? baseUrl}) : _base = baseUrl ?? 'http://localhost:3000';
  final String _base;

  Future<List<Vehicle>> fetchVehicles() async {
    final res = await http.get(Uri.parse('$_base/vehicles'));
    if (res.statusCode != 200) {
      throw Exception('GET /vehicles -> ${res.statusCode}');
    }
    final List data = jsonDecode(res.body) as List;
    return data
        .cast<Map<String, dynamic>>()
        .map(Vehicle.fromJson)
        .toList(growable: false);
  }

  Future<List<DirectedStop>> fetchStops({
    required FallbackBearingResolver fallbackResolver,
  }) async {
    final res = await http.get(Uri.parse('$_base/stops'));
    if (res.statusCode != 200) {
      throw Exception('GET /stops -> ${res.statusCode}');
    }
    final List data = jsonDecode(res.body) as List;
    final out = <DirectedStop>[];
    for (final raw in data) {
      final s = raw as Map<String, dynamic>;
      final lat = (s['lat'] as num?)?.toDouble();
      final lon = (s['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;
      final name = (s['name'] as String?) ?? '';
      final stopId =
          (s['stop_id'] as String?) ?? (s['stopId'] as String?) ?? '';
      final dir = s['direction'] as String?;
      final point = LatLng(lat, lon);
      final bearing = switch (dir) {
        'NB' => 0.0,
        'SB' => 180.0,
        'EB' => 90.0,
        'WB' => 270.0,
        _ => fallbackResolver(point, name),
      };
      out.add(DirectedStop(
        stopId: stopId,
        name: name,
        point: point,
        bearing: bearing,
        iconPath: iconFromBearing(bearing),
      ));
    }
    return out;
  }
}
