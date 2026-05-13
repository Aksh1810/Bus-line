import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/transit_store.dart';
import '../widgets/map/bus_marker_layer.dart';
import '../widgets/map/route_polyline_layer.dart';
import '../widgets/map/stop_marker_layer.dart';
import '../widgets/map/transit_map.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loading = context.select<TransitStore, bool>((s) => s.isLoading);
    return Stack(
      children: [
        const TransitMap(
          children: [
            RoutePolylineLayer(),
            BusMarkerLayer(),
            StopMarkerLayer(),
          ],
        ),
        if (loading)
          const Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Loading routes + stops...'),
              ),
            ),
          ),
      ],
    );
  }
}
