const express = require("express");
const fs = require("fs");
const path = require("path");

const app = express();
const PORT = 3000;

app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  next();
});

// Parse shapes.txt into a map of shape_id -> sorted array of {lat, lon}
function loadShapes() {
  const filePath = path.resolve(__dirname, "gtfs", "shapes.txt");
  const raw = fs.readFileSync(filePath, "utf8");
  const lines = raw.split(/\r?\n/).filter(Boolean);
  const header = lines[0].split(",");
  const idI = header.indexOf("shape_id");
  const latI = header.indexOf("shape_pt_lat");
  const lonI = header.indexOf("shape_pt_lon");
  const seqI = header.indexOf("shape_pt_sequence");

  const map = {};
  for (let i = 1; i < lines.length; i++) {
    const c = lines[i].split(",");
    const id = c[idI];
    const lat = parseFloat(c[latI]);
    const lon = parseFloat(c[lonI]);
    const seq = parseInt(c[seqI], 10);
    if (!id || isNaN(lat) || isNaN(lon)) continue;
    if (!map[id]) map[id] = [];
    map[id].push({ lat, lon, seq });
  }

  for (const id of Object.keys(map)) {
    map[id].sort((a, b) => a.seq - b.seq);
  }
  return map;
}

function calcBearing(a, b) {
  const lat1 = a.lat * Math.PI / 180;
  const lat2 = b.lat * Math.PI / 180;
  const dLon = (b.lon - a.lon) * Math.PI / 180;
  const y = Math.sin(dLon) * Math.cos(lat2);
  const x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);
  return (Math.atan2(y, x) * 180 / Math.PI + 360) % 360;
}

const shapes = loadShapes();
const shapeIds = Object.keys(shapes);

// Pick 15 shapes spread evenly across the 119 available
const BUS_COUNT = 15;
const step = Math.floor(shapeIds.length / BUS_COUNT);
const selectedShapes = Array.from({ length: BUS_COUNT }, (_, i) => shapeIds[i * step]);

// Build bus state: each bus starts at a different offset along its route
const buses = selectedShapes.map((shapeId, i) => {
  const points = shapes[shapeId];
  const startOffset = Math.floor((points.length / BUS_COUNT) * i);
  return { id: `bus-${i + 1}`, shapeId, pointIndex: startOffset % points.length };
});

console.log(`✅ Loaded ${shapeIds.length} shapes, simulating ${BUS_COUNT} buses`);

app.get("/vehicles", (req, res) => {
  const result = buses.map(bus => {
    const points = shapes[bus.shapeId];
    const cur = points[bus.pointIndex];
    const next = points[(bus.pointIndex + 1) % points.length];
    const bearing = calcBearing(cur, next);

    // Advance bus along route (2 points per tick)
    bus.pointIndex = (bus.pointIndex + 2) % points.length;

    return { id: bus.id, latitude: cur.lat, longitude: cur.lon, bearing };
  });

  res.json(result);
});

app.listen(PORT, () => {
  console.log(`🚍 Regina GTFS proxy running at http://localhost:${PORT}`);
});

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

      const bearing = stopDirections[stopId];
      const dirMap = { 0: 'NB', 90: 'EB', 180: 'SB', 270: 'WB' };

      stops.push({
        stop_id: stopId,
        name: c[nameI],
        lat,
        lon,
        direction: dirMap[bearing] ?? 'UNK',
      });
    }

    res.json(stops);
  } catch (e) {
    console.error("STOP LOAD ERROR:", e.message);
    res.status(500).json({ error: "Failed to load stops" });
  }
});