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

app.get("/stops", (req, res) => {
  try {
    const filePath = path.resolve(__dirname, "gtfs", "stops.txt");

    console.log("Loading stops from:", filePath);

    const raw = fs.readFileSync(filePath, "utf8");

    const lines = raw.split(/\r?\n/).filter(Boolean);
    const header = lines[0].split(",");

    const nameI = header.indexOf("stop_name");
    const latI = header.indexOf("stop_lat");
    const lonI = header.indexOf("stop_lon");

    const stops = [];

    for (let i = 1; i < lines.length; i++) {
      const c = lines[i].split(",");
      stops.push({
        name: c[nameI],
        lat: parseFloat(c[latI]),
        lon: parseFloat(c[lonI]),
      });
    }

    res.json(stops);
  } catch (e) {
    console.error("STOP LOAD ERROR:", e.message);
    res.status(500).json({ error: "Failed to load stops" });
  }
});