# Indoor Navigation — Maprang Project
## บันทึกขั้นตอนการพัฒนาทั้งหมด

---

## สถาปัตยกรรมระบบ

```
[Flutter App (Android)]
        ↓ HTTP
[Node.js server.js — port 3000]
        ↓                    ↓
[Python Flask          [Ollama — port 11434]
 model_server.py        qwen3:4b  → อธิบายตำแหน่ง
 port 5000]             minicpm-v → วิเคราะห์ผัง
        ↓
[MySQL — indoor_navigation]
 • wifi_dataset
 • access_points
```

---

## ข้อมูลระบบ

| รายการ | ค่า |
|---|---|
| OS | Windows |
| GPU | NVIDIA GeForce RTX 3050 Laptop |
| Node.js | v24.15.0 |
| Python | ติดตั้งแล้ว |
| MySQL | MariaDB 10.4.32 via XAMPP |
| phpMyAdmin | host: 127.0.0.1 |
| DB Name | indoor_navigation |
| DB User | root |
| DB Password | (ว่าง) |
| Ollama Models | qwen3:4b, minicpm-v |

---

## โครงสร้างโฟลเดอร์

```
C:\Users\araya\Downloads\NewSystem\NewSystem\backend-node\
├── server.js          ← Node.js API server
├── model_server.py    ← Python Flask ML server
├── train_model.py     ← เทรนโมเดล Random Forest
└── model.pkl          ← โมเดลที่เทรนแล้ว (สร้างอัตโนมัติ)
```

---

## Database Schema

```sql
-- ตาราง access_points (ตำแหน่ง AP จริงในอาคาร)
CREATE TABLE access_points (
    id   INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    x    DOUBLE NOT NULL,
    y    DOUBLE NOT NULL
);

-- ข้อมูล AP จริง
INSERT INTO access_points (name, x, y) VALUES
    ('AP1', 16,   11.5),
    ('AP2', 10.2,  9.5),
    ('AP3',  2,    1.0);

-- ตาราง wifi_dataset (fingerprint data)
CREATE TABLE wifi_dataset (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    ap1        INT NOT NULL,
    ap2        INT NOT NULL,
    ap3        INT NOT NULL,
    x          DOUBLE NOT NULL,
    y          DOUBLE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**ข้อมูลที่เก็บได้:** 79 แถว, 8 ตำแหน่ง

---

## Map พิกัด → ชื่อพื้นที่

| พิกัด (x, y) | ภาษาไทย | English |
|---|---|---|
| (1, 2) | ทางเข้าอาคาร | Building Entrance |
| (5, 2) | ทางเดินกลางอาคาร | Main Corridor |
| (9, 2) | ทางเดินกลางอาคาร | Main Corridor |
| (13, 2) | ทางเดินกลางอาคาร | Main Corridor |
| (13, 4) | หน้า Room 1 และ Room 3 | In front of Room 1 & Room 3 |
| (13, 8) | หน้า Room 2 | In front of Room 2 |
| (16, 3.75) | ทางเข้า Hallway เล็ก | Small Hallway Entrance |
| (19, 3.75) | ทางเดินกลาง Hallway เล็ก | Small Hallway Center |

**BSSID ของ AP ที่ใช้:**
- AP1: `f0:1d:2d:ba:38:xx`
- AP2: `f0:1d:2d:ba:98:xx`
- AP3: `f0:1d:2d:bc:41:xx`

---

## ผลการเทรนโมเดล

```
โมเดล: Random Forest (MultiOutputRegressor)
n_estimators: 200
การแบ่งข้อมูล: 80% train / 20% test
ข้อมูล: 79 แถว → train 63, test 16
MAE (X): 1.299 เมตร
MAE (Y): 0.863 เมตร
ระยะห่างเฉลี่ย: ±1.82 เมตร
```

---

## วิธีรันระบบ (ทุกครั้งที่ใช้งาน)

ต้องเปิด Terminal **3 อัน** พร้อมกัน:

### Terminal 1 — Python ML Server
```bash
cd C:\Users\araya\Downloads\NewSystem\NewSystem\backend-node
python model_server.py
```
ขึ้น: `✓ Server รันที่ http://localhost:5000`

### Terminal 2 — Node.js Server
```bash
cd C:\Users\araya\Downloads\NewSystem\NewSystem\backend-node
node server.js
```
ขึ้น: `✓ Server รันที่ http://localhost:3000`

### Terminal 3 — Ollama
Ollama รันอัตโนมัติตอน Windows บูทแล้ว **ไม่ต้องรันเพิ่ม**
ถ้าต้องการเช็ค: `ollama list`

### เช็คสถานะทั้งหมด
```
http://localhost:3000/health
```
ควรได้:
```json
{
  "node_server": "online",
  "ml_server": "online",
  "ollama": "online",
  "port": 3000
}
```

---

## API Endpoints

### POST /locate
ทำนายตำแหน่งจากค่า RSSI ด้วย ML model

**Request:**
```json
{ "ap1": -67, "ap2": -68, "ap3": -61 }
```
**Response:**
```json
{
  "x": 9.0,
  "y": 2.0,
  "confidence": 0.87,
  "location_th": "ทางเดินกลางอาคาร",
  "location_en": "Main Corridor"
}
```

---

### POST /explain
ให้ Qwen3 อธิบายตำแหน่งเป็นภาษาไทย + อังกฤษ

**Request:**
```json
{ "x": 9, "y": 2 }
```
**Response:**
```json
{
  "explanation_th": "คุณอยู่ที่ทางเดินกลางอาคาร",
  "explanation_en": "You are at Main Corridor",
  "location_th": "ทางเดินกลางอาคาร",
  "location_en": "Main Corridor",
  "x": 9,
  "y": 2
}
```
> หมายเหตุ: ถ้า Ollama timeout จะมี `"fallback": true` แต่ยังได้คำตอบที่ถูกต้อง

---

### POST /save-point
บันทึก fingerprint ลง MySQL

**Request:**
```json
{ "ap1": -67, "ap2": -68, "ap3": -61, "x": 9, "y": 2 }
```
**Response:**
```json
{ "success": true, "insertId": 81 }
```

---

### GET /health
เช็คสถานะ server ทั้งหมด

---

## ไฟล์ที่สำคัญ

### train_model.py
```python
# รันครั้งเดียวเพื่อสร้าง model.pkl
# python train_model.py
import mysql.connector, pandas as pd, numpy as np, pickle
from sklearn.ensemble import RandomForestRegressor
from sklearn.multioutput import MultiOutputRegressor
from sklearn.model_selection import train_test_split

DB_CONFIG = {
    "host": "127.0.0.1", "user": "root",
    "password": "", "database": "indoor_navigation"
}

conn = mysql.connector.connect(**DB_CONFIG)
cursor = conn.cursor()
cursor.execute("SELECT ap1, ap2, ap3, x, y FROM wifi_dataset")
rows = cursor.fetchall()
cursor.close(); conn.close()

df = pd.DataFrame(rows, columns=["ap1","ap2","ap3","x","y"])
X = df[["ap1","ap2","ap3"]].values
y = df[["x","y"]].values
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

model = MultiOutputRegressor(RandomForestRegressor(n_estimators=200, random_state=42, n_jobs=-1))
model.fit(X_train, y_train)

with open("model.pkl", "wb") as f:
    pickle.dump(model, f)
print("✓ บันทึก model.pkl เรียบร้อย")
```

### model_server.py
```python
# python model_server.py
import pickle, numpy as np
from flask import Flask, request, jsonify

app = Flask(__name__)
with open("model.pkl", "rb") as f:
    model = pickle.load(f)

@app.route("/predict", methods=["POST"])
def predict():
    data = request.get_json()
    ap1, ap2, ap3 = data["ap1"], data["ap2"], data["ap3"]
    features = np.array([[ap1, ap2, ap3]])
    prediction = model.predict(features)
    x = round(float(prediction[0][0]), 2)
    y = round(float(prediction[0][1]), 2)

    tree_preds = np.array([e.predict(features)[0] for e in model.estimators_])
    avg_std = (np.std(tree_preds[:,0]) + np.std(tree_preds[:,1])) / 2
    confidence = round(max(0.0, 1.0 - (avg_std / 3.0)), 2)

    return jsonify({"x": x, "y": y, "confidence": confidence})

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
```

---

## Flutter / Client App Notes

ในโปรเจกต์นี้ยังไม่มีไฟล์ `main.dart` อยู่ใน workspace ของ backend-node ดังนั้นข้อมูลด้าน Flutter ที่เขียนไว้เป็นประวัติ/แนวทางการใช้งานเดิม ไม่ใช่ไฟล์หลักของโครงงานปัจจุบัน

หากมีการต่อ client app ภายนอก ให้กำหนด IP ของ Node.js server เป็น:
```text
http://172.25.11.63:3000
```

เช็ค IP ปัจจุบันของ server ด้วย:
```bash
ipconfig
# ดูที่ Wireless LAN adapter Wi-Fi → IPv4 Address
```

---

## ปัญหาที่เจอและวิธีแก้

| ปัญหา | สาเหตุ | วิธีแก้ |
|---|---|---|
| Red screen `_dependents.isEmpty` | AnimatedBuilder เปลี่ยน tree shape ตอน scan | ใช้ `AnimatedBuilder` ตลอดเวลา ไม่สลับ widget type |
| Red screen ตอนกด "Use This" | `StatefulBuilder` + Form ใน dialog | เอา Form/GlobalKey ออก ใช้ plain TextField |
| Position เปลี่ยนเองหลัง confirm | `locate()` overwrite x,y หลัง dialog ปิด | เพิ่ม `_positionGeneration` counter |
| Save ขึ้น success แต่ไม่มีใน DB | phpMyAdmin แสดงผลค้าง | กด Browse ใหม่ หรือรัน `SELECT COUNT(*)` |
| `No route to host` | IP server เปลี่ยน (DHCP) | รัน `ipconfig` แล้วแก้ IP ใน main.dart |
| `ollama serve` error | Ollama รันอยู่แล้ว | ไม่ต้องรัน serve เพิ่ม |
| `Cannot find module 'mysql2'` | ยังไม่ install npm packages | `npm install mysql2 express cors` |
| `fallback: true` ใน /explain | Ollama timeout 30 วินาที | เพิ่ม timeout เป็น 120000 ms |

---

## สิ่งที่ทำเสร็จแล้ว ✅

```
✅ Flutter app — scan WiFi + แสดง AP signal
✅ Flutter app — manual position input (dialog)
✅ Flutter app — save fingerprint ไป server
✅ MySQL — wifi_dataset + access_points
✅ server.js — /save-point, /locate, /explain, /health
✅ train_model.py — เทรน Random Forest ±1.82m
✅ model_server.py — Flask API port 5000
✅ Ollama — qwen3:4b + minicpm-v ดาวน์โหลดแล้ว
✅ /explain — อธิบายตำแหน่งภาษาไทย+อังกฤษ
```

## สิ่งที่ต้องทำต่อ ⬜

```
⬜ Phase 3 — ระบบนำทาง A* (หาเส้นทาง)
⬜ Phase 4 — แสดงแผนที่ใน Flutter (รูป As.png)
⬜ Phase 4 — วาดจุดตำแหน่งปัจจุบันบนแผนที่
⬜ Phase 4 — แสดงคำอธิบาย LLM ใน Flutter
⬜ Phase 2B — วิเคราะห์ผังด้วย minicpm-v
⬜ Vue.js frontend จากเทมเพลต NewSystem
```
