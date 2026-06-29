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
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.Tasks
import kotlinx.coroutines.*

class LocationService : Service() {
    
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val CHANNEL_ID = "LocationServiceChannel"
    
    // Infrastructure components
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var dbHelper: DatabaseHelper

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        dbHelper = DatabaseHelper(this)
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

        startForeground(1, notification)
        executeTelemetryLoop()

        return START_STICKY 
    }

    private fun executeTelemetryLoop() {
        serviceScope.launch {
            while (isActive) {
                try {
                    // Verifying runtime permissions before requesting hardware access
                    if (ContextCompat.checkSelfPermission(applicationContext, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                        
                        // Executing a synchronous location request to guarantee execution order within the coroutine
                        val locationTask = fusedLocationClient.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, null)
                        val location: Location? = Tasks.await(locationTask)
                        
                        if (location != null) {
                            dbHelper.insertLocation(
                                latitude = location.latitude,
                                longitude = location.longitude,
                                timestamp = System.currentTimeMillis(),
                                accuracy = location.accuracy
                            )
                        } else {
                            Log.w("LocationService", "SYSTEM METRIC: Hardware returned null location payload.")
                        }
                    }
                } catch (e: Exception) {
                    Log.e("LocationService", "SYSTEM METRIC: Exception during telemetry acquisition: ${e.message}")
                }
                
                // Suspend execution for precisely 60 seconds
                delay(60000)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
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