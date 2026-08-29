# MFU SmartGuide Project Overview

## Project summary

MFU SmartGuide is an Android indoor-navigation application for a university
building. A user selects a room, the phone reads nearby Wi-Fi access-point
signals, and the system estimates a coarse indoor zone before displaying a
walkable route on the floor plan.

The project also includes an administrator interface for maintaining map data
and reviewing reports submitted by mobile users.

## Project goals

- Help users find room entrances inside a building where GPS is unreliable.
- Use the building's existing Wi-Fi infrastructure without requiring a Cisco
  controller connection for the current release.
- Keep routes on walkable floor-plan cells and prevent wall-crossing paths.
- Separate User and Admin permissions.
- Provide a reproducible Docker setup for the Backend and Positioning Model.

## Current scope

The submitted release supports one floor, three navigation zones, three access
points, and three room entrances.

### Access points

| AP | Position (metres) | Zone |
|---|---:|---|
| AP1 | `(17.00, 5.00)` | `RIGHT_WING` |
| AP2 | `(10.50, 9.75)` | `CENTRAL_HALLWAY` |
| AP3 | `(2.00, 0.50)` | `LEFT_WING` |

### Destinations

| Destination | Position (metres) |
|---|---:|
| Room 1 entrance | `(15.00, 5.00)` |
| Room 2 entrance | `(15.00, 9.00)` |
| Room 3 entrance | `(11.00, 5.00)` |

Coordinates use the project floor-plan coordinate system. Navigation uses a
0.25-metre occupancy grid.

## Main components

| Component | Technology | Directory | Responsibility |
|---|---|---|---|
| Mobile application | Flutter/Dart and Android Kotlin | `frontend/` | UI, Wi-Fi scanning, motion detection, navigation display |
| Backend API | Node.js/Express | `backend-node/` | Authentication, permissions, map catalog, reports, navigation orchestration |
| Positioning API | Python/FastAPI | `model/` | RSSI filtering, zone estimation, route progress, path calculation |
| Database | MongoDB Atlas | External service | Users, sessions, favorites, reports, map data, observations |
| Runtime support | Redis | Docker service | Backend runtime/cache support |

## User functions

- Sign in and sign out.
- Search rooms by name or number with live suggestions.
- Clear the active search query.
- Add and remove favorite destinations.
- Start navigation from the Map or Favorite page.
- Detect an initial zone from Wi-Fi observations.
- View the route, current estimated marker, and destination.
- Submit application/system reports to an administrator.
- View the signed-in user's name in Settings.

## Administrator functions

- Sign in with the Admin role.
- View counts for rooms, access points, zones, and open reports.
- Maintain floor, destination, access-point, and zone records.
- View reports submitted by users and update report status.
- Use a navigation/header layout consistent with the User application.
- Sign out and remove the local session.

## Positioning approach

The Android application requests Wi-Fi scan results and maps known BSSID
prefixes to AP1, AP2, and AP3. Each observation can include:

- the access point currently associated with the phone;
- the associated RSSI;
- cached or newly scanned RSSI values for known APs.

The Positioning Model then:

1. Rejects invalid RSSI values outside the configured range.
2. Applies a median window of five readings to reduce short noise spikes.
3. Uses the nearest/strongest known AP as the primary zone signal.
4. Requires a 4 dB margin before changing the nearest AP candidate.
5. Requires three confirmations for a normal zone transition.
6. Requires five confirmations for a rapid reverse transition.
7. Uses configured hallway anchors instead of claiming exact GPS-like
   coordinates.

The current configuration enables stable-zone navigation and does not use the
three-AP fingerprint as the initial exact coordinate. Multi-AP values still
support signal comparison and model availability, but the reported location
must be understood as a zone-level estimate.

## Route generation and movement

- The floor plan is converted to a 0.25-metre occupancy grid.
- A* searches only walkable cells.
- Diagonal movement is rejected when it would cut across a wall corner.
- Simplified segments are checked again against the occupancy grid.
- The route begins at the estimated marker and removes passed segments.
- Monotonic route progress prevents signal noise from pulling the marker
  backwards on the same route.
- The Android accelerometer determines whether the phone is moving. Motion
  progress advances the estimate; it is not a measurement of every real step.
- Arrival requires stable destination evidence configured by the model.

## Authentication and authorization

Mobile users are stored separately from legacy accounts. The Backend creates a
mobile session with a default lifetime of 24 hours. User and Admin roles select
different application shells and API permissions.

Passwords and active environment values must remain in ignored `.env` files.
Only placeholder `.env.example` files belong in Git.

## Database

The active MongoDB Atlas database is:

```text
indoor_navigation
```

Primary collections include:

- `Mobile_Users`
- `Mobile_Sessions`
- `Mobile_Favorites`
- `Mobile_Reports`
- `Navigation_Floors`
- `Navigation_Destinations`
- `Navigation_Access_Points`
- `Navigation_Zones`
- `Navigation_Sessions`
- `Navigation_Observations`

## Deployment

Docker Compose runs Redis, the Python Model, and the Node.js Backend. The
Flutter application is distributed as an Android APK because native Android
Wi-Fi and motion APIs are not available inside a web/container frontend.

See [DOCKER-GUIDE.md](DOCKER-GUIDE.md) for the complete deployment procedure.

## Known limitations

- This is Wi-Fi zone positioning, not indoor GPS.
- RSSI varies by phone model, body orientation, walls, interference, and AP
  load.
- Android can throttle Wi-Fi scans, so a reading may come from the scan cache.
- A phone can remain associated with an AP that is no longer physically
  closest.
- Failure of an AP reduces positioning confidence and zone coverage.
- The route marker is an estimate and should not be interpreted as a surveyed
  real-time coordinate.
- The current deployment does not require or poll a Cisco wireless controller.
- An APK built with a fixed Backend IP must be rebuilt when that IP changes.

## Validation status

At the time this document was prepared:

- Python Model tests passed: 32/32.
- Backend navigation tests passed: 11/11.
- Redis, Model, and Backend Docker containers reported healthy.
- Backend reported MongoDB and positioning services as available.
- Navigation map and mobile account seed commands completed successfully.
