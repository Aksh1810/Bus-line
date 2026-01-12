import 'dart:math';
import 'dart:async'; // 🚌 NEW
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/bus.dart';
import '../models/stop.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}



class _MapScreenState extends State<MapScreen> {
  final LatLng reginaCenter = const LatLng(50.4452, -104.6189);

  bool _isOppositeDirection(double a, double b) {
    return _angleDiff(a, b) > 135;
  }

  List<Bus> _buses = [];
  Timer? _liveBusTimer;

  // shape_id -> polyline points
  final Map<String, List<LatLng>> routeShapes = {};

  bool _loading = true;

  // final stops with chosen direction icon
  final List<_DirectedStop> directedStops = [];

  // ✅ zoom handling
  double _currentZoom = 13.0;
  static const double stopVisibleZoom = 14.0;

  // ============================================================
  // 🚌 NEW: TEST BUS (ADDED ONLY - does not touch stop logic)
  // ============================================================
  Timer? _busTimer;

  // If your bus.svg points LEFT by default, set this to +pi/2 or +pi etc.
  // Try 0 first. If bus faces wrong direction, change to:
  //   +pi (reverse) or +pi/2 (90deg) or -pi/2.
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadAll(); // ← REQUIRED
    _fetchLiveBuses();

    _liveBusTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _fetchLiveBuses(),
    );
  }

  // 🚌 NEW
  @override
  void dispose() {
    _busTimer?.cancel();
    _liveBusTimer?.cancel(); // 🔑 ADD THIS
    super.dispose();
  }

  Future<void> _fetchLiveBuses() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:3000/vehicles'),
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        setState(() {
          _buses = data.map((e) => Bus.fromJson(e)).toList();
        });

        debugPrint('Buses received: ${_buses.length}');
      }
    } catch (e) {
      debugPrint('Live bus fetch error: $e');
    }
  }


  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await _loadShapes();      // FIRST
    await _fetchLiveStops();  // THEN compute bearings
    setState(() => _loading = false);
  }

  /* ============================================================
     Robust GTFS parsing (comma or tab, handles BOM)
  ============================================================ */
  List<List<String>> _parseGtfs(String raw) {
    raw = raw.replaceFirst('\uFEFF', '');
    final lines =
        raw.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) return [];
    final delimiter = lines.first.contains('\t') ? '\t' : ',';
    return lines.map((l) => l.split(delimiter)).toList();
  }

  /* ============================================================
     LOAD SHAPES
     ✅ NEW: sort points by shape_pt_sequence (GTFS-correct)
  ============================================================ */
  Future<void> _loadShapes() async {
    final raw = await rootBundle.loadString('assets/gtfs/shapes.txt');
    final rows = _parseGtfs(raw);

    if (rows.isEmpty) {
      debugPrint('❌ shapes.txt parsed with no rows');
      return;
    }

    final header = rows.first;
    final idI = header.indexOf('shape_id');
    final latI = header.indexOf('shape_pt_lat');
    final lonI = header.indexOf('shape_pt_lon');
    final seqI = header.indexOf('shape_pt_sequence'); // ✅ NEW

    if (idI < 0 || latI < 0 || lonI < 0) {
      debugPrint('❌ shapes header missing required columns');
      return;
    }

    routeShapes.clear();

    // ✅ NEW: collect with sequence first, then sort within each shape_id
    final Map<String, List<_ShapePt>> temp = {};

    for (int i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.length <= max(idI, max(latI, lonI))) continue;

      final lat = double.tryParse(r[latI]);
      final lon = double.tryParse(r[lonI]);
      if (lat == null || lon == null) continue;

      final id = r[idI];

      int seq = i; // fallback if no shape_pt_sequence column
      if (seqI >= 0 && r.length > seqI) {
        seq = int.tryParse(r[seqI]) ?? i;
      }

      temp.putIfAbsent(id, () => []);
      temp[id]!.add(_ShapePt(seq: seq, point: LatLng(lat, lon)));
    }

    // sort + write into routeShapes
    for (final e in temp.entries) {
      e.value.sort((a, b) => a.seq.compareTo(b.seq));
      routeShapes[e.key] = e.value.map((p) => p.point).toList();
    }

    debugPrint('✅ shapes loaded (sorted): ${routeShapes.length} shape_ids');
  }

  /* ============================================================
     LOAD STOPS + ASSIGN DIRECTIONS
  ============================================================ */

  /* ============================================================
     BEARING LOGIC
     ✅ NEW: stability guard for intersections / noisy segments
  ============================================================ */
  double _bestBearingForStop(LatLng stop, String stopName) {
    final hint = _directionHint(stopName); // degrees or null
    final hits = <_CandidateHit>[];

    for (final pts in routeShapes.values) {
      if (pts.length < 2) continue;

      for (int i = 0; i < pts.length - 1; i++) {
        final a = pts[i];
        final b = pts[i + 1];

        if (_dist2(a, b) < 1e-12) continue;

        final d2 = _pointToSegmentDistance2(stop, a, b);

        // keep local (performance + avoids far wrong segments)
        if (d2 > 2e-8) continue;

        final bearing = _windowBearing(pts, i);
        hits.add(_CandidateHit(score: d2, bearing: bearing));
      }
    }

    if (hits.isEmpty) return 0;

    // If stop_name has a direction hint, prefer candidates that match it first
    List<_CandidateHit> pool = hits;
    if (hint != null) {
      final hinted =
          hits.where((h) => _angleDiff(h.bearing, hint) <= 95).toList();
      if (hinted.isNotEmpty) pool = hinted;
    }

    // Sort by distance first
    pool.sort((a, b) => a.score.compareTo(b.score));

    // Take top few and circular-mean them (reduces flip errors)

    final top = pool.take(10).toList();

// 🔒 NEW: remove opposite-direction segments if majority agrees
    if (top.length >= 3) {
      final base = top.first.bearing;
      final sameDir = top
          .where(
            (h) => !_isOppositeDirection(h.bearing, base),
          )
          .toList();

      if (sameDir.length >= 2) {
        top
          ..clear()
          ..addAll(sameDir);
      }
    }

    // ✅ NEW: if the top candidates disagree too much (intersection),
    // return the closest segment bearing (prevents random flipped arrows)
    double maxSpread = 0;
    for (int i = 0; i < top.length; i++) {
      for (int j = i + 1; j < top.length; j++) {
        maxSpread = max(maxSpread, _angleDiff(top[i].bearing, top[j].bearing));
      }
    }
    if (maxSpread >= 120) {
      // “too messy” → closest is usually correct
      final closest = top.first.bearing;
      if (hint != null && _angleDiff(closest, hint) <= 95) return hint;
      return closest;
    }

    double x = 0, y = 0;
    for (final h in top) {
      final rad = h.bearing * pi / 180.0;
      x += cos(rad);
      y += sin(rad);
    }

    final mean = (atan2(y, x) * 180 / pi + 360) % 360;

    // Final snap toward hint if reasonably close (TransitLive-like)
    if (hint != null && _angleDiff(mean, hint) <= 95) return hint;

    return mean;
  }

  double _windowBearing(List<LatLng> pts, int i) {
    final start = max(0, i - 2);
    final end = min(pts.length - 1, i + 2);
    return _bearing(pts[start], pts[end]);
  }

  /* ============================================================
     Better direction parsing (unchanged from your working code)
  ============================================================ */
  double? _directionHint(String name) {
    final u = name.toUpperCase().trim();

    bool has(RegExp r) => r.hasMatch(u);

    // North
    if (has(RegExp(r'(^|[\s\-\(\[/])N\s*/\s*B($|[\s\-\)\]/:])'))) return 0;
    if (has(RegExp(r'(^|[\s\-\(\[/])NB($|[\s\-\)\]/:])'))) return 0;
    if (has(RegExp(r'NORTH\s*BOUND'))) return 0;
    if (has(RegExp(r'NORTHBOUND'))) return 0;

    // South
    if (has(RegExp(r'(^|[\s\-\(\[/])S\s*/\s*B($|[\s\-\)\]/:])'))) return 180;
    if (has(RegExp(r'(^|[\s\-\(\[/])SB($|[\s\-\)\]/:])'))) return 180;
    if (has(RegExp(r'SOUTH\s*BOUND'))) return 180;
    if (has(RegExp(r'SOUTHBOUND'))) return 180;

    // East
    if (has(RegExp(r'(^|[\s\-\(\[/])E\s*/\s*B($|[\s\-\)\]/:])'))) return 90;
    if (has(RegExp(r'(^|[\s\-\(\[/])EB($|[\s\-\(\)\]/:])'))) return 90;
    if (has(RegExp(r'EAST\s*BOUND'))) return 90;
    if (has(RegExp(r'EASTBOUND'))) return 90;

    // West
    if (has(RegExp(r'(^|[\s\-\(\[/])W\s*/\s*B($|[\s\-\)\]/:])'))) return 270;
    if (has(RegExp(r'(^|[\s\-\(\[/])WB($|[\s\-\)\]/:])'))) return 270;
    if (has(RegExp(r'WEST\s*BOUND'))) return 270;
    if (has(RegExp(r'WESTBOUND'))) return 270;

    return null;
  }


  Future<void> _fetchLiveStops() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:3000/stops'),
      );

      if (response.statusCode != 200) {
        debugPrint('❌ Stop fetch failed: ${response.statusCode}');
        return;
      }

      final List data = jsonDecode(response.body);

      directedStops.clear();

      for (final s in data) {
        final lat = (s['lat'] as num?)?.toDouble();
        final lon = (s['lon'] as num?)?.toDouble();
        final name = s['name'] ?? '';

        if (lat == null || lon == null) continue;

        final point = LatLng(lat, lon);

        // 🔑 SAME LOGIC AS BEFORE
        final bearing = _bestBearingForStop(point, name);
        final icon = _iconFromBearing(bearing);

        directedStops.add(
          _DirectedStop(
            point: point,
            iconPath: icon,
          ),
        );
      }

      debugPrint('Stops received: ${directedStops.length}');
      setState(() {});
    } catch (e) {
      debugPrint('Stop fetch error: $e');
    }
  }

  String _iconFromBearing(double b) {
    if (b >= 45 && b < 135) return 'assets/icons/stop_right.svg';
    if (b >= 135 && b < 225) return 'assets/icons/stop_down.svg';
    if (b >= 225 && b < 315) return 'assets/icons/stop_left.svg';
    return 'assets/icons/stop_up.svg';
  }

  /* ============================================================
     MATH HELPERS
  ============================================================ */

  LatLng _snapToRoutes(LatLng busPoint) {
    LatLng? bestPoint;
    double bestDist = double.infinity;

    for (final pts in routeShapes.values) {
      for (int i = 0; i < pts.length - 1; i++) {
        final a = pts[i];
        final b = pts[i + 1];

        final snapped = _projectPoint(busPoint, a, b);
        final d = _dist2(busPoint, snapped);

        if (d < bestDist) {
          bestDist = d;
          bestPoint = snapped;
        }
      }
    }

    return bestPoint ?? busPoint;
  }

  LatLng _projectPoint(LatLng p, LatLng a, LatLng b) {
    final ax = a.longitude, ay = a.latitude;
    final bx = b.longitude, by = b.latitude;
    final px = p.longitude, py = p.latitude;

    final dx = bx - ax;
    final dy = by - ay;

    if (dx == 0 && dy == 0) return a;

    final t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
    final clamped = t.clamp(0.0, 1.0);

    return LatLng(
      ay + dy * clamped,
      ax + dx * clamped,
    );
  }

  double _angleDiff(double a, double b) {
    final d = (a - b).abs() % 360;
    return d > 180 ? 360 - d : d;
  }

  double _dist2(LatLng a, LatLng b) {
    final dx = a.latitude - b.latitude;
    final dy = a.longitude - b.longitude;
    return dx * dx + dy * dy;
  }

  double _pointToSegmentDistance2(LatLng p, LatLng a, LatLng b) {
    final ax = a.longitude, ay = a.latitude;
    final bx = b.longitude, by = b.latitude;
    final px = p.longitude, py = p.latitude;

    final dx = bx - ax;
    final dy = by - ay;
    if (dx == 0 && dy == 0) return _dist2(p, a);

    final t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
    final tc = t.clamp(0.0, 1.0);

    final projX = ax + dx * tc;
    final projY = ay + dy * tc;

    final ddx = px - projX;
    final ddy = py - projY;
    return ddx * ddx + ddy * ddy;
  }

  double _bearing(LatLng a, LatLng b) {
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;

    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  double _bearingFromRoute(LatLng busPos) {
    double bestDist = double.infinity;
    double bestBearing = 0;

    for (final pts in routeShapes.values) {
      for (int i = 0; i < pts.length - 1; i++) {
        final a = pts[i];
        final b = pts[i + 1];

        final d = _pointToSegmentDistance2(busPos, a, b);
        if (d < bestDist) {
          bestDist = d;
          bestBearing = _bearing(a, b);
        }
      }
    }
    return bestBearing;
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final List<Marker> busMarkers = _buses.map((bus) {
      final snapped = _snapToRoutes(LatLng(bus.lat, bus.lon));

      return Marker(
        point: snapped,
        width: 36,
        height: 36,
        child: Transform.rotate(
          angle: _bearingFromRoute(snapped) * pi / 180,
          alignment: Alignment.center,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.blue, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
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
    }).toList();

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: reginaCenter,
            initialZoom: 13,
            minZoom: 11,
            maxZoom: 18,

            // 🔒 rotation locked
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.drag |
                  InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom,
            ),

            onPositionChanged: (pos, _) {
              setState(() {
                _currentZoom = pos.zoom ?? _currentZoom;
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.busline.bus_line',
            ),

            // 🛑 STATIC ROUTES DISABLED FOR LIVE BUS DEBUG

            PolylineLayer(
              polylines: routeShapes.values
                  .map(
                    (pts) => Polyline(
                        points: pts,
                        strokeWidth: 3,
                        color: Colors.blue),
                  )
                  .toList(),
            ),

            // 🚌 TEST BUS MARKER
            if (busMarkers.isNotEmpty) MarkerLayer(markers: busMarkers),

            // 🚏 STOPS (DISABLED FOR LIVE BUS DEBUG)

            if (_currentZoom >= stopVisibleZoom)
              if (_currentZoom >= stopVisibleZoom)
                MarkerLayer(
                  markers: directedStops.map((s) {
                    return Marker(
                      point: s.point,
                      width: 22,
                      height: 22,
                      child: SvgPicture.asset(
                        s.iconPath,
                        fit: BoxFit.contain,
                      ),
                    );
                  }).toList(),
                ),

          ],
        ),
        if (_loading)
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
// ============================================================
// Helper classes (REQUIRED — were missing)
// ============================================================


class _CandidateHit {
  final double score; // distance score
  final double bearing;

  _CandidateHit({
    required this.score,
    required this.bearing,
  });
}

class _ShapePt {
  final int seq;
  final LatLng point;

  _ShapePt({
    required this.seq,
    required this.point,
  });
}

class _DirectedStop {
  final LatLng point;
  final String iconPath;

  _DirectedStop({
    required this.point,
    required this.iconPath,
  });
}
