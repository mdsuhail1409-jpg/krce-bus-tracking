package com.krce.bus.ui.screens

import android.annotation.SuppressLint
import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DirectionsBus
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.Fullscreen
import androidx.compose.material.icons.filled.FullscreenExit
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.google.android.gms.location.LocationServices
import com.krce.bus.api.ApiService
import com.krce.bus.ui.theme.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import com.google.gson.Gson
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.tileprovider.tilesource.XYTileSource
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polyline
import org.osmdroid.views.overlay.ScaleBarOverlay
import org.osmdroid.views.overlay.compass.CompassOverlay
import org.osmdroid.views.overlay.compass.InternalCompassOrientationProvider
import org.osmdroid.views.overlay.mylocation.MyLocationNewOverlay
import org.osmdroid.views.overlay.mylocation.GpsMyLocationProvider

data class OSRMRouteResult(
    val points: List<GeoPoint>,
    val durationText: String,
    val distanceText: String
)

@SuppressLint("MissingPermission")
@Composable
fun LiveMapScreen(authToken: String, busId: String?) {
    val context = LocalContext.current
    val apiService = remember { ApiService.create() }
    var liveBuses by remember { mutableStateOf<List<com.krce.bus.models.Bus>>(emptyList()) }
    var errorMessage by remember { mutableStateOf("") }
    
    // Interactive Map settings
    var isMapDarkMode by remember { mutableStateOf(false) }
    var isFullscreen by remember { mutableStateOf(false) }
    
    // Polling logic
    LaunchedEffect(Unit) {
        while (true) {
            try {
                val buses = apiService.getBuses(authToken)
                liveBuses = buses
            } catch (e: Exception) {
                errorMessage = "Failed to load live bus data"
            }
            delay(5000)
        }
    }

    val collegeLatLng = GeoPoint(10.927669, 78.7410) // Actual KRCE campus coordinates

    // Keep track of the currently selected/tracked bus
    var selectedBusId by remember { mutableStateOf(busId) }
    
    // Selected bus object
    val trackedBus = liveBuses.find { it.id == selectedBusId }
    val trackedLive = trackedBus?.live

    // Smoothly animated marker position
    var animatedBusLatLng by remember { mutableStateOf<GeoPoint?>(null) }
    LaunchedEffect(trackedLive) {
        trackedLive?.let { live ->
            val target = GeoPoint(live.lat, live.lon)
            val start = animatedBusLatLng ?: target
            val steps = 20
            val stepTime = 1000L / steps
            for (i in 1..steps) {
                val fraction = i.toFloat() / steps
                val lat = start.latitude + (target.latitude - start.latitude) * fraction
                val lon = start.longitude + (target.longitude - start.longitude) * fraction
                animatedBusLatLng = GeoPoint(lat, lon)
                delay(stepTime)
            }
            animatedBusLatLng = target
        }
    }

    // Directions state from OSRM (Zero keys required)
    var directionsResult by remember { mutableStateOf<OSRMRouteResult?>(null) }
    
    // Fetch directions from OSRM every time the tracked bus position changes
    LaunchedEffect(trackedLive) {
        trackedLive?.let { live ->
            val result = fetchOSRMRoute(
                originLat = live.lat,
                originLon = live.lon,
                destLat = collegeLatLng.latitude,
                destLon = collegeLatLng.longitude
            )
            directionsResult = result
        }
    }

    // Fused Location Client for "Locate Me"
    val fusedLocationClient = remember { LocationServices.getFusedLocationProviderClient(context) }
    var mapRef by remember { mutableStateOf<MapView?>(null) }

    // Fit Bounds state
    var hasCentered by remember { mutableStateOf(false) }
    LaunchedEffect(animatedBusLatLng) {
        animatedBusLatLng?.let { busPoint ->
            val mapView = mapRef
            if (mapView != null && !hasCentered) {
                try {
                    val box = BoundingBox.fromGeoPoints(listOf(collegeLatLng, busPoint))
                    mapView.zoomToBoundingBox(box, true, 150)
                    hasCentered = true
                } catch (e: Exception) {
                    mapView.controller.animateTo(busPoint)
                    mapView.controller.setZoom(14.0)
                    hasCentered = true
                }
            }
        }
    }

    Scaffold { padding ->
        Box(
            modifier = Modifier
                .padding(if (isFullscreen) PaddingValues(0.dp) else padding)
                .fillMaxSize()
        ) {
            // OSMDroid Map Container
            AndroidView(
                factory = { ctx ->
                    MapView(ctx).apply {
                        setMultiTouchControls(true)
                        zoomController.setVisibility(org.osmdroid.views.CustomZoomButtonsController.Visibility.NEVER)
                        controller.setZoom(12.5)
                        controller.setCenter(collegeLatLng)
                        
                        // Add Scale Bar Overlay
                        val scaleBar = ScaleBarOverlay(this).apply {
                            setAlignBottom(true)
                            setScaleBarOffset(10, 50)
                        }
                        overlays.add(scaleBar)

                        // Add Compass Overlay
                        val compass = CompassOverlay(ctx, InternalCompassOrientationProvider(ctx), this).apply {
                            enableCompass()
                        }
                        overlays.add(compass)

                        // Add My Location Overlay (user device GPS pointer)
                        val myLocation = MyLocationNewOverlay(GpsMyLocationProvider(ctx), this).apply {
                            enableMyLocation()
                        }
                        overlays.add(myLocation)
                        
                        mapRef = this
                    }
                },
                modifier = Modifier.fillMaxSize(),
                update = { mapView ->
                    // Apply Dark / Light layer
                    if (isMapDarkMode) {
                        val darkTileSource = XYTileSource(
                            "CartoDark",
                            0, 19, 256, ".png",
                            arrayOf(
                                "https://a.basemaps.cartocdn.com/dark_all/",
                                "https://b.basemaps.cartocdn.com/dark_all/",
                                "https://c.basemaps.cartocdn.com/dark_all/"
                            )
                        )
                        mapView.setTileSource(darkTileSource)
                    } else {
                        mapView.setTileSource(TileSourceFactory.MAPNIK)
                    }

                    // Clear previous overlays except dynamic defaults (Scale, Compass & MyLocation)
                    val baseOverlays = mapView.overlays.filter { 
                        it is ScaleBarOverlay || it is CompassOverlay || it is MyLocationNewOverlay 
                    }
                    mapView.overlays.clear()
                    mapView.overlays.addAll(baseOverlays)

                    // Draw College Campus Marker
                    val collegeMarker = Marker(mapView).apply {
                        position = collegeLatLng
                        title = "K. Ramakrishnan College of Engineering"
                        snippet = "Campus Main Gate"
                        icon = createCampusMarkerIcon(context)
                        setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                    }
                    mapView.overlays.add(collegeMarker)

                    // Draw Bus Markers
                    liveBuses.forEach { bus ->
                        bus.live?.let { live ->
                            // Use animated position for tracked bus, snapped for others
                            val busPos = if (bus.id == selectedBusId && animatedBusLatLng != null) {
                                animatedBusLatLng!!
                            } else {
                                GeoPoint(live.lat, live.lon)
                            }
                            
                            val busMarker = Marker(mapView).apply {
                                position = busPos
                                title = "Bus ${bus.number}"
                                snippet = "Route: ${bus.routeName} | Speed: ${live.speed.toInt()} km/h"
                                val isOnline = live.status != "offline"
                                icon = createBusMarkerIcon(context, bus.number, isOnline)
                                setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                                setOnMarkerClickListener { _, _ ->
                                    selectedBusId = bus.id
                                    hasCentered = false // Refit bounds
                                    true
                                }
                            }
                            mapView.overlays.add(busMarker)
                        }
                    }

                    // Draw Route line
                    directionsResult?.let { result ->
                        val routeLine = Polyline(mapView).apply {
                            setPoints(result.points)
                            outlinePaint.color = android.graphics.Color.parseColor("#1F3E97")
                            outlinePaint.strokeWidth = 10f
                        }
                        mapView.overlays.add(routeLine)
                    }

                    mapView.invalidate()
                }
            )

            // Top overlay card (Title / Error message if any)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
                    .align(Alignment.TopCenter)
            ) {
                if (errorMessage.isNotEmpty()) {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = ErrorRed.copy(alpha = 0.9f)),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 8.dp)
                    ) {
                        Text(
                            text = errorMessage,
                            color = Color.White,
                            modifier = Modifier.padding(12.dp),
                            style = Typography.bodyMedium,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }

            // Interactive Map Controls (Fabs)
            Column(
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Layer Selection button
                FloatingActionButton(
                    onClick = { isMapDarkMode = !isMapDarkMode },
                    containerColor = Color.White,
                    contentColor = IndigoPrimary,
                    shape = CircleShape,
                    modifier = Modifier.size(50.dp)
                ) {
                    Icon(Icons.Default.Layers, contentDescription = "Layers")
                }

                // Locate Me Button
                FloatingActionButton(
                    onClick = {
                        try {
                            fusedLocationClient.lastLocation.addOnSuccessListener { location ->
                                if (location != null) {
                                    val userPoint = GeoPoint(location.latitude, location.longitude)
                                    mapRef?.controller?.animateTo(userPoint)
                                    mapRef?.controller?.setZoom(16.0)
                                }
                            }
                        } catch (e: Exception) {
                            errorMessage = "Location permission required"
                        }
                    },
                    containerColor = Color.White,
                    contentColor = IndigoPrimary,
                    shape = CircleShape,
                    modifier = Modifier.size(50.dp)
                ) {
                    Icon(Icons.Default.MyLocation, contentDescription = "Locate Me")
                }

                // Fullscreen Button
                FloatingActionButton(
                    onClick = { isFullscreen = !isFullscreen },
                    containerColor = Color.White,
                    contentColor = IndigoPrimary,
                    shape = CircleShape,
                    modifier = Modifier.size(50.dp)
                ) {
                    Icon(
                        imageVector = if (isFullscreen) Icons.Default.FullscreenExit else Icons.Default.Fullscreen,
                        contentDescription = "Toggle Fullscreen"
                    )
                }
            }

            // Bottom overlay card showing details
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.BottomCenter)
                    .padding(16.dp)
            ) {
                if (trackedBus != null && trackedLive != null) {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = SurfaceColor),
                        shape = RoundedCornerShape(24.dp),
                        elevation = CardDefaults.cardElevation(defaultElevation = 6.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .border(1.dp, BorderColor, RoundedCornerShape(24.dp))
                    ) {
                        Column(modifier = Modifier.padding(20.dp)) {
                            // Header row
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Box(
                                        modifier = Modifier
                                            .size(44.dp)
                                            .background(BusBadgeBg, RoundedCornerShape(12.dp)),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Icon(Icons.Default.DirectionsBus, contentDescription = null, tint = BusBadgeIcon)
                                    }
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Column {
                                        Text(
                                            text = "Bus ${trackedBus.number}",
                                            style = Typography.titleLarge,
                                            fontWeight = FontWeight.Bold
                                        )
                                        Text(
                                            text = trackedBus.routeName,
                                            style = Typography.bodySmall,
                                            color = MutedText
                                        )
                                    }
                                }
                                IconButton(
                                    onClick = {
                                        selectedBusId = null
                                        directionsResult = null
                                    }
                                ) {
                                    Icon(Icons.Default.Close, contentDescription = "Close", tint = MutedText)
                                }
                            }

                            Spacer(modifier = Modifier.height(16.dp))
                            Divider(color = BorderColor, thickness = 0.5.dp)
                            Spacer(modifier = Modifier.height(16.dp))

                            // Grid details
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Column(horizontalAlignment = Alignment.Start) {
                                    Text("ETA", style = Typography.bodySmall, color = MutedText)
                                    Spacer(modifier = Modifier.height(2.dp))
                                    Text(
                                        text = directionsResult?.durationText ?: "Calculating...",
                                        style = Typography.titleLarge,
                                        color = SuccessGreen,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                                Column(horizontalAlignment = Alignment.Start) {
                                    Text("Distance", style = Typography.bodySmall, color = MutedText)
                                    Spacer(modifier = Modifier.height(2.dp))
                                    Text(
                                        text = directionsResult?.distanceText ?: "Calculating...",
                                        style = Typography.titleLarge,
                                        color = TextColor,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                                Column(horizontalAlignment = Alignment.Start) {
                                    Text("Speed", style = Typography.bodySmall, color = MutedText)
                                    Spacer(modifier = Modifier.height(2.dp))
                                    Text(
                                        text = "${trackedLive.speed.toInt()} km/h",
                                        style = Typography.titleLarge,
                                        color = TextColor,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                                Column(horizontalAlignment = Alignment.Start) {
                                    Text("Passengers", style = Typography.bodySmall, color = MutedText)
                                    Spacer(modifier = Modifier.height(2.dp))
                                    Text(
                                        text = "${trackedLive.passengers}",
                                        style = Typography.titleLarge,
                                        color = TextColor,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            }
                        }
                    }
                } else {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = SurfaceColor),
                        shape = RoundedCornerShape(20.dp),
                        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .border(1.dp, BorderColor, RoundedCornerShape(20.dp))
                    ) {
                        Row(
                            modifier = Modifier.padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(40.dp)
                                    .background(BusBadgeBg, RoundedCornerShape(10.dp)),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Default.DirectionsBus, contentDescription = null, tint = BusBadgeIcon)
                            }
                            Spacer(modifier = Modifier.width(16.dp))
                            Column {
                                Text(
                                    text = "Campus Bus Fleet",
                                    style = Typography.titleMedium,
                                    fontWeight = FontWeight.Bold
                                )
                                Text(
                                    text = "Total Active: ${liveBuses.filter { it.live != null }.size}",
                                    style = Typography.bodySmall,
                                    color = MutedText
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// Request optimal routing from Open Source Routing Machine (OSRM)
suspend fun fetchOSRMRoute(originLat: Double, originLon: Double, destLat: Double, destLon: Double): OSRMRouteResult? {
    return withContext(Dispatchers.IO) {
        try {
            val client = OkHttpClient()
            val url = "https://router.project-osrm.org/route/v1/driving/$originLon,$originLat;$destLon,$destLat?overview=full&geometries=geojson"
            val request = Request.Builder().url(url).build()
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return@withContext null
                val body = response.body?.string() ?: return@withContext null
                val gson = Gson()
                val jsonObject = gson.fromJson(body, com.google.gson.JsonObject::class.java)
                val routesObj = jsonObject.getAsJsonArray("routes")
                if (routesObj != null && routesObj.size() > 0) {
                    val route = routesObj.get(0).asJsonObject
                    val distanceMeters = route.get("distance").asDouble
                    val durationSeconds = route.get("duration").asDouble
                    
                    val geometry = route.getAsJsonObject("geometry")
                    val coordinates = geometry.getAsJsonArray("coordinates")
                    val points = ArrayList<GeoPoint>()
                    coordinates.forEach { elem ->
                        val coord = elem.asJsonArray
                        val lon = coord.get(0).asDouble
                        val lat = coord.get(1).asDouble
                        points.add(GeoPoint(lat, lon))
                    }
                    
                    // Format distance
                    val distanceText = if (distanceMeters >= 1000) {
                        String.format("%.1f km", distanceMeters / 1000.0)
                    } else {
                        String.format("%d m", distanceMeters.toInt())
                    }

                    // Format travel duration
                    val durationMins = (durationSeconds / 60.0).toInt()
                    val durationText = if (durationMins > 0) {
                        "$durationMins mins"
                    } else {
                        "1 min"
                    }

                    return@withContext OSRMRouteResult(points, durationText, distanceText)
                }
            }
            null
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}

fun createCampusMarkerIcon(context: android.content.Context): android.graphics.drawable.BitmapDrawable {
    val size = 96
    val bitmap = android.graphics.Bitmap.createBitmap(size, size, android.graphics.Bitmap.Config.ARGB_8888)
    val canvas = android.graphics.Canvas(bitmap)
    val paint = android.graphics.Paint().apply { isAntiAlias = true }
    
    // Outer white circle
    paint.color = android.graphics.Color.WHITE
    canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
    
    // Inner indigo/purple circle
    paint.color = android.graphics.Color.parseColor("#8B5CF6")
    canvas.drawCircle(size / 2f, size / 2f, size / 2f - 6f, paint)
    
    // Center target dot
    paint.color = android.graphics.Color.WHITE
    canvas.drawCircle(size / 2f, size / 2f, size / 5f, paint)
    
    return android.graphics.drawable.BitmapDrawable(context.resources, bitmap)
}

fun createBusMarkerIcon(context: android.content.Context, busNumber: String, isOnline: Boolean): android.graphics.drawable.BitmapDrawable {
    val width = 140
    val height = 100
    val bitmap = android.graphics.Bitmap.createBitmap(width, height, android.graphics.Bitmap.Config.ARGB_8888)
    val canvas = android.graphics.Canvas(bitmap)
    val paint = android.graphics.Paint().apply { isAntiAlias = true }

    // Shadow
    paint.color = android.graphics.Color.parseColor("#44000000")
    canvas.drawRoundRect(4f, 6f, width - 4f, height - 4f, 20f, 20f, paint)

    // Bus body: white outline
    paint.color = android.graphics.Color.WHITE
    canvas.drawRoundRect(2f, 2f, width - 2f, height - 14f, 18f, 18f, paint)

    // Bus body fill: Green for online, grey for offline
    val bodyColor = if (isOnline) "#10B981" else "#64748B"
    paint.color = android.graphics.Color.parseColor(bodyColor)
    canvas.drawRoundRect(6f, 6f, width - 6f, height - 18f, 14f, 14f, paint)

    // Tail / pointer triangle at bottom center
    val triPath = android.graphics.Path().apply {
        moveTo(width / 2f - 14f, height - 18f)
        lineTo(width / 2f + 14f, height - 18f)
        lineTo(width / 2f, height.toFloat())
        close()
    }
    paint.color = android.graphics.Color.parseColor(bodyColor)
    canvas.drawPath(triPath, paint)

    // White outline for triangle
    paint.color = android.graphics.Color.WHITE
    paint.style = android.graphics.Paint.Style.STROKE
    paint.strokeWidth = 2f
    canvas.drawPath(triPath, paint)
    paint.style = android.graphics.Paint.Style.FILL

    // Bus windows — three small white rounded rects
    paint.color = android.graphics.Color.parseColor("#CCFFFFFF")
    canvas.drawRoundRect(14f, 14f, 50f, 46f, 6f, 6f, paint)
    canvas.drawRoundRect(58f, 14f, 94f, 46f, 6f, 6f, paint)
    canvas.drawRoundRect(102f, 14f, 128f, 46f, 6f, 6f, paint)

    // Bus number label at bottom of body
    paint.color = android.graphics.Color.WHITE
    paint.textSize = 26f
    paint.typeface = android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD)
    paint.textAlign = android.graphics.Paint.Align.CENTER
    val label = if (busNumber.contains("-")) busNumber.split("-").last() else busNumber
    val textY = height - 22f - ((paint.descent() + paint.ascent()) / 2f)
    canvas.drawText(label, width / 2f, textY, paint)

    return android.graphics.drawable.BitmapDrawable(context.resources, bitmap)
}
