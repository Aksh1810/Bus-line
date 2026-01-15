# Bus Line 🚌

Bus Line is a modern, cross-platform transit application built with Flutter, designed to provide commuters with an intuitive and real-time transit experience. It combines a responsive mobile interface with a custom Node.js backend to process and visualize transit data efficiently.

## 🎯 What it Does

Bus Line transforms complex transit data into a user-friendly visual interface, helping users understand their transit network at a glance.

### 🗺️ Interactive Transit Map
The core of the application is a high-performance map interface powered by `flutter_map` and OpenStreetMap.
- **Visualizes Routes**: Renders precise bus route paths (polylines) derived from GTFS shape data.
- **Smart Stops**: Displays bus stops with intelligent directional icons (e.g., Northbound vs. Southbound arrows), helping users stand on the correct side of the street.
- **Live Vehicle Tracking**: Shows moving bus icons on the map. *Note: Currently, vehicle positions are simulated for testing and demonstration purposes.*

### 🏝️ iOS Live Activities
Bus Line integrates deeply with iOS features to keep users informed without needing to open the app.
- **Dynamic Island Support**: Users can start a "ride" to track their bus directly from the Dynamic Island on supported iPhones.
- **Lock Screen Updates**: Essential trip information is visible right on the lock screen via Live Activities.

### 📍 Location Services
- **Nearby Access**: Uses device location to instantly center the map on the user's surroundings, highlighting the nearest transit options.

---

## 🚀 Planned Features

The project is actively evolving from a prototype to a fully-featured transit assistant. The roadmap includes:

### 1. Real-World Data Integration
- Connect the current Node.js proxy to live GTFS-Realtime feeds (e.g., TransitLive or other municipal open data portals).
- Replace simulated "ticking" vehicle positions with actual GPS coordinates from transit agencies.

### 2. Enhanced Trip Planning
- Implement a routing engine to allow users to plan trips from their current location to a destination.
- Provide step-by-step navigation instructions including walking segments and transfers.

### 3. Advanced Live Activities
- Enrich the Dynamic Island interface with estimated arrival times (ETA), delay warnings, and stop count countdowns.
- Allow users to "pin" a specific bus to follow its progress in the background.

### 4. Smart Notifications
- Push notifications for bus arrivals ("Your bus is 2 minutes away").
- Service alerts for route detours or cancellations.

### 5. Offline Capabilities
- Cache static schedule data (stop times and route shapes) so basic network information is available even without an internet connection.
