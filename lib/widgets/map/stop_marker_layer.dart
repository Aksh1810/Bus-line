import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../api/api_models.dart';
import '../../state/map_ui_store.dart';
import '../../state/transit_store.dart';

class StopMarkerLayer extends StatelessWidget {
  const StopMarkerLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final zoom = context.select<MapUiStore, double>((s) => s.currentZoom);
    if (zoom < MapUiStore.stopVisibleZoom) return const SizedBox.shrink();
    final stops =
        context.select<TransitStore, List<DirectedStop>>((s) => s.stops);
    if (stops.isEmpty) return const SizedBox.shrink();
    return MarkerLayer(
      markers: [
        for (final s in stops)
          Marker(
            point: s.point,
            width: 22,
            height: 22,
            child: SvgPicture.asset(s.iconPath, fit: BoxFit.contain),
          ),
      ],
    );
  }
}
