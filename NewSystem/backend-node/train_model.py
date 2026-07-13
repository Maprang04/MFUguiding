# =============================================================
# train_model.py
# เทรนโมเดล Random Forest จากข้อมูล WiFi fingerprint ใน MySQL
# รันครั้งเดียว → ได้ไฟล์ model.pkl สำหรับใช้งานจริง
# =============================================================

import mysql.connector
import pandas as pd
import numpy as np
import pickle
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error
from sklearn.multioutput import MultiOutputRegressor

# -------------------------------------------------------------
# 1. ตั้งค่าการเชื่อมต่อ MySQL (ตรงกับ server.js เดิม)
# -------------------------------------------------------------
DB_CONFIG = {
    "host": "127.0.0.1",
    "user": "root",
    "password": "",
    "database": "indoor_navigation"
}

print("=" * 50)
print("Indoor Navigation — Model Training")
print("=" * 50)

# -------------------------------------------------------------
# 2. ดึงข้อมูลจาก MySQL
# -------------------------------------------------------------
print("\n[1] กำลังเชื่อมต่อ MySQL...")

try:
    conn = mysql.connector.connect(**DB_CONFIG)
    cursor = conn.cursor()
    cursor.execute("SELECT ap1, ap2, ap3, x, y FROM wifi_dataset")
    rows = cursor.fetchall()
    cursor.close()
    conn.close()
    print(f"    ✓ ดึงข้อมูลสำเร็จ — {len(rows)} แถว")
except Exception as e:
    print(f"    ✗ เชื่อมต่อ MySQL ไม่ได้: {e}")
    print("      ตรวจสอบว่า XAMPP/MySQL กำลังรันอยู่")
    exit(1)

# -------------------------------------------------------------
# 3. เตรียมข้อมูล
# -------------------------------------------------------------
print("\n[2] กำลังเตรียมข้อมูล...")

df = pd.DataFrame(rows, columns=["ap1", "ap2", "ap3", "x", "y"])

print(f"    ข้อมูลทั้งหมด: {len(df)} แถว")
print(f"    ตำแหน่งที่มีข้อมูล:")

# แสดงจำนวน sample ต่อตำแหน่ง
for pos, group in df.groupby(["x", "y"]):
    print(f"      ({pos[0]}, {pos[1]}) — {len(group)} samples")

# Features: ap1, ap2, ap3 (ค่า RSSI ในหน่วย dBm)
# Targets: x, y (ตำแหน่ง)
X = df[["ap1", "ap2", "ap3"]].values
y = df[["x", "y"]].values

# แบ่งข้อมูล train/test (80/20)
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

print(f"\n    Train set: {len(X_train)} แถว")
print(f"    Test set:  {len(X_test)} แถว")

# -------------------------------------------------------------
# 4. เทรนโมเดล Random Forest
# -------------------------------------------------------------
print("\n[3] กำลังเทรนโมเดล Random Forest...")

model = MultiOutputRegressor(
    RandomForestRegressor(
        n_estimators=200,       # จำนวน tree
        max_depth=10,           # ความลึกสูงสุด
        min_samples_split=2,
        random_state=42,
        n_jobs=-1               # ใช้ CPU ทุก core
    )
)

model.fit(X_train, y_train)
print("    ✓ เทรนเสร็จแล้ว")

# -------------------------------------------------------------
# 5. ทดสอบความแม่นยำ
# -------------------------------------------------------------
print("\n[4] กำลังทดสอบความแม่นยำ...")

y_pred = model.predict(X_test)

# คำนวณ MAE แยก x และ y
mae_x = mean_absolute_error(y_test[:, 0], y_pred[:, 0])
mae_y = mean_absolute_error(y_test[:, 1], y_pred[:, 1])

# คำนวณ Euclidean distance error (ระยะห่างจริงในเมตร)
distances = np.sqrt(
    (y_test[:, 0] - y_pred[:, 0]) ** 2 +
    (y_test[:, 1] - y_pred[:, 1]) ** 2
)
mean_dist = np.mean(distances)
median_dist = np.median(distances)

print(f"    MAE (X): {mae_x:.3f} เมตร")
print(f"    MAE (Y): {mae_y:.3f} เมตร")
print(f"    ระยะห่างเฉลี่ย: {mean_dist:.3f} เมตร")
print(f"    ระยะห่าง median: {median_dist:.3f} เมตร")

# แสดงผลทดสอบแบบละเอียด
print(f"\n    ตัวอย่างผลทำนาย:")
print(f"    {'จริง (x,y)':<20} {'ทำนาย (x,y)':<20} {'ห่าง (เมตร)'}")
print(f"    {'-'*60}")
for i in range(min(5, len(y_test))):
    actual = f"({y_test[i,0]:.1f}, {y_test[i,1]:.1f})"
    predicted = f"({y_pred[i,0]:.2f}, {y_pred[i,1]:.2f})"
    dist = distances[i]
    print(f"    {actual:<20} {predicted:<20} {dist:.3f} m")

# -------------------------------------------------------------
# 6. บันทึกโมเดล
# -------------------------------------------------------------
print("\n[5] กำลังบันทึกโมเดล...")

MODEL_PATH = "model.pkl"

with open(MODEL_PATH, "wb") as f:
    pickle.dump(model, f)

print(f"    ✓ บันทึกสำเร็จ → {MODEL_PATH}")

# -------------------------------------------------------------
# 7. ทดสอบโหลดโมเดลกลับมา
# -------------------------------------------------------------
print("\n[6] ทดสอบโหลดโมเดล...")

with open(MODEL_PATH, "rb") as f:
    loaded_model = pickle.load(f)

# ทดสอบด้วยค่า RSSI ตัวอย่าง
test_rssi = [[-67, -68, -61]]
result = loaded_model.predict(test_rssi)
print(f"    ✓ โหลดสำเร็จ")
print(f"    ทดสอบ: RSSI = {test_rssi[0]}")
print(f"    ผลทำนาย: x={result[0][0]:.2f}, y={result[0][1]:.2f}")

print("\n" + "=" * 50)
print("✓ เทรนโมเดลเสร็จสมบูรณ์!")
print(f"  ไฟล์: {MODEL_PATH}")
print(f"  ความแม่นยำ: ±{mean_dist:.2f} เมตร (เฉลี่ย)")
print("=" * 50)