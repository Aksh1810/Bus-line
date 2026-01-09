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