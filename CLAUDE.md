# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run on connected device or emulator
flutter run

# Run on specific platform
flutter run -d ios
flutter run -d android

# Build
flutter build apk        # Android
flutter build ios        # iOS (requires Xcode)

# Analyze and format
flutter analyze
dart format lib/

# Get dependencies
flutter pub get
```

No test suite is currently set up (`flutter test` will find nothing).

## Architecture

Single-screen Flutter app for real-time bus tracking in Regina, SK. The entire UI lives in `lib/screens/map_screen.dart`; `lib/main.dart` is just a thin entry point.

### Data flow

The app has two data sources:

1. **Static GTFS assets** (`assets/gtfs/shapes.txt`, `assets/gtfs/stops.txt`) — loaded from the bundle at startup via `rootBundle`. Used to draw route polylines and as a fallback for stop direction computation.

2. **Node.js backend** at `http://10.0.2.2:3000` (Android emulator loopback; change for iOS simulator or physical device) — **this server is not in this repo**. It exposes:
   - `GET /vehicles` — returns live bus positions (currently simulated); polled every 3 seconds
   - `GET /stops` — returns stop data including a pre-computed `direction` field (`NB`/`SB`/`EB`/`WB`)

### Stop direction logic

Stop icons are directional arrows. The server's `direction` field is used when present. The fallback path (rare) runs in `_bestBearingForStop()` inside `map_screen.dart`, which:
1. Collects nearby GTFS shape segments within a distance threshold
2. Votes on dominant road axis (EW vs NS)
3. Applies name-based hints from `_directionHint()` (parses "NB", "SB", "EB", "WB", "NORTHBOUND", etc. from stop names)
4. Filters opposite-direction segments and computes a circular mean bearing
5. Maps bearing → icon via `_iconFromBearing()`

Bus markers are snapped to the nearest route polyline segment (`_snapToRoutes`) and rotated to face their direction of travel (`_bearingFromRoute`).

### iOS Live Activities

`LiveActivityService` (Dart) communicates with `AppDelegate.swift` (Swift) over a `MethodChannel` named `com.busline/live_activity`. The Swift side uses `ActivityKit` to manage a `BusActivityAttributes` Live Activity on the Dynamic Island / Lock Screen. Requires iOS 16.1+.

### Models

- `Bus` — id, lat, lon, bearing; parsed from `/vehicles` JSON
- `Stop` — lat, lon, name; used as intermediate during GTFS parsing
- `BusStop` — LatLng position + direction string; internal map marker type
- `_DirectedStop` (private, in `map_screen.dart`) — stopId, LatLng, iconPath; the final rendered stop

### Backend URL note

`BusApi._url` and the inline `http.get` calls in `map_screen.dart` both hardcode `http://10.0.2.2:3000`. For iOS simulator use `http://127.0.0.1:3000`; for a physical device use the host machine's local IP.
