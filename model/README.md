# ระบบระบุตำแหน่งและนำทางในอาคารด้วย WiFi (Indoor WiFi Positioning & Navigation)

โปรเจกต์นักศึกษา — ส่วนของ **โมเดล machine learning** เท่านั้น (ยังไม่รวม frontend/backend ตาม
scope ที่อาจารย์กำหนด)

## ภาพรวมระบบ

ระบบมี 3 ส่วนหลัก ทำงานต่อเนื่องกัน:

1. **การระบุตำแหน่ง (Positioning)** — แบบ hybrid ผสม 2 วิธี:
   - **Roaming zone**: ดูว่า AP ตัวไหนสัญญาณแรงสุด (จำลองพฤติกรรมการ roam/associate ของมือถือจริง) ให้โซนกว้าง ๆ อย่างรวดเร็วและ robust
   - **RSSI fingerprinting (KNN)**: ใช้ค่า RSSI ของ AP ทั้ง 3 ตัวพร้อมกัน เทียบกับฐานข้อมูลที่เก็บไว้ เพื่อได้พิกัด (x, y) ละเอียดขึ้น ภายในโซนนั้น
2. **แผนที่พื้นที่เดินได้ (Walkability grid)** — แปลงภาพ floor plan เป็นตาราง grid (0.25 ม./ช่อง) บอกว่าช่องไหนเดินได้/เดินไม่ได้ โดยตรวจจับกำแพงจากภาพอัตโนมัติ
3. **การนำทาง (Navigation)** — ใช้ A* หาเส้นทางที่สั้นที่สุดบน grid จากตำแหน่งปัจจุบันไปยังจุดหมาย โดยหลบกำแพง/พื้นที่เดินไม่ได้

```
WiFi RSSI (AP1, AP2, AP3)
        │
        ▼
  [roaming zone: AP ไหนแรงสุด] ──► จำกัดขอบเขตการค้นหา
        │
        ▼
  [KNN fingerprinting ในโซนนั้น] ──► พิกัด (x, y) โดยประมาณ
        │
        ▼
  [ตรวจสอบกับ occupancy grid] ──► ถ้าตกในกำแพง สแนปไปช่องเดินได้ใกล้สุด
        │
        ▼
  [A* pathfinding] ──► เส้นทางไปจุดหมาย (waypoints)
```

## โครงสร้างไฟล์

```
indoor_nav_model/
├── .env.example                  # เทมเพลตค่าเชื่อมต่อ MySQL (คัดลอกเป็น .env)
├── requirements.txt
├── data/
│   ├── load_data.py               # โหลดข้อมูล: MySQL ก่อน -> fallback CSV
│   ├── wifi_dataset.csv          # 176 samples, 18 จุดอ้างอิง (snapshot ล่าสุดจาก .sql)
│   └── access_points.csv         # ตำแหน่ง AP1, AP2, AP3
├── floorplan/
│   ├── floorplan_clean.png       # ภาพแปลนต้นฉบับ (ไม่มี grid/dot overlay)
│   ├── floorplan_with_grid_ref.png  # ใช้ calibrate พิกัดพิกเซล<->เมตร
│   ├── build_occupancy_grid.py   # สคริปต์สร้าง occupancy grid จากภาพ
│   ├── occupancy_grid.npy        # ผลลัพธ์: grid เดินได้/เดินไม่ได้
│   ├── occupancy_overlay.png     # ภาพตรวจสอบว่า grid ตรงกับกำแพงจริงไหม
│   └── grid_config.json          # ค่า transform + ขนาด grid
├── models/
│   ├── train_fingerprint_model.py  # โมเดล fingerprinting อย่างเดียว (baseline)
│   ├── train_hybrid_model.py       # โมเดล hybrid (roaming zone + fingerprinting) ★ ใช้ตัวนี้
│   ├── fingerprint_knn.joblib
│   ├── fingerprint_rf.joblib
│   ├── hybrid_model.joblib
│   ├── training_report.json
│   └── hybrid_training_report.json
├── navigation/
│   ├── astar.py                  # A* pathfinding บน occupancy grid
│   └── path_demo.png             # ภาพตัวอย่างเส้นทางที่คำนวณได้
└── navigate_demo.py               # เดโมครบวงจร: WiFi -> ตำแหน่ง -> เส้นทาง
```

## วิธีใช้งาน

```bash
pip install -r requirements.txt --break-system-packages
cp .env.example .env   # ปรับค่าตามเครื่องจริงถ้าจำเป็น

# 1. สร้าง occupancy grid จาก floor plan (รันครั้งเดียว หรือรันใหม่ถ้าแปลนเปลี่ยน)
cd floorplan && python3 build_occupancy_grid.py && cd ..

# 2. เทรนโมเดล (จะพยายามอ่านจาก MySQL ก่อน แล้ว fallback เป็น CSV อัตโนมัติ)
cd models && python3 train_fingerprint_model.py && python3 train_hybrid_model.py && cd ..

# 3. รันเดโมครบวงจร
python3 navigate_demo.py
```

## รายละเอียดแต่ละส่วน

### 1. ข้อมูล (data/)

`data/load_data.py` เป็นตัวโหลดข้อมูลกลางที่ทั้งสองสคริปต์เทรนใช้ร่วมกัน — **อ่านจาก MySQL โดยตรง
เป็นค่าเริ่มต้น** (ใช้ credential ชุดเดียวกับที่ `backend-node` เชื่อมต่ออยู่แล้ว: host `localhost`,
user `root`, password ว่าง, database `indoor_navigation`) แล้ว **fallback เป็นไฟล์ CSV
(`data/wifi_dataset.csv`) อัตโนมัติถ้าต่อ DB ไม่ได้** (เช่น รันบนเครื่องที่ไม่มี MySQL หรือยังไม่ได้
ตั้งค่า) ไฟล์ CSV คือ snapshot ล่าสุดที่แปลงมาจาก `.sql` dump ที่ให้มา ใช้เป็น fallback/backup

**ตั้งค่าการเชื่อมต่อ:** คัดลอก `.env.example` เป็น `.env` แล้วปรับตามเครื่องจริง (ค่า default ตรงกับ
mysql pool ของ backend-node อยู่แล้ว ไม่ต้องแก้ถ้าใช้ setup เดียวกัน)

```bash
cp .env.example .env
```

ทดสอบว่าต่อ DB ได้ไหม:
```bash
cd data && python3 load_data.py
```
ถ้าต่อไม่ได้จะเห็นข้อความ fallback ไปอ่าน CSV แทน (ไม่ error ทั้งโปรแกรม)

### 2. Occupancy grid (floorplan/)

เนื่องจากไม่มีข้อมูล CAD/vector ของแปลน จึงต้อง **calibrate พิกเซล↔เมตร ก่อน** โดยตรวจจับจุดสีแดง
อ้างอิง 8 จุดในภาพ (พิกัดเมตรตรงกับจุดเก็บ fingerprint พอดี) แล้ว fit เส้นตรง px = a·m + b แยกแกน x, y
(ความคลาดเคลื่อนต่ำกว่า 3 พิกเซล) จากนั้นตรวจจับพิกเซลสีดำ (กำแพง) ในภาพต้นฉบับ แล้วแปลงเป็น grid
ขนาดช่องละ 0.25 เมตร

**ข้อควรระวัง / สมมติฐานที่ทำไว้:**
- พื้นที่ลายเส้นทแยง (hatched zone) มุมบนซ้าย **ถูกกำหนดให้เดินไม่ได้ (blocked)** เพราะไม่มีชื่อห้องกำกับ
  ในแปลน และตามธรรมเนียมงานสถาปัตย์ ลายเส้นแบบนี้มักหมายถึงพื้นที่ทึบ/ไม่ให้เข้า — ถ้าจริง ๆ แล้วเป็น
  พื้นที่เดินได้ (เช่น บันได) ต้องแก้ไข `HATCHED_EXCLUSION_BOX_M` ใน `build_occupancy_grid.py`
- พิกัดกำแพง/ห้องทั้งหมดเป็นการประมาณจากภาพ ไม่ใช่ข้อมูล CAD จริง ควรตรวจสอบกับ `occupancy_overlay.png`
  ก่อนใช้งานจริง

### 3. โมเดลตำแหน่ง (models/)

**อัปเดตล่าสุด: เทรนด้วยข้อมูล 176 samples จาก 18 จุดอ้างอิง** (เดิม 79 samples/8 จุด)

| โมเดล | วิธีการ | ค่าคลาดเคลื่อนเฉลี่ย (cross-validated) |
|---|---|---|
| KNN (k=5) fingerprinting อย่างเดียว | ใช้ RSSI ทั้ง 3 ค่า หาจุดใกล้สุดในฐานข้อมูล | ~2.00 ม. |
| Random Forest | เช่นเดียวกัน แต่ใช้ ensemble ของ decision tree | ~2.11 ม. |
| **Hybrid (roaming zone + KNN, k=5)** | หา AP ที่แรงสุด (จำลอง roaming) ก่อน แล้วค่อยหา KNN เฉพาะในโซนนั้น | **~1.99 ม.** |

> **หมายเหตุ**: ค่าคลาดเคลื่อนเพิ่มขึ้นจากรอบก่อน (~1.4-1.5 ม.) แม้มีข้อมูลมากขึ้น เพราะจำนวนจุดอ้างอิง
> เพิ่มจาก 8 เป็น 18 จุด กระจายอยู่ใกล้กันมากขึ้น (เช่น (13,2)/(13,4)/(13,6)/(13,8) ห่างกันแค่ 2 เมตร)
> ทำให้แยกแยะตำแหน่งยากขึ้น — เป็นเรื่องปกติของ fingerprinting ยิ่งจุดอ้างอิงถี่ ยิ่งท้าทายกว่าจุดห่าง ๆ
> แต่ก็สะท้อนความแม่นยำที่ใกล้เคียงการใช้งานจริงมากกว่าเดิม
>
> พบและแก้ไขข้อมูลผิดพลาด 1 จุด: id 111 มี `x=111` (พิมพ์ผิด ควรเป็น `x=11` ตามบริบทแถวข้างเคียงที่
> เก็บช่วงเวลาใกล้กันที่ตำแหน่ง (11,5)) แก้ไขให้แล้วในไฟล์ `data/wifi_dataset.csv`
>
> ค่า RSSI ที่เป็น **-100 dBm** (พบ 14 ค่า จากทั้งหมด) น่าจะเป็นค่า sentinel/ค่าต่ำสุดที่วัดได้ (ไม่ใช่
> สัญญาณจริงที่วัดได้แม่นยำ) เกิดตอนมือถืออยู่ไกลจาก AP ตัวนั้นมาก ๆ จนตรวจจับแทบไม่ได้ ยังไม่ได้กรองออก
> เพราะ KNN ใช้ค่านี้เป็นสัญญาณ "ไกลมาก" ได้อย่างสมเหตุสมผล แต่ควรระวังถ้าจะใช้โมเดลอื่นที่อ่อนไหวกับ
> outlier มากกว่านี้

**เลือกใช้ hybrid model** เป็นค่าเริ่มต้น เพราะ:
- แม่นยำใกล้เคียงหรือดีกว่า KNN ล้วน ๆ เล็กน้อย
- ตรงกับโจทย์ที่อาจารย์ต้องการ (ดูว่าเกาะ AP ตัวไหน)
- ขยายไปหลายชั้น/หลายโซนในอนาคตได้ง่ายกว่า เพราะแยกโมเดลย่อยตามโซนอยู่แล้ว

**ข้อจำกัดสำคัญ**: มีแค่ 8 จุดอ้างอิง โมเดลจึงบอกได้แม่นยำแค่ "ใกล้จุดอ้างอิงไหนที่สุด" การประมาณ
ตำแหน่งระหว่างจุดอ้างอิง (interpolation) ยังมีความคลาดเคลื่อนพอสมควร แนะนำให้เก็บจุดอ้างอิงเพิ่มถ้า
ต้องการความแม่นยำสูงขึ้น

### 4. A* Navigation (navigation/astar.py)

- ใช้ 8-connected movement (เดินทแยงได้) พร้อมกันการเดินทแยงตัดมุมกำแพง (corner-cutting prevention)
- ถ้าตำแหน่งที่โมเดลทำนายดันตกอยู่ในกำแพง (สัญญาณ noise) จะ snap ไปยังช่องเดินได้ที่ใกล้ที่สุดอัตโนมัติ
- ผลลัพธ์เส้นทางถูก simplify เหลือแค่จุดเลี้ยว (waypoints) แทนที่จะเป็นทุกช่อง grid

## ข้อจำกัดของวิธี WiFi fingerprinting ที่ควรรู้

- **ขยายไปชั้นอื่น/ปีกอาคารอื่นต้องเก็บข้อมูลใหม่เสมอ** เพราะสัญญาณ WiFi ทะลุพื้น/ผนังคอนกรีตได้ไม่ดี
  fingerprint ของชั้นหนึ่งใช้กับอีกชั้นไม่ได้ ต้องมี AP ประจำแต่ละชั้น + เก็บจุดอ้างอิงใหม่ + สร้าง
  occupancy grid ใหม่จากแปลนชั้นนั้น
- แนวทางลดภาระงานเก็บข้อมูลสำหรับงานต่อยอด (future work): crowdsourced fingerprint collection,
  path-loss propagation model (ประมาณค่าจากสูตรฟิสิกส์แทนการวัดจริงทุกจุด), หรือเก็บแบบเดินต่อเนื่อง
  (path-based) แทนยืนนิ่งทีละจุด

## ขั้นตอนถัดไป (ตาม scope ที่อาจารย์วางไว้)

1. เก็บจุดอ้างอิง WiFi เพิ่ม เพื่อลดค่าคลาดเคลื่อนตำแหน่ง
2. ตรวจสอบ/แก้ไขพิกัดกำแพงใน `occupancy_overlay.png` ให้ตรงกับพื้นที่จริง (โดยเฉพาะโซน hatched)
3. เพิ่ม real-time tracking loop ในแอป (สแกน WiFi ทุก 2-3 วินาที → ทำนายตำแหน่งใหม่ → คำนวณเส้นทางใหม่)
4. เชื่อมต่อกับ frontend/backend template ที่อาจารย์ให้มา
# Zone navigation simulator (single associated AP + RSSI)

The controller-independent MVP reads simulated observations from
`simulator/observations.json`, confirms roaming after three consecutive
readings, estimates an AP zone, and recalculates an A* route on each
confirmed roaming event.

Run from the `model` directory:

```powershell
.\.venv\Scripts\python.exe zone_navigation_demo.py --destination room_2
```

Each route calculation also creates a floor-plan image in
`navigation_outputs/`. The green marker is the estimated start, the blue line
is the A* route, and the red marker is the selected room entrance.

Available destinations are `room_1`, `room_2`, and `room_3`. To try other
controller readings, edit `simulator/observations.json`. Each observation
must contain `client_id`, `associated_ap`, `rssi`, and `timestamp`.

Run the tests:

```powershell
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

Zone anchors, RSSI bands, roaming confirmation, transitions, and destination
coordinates are configured in `positioning/zone_config.json`. These are MVP
calibration values and must be validated on site before production use.
