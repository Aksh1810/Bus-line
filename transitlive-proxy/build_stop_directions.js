const fs = require("fs");
const path = require("path");

const ROOT = __dirname;

// GTFS input lives in Flutter project:
const GTFS_IN = path.join(ROOT, "..", "assets", "gtfs");

// Output should live where server.js reads it:
const GTFS_OUT = path.join(ROOT, "gtfs");

const stopsPath = path.join(GTFS_IN, "stops.txt");
const stopTimesPath = path.join(GTFS_IN, "stop_times.txt");

// ---------- helpers ----------
function parseGtfs(raw) {
  raw = raw.replace(/^\uFEFF/, "");
  const lines = raw.split(/\r?\n/).filter((l) => l.trim().length);
  const delim = lines[0].includes("\t") ? "\t" : ",";
  return lines.map((l) => l.split(delim));
}

function toRad(d) { return (d * Math.PI) / 180; }
function toDeg(r) { return (r * 180) / Math.PI; }

function bearingDeg(aLat, aLon, bLat, bLon) {
  const lat1 = toRad(aLat);
  const lat2 = toRad(bLat);
  const dLon = toRad(bLon - aLon);

  const y = Math.sin(dLon) * Math.cos(lat2);
  const x =
    Math.cos(lat1) * Math.sin(lat2) -
    Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);

  return (toDeg(Math.atan2(y, x)) + 360) % 360;
}

// snap to 4-way icons
function snap4(b) {
  const dirs = [0, 90, 180, 270];
  let best = dirs[0], bestDiff = 999;
  for (const d of dirs) {
    const diff = Math.min(Math.abs(b - d), 360 - Math.abs(b - d));
    if (diff < bestDiff) { bestDiff = diff; best = d; }
  }
  return best;
}

// ---------- load files ----------
const stopsRaw = fs.readFileSync(stopsPath, "utf8");
const stRaw = fs.readFileSync(stopTimesPath, "utf8");

const stopsRows = parseGtfs(stopsRaw);
const stRows = parseGtfs(stRaw);

// stops map: stop_id -> {lat, lon}
const sH = stopsRows[0];
const sIdI = sH.indexOf("stop_id");
const sLatI = sH.indexOf("stop_lat");
const sLonI = sH.indexOf("stop_lon");

const stopPos = new Map();
for (let i = 1; i < stopsRows.length; i++) {
  const r = stopsRows[i];
  const id = r[sIdI];
  const lat = parseFloat(r[sLatI]);
  const lon = parseFloat(r[sLonI]);
  if (!id || Number.isNaN(lat) || Number.isNaN(lon)) continue;
  stopPos.set(id, { lat, lon });
}

// group stop_times by trip: trip_id -> [{stop_id, seq}]
const stH = stRows[0];
const tripI = stH.indexOf("trip_id");
const stopI = stH.indexOf("stop_id");
const seqI = stH.indexOf("stop_sequence");

const trips = new Map();
for (let i = 1; i < stRows.length; i++) {
  const r = stRows[i];
  const tripId = r[tripI];
  const stopId = r[stopI];
  const seq = parseInt(r[seqI] || "", 10);
  if (!tripId || !stopId || Number.isNaN(seq)) continue;
  if (!trips.has(tripId)) trips.set(tripId, []);
  trips.get(tripId).push({ stopId, seq });
}

// accumulate bearings per stop using circular mean (vector sum)
const sum = new Map(); // stop_id -> {x,y,count}
function addBearing(stopId, b) {
  const rad = toRad(b);
  const x = Math.cos(rad);
  const y = Math.sin(rad);

  const cur = sum.get(stopId) || { x: 0, y: 0, n: 0 };
  cur.x += x;
  cur.y += y;
  cur.n += 1;
  sum.set(stopId, cur);
}

// For each trip, take bearings between consecutive stops (both forward and backward to help terminals)
for (const trip of trips.values()) {
  trip.sort((a, b) => a.seq - b.seq);

  for (let i = 0; i < trip.length - 1; i++) {
    const A = trip[i].stopId;
    const B = trip[i + 1].stopId;

    const a = stopPos.get(A);
    const b = stopPos.get(B);
    if (!a || !b) continue;

    const brg = bearingDeg(a.lat, a.lon, b.lat, b.lon);

    // bearing for A using next
    addBearing(A, brg);

    // also give B an opposite bearing using previous (helps last stops)
    addBearing(B, (brg + 180) % 360);
  }
}

// finalize
const out = {};
for (const [stopId, v] of sum.entries()) {
  if (v.n < 1) continue;
  const mean = (toDeg(Math.atan2(v.y, v.x)) + 360) % 360;
  out[stopId] = snap4(mean); // store snapped 0/90/180/270
}

// ensure output dir exists
fs.mkdirSync(GTFS_OUT, { recursive: true });

// ─── WRITE OUTPUT ──────────────────────
const outPath = path.join(__dirname, "gtfs", "stop_directions.json");
fs.writeFileSync(outPath, JSON.stringify(out, null, 2));

console.log("✅ stop_directions.json created in transitlive-proxy/gtfs/");