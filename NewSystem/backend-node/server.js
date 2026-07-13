const express = require("express");
const mysql = require("mysql2");
const cors = require("cors");
const http = require("http");

const app = express();

app.use(cors());
app.use(express.json());

// -------------------------------------------------------
// MySQL connection pool
// -------------------------------------------------------
const db = mysql.createPool({
    host: "localhost",
    user: "root",
    password: "",
    database: "indoor_navigation",
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

// -------------------------------------------------------
// Map พิกัด → ชื่อพื้นที่ (ตามที่ Maprang กำหนด)
// -------------------------------------------------------
const LOCATION_MAP = [
    { x: 1,  y: 2,    radius: 1.5, th: "ทางเข้าอาคาร",              en: "Building Entrance" },
    { x: 5,  y: 2,    radius: 1.5, th: "ทางเดินกลางอาคาร",           en: "Main Corridor" },
    { x: 9,  y: 2,    radius: 1.5, th: "ทางเดินกลางอาคาร",           en: "Main Corridor" },
    { x: 13, y: 2,    radius: 1.5, th: "ทางเดินกลางอาคาร",           en: "Main Corridor" },
    { x: 13, y: 4,    radius: 1.5, th: "หน้า Room 1 และ Room 3",     en: "In front of Room 1 & Room 3" },
    { x: 13, y: 8,    radius: 1.5, th: "หน้า Room 2",                en: "In front of Room 2" },
    { x: 16, y: 3.75, radius: 1.5, th: "ทางเข้า Hallway เล็ก",      en: "Small Hallway Entrance" },
    { x: 19, y: 3.75, radius: 1.5, th: "ทางเดินกลาง Hallway เล็ก",  en: "Small Hallway Center" },
];

// หาชื่อพื้นที่ที่ใกล้ที่สุดจากพิกัด x,y
function getLocationName(x, y) {
    let nearest = null;
    let minDist = Infinity;

    for (const loc of LOCATION_MAP) {
        const dist = Math.sqrt(
            Math.pow(x - loc.x, 2) + Math.pow(y - loc.y, 2)
        );
        if (dist < minDist) {
            minDist = dist;
            nearest = loc;
        }
    }

    return nearest
        ? { th: nearest.th, en: nearest.en, distance: minDist }
        : { th: "บริเวณที่ไม่ทราบ", en: "Unknown Area", distance: minDist };
}

// -------------------------------------------------------
// Helper: เรียก Python ML Server (port 5000)
// -------------------------------------------------------
function callMLServer(path, body) {
    return new Promise((resolve, reject) => {
        const bodyStr = JSON.stringify(body);
        const options = {
            hostname: "127.0.0.1",
            port: 5000,
            path: path,
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Content-Length": Buffer.byteLength(bodyStr)
            }
        };

        const req = http.request(options, (res) => {
            let data = "";
            res.on("data", (chunk) => { data += chunk; });
            res.on("end", () => {
                try { resolve(JSON.parse(data)); }
                catch (e) { reject(new Error("ML Server ตอบกลับไม่ถูกต้อง")); }
            });
        });

        req.on("error", (e) => reject(new Error(
            `เรียก ML Server ไม่ได้: ${e.message} — ตรวจสอบว่า python model_server.py กำลังรันอยู่`
        )));
        req.setTimeout(5000, () => { req.destroy(); reject(new Error("ML Server timeout")); });
        req.write(bodyStr);
        req.end();
    });
}

// -------------------------------------------------------
// Helper: เรียก Ollama (port 11434)
// -------------------------------------------------------
function callOllama(prompt) {
    return new Promise((resolve, reject) => {
        const body = JSON.stringify({
            model: "qwen3:4b",
            prompt: prompt,
            stream: false,
            options: { temperature: 0.3 }
        });

        const options = {
            hostname: "127.0.0.1",
            port: 11434,
            path: "/api/generate",
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Content-Length": Buffer.byteLength(body)
            }
        };

        const req = http.request(options, (res) => {
            let data = "";
            res.on("data", (chunk) => { data += chunk; });
            res.on("end", () => {
                try {
                    const json = JSON.parse(data);
                    resolve(json.response || "");
                } catch (e) {
                    reject(new Error("Ollama ตอบกลับไม่ถูกต้อง"));
                }
            });
        });

        req.on("error", (e) => reject(new Error(
            `เรียก Ollama ไม่ได้: ${e.message} — ตรวจสอบว่า Ollama กำลังรันอยู่`
        )));
        req.setTimeout(30000, () => { req.destroy(); reject(new Error("Ollama timeout")); });
        req.write(body);
        req.end();
    });
}

// -------------------------------------------------------
// POST /locate
// รับ: { ap1, ap2, ap3 }
// ส่งกลับ: { x, y, confidence, location_th, location_en }
// -------------------------------------------------------
app.post("/locate", async (req, res) => {
    const { ap1, ap2, ap3 } = req.body;

    if (ap1 === undefined || ap2 === undefined || ap3 === undefined) {
        return res.status(400).json({ error: "ต้องส่ง ap1, ap2, ap3" });
    }

    try {
        const ml = await callMLServer("/predict", { ap1, ap2, ap3 });
        const location = getLocationName(ml.x, ml.y);

        console.log(`/locate (${ap1},${ap2},${ap3}) → (${ml.x},${ml.y}) = ${location.th}`);

        res.json({
            x: ml.x,
            y: ml.y,
            confidence: ml.confidence,
            location_th: location.th,
            location_en: location.en
        });

    } catch (err) {
        console.error("/locate error:", err.message);
        res.status(500).json({ error: err.message });
    }
});

// -------------------------------------------------------
// POST /explain
// รับ: { x, y } — พิกัดที่ทำนายได้แล้ว
// ส่งกลับ: { explanation_th, explanation_en, location_th }
// LLM อธิบายตำแหน่งเป็นภาษาไทย (หลัก) และอังกฤษ (รอง)
// -------------------------------------------------------
app.post("/explain", async (req, res) => {
    const { x, y } = req.body;

    if (x === undefined || y === undefined) {
        return res.status(400).json({ error: "ต้องส่ง x, y" });
    }

    const location = getLocationName(x, y);

    const prompt = `/no_think
คุณเป็นผู้ช่วยนำทางในอาคาร ห้ามคำนวณตัวเลขเอง ใช้เฉพาะข้อมูลที่ให้มาเท่านั้น

ข้อมูล:
- ตำแหน่งปัจจุบัน: ${location.th} (${location.en})
- พิกัด: x=${x}, y=${y}

งาน: เขียนประโยคสั้นๆ บอกตำแหน่งปัจจุบัน 2 ประโยค:
1. ภาษาไทย (1 ประโยค ไม่เกิน 15 คำ)
2. English (1 sentence, max 10 words)

ตอบในรูปแบบนี้เท่านั้น ห้ามเพิ่มข้อความอื่น:
TH: [ประโยคภาษาไทย]
EN: [English sentence]`;

    try {
        console.log(`/explain (${x},${y}) = ${location.th} → กำลังถาม Ollama...`);
        const response = await callOllama(prompt);

        // Parse คำตอบจาก LLM
        const thMatch = response.match(/TH:\s*(.+)/);
        const enMatch = response.match(/EN:\s*(.+)/);

        const explanation_th = thMatch
            ? thMatch[1].trim()
            : `คุณอยู่ที่ ${location.th}`;
        const explanation_en = enMatch
            ? enMatch[1].trim()
            : `You are at ${location.en}`;

        console.log(`/explain → TH: ${explanation_th}`);

        res.json({
            explanation_th,
            explanation_en,
            location_th: location.th,
            location_en: location.en,
            x, y
        });

    } catch (err) {
        console.error("/explain error:", err.message);

        // Fallback: ถ้า Ollama ไม่พร้อม ส่งชื่อพื้นที่แทน
        res.json({
            explanation_th: `คุณอยู่ที่${location.th}`,
            explanation_en: `You are at ${location.en}`,
            location_th: location.th,
            location_en: location.en,
            x, y,
            fallback: true,
            error: err.message
        });
    }
});

// -------------------------------------------------------
// POST /save-point
// รับ: { ap1, ap2, ap3, x, y }
// -------------------------------------------------------
app.post("/save-point", (req, res) => {
    const { ap1, ap2, ap3, x, y } = req.body;

    if ([ap1, ap2, ap3, x, y].some(v => v === undefined)) {
        return res.status(400).json({ error: "ต้องส่ง ap1, ap2, ap3, x, y" });
    }

    db.query(
        "INSERT INTO wifi_dataset (ap1, ap2, ap3, x, y) VALUES (?, ?, ?, ?, ?)",
        [ap1, ap2, ap3, x, y],
        (err, result) => {
            if (err) {
                console.error("/save-point error:", err);
                return res.status(500).json(err);
            }
            console.log(`/save-point saved id=${result.insertId} (${x},${y})`);
            res.json({ success: true, insertId: result.insertId });
        }
    );
});

// -------------------------------------------------------
// GET /health
// -------------------------------------------------------
app.get("/health", async (req, res) => {
    // เช็ค ML Server
    let mlStatus = "offline";
    try { await callMLServer("/predict", { ap1: -70, ap2: -70, ap3: -70 }); mlStatus = "online"; }
    catch (e) { mlStatus = `offline: ${e.message}`; }

    // เช็ค Ollama
    let ollamaStatus = "offline";
    try {
        await new Promise((resolve, reject) => {
            const req = http.get("http://127.0.0.1:11434/api/tags", (r) => {
                resolve(r.statusCode);
            });
            req.on("error", reject);
            req.setTimeout(3000, () => { req.destroy(); reject(new Error("timeout")); });
        });
        ollamaStatus = "online";
    } catch (e) { ollamaStatus = `offline: ${e.message}`; }

    res.json({
        node_server: "online",
        ml_server: mlStatus,
        ollama: ollamaStatus,
        port: 3000
    });
});

// -------------------------------------------------------
// รัน server
// -------------------------------------------------------
app.listen(3000, () => {
    console.log("=====================================");
    console.log("Indoor Navigation — Node.js Server");
    console.log("=====================================");
    console.log("✓ Server รันที่ http://localhost:3000");
    console.log("  /locate     — ทำนายตำแหน่ง (ML)");
    console.log("  /explain    — อธิบายตำแหน่ง (LLM)");
    console.log("  /save-point — บันทึก fingerprint");
    console.log("  /health     — ตรวจสอบสถานะ");
    console.log("=====================================");
});