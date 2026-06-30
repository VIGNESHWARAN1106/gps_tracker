package com.example.gps_tracker

import android.content.Context
import android.content.Intent
import android.os.BatteryManager
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    
    private val BATTERY_CHANNEL = "com.example.gps_tracker/battery"
    private val CONTROL_CHANNEL = "com.example.gps_tracker/control"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Battery Telemetry Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getBatteryLevel") {
                val batteryLevel = retrieveBatteryCapacity()
                if (batteryLevel != -1) {
                    result.success(batteryLevel)
                } else {
                    result.error("UNAVAILABLE", "SYSTEM METRIC: Battery level unable to be acquired.", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // 2. Service Control Channel
       MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTROL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startTracking" -> {
                    executeServiceInitialization()
                    result.success(true)
                }
                "stopTracking" -> {
                    executeServiceTermination()
                    result.success(true)
                }
                "isServiceRunning" -> {
                    // Returns the static flag from the service to the Flutter UI
                    result.success(LocationService.isServiceRunning)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun retrieveBatteryCapacity(): Int {
        val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        return batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
    }

    private fun executeServiceInitialization() {
        val serviceIntent = Intent(this, LocationService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun executeServiceTermination() {
        val serviceIntent = Intent(this, LocationService::class.java)
        stopService(serviceIntent)
    }
}