package com.example.gps_tracker

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.Tasks
import kotlinx.coroutines.*

class LocationService : Service() {
    
    // Establishing a global state flag for the UI to query
    companion object {
        var isServiceRunning = false
    }

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val CHANNEL_ID = "LocationServiceChannel"
    
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var dbHelper: DatabaseHelper
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        dbHelper = DatabaseHelper(this)

        // Acquire a Partial WakeLock to keep the CPU running during screen-off sleep states
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "GPSTracker::ExecutionLock")
        wakeLock?.acquire()
        Log.i("LocationService", "SYSTEM METRIC: CPU WakeLock acquired.")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val hasFineLocation = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val hasCoarseLocation = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        
        if (!hasFineLocation && !hasCoarseLocation) {
            Log.e("LocationService", "SYSTEM METRIC: Insufficient runtime permissions. Terminating FGS execution.")
            stopSelf()
            return START_NOT_STICKY
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Active Tracking Session")
            .setContentText("Acquiring telemetry data...")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        isServiceRunning = true // Update global state
        startForeground(1, notification)
        executeTelemetryLoop()

        return START_STICKY 
    }

    private fun executeTelemetryLoop() {
        serviceScope.launch {
            while (isActive) {
                Log.i("LocationService", "SYSTEM METRIC: Commencing 60-second telemetry polling tick.")
                
                try {
                    if (ContextCompat.checkSelfPermission(applicationContext, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                        
                        Log.d("LocationService", "SYSTEM METRIC: Dispatching PRIORITY_HIGH_ACCURACY request to hardware...")
                        
                        // Executing location request
                        val locationTask = fusedLocationClient.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, null)
                        val location: Location? = Tasks.await(locationTask)
                        
                        if (location != null) {
                            Log.i("LocationService", "SYSTEM METRIC: Hardware locked -> Lat: ${location.latitude}, Lon: ${location.longitude}, Acc: ${location.accuracy}m")
                            
                            dbHelper.insertLocation(
                                latitude = location.latitude,
                                longitude = location.longitude,
                                timestamp = System.currentTimeMillis(),
                                accuracy = location.accuracy
                            )
                        } else {
                            Log.w("LocationService", "SYSTEM METRIC: Hardware Payload is NULL. The device is indoors, has no satellite line-of-sight, and has no cached coordinates.")
                        }
                    } else {
                        Log.e("LocationService", "SYSTEM METRIC: Polling aborted. Permissions are not GRANTED at runtime.")
                    }
                } catch (e: SecurityException) {
                    Log.e("LocationService", "SYSTEM METRIC: Security Exception during polling (Permissions likely revoked mid-session): ${e.message}")
                } catch (e: Exception) {
                    Log.e("LocationService", "SYSTEM METRIC: Critical Exception during FusedLocationClient execution: ${e.message}")
                }
                
                // Suspend execution for precisely 60 seconds
                delay(60000)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isServiceRunning = false
        serviceScope.cancel()
        
        // Release the CPU lock to prevent battery drain when tracking is stopped
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
                Log.i("LocationService", "SYSTEM METRIC: CPU WakeLock released.")
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Telemetry Operations",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }
}