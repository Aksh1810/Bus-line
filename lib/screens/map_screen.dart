import 'dart:math';
import 'dart:async'; // 🚌 NEW
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

double? _stableBusBearingDeg;

class _MapScreenState extends State<MapScreen> {
  final LatLng reginaCenter = const LatLng(50.4452, -104.6189);
  bool _isOppositeDirection(double a, double b) {
    return _angleDiff(a, b) > 135;
  }

  // shape_id -> polyline points
  final Map<String, List<LatLng>> routeShapes = {};

  // final stops with chosen direction icon
  final List<_DirectedStop> directedStops = [];

  bool _loading = true;

  // ✅ zoom handling
  double _currentZoom = 13.0;
  static const double stopVisibleZoom = 14.0;

  // ============================================================
  // 🚌 NEW: TEST BUS (ADDED ONLY - does not touch stop logic)
  // ============================================================
  Timer? _busTimer;
  String? _busShapeId; // which route (shape) the test bus follows
  int _busSegIndex = 0; // which segment in that shape
  double _busT = 0.0; // 0..1 progress along the segment
  static const double _busSpeed = 0.04; // adjust speed if needed
  static const double busVisibleZoom = 12.0; // show bus after this zoom

  // If your bus.svg points LEFT by default, set this to +pi/2 or +pi etc.
  // Try 0 first. If bus faces wrong direction, change to:
  //   +pi (reverse) or +pi/2 (90deg) or -pi/2.
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // 🚌 NEW
  @override
  void dispose() {
    _busTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await _loadShapes();
    await _loadStopsAndAssignDirections();

    // 🚌 NEW: start the test bus only after shapes exist
    _startTestBus();

    setState(() => _loading = false);
  }

  /* ============================================================
     Robust GTFS parsing (comma or tab, handles BOM)
  ============================================================ */
  List<List<String>> _parseGtfs(String raw) {
    raw = raw.replaceFirst('\uFEFF', '');
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();
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
  Future<void> _loadStopsAndAssignDirections() async {
    directedStops.clear();

    final raw = await rootBundle.loadString('assets/gtfs/stops.txt');
    final rows = _parseGtfs(raw);

    if (rows.isEmpty) {
      debugPrint('❌ stops.txt parsed with no rows');
      return;
    }

    final header = rows.first;
    final nameI = header.indexOf('stop_name');
    final latI = header.indexOf('stop_lat');
    final lonI = header.indexOf('stop_lon');

    debugPrint('CSV rows: ${rows.length}');

    for (int i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.length <= max(nameI, max(latI, lonI))) continue;

      final name = nameI >= 0 ? r[nameI] : '';
      final lat = double.tryParse(r[latI]);
      final lon = double.tryParse(r[lonI]);
      if (lat == null || lon == null) continue;

      final stopPoint = LatLng(lat, lon);
      final bearing = _bestBearingForStop(stopPoint, name);
      final icon = _iconFromBearing(bearing);

      directedStops.add(_DirectedStop(
        point: stopPoint,
        iconPath: icon,
      ));
    }

    debugPrint('✅ Parsed stops count: ${directedStops.length}');
  }

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
      final sameDir = top.where(
            (h) => !_isOppositeDirection(h.bearing, base),
      ).toList();

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

  /* ============================================================
     ICONS
  ============================================================ */
  String _iconFromBearing(double b) {
    if (b >= 45 && b < 135) return 'assets/icons/stop_right.svg';
    if (b >= 135 && b < 225) return 'assets/icons/stop_down.svg';
    if (b >= 225 && b < 315) return 'assets/icons/stop_left.svg';
    return 'assets/icons/stop_up.svg';
  }

  /* ============================================================
     MATH HELPERS
  ============================================================ */
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

  // ============================================================
  // 🚌 NEW: TEST BUS HELPERS (ADDED ONLY)
  // ============================================================
  void _startTestBus() {
    _busTimer?.cancel();

    if (routeShapes.isEmpty) {

      return;
    }

    // Pick the first available shape for the test bus
    _busShapeId = routeShapes.keys.first;
    _busSegIndex = 0;
    _busT = 0.0;

    _busTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      final pts = routeShapes[_busShapeId];
      if (pts == null || pts.length < 2) return;

      _busT += _busSpeed;

      if (_busT >= 1.0) {
        _busT = 0.0;
        _busSegIndex++;

        if (_busSegIndex >= pts.length - 1) {
          _busSegIndex = 0; // loop back to start
        }
      }

      // Update stable bearing ONLY if this segment has real length
      final a = pts[_busSegIndex];
      final b = pts[_busSegIndex + 1];

      final dx = (b.longitude - a.longitude).abs();
      final dy = (b.latitude - a.latitude).abs();

      if (dx > 1e-7 || dy > 1e-7) {
        _stableBusBearingDeg = _bearing(a, b);
      }

      setState(() {});
    });
  }

  LatLng _busPosition(List<LatLng> pts) {
    final a = pts[_busSegIndex];
    final b = pts[_busSegIndex + 1];

    return LatLng(
      a.latitude + (b.latitude - a.latitude) * _busT,
      a.longitude + (b.longitude - a.longitude) * _busT,
    );
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final List<Marker> busMarkers = [];

    if (_busShapeId != null && _currentZoom >= busVisibleZoom) {
      final pts = routeShapes[_busShapeId];
      if (pts != null && pts.length >= 2) {
        final pos = _busPosition(pts);
        final bearingDeg = _stableBusBearingDeg ?? _bearing(
          pts[_busSegIndex],
          pts[_busSegIndex + 1],
        );
// bus.svg faces LEFT (west), so we align west to 0-rotation.
// Also negate bearing to match Flutter's rotation direction.
        busMarkers.add(
          Marker(
            point: pos,
            width: 36,
            height: 36,
            child: Transform.rotate(
              angle: - (bearingDeg - 90) * pi / 180,
              // 🔑 PNG faces right → offset by -90°
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
          ),
        );
      }
    }

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

            PolylineLayer(
              polylines: routeShapes.values
                  .map(
                    (pts) => Polyline(
                  points: pts,
                  strokeWidth: 3,
                  color: Colors.blue.withOpacity(0.35),
                ),
              )
                  .toList(),
            ),

            // 🚌 TEST BUS MARKER
            if (busMarkers.isNotEmpty)
              MarkerLayer(markers: busMarkers),

            // 🚏 STOPS (unchanged)
            if (_currentZoom >= stopVisibleZoom)
              MarkerLayer(
                markers: directedStops.map((s) {
                  return Marker(
                    point: s.point,
                    width: 22,
                    height: 22,
                    child: SvgPicture.asset(s.iconPath),
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

class _DirectedStop {
  final LatLng point;
  final String iconPath;

  _DirectedStop({
    required this.point,
    required this.iconPath,
  });
}

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
