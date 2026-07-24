import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../api/api_models.dart';
import '../../state/transit_store.dart';
import '../../util/geo.dart' as geo;

class BusMarkerLayer extends StatelessWidget {
  const BusMarkerLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final shapes = context.select<TransitStore, Map<String, List<LatLng>>>(
      (s) => s.shapes,
    );
    final vehicles =
        context.select<TransitStore, List<Vehicle>>((s) => s.vehicles);
    if (vehicles.isEmpty) return const SizedBox.shrink();
    return MarkerLayer(
      markers: [for (final v in vehicles) _busMarker(v, shapes)],
    );
  }

  // Client-side snap to nearest route segment keeps buses visually on roads
  // when the backend still returns raw simulated positions. Becomes a no-op
  // once /vehicles is upgraded to schedule-based shape-interpolated positions.
  Marker _busMarker(Vehicle v, Map<String, List<LatLng>> shapes) {
    final raw = LatLng(v.lat, v.lon);
    final snapped = shapes.isEmpty ? raw : geo.snapToRoutes(raw, shapes);
    final bearing =
        shapes.isEmpty ? v.bearing : geo.bearingFromRoute(snapped, shapes);
    final color = v.routeColor ?? Colors.blue;
    return Marker(
      point: snapped,
      width: 36,
      height: 36,
      child: Transform.rotate(
        angle: (bearing - 90) * pi / 180,
        alignment: Alignment.center,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: color, width: 3),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 3)),
            ],
          ),
          child: Center(
            child: Image.asset(
              'assets/icons/bus.png',
              width: 22,
              height: 22,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
