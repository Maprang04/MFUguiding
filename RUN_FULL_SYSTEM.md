# MFU SmartGuide - Full System Run and Handover Guide

Last reviewed: 30 August 2026

This document is the operational handover for running `Flutter + Node.js + Python positioning + Redis + MongoDB Atlas`. Docker is the primary review method. Local commands are included for development.

## 1. Current system behavior

```text
Android phone
  +-- reads connected AS-Project BSSID/RSSI
  +-- scans AP1/AP2/AP3 when Android permits it
  +-- sends an observation to Node.js
             |
             v
Node.js backend :8097 -- MongoDB Atlas / indoor_navigation
       |                    +-- users and sessions
       |                    +-- favorites and reports
       |                    +-- map catalog
       |                    +-- navigation observations
       v
Python positioning :8001
  +-- median RSSI and roaming/fingerprint hysteresis
  +-- stable zone and estimated map position
  +-- A* route on a 0.25-metre occupancy grid
```

The system does not currently use the Cisco Controller or GPS. Wi-Fi supplies approximate zone-level position. It cannot confirm every step, walking direction, or exact point inside a zone.

Reference coordinates:

```text
AP1 physical position = (17.00, 5.00)
AP2 physical position = (10.50, 9.75)
AP3 physical position = (2.00, 0.50)

Room 1 entrance = (15.00, 5.00)
Room 2 entrance = (15.00, 9.00)
Room 3 entrance = (11.00, 5.00)
```

Source-of-truth configuration:

- `model/positioning/zone_config.json`
- `backend-node/server/Project/navigation/config/navigation.config.js`
- MongoDB collections seeded by `seed:navigation-map`
- `frontend/lib/floor_plan_coordinates.dart`
- `frontend/lib/connected_wifi_service.dart`

Keep these sources consistent after changing AP, destination, anchor, or map coordinates.

## 2. First-time setup

Required:

- Git;
- Docker Desktop with Docker Compose;
- MongoDB Atlas credentials and Network Access permission;
- Flutter/Android SDK only for building the app;
- Android phone for live Wi-Fi tests.

Verify Docker:

```powershell
docker version
docker compose version
docker run --rm hello-world
```

If Docker Desktop reports missing virtualization, enable CPU virtualization in BIOS/UEFI and the Windows WSL/Virtual Machine Platform features, then reboot.

## 3. Configure private environment

From the repository root:

```powershell
Copy-Item backend-node/.env.example backend-node/.env
```

Edit `backend-node/.env`:

```env
NODE_ENV=development
PORT=8097
BASE_SERVER_URL=http://127.0.0.1:8097

MONGODB_ATLAS=mongodb+srv://<username>:<url-encoded-password>@<cluster-host>/indoor_navigation?retryWrites=true&w=majority
INDOOR_NAVIGATION_DB=indoor_navigation

POSITIONING_MODE=http
POSITIONING_SERVICE_URL=http://model:8001
POSITIONING_SERVICE_TIMEOUT_MS=5000
POSITIONING_SIMULATOR_ENABLED=false
NAVIGATION_OBSERVATION_SOURCE=mobile
POSITIONING_ROAMING_CONFIRMATIONS=3

REDIS_HOST=redis
REDIS_PORT=6379
MOBILE_SESSION_HOURS=24

MOBILE_USER_EMAIL=user@example.invalid
MOBILE_USER_PASSWORD=<strong-local-password>
MOBILE_ADMIN_EMAIL=admin@example.invalid
MOBILE_ADMIN_PASSWORD=<strong-local-password>
```

Use the current Atlas `mongodb+srv://` URI. Do not use the old multi-host shard URI. URL-encode reserved password characters. In Atlas, add only the reviewer's current public IP and select database `indoor_navigation`.

Never commit `.env`, `.env.local`, credentials, tokens, or real test-account passwords.

## 4. Run the complete stack with Docker

From the repository root:

```powershell
docker compose up -d --build
docker compose ps
```

Wait until `backend`, `model`, and `redis` report healthy. Follow logs if a service is not ready:

```powershell
docker compose logs --tail 100 backend
docker compose logs --tail 100 model
docker compose logs --tail 100 redis
```

Seed map data and test accounts after first setup:

```powershell
docker compose exec backend npm run seed:navigation-map
docker compose exec backend npm run seed:mobile-users
```

Expected map seed totals are one floor, three destinations, three access points, and three zones. Confirm the database target before seeding.

Health checks:

```powershell
curl.exe --noproxy "*" http://127.0.0.1:8097/healthz
curl.exe --noproxy "*" http://127.0.0.1:8097/api/v1/navigation/health
curl.exe --noproxy "*" http://127.0.0.1:8001/health
```

Expected:

- backend `/healthz` returns `OK`;
- navigation health reports backend, MongoDB, and positioning healthy;
- model reports `status: ok`, with model-loaded flags visible.

Manage the stack:

```powershell
docker compose stop
docker compose start
docker compose restart backend
docker compose down
```

Avoid `docker compose down -v` unless deleting local Docker data is intentional.

## 5. Check the computer IP before phone testing

The LAN IP may change every day due to DHCP. Check it every time:

```powershell
ipconfig
```

Use the IPv4 address of the active Wi-Fi adapter, not a disconnected adapter, VPN, WSL, VirtualBox, or Docker interface. Verify the backend is listening:

```powershell
netstat -ano | findstr :8097
curl.exe --noproxy "*" http://127.0.0.1:8097/healthz
curl.exe --noproxy "*" http://<computer-ip>:8097/healthz
```

Then open on the phone:

```text
http://<computer-ip>:8097/healthz
```

Continue only when the phone displays `OK`. Otherwise check:

- phone and computer can communicate on the network;
- Windows Firewall permits inbound TCP 8097 on the active profile;
- Docker publishes `0.0.0.0:8097`;
- the Wi-Fi network does not use client isolation;
- a proxy/VPN is not intercepting local traffic.

## 6. Build and install the APK

An installed release APK embeds `BACKEND_BASE_URL`; it cannot discover a changed IP automatically.

```powershell
cd frontend
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define=BACKEND_BASE_URL=http://<computer-ip>:8097
```

APK location:

```text
frontend/build/app/outputs/flutter-apk/app-release.apk
```

Open its folder:

```powershell
explorer .\build\app\outputs\flutter-apk
```

Transfer the APK to Android, allow **Install unknown apps** for the file-opening application, and install it. Installing over the existing app preserves local data only when package id and signing key match. A signing mismatch requires uninstalling the old app, which removes its local data.

If the computer IP changes, repeat the phone-browser health test and rebuild the APK with the new IP.

### USB development alternative

```powershell
cd frontend
flutter devices
adb -s <device-id> reverse tcp:8097 tcp:8097
flutter run -d <device-id> --dart-define=BACKEND_BASE_URL=http://127.0.0.1:8097
```

During `flutter run`, press `r` for Hot Reload and `R` for Hot Restart.

### Android emulator alternative

```powershell
cd frontend
flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8097
```

An emulator cannot perform the real building Wi-Fi/BSSID acceptance test.

## 7. Live Wi-Fi positioning test

1. Confirm all three Docker services are healthy.
2. Confirm the phone can open `http://<computer-ip>:8097/healthz`.
3. Connect Android to SSID `AS-Project`.
4. Enable Wi-Fi and Location.
5. Grant Location and Nearby Wi-Fi permissions requested by the app.
6. Sign in as a User.
7. Search and select a destination.
8. Tap **Start** and wait for stable observations.
9. Test known labelled points near AP1, AP2, and AP3.
10. Walk a planned AP3 -> AP2 or AP2 -> AP1 transition.
11. Confirm the marker does not repeatedly ping-pong and the route never crosses a wall.
12. Record failures with timestamp, true test point, associated AP, all available RSSI readings, destination, and phone model.

The app recognizes project APs by BSSID prefix in `frontend/lib/connected_wifi_service.dart`. `Unknown AS-Project BSSID` means the physical BSSID is missing or mapped incorrectly. Verify the controller/AP inventory before changing this mapping.

Current stability behavior:

- five-sample median RSSI filter;
- three confirmations for ordinary roaming;
- stronger guard for an immediate reverse roam;
- nearest-AP/fingerprint margin and confirmation rules;
- small position changes ignored and large per-update moves limited;
- accepted updates projected forward when close to the remaining route;
- arrival guarded by proximity confirmations.

The marker must not move merely because time passes. It moves when the backend/model accepts evidence from Wi-Fi observations or an explicit progress call.

## 8. Run without Docker (development fallback)

Docker is the required review method. Use this only for development.

Create `backend-node/.env.local` from `.env.example` and change service hosts for local processes:

```env
PORT=8097
POSITIONING_SERVICE_URL=http://127.0.0.1:8001
REDIS_HOST=127.0.0.1
```

Terminal 1 - model:

```powershell
cd model
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m uvicorn positioning_api:app --host 0.0.0.0 --port 8001
```

Terminal 2 - backend:

```powershell
cd backend-node
npm.cmd install
npm.cmd run start:local
```

Local Redis is required for the complete backend health state. Running only Node and model may show Redis connection errors.

## 9. Automated tests

Docker:

```powershell
docker compose exec model python -m unittest discover -s tests -v
docker compose exec backend npm run test:navigation
```

Flutter:

```powershell
cd frontend
flutter analyze
flutter test
```

Use `docs/ACCEPTANCE-TESTS.md` for manual User/Admin/Wi-Fi acceptance. Store only anonymized test evidence.

## 10. MongoDB verification

Open Atlas Data Explorer and select `indoor_navigation`. Expected collections:

```text
Mobile_Users
Mobile_Sessions
Mobile_Favorites
Mobile_Reports
Navigation_Floors
Navigation_Destinations
Navigation_Access_Points
Navigation_Zones
Navigation_Sessions
Navigation_Observations
```

For a positioning investigation, filter `Navigation_Observations` by the current `sessionId` or `clientId`, sort `timestamp` descending, and compare:

- `associatedAp`;
- `rssi`;
- `rssiReadings` for AP1/AP2/AP3;
- `source`, `valid`, and `validationError`;
- timestamp order and gaps.

Do not paste real email, token, database URI, or raw client id into public issues.

## 11. Troubleshooting

### `Cannot connect to backend` / `No route to host`

The backend is stopped, the APK contains an old IP, the firewall blocks port 8097, or the phone cannot route to the computer. Recheck section 5 from the phone before rebuilding.

### `/healthz` returns `503 Service Unavailable`

Inspect backend logs and MongoDB connectivity:

```powershell
docker compose logs --tail 150 backend
```

Check the Atlas Network Access list, current `mongodb+srv://` URI, URL-encoded password, and database name.

### Navigation health fails while `/healthz` works

```powershell
docker compose ps
docker compose logs --tail 150 model
curl.exe http://127.0.0.1:8001/health
```

Verify `POSITIONING_SERVICE_URL=http://model:8001` inside Docker.

### Login works and later stops

Check backend reachability first. A login session defaults to 24 hours, but logout revokes it immediately. Restarting the phone app does not restart the backend.

### Position is waiting

Verify `AS-Project`, Location/Wi-Fi permissions, a recognized BSSID, an active navigation session, and new valid observations in MongoDB.

### Position is wrong or jumps zones

Do not tune from one RSSI reading. Collect repeated labelled AP1/AP2/AP3 samples, verify physical/AP anchor coordinates, then evaluate fingerprint and hysteresis settings. RSSI differs across phones and environmental conditions.

### Route crosses a wall

Check `model/floorplan/occupancy_grid.npy`, `grid_config.json`, map transform, and destination/anchor points. A correct pathfinder cannot compensate for a wrong occupancy grid.

### `flutter pub get` requests Windows Developer Mode

Flutter plugins require symlink support. Open:

```powershell
start ms-settings:developers
```

Enable Developer Mode, reopen PowerShell, and rerun the command.

## 12. Files to read before modifying the project

| Area | Files |
|---|---|
| Docker | `docker-compose.yml`, `backend-node/Dockerfile`, `model/Dockerfile` |
| Backend environment | `backend-node/.env.example` |
| Authentication/content | `backend-node/server/Project/mobile-auth/`, `mobile-content/` |
| Navigation backend | `backend-node/server/Project/navigation/` |
| Positioning | `model/positioning/service.py`, `zone_config.json` |
| Routing | `model/navigation/astar.py`, `model/floorplan/` |
| Android Wi-Fi | `frontend/lib/connected_wifi_service.dart` |
| User navigation UI | `frontend/lib/map_screen.dart`, `map_start.dart` |
| App shells | `frontend/lib/app_shells.dart` |
| Documentation | `README.md`, `docs/` |

## 13. GitLab handover checklist

1. Rotate any credential previously exposed in chat, screenshots, or Git history.
2. Confirm `.env`, `.env.local`, APKs, signing keys, and caches are ignored.
3. Run every automated test and relevant acceptance test.
4. Review all modified and untracked files; do not stage virtual-environment caches.
5. Commit source, Docker configuration, environment examples, and documentation.
6. Push to the MFU GitLab repository using the university account.
7. Add the instructor as a project member with the required role.
8. Send the repository URL and credentials separately; never place credentials in Git.
9. Ask the instructor to follow `README.md` and `docs/DOCKER-GUIDE.md` from a clean clone.
10. Schedule the examination only after the clean-clone Docker run and acceptance checklist pass.

Suggested verification before staging:

```powershell
git status --short
git diff --check
git diff
git ls-files | Select-String -Pattern "(^|/)\.env($|\.)|\.apk$|\.jks$|\.keystore$"
```

## 14. Known work remaining

- collect a labelled multi-phone Wi-Fi fingerprint dataset;
- quantify zone accuracy and transition delay;
- bind navigation session ownership to authenticated user ids;
- secure or disable simulator endpoints outside development;
- replace demonstration Emergency Alerts with a real, tested backend or remove the tab;
- decide deployment networking so release APKs do not depend on a changing laptop DHCP address;
- define a production Android signing and update process;
- run a clean-clone review on another computer.

These limitations must remain visible in the project report and demonstration.
