# Task: ติดตั้งระบบ Indoor WiFi Positioning & Navigation Model เข้าโปรเจกต์

## บริบท

โปรเจกต์นี้เป็นระบบระบุตำแหน่งและนำทางในอาคารด้วย WiFi (indoor positioning) มีเทมเพลตอยู่แล้วที่
`backend-node/` และ `frontend-vue/` **แต่ยังไม่ต้องแตะสองโฟลเดอร์นี้** งานตอนนี้คือติดตั้งเฉพาะ
ส่วนโมเดล machine learning ให้เข้าไปอยู่ในโปรเจกต์ก่อน แล้วรันทดสอบให้ผ่าน

ระบบมี 3 ส่วนทำงานต่อเนื่องกัน:
1. **Hybrid positioning**: หา AP ที่สัญญาณแรงสุด (roaming zone) ก่อน แล้วใช้ RSSI ทั้ง 3 AP ทำ KNN
   fingerprinting หาพิกัด (x, y) ละเอียดขึ้นภายในโซนนั้น
2. **Occupancy grid**: แปลงภาพ floor plan เป็นตาราง 0.25 ม./ช่อง บอกว่าเดินได้/เดินไม่ได้
3. **A\* pathfinding**: หาเส้นทางจากตำแหน่งปัจจุบันไปจุดหมาย โดยหลบพื้นที่เดินไม่ได้

## ขั้นตอนที่ต้องทำ

### 1. สร้างโฟลเดอร์ `model/` ที่ root ของ repo (ระดับเดียวกับ `backend-node/`, `frontend-vue/`)

ย้าย/สร้างโครงสร้างไฟล์ตามนี้ (ไฟล์ตัวอย่างอยู่ใน `indoor_nav_model.zip` ที่แนบมาให้แล้ว — แตกไฟล์
แล้วย้ายเนื้อหาทั้งหมดเข้า `model/`):

```
indoor_nav_model/
├── data/
│   ├── wifi_dataset.csv
│   └── access_points.csv
├── floorplan/
│   ├── floorplan_clean.png
│   ├── floorplan_with_grid_ref.png
│   ├── build_occupancy_grid.py
│   ├── occupancy_grid.npy          (สร้างจาก build_occupancy_grid.py)
│   ├── occupancy_overlay.png       (สร้างจาก build_occupancy_grid.py)
│   └── grid_config.json            (สร้างจาก build_occupancy_grid.py)
├── models/
│   ├── train_fingerprint_model.py
│   ├── train_hybrid_model.py
│   ├── fingerprint_knn.joblib       (สร้างจากการรันเทรน)
│   ├── fingerprint_rf.joblib        (สร้างจากการรันเทรน)
│   ├── hybrid_model.joblib          (สร้างจากการรันเทรน)
│   ├── training_report.json         (สร้างจากการรันเทรน)
│   └── hybrid_training_report.json  (สร้างจากการรันเทรน)
├── navigation/
│   └── astar.py
├── navigate_demo.py
├── requirements.txt   (ต้องสร้างใหม่ — ดูข้อ 2)
└── README.md
```

### 2. สร้าง `model/requirements.txt`

```
numpy
pandas
scikit-learn
scipy
pillow
joblib
```

### 3. ติดตั้ง environment และรันไพพ์ไลน์ให้ครบ

```bash
cd model
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# 3.1 สร้าง occupancy grid จากภาพ floor plan
cd floorplan && python3 build_occupancy_grid.py && cd ..

# 3.2 เทรนโมเดลตำแหน่ง (ทั้ง baseline และ hybrid)
cd models && python3 train_fingerprint_model.py && python3 train_hybrid_model.py && cd ..

# 3.3 รันเดโมครบวงจร ตรวจว่าทุกอย่างต่อกันได้
python3 navigate_demo.py
```

### 4. เกณฑ์ตรวจว่าสำเร็จ (acceptance criteria)

- [ ] `python3 build_occupancy_grid.py` รันผ่านไม่มี error และไฟล์ `occupancy_grid.npy`,
      `grid_config.json`, `occupancy_overlay.png` ถูกสร้างขึ้นใน `model/floorplan/`
- [ ] `python3 train_fingerprint_model.py` รันผ่าน และพิมพ์ค่า mean positional error ออกมา
      (ควรอยู่ราว 1.4–2.1 เมตร)
- [ ] `python3 train_hybrid_model.py` รันผ่าน และสร้างไฟล์ `hybrid_model.joblib`
- [ ] `python3 navigate_demo.py` รันผ่าน พิมพ์ผลลัพธ์ประมาณนี้ (ตัวเลขอาจต่างกันได้เล็กน้อย):
      ```
      WiFi reading (AP1=-70, AP2=-60, AP3=-49)
        -> roaming zone (strongest AP): AP3
        -> predicted position: (13.00, 2.00) m
        -> walkable at that position? True

      Path to destination (13.0, 8.0) (N waypoints):
        -> (...)
      ```
- [ ] เปิด `model/floorplan/occupancy_overlay.png` ด้วยสายตา ตรวจว่าพื้นที่สีแดง (บล็อก/เดินไม่ได้)
      ทับกำแพงจริงในภาพพอดี ไม่เพี้ยน

### 5. สิ่งที่ยัง "ไม่ต้องทำ" ในรอบนี้

- ห้ามแก้ไข `backend-node/` หรือ `frontend-vue/`
- ห้ามสร้าง REST API endpoint หรือเชื่อมต่อฐานข้อมูลใหม่
- ห้ามลบ/แก้ไข `.env*`, `docker-compose*.yml`, ไฟล์ deploy อื่น ๆ ที่มีอยู่แล้ว
- ยังไม่ต้องทำ mobile app scanning (WifiManager) — ส่วนนั้นเป็นงานเฟสถัดไป

### 6. หมายเหตุสำคัญ

- โมเดลปัจจุบันเทรนจากจุดอ้างอิงแค่ 8 จุด ความแม่นยำอยู่ที่ประมาณ 1.4 เมตร ถ้าอยากแม่นขึ้นต้องเก็บ
  WiFi fingerprint เพิ่ม (ดูรายละเอียดใน `model/README.md` หัวข้อ "ข้อจำกัด")
- โซนลายเส้นทแยงมุมบนซ้ายของแปลนถูกตั้งให้เป็น "เดินไม่ได้" แบบ manual override ใน
  `build_occupancy_grid.py` (ตัวแปร `HATCHED_EXCLUSION_BOX_M`) เพราะไม่มีชื่อห้องกำกับในแปลน — ถ้า
  ตรวจสอบแล้วพบว่าควรเป็นพื้นที่เดินได้ ให้แก้ค่านี้แล้วรัน `build_occupancy_grid.py` ใหม่
