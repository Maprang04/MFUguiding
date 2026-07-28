# Indoor Navigation Backend Handoff และ API Specification

## 0. คำแนะนำสำหรับผู้พัฒนา Backend

เอกสารฉบับนี้ออกแบบให้ผู้พัฒนา Backend สามารถทำงานได้โดย **ไม่ต้องเห็น source code, training data หรือ model artifacts ของระบบ Positioning** ให้ถือว่า Python Positioning Engine เป็น external/internal service ที่ติดต่อผ่าน API contract เท่านั้น

### 0.1 เป้าหมายของงานที่ส่งมอบให้ผู้พัฒนา Backend

ผู้พัฒนา Backend ต้องทำ:

1. REST API และ Socket.IO ตามเอกสารนี้
2. MongoDB models, repositories และ indexes
3. Navigation session lifecycle
4. Simulator observation source
5. Background observation worker
6. Positioning client interface
7. Mock Positioning Adapter สำหรับพัฒนาโดยยังไม่มีโมเดล
8. Validation, authentication, authorization และ error handling
9. Unit, integration และ contract tests
10. Environment configuration และ health checks

ผู้พัฒนา Backend ไม่ต้องทำ:

- Train หรือแก้โมเดล Machine Learning
- อ่านหรือแก้ไฟล์ `.joblib`
- อ่าน training dataset โดยตรงเพื่อคำนวณตำแหน่ง
- เขียน KNN, RSSI median filter, roaming tracker หรือ zone estimator ซ้ำใน Node.js
- อ่าน occupancy grid หรือเขียน A* ซ้ำใน Node.js
- สร้าง route จาก floor plan เอง
- เชื่อม Cisco Controller จริงในรอบ Simulator MVP เว้นแต่ได้รับรายละเอียดเพิ่มเติม

### 0.2 วิธีทำงานระหว่างยังไม่มี Positioning Service จริง

ให้ตั้งค่า:

```env
POSITIONING_MODE=mock
POSITIONING_OBSERVATION_SOURCE=simulator
```

Backend ต้องเลือก adapter ตาม configuration:

```text
POSITIONING_MODE=mock
  -> MockPositioningClient

POSITIONING_MODE=http
  -> HttpPositioningClient
```

Service อื่นใน Backend ต้องเรียกผ่าน interface เดียวกัน ห้ามตรวจ `POSITIONING_MODE` กระจายหลายไฟล์

```javascript
class PositioningClient {
  async healthCheck() {}
  async createSession(input) {}
  async submitObservation(sessionId, observation) {}
  async changeDestination(sessionId, destinationId) {}
  async getSession(sessionId) {}
  async deleteSession(sessionId) {}
}
```

### 0.3 Mock Positioning Client Contract

Mock ต้องเก็บ state แยกตาม `session_id` และคืน response shape เดียวกับ Positioning API จริง

ตัวอย่าง request:

```javascript
await positioningClient.submitObservation("nav-001", {
  associated_ap: "AP2",
  rssi: -64,
  timestamp: "2026-07-24T10:30:08.000Z"
});
```

ตัวอย่าง response:

```json
{
  "confirmed_ap": "AP2",
  "candidate_ap": null,
  "candidate_count": 0,
  "roaming_confirmed": true,
  "previous_ap": "AP3",
  "zone": "CENTRAL_HALLWAY",
  "zone_label": "Central hallway / Room 2 area",
  "signal_band": "medium",
  "median_rssi": -69,
  "estimated_position": {"x": 9.125, "y": 3.625},
  "position_source": "roaming_transition",
  "confidence": "high",
  "route_recalculated": true,
  "route": [
    {"x": 9.125, "y": 3.625},
    {"x": 10.125, "y": 3.875},
    {"x": 15.125, "y": 9.125}
  ]
}
```

Mock ไม่จำเป็นต้องจำลอง algorithm จริง แต่ต้องรองรับ scenario ที่กำหนดผลลัพธ์ล่วงหน้า เพื่อทดสอบ Backend orchestration:

```text
initial position
AP candidate ยังไม่ครบ
roaming confirmed
route recalculated
invalid RSSI
positioning timeout
route not found
stale observation
```

### 0.4 Mock Scenario Format

แนะนำให้เก็บไฟล์ scenario ฝั่ง Backend test:

```json
{
  "scenario_id": "ap3-to-ap2",
  "steps": [
    {
      "observation": {
        "associated_ap": "AP3",
        "rssi": -62
      },
      "positioning_result": {
        "confirmed_ap": "AP3",
        "roaming_confirmed": false,
        "zone": "LEFT_WING",
        "estimated_position": {"x": 6.125, "y": 2.125},
        "confidence": "low",
        "route_recalculated": true,
        "route": [
          {"x": 6.125, "y": 2.125},
          {"x": 15.125, "y": 9.125}
        ]
      }
    },
    {
      "observation": {
        "associated_ap": "AP2",
        "rssi": -66
      },
      "positioning_result": {
        "confirmed_ap": "AP2",
        "previous_ap": "AP3",
        "roaming_confirmed": true,
        "zone": "CENTRAL_HALLWAY",
        "estimated_position": {"x": 9.125, "y": 3.625},
        "confidence": "high",
        "route_recalculated": true,
        "route": [
          {"x": 9.125, "y": 3.625},
          {"x": 15.125, "y": 9.125}
        ]
      }
    }
  ]
}
```

### 0.5 Backend Deliverables

ผู้พัฒนา Backend ต้องส่งมอบ:

```text
1. Source code ของ navigation module
2. MongoDB models และ indexes
3. SimulatorObservationSource
4. MockPositioningClient
5. HttpPositioningClient
6. Navigation worker
7. REST routes/controllers/services
8. Socket.IO events
9. Environment example
10. Unit/integration/contract tests
11. API documentation หรือ OpenAPI file
12. README วิธีรันด้วย mock mode
```

### 0.6 สิ่งที่เจ้าของโมเดลจะส่งให้ภายหลัง

ผู้พัฒนา Backend ไม่ต้องรอสิ่งเหล่านี้เพื่อเริ่มงาน:

```text
POSITIONING_SERVICE_URL
วิธี authentication ระหว่าง Node และ Python
Python service deployment command
Health endpoint ที่ใช้งานจริง
ผล contract test จาก Positioning Service
Cisco Controller รุ่น/API/credential
```

เมื่อได้รับ Positioning Service จริง ต้องเปลี่ยน:

```env
POSITIONING_MODE=http
POSITIONING_SERVICE_URL=http://127.0.0.1:8001
```

ห้ามแก้ navigation session service หรือ REST API contract ตอนสลับจาก mock เป็น HTTP adapter

### 0.7 เกณฑ์รับงาน Backend โดยยังไม่มีโมเดล

งาน Backend ถือว่าพร้อมส่งต่อ integration เมื่อ:

- [ ] ทุก REST endpoint ใน API Summary ทำงานด้วย mock mode
- [ ] MongoDB บันทึก session และ observation ได้
- [ ] Worker อ่าน simulator observations ได้
- [ ] Mock positioning response อัปเดต session ได้
- [ ] Socket.IO ส่ง position, roaming และ route ได้
- [ ] User อื่นเข้าถึง session ไม่ได้
- [ ] Invalid RSSI, timeout และ stale observation มี tests
- [ ] เปลี่ยน `POSITIONING_MODE` ผ่าน factory จุดเดียว
- [ ] `HttpPositioningClient` มี timeout และ error mapping แม้ยังไม่มี service จริง
- [ ] Contract tests ตรวจ request/response shape
- [ ] Tests ไม่ต้องใช้ model files หรือ Python source
- [ ] README อธิบายการรัน Backend ด้วย simulator + mock positioning

เมื่อผ่านรายการนี้ เพื่อนสามารถส่งมอบ Backend portion ได้โดยไม่ต้องเข้าถึงโค้ดโมเดล

## 1. วัตถุประสงค์

เอกสารนี้กำหนดสิ่งที่ Backend ต้องพัฒนาเพื่อรองรับระบบนำทางภายในอาคาร โดยใช้ข้อมูล AP และ RSSI จาก Cisco Controller หรือ simulator ส่งเข้า Python Positioning Engine แล้วส่งตำแหน่งโดยประมาณและเส้นทางให้ Frontend

ไฟล์นี้เป็น specification สำหรับการพัฒนา ยังไม่ใช่ API ที่พร้อมใช้งานจริง

## 2. ขอบเขตระบบ

Backend มีหน้าที่:

1. ตรวจสอบตัวตนและสิทธิ์ของผู้ใช้
2. ผูกผู้ใช้กับอุปกรณ์หรือ client identifier
3. สร้างและจัดการ navigation session
4. รับข้อมูล associated AP และ RSSI จาก simulator หรือ Cisco Controller
5. ตรวจสอบและบันทึก observations ลง MongoDB
6. ส่ง observation เข้า Python Positioning Engine
7. รับ zone, confidence, position และ route กลับมา
8. บันทึกสถานะล่าสุดของ session
9. ส่งข้อมูลให้ Frontend ผ่าน REST API และ Socket.IO
10. จัดการ timeout, stale data, controller failure และ positioning failure

Backend ไม่ควร:

- คำนวณ KNN, roaming state, occupancy grid หรือ A* ซ้ำใน Node.js
- เปิดเผย Cisco credential หรือ MongoDB connection string ให้ Frontend
- อ้างว่าตำแหน่งจาก AP และ RSSI ตัวเดียวเป็นตำแหน่งแม่นยำแบบ GPS
- ให้ Frontend ติดต่อ Cisco Controller, MongoDB หรือ Python Engine โดยตรง

## 3. สถาปัตยกรรม

```text
Frontend
   |
   | REST API + Socket.IO
   v
Backend Node.js
   |-- Authentication / Authorization
   |-- Navigation Sessions
   |-- Observation Source Adapter
   |-- MongoDB Repository
   |-- Positioning Client
   |
   +--> Simulator Adapter (ระหว่างรอ Controller)
   |
   +--> Cisco Controller Adapter (ภายหลัง)
   |
   +--> MongoDB
   |
   +--> Python Positioning Engine
          |-- RSSI median filter
          |-- Roaming tracker
          |-- Zone estimator
          |-- Occupancy grid
          |-- A*
          +-- Route visualization
```

## 4. Data Flow

### 4.1 เริ่มนำทาง

```text
1. User เลือกปลายทาง
2. Frontend ขอสร้าง navigation session
3. Backend ตรวจ destination และ client identifier
4. Backend สร้าง session ใน MongoDB
5. Backend เริ่ม observation worker
6. Backend ส่ง observation แรกเข้า Python Engine
7. Python Engine คืน zone และ route
8. Backend ส่งผลให้ Frontend
```

### 4.2 ระหว่างนำทาง

```text
1. Worker อ่าน AP/RSSI ทุก 1-3 วินาที
2. Backend validate observation
3. Backend บันทึก observation
4. Backend ส่ง observation เข้า Python Engine
5. Python Engine อัปเดต median และ roaming state
6. ถ้ายืนยัน roaming ให้คำนวณ route ใหม่
7. Backend อัปเดต session
8. Backend emit Socket.IO event
```

### 4.3 จบการนำทาง

```text
1. User ถึงปลายทาง ยกเลิก หรือ session หมดอายุ
2. Backend เปลี่ยนสถานะ session
3. Backend หยุด observation worker
4. Backend ล้าง state ใน Python Engine
5. Backend แจ้ง Frontend
```

## 5. Environment Variables

```env
# MongoDB
MONGODB_URI=mongodb://localhost:27017
MONGODB_DATABASE=indoor_navigation

# Observation source
POSITIONING_OBSERVATION_SOURCE=simulator
POSITIONING_POLL_INTERVAL_MS=2000
POSITIONING_STALE_AFTER_MS=10000

# Python positioning service
POSITIONING_SERVICE_URL=http://127.0.0.1:8001
POSITIONING_SERVICE_TIMEOUT_MS=5000
POSITIONING_MODE=mock

# Cisco Controller (ใช้เมื่อได้ข้อมูลจริง)
CISCO_CONTROLLER_URL=
CISCO_CONTROLLER_USERNAME=
CISCO_CONTROLLER_PASSWORD=
CISCO_CONTROLLER_VERIFY_TLS=true
```

ห้าม commit ค่า credential จริงลง Git

## 6. MongoDB Collections

### 6.1 `wifi_fingerprints`

ใช้ train โมเดล fingerprint

```json
{
  "_id": "ObjectId",
  "id": 1,
  "ap1": -70,
  "ap2": -65,
  "ap3": -70,
  "x": 14.0,
  "y": 7.0,
  "created_at": "Date"
}
```

### 6.2 `access_points`

```json
{
  "_id": "ObjectId",
  "id": 1,
  "name": "AP1",
  "x": 16.25,
  "y": 11.75,
  "enabled": true
}
```

Index:

```javascript
db.access_points.createIndex({ name: 1 }, { unique: true })
```

### 6.3 `controller_observations`

```json
{
  "_id": "ObjectId",
  "session_id": "nav-001",
  "client_id": "device-001",
  "associated_ap": "AP2",
  "rssi": -64,
  "timestamp": "Date",
  "received_at": "Date",
  "source": "simulator",
  "valid": true,
  "validation_error": null
}
```

Indexes:

```javascript
db.controller_observations.createIndex({ session_id: 1, timestamp: -1 })
db.controller_observations.createIndex({ client_id: 1, timestamp: -1 })
db.controller_observations.createIndex({ associated_ap: 1, timestamp: -1 })
```

### 6.4 `navigation_sessions`

```json
{
  "_id": "ObjectId",
  "session_id": "nav-001",
  "user_id": "user-001",
  "client_id": "device-001",
  "destination_id": "room_2",
  "status": "active",
  "current_ap": "AP2",
  "current_zone": "CENTRAL_HALLWAY",
  "signal_band": "medium",
  "median_rssi": -67.5,
  "estimated_position": {
    "x": 9.125,
    "y": 3.625
  },
  "position_source": "roaming_transition",
  "confidence": "high",
  "route": [
    {"x": 9.125, "y": 3.625},
    {"x": 10.125, "y": 3.875},
    {"x": 15.125, "y": 9.125}
  ],
  "last_observation_at": "Date",
  "started_at": "Date",
  "updated_at": "Date",
  "completed_at": null
}
```

Indexes:

```javascript
db.navigation_sessions.createIndex({ session_id: 1 }, { unique: true })
db.navigation_sessions.createIndex({ user_id: 1, status: 1 })
db.navigation_sessions.createIndex({ client_id: 1, status: 1 })
```

### 6.5 `destinations`

ใน MVP สามารถอ่านจาก `model/positioning/zone_config.json` ก่อน หากย้ายเข้า MongoDB ให้ใช้รูปแบบ:

```json
{
  "_id": "ObjectId",
  "destination_id": "room_2",
  "label": "Room 2 entrance",
  "floor_id": "floor-1",
  "position": {
    "x": 15.0,
    "y": 9.0
  },
  "enabled": true
}
```

## 7. API Summary

Base path ที่ใช้ตาม convention ของ Backend ปัจจุบัน:

```text
/api/v1/navigation
```

| Method | Endpoint | Authentication | หน้าที่ |
|---|---|---:|---|
| `GET` | `/api/v1/navigation/health` | Optional/Admin | ตรวจ Backend, MongoDB, observation source และ Python Engine |
| `GET` | `/api/v1/navigation/destinations` | Required | อ่านรายการปลายทางที่เปิดใช้งาน |
| `GET` | `/api/v1/navigation/destinations/:destinationId` | Required | อ่านรายละเอียดปลายทางหนึ่งรายการ |
| `POST` | `/api/v1/navigation/sessions` | Required | เริ่ม navigation session |
| `GET` | `/api/v1/navigation/sessions/:sessionId` | Required | อ่านสถานะและ route ล่าสุด |
| `PATCH` | `/api/v1/navigation/sessions/:sessionId/destination` | Required | เปลี่ยนปลายทาง |
| `POST` | `/api/v1/navigation/sessions/:sessionId/refresh` | Required | ขออ่าน observation และคำนวณสถานะใหม่ทันที |
| `POST` | `/api/v1/navigation/sessions/:sessionId/complete` | Required | ทำเครื่องหมายว่าถึงปลายทาง |
| `DELETE` | `/api/v1/navigation/sessions/:sessionId` | Required | ยกเลิก navigation session |
| `GET` | `/api/v1/navigation/sessions/:sessionId/observations` | Required/Admin | อ่าน observation history ของ session |
| `POST` | `/api/v1/navigation/simulator/observations` | Development/Admin | ส่ง observation จำลองเข้า Backend |
| `POST` | `/api/v1/navigation/simulator/scenarios/:scenarioId/run` | Development/Admin | รัน simulation scenario |
| `GET` | `/api/v1/navigation/access-points` | Required/Admin | อ่านรายการ AP และตำแหน่ง |

## 8. Public REST API Contracts

### 8.1 Health Check

```http
GET /api/navigation/health
```

Response `200`:

```json
{
  "status": "ok",
  "services": {
    "backend": "ok",
    "mongodb": "ok",
    "positioning_engine": "ok",
    "observation_source": "simulator",
    "cisco_controller": "not_configured"
  },
  "timestamp": "2026-07-24T10:30:00.000Z"
}
```

หากบาง dependency ใช้งานไม่ได้ สามารถตอบ `503`:

```json
{
  "status": "degraded",
  "services": {
    "backend": "ok",
    "mongodb": "ok",
    "positioning_engine": "unavailable"
  }
}
```

### 8.2 Get Destinations

```http
GET /api/navigation/destinations
```

Response `200`:

```json
{
  "items": [
    {
      "id": "room_1",
      "label": "Room 1 entrance",
      "floor_id": "floor-1",
      "position": {"x": 15.0, "y": 5.0}
    },
    {
      "id": "room_2",
      "label": "Room 2 entrance",
      "floor_id": "floor-1",
      "position": {"x": 15.0, "y": 9.0}
    },
    {
      "id": "room_3",
      "label": "Room 3 entrance",
      "floor_id": "floor-1",
      "position": {"x": 11.0, "y": 5.0}
    }
  ]
}
```

### 8.3 Start Navigation Session

```http
POST /api/navigation/sessions
Content-Type: application/json
```

Request:

```json
{
  "client_id": "device-001",
  "destination_id": "room_2"
}
```

Response `201`:

```json
{
  "session_id": "nav-001",
  "status": "active",
  "client_id": "device-001",
  "destination": {
    "id": "room_2",
    "label": "Room 2 entrance",
    "position": {"x": 15.0, "y": 9.0}
  },
  "position_status": "waiting_for_observation",
  "started_at": "2026-07-24T10:30:00.000Z"
}
```

Validation errors:

| HTTP | Code | กรณี |
|---:|---|---|
| `400` | `INVALID_REQUEST` | ไม่มี client ID หรือ destination ID |
| `404` | `DESTINATION_NOT_FOUND` | ไม่พบปลายทาง |
| `409` | `ACTIVE_SESSION_EXISTS` | ผู้ใช้หรืออุปกรณ์มี session ที่ active อยู่แล้ว |
| `503` | `POSITIONING_UNAVAILABLE` | Positioning Engine ใช้งานไม่ได้ |

### 8.4 Get Navigation Session

```http
GET /api/navigation/sessions/:sessionId
```

Response `200`:

```json
{
  "session_id": "nav-001",
  "status": "active",
  "observation_status": "fresh",
  "confirmed_ap": "AP2",
  "zone": "CENTRAL_HALLWAY",
  "zone_label": "Central hallway / Room 2 area",
  "signal_band": "medium",
  "median_rssi": -67.5,
  "estimated_position": {"x": 9.125, "y": 3.625},
  "position_source": "roaming_transition",
  "confidence": "high",
  "destination": {
    "id": "room_2",
    "label": "Room 2 entrance",
    "position": {"x": 15.0, "y": 9.0}
  },
  "route": [
    {"x": 9.125, "y": 3.625},
    {"x": 10.125, "y": 3.875},
    {"x": 15.125, "y": 9.125}
  ],
  "route_version": 2,
  "last_observation_at": "2026-07-24T10:30:08.000Z",
  "updated_at": "2026-07-24T10:30:08.100Z"
}
```

`observation_status`:

```text
waiting
fresh
stale
unavailable
```

### 8.5 Change Destination

```http
PATCH /api/navigation/sessions/:sessionId/destination
Content-Type: application/json
```

Request:

```json
{
  "destination_id": "room_3"
}
```

Response `200`:

```json
{
  "session_id": "nav-001",
  "destination_id": "room_3",
  "route_recalculated": true,
  "route_version": 3
}
```

### 8.6 Refresh Position

```http
POST /api/navigation/sessions/:sessionId/refresh
```

ใช้สำหรับ debug หรือ manual refresh เท่านั้น ระบบ production ควรมี worker อัปเดตอัตโนมัติ

Response `200`:

```json
{
  "session_id": "nav-001",
  "observation_received": true,
  "position_updated": true,
  "route_recalculated": false
}
```

### 8.7 Complete Navigation

```http
POST /api/navigation/sessions/:sessionId/complete
```

Response `200`:

```json
{
  "session_id": "nav-001",
  "status": "completed",
  "completed_at": "2026-07-24T10:40:00.000Z"
}
```

### 8.8 Cancel Navigation

```http
DELETE /api/navigation/sessions/:sessionId
```

Response `200`:

```json
{
  "session_id": "nav-001",
  "status": "cancelled"
}
```

### 8.9 Get Observation History

```http
GET /api/navigation/sessions/:sessionId/observations?limit=100
```

Response `200`:

```json
{
  "items": [
    {
      "associated_ap": "AP2",
      "rssi": -64,
      "timestamp": "2026-07-24T10:30:08.000Z",
      "source": "simulator",
      "valid": true
    }
  ],
  "next_cursor": null
}
```

### 8.10 Submit Simulator Observation

Endpoint นี้ต้องเปิดเฉพาะ development/test หรือ admin

```http
POST /api/navigation/simulator/observations
Content-Type: application/json
```

Request:

```json
{
  "client_id": "device-001",
  "associated_ap": "AP2",
  "rssi": -64,
  "timestamp": "2026-07-24T10:30:08.000Z"
}
```

Response `202`:

```json
{
  "accepted": true,
  "observation_id": "..."
}
```

## 9. Standard Error Response

ทุก endpoint ควรใช้ error shape เดียวกัน:

```json
{
  "error": {
    "code": "DESTINATION_NOT_FOUND",
    "message": "Destination room_99 does not exist",
    "request_id": "req-001"
  }
}
```

Error codes ที่ควรมี:

| HTTP | Code | ความหมาย |
|---:|---|---|
| `400` | `INVALID_REQUEST` | Request body หรือ parameter ไม่ถูกต้อง |
| `400` | `INVALID_RSSI` | RSSI ไม่ใช่ตัวเลขหรืออยู่นอกช่วง |
| `400` | `UNKNOWN_ACCESS_POINT` | AP ไม่อยู่ใน configuration |
| `401` | `UNAUTHENTICATED` | ยังไม่ได้ login |
| `403` | `FORBIDDEN` | ไม่มีสิทธิ์เข้าถึง session |
| `404` | `SESSION_NOT_FOUND` | ไม่พบ navigation session |
| `404` | `DESTINATION_NOT_FOUND` | ไม่พบปลายทาง |
| `409` | `ACTIVE_SESSION_EXISTS` | มี active session อยู่แล้ว |
| `409` | `SESSION_NOT_ACTIVE` | session จบหรือถูกยกเลิกแล้ว |
| `422` | `NO_WALKABLE_POSITION` | หา anchor ที่เดินได้ไม่ได้ |
| `422` | `ROUTE_NOT_FOUND` | A* หาเส้นทางไม่ได้ |
| `502` | `CONTROLLER_ERROR` | Controller ตอบกลับผิดพลาด |
| `503` | `CONTROLLER_UNAVAILABLE` | ติดต่อ Controller ไม่ได้ |
| `503` | `POSITIONING_UNAVAILABLE` | Python Positioning Engine ใช้งานไม่ได้ |
| `504` | `POSITIONING_TIMEOUT` | Python Engine ตอบช้าเกินกำหนด |

## 10. Socket.IO Events

Frontend ควร subscribe ตาม `session_id`

| Event | ผู้ส่ง | ใช้เมื่อ |
|---|---|---|
| `navigation:joined` | Backend → Client | Client subscribe session สำเร็จ |
| `navigation:position` | Backend → Client | zone หรือ estimated position อัปเดต |
| `navigation:roaming` | Backend → Client | ยืนยันการ roam ไป AP ใหม่ |
| `navigation:route` | Backend → Client | route ถูกคำนวณใหม่ |
| `navigation:stale` | Backend → Client | observation เก่าเกิน threshold |
| `navigation:error` | Backend → Client | Controller หรือ positioning เกิด error |
| `navigation:completed` | Backend → Client | navigation เสร็จสิ้น |
| `navigation:cancelled` | Backend → Client | navigation ถูกยกเลิก |

### Join session

Client ส่ง:

```json
{
  "event": "navigation:join",
  "session_id": "nav-001"
}
```

Backend ต้องตรวจว่า user มีสิทธิ์เข้าถึง session ก่อนเข้าห้อง Socket.IO

### Position event

```json
{
  "session_id": "nav-001",
  "confirmed_ap": "AP2",
  "zone": "CENTRAL_HALLWAY",
  "signal_band": "medium",
  "median_rssi": -67.5,
  "estimated_position": {"x": 9.125, "y": 3.625},
  "confidence": "high",
  "updated_at": "2026-07-24T10:30:08.100Z"
}
```

### Roaming event

```json
{
  "session_id": "nav-001",
  "previous_ap": "AP3",
  "current_ap": "AP2",
  "transition_position": {"x": 9.125, "y": 3.625},
  "confidence": "high"
}
```

### Route event

```json
{
  "session_id": "nav-001",
  "route_version": 2,
  "route": [
    {"x": 9.125, "y": 3.625},
    {"x": 10.125, "y": 3.875},
    {"x": 15.125, "y": 9.125}
  ],
  "destination": {
    "id": "room_2",
    "position": {"x": 15.0, "y": 9.0}
  }
}
```

Frontend ควรวาด route จาก coordinates ไม่ควรใช้ PNG เป็นข้อมูลหลัก เพราะ coordinates อัปเดตแบบ real-time ได้ง่ายกว่า

## 11. Internal Python Positioning API

API กลุ่มนี้เป็น internal service ไม่ควรเปิดต่อ Internet โดยตรง

Base URL:

```text
http://127.0.0.1:8001
```

| Method | Endpoint | หน้าที่ |
|---|---|---|
| `GET` | `/health` | ตรวจ Python Engine และ model artifacts |
| `POST` | `/sessions` | สร้าง positioning state ของ session |
| `POST` | `/sessions/:sessionId/observations` | ส่ง AP/RSSI และอัปเดตตำแหน่ง |
| `PATCH` | `/sessions/:sessionId/destination` | เปลี่ยนปลายทางและคำนวณ route ใหม่ |
| `GET` | `/sessions/:sessionId` | อ่าน state ล่าสุด |
| `DELETE` | `/sessions/:sessionId` | ล้าง RSSI/roaming state |

### Create Positioning Session

```http
POST /sessions
```

```json
{
  "session_id": "nav-001",
  "client_id": "device-001",
  "destination_id": "room_2"
}
```

### Submit Observation

```http
POST /sessions/nav-001/observations
```

Request:

```json
{
  "associated_ap": "AP2",
  "rssi": -64,
  "timestamp": "2026-07-24T10:30:08.000Z"
}
```

Response:

```json
{
  "confirmed_ap": "AP2",
  "candidate_ap": null,
  "candidate_count": 0,
  "roaming_confirmed": true,
  "previous_ap": "AP3",
  "zone": "CENTRAL_HALLWAY",
  "zone_label": "Central hallway / Room 2 area",
  "signal_band": "medium",
  "median_rssi": -69,
  "estimated_position": {"x": 9.125, "y": 3.625},
  "position_source": "roaming_transition",
  "confidence": "high",
  "route_recalculated": true,
  "route": [
    {"x": 9.125, "y": 3.625},
    {"x": 10.125, "y": 3.875},
    {"x": 15.125, "y": 9.125}
  ]
}
```

## 12. Observation Source Interface

Simulator และ Cisco adapter ต้อง implement contract เดียวกัน:

```javascript
class ObservationSource {
  async getClientObservation(clientId) {
    return {
      clientId,
      associatedAp: "AP2",
      rssi: -64,
      timestamp: new Date(),
      source: "simulator"
    };
  }

  async healthCheck() {}
}
```

### Simulator Adapter

ระหว่างรอ Controller:

- อ่าน JSON scenario
- ส่ง observation ตามลำดับ
- รองรับ interval จำลอง
- รองรับ invalid RSSI และ AP ping-pong สำหรับ tests
- ไม่ควรใช้ใน production

### Cisco Adapter

เมื่อได้ Controller:

- ใช้ read-only credential
- แปลง AP identifier ให้ตรงกับ `AP1`, `AP2`, `AP3`
- แปลง timestamp เป็น UTC
- มี timeout และ retry with backoff
- ไม่ log password, token หรือ full controller response ที่มีข้อมูลส่วนบุคคล
- ตรวจ TLS certificate ใน production

## 13. Backend Modules ที่ต้องสร้าง

โครงสร้างที่เสนอ:

```text
backend-node/
└── server/
    └── Project/
        └── navigation/
            ├── navigation.routes.js
            ├── controller/
            │   ├── navigation.controller.js
            │   └── simulator.controller.js
            ├── service/
            │   ├── navigation-session.service.js
            │   ├── navigation-worker.service.js
            │   ├── positioning-client.service.js
            │   └── destination.service.js
            ├── repository/
            │   ├── navigation-session.repository.js
            │   └── observation.repository.js
            ├── integrations/
            │   ├── observation-source.interface.js
            │   ├── simulator.adapter.js
            │   └── cisco.adapter.js
            ├── models/
            │   ├── navigation-session.model.js
            │   └── controller-observation.model.js
            ├── validation/
            │   └── navigation.validation.js
            └── test/
                ├── navigation.routes.test.js
                ├── navigation-session.service.test.js
                ├── simulator.adapter.test.js
                └── positioning-client.test.js
```

ให้ปรับ path และรูปแบบ module ตาม convention ของ Backend ปัจจุบันก่อนเริ่ม implement

## 14. Background Worker

Worker ทำงานต่อ active session:

```text
ทุก POSITIONING_POLL_INTERVAL_MS:
  1. หา active sessions
  2. อ่าน observation จาก source
  3. validate และบันทึก
  4. ส่งเข้า Python Engine
  5. อัปเดต session
  6. emit Socket.IO เมื่อ state เปลี่ยน
```

ข้อกำหนด:

- ห้ามมี worker ซ้ำสำหรับ session เดียว
- หยุด worker เมื่อ session จบ
- จำกัด concurrency
- ใช้ distributed lock หากรัน Backend หลาย instance
- มี retry/backoff เมื่อ dependency ล่ม
- observation เก่าต้องเป็น `stale`

## 15. Security และ Privacy

- ใช้ authentication middleware ของระบบเดิม
- User อ่านหรือแก้เฉพาะ navigation session ของตนเอง
- Admin/debug endpoints ต้องมีสิทธิ์เฉพาะ
- Simulator endpoints ปิดใน production
- Cisco credential อยู่ใน environment หรือ secret manager
- ใช้ controller account แบบ read-only
- ห้ามส่ง client MAC ให้ user อื่น
- ห้าม log credential และ connection string
- กำหนด retention ของ observations
- rate limit start/refresh/simulator endpoints
- validate ทุก AP, RSSI, destination และ session ID
- ใช้ HTTPS ระหว่าง service เมื่อไม่ได้อยู่ในเครื่องเดียวกัน

## 16. Logging และ Monitoring

ทุก log ควรมี:

```text
request_id
session_id
user_id (ถ้าเหมาะสม)
client_id แบบ mask/hash
event
duration_ms
result
```

Events สำคัญ:

```text
navigation_session_started
observation_received
observation_rejected
roaming_confirmed
route_recalculated
observation_stale
controller_unavailable
positioning_timeout
navigation_completed
navigation_cancelled
```

Metrics:

```text
active navigation sessions
controller request latency
positioning request latency
invalid observation count
confirmed roaming count
route recalculation count
stale session count
error rate
```

## 17. Testing Requirements

### Unit Tests

- request validation
- RSSI validation
- destination validation
- session ownership
- simulator adapter
- Cisco response mapping
- MongoDB repository
- Python client timeout/error mapping
- stale observation logic
- worker start/stop

### Integration Tests

- Start session → simulator observation → Python Engine → route
- AP candidate ยังไม่ครบ confirmation
- AP ใหม่ครบ confirmation แล้ว route เปลี่ยน
- invalid RSSI ถูกปฏิเสธ
- MongoDB unavailable
- Python Engine unavailable/timeout
- observation stale
- cancel session แล้ว worker หยุด
- user อื่นเข้าถึง session ไม่ได้

### Contract Tests

ตรวจ Node/Python payload:

- field names ตรงกัน
- coordinate เป็น number
- timestamp เป็น ISO-8601 UTC
- error codes ตรง specification
- route เป็นลำดับ `{x, y}`

### Load Tests

- หลาย active sessions พร้อมกัน
- polling ไม่เรียก Controller ถี่เกิน limit
- Socket.IO ส่งเฉพาะ room/session ที่เกี่ยวข้อง
- worker ไม่ซ้ำหลัง restart

## 18. Acceptance Criteria

- [ ] Backend สร้าง navigation session ได้
- [ ] User เลือก Room 1, Room 2 หรือ Room 3 ได้
- [ ] Backend อ่าน observation จาก simulator ได้
- [ ] Backend validate AP, RSSI และ timestamp ได้
- [ ] Observation ถูกบันทึกใน MongoDB
- [ ] Backend ส่ง observation เข้า Python Engine ได้
- [ ] Python Engine คืน zone, confidence และ position
- [ ] Backend ส่ง route coordinates ให้ Frontend ได้
- [ ] AP ใหม่ reading เดียวไม่ทำให้ roaming
- [ ] AP ใหม่ครบ confirmation ทำให้ route recalculated
- [ ] Socket.IO ส่ง position, roaming และ route events ได้
- [ ] Session ของ user อื่นไม่สามารถเข้าถึงได้
- [ ] Invalid RSSI ไม่ถูกใช้คำนวณตำแหน่ง
- [ ] Controller/Simulator timeout ถูกจัดการโดยไม่ทำให้ Backend crash
- [ ] Observation เก่าถูกระบุเป็น stale
- [ ] Session จบแล้ว worker และ Python state ถูกล้าง
- [ ] Health endpoint รายงาน MongoDB และ Positioning Engine ได้
- [ ] Simulator endpoints ถูกปิดหรือจำกัดสิทธิ์ใน production
- [ ] Tests ผ่านทุกชุดที่เกี่ยวข้อง

## 19. ลำดับการพัฒนา

### Phase 1: Simulator MVP

1. สร้าง MongoDB models/repositories
2. สร้าง navigation session service
3. สร้าง simulator adapter
4. สร้าง Python Positioning API
5. สร้าง positioning client ใน Node.js
6. สร้าง REST session APIs
7. สร้าง worker
8. สร้าง Socket.IO events
9. ทดสอบ end-to-end ด้วย simulator

### Phase 2: Cisco Integration

1. รับรุ่น Controller และ API documentation
2. สร้าง Cisco adapter
3. map AP identifier
4. เพิ่ม credential/TLS configuration
5. ทดสอบ read-only integration
6. ปรับ polling และ rate limits
7. ทดสอบ roaming จริง

### Phase 3: Production Hardening

1. เพิ่ม Redis/distributed state หากมีหลาย Backend instances
2. เพิ่ม monitoring และ alerts
3. กำหนด data retention
4. load/security tests
5. backup/restore
6. deployment และ rollback plan

## 20. Definition of Done

Backend ถือว่าเสร็จสำหรับ MVP เมื่อ:

1. Frontend เริ่ม navigation session และเลือกปลายทางได้
2. Simulator ส่ง AP/RSSI เข้า Backend ได้
3. Backend บันทึก MongoDB และเรียก Python Engine ได้
4. Frontend ได้ zone, confidence และ route แบบ real-time
5. ระบบคำนวณ route ใหม่หลังยืนยัน roaming
6. Session จบหรือยกเลิกได้โดยไม่มี worker/state ค้าง
7. Error, stale data และ dependency failures ถูกจัดการ
8. Unit, integration และ contract tests ผ่าน

## 21. Checklist สำหรับผู้รับงาน Backend

ใช้ checklist นี้เป็นลำดับการลงมือทำ:

### Setup

- [ ] อ่านหัวข้อ 0, 3, 7, 8, 9, 10 และ 11
- [ ] สร้าง feature branch สำหรับ navigation backend
- [ ] ตรวจ convention ของ routes, controllers, services และ tests ใน Backend เดิม
- [ ] เพิ่ม environment variables โดยไม่ commit secrets
- [ ] ตรวจว่าเชื่อม MongoDB test database ได้

### Data Layer

- [ ] สร้าง `controller_observations`
- [ ] สร้าง `navigation_sessions`
- [ ] สร้าง indexes
- [ ] สร้าง repository methods
- [ ] เขียน repository tests

### Adapter Layer

- [ ] สร้าง `ObservationSource` interface
- [ ] สร้าง `SimulatorObservationSource`
- [ ] สร้าง `PositioningClient` interface
- [ ] สร้าง `MockPositioningClient`
- [ ] สร้าง `HttpPositioningClient`
- [ ] สร้าง factory เลือก adapter จาก environment

### Business Logic

- [ ] สร้าง navigation session service
- [ ] ตรวจ active session ซ้ำ
- [ ] ตรวจ destination
- [ ] ตรวจ session ownership
- [ ] สร้าง worker start/stop
- [ ] จัดการ stale observation
- [ ] จัดการ positioning timeout/error
- [ ] อัปเดต route version

### API และ Real-time

- [ ] Implement REST API ตามตาราง
- [ ] ใช้ standard error response
- [ ] Implement Socket.IO join authorization
- [ ] Emit position/roaming/route/stale/error/completed events
- [ ] ปิด simulator endpoints ใน production

### Testing

- [ ] Unit tests
- [ ] Repository tests
- [ ] Route/controller tests
- [ ] Mock positioning contract tests
- [ ] End-to-end simulator test
- [ ] Authorization tests
- [ ] Timeout/stale/error tests

### Handoff

- [ ] README วิธีรัน
- [ ] `.env.example`
- [ ] API/OpenAPI documentation
- [ ] Test report
- [ ] Known limitations
- [ ] รายการสิ่งที่รอจาก Positioning/Cisco integration
