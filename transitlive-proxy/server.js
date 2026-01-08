const express = require("express");
const fetch = require("node-fetch");

const app = express();

app.get("/vehicles", async (req, res) => {
  try {
    const url = `https://transitlive.com/mobile/updatedBuses.js?_=${Date.now()}`;

    const response = await fetch(url, {
      headers: {
        "User-Agent": "Mozilla/5.0",
        "Referer": "https://transitlive.com/mobile/livemap.php",
        "Accept": "*/*"
      }
    });

    const text = await response.text();

    if (!text.includes("bus")) {
      return res.status(500).json({
        error: "No bus data in JS",
        preview: text.slice(0, 200)
      });
    }

    res.json({
      raw: text
    });

  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.listen(3000, () =>
  console.log("Proxy running on http://localhost:3000")
);