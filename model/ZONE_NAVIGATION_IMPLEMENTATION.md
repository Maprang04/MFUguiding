# แผนพัฒนาระบบ Zone-based Indoor Navigation ด้วย Cisco Controller

## 1. เป้าหมาย

ระบบรับข้อมูลของอุปกรณ์ผู้ใช้จาก Cisco Wireless Controller ได้แก่ AP ที่อุปกรณ์เชื่อมต่ออยู่และ RSSI ของ AP นั้น แล้วประมาณว่าอุปกรณ์อยู่ในบริเวณใดของชั้น ก่อนเลือกจุดเริ่มต้นที่เดินได้และใช้ A* สร้างเส้นทางไปยังประตูห้องหรือจุดหมายที่กำหนดไว้บน floor plan

ข้อจำกัดสำคัญ: ข้อมูล AP หนึ่งตัวกับ RSSI หนึ่งค่าไม่เพียงพอสำหรับระบุพิกัด `(x, y)` ที่แม่นยำ ระบบจึงต้องแสดงผลเป็น zone/บริเวณพร้อมระดับความมั่นใจ และใช้จุดตัวแทนบนทางเดินสำหรับเริ่มคำนวณเส้นทาง

## 2. สถาปัตยกรรม

```text
Cisco Controller
  -> associated AP + RSSI + client identifier + timestamp
  -> validation และ RSSI median filter
  -> roaming state tracker
  -> zone prediction model
  -> representative/transition anchor
  -> snap ลง occupancy grid
  -> A* pathfinding
  -> route ไปยัง destination entrance
```

### หน้าที่ของแต่ละส่วน

| ส่วน | หน้าที่ |
|---|---|
| Cisco Controller | บอกว่า client เชื่อม AP ใดและ RSSI เท่าไร |
| RSSI filter | ตัดค่าผิดปกติและคำนวณ median จากหลาย readings |
| Roaming tracker | ยืนยันการเปลี่ยน AP และป้องกัน AP สลับไปมา |
| Zone model | ทำนายบริเวณจาก AP, RSSI และสถานะก่อนหน้า |
| Zone/transition anchor | แปลงบริเวณเป็นจุดตัวแทนที่อยู่บนทางเดิน |
| Occupancy grid | ตรวจว่าจุดและเส้นทางอยู่ในพื้นที่เดินได้ |
| A* | หาเส้นทางจาก anchor ไปยังพิกัดประตูปลายทาง |

## 3. จำเป็นต้องเชื่อม Cisco Controller หรือไม่

จำเป็นสำหรับการทดสอบกับผู้ใช้และข้อมูลจริง แต่ไม่จำเป็นต้องรอ controller เพื่อเริ่มพัฒนาส่วนอื่น สามารถใช้ไฟล์ JSON หรือ simulator ส่งข้อมูลรูปแบบเดียวกันก่อนได้

ตัวอย่างข้อมูลมาตรฐานภายในระบบ:

```json
{
  "client_id": "device-001",
  "associated_ap": "AP2",
  "rssi": -64,
  "timestamp": "2026-07-22T10:30:00+07:00"
}
```

ก่อนเชื่อมต่อจริงต้องขอข้อมูลต่อไปนี้จากอาจารย์หรือผู้ดูแลเครือข่าย:

- รุ่นและเวอร์ชันของ Cisco Controller
- URL/IP สำหรับ management หรือ API
- วิธีเชื่อมต่อที่รองรับ เช่น Catalyst Center API, Cisco DNA Center API, Catalyst 9800 RESTCONF หรือ API ของ controller รุ่นนั้น
- บัญชีแบบ read-only หรือ API credential
- AP identifier ที่ controller ส่ง เช่น AP name, MAC หรือ radio MAC
- วิธีระบุ client เช่น client MAC หรือ session identifier
- ตัวอย่าง response จริงที่มี associated AP, RSSI และ timestamp
- รอบเวลาที่อนุญาตให้ดึงข้อมูล และข้อจำกัด rate limit
- การเข้าถึงเครือข่าย เช่น VPN, certificate และ firewall

ห้ามสมมติ endpoint หรือรูปแบบ authentication ก่อนทราบรุ่น controller เพราะ Cisco แต่ละรุ่นและแต่ละระบบบริหารใช้ API ต่างกัน

## 4. ส่วนที่ใช้โมเดล

โมเดลอยู่หลังการกรองข้อมูล controller และก่อนเลือก anchor:

```text
associated AP + median RSSI + previous zone + roaming state
                         |
                         v
                  Zone prediction model
                         |
                         v
             predicted zone + confidence
```

ตัวอย่าง input:

```json
{
  "associated_ap": "AP2",
  "median_rssi": -64,
  "previous_zone": "AP3_ZONE",
  "roamed_from": "AP3"
}
```

ตัวอย่าง output:

```json
{
  "zone": "CENTRAL_HALLWAY",
  "confidence": 0.78
}
```

### โมเดลเดิมใช้ได้อย่างไร

`hybrid_model.joblib` ปัจจุบันต้องใช้ RSSI จาก AP1, AP2 และ AP3 พร้อมกัน จึงใช้ตรง ๆ ไม่ได้เมื่อ controller ส่ง RSSI เฉพาะ AP ที่ client เกาะอยู่

ส่วนที่ใช้ต่อได้:

- occupancy grid
- A* pathfinding
- พิกัด AP และ floor plan
- fingerprint dataset สำหรับช่วยวิเคราะห์และกำหนดขอบเขต AP zone
- แนวคิด roaming zone

ส่วนที่ต้องสร้างหรือปรับใหม่:

- Cisco controller adapter
- RSSI median filter
- roaming state tracker
- zone configuration และ transition anchors
- zone classifier ที่รับข้อมูล AP ตัวเดียว
- destination entrance configuration
- zone navigation orchestrator

ใน MVP สามารถเริ่มด้วย rule-based classifier ก่อน เช่น `AP2 + medium RSSI -> CENTRAL_HALLWAY` แล้วเปลี่ยนเป็นโมเดล เช่น Random Forest หรือ probabilistic classifier เมื่อมีข้อมูลจาก controller ที่ติดป้าย zone แล้ว

## 5. ขั้นตอนดำเนินงาน

### ขั้นที่ 1: ยืนยันข้อมูลจาก controller

- [ ] ระบุรุ่นและ software version
- [ ] ยืนยัน API/โปรโตคอลที่ใช้ได้
- [ ] ขอ read-only credential
- [ ] ทดลองดึงรายการ AP
- [ ] ทดลองค้นหา client ที่กำลังเชื่อมต่อ
- [ ] ยืนยันว่า response มี associated AP และ RSSI
- [ ] บันทึกตัวอย่าง response โดยปกปิด credential และข้อมูลส่วนบุคคล

ผลลัพธ์ที่ต้องได้คือข้อมูลที่แปลงเป็น schema มาตรฐานได้:

```text
client_id, associated_ap, rssi, timestamp
```

### ขั้นที่ 2: สร้าง controller adapter

สร้าง module ที่รับผิดชอบเฉพาะการสื่อสารกับ controller และคืนข้อมูล schema กลาง ห้ามให้ส่วน navigation ผูกกับ response ของ Cisco โดยตรง

```python
def get_client_observation(client_id):
    return {
        "client_id": client_id,
        "associated_ap": "AP2",
        "rssi": -64,
        "timestamp": "...",
    }
```

ต้องมี simulator ที่อ่าน observations จาก JSON เพื่อให้พัฒนาและทดสอบได้เมื่อ controller ใช้งานไม่ได้

### ขั้นที่ 3: ทำ data validation และ RSSI filter

- ปฏิเสธค่า null, 0 หรือค่าที่อยู่นอกช่วงที่กำหนด
- ถือค่า `<= -95 dBm` เป็น missing/invalid ตามอุปกรณ์ที่ใช้
- เก็บ readings ล่าสุด 5 ค่าแยกตาม client
- ใช้ median เป็นค่าหลัก
- ถ้าข้อมูลเก่าเกินเวลาที่กำหนด ให้สถานะเป็น stale

ช่วง RSSI เริ่มต้น:

```text
near:   RSSI >= -55
medium: -70 <= RSSI < -55
edge:   RSSI < -70
```

ช่วงนี้เป็นค่าเริ่มต้น ไม่ใช่ระยะเมตร และต้องปรับจากผลทดสอบจริง

### ขั้นที่ 4: กำหนด AP zones

- [ ] ตรวจตำแหน่ง AP บน floor plan
- [ ] กำหนดชื่อ zone ที่ผู้ใช้เข้าใจ เช่น `ROOM_1_AREA`, `CENTRAL_HALLWAY`
- [ ] กำหนด anchor สำหรับ near/medium/edge ของแต่ละ AP
- [ ] ตรวจทุก anchor ว่าอยู่ใน walkable cell
- [ ] ใช้ fingerprint เดิมประกอบการแบ่งขอบเขต แต่ไม่ใช้เติม RSSI ที่ controller ไม่มี

ตัวอย่าง configuration:

```json
{
  "AP2": {
    "near": [11.0, 7.0],
    "medium": [12.0, 4.0],
    "edge": [9.0, 3.5]
  }
}
```

### ขั้นที่ 5: กำหนด roaming transitions

- [ ] ระบุคู่ AP ที่สามารถ roam ถึงกันได้จริง
- [ ] กำหนด anchor บริเวณรอยต่อบนทางเดิน
- [ ] ถ้ามีหลายทางเชื่อม ให้เก็บหลาย candidate anchors
- [ ] เลือก candidate ที่ใกล้ตำแหน่งก่อนหน้าและหาเส้นทางได้

ตัวอย่าง:

```json
{
  "AP3->AP2": [[9.0, 3.5]],
  "AP2->AP1": [[14.0, 4.0], [14.0, 7.0]]
}
```

### ขั้นที่ 6: สร้าง roaming state tracker

ยืนยัน AP ใหม่ต่อเนื่องอย่างน้อย 3 readings หรือ 3–5 วินาทีก่อนเปลี่ยน zone

สถานะต่อ client:

```text
current_ap
candidate_ap
candidate_count
last_confirmed_position
last_update_time
```

เมื่อยืนยัน roaming แล้ว:

1. บันทึก `previous_ap -> current_ap`
2. เลือก transition anchor
3. อัปเดต estimated position
4. คำนวณเส้นทางใหม่

### ขั้นที่ 7: สร้าง zone classifier

MVP ใช้กฎที่ตรวจสอบได้:

```text
associated AP + RSSI band + previous AP -> zone
```

ระยะต่อไปจึง train classifier ด้วยข้อมูล:

```csv
associated_ap,rssi,previous_ap,zone
AP2,-64,AP3,CENTRAL_HALLWAY
```

การประเมินต้องแบ่ง train/test ตาม session หรือช่วงเวลา ห้ามสุ่ม readings จากตำแหน่งเดียวกันกระจายทั้ง train และ test เพราะจะทำให้คะแนนสูงเกินจริง

### ขั้นที่ 8: กำหนด destinations

ปลายทางต้องเป็นพิกัดประตูหรือจุดหน้าห้องที่เดินได้:

```json
{
  "room_1": {"name": "Room 1", "entrance": [14.0, 5.5]},
  "room_2": {"name": "Room 2", "entrance": [13.0, 8.0]},
  "room_3": {"name": "Room 3", "entrance": [9.0, 4.0]}
}
```

### ขั้นที่ 9: เชื่อมกับ occupancy grid และ A*

1. รับ predicted zone
2. เลือก zone anchor หรือ transition anchor
3. snap anchor ไปยัง walkable cell ที่ใกล้ที่สุด
4. อ่าน destination entrance
5. เรียก A*
6. simplify waypoints
7. ส่ง zone, confidence และ route เป็นผลลัพธ์

### ขั้นที่ 10: อัปเดตระหว่างนำทาง

คำนวณเส้นทางใหม่เมื่อ:

- ยืนยัน roaming สำเร็จ
- RSSI band เปลี่ยนอย่างต่อเนื่อง
- ผู้ใช้เปลี่ยนปลายทาง
- anchor ใหม่ห่างจาก anchor เดิมเกินค่าที่กำหนด

ไม่ควรคำนวณใหม่เมื่อ RSSI เปลี่ยนเพียง 1–2 dBm ครั้งเดียว

## 6. Confidence

ระบบต้องแสดงความมั่นใจเพื่อไม่สื่อว่าพิกัดประมาณเป็นพิกัดจริง

| Confidence | เงื่อนไขตัวอย่าง |
|---|---|
| High | เพิ่งยืนยัน roaming และมี transition anchor เดียวที่ชัดเจน |
| Medium | AP คงที่หลาย readings และมีตำแหน่งก่อนหน้า |
| Low | เริ่ม session ใหม่และมีเพียง AP + RSSI ตัวเดียว |

ผลลัพธ์ตัวอย่าง:

```json
{
  "current_region": "CENTRAL_HALLWAY",
  "estimated_start": [12.0, 4.0],
  "confidence": "low",
  "destination": "room_2",
  "route": [[12.0, 4.0], [12.5, 6.0], [13.0, 8.0]]
}
```

## 7. Acceptance criteria

- [ ] Adapter อ่าน associated AP และ RSSI ของ client จาก controller หรือ simulator ได้
- [ ] Credential ไม่ถูกเขียนลง source code หรือ commit ลง Git
- [ ] Invalid RSSI ถูกปฏิเสธและ median filter ทำงานถูกต้อง
- [ ] AP ใหม่หนึ่ง reading ไม่ทำให้ zone เปลี่ยนทันที
- [ ] AP ใหม่ต่อเนื่องตาม threshold ทำให้ roaming ได้รับการยืนยัน
- [ ] ทุก AP zone มี anchor ที่อยู่บน walkable cell
- [ ] ทุก roaming transition ที่รองรับมี anchor ที่เดินได้
- [ ] ทุก destination อยู่บนหรือชิดพื้นที่เดินได้
- [ ] A* หาเส้นทางจากทุก zone anchor ไปทุก destination ได้
- [ ] ระบบคำนวณเส้นทางใหม่หลังยืนยัน roaming
- [ ] เมื่อ controller ใช้งานไม่ได้ ระบบแจ้งข้อมูล stale/unavailable โดยไม่ใช้ตำแหน่งเก่าแบบไม่จำกัดเวลา
- [ ] UI/API แสดง `zone`, `estimated position` และ `confidence` แยกกันชัดเจน
- [ ] ไม่อ้างว่า RSSI หนึ่งค่าคือระยะเมตรหรือพิกัดแม่นยำ

## 8. แผนทดสอบ

### Unit tests

- RSSI validation
- median filter
- near/medium/edge classification
- roaming confirmation และการป้องกัน ping-pong
- anchor snapping
- destination lookup

### Simulation tests

```text
AP3 -> AP3 -> AP3
AP3 -> AP2 -> AP3
AP3 -> AP2 -> AP2 -> AP2
AP2 -> AP1 -> AP2 -> AP1
```

ตรวจว่าเฉพาะลำดับที่ยืนยันครบเท่านั้นที่ทำให้เปลี่ยน zone และคำนวณ route ใหม่

### Controller integration tests

- client ที่ online
- client ที่ offline
- client roam ระหว่าง AP
- RSSI หายหรือเป็นค่าผิดปกติ
- controller timeout
- credential หมดอายุ
- AP identifier ไม่ตรงกับ configuration

### Navigation tests

ทดสอบเส้นทางจากทุก anchor ไปทุก destination และตรวจว่าไม่มี waypoint อยู่ใน blocked cell

## 9. ลำดับการพัฒนาที่แนะนำ

1. ขอข้อมูลรุ่น controller, API และ sample response
2. สร้าง simulator และ schema กลาง
3. สร้าง RSSI filter และ roaming tracker
4. กำหนด AP zones, anchors และ destinations
5. เชื่อม zone estimator กับ occupancy grid และ A*
6. ทำ end-to-end demo ด้วย simulator
7. สร้าง Cisco adapter เมื่อได้ API จริง
8. ทดสอบด้วย controller แบบ read-only
9. ปรับ RSSI thresholds และ transition anchors
10. สร้าง dataset สำหรับ zone classifier หากต้องการแทน rule-based MVP

## 10. สิ่งที่ต้องขอจากอาจารย์ก่อนเริ่ม integration

- รุ่นและเวอร์ชัน Cisco Controller
- วิธีเชื่อมต่อ controller จากเครื่องพัฒนา
- read-only account หรือ API credential
- เอกสารหรือ sample API response
- รายชื่อ AP และ identifier ที่ใช้จริง
- ตำแหน่ง AP บน floor plan ที่ยืนยันแล้ว
- client identifier ที่อนุญาตให้ใช้ทดสอบ
- ขอบเขตด้านข้อมูลส่วนบุคคลและระยะเวลาการเก็บ log

