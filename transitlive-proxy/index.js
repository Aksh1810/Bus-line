const express = require("express");

const app = express();
const PORT = 3000;

// TEMP mock endpoint (matches what Flutter needs)
app.get("/vehicles", (req, res) => {
  res.json([
    {
      id: "bus-101",
      latitude: 50.4452,
      longitude: -104.6189,
      bearing: 270
    },
    {
      id: "bus-102",
      latitude: 50.448,
      longitude: -104.62,
      bearing: 90
    }
  ]);
});

app.listen(PORT, () => {
  console.log(`🚍 API running at http://localhost:${PORT}`);
});