# Run frontend + backend + model

The local development data flow is:

```text
Flutter app -> Node.js backend (:8097) -> Python positioning API (:8001)
                                      -> MongoDB (:27017)
```

## 1. Start MongoDB

MongoDB Server must be running. MongoDB Compass is only the client used to
inspect the database.

```powershell
Get-Service MongoDB
Start-Service MongoDB
```

## 2. Start the Python positioning model

Open a terminal:

```powershell
cd C:\Users\araya\Downloads\MFUguiding\model
.\.venv\Scripts\python.exe -m uvicorn positioning_api:app --host 127.0.0.1 --port 8001
```

Verify:

```text
http://127.0.0.1:8001/health
http://127.0.0.1:8001/docs
```

## 3. Start the Node.js backend

Open another terminal:

```powershell
cd C:\Users\araya\Downloads\MFUguiding\backend-node
npm.cmd run start:local
```

The local environment already selects the Python HTTP integration:

```env
PORT=8097
POSITIONING_MODE=http
POSITIONING_SERVICE_URL=http://127.0.0.1:8001
POSITIONING_SIMULATOR_ENABLED=true
```

Verify:

```text
http://127.0.0.1:8097/api/v1/navigation/health
http://127.0.0.1:8097/api/v1/navigation/destinations
```

## 4. Start Flutter

Android Emulator uses `10.0.2.2` to reach the Windows host:

```powershell
cd C:\Users\araya\Downloads\MFUguiding\frontend
flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8097
```

For a physical Android phone, replace `10.0.2.2` with the computer's LAN IP,
and keep the phone and computer on the same network:

```powershell
flutter run --dart-define=BACKEND_BASE_URL=http://192.168.1.10:8097
```

## Current development flow

1. The Map screen loads rooms from `GET /api/v1/navigation/destinations`.
2. Start creates an anonymous navigation session.
3. Until Cisco Controller data is connected, Flutter asks the backend to run
   the built-in RSSI scenario.
4. The backend forwards every AP/RSSI observation to the Python model.
5. The Python model returns the confirmed AP, position, and A* route.
6. Flutter displays the current position and number of route waypoints.

When the Cisco Controller integration is ready, it should submit observations
to the backend. Remove the Flutter `runSimulatorScenario` call; the remaining
session and route APIs stay unchanged.
