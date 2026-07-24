# Bus Line 🚌

Bus Line is a cross-platform transit application built with Flutter. It pairs a mobile map client with a lightweight Node.js proxy for GTFS/static data processing.

## 🎯 What it Does

Bus Line transforms complex transit data into a user-friendly visual interface.

### 🗺️ Interactive Transit Map
- **Visualizes Routes**: Renders bus route polylines from GTFS shape data.
- **Smart Stops**: Shows directional stop icons (NB/SB/EB/WB style).
- **Live Vehicle Tracking**: Shows moving bus icons on the map. *Note: vehicle positions are currently simulated for testing and demonstration purposes.*

### 🏝️ iOS Live Activities
- **Dynamic Island Support**: Track an active ride from Dynamic Island on supported iPhones.
- **Lock Screen Updates**: Show key trip status through Live Activities.

### 📍 Location Services
- **Nearby Access**: Centers the map around the user and nearby transit options.

---

## 🧱 Architecture

- **Flutter client (`lib/`)**: UI, map rendering, stop/route presentation, and periodic vehicle polling.
- **Node.js proxy (`transitlive-proxy/`)**: GTFS-oriented backend endpoints consumed by the app (including simulated vehicle movement today).

---

## ▶️ Run the Project

### 1) Flutter client
```bash
flutter pub get
flutter run
```

Platform-specific examples:
```bash
flutter run -d android
flutter run -d ios
```

### 2) Node.js proxy
```bash
cd transitlive-proxy
npm install
npm start
```

The Flutter app currently points to `http://10.0.2.2:3000` for Android emulator use. Update the base URL for iOS simulator or physical devices as needed.

---

## 🚀 Planned Features

1. **Real-World Data Integration**
   - Connect the proxy to live GTFS-Realtime feeds.
   - Replace simulated vehicle positions with agency GPS data.

2. **Enhanced Trip Planning**
   - Add routing from current location to destination.
   - Provide step-by-step guidance with transfers.

3. **Advanced Live Activities**
   - Add ETA, delay warnings, and stop countdown details.
   - Let users pin a specific bus for background tracking.

4. **Smart Notifications**
   - Arrival alerts (for example, “Your bus is 2 minutes away”).
   - Service alerts for detours/cancellations.

5. **Offline Capabilities**
   - Cache static schedule and route data for limited offline use.
