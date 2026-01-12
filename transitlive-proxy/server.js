const express = require("express");
const fetch = require("node-fetch");
const protobuf = require("protobufjs");

const app = express();
const PORT = 3000;

// Regina Transit GTFS-Realtime Vehicle Positions
const VEHICLE_URL =
  "https://transitfeeds.com/p/regina-transit/318/latest/download";

let FeedMessage = null;

// Load GTFS-Realtime proto
protobuf.load("gtfs-realtime.proto").then(root => {
  FeedMessage = root.lookupType("transit_realtime.FeedMessage");
  console.log("✅ GTFS-Realtime proto loaded");
});

// Vehicles endpoint
let tick = 0;

app.get("/vehicles", async (req, res) => {
  tick += 1;

  res.json([
    {
      id: "bus-101",
      latitude: 50.4452 + tick * 0.00005,
      longitude: -104.6189,
      bearing: 270,
    },
    {
      id: "bus-102",
      latitude: 50.448,
      longitude: -104.62 + tick * 0.00005,
      bearing: 90,
    },
  ]);
});

app.listen(PORT, () => {
  console.log(`🚍 Regina GTFS proxy running at http://localhost:${PORT}`);
});

const fs = require("fs");
const path = require("path");
const directionsPath = path.resolve(__dirname, "gtfs", "stop_directions.json");

let stopDirections = {};
if (fs.existsSync(directionsPath)) {
  stopDirections = JSON.parse(fs.readFileSync(directionsPath, "utf8"));
  console.log(`✅ stop_directions loaded: ${Object.keys(stopDirections).length}`);
} else {
  console.warn("⚠️ stop_directions.json not found");
}

app.get("/stops", (req, res) => {
  try {
    const filePath = path.resolve(__dirname, "gtfs", "stops.txt");
    console.log("Loading stops from:", filePath);

    const raw = fs.readFileSync(filePath, "utf8");
    const lines = raw.split(/\r?\n/).filter(Boolean);
    const header = lines[0].split(",");

    const idI = header.indexOf("stop_id");
    const nameI = header.indexOf("stop_name");
    const latI = header.indexOf("stop_lat");
    const lonI = header.indexOf("stop_lon");

    const stops = [];

    for (let i = 1; i < lines.length; i++) {
      const c = lines[i].split(",");

      const stopId = c[idI];
      const lat = parseFloat(c[latI]);
      const lon = parseFloat(c[lonI]);

      if (!stopId || isNaN(lat) || isNaN(lon)) continue;

      const score = stopDirections[stopId] ?? 0;

      stops.push({
        stop_id: stopId,
        name: c[nameI],
        lat,
        lon,
        direction:
          score > 0 ? "NB" :
          score < 0 ? "SB" :
          "UNK",
      });
    }

    res.json(stops);
  } catch (e) {
    console.error("STOP LOAD ERROR:", e.message);
    res.status(500).json({ error: "Failed to load stops" });
  }
});