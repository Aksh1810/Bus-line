const fs = require("fs");
const path = require("path");

// Absolute base path (project root)
const ROOT = __dirname;

// Correct GTFS paths
const stopTimesPath = path.join(ROOT, "assets/gtfs/stop_times.txt");
const tripsPath     = path.join(ROOT, "assets/gtfs/trips.txt");

// Read files
const stopTimes = fs.readFileSync(stopTimesPath, "utf8").trim().split("\n");
const trips     = fs.readFileSync(tripsPath, "utf8").trim().split("\n");

const tripDir = {};
const stopScore = {};

// ─────────────────────────────
// Parse trips.txt
// ─────────────────────────────
const tripHeader = trips[0].split(",");
const tripIdI = tripHeader.indexOf("trip_id");
const dirI    = tripHeader.indexOf("direction_id");

for (let i = 1; i < trips.length; i++) {
  const r = trips[i].split(",");
  if (!r[tripIdI]) continue;
  tripDir[r[tripIdI]] = parseInt(r[dirI] || "0", 10);
}

// ─────────────────────────────
// Parse stop_times.txt
// ─────────────────────────────
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

// ─────────────────────────────
// Write output
// ─────────────────────────────
const outPath = path.join(ROOT, "assets/gtfs/stop_directions.json");

fs.writeFileSync(outPath, JSON.stringify(stopScore, null, 2));

console.log("✅ stop_directions.json created at assets/gtfs/");