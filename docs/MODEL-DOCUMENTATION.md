# Positioning Model and Navigation Engine

## Purpose and current scope

The Python service estimates a user's indoor **zone-level** position from Wi-Fi RSSI and produces a walkable route on the floor grid. The current release does not require a Cisco Controller. A phone normally reports its associated AP and may additionally provide readings for AP1, AP2, and AP3.

This is not centimetre-level tracking. RSSI is affected by walls, people, phone hardware, and AP roaming decisions; intermediate marker positions are estimates.

## Runtime architecture

The Flutter app sends observations to the Node.js backend. Node validates and stores them in MongoDB, then calls the Python service. The Python service keeps short-lived positioning state in memory and returns an estimated point, zone, diagnostics, and route. Node remains the public API; port 8001 is internal/diagnostic.

## HTTP API

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/health` | service and loaded-model status |
| `PUT` | `/configuration` | replace destination/AP/transition snapshot |
| `POST` | `/sessions` | create an in-memory positioning session |
| `GET` | `/sessions/{session_id}` | read current state |
| `POST` | `/sessions/{session_id}/observations` | submit Wi-Fi readings |
| `POST` | `/sessions/{session_id}/progress` | advance along a route by metres |
| `PATCH` | `/sessions/{session_id}/destination` | change target and rebuild route |
| `DELETE` | `/sessions/{session_id}` | remove in-memory state |

Example observation request:

```json
{
  "associated_ap": "AP2",
  "rssi": -63,
  "rssi_readings": { "AP1": -72, "AP2": -63, "AP3": -79 }
}
```

Important response fields include `estimated_position`, `zone`, `confirmed_ap`, `median_rssi`, `signal_band`, `confidence`, `position_source`, `route`, `route_recalculated`, roaming candidates, fingerprint diagnostics, and arrival-guard state. Errors use `{ "error": { "code": "...", "message": "..." } }` with an appropriate HTTP status.

## Positioning pipeline

1. Validate RSSI inside the configured exclusive range `(-95, -20)` dBm.
2. Keep a rolling five-sample window per navigation session and AP, then use its median to reduce spikes.
3. Confirm ordinary roaming only after three consecutive observations. A quick return to the previous AP requires five confirmations during an eight-observation guard window.
4. Convert the confirmed AP and signal band to a configured, walkable zone anchor.
5. If a complete multi-AP scan and `hybrid_model.joblib` are available, estimate a fingerprint position. The strongest-zone change must pass confirmation and margin rules before it can change the stable zone.
6. Snap accepted coordinates to the occupancy grid and project updates forward onto the remaining route when they are close enough.
7. Hold the final arrival state until its configured proximity confirmations pass.

The classifier artifact `zone_classifier.joblib` can add confidence to the AP/RSSI estimate, but it is not permission to jump into an unrelated zone. If either model artifact is missing, deterministic AP-zone anchors remain available as fallback.

## Stability rules

Configuration lives in `model/positioning/zone_config.json`. Current important defaults include:

| Setting | Value | Effect |
|---|---:|---|
| RSSI window | 5 | median smoothing |
| near / medium thresholds | -55 / -70 dBm | signal-band anchors |
| roaming confirmations | 3 | suppress AP ping-pong |
| reverse confirmations | 5 | stronger guard against immediate reversal |
| nearest-AP margin | 4 dB | prevent small changes from switching zone |
| fingerprint confirmations | 3 | stabilize multi-AP zone changes |
| maximum fingerprint move | 0.75 m/update | limit marker jumps |
| minimum fingerprint move | 0.20 m | ignore tiny jitter |
| route snap tolerance | 1.5 m | accept readings near remaining route |
| arrival radius | 1.5 m | destination proximity gate |
| arrival confirmations | 3 | avoid early completion |

The current `calibrated_fingerprints` list is empty. For better accuracy, collect labelled AP1/AP2/AP3 RSSI samples at known hallway points and retrain or add reviewed calibration entries; do not invent calibration values.

## Routing and wall safety

The engine uses A* on `floorplan/occupancy_grid.npy` with metadata in `floorplan/grid_config.json`. Start and goal positions are moved to the nearest walkable cell. Diagonal movement is permitted only when both side-adjacent cells are walkable, preventing corner cutting. Simplified paths are accepted only if every visual segment remains walkable; otherwise the raw grid path is returned.

Changing A* to Dijkstra would not improve map correctness: with the same grid they find an optimal path, while A* explores fewer cells using a heuristic. Wall accuracy depends primarily on a correct occupancy grid and coordinate transform.

## Session lifecycle and limits

Python positioning sessions are held in process memory. Restarting the model container clears them; Node/MongoDB retains the persistent navigation session and observation history and can create a new model session. For that reason the container runs one Uvicorn worker. Horizontal scaling requires shared state or session affinity.

The model only knows movement supported by incoming observations or explicit progress calls. It cannot know that the user has stopped, taken a step, or walked in the wrong direction from one associated AP alone.

## Health and verification

```powershell
curl.exe http://127.0.0.1:8001/health
docker compose exec model python -m unittest discover -s tests -v
docker compose exec backend npm run test:navigation
```

A healthy response reports `status`, `service`, `active_sessions`, `zone_model_loaded`, and `multi_ap_model_loaded`. The model test suite currently covers filtering, roaming hysteresis, positioning, routing, wall/corner safety, and session behavior.

## Calibration procedure

1. Verify AP physical coordinates, hallway anchors, destination coordinates, map scale, and occupancy grid.
2. At each labelled hallway point, remain still and record repeated RSSI readings for all visible project APs.
3. Include different phones and normal environmental conditions.
4. Split training and evaluation data by collection session, not random adjacent samples.
5. Measure zone accuracy, transition delay, false roaming, route deviation, and early arrival rate.
6. Version the dataset, generated artifact, configuration, and evaluation result together.

Never treat evaluation samples as training data or claim point-level accuracy when the available observation only supports zone-level estimation.
