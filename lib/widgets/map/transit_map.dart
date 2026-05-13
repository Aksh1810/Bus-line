import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../state/map_ui_store.dart';

class TransitMap extends StatelessWidget {
  const TransitMap({super.key, required this.children, this.mapController});
  final List<Widget> children;
  final MapController? mapController;

  static const LatLng _regina = LatLng(50.4452, -104.6189);

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: _regina,
        initialZoom: 13,
        minZoom: 11,
        maxZoom: 18,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.drag |
              InteractiveFlag.pinchZoom |
              InteractiveFlag.doubleTapZoom,
        ),
        onPositionChanged: (pos, _) =>
            context.read<MapUiStore>().currentZoom = pos.zoom,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.busline.bus_line',
        ),
        ...children,
      ],
    );
  }
}
