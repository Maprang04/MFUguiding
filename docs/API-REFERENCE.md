# MFU SmartGuide Backend API Reference

## Base URL and conventions

Local Docker URL:

```text
http://localhost:8097
```

Mobile application API prefix:

```text
/api/v1
```

Successful application responses normally use:

```json
{
  "code": 20000,
  "message": "Success",
  "data": {}
}
```

Errors normally use:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable explanation"
  }
}
```

Use `Content-Type: application/json`. Protected mobile endpoints require:

```http
Authorization: Bearer <session-token>
```

Do not put real passwords, tokens, client identifiers, or database credentials in GitLab issues or screenshots.

## Access levels

| Level | Meaning |
|---|---|
| Public | no mobile session required |
| Client-owned | requires matching `x-navigation-client-id`; currently not tied to login identity |
| User | valid Bearer token for an active user or admin |
| Admin | valid Bearer token whose user role is `admin` |

> Security note: navigation session routes currently authorize ownership using a client-generated identifier, not the signed-in user token. This is suitable only for the current controlled prototype. Before Internet deployment, add `requireAuth`, bind each navigation session to `mobileAuth.user.id`, rate-limit observations, and disable the simulator.

## Service health

### `GET /healthz`

Basic backend liveness endpoint. This is the first endpoint Docker and local troubleshooting should check.

```powershell
curl.exe http://127.0.0.1:8097/healthz
```

### `GET /api/v1/navigation/health`

Checks the navigation dependencies, including MongoDB and the positioning service. Returns HTTP `503` when the navigation stack is unavailable.

## Mobile authentication

Base path: `/api/v1/mobile-auth`

### `POST /login` — Public

Request:

```json
{
  "email": "student@example.invalid",
  "password": "example-password"
}
```

Response data:

```json
{
  "token": "<returned-once-session-token>",
  "expires_at": "2026-01-02T00:00:00.000Z",
  "user": {
    "id": "<user-id>",
    "email": "student@example.invalid",
    "role": "user"
  }
}
```

The default session lifetime is 24 hours and can be changed with `MOBILE_SESSION_HOURS`. The database stores only a SHA-256 token hash. Invalid credentials return `401 INVALID_CREDENTIALS`.

### `GET /me` — User

Validates the token and returns the public user object. This route also accepts `x-access-token`, but clients should use the Bearer header consistently.

### `POST /logout` — User

Revokes the current token and returns `{ "logged_out": true }`. Calling logout without a token is idempotent and still returns success.

## Destinations and map configuration

Base path: `/api/v1/navigation`

| Method | Path | Access | Result |
|---|---|---|---|
| `GET` | `/destinations` | Public | active destination list |
| `GET` | `/destinations/:destinationId` | Public | one destination or `404` |
| `GET` | `/access-points` | Public | active AP configuration |
| `GET` | `/map-config` | Public | floor, destinations, APs, zones and transitions used by the app |

The destination response contains identifiers, labels, floor information, and map coordinates. The app uses this endpoint for search suggestions rather than hard-coded room names.

## Navigation sessions

Navigation clients should generate and persist one opaque `client_id`, send it in the body when creating a session, then include the same value in this header for every owned-session request:

```http
x-navigation-client-id: mfu-flutter-example
```

### `POST /api/v1/navigation/sessions` — Public creation

Request:

```json
{
  "client_id": "mfu-flutter-example",
  "destination_id": "room_2",
  "start_position": { "x": 12.0, "y": 4.0 },
  "start_position_source": "user_selected"
}
```

`start_position` is optional. If omitted, the model waits for a usable Wi-Fi observation. Only one active session is allowed per client. Typical errors are `DESTINATION_NOT_FOUND` and `ACTIVE_SESSION_EXISTS`.

Session data includes status, observation freshness, destination, AP/zone/RSSI estimate, position source, confidence, route, route version, timestamps, and optional step/distance counters.

### Owned-session endpoints — Client-owned

| Method | Path | Body/purpose |
|---|---|---|
| `GET` | `/sessions/:sessionId` | return state; may mark old observations stale |
| `POST` | `/sessions/:sessionId/refresh` | return the same refreshed state |
| `PATCH` | `/sessions/:sessionId/destination` | `{ "destination_id": "room_1" }` |
| `POST` | `/sessions/:sessionId/progress` | submit progress data used by the service |
| `POST` | `/sessions/:sessionId/complete` | set status to `completed` |
| `DELETE` | `/sessions/:sessionId` | cancel the session; persistent record remains |
| `GET` | `/sessions/:sessionId/observations?limit=50` | newest observation history |

Missing client ownership returns `400 CLIENT_ID_REQUIRED`; a different client returns `403 FORBIDDEN`.

## Mobile Wi-Fi observations

### `POST /api/v1/navigation/mobile/observations` — Client-owned

The header client id must exactly match `body.client_id`.

```json
{
  "client_id": "mfu-flutter-example",
  "associated_ap": "AP2",
  "rssi": -63,
  "rssi_readings": {
    "AP1": -72,
    "AP2": -63,
    "AP3": -79
  },
  "timestamp": "2026-01-01T12:00:00.000Z",
  "observation_id": "optional-unique-id"
}
```

Rules:

- `client_id`, `associated_ap`, and a valid timestamp are required.
- RSSI must be strictly between `-95` and `-20` dBm.
- Only AP1, AP2, and AP3 values inside that range are retained from `rssi_readings`.
- The positioning model receives multi-AP data only when all three readings are valid.
- The client must already have an active navigation session.
- `observation_id` is optional and can make retries idempotent.

The endpoint returns HTTP `202`. Invalid observations are still stored with `valid: false` and a validation reason, then returned as `INVALID_RSSI` or `UNKNOWN_ACCESS_POINT`.

## Favorites

Base path: `/api/v1/mobile-content`; all routes require a User token.

| Method | Path | Body/result |
|---|---|---|
| `GET` | `/favorites` | favorites joined with active destination data |
| `POST` | `/favorites` | `{ "destination_id": "room_2", "tag": "Study" }` |
| `DELETE` | `/favorites/:destinationId` | remove the user's matching favorite |

Allowed tags are `Home`, `Study`, and `Others`. Adding the same destination again updates its tag instead of creating a duplicate.

## User reports

Base path: `/api/v1/mobile-content`

### `POST /reports` — User

```json
{
  "type": "navigation_problem",
  "location": "Floor 1 hallway",
  "description": "The route did not update after entering the next zone.",
  "navigation_session_id": "nav-example",
  "estimated_position": { "x": 12.0, "y": 4.0 }
}
```

`type`, `location`, and `description` are required. The session id and estimated position are optional. New reports start as `pending`.

### `GET /reports/mine` — User

Returns the signed-in user's reports, newest first.

### `GET /admin/reports` — Admin

Returns up to 200 reports, newest first.

### `PATCH /admin/reports/:id` — Admin

```json
{ "status": "in_progress" }
```

Allowed update values are `approved`, `rejected`, `in_progress`, and `resolved`.

## Map administration

Base path: `/api/v1/navigation/admin`; every route requires an Admin token.

Supported resource names are:

- `floors`
- `destinations`
- `access-points`
- `zones`

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/:resource` | list active records |
| `GET` | `/:resource?include_inactive=true` | include deactivated records |
| `GET` | `/:resource/:id` | read one record |
| `POST` | `/:resource` | create a validated record |
| `PATCH` | `/:resource/:id` | update allowed schema fields |
| `DELETE` | `/:resource/:id` | soft-delete by setting `active: false` |

Changing map data affects subsequent model configuration and routes. Validate coordinates and back up the database before editing a deployed map.

## Simulator endpoints

The following development-only routes exist when `POSITIONING_SIMULATOR_ENABLED=true`:

- `POST /api/v1/navigation/simulator/observations`
- `POST /api/v1/navigation/simulator/scenarios/:scenarioId/run`

Set `POSITIONING_SIMULATOR_ENABLED=false` outside a controlled development environment. These routes currently do not require authentication.

## Common status codes

| HTTP | Meaning |
|---:|---|
| `200` | successful read/update |
| `201` | resource or session created |
| `202` | observation/progress accepted |
| `400` | missing or invalid input |
| `401` | missing, expired, or revoked user token |
| `403` | wrong role or client ownership mismatch |
| `404` | destination, session, report, or map item not found |
| `409` | active session conflict or invalid state |
| `503` | backend dependency unavailable |

## Quick verification

```powershell
curl.exe http://127.0.0.1:8097/healthz
curl.exe http://127.0.0.1:8097/api/v1/navigation/health
curl.exe http://127.0.0.1:8097/api/v1/navigation/destinations
```

Use a locally obtained token for protected calls. Never commit a prepared command containing a real password or token.
