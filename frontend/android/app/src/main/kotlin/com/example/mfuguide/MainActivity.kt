package com.example.mfuguide

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), SensorEventListener {
    private val channelName = "mfu.smartguide/connected_wifi"
    private val permissionRequestCode = 4107
    private var pendingResult: MethodChannel.Result? = null
    private var pendingMethod: String? = null
    private var pendingWifiScanResult: MethodChannel.Result? = null
    private var wifiScanReceiverRegistered = false
    private val mainHandler = Handler(Looper.getMainLooper())
    private val wifiScanTimeout = Runnable { finishWifiScan() }
    private val wifiScanReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == WifiManager.SCAN_RESULTS_AVAILABLE_ACTION) {
                finishWifiScan()
            }
        }
    }
    private lateinit var sensorManager: SensorManager
    private var stepSensor: Sensor? = null
    private var accelerometer: Sensor? = null
    @Volatile private var latestStepCount: Long? = null
    private val gravity = FloatArray(3)
    @Volatile private var lastMotionAtMs: Long = 0
    @Volatile private var motionStartedAtMs: Long = 0
    @Volatile private var motionIntensity: Double = 0.0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        startMotionSensor()
        if (hasActivityPermission()) startStepSensor()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getConnectedWifi" -> {
                        if (hasRequiredPermissions(call.method)) result.success(readConnectedWifi())
                        else requestRequiredPermissions(call.method, result)
                    }
                    "getWifiScan" -> {
                        if (hasRequiredPermissions(call.method)) requestWifiScan(result)
                        else requestRequiredPermissions(call.method, result)
                    }
                    "getStepCount" -> {
                        if (hasRequiredPermissions(call.method)) readStepCount(result)
                        else requestRequiredPermissions(call.method, result)
                    }
                    "getMotionState" -> readMotionState(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestRequiredPermissions(method: String, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("PERMISSION_REQUEST_ACTIVE", "Another permission request is active.", null)
            return
        }
        pendingResult = result
        pendingMethod = method
        requestPermissions(requiredPermissions(method), permissionRequestCode)
    }

    private fun requiredPermissions(method: String? = null): Array<String> {
        val values = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            values.add(Manifest.permission.NEARBY_WIFI_DEVICES)
        }
        if (method == "getStepCount" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.add(Manifest.permission.ACTIVITY_RECOGNITION)
        }
        return values.toTypedArray()
    }

    private fun hasRequiredPermissions(method: String? = null) = requiredPermissions(method).all {
        checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasActivityPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) ==
            PackageManager.PERMISSION_GRANTED

    private fun startStepSensor() {
        val sensor = stepSensor ?: return
        sensorManager.unregisterListener(this, sensor)
        sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_FASTEST, 0)
    }

    private fun startMotionSensor() {
        val sensor = accelerometer ?: return
        sensorManager.unregisterListener(this, sensor)
        sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_GAME)
    }

    private fun readMotionState(result: MethodChannel.Result) {
        if (accelerometer == null) {
            result.error("ACCELEROMETER_UNAVAILABLE", "This phone has no accelerometer.", null)
            return
        }
        val now = System.currentTimeMillis()
        val recentlyActive = now - lastMotionAtMs <= 1400L
        val sustained = motionStartedAtMs > 0L && now - motionStartedAtMs >= 450L
        result.success(
            mapOf(
                "moving" to (recentlyActive && sustained),
                "intensity" to motionIntensity,
                "lastMotionAgeMs" to if (lastMotionAtMs == 0L) -1L else now - lastMotionAtMs
            )
        )
    }

    private fun readStepCount(result: MethodChannel.Result) {
        if (stepSensor == null) {
            result.error("STEP_COUNTER_UNAVAILABLE", "This phone has no step counter sensor.", null)
            return
        }
        val count = latestStepCount
        if (count == null) {
            startStepSensor()
            result.error("STEP_COUNTER_STARTING", "Step counter is starting. Try again in one second.", null)
        } else {
            result.success(count)
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type == Sensor.TYPE_STEP_COUNTER) {
            latestStepCount = event.values[0].toLong()
        } else if (event.sensor.type == Sensor.TYPE_ACCELEROMETER) {
            val alpha = 0.82f
            var squared = 0.0
            for (index in 0..2) {
                gravity[index] = alpha * gravity[index] + (1f - alpha) * event.values[index]
                val linear = event.values[index] - gravity[index]
                squared += linear * linear
            }
            val magnitude = kotlin.math.sqrt(squared)
            motionIntensity = motionIntensity * 0.85 + magnitude * 0.15
            val now = System.currentTimeMillis()
            if (magnitude >= 0.55) {
                if (now - lastMotionAtMs > 650L) motionStartedAtMs = now
                lastMotionAtMs = now
            } else if (now - lastMotionAtMs > 1400L) {
                motionStartedAtMs = 0L
                motionIntensity *= 0.8
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    @Suppress("DEPRECATION")
    private fun readConnectedWifi(): Map<String, Any> {
        val manager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val info = manager.connectionInfo
        return mapOf(
            "ssid" to (info.ssid ?: "").removeSurrounding("\""),
            "bssid" to (info.bssid ?: "").lowercase(),
            "rssi" to info.rssi,
            "networkId" to info.networkId
        )
    }

    @Suppress("DEPRECATION")
    private fun requestWifiScan(result: MethodChannel.Result) {
        if (pendingWifiScanResult != null) {
            result.error("WIFI_SCAN_ACTIVE", "A Wi-Fi scan is already running.", null)
            return
        }
        pendingWifiScanResult = result
        val filter = IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(wifiScanReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(wifiScanReceiver, filter)
        }
        wifiScanReceiverRegistered = true

        val manager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val started = manager.startScan()
        // Android throttles active scans. If a new scan cannot start, return
        // the latest cached multi-AP results instead of returning no data.
        mainHandler.postDelayed(wifiScanTimeout, if (started) 2500L else 100L)
    }

    private fun finishWifiScan() {
        val result = pendingWifiScanResult ?: return
        pendingWifiScanResult = null
        mainHandler.removeCallbacks(wifiScanTimeout)
        if (wifiScanReceiverRegistered) {
            try {
                unregisterReceiver(wifiScanReceiver)
            } catch (_: IllegalArgumentException) {
                // Receiver may already be detached while the activity closes.
            }
            wifiScanReceiverRegistered = false
        }
        result.success(readWifiScanResults())
    }

    @Suppress("DEPRECATION")
    private fun readWifiScanResults(): List<Map<String, Any>> {
        val manager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        return manager.scanResults
            .filter { it.SSID == "AS-Project" }
            .map {
                mapOf(
                    "ssid" to it.SSID,
                    "bssid" to it.BSSID.lowercase(),
                    "rssi" to it.level,
                    "frequency" to it.frequency
                )
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequestCode) return
        val result = pendingResult ?: return
        val method = pendingMethod
        pendingResult = null
        pendingMethod = null
        if (!hasRequiredPermissions(method)) {
            result.error("SENSOR_PERMISSION_DENIED", "The required Wi-Fi or sensor permission was denied.", null)
        } else if (method == "getStepCount") {
            startStepSensor()
            readStepCount(result)
        } else if (method == "getWifiScan") {
            requestWifiScan(result)
        } else {
            result.success(readConnectedWifi())
        }
    }

    override fun onResume() {
        super.onResume()
        if (::sensorManager.isInitialized) startMotionSensor()
        if (::sensorManager.isInitialized && hasActivityPermission()) startStepSensor()
    }

    override fun onPause() {
        if (::sensorManager.isInitialized) sensorManager.unregisterListener(this)
        super.onPause()
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(wifiScanTimeout)
        pendingWifiScanResult?.error("WIFI_SCAN_CANCELLED", "The Wi-Fi scan was cancelled.", null)
        pendingWifiScanResult = null
        if (wifiScanReceiverRegistered) {
            try {
                unregisterReceiver(wifiScanReceiver)
            } catch (_: IllegalArgumentException) {
                // Receiver was already unregistered.
            }
            wifiScanReceiverRegistered = false
        }
        super.onDestroy()
    }
}
