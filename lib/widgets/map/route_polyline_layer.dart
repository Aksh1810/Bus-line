import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../state/transit_store.dart';

class RoutePolylineLayer extends StatelessWidget {
  const RoutePolylineLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final shapes = context.select<TransitStore, Map<String, List<LatLng>>>(
      (s) => s.shapes,
    );
    if (shapes.isEmpty) return const SizedBox.shrink();
    return PolylineLayer(
      polylines: [
        for (final pts in shapes.values)
          Polyline(points: pts, strokeWidth: 3, color: Colors.blue),
      ],
    );
  }
}
