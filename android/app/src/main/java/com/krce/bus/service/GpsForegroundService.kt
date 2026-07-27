package com.krce.bus.service

import android.app.*
import android.content.Intent
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import com.krce.bus.MainActivity
import com.krce.bus.api.WebSocketManager
import com.krce.bus.ui.theme.SuccessGreen
import org.json.JSONObject

class GpsForegroundService : Service() {

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback
    private var webSocketManager: WebSocketManager? = null
    private val channelId = "GpsServiceChannel"
    private val notificationId = 101

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val token = intent?.getStringExtra("EXTRA_TOKEN") ?: ""
        val busId = intent?.getStringExtra("EXTRA_BUS_ID") ?: ""

        if (token.isNotEmpty() && webSocketManager == null) {
            webSocketManager = WebSocketManager(token.replace("Bearer ", ""))
            webSocketManager?.connect { msg ->
                Log.d("GpsService", "Received: $msg")
            }
        }

        val notification = createNotification()
        startForeground(notificationId, notification)

        startLocationUpdates(busId)

        return START_STICKY
    }

    private fun startLocationUpdates(busId: String) {
        val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 5000)
            .setWaitForAccurateLocation(false)
            .setMinUpdateIntervalMillis(3000)
            .setMaxUpdateDelayMillis(10000)
            .build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                for (location in locationResult.locations) {
                    sendLocationToBackend(location)
                }
            }
        }

        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback,
                Looper.getMainLooper()
            )
        } catch (unlikely: SecurityException) {
            Log.e("GpsService", "Lost location permission. Couldn't remove updates. $unlikely")
        }
    }

    private fun sendLocationToBackend(location: Location) {
        val json = JSONObject().apply {
            put("type", "gps")
            put("lat", location.latitude)
            put("lon", location.longitude)
            put("speed", location.speed * 3.6) // Convert to km/h
            put("heading", location.bearing)
            put("passengers", 0) // Placeholder
        }
        webSocketManager?.send(json.toString())
        Log.d("GpsService", "Sent: $json")
    }

    private fun createNotification(): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("KRCE Bus Tracking")
            .setContentText("Broadcasting your location live...")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                channelId, "GPS Service Channel",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        fusedLocationClient.removeLocationUpdates(locationCallback)
        webSocketManager?.close()
        webSocketManager = null
    }
}
