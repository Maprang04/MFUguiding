# MFU SmartGuide Docker Guide

This guide starts the server-side MFU SmartGuide stack with Docker Compose.
It is written for a reviewer who has cloned the repository and has not seen
the development environment before.

## What Docker runs

| Service | Container port | Host port | Purpose |
|---|---:|---:|---|
| `redis` | `6379` | Not published | Backend cache and runtime support |
| `model` | `8001` | `127.0.0.1:8001` | Python positioning and routing API |
| `backend` | `8082` | `0.0.0.0:8097` | Mobile authentication, content, reports, and navigation API |

The Flutter Android application is not run inside Docker. Install the APK on
an Android phone and configure it to call `http://<computer-ip>:8097`.

```text
Android APK -> Backend container -> Model container
                         |
                         +-> Redis container
                         +-> MongoDB Atlas
```

## Prerequisites

- Docker Desktop with the Linux/WSL 2 engine running
- Git
- A MongoDB Atlas database user with access to `indoor_navigation`
- The current computer IP allowed in Atlas `Security > Network Access`
- Ports `8001` and `8097` available on the host

Verify Docker before continuing:

```powershell
docker version
docker compose version
docker run --rm hello-world
```

## 1. Clone the repository

```powershell
git clone <gitlab-repository-url> MFUguiding
cd MFUguiding
```

## 2. Create the Backend environment file

Windows PowerShell:

```powershell
Copy-Item backend-node\.env.example backend-node\.env
```

Linux/macOS shell:

```bash
cp backend-node/.env.example backend-node/.env
```

Edit `backend-node/.env` and replace only local placeholder values. At a
minimum, set a valid MongoDB Atlas URI and seed-account passwords:

```env
MONGODB_ATLAS=mongodb+srv://<username>:<url-encoded-password>@<cluster-host>/indoor_navigation?retryWrites=true&w=majority
INDOOR_NAVIGATION_DB=indoor_navigation

MOBILE_USER_EMAIL=<test-user-email>
MOBILE_USER_PASSWORD=<strong-test-password>
MOBILE_ADMIN_EMAIL=<test-admin-email>
MOBILE_ADMIN_PASSWORD=<strong-test-password>
```

Keep these Docker networking values unchanged:

```env
POSITIONING_MODE=http
POSITIONING_SERVICE_URL=http://model:8001
REDIS_HOST=redis
REDIS_PORT=6379
```

Never commit `backend-node/.env`. The repository intentionally tracks only
the placeholder file `backend-node/.env.example`.

If the MongoDB password contains reserved URL characters, URL-encode it before
placing it in the connection string. Examples: `@` becomes `%40`, `#` becomes
`%23`, and `%` becomes `%25`.

## 3. Build and start the stack

Run this command from the repository root:

```powershell
docker compose up --build -d
```

The first build downloads Python scientific packages and can take several
minutes. Later builds normally reuse the Docker cache.

## 4. Check container status

```powershell
docker compose ps
```

Wait until all services show `healthy`:

```text
redis    Up (healthy)
model    Up (healthy)
backend  Up (healthy)
```

## 5. Verify health endpoints

PowerShell:

```powershell
curl.exe --noproxy "*" --fail http://127.0.0.1:8001/health
curl.exe --noproxy "*" --fail http://127.0.0.1:8097/healthz
curl.exe --noproxy "*" --fail http://127.0.0.1:8097/api/v1/navigation/health
```

Expected positioning fields:

```json
{
  "status": "ok",
  "zone_model_loaded": true,
  "multi_ap_model_loaded": true
}
```

Expected navigation services:

```json
{
  "backend": "ok",
  "mongodb": "ok",
  "positioning_engine": "ok",
  "observation_source": "mobile"
}
```

The exact response includes additional fields and timestamps.

## 6. Seed required data

Seed the floor, destinations, access points, and zones:

```powershell
docker compose exec -T backend npm run seed:navigation-map
```

Expected counts:

```json
{"seeded":{"floors":1,"destinations":3,"access_points":3,"zones":3}}
```

Seed or update the test User and Admin configured in `backend-node/.env`:

```powershell
docker compose exec -T backend npm run seed:mobile-users
```

Both seed commands are designed to update matching records instead of deleting
the database.

## 7. Connect an Android phone

Find the computer IPv4 address:

```powershell
ipconfig
```

The phone and computer must be reachable on the same network. From the phone's
browser, open:

```text
http://<computer-ip>:8097/healthz
```

It must display `OK` before testing the APK. If Windows Firewall prompts for
Node/Docker network access, allow Private networks used for the demonstration.

The APK must have been built with:

```text
BACKEND_BASE_URL=http://<computer-ip>:8097
```

## 8. View logs

All services:

```powershell
docker compose logs --tail=100
```

One service:

```powershell
docker compose logs --tail=100 backend
docker compose logs --tail=100 model
docker compose logs --tail=100 redis
```

Follow logs continuously:

```powershell
docker compose logs -f backend model
```

Press `Ctrl+C` to stop following logs. This does not stop the containers.

## 9. Restart or stop the stack

Restart without rebuilding:

```powershell
docker compose restart
```

Stop and remove containers while preserving the Redis volume:

```powershell
docker compose down
```

Start the existing images again:

```powershell
docker compose up -d
```

## Troubleshooting

### `backend-node/.env` not found

Create it from the example file as described in step 2. Do not rename or
commit the real environment file.

### Backend is unhealthy or `/healthz` returns 503

```powershell
docker compose logs --tail=100 backend
```

Check the Atlas URI, database-user password, Atlas Network Access allow list,
and database name. The required database is `indoor_navigation`.

### Positioning engine is unavailable

```powershell
docker compose ps model
docker compose logs --tail=100 model
curl.exe --noproxy "*" http://127.0.0.1:8001/health
```

Inside Docker, the Backend must use `http://model:8001`, not
`http://127.0.0.1:8001`.

### Port 8001 or 8097 is already in use

Stop locally running Uvicorn/Node terminals before starting Compose. To find
the process on Windows:

```powershell
netstat -ano | findstr :8001
netstat -ano | findstr :8097
```

### Phone cannot reach the Backend

1. Confirm `docker compose ps` publishes Backend on `0.0.0.0:8097`.
2. Test `http://127.0.0.1:8097/healthz` on the computer.
3. Test `http://<computer-ip>:8097/healthz` on the computer.
4. Test the same computer-IP URL on the phone.
5. Check that the network does not isolate wireless clients.
6. Check Windows Firewall Private-network access.

## Current validation result

The project Docker setup was validated on Windows with Docker Desktop:

- Model image built successfully
- Model container reported healthy
- `zone_model_loaded: true`
- `multi_ap_model_loaded: true`
- Redis, Model, and Backend containers reported healthy
- Backend reported MongoDB and positioning engine as `ok`
- Navigation map seed completed with 1 floor, 3 destinations, 3 APs, and 3 zones
- Mobile User/Admin seed completed successfully
