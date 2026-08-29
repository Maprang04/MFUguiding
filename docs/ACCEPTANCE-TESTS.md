# MFU SmartGuide Acceptance Test Checklist

Use this checklist before inviting a reviewer or scheduling the project examination. Record date, tester, phone model, Android version, APK version/commit, network, and result for every test run.

Result values: `PASS`, `FAIL`, `BLOCKED`, or `NOT APPLICABLE`.

## Environment checks

| ID | Test | Expected result | Result |
|---|---|---|---|
| ENV-01 | `docker compose up -d --build` | backend, model, and Redis start | |
| ENV-02 | `docker compose ps` | all services show healthy | |
| ENV-03 | Open `/healthz` on computer | response is `OK` | |
| ENV-04 | Open navigation health | backend, MongoDB, and positioning are healthy | |
| ENV-05 | Open computer health URL from phone | phone can reach port 8097 | |
| ENV-06 | Verify `.env` with `git status` | no secret environment file is tracked | |

## Authentication and roles

| ID | Test | Expected result | Result |
|---|---|---|---|
| AUTH-01 | Login with missing fields | clear validation/error; no login | |
| AUTH-02 | Login with incorrect password | `INVALID_CREDENTIALS`; no sensitive detail | |
| AUTH-03 | Login with User account | User shell opens | |
| AUTH-04 | Restart app before expiry | valid session is restored | |
| AUTH-05 | Logout and reopen app | login screen appears; old token is unusable | |
| AUTH-06 | Login with Admin account | Admin shell opens | |
| AUTH-07 | User token calls admin report/map API | request is rejected with `403` | |

## User interface and content

| ID | Test | Expected result | Result |
|---|---|---|---|
| UI-01 | Switch Map, Favorite, Settings | one persistent bottom bar; correct selected item | |
| UI-02 | Change language from top bar | visible labels switch language | |
| UI-03 | Open Settings | signed-in user email is displayed | |
| UI-04 | Open Map without destination | floor map remains hidden | |
| UI-05 | Type partial room name/number | matching suggestions appear | |
| UI-06 | Tap search-field X | complete query and current selection are cleared | |
| UI-07 | Select a suggestion | map and destination information appear | |

## Favorites and reports

| ID | Test | Expected result | Result |
|---|---|---|---|
| CNT-01 | Save a destination | item appears in Favorite | |
| CNT-02 | Save it again with another tag | existing favorite updates; no duplicate | |
| CNT-03 | Navigate from Favorite | Map opens with the chosen destination | |
| CNT-04 | Remove favorite | item disappears after refresh | |
| CNT-05 | Submit incomplete report | submission is blocked | |
| CNT-06 | Submit complete app issue | success appears; status is pending | |
| CNT-07 | Open Admin reports | newly submitted issue is visible | |
| CNT-08 | Admin approves/rejects report | status persists after refresh | |

## Live Wi-Fi positioning

Run these tests on `AS-Project`, not simulated data. Record the raw AP/RSSI observations for failures.

| ID | Test | Expected result | Result |
|---|---|---|---|
| POS-01 | Deny Location permission | app explains that Wi-Fi/Location is required | |
| POS-02 | Connect to another SSID | app asks for `AS-Project` | |
| POS-03 | Start at known AP1 test point | stable detected zone matches labelled ground truth | |
| POS-04 | Start at known AP2 test point | stable detected zone matches labelled ground truth | |
| POS-05 | Start at known AP3 test point | stable detected zone matches labelled ground truth | |
| POS-06 | Remain still for 20 seconds | marker does not repeatedly ping-pong between zones | |
| POS-07 | Walk AP3 → AP2 | transition occurs after confirmation, not one sample | |
| POS-08 | Walk AP2 → AP1 | marker moves forward on route; no large backward jump | |
| POS-09 | Brief RSSI spike/weak sample | median/hysteresis prevents immediate zone switch | |
| POS-10 | Scan returns all three APs | observation contains AP1/AP2/AP3 and multi-AP diagnostic is usable | |
| POS-11 | Scan contains fewer than three APs | associated-AP fallback continues without crash | |
| POS-12 | Stop sending observations | session becomes stale rather than inventing movement | |

## Navigation and map safety

| ID | Test | Expected result | Result |
|---|---|---|---|
| NAV-01 | Start navigation | bottom navigation is hidden | |
| NAV-02 | Route to Room 1 | blue route ends at Room 1 entrance | |
| NAV-03 | Route to Room 2 | blue route ends at Room 2 entrance | |
| NAV-04 | Route to Room 3 | blue route ends at Room 3 entrance | |
| NAV-05 | Inspect every route segment | no line crosses a wall or cuts a blocked corner | |
| NAV-06 | Accept a marker update | only marker-connected route start changes; remainder stays stable | |
| NAV-07 | Approach destination | arrival does not trigger substantially before ground truth | |
| NAV-08 | Reach destination with stable samples | arrival dialog appears after confirmations | |
| NAV-09 | Cancel navigation | session becomes cancelled and Map returns | |
| NAV-10 | Model restarts during session | backend recreates model session or reports recoverable failure | |

## Administrator functions

| ID | Test | Expected result | Result |
|---|---|---|---|
| ADM-01 | Load Dashboard | room, AP, zone, and open-report totals load | |
| ADM-02 | Tap informational summary cards | rooms/AP/zones do not unexpectedly navigate | |
| ADM-03 | Tap Open reports | report page opens | |
| ADM-04 | List each map resource | active records load | |
| ADM-05 | Create a temporary valid item | API validates and saves it | |
| ADM-06 | Edit the temporary item | allowed fields and updated timestamp change | |
| ADM-07 | Disable the temporary item | item becomes inactive, not physically deleted | |
| ADM-08 | User accesses map admin route | backend rejects the request | |

## Automated regression tests

```powershell
docker compose exec model python -m unittest discover -s tests -v
docker compose exec backend npm run test:navigation
```

Both commands must complete without failed tests. Also run the Flutter checks available in the project before producing the final APK:

```powershell
cd frontend
flutter analyze
flutter test
```

Document any known analyzer warnings separately; do not describe a failing build as release-ready.

## Evidence to keep

- terminal output from Docker health and automated tests;
- anonymized screenshots of User and Admin flows;
- test coordinates and timestamped RSSI samples;
- commit hash used to build the APK;
- list of known limitations and failed/blocked acceptance tests.

Do not commit real passwords, Bearer tokens, MongoDB URIs, personal email addresses, or raw client identifiers as evidence.
