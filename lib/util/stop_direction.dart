import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'geo.dart';

enum _RoadAxis { eastWest, northSouth }

/// Derive a stop's facing direction from local road geometry. Fallback path —
/// the backend supplies `direction` for every Regina stop today, so this is
/// rarely hit. Kept for stops with `direction == UNK`.
double bestBearingForStop(
  LatLng stop,
  String stopName,
  Map<String, List<LatLng>> shapes,
  List<LatLng> nearbyVehiclePositions,
) {
  final hint = _directionHint(stopName);

  final flow = _busFlowHintNearStop(stop, nearbyVehiclePositions, shapes);
  if (flow != null) {
    final snapped = _snapAxisToCompass(flow);
    if (hint == null || angleDiff(hint, snapped) <= 45) return snapped;
  }

  final hits = <_CandidateHit>[];
  for (final pts in shapes.values) {
    if (pts.length < 2) continue;
    for (int i = 0; i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      if (dist2(a, b) < 1e-12) continue;
      final d2 = pointToSegmentDistance2(stop, a, b);
      if (d2 > 2e-8) continue;
      hits.add(_CandidateHit(score: d2, bearing: _windowBearing(pts, i)));
    }
  }
  if (hits.isEmpty) return 0;

  int ew = 0, ns = 0;
  for (final h in hits) {
    if (_axisFromBearing(h.bearing) == _RoadAxis.eastWest) {
      ew++;
    } else {
      ns++;
    }
  }
  final dominant = ew >= ns ? _RoadAxis.eastWest : _RoadAxis.northSouth;

  List<_CandidateHit> pool =
      hits.where((h) => _axisFromBearing(h.bearing) == dominant).toList();
  if (pool.isEmpty) pool = hits;

  if (hint != null) {
    final hinted = pool.where((h) => angleDiff(h.bearing, hint) <= 95).toList();
    if (hinted.isNotEmpty) pool = hinted;
  }

  pool.sort((a, b) => a.score.compareTo(b.score));
  final top = pool.take(10).toList();

  if (top.length >= 3) {
    final base = top.first.bearing;
    final sameDir =
        top.where((h) => angleDiff(h.bearing, base) <= 135).toList();
    if (sameDir.length >= 2) {
      top
        ..clear()
        ..addAll(sameDir);
    }
  }

  double maxSpread = 0;
  for (int i = 0; i < top.length; i++) {
    for (int j = i + 1; j < top.length; j++) {
      maxSpread = max(maxSpread, angleDiff(top[i].bearing, top[j].bearing));
    }
  }
  if (maxSpread >= 120) {
    final closest = top.first.bearing;
    if (hint != null && angleDiff(closest, hint) <= 95) return hint;
    return closest;
  }

  double x = 0, y = 0;
  for (final h in top) {
    final rad = h.bearing * pi / 180.0;
    x += cos(rad);
    y += sin(rad);
  }
  final mean = (atan2(y, x) * 180 / pi + 360) % 360;
  if (hint != null && angleDiff(mean, hint) <= 95) return hint;
  return mean;
}

double _windowBearing(List<LatLng> pts, int i) {
  final start = max(0, i - 2);
  final end = min(pts.length - 1, i + 2);
  return bearing(pts[start], pts[end]);
}

_RoadAxis _axisFromBearing(double b) {
  if ((b >= 45 && b < 135) || (b >= 225 && b < 315)) return _RoadAxis.eastWest;
  return _RoadAxis.northSouth;
}

double _snapAxisToCompass(double axis) {
  if (axis >= 45 && axis < 135) return 90;
  if (axis >= 135 && axis < 225) return 180;
  if (axis >= 225 && axis < 315) return 270;
  return 0;
}

double? _busFlowHintNearStop(
  LatLng stop,
  List<LatLng> vehiclePositions,
  Map<String, List<LatLng>> shapes, {
  double maxDist = 0.00025,
}) {
  final List<double> bearings = [];
  for (final pos in vehiclePositions) {
    if (dist2(stop, pos) < maxDist) {
      bearings.add(bearingFromRoute(pos, shapes));
    }
  }
  if (bearings.length < 2) return null;
  double x = 0, y = 0;
  for (final b in bearings) {
    final r = b * pi / 180;
    x += cos(r);
    y += sin(r);
  }
  return (atan2(y, x) * 180 / pi + 360) % 360;
}

double? _directionHint(String name) {
  final u = name.toUpperCase().trim();
  bool has(RegExp r) => r.hasMatch(u);

  if (has(RegExp(r'(^|[\s\-\(\[/])N\s*/\s*B($|[\s\-\)\]/:])'))) return 0;
  if (has(RegExp(r'(^|[\s\-\(\[/])NB($|[\s\-\)\]/:])'))) return 0;
  if (has(RegExp(r'NORTH\s*BOUND'))) return 0;
  if (has(RegExp(r'NORTHBOUND'))) return 0;
  if (has(RegExp(r'(^|[\s\-\(\[/])S\s*/\s*B($|[\s\-\)\]/:])'))) return 180;
  if (has(RegExp(r'(^|[\s\-\(\[/])SB($|[\s\-\)\]/:])'))) return 180;
  if (has(RegExp(r'SOUTH\s*BOUND'))) return 180;
  if (has(RegExp(r'SOUTHBOUND'))) return 180;
  if (has(RegExp(r'(^|[\s\-\(\[/])E\s*/\s*B($|[\s\-\)\]/:])'))) return 90;
  if (has(RegExp(r'(^|[\s\-\(\[/])EB($|[\s\-\(\)\]/:])'))) return 90;
  if (has(RegExp(r'EAST\s*BOUND'))) return 90;
  if (has(RegExp(r'EASTBOUND'))) return 90;
  if (has(RegExp(r'(^|[\s\-\(\[/])W\s*/\s*B($|[\s\-\)\]/:])'))) return 270;
  if (has(RegExp(r'(^|[\s\-\(\[/])WB($|[\s\-\)\]/:])'))) return 270;
  if (has(RegExp(r'WEST\s*BOUND'))) return 270;
  if (has(RegExp(r'WESTBOUND'))) return 270;
  return null;
}

class _CandidateHit {
  final double score;
  final double bearing;
  _CandidateHit({required this.score, required this.bearing});
}
