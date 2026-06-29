package com.example.gps_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import android.Manifest
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Enforce strict intent matching
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        // PRE-FLIGHT VALIDATION: Verify permissions before requesting service allocation
        val hasFineLocation = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val hasCoarseLocation = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        
        if (!hasFineLocation && !hasCoarseLocation) {
            Log.w("BootReceiver", "SYSTEM METRIC: Insufficient runtime permissions. Aborting autonomous service initialization.")
            return // Terminate execution here. Do not invoke startForegroundService.
        }

        val serviceIntent = Intent(context, LocationService::class.java)
        
        // API 26+ explicit FGS allocation
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}