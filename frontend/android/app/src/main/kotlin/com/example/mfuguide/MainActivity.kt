package com.example.mfuguide

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "mfu.smartguide/connected_wifi"
    private val permissionRequestCode = 4107
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "getConnectedWifi") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (hasWifiPermissions()) result.success(readConnectedWifi())
                else {
                    pendingResult = result
                    requestPermissions(requiredPermissions(), permissionRequestCode)
                }
            }
    }

    private fun requiredPermissions(): Array<String> {
        val values = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            values.add(Manifest.permission.NEARBY_WIFI_DEVICES)
        }
        return values.toTypedArray()
    }

    private fun hasWifiPermissions() = requiredPermissions().all {
        checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
    }

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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequestCode) return
        val result = pendingResult ?: return
        pendingResult = null
        if (hasWifiPermissions()) result.success(readConnectedWifi())
        else result.error("WIFI_PERMISSION_DENIED", "Wi-Fi and location permissions are required.", null)
    }
}
