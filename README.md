# Bus Line 🚌

Flutter transit map app inspired by TransitLive.

Renders GTFS routes, stops, and a moving bus marker on OpenStreetMap using
`flutter_map`.

---

## Features

- GTFS `shapes.txt` → route polylines
- GTFS `stops.txt` → direction-aware stop icons
- Animated bus marker moving along route
- Stable bus orientation (no flipping at stops)
- Zoom-based visibility for routes / stops / bus
- Custom TransitLive-style bus marker (PNG)

---

## Bus Marker Logic

- Bus follows a GTFS shape (ordered by `shape_pt_sequence`)
- Bearing calculated from current segment
- Bearing stabilized across segments
- PNG faces **west (left)** by default
- Rotation applied to align PNG with travel direction

---

## Project Structure
assets/
├── gtfs/
│   ├── shapes.txt
│   └── stops.txt
└── icons/
├── bus.png
├── stop_up.svg
├── stop_down.svg
├── stop_left.svg
└── stop_right.svg

lib/
├── screens/
│   └── map_screen.dart
└── main.dart

---

## Tech Stack

- Flutter
- flutter_map
- OpenStreetMap
- latlong2
- GTFS (static)

---

## Run

```bash
flutter pub get
flutter run

Status
	•	Routes: ✅
	•	Stops + direction icons: ✅
	•	Moving bus marker: ✅
	•	GTFS-Realtime: (planned)
