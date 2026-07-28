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
POST   /api/v1/navigation/sessions
GET    /api/v1/navigation/sessions/:sessionId
PATCH  /api/v1/navigation/sessions/:sessionId/destination
POST   /api/v1/navigation/sessions/:sessionId/complete
DELETE /api/v1/navigation/sessions/:sessionId
GET    /api/v1/navigation/sessions/:sessionId/observations
POST   /api/v1/navigation/simulator/observations
POST   /api/v1/navigation/simulator/scenarios/:scenarioId/run
```

Public navigation routes do not require sign-in. The client creates a session
with `client_id`, then sends the same value in the
`x-navigation-client-id` header when reading or changing that session.
Administrative APIs outside this module keep their existing authentication.
Simulator endpoints must be disabled in production.

## Test

```powershell
npm.cmd run test:navigation
```
