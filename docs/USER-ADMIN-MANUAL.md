# MFU SmartGuide User and Administrator Manual

## Before using the app

The current prototype requires:

- an Android phone with the MFU SmartGuide APK installed;
- access to the backend over the same reachable network;
- connection to the `AS-Project` Wi-Fi network for indoor positioning;
- Wi-Fi and Location enabled, with the requested Android permissions granted;
- backend, MongoDB, Redis, and Python positioning service running.

Confirm the backend from the phone browser before opening the app:

```text
http://<computer-ip>:8097/healthz
```

If this address does not respond, login and navigation cannot work. See `DOCKER-GUIDE.md` for startup and network troubleshooting.

## Sign in

1. Open MFU SmartGuide.
2. Enter the seeded email and password provided separately by the project owner.
3. Tap **SIGN IN**.
4. The backend returns the account role. A `user` enters the user application; an `admin` enters the administrator application.

The default login session lasts 24 hours. Signing out revokes the current token. Never include demonstration account passwords in this repository.

## User application

The persistent bottom navigation contains **Map**, **Favorite**, and **Settings**. It is intentionally hidden while turn-by-turn navigation is active to maximize map space and prevent accidental page switching.

### Search for a destination

1. Open **Map**.
2. Type a room number or name in the search box.
3. Select a matching suggestion. The floor map is not shown before a destination is selected.
4. Check the destination marker and information card.
5. Tap the **X** in the search field to clear the entire query when needed.

If no destination appears, verify that it is active in `Navigation_Destinations` and that the backend destinations endpoint responds.

### Save a favorite

1. Select a room on the Map page.
2. Tap **Save**.
3. Choose `Home`, `Study`, or `Others` and confirm.
4. Open **Favorite** to see the saved destination.

Adding the same destination again updates its tag. Use the delete icon on a favorite card to remove it.

### Start from Favorite

1. Open **Favorite**.
2. Tap the directions icon on the required destination.
3. The app switches back to Map with that destination selected.
4. Tap **Start** to begin navigation.

### Start indoor navigation

1. Connect the phone to `AS-Project` Wi-Fi.
2. Enable Wi-Fi and Location and grant the app's requested permission.
3. Select a destination and tap **Start**.
4. Wait while the app gathers stable Wi-Fi observations. When a zone is detected, navigation starts automatically.
5. Follow the blue route. The green marker is the estimated user position and the red marker is the destination.
6. Wi-Fi updates can move the green marker. The route behind the accepted position is removed while the stable remainder is retained.
7. On arrival, tap **Done** to close navigation.

Position is an RSSI-based estimate. It can identify a zone and approximate route position, but it cannot prove the exact point where the phone is standing. Remain in each test area long enough to collect several readings and do not treat a single jump as a final result.

### Navigation controls

- **Report** opens an app issue form with the navigation session and estimated position when available.
- **Emergency** asks for confirmation before starting a telephone call or showing assistance feedback.
- The close button cancels the active navigation session and returns to Map.
- The center-location control restores the intended map focus.

The compass/map-rotation feature has been removed from the current release.

### Report an app problem

1. Tap **Settings** and then **Report a problem**, or use **Report** during navigation.
2. Complete **Issue type**, **Screen or feature**, and **Description**.
3. Tap **Submit**.

All three fields are required. Reports are stored as `pending` and become visible to administrators. The form is for application/system problems, not building maintenance work orders.

### Profile, language, and sign out

- The profile displays the signed-in account email.
- Change English/Thai using the language control in the top bar.
- Open **Settings**, tap **Sign out**, and confirm. The app clears the local session and returns to Login.

## Administrator application

The bottom navigation contains **Dashboard**, **Notification**, and **Settings**.

### Dashboard

Dashboard summary cards show the number of rooms, access points, navigation zones, and open reports. Room/AP/zone summary cards are informational; **Open reports** remains actionable.

Use the quick actions:

- **Manage map data** to maintain floors, rooms, APs, and zones;
- **Review user reports** to inspect application issue reports.

Pull down to refresh the summary. If only some data fails, use the refresh control and check the backend health.

### Review reports

1. Open **Notification** or tap **Open reports**.
2. Select **App Issue Reports**.
3. Review the report type, reporter, location, and current status.
4. Use **Approved** or **Reject** to update the record.

The backend also supports `in_progress` and `resolved` states. The current **Emergency Alerts** tab displays prototype/demo cards and is not backed by the mobile report collection; do not present it as a completed real-time emergency system.

### Manage map data

1. Open **Dashboard → Manage map data**, or **Settings → Map data**.
2. Select `Floors`, `Destinations`, `Access points`, or `Zones`.
3. Tap **Add** to create a record, select a record to edit it, or choose **Disable** to soft-delete it.
4. Complete every required field and save.

Disabling a record sets `active: false`; it does not remove the MongoDB document. Coordinate edits can affect positioning and wall-safe routing. Back up data and verify the map after changing AP positions, anchors, transitions, destination points, scale, or transform values.

### Administrator settings

Settings displays the administrator email and contains:

- **Map data** — opens map administration;
- **Sign out** — revokes the session and returns to Login.

Language is changed only from the top bar.

## Common problems

| Message/symptom | Check |
|---|---|
| Cannot connect to backend | Docker services, current computer IP, port 8097, firewall, and phone network |
| Service Unavailable | `/api/v1/navigation/health`, MongoDB connectivity, and model health |
| Connect to AS-Project Wi-Fi | phone is connected to a different SSID |
| Enable Wi-Fi and Location | Android Location/Wi-Fi state and permissions |
| Unknown AS-Project BSSID | BSSID prefix is absent from `connected_wifi_service.dart` |
| Position stays waiting | active navigation session and valid observations have not been accepted |
| Position is in wrong zone | collect AP1/AP2/AP3 RSSI samples and review calibration/anchors |
| Login works once but later fails | backend stopped, IP changed, token expired, or session was revoked |

## Safe demonstration order

1. Show Docker services and both health endpoints.
2. Sign in as User.
3. Search for a room, save it, and select it from Favorite.
4. Start navigation using live `AS-Project` Wi-Fi.
5. Submit an app issue.
6. Sign out and sign in as Admin.
7. Show dashboard totals and update the submitted report.
8. Show map data without changing production coordinates during the demonstration.
