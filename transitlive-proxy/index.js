const express = require('express');
const fetch = require('node-fetch');
const protobuf = require('protobufjs');
const path = require('path');

const app = express();
const PORT = 3000;

// ✅ OFFICIAL Regina GTFS-Realtime Vehicle Positions feed
const VEHICLE_POSITIONS_URL =
    'https://opendata.regina.ca/gtfsrealtime/vehicle_positions.pb';

app.get('/vehicles', async (req, res) => {
    try {
        const response = await fetch(VEHICLE_POSITIONS_URL);
        if (!response.ok) {
            return res.status(500).json({ error: 'Failed to fetch GTFS-RT feed' });
        }

        const buffer = await response.arrayBuffer();

        const root = await protobuf.load(
            path.join(__dirname, 'gtfs-realtime.proto')
        );

        const FeedMessage = root.lookupType(
            'transit_realtime.FeedMessage'
        );

        const message = FeedMessage.decode(new Uint8Array(buffer));

        const vehicles = message.entity
            .filter(e => e.vehicle && e.vehicle.position)
            .map(e => ({
                id: e.vehicle.vehicle?.id ?? e.id,
                lat: e.vehicle.position.latitude,
                lon: e.vehicle.position.longitude,
                bearing: e.vehicle.position.bearing ?? 0,
                speed: e.vehicle.position.speed ?? 0,
                routeId: e.vehicle.trip?.route_id ?? null,
                tripId: e.vehicle.trip?.trip_id ?? null,
            }));

        res.json(vehicles);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'GTFS-RT parse error' });
    }
});

app.listen(PORT, () => {
    console.log(`✅ Proxy running on http://localhost:${PORT}`);
});