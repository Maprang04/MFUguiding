# MFU SmartGuide

ระบบนำทางภายในอาคาร ประกอบด้วย Flutter Android, Node.js Backend, Python Positioning API และ MongoDB Atlas

```text
Android app -> Node.js Backend (:8097) -> Python Positioning API (:8001)
                    |
                    -> MongoDB Atlas (indoor_navigation)
```

มือถืออ่าน AP/BSSID ที่เชื่อมต่ออยู่และ RSSI ทุก 1 วินาที โมเดลช่วยจำแนกโซน และระบบยืนยันการ roaming 3 ค่าติดต่อกันก่อนเปลี่ยนโซน เมื่อเปลี่ยนโซนแล้วหมุดจะค่อย ๆ เลื่อนไปตามเส้นทางด้วยความเร็วประมาณ 1.1 เมตร/วินาที ระบบรุ่นปัจจุบันไม่ใช้ Step Counter ดังนั้นตำแหน่งระหว่างโซนเป็นตำแหน่งประมาณการ ไม่ใช่พิกัดจริงระดับจุด

## ฟังก์ชันปัจจุบัน

### ผู้ใช้

- Sign in/Sign out และเก็บ session อย่างปลอดภัยบนอุปกรณ์
- ค้นหาห้องพร้อมคำแนะนำระหว่างพิมพ์
- บันทึกและเริ่มนำทางจากหน้า Favorite
- อ่าน AP/BSSID ที่มือถือเชื่อมต่อเพื่อหาโซนเริ่มต้นอัตโนมัติ โดยไม่ถามตำแหน่งเริ่มต้น
- แสดงเส้นทางบนแผนที่และติดตามหมุดแบบ follow camera
- เมื่อยืนยัน roaming หมุดจะเคลื่อนผ่าน waypoint ด้วยความเร็วประมาณ 1.1 เมตร/วินาที และตัดเส้นที่เดินผ่านมา
- ส่งรายงานปัญหาการใช้งานแอป

### ผู้ดูแลระบบ

- Dashboard สรุปจำนวนห้อง, AP, โซน และรายงานที่เปิดอยู่
- จัดการข้อมูลแผนที่ ห้อง จุดหมาย AP และโซน
- ดูและเปลี่ยนสถานะรายงานจากผู้ใช้
- แยกสิทธิ์และหน้าจอ Admin ออกจาก User

### Backend และ Model

- REST API สำหรับ authentication, favorites, reports, map catalog และ navigation sessions
- เก็บข้อมูลใน MongoDB Atlas database `indoor_navigation`
- Python FastAPI ประเมินโซน กรอง RSSI ด้วย median และคำนวณเส้นทางบนกริด 0.25 เมตร
- Zone classifier ช่วยเพิ่มความเชื่อมั่น แต่ AP ที่มือถือเชื่อมต่อเป็นขอบเขตหลักของโซน
- ยืนยัน AP ใหม่ 3 observation ก่อนเปลี่ยนโซน เพื่อลดอาการตำแหน่งเด้ง

## สิ่งที่ต้องติดตั้ง

- Python และ virtual environment ที่ `model/.venv`
- Node.js 20 LTS
- Flutter SDK และ Android Studio
- MongoDB Atlas พร้อม database `indoor_navigation`
- มือถือ Android และคอมพิวเตอร์ที่เชื่อมต่อถึงกันผ่านเครือข่ายเดียวกัน

ห้าม commit `.env.local`, MongoDB URI, รหัสผ่าน หรือ API key

## 1. ตั้งค่า Backend

สร้างหรือแก้ไฟล์ `backend-node/.env.local`:

```env
PORT=8097
MONGODB_ATLAS=mongodb+srv://<username>:<url-encoded-password>@<cluster-host>/indoor_navigation?retryWrites=true&w=majority
INDOOR_NAVIGATION_DB=indoor_navigation

POSITIONING_MODE=http
POSITIONING_SERVICE_URL=http://127.0.0.1:8001
POSITIONING_SERVICE_TIMEOUT_MS=5000
POSITIONING_SIMULATOR_ENABLED=false
NAVIGATION_OBSERVATION_SOURCE=mobile
POSITIONING_ROAMING_CONFIRMATIONS=3
```

ใน Atlas ให้เพิ่ม **Public IP** ปัจจุบันที่ `Security > Network Access > Add Current IP Address` และตรวจว่า collections อยู่ใน database `indoor_navigation` ไม่ใช่ `NewSystem` ควรใช้ URI แบบ `mongodb+srv://` ไม่ใช่รายการ shard host แบบเก่า

## 2. เปิด Python Positioning Model

เปิด PowerShell หน้าต่างที่ 1:

```powershell
cd C:\Users\araya\Downloads\MFUguiding\model
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m uvicorn positioning_api:app --host 0.0.0.0 --port 8001
```

ตรวจสอบ:

```text
http://127.0.0.1:8001/health
http://127.0.0.1:8001/docs
```

`/health` ควรตอบสำเร็จและมี `"zone_model_loaded": true`

หากต้องฝึกโมเดลใหม่จาก fingerprint:

```powershell
cd C:\Users\araya\Downloads\MFUguiding\model
.\.venv\Scripts\python.exe models\train_zone_classifier.py
```

## 3. เปิด Node.js Backend

เปิด PowerShell หน้าต่างที่ 2 โดยไม่ปิด Model:

```powershell
cd C:\Users\araya\Downloads\MFUguiding\backend-node
npm.cmd install
npm.cmd run start:local
```

ตรวจสอบจาก PowerShell อีกหน้าต่าง:

```powershell
curl.exe --noproxy "*" http://127.0.0.1:8097/healthz
curl.exe --noproxy "*" http://127.0.0.1:8097/api/v1/navigation/health
```

ทั้งสองระบบต้องพร้อมก่อนเปิดแอป ข้อความ `Redis connection failed` ข้ามได้สำหรับการทดสอบ navigation แบบ local แต่ `/healthz` ต้องตอบ `200 OK`

## 4. รัน Flutter ระหว่างพัฒนา

### Android Emulator

```powershell
cd C:\Users\araya\Downloads\MFUguiding\frontend
flutter pub get
flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8097
```

### มือถือผ่าน USB Debugging

```powershell
cd C:\Users\araya\Downloads\MFUguiding\frontend
flutter devices
adb -s <device-id> reverse tcp:8097 tcp:8097
flutter run -d <device-id> --dart-define=BACKEND_BASE_URL=http://127.0.0.1:8097
```

ระหว่าง `flutter run` กด `r` เพื่อ Hot Reload และกด `R` เพื่อ Hot Restart

## 5. สร้าง APK สำหรับติดตั้งโดยไม่เปิด Developer mode

ดู IPv4 ของคอมพิวเตอร์:

```powershell
ipconfig
```

ก่อน build ให้เปิด URL ต่อไปนี้จาก browser บนมือถือ โดยแทน `<computer-ip>` ด้วย IPv4 ปัจจุบัน:

```text
http://<computer-ip>:8097/healthz
```

ถ้าขึ้น `OK` ให้สร้าง APK:

```powershell
cd C:\Users\araya\Downloads\MFUguiding\frontend
flutter clean
flutter pub get
flutter build apk --release --dart-define=BACKEND_BASE_URL=http://<computer-ip>:8097
```

ห้ามคัดลอก IP จากตัวอย่างเก่าหรือจากวันก่อน เพราะ DHCP ของเครือข่ายอาจเปลี่ยน IP ทุกวัน

APK อยู่ที่:

```text
C:\Users\araya\Downloads\MFUguiding\frontend\build\app\outputs\flutter-apk\app-release.apk
```

เปิดโฟลเดอร์ด้วย:

```powershell
explorer "C:\Users\araya\Downloads\MFUguiding\frontend\build\app\outputs\flutter-apk"
```

ส่ง APK ไปมือถือ เปิด `Install unknown apps` ให้แอปที่ใช้เปิดไฟล์ แล้วติดตั้ง

## 6. วิธีอัปเดตแอปหลังแก้โค้ด

แอปที่ติดตั้งจาก APK ไม่อัปเดตอัตโนมัติ หลังแก้โค้ดให้:

1. ตรวจ IPv4 ของคอมพิวเตอร์อีกครั้ง
2. รัน `flutter clean` และ `flutter pub get`
3. build `app-release.apk` ใหม่ด้วย `BACKEND_BASE_URL` ที่ถูกต้อง
4. ส่ง APK ใหม่ไปมือถือและกดติดตั้งทับแอปเดิม

ถ้า package name และ signing key ไม่เปลี่ยน สามารถติดตั้งทับและเก็บข้อมูลเดิมได้ หาก Android แจ้งว่าลายเซ็นไม่ตรง ต้องถอนแอปเดิมก่อน ซึ่งจะลบข้อมูลภายในแอป

## 7. ทดสอบตำแหน่งด้วย Wi-Fi จริง

1. เปิด Model ที่พอร์ต `8001`
2. เปิด Backend ที่พอร์ต `8097`
3. ใช้มือถือเปิด `http://<computer-ip>:8097/healthz` และต้องพบ `OK`
4. เชื่อมมือถือกับ SSID `AS-Project`
5. เปิด Wi-Fi และ Location
6. อนุญาต Location และ Nearby Wi-Fi Devices ให้แอป ไม่จำเป็นต้องอนุญาต Physical Activity สำหรับระบบปัจจุบัน
7. Sign in แล้วเลือกห้องปลายทาง
8. กดเริ่มนำทาง แอปจะอ่าน AP/BSSID และหาโซนเริ่มต้นอัตโนมัติ ไม่ถามจุดเริ่มต้น
9. ตรวจว่าหมุดและเส้นทางเริ่มจาก anchor ของโซนที่ตรวจพบ
10. เดินไปยังพื้นที่ของ AP ถัดไป ระบบจะตรวจ Wi-Fi ทุก 1 วินาที
11. เมื่อพบ AP ใหม่ครบ 3 ครั้ง ระบบจะยืนยัน roaming คำนวณเส้นใหม่ และค่อย ๆ เลื่อนหมุดผ่าน waypoint ด้วยความเร็วประมาณ 1.1 เมตร/วินาที
12. ตรวจว่าเส้นสีน้ำเงินเริ่มจากหมุดและส่วนที่ผ่านแล้วถูกตัดออก

ข้อจำกัด: AP ที่เชื่อมต่อเพียงตัวเดียวระบุได้ในระดับโซน ระบบไม่สามารถรู้ความเร็วหรือทิศทางการเดินจริงระหว่าง AP ได้ การเคลื่อนหมุดจึงเป็นภาพประมาณการตามเส้นทาง

## 8. BSSID และ AP Mapping

แก้ mapping ได้ที่ `frontend/lib/connected_wifi_service.dart`

```text
AP1 -> RIGHT_WING
AP2 -> CENTRAL_HALLWAY
AP3 -> LEFT_WING
```

ถ้าแอปแสดง `Unknown AS-Project BSSID` ให้นำ BSSID ที่แสดงมาเพิ่ม mapping ให้ตรงกับ AP จริง

## 9. รันชุดทดสอบ

Model:

```powershell
cd C:\Users\araya\Downloads\MFUguiding\model
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

Backend navigation:

```powershell
cd C:\Users\araya\Downloads\MFUguiding\backend-node
npm.cmd run test:navigation
```

Flutter:

```powershell
cd C:\Users\araya\Downloads\MFUguiding\frontend
flutter analyze
flutter test
```

## Troubleshooting

- `healthz = 503`: Backend เปิดแล้วแต่ MongoDB ยังไม่พร้อม ตรวจ URI แบบ `mongodb+srv://`, database `indoor_navigation` และเพิ่ม Public IP ปัจจุบันใน Atlas Network Access
- Backend ตอบ `503` แล้ว process ปิด: ดู log จาก `node -r dotenv/config server.js`; `ReplicaSetNoPrimary` หรือ TLS error มักเกิดจาก Atlas Network Access, URI เก่า หรือการใช้ Node 24 กับ dependency เก่า ให้ใช้ Node 20 LTS
- `No route to host`: APK ฝัง LAN IP เก่าของคอม ตรวจ `ipconfig`, ทดสอบ URL จาก browser มือถือ แล้ว build APK ใหม่ด้วย IP ปัจจุบัน
- `curl/Invoke-WebRequest` ได้ผลต่างกัน: ใช้ `curl.exe --noproxy "*"` เพราะเครื่องอาจมี `HTTP_PROXY`
- `Cannot connect to backend`: ตรวจ IP, พอร์ต 8097, Backend, Windows Firewall และ client isolation ของ Wi-Fi
- `zone_model_loaded = false`: ตรวจ `model/models/zone_classifier.joblib` หรือฝึกโมเดลใหม่
- `Unknown AS-Project BSSID`: เพิ่ม BSSID prefix ใน `connected_wifi_service.dart`
- หมุดไม่เปลี่ยนโซน: ตรวจว่ามือถือ roaming ไป AP ใหม่จริง และ BSSID ตรงกับ mapping
- `Redis connection failed`: ข้ามได้ในการทดสอบ local navigation
- `JAVA_HOME is not set`: ใช้ JDK ที่ `C:\Program Files\Android\Android Studio\jbr`
- build ค้าง: ปิด Android Studio/โปรเซส Dart ที่ค้าง เปิด terminal ใหม่ แล้วรัน `flutter clean` อีกครั้ง

## กรณี AP บางตัวดับ

- มือถือเครื่องเดียวไม่สามารถยืนยันได้แน่นอนว่า AP ดับ จึงควรแสดงเป็น `suspected unavailable`
- ถ้ามือถือข้ามจาก AP หนึ่งไปอีก AP หนึ่ง ระบบยังยืนยัน AP ใหม่ตามจำนวน observation และคำนวณเส้นทางใหม่ได้
- หมุดต้องเดินผ่านเส้นทางบนแผนที่ ไม่กระโดดข้ามพื้นที่ และหยุดที่ตำแหน่งล่าสุดที่ยืนยันได้แทนการเดินเองถึงปลายทาง
- RSSI ต่ำมาก, อ่าน BSSID ไม่ได้ หรือหลุดจาก `AS-Project` ต้องลด confidence และแจ้งว่าตำแหน่งเป็นค่าประมาณ
- เมื่อเชื่อม Cisco Controller ในอนาคต ควรใช้สถานะ Registered/Up และเวลาที่พบ AP ล่าสุดเป็นแหล่งตรวจ AP outage หลัก

รายละเอียด API เพิ่มเติมอยู่ที่ `docs/INDOOR-NAVIGATION-BACKEND-API.md`
