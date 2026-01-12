const fs = require("fs");
const path = require("path");

// transitlive-proxy directory
const ROOT = __dirname;

// 👇 GTFS is one level UP, inside bus_line/assets/gtfs
const GTFS_DIR = path.join(ROOT, "..", "assets", "gtfs");

const stopTimesPath = path.join(GTFS_DIR, "stop_times.txt");
const tripsPath     = path.join(GTFS_DIR, "trips.txt");

// Read files
const stopTimes = fs.readFileSync(stopTimesPath, "utf8").trim().split("\n");
const trips     = fs.readFileSync(tripsPath, "utf8").trim().split("\n");

const tripDir = {};
const stopScore = {};

// ─── trips.txt ─────────────────────────
const tripHeader = trips[0].split(",");
const tripIdI = tripHeader.indexOf("trip_id");
const dirI    = tripHeader.indexOf("direction_id");

for (let i = 1; i < trips.length; i++) {
  const r = trips[i].split(",");
  if (!r[tripIdI]) continue;
  tripDir[r[tripIdI]] = parseInt(r[dirI] || "0", 10);
}

// ─── stop_times.txt ────────────────────
const stopHeader = stopTimes[0].split(",");
const stopI = stopHeader.indexOf("stop_id");
const tripI = stopHeader.indexOf("trip_id");

for (let i = 1; i < stopTimes.length; i++) {
  const r = stopTimes[i].split(",");
  if (!r[stopI] || !r[tripI]) continue;

  const dir = tripDir[r[tripI]];
  if (dir === undefined) continue;

  stopScore[r[stopI]] ??= 0;
  stopScore[r[stopI]] += dir === 0 ? 1 : -1;
}

// ─── WRITE OUTPUT ──────────────────────
const outPath = path.join(ROOT, "gtfs", "stop_directions.json");
fs.writeFileSync(outPath, JSON.stringify(stopScore, null, 2));

console.log("✅ stop_directions.json created");