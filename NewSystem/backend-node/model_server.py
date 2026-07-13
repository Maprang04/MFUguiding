# =============================================================
# model_server.py
# Flask server สำหรับทำนายตำแหน่งจากค่า RSSI
# รันพร้อมกับ server.js → Node.js จะเรียก API นี้
# Port: 5000
# =============================================================

import pickle
import numpy as np
from flask import Flask, request, jsonify
import os

app = Flask(__name__)

# -------------------------------------------------------------
# โหลดโมเดลตอน server เริ่มทำงาน (โหลดครั้งเดียว)
# -------------------------------------------------------------
MODEL_PATH = "model.pkl"

if not os.path.exists(MODEL_PATH):
    print(f"✗ ไม่พบไฟล์ {MODEL_PATH}")
    print("  กรุณารัน train_model.py ก่อน")
    exit(1)

with open(MODEL_PATH, "rb") as f:
    model = pickle.load(f)

print("=" * 40)
print("Indoor Navigation — ML Server")
print("=" * 40)
print(f"✓ โหลดโมเดลสำเร็จ: {MODEL_PATH}")
print(f"✓ Server รันที่ http://localhost:5000")
print("=" * 40)


# -------------------------------------------------------------
# Endpoint: POST /predict
# รับ: { "ap1": -67, "ap2": -68, "ap3": -61 }
# ส่งกลับ: { "x": 9.0, "y": 2.0, "confidence": 0.87 }
# -------------------------------------------------------------
@app.route("/predict", methods=["POST"])
def predict():
    try:
        data = request.get_json()

        # ตรวจสอบ input
        if not data:
            return jsonify({"error": "ไม่ได้ส่งข้อมูลมา"}), 400

        ap1 = data.get("ap1")
        ap2 = data.get("ap2")
        ap3 = data.get("ap3")

        if ap1 is None or ap2 is None or ap3 is None:
            return jsonify({
                "error": "ต้องส่ง ap1, ap2, ap3"
            }), 400

        # ทำนายตำแหน่ง
        features = np.array([[ap1, ap2, ap3]])
        prediction = model.predict(features)

        x = round(float(prediction[0][0]), 2)
        y = round(float(prediction[0][1]), 2)

        # คำนวณ confidence จาก tree predictions
        # (ดูว่า tree แต่ละต้นเห็นด้วยกันแค่ไหน)
        tree_predictions = np.array([
            estimator.predict(features)[0]
            for estimator in model.estimators_
        ])

        std_x = float(np.std(tree_predictions[:, 0]))
        std_y = float(np.std(tree_predictions[:, 1]))

        # confidence: ยิ่ง std น้อย = ยิ่งมั่นใจ
        # แปลงเป็น 0-1 (std 0 = confidence 1.0, std 3+ = confidence ~0)
        avg_std = (std_x + std_y) / 2
        confidence = round(max(0.0, 1.0 - (avg_std / 3.0)), 2)

        result = {
            "x": x,
            "y": y,
            "confidence": confidence,
            "std_x": round(std_x, 3),
            "std_y": round(std_y, 3)
        }

        print(f"Predict: RSSI=({ap1},{ap2},{ap3}) → ({x},{y}) conf={confidence}")
        return jsonify(result)

    except Exception as e:
        print(f"Error: {e}")
        return jsonify({"error": str(e)}), 500


# -------------------------------------------------------------
# Endpoint: GET /health
# ตรวจสอบว่า server ทำงานอยู่
# -------------------------------------------------------------
@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "ok",
        "model": MODEL_PATH,
        "message": "ML Server กำลังทำงาน"
    })


# -------------------------------------------------------------
# Endpoint: POST /predict-batch
# รับหลาย RSSI พร้อมกัน (สำหรับ smooth tracking)
# รับ: { "samples": [{"ap1":-67,"ap2":-68,"ap3":-61}, ...] }
# ส่งกลับ: { "x": 9.1, "y": 2.0 } (ค่าเฉลี่ย)
# -------------------------------------------------------------
@app.route("/predict-batch", methods=["POST"])
def predict_batch():
    try:
        data = request.get_json()
        samples = data.get("samples", [])

        if not samples:
            return jsonify({"error": "ต้องส่ง samples"}), 400

        features = np.array([
            [s["ap1"], s["ap2"], s["ap3"]]
            for s in samples
        ])

        predictions = model.predict(features)

        # เฉลี่ยจากหลาย sample
        avg_x = round(float(np.mean(predictions[:, 0])), 2)
        avg_y = round(float(np.mean(predictions[:, 1])), 2)

        return jsonify({
            "x": avg_x,
            "y": avg_y,
            "samples_used": len(samples)
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500


# -------------------------------------------------------------
# รัน server
# -------------------------------------------------------------
if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5000,
        debug=False      # ปิด debug mode ในการใช้งานจริง
    )