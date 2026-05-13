import 'dart:math';
import 'package:latlong2/latlong.dart';

double bearing(LatLng a, LatLng b) {
  final lat1 = a.latitude * pi / 180;
  final lat2 = b.latitude * pi / 180;
  final dLon = (b.longitude - a.longitude) * pi / 180;
  final y = sin(dLon) * cos(lat2);
  final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
  return (atan2(y, x) * 180 / pi + 360) % 360;
}

LatLng projectPoint(LatLng p, LatLng a, LatLng b) {
  final ax = a.longitude, ay = a.latitude;
  final bx = b.longitude, by = b.latitude;
  final px = p.longitude, py = p.latitude;
  final dx = bx - ax;
  final dy = by - ay;
  if (dx == 0 && dy == 0) return a;
  final t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
  final clamped = t.clamp(0.0, 1.0);
  return LatLng(ay + dy * clamped, ax + dx * clamped);
}

double dist2(LatLng a, LatLng b) {
  final dx = a.latitude - b.latitude;
  final dy = a.longitude - b.longitude;
  return dx * dx + dy * dy;
}

double pointToSegmentDistance2(LatLng p, LatLng a, LatLng b) {
  final projected = projectPoint(p, a, b);
  return dist2(p, projected);
}

double angleDiff(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

LatLng snapToRoutes(LatLng busPoint, Map<String, List<LatLng>> shapes) {
  LatLng best = busPoint;
  double bestDist = double.infinity;
  for (final pts in shapes.values) {
    for (int i = 0; i < pts.length - 1; i++) {
      final snapped = projectPoint(busPoint, pts[i], pts[i + 1]);
      final d = dist2(busPoint, snapped);
      if (d < bestDist) {
        bestDist = d;
        best = snapped;
      }
    }
  }
  return best;
}

double bearingFromRoute(LatLng busPos, Map<String, List<LatLng>> shapes) {
  double bestDist = double.infinity;
  double bestBearing = 0;
  for (final pts in shapes.values) {
    for (int i = 0; i < pts.length - 1; i++) {
      final d = pointToSegmentDistance2(busPos, pts[i], pts[i + 1]);
      if (d < bestDist) {
        bestDist = d;
        bestBearing = bearing(pts[i], pts[i + 1]);
      }
    }
  }
  return bestBearing;
}
