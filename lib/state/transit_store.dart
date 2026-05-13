import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import '../api/api_models.dart';
import '../api/transit_api.dart';
import '../util/stop_direction.dart';

class TransitStore extends ChangeNotifier {
  TransitStore(this._api);
  final TransitApi _api;

  Map<String, List<LatLng>> _shapes = const {};
  List<DirectedStop> _stops = const [];
  List<Vehicle> _vehicles = const [];
  bool _isLoading = true;

  Map<String, List<LatLng>> get shapes => _shapes;
  List<DirectedStop> get stops => _stops;
  List<Vehicle> get vehicles => _vehicles;
  bool get isLoading => _isLoading;

  Future<void> bootstrap() async {
    _isLoading = true;
    notifyListeners();
    await _loadShapesFromAssets();
    await _refreshStops();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshVehicles() async {
    try {
      _vehicles = await _api.fetchVehicles();
      notifyListeners();
    } catch (e) {
      debugPrint('vehicle fetch failed: $e');
    }
  }

  Future<void> _refreshStops() async {
    try {
      _stops = await _api.fetchStops(
        fallbackResolver: (point, name) => bestBearingForStop(
          point,
          name,
          _shapes,
          [for (final v in _vehicles) LatLng(v.lat, v.lon)],
        ),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('stop fetch failed: $e');
    }
  }

  Future<void> _loadShapesFromAssets() async {
    final raw = await rootBundle.loadString('assets/gtfs/shapes.txt');
    final rows = _parseGtfs(raw);
    if (rows.isEmpty) {
      debugPrint('shapes.txt parsed with no rows');
      return;
    }
    final header = rows.first;
    final idI = header.indexOf('shape_id');
    final latI = header.indexOf('shape_pt_lat');
    final lonI = header.indexOf('shape_pt_lon');
    final seqI = header.indexOf('shape_pt_sequence');
    if (idI < 0 || latI < 0 || lonI < 0) {
      debugPrint('shapes header missing required columns');
      return;
    }
    final temp = <String, List<_PointWithSeq>>{};
    for (int i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.length <= [idI, latI, lonI].reduce(max)) continue;
      final lat = double.tryParse(r[latI]);
      final lon = double.tryParse(r[lonI]);
      if (lat == null || lon == null) continue;
      int seq = i;
      if (seqI >= 0 && r.length > seqI) seq = int.tryParse(r[seqI]) ?? i;
      temp
          .putIfAbsent(r[idI], () => <_PointWithSeq>[])
          .add(_PointWithSeq(seq, LatLng(lat, lon)));
    }
    final next = <String, List<LatLng>>{};
    for (final e in temp.entries) {
      e.value.sort((a, b) => a.seq.compareTo(b.seq));
      next[e.key] = e.value.map((p) => p.point).toList(growable: false);
    }
    _shapes = next;
    debugPrint('shapes loaded: ${_shapes.length} shape_ids');
  }

  List<List<String>> _parseGtfs(String raw) {
    final cleaned = raw.replaceFirst('\uFEFF', '');
    final lines = cleaned
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.length < 2) return const [];
    final delimiter = lines.first.contains('\t') ? '\t' : ',';
    return lines.map((l) => l.split(delimiter)).toList();
  }
}

class _PointWithSeq {
  final int seq;
  final LatLng point;
  _PointWithSeq(this.seq, this.point);
}
