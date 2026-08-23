# MFU SmartGuide — คู่มือรันระบบและส่งต่องานให้ AI

อัปเดตล่าสุด: 22 สิงหาคม 2026

เอกสารนี้ใช้เปิดระบบ `Flutter + Node.js Backend + Python Positioning Model + MongoDB Atlas` และใช้ส่งต่องานให้นักพัฒนาหรือ AI คนถัดไป

## 1. ภาพรวม

```text
Android app
  ├─ อ่าน AP/BSSID ที่เชื่อมอยู่
  ├─ สแกน RSSI ของ AP1, AP2, AP3
  └─ ส่ง observation ทุกประมาณ 1 วินาที
          |
          v
Node.js Backend :8097 ── MongoDB Atlas: indoor_navigation
          |
          v
Python Positioning API :8001
  ├─ median RSSI และ roaming hysteresis
  ├─ 3-AP fingerprint
  └─ A* route บนกริด 0.25 เมตร
```

ระบบยังไม่ใช้ Cisco Controller โดย Wi-Fi ใช้ระบุโซน และ Step Counter ใช้ตรวจว่าผู้ใช้กำลังเดินหรือหยุด ตำแหน่งยังเป็นค่าประมาณ ไม่ใช่ GPS

### การเคลื่อนหมุดแบบผสม (Hybrid walking progress)

- แอปตรวจ Step Counter ทุก 1 วินาที แต่ไม่ใช้จำนวนก้าวคำนวณระยะโดยตรง
- เมื่อพบก้าว หมุดจะเคลื่อนตาม route ด้วยความเร็วประมาณ 1.1 เมตร/วินาที
- ระบบมีช่วงผ่อนผัน 2 วินาทีหลังพบก้าว เพื่อให้การเคลื่อนไหวต่อเนื่องระหว่างแต่ละก้าว
- เมื่อไม่พบก้าวเกิน 2 วินาที หมุดจะหยุด
- ต้องอนุญาตสิทธิ์ Physical activity; หากอ่าน Step Counter ไม่ได้ หมุดจะหยุด แต่การระบุโซนด้วย Wi-Fi ยังทำงาน

## 2. พิกัดอ้างอิง

```text
AP1 = (17.00, 5.00)
AP2 = (10.50, 9.75)
AP3 = (2.00, 0.50)

Room 1 entrance = (15.00, 5.00)
Room 2 entrance = (15.00, 9.00)
Room 3 entrance = (11.00, 5.00)
```

Config หลักอยู่ที่ `model/positioning/zone_config.json`, `backend-node/server/Project/navigation/config/navigation.config.js` และ `frontend/lib/floor_plan_coordinates.dart`

## 3. Environment ของ Backend

ตรวจ `backend-node/.env.local`:

```env
PORT=8097
MONGODB_ATLAS=mongodb+srv://<username>:<url-encoded-password>@<cluster-host>/indoor_navigation?retryWrites=true&w=majority
INDOOR_NAVIGATION_DB=indoor_navigation

POSITIONING_MODE=http
POSITIONING_SERVICE_URL=http://127.0.0.1:8001
POSITIONING_SERVICE_TIMEOUT_MS=5000
POSITIONING_SIMULATOR_ENABLED=false
NAVIGATION_OBSERVATION_SOURCE=mobile

# ค่าเริ่มต้น 24 ชั่วโมง; 168 = 7 วัน
MOBILE_SESSION_HOURS=24
```

ห้าม commit `.env.local`, MongoDB URI, username/password หรือ API key และ MongoDB Compass ไม่จำเป็นต้องเปิดไว้ตลอด

## 4. เปิด Model

Terminal 1:

```powershell
cd C:\Users\araya\Downloads\MFUguiding\model
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m uvicorn positioning_api:app --host 0.0.0.0 --port 8001
```

ตรวจสอบ:

```powershell
curl.exe --noproxy "*" http://127.0.0.1:8001/health
```

ควรเห็น `zone_model_loaded: true` และ `multi_ap_model_loaded: true` เอกสาร API อยู่ที่ `http://127.0.0.1:8001/docs`

## 5. เปิด Backend

Terminal 2 โดยไม่ปิด Model:

```powershell
cd C:\Users\araya\Downloads\MFUguiding\backend-node
npm.cmd install
npm.cmd run start:local
```

ตรวจสอบ:

```powershell
curl.exe --noproxy "*" http://127.0.0.1:8097/healthz
curl.exe --noproxy "*" http://127.0.0.1:8097/api/v1/navigation/health
```

`/healthz` ต้องตอบ `200 OK` ถ้าเป็น `503` ให้ตรวจ Atlas Network Access, MongoDB URI และ log ฐานข้อมูล ส่วน `Redis connection failed` ข้ามได้ในการทดลอง navigation local หาก health ผ่าน

## 6. รัน Flutter

Android Emulator:

```powershell
cd C:\Users\araya\Downloads\MFUguiding\frontend
flutter pub get
flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8097
```

มือถือผ่าน USB Debugging:

```powershell
cd C:\Users\araya\Downloads\MFUguiding\frontend
flutter devices
adb -s <device-id> reverse tcp:8097 tcp:8097
flutter run -d <device-id> --dart-define=BACKEND_BASE_URL=http://127.0.0.1:8097
```

ระหว่าง `flutter run` กด `r` = Hot Reload, `R` = Hot Restart, `q` = หยุด

## 7. Build APK แบบไม่เสียบ USB

หา IP ปัจจุบันด้วย `ipconfig` มือถือและคอมพิวเตอร์ต้องอยู่เครือข่ายเดียวกัน และ browser มือถือต้องเปิด URL ต่อไปนี้ได้ก่อน:

```text
http://<computer-ip>:8097/healthz
```

Build:

```powershell
cd C:\Users\araya\Downloads\MFUguiding\frontend
flutter clean
flutter pub get
flutter build apk --release --dart-define=BACKEND_BASE_URL=http://<computer-ip>:8097
```

APK อยู่ที่:

```text
C:\Users\araya\Downloads\MFUguiding\frontend\build\app\outputs\flutter-apk\app-release.apk
```

ถ้า IP เปลี่ยน ต้อง build APK ใหม่ เพราะ URL ถูกฝังใน APK ตอน build

## 8. Permission และ Wi-Fi

1. เชื่อมมือถือกับ SSID `AS-Project`
2. เปิด Wi-Fi และ Location
3. อนุญาต Location และ Nearby Wi-Fi Devices
4. ใช้ APK ล่าสุดที่มีโค้ดสแกน 3 AP
5. Android อาจ throttle Wi-Fi scan จึงไม่รับประกันค่าใหม่ทุก 1 วินาที

BSSID prefix อยู่ใน `frontend/lib/connected_wifi_service.dart`:

```text
AP1: f0:1d:2d:ba:38
AP2: f0:1d:2d:ba:98
AP3: f0:1d:2d:bc:41
```

## 9. การทำงานปัจจุบัน

1. ผู้ใช้เลือกปลายทางจาก Map หรือ Favorite
2. แอปสร้าง navigation session โดยไม่ถามตำแหน่งเริ่มต้น
3. แอปสแกน RSSI ทั้ง 3 AP และส่งผ่าน Backend ไป Model
4. หน้าโหลดตำแหน่งรอข้อมูลครบ 3 AP ติดต่อกัน 3 รอบ
5. ถ้าไม่ครบภายในประมาณ 8 รอบ แอปเข้าแผนที่ด้วยตำแหน่งระดับโซนเพื่อไม่ให้ค้าง
6. Model ใช้ median RSSI ลด noise
7. ถ้าครบ 3 AP ใช้ `hybrid_model.joblib`; ถ้าไม่ครบ fallback เป็น connected AP + zone anchor
8. Roaming ปกติต้องพบ AP ใหม่ติดต่อกัน 3 ครั้ง และการย้อนกลับอย่างรวดเร็วต้องยืนยันมากขึ้น
9. หมุดเคลื่อนตาม waypoint ประมาณ 1.1 เมตร/วินาที ไม่ย้าย anchor ทันที
10. เส้นสีน้ำเงินเริ่มจากหมุดและตัดส่วนที่ผ่านแล้ว
11. แสดงวงความไม่แน่นอนตาม signal band/confidence
12. Login session ค่าเริ่มต้นมีอายุ 24 ชั่วโมง
13. ใช้ monotonic route progress: noise ไม่สามารถดึงหมุดย้อนหลังบนเส้นทางเดิม
14. ตำแหน่งในโซนเดิมที่ห่างเส้นทางเกิน 1.5 เมตรจะถูกตรึงไว้ เว้นแต่ยืนยันการเปลี่ยน fingerprint zone แล้ว
15. A* ห้ามตัดมุมกำแพงในแนวทแยง และตรวจทุก segment หลัง simplify; ถ้าเส้นย่อไม่ปลอดภัยจะใช้ grid path เดิม
16. เปิด `stable_zone_navigation`: เมื่อยืนยัน AP3 แล้วจะล็อกตำแหน่งในโซน AP3 ไม่ขยับตาม RSSI near/medium/edge หรือ fingerprint ทุกวินาที
17. หมุดเปลี่ยนไปโซนถัดไปเฉพาะเมื่อพบ AP ใหม่ติดต่อกันครบ 3 observations แล้วจึงเคลื่อนตาม waypoint ไปข้างหน้า
18. เมื่อหน้ารอตรวจตำแหน่งเริ่มต้นเสร็จ แอปเริ่มส่ง progress อัตโนมัติประมาณ 1.1 เมตรทุกวินาที ทำให้หมุดเดินหน้าตาม route ทันทีโดยไม่ต้องกดเริ่มซ้ำ

Automatic progress เป็นการประมาณว่าผู้ใช้เดินต่อเนื่อง ไม่ได้ตรวจว่าผู้ใช้ขยับจริง หากผู้ใช้ยืนอยู่กับที่หมุดยังคงเดินหน้า จึงเหมาะกับต้นแบบที่ต้องการการนำทางต่อเนื่องและต้องอธิบายข้อจำกัดนี้ในการนำเสนอ

## 10. ปัญหาที่ยังเหลือ

ปัญหาหลักที่กำลังทดสอบ: เมื่อยืนกลางทางเดินและเลือกไป Room 1 เคยพบว่าหมุดถูกทำนายไปใกล้ประตู Room 1 แม้ผู้ใช้ยังไม่ได้อยู่ตรงนั้น

สาเหตุที่คาด:

- fingerprint จริงคล้ายตัวอย่างบริเวณประตู หรือ dataset ยังน้อย
- AP ที่แรงที่สุดแกว่งชั่วคราว
- 3-AP fingerprint สามารถ override connected AP เพื่อแก้ sticky client

การป้องกันที่เพิ่มแล้ว:

1. Fingerprint-zone hysteresis ต้องยืนยันโซนใหม่ 3 observations ก่อนข้ามโซน
2. ระหว่างรอยืนยันจะยังไม่ใช้ fingerprint ของ candidate zone
3. จำกัดการเปลี่ยนพิกัดไม่เกิน 0.75 เมตรต่อ observation
4. Arrival guard ตรึงตำแหน่งเมื่อโมเดลทำนายเข้าใกล้ปลายทาง 1.5 เมตร จนพบต่อเนื่อง 3 รอบ ซึ่งตรงกับหน้ารอเริ่มต้น
5. Destination ไม่ได้ถูกใช้เป็น feature ของโมเดลระบุตำแหน่ง
6. มี tests สำหรับ transient spike, sticky association และ false arrival

งานถัดไป: ทดสอบค่าจริงบนมือถือหลายจุด และตรวจ `Navigation_Observations.rssiReadings` หากยังผิดตำแหน่ง ให้ปรับจาก observation จริง ไม่ควรเดาพิกัดหรือผูกหมุดกับ destination

## 11. ตรวจ observation ใน MongoDB

Database: `indoor_navigation` และ collection observation คือ `Navigation_Observations`

ข้อมูลที่ใช้ 3 AP ควรมีรูปแบบ:

```json
{
  "associatedAp": "AP2",
  "rssi": -63,
  "rssiReadings": {
    "AP1": -75,
    "AP2": -63,
    "AP3": -81
  },
  "source": "mobile"
}
```

ถ้า `rssiReadings` ไม่มีครบ AP1/AP2/AP3 Model จะไม่ใช้ 3-AP fingerprint

Calibration จริงที่เคยวัดเมื่อ 22 สิงหาคม 2026:

```text
Room 2 entrance (15,9): AP1=-65, AP2=-63, AP3=-52
Associated AP = AP3
```

AP1 ถูกย้ายเป็น `(17,5)` เมื่อ 23 สิงหาคม 2026 จึงปิด calibration ชุดนี้แล้ว ต้องวัด RSSI ที่ Room 2 ใหม่ก่อนเพิ่มกลับเข้า `zone_config.json` และห้ามใช้กฎ strongest AP เพียงอย่างเดียว

## 12. รัน Tests

Model:

```powershell
cd C:\Users\araya\Downloads\MFUguiding\model
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

ผลล่าสุด: 28 tests ผ่านหลังเปิด Stable Zone Navigation

Backend:

```powershell
cd C:\Users\araya\Downloads\MFUguiding\backend-node
npm.cmd run test:navigation
```

ผลล่าสุด: 10 tests ผ่าน

Flutter/Android:

```powershell
cd C:\Users\araya\Downloads\MFUguiding\frontend
flutter analyze
flutter test
```

```powershell
cd C:\Users\araya\Downloads\MFUguiding\frontend\android
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
.\gradlew.bat compileDebugKotlin --no-daemon
```

Android compile ล่าสุดผ่าน `BUILD SUCCESSFUL`

## 13. ปัญหาการรันที่พบบ่อย

- `Cannot connect to backend`: Backend ปิด, IP/port ผิด, Firewall หรือ Wi-Fi client isolation
- `No route to host`: APK ฝัง IP เก่า ต้องตรวจ IP, ทดสอบ `/healthz` จากมือถือ และ build ใหม่
- `/healthz = 503`: MongoDB ไม่พร้อม ตรวจ Atlas whitelist และ URI `mongodb+srv://`
- PowerShell ผ่าน proxy: ใช้ `curl.exe --noproxy "*"`
- `zone_model_loaded = false`: ตรวจ `model/models/zone_classifier.joblib`
- `multi_ap_model_loaded = false`: ตรวจ `model/models/hybrid_model.joblib`
- `Unknown AS-Project BSSID`: แก้ mapping ใน `frontend/lib/connected_wifi_service.dart`
- `POST /sessions/.../observations 404`: Backend/Model คนละ schema หรือ version ให้ตรวจ integration และ restart ทั้งคู่
- Flutter build ต้องการ symlink: เปิด Windows Developer Mode
- Gradle/Flutter ค้าง: ปิด process ที่ค้างแล้วรัน `flutter clean`

## 14. ไฟล์สำคัญสำหรับผู้พัฒนาหรือ AI คนถัดไป

- `frontend/lib/connected_wifi_service.dart` — connected AP และ scan RSSI 3 AP
- `frontend/android/app/src/main/kotlin/com/example/mfuguide/MainActivity.kt` — Android Wi-Fi MethodChannel
- `frontend/lib/navigation_api.dart` — observation payload
- `frontend/lib/map_start.dart` — polling, loading, marker และ route
- `backend-node/server/Project/navigation/service/navigation-session.service.js` — validate/store/forward
- `backend-node/server/Project/navigation/models/navigation-observation.model.js` — observation schema
- `model/positioning/service.py` — median, roaming, fingerprint, position, route
- `model/positioning/multi_ap_positioner.py` — inference RSSI 3 AP
- `model/positioning/roaming_tracker.py` — hysteresis
- `model/positioning/zone_config.json` — anchors/config
- `model/models/hybrid_model.joblib` — fingerprint model
- `model/tests/test_positioning_service.py` — behavior tests

## 15. Prompt ส่งให้ AI ทำต่อ

```text
ช่วยทำงานต่อในโปรเจกต์ MFU SmartGuide ตาม RUN_FULL_SYSTEM.md และอ่านไฟล์ในหัวข้อ "ไฟล์สำคัญสำหรับผู้พัฒนาหรือ AI คนถัดไป" ก่อนแก้ไข

สถานะปัจจุบัน:
- Flutter สแกน RSSI AP1/AP2/AP3 และส่งทุกประมาณ 1 วินาที
- Backend เก็บ observation ใน MongoDB และส่ง Python Model
- Model ใช้ median RSSI, roaming hysteresis, 3-AP fingerprint และ A* route
- หน้าโหลดรอข้อมูลครบ 3 AP ติดต่อกัน 3 รอบ
- หมุดเคลื่อนตาม waypoint และตัดเส้นที่ผ่านแล้ว

สถานะล่าสุด:
เพิ่ม fingerprint-zone hysteresis 3 observations, monotonic route progress, จำกัดการเปลี่ยนพิกัด 0.75 เมตรต่อ observation, arrival guard รัศมี 1.5 เมตร/3 observations และ wall-collision validation แล้ว ระบบยังใช้ A* เพราะให้ shortest path เช่นเดียวกับ Dijkstra แต่ค้นหาเร็วกว่า งานถัดไปคือตรวจผลบนมือถือด้วย RSSI จริงและแก้เฉพาะกรณีที่ tests ยังไม่ครอบคลุม

ข้อกำหนด:
1. ตรวจ implementation และ tests เดิมก่อนแก้
2. ห้ามใช้ destination เป็น feature ทำนายตำแหน่งผู้ใช้
3. ห้ามย้ายหมุดไป destination เพียงเพราะเลือก destination
4. รองรับกรณีสแกนไม่ครบ 3 AP
5. รักษาและเพิ่ม tests ครอบคลุม transient spike, sticky association, false arrival และ stable transition
6. รัน Model tests, Backend navigation tests และ Flutter/Android compile
7. สรุปไฟล์ที่แก้และวิธีทดสอบบนมือถือ
```

## 16. Git และความลับ

- ตรวจ `git status` ก่อน commit เพราะ worktree อาจมีการแก้ไขอื่น
- ห้าม commit `.env.local`, credentials, Atlas URI หรือรหัส Controller
- ไม่ควร commit `model/.venv`, `__pycache__`, build output หรือ APK
- ก่อน commit ใช้ `git diff --check`
