# Navigation Backend MVP

The module is mounted at `/api/v1/navigation` and defaults to an in-process
mock positioning client. It does not read Python model source or model files.

## Configuration

```env
POSITIONING_MODE=mock
POSITIONING_SIMULATOR_ENABLED=true
POSITIONING_STALE_AFTER_MS=10000
POSITIONING_ROAMING_CONFIRMATIONS=3
POSITIONING_SERVICE_URL=http://127.0.0.1:8001
POSITIONING_SERVICE_TIMEOUT_MS=5000
```

Set `POSITIONING_MODE=http` after the Python positioning API is available.

## Main endpoints

```text
GET    /api/v1/navigation/health
GET    /api/v1/navigation/destinations
GET    /api/v1/navigation/access-points
GET    /api/v1/navigation/map-config
GET    /api/v1/navigation/admin/:resource
POST   /api/v1/navigation/admin/:resource
PATCH  /api/v1/navigation/admin/:resource/:id
DELETE /api/v1/navigation/admin/:resource/:id
POST   /api/v1/navigation/sessions
GET    /api/v1/navigation/sessions/:sessionId
PATCH  /api/v1/navigation/sessions/:sessionId/destination
POST   /api/v1/navigation/sessions/:sessionId/complete
DELETE /api/v1/navigation/sessions/:sessionId
GET    /api/v1/navigation/sessions/:sessionId/observations
POST   /api/v1/navigation/simulator/observations
POST   /api/v1/navigation/simulator/scenarios/:scenarioId/run
POST   /api/v1/navigation/controller/observations
```

Public navigation routes do not require sign-in. The client creates a session
with `client_id`, then sends the same value in the
`x-navigation-client-id` header when reading or changing that session.
Administrative APIs outside this module keep their existing authentication.
Simulator endpoints must be disabled in production.

## Cisco controller ingestion

The controller-specific poller normalizes vendor responses into:

```json
{
  "observation_id": "unique-controller-event-id",
  "client_id": "same-id-used-to-create-the-navigation-session",
  "associated_ap": "controller AP name, ID, or BSSID",
  "rssi": -65,
  "timestamp": "2026-07-30T10:00:00Z"
}
```

Send the observation with `x-controller-api-key`. AP identifiers are resolved
against `apId`, `controllerApId`, or `bssid` in
`Navigation_Access_Points`. Duplicate, stale, future, unknown-AP, and invalid
RSSI observations are rejected before they affect positioning.

Copy the relevant values from `.env.navigation.example` into `.env.local`.
After the Cisco administrator supplies the controller URL, clients path,
credentials, and response field names, test a one-shot poll with:

```powershell
npm.cmd run poll:cisco
```

## Test

```powershell
npm.cmd run test:navigation
```

## MongoDB map catalog

Floor calibration, destinations, access points, and zones are stored in:

- `Navigation_Floors`
- `Navigation_Destinations`
- `Navigation_Access_Points`
- `Navigation_Zones`

Seed local/Atlas data with:

```powershell
npm.cmd run seed:navigation-map
```

`GET /api/v1/navigation/map-config` returns the complete catalog snapshot.
When `POSITIONING_MODE=http`, the backend sends this snapshot to the Python
positioning service before creating a positioning session. This keeps Flutter,
Node.js, and Python on the same destination/AP/zone coordinates.

Admin map routes require `Authorization: Bearer <token>` from a mobile-auth
session whose user has the `admin` role. Supported resources are `floors`,
`destinations`, `access-points`, and `zones`. DELETE performs a soft delete by
setting `active` to false.
