package com.example.mfuguide

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), SensorEventListener {
    private val channelName = "mfu.smartguide/connected_wifi"
    private val permissionRequestCode = 4107
    private var pendingResult: MethodChannel.Result? = null
    private var pendingMethod: String? = null
    private lateinit var sensorManager: SensorManager
    private var stepSensor: Sensor? = null
    @Volatile private var latestStepCount: Long? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (hasActivityPermission()) startStepSensor()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getConnectedWifi" -> {
                        if (hasRequiredPermissions()) result.success(readConnectedWifi())
                        else requestRequiredPermissions(call.method, result)
                    }
                    "getWifiScan" -> {
                        if (hasRequiredPermissions()) result.success(readWifiScan())
                        else requestRequiredPermissions(call.method, result)
                    }
                    "getStepCount" -> {
                        if (hasRequiredPermissions()) readStepCount(result)
                        else requestRequiredPermissions(call.method, result)
                    }
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
        requestPermissions(requiredPermissions(), permissionRequestCode)
    }

    private fun requiredPermissions(): Array<String> {
        val values = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            values.add(Manifest.permission.NEARBY_WIFI_DEVICES)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.add(Manifest.permission.ACTIVITY_RECOGNITION)
        }
        return values.toTypedArray()
    }

    private fun hasRequiredPermissions() = requiredPermissions().all {
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
    private fun readWifiScan(): List<Map<String, Any>> {
        val manager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        // Android may throttle startScan; scanResults still returns the latest
        // cached measurements, which is preferable to losing multi-AP input.
        manager.startScan()
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
        if (!hasRequiredPermissions()) {
            result.error("SENSOR_PERMISSION_DENIED", "Wi-Fi, location and activity permissions are required.", null)
        } else if (method == "getStepCount") {
            startStepSensor()
            readStepCount(result)
        } else if (method == "getWifiScan") {
            result.success(readWifiScan())
        } else {
            result.success(readConnectedWifi())
        }
    }

    override fun onResume() {
        super.onResume()
        if (::sensorManager.isInitialized && hasActivityPermission()) startStepSensor()
    }

    override fun onPause() {
        if (::sensorManager.isInitialized) sensorManager.unregisterListener(this)
        super.onPause()
    }
}
