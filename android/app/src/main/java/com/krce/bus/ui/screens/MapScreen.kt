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
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.google.android.gms.location.LocationServices
import com.krce.bus.api.ApiService
import com.krce.bus.ui.theme.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import com.google.gson.Gson
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.LatLngBounds
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.MapStyleOptions
import com.google.maps.android.compose.*

data class OSRMRouteResult(
    val points: List<LatLng>,
    val durationText: String,
    val distanceText: String
)

@SuppressLint("MissingPermission")
@Composable
fun LiveMapScreen(authToken: String, busId: String?) {
    val context = LocalContext.current
    val apiService = remember { ApiService.create() }
    val coroutineScope = rememberCoroutineScope()
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

    val collegeLatLng = LatLng(10.927669, 78.7410) // Actual KRCE campus coordinates

    val stopCoordinates = remember {
        mapOf(
            "KRCE Campus" to LatLng(10.927669, 78.7410),
            "Samayapuram" to LatLng(10.9310, 78.8130),
            "Woraiyur Bus Stand" to LatLng(10.7905, 78.7047),
            "Woraiyur Town" to LatLng(10.7920, 78.7020),
            "Gandhi Market" to LatLng(10.8190, 78.6990),
            "Panjappur" to LatLng(10.7516, 78.6830),
            "Srirangam" to LatLng(10.8631, 78.6933),
            "Cauvery Bridge" to LatLng(10.8416, 78.7010),
            "K.K. Nagar" to LatLng(10.8176, 78.6960),
            "Thuvakudi" to LatLng(10.8730, 78.7680),
            "Ariyamangalam" to LatLng(10.8280, 78.7380),
            "Cantonment" to LatLng(10.8116, 78.6860),
            "Collector Office" to LatLng(10.8080, 78.6820),
            "Palakarai" to LatLng(10.8120, 78.6930),
            "Chatram Bus Stand" to LatLng(10.8096, 78.6964),
            "Central" to LatLng(10.8050, 78.6840),
            "Junction" to LatLng(10.8020, 78.6810),
            "Thillai Nagar" to LatLng(10.8240, 78.6890),
            "Mannarpuram" to LatLng(10.8182, 78.7030),
            "Rockfort" to LatLng(10.8300, 78.6970),
            "Chinthamani" to LatLng(10.8350, 78.7020),
            "TVS Tollgate" to LatLng(10.8015, 78.6890),
            "SIT" to LatLng(10.8055, 78.6912),
            "Ambigapuram" to LatLng(10.7985, 78.7050),
            "Manjathidal" to LatLng(10.7950, 78.7110),
            "Armory Gate" to LatLng(10.7915, 78.7180),
            "Panjayat Office" to LatLng(10.7880, 78.7240),
            "Kalkandar Kottai" to LatLng(10.7850, 78.7310),
            "BVM Trichy" to LatLng(10.8100, 78.6950),
            "Kadai Veethi" to LatLng(10.8050, 78.7000),
            "Mandabam" to LatLng(10.8000, 78.7080),
            "Aathupalam" to LatLng(10.7930, 78.7150)
        )
    }

    // Keep track of the currently selected/tracked bus
    var selectedBusId by remember { mutableStateOf(busId) }
    
    // Selected bus object
    val trackedBus = liveBuses.find { it.id == selectedBusId }
    val trackedLive = trackedBus?.live

    // Smoothly animated marker position
    var animatedBusLatLng by remember { mutableStateOf<LatLng?>(null) }
    LaunchedEffect(trackedLive) {
        trackedLive?.let { live ->
            val target = LatLng(live.lat, live.lon)
            val start = animatedBusLatLng ?: target
            val steps = 20
            val stepTime = 1000L / steps
            for (i in 1..steps) {
                val fraction = i.toFloat() / steps
                val lat = start.latitude + (target.latitude - start.latitude) * fraction
                val lon = start.longitude + (target.longitude - start.longitude) * fraction
                animatedBusLatLng = LatLng(lat, lon)
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
            val dLat = live.destinationLat ?: collegeLatLng.latitude
            val dLon = live.destinationLon ?: collegeLatLng.longitude
            val result = fetchOSRMRoute(
                originLat = live.lat,
                originLon = live.lon,
                destLat = dLat,
                destLon = dLon
            )
            directionsResult = result
        }
    }

    // Fused Location Client for "Locate Me"
    val fusedLocationClient = remember { LocationServices.getFusedLocationProviderClient(context) }
    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(collegeLatLng, 12.5f)
    }

    // Fit Bounds state
    var hasCentered by remember { mutableStateOf(false) }
    LaunchedEffect(animatedBusLatLng) {
        animatedBusLatLng?.let { busPoint ->
            if (!hasCentered) {
                try {
                    val dLat = trackedLive?.destinationLat ?: collegeLatLng.latitude
                    val dLon = trackedLive?.destinationLon ?: collegeLatLng.longitude
                    val targetLatLng = LatLng(dLat, dLon)
                    val bounds = LatLngBounds.builder()
                        .include(targetLatLng)
                        .include(busPoint)
                        .build()
                    cameraPositionState.animate(
                        CameraUpdateFactory.newLatLngBounds(bounds, 150),
                        1000
                    )
                    hasCentered = true
                } catch (e: Exception) {
                    cameraPositionState.animate(
                        CameraUpdateFactory.newLatLngZoom(busPoint, 14f),
                        1000
                    )
                    hasCentered = true
                }
            }
        }
    }

    val darkMapJson = """
    [
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#212121"
          }
        ]
      },
      {
        "elementType": "labels.icon",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#757575"
          }
        ]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [
          {
            "color": "#212121"
          }
        ]
      },
      {
        "featureType": "administrative",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#757575"
          }
        ]
      },
      {
        "featureType": "poi",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#181818"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry.fill",
        "stylers": [
          {
            "color": "#2c2c2c"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#000000"
          }
        ]
      }
    ]
    """.trimIndent()

    Scaffold { padding ->
        Box(
            modifier = Modifier
                .padding(if (isFullscreen) PaddingValues(0.dp) else padding)
                .fillMaxSize()
        ) {
            // Google Map Container
            GoogleMap(
                modifier = Modifier.fillMaxSize(),
                cameraPositionState = cameraPositionState,
                uiSettings = MapUiSettings(
                    zoomControlsEnabled = false,
                    compassEnabled = false,
                    myLocationButtonEnabled = false,
                    mapToolbarEnabled = false
                ),
                properties = MapProperties(
                    mapStyleOptions = if (isMapDarkMode) MapStyleOptions(darkMapJson) else null,
                    isMyLocationEnabled = true
                )
            ) {
                // College Campus Marker
                Marker(
                    state = rememberMarkerState(position = collegeLatLng),
                    title = "K. Ramakrishnan College of Engineering",
                    snippet = "Campus Main Gate",
                    icon = BitmapDescriptorFactory.fromBitmap(createCampusMarkerIcon(context))
                )

                // Bus Markers
                liveBuses.forEach { bus ->
                    bus.live?.let { live ->
                        val busPos = if (bus.id == selectedBusId && animatedBusLatLng != null) {
                            animatedBusLatLng!!
                        } else {
                            LatLng(live.lat, live.lon)
                        }

                        Marker(
                            state = rememberMarkerState(position = busPos),
                            title = "Bus ${bus.number}",
                            snippet = "Route: ${bus.routeName} | Speed: ${live.speed.toInt()} km/h",
                            icon = BitmapDescriptorFactory.fromBitmap(createBusMarkerIcon(context, bus.number, live.status != "offline")),
                            onClick = {
                                selectedBusId = bus.id
                                hasCentered = false // Refit bounds
                                true
                            }
                        )
                    }
                }

                // Bus Stop Markers for active route
                val activeBus = liveBuses.find { it.id == selectedBusId } ?: liveBuses.firstOrNull()
                val busStopBitmap = remember(context) { createBusStopMarkerIcon(context) }
                activeBus?.stops?.forEachIndexed { index, stopName ->
                    if (stopName != "KRCE Campus") {
                        val pos = stopCoordinates[stopName]
                        if (pos != null) {
                            val isDest = index == activeBus.stops.size - 1
                            Marker(
                                state = rememberMarkerState(position = pos),
                                title = if (isDest) "Destination: $stopName" else "Stop #${index + 1}: $stopName",
                                snippet = "Route: ${activeBus.routeName}",
                                icon = BitmapDescriptorFactory.fromBitmap(busStopBitmap)
                            )
                        }
                    }
                }

                // Route polyline
                directionsResult?.let { result ->
                    Polyline(
                        points = result.points,
                        color = Color(0xFF1F3E97),
                        width = 10f
                    )
                }
            }

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
                                    val userPoint = LatLng(location.latitude, location.longitude)
                                    coroutineScope.launch {
                                        cameraPositionState.animate(
                                            CameraUpdateFactory.newLatLngZoom(userPoint, 16f),
                                            1000
                                        )
                                    }
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

                // North Realignment Button (Bottom Corner)
                FloatingActionButton(
                    onClick = {
                        coroutineScope.launch {
                            val cur = cameraPositionState.position
                            cameraPositionState.animate(
                                CameraUpdateFactory.newCameraPosition(
                                    CameraPosition(cur.target, cur.zoom, 0f, 0f)
                                ),
                                800
                            )
                        }
                    },
                    containerColor = Color.White,
                    contentColor = IndigoPrimary,
                    shape = CircleShape,
                    modifier = Modifier.size(50.dp)
                ) {
                    Icon(Icons.Default.Explore, contentDescription = "Align North")
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
                    val points = ArrayList<LatLng>()
                    coordinates.forEach { elem ->
                        val coord = elem.asJsonArray
                        val lon = coord.get(0).asDouble
                        val lat = coord.get(1).asDouble
                        points.add(LatLng(lat, lon))
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

fun createCampusMarkerIcon(context: Context): android.graphics.Bitmap {
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
    
    return bitmap
}

fun createBusStopMarkerIcon(context: Context): android.graphics.Bitmap {
    val width = 72
    val height = 100
    val bitmap = android.graphics.Bitmap.createBitmap(width, height, android.graphics.Bitmap.Config.ARGB_8888)
    val canvas = android.graphics.Canvas(bitmap)
    val paint = android.graphics.Paint().apply { isAntiAlias = true }

    // Drop shadow
    paint.color = android.graphics.Color.parseColor("#44000000")
    val shadowPath = android.graphics.Path().apply {
        moveTo(width / 2f, height - 2f)
        cubicTo(width / 2f - 4f, height - 8f, 2f, height * 0.55f, 2f, width / 2f + 4f)
        arcTo(android.graphics.RectF(2f, 4f, width - 2f, width + 4f), 180f, 180f, false)
        cubicTo(width - 2f, height * 0.55f, width / 2f + 4f, height - 8f, width / 2f, height - 2f)
        close()
    }
    canvas.drawPath(shadowPath, paint)

    // Pin body (Black)
    val pinPath = android.graphics.Path().apply {
        moveTo(width / 2f, height - 6f)
        cubicTo(width / 2f - 4f, height - 12f, 4f, height * 0.55f, 4f, width / 2f)
        arcTo(android.graphics.RectF(4f, 2f, width - 4f, width - 2f), 180f, 180f, false)
        cubicTo(width - 4f, height * 0.55f, width / 2f + 4f, height - 12f, width / 2f, height - 6f)
        close()
    }
    paint.color = android.graphics.Color.parseColor("#111827")
    paint.style = android.graphics.Paint.Style.FILL
    canvas.drawPath(pinPath, paint)

    // White outline
    paint.color = android.graphics.Color.WHITE
    paint.style = android.graphics.Paint.Style.STROKE
    paint.strokeWidth = 3f
    canvas.drawPath(pinPath, paint)

    // Inner white circle
    paint.style = android.graphics.Paint.Style.FILL
    paint.color = android.graphics.Color.WHITE
    canvas.drawCircle(width / 2f, width / 2f, 24f, paint)

    // Bus body inside (Black)
    paint.color = android.graphics.Color.parseColor("#111827")
    val busRect = android.graphics.RectF(width / 2f - 14f, width / 2f - 18f, width / 2f + 14f, width / 2f + 14f)
    canvas.drawRoundRect(busRect, 6f, 6f, paint)

    // Top signboard (White)
    paint.color = android.graphics.Color.WHITE
    canvas.drawRoundRect(android.graphics.RectF(width / 2f - 8f, width / 2f - 16f, width / 2f + 8f, width / 2f - 13f), 2f, 2f, paint)

    // Windshield (White)
    canvas.drawRoundRect(android.graphics.RectF(width / 2f - 11f, width / 2f - 11f, width / 2f + 11f, width / 2f + 2f), 3f, 3f, paint)

    // Headlights (White)
    canvas.drawRect(width / 2f - 11f, width / 2f + 6f, width / 2f - 5f, width / 2f + 9f, paint)
    canvas.drawRect(width / 2f + 5f, width / 2f + 6f, width / 2f + 11f, width / 2f + 9f, paint)

    // License plate (White)
    canvas.drawRect(width / 2f - 3f, width / 2f + 10f, width / 2f + 3f, width / 2f + 12f, paint)

    // Side mirrors (Black)
    paint.color = android.graphics.Color.parseColor("#111827")
    canvas.drawRect(width / 2f - 17f, width / 2f - 9f, width / 2f - 14f, width / 2f - 3f, paint)
    canvas.drawRect(width / 2f + 14f, width / 2f - 9f, width / 2f + 17f, width / 2f - 3f, paint)

    // Wheels (Black)
    canvas.drawRect(width / 2f - 12f, width / 2f + 14f, width / 2f - 7f, width / 2f + 17f, paint)
    canvas.drawRect(width / 2f + 7f, width / 2f + 14f, width / 2f + 12f, width / 2f + 17f, paint)

    return bitmap
}

fun createBusMarkerIcon(context: Context, busNumber: String, isOnline: Boolean): android.graphics.Bitmap {
    val width = 140
    val height = 100
    val bitmap = android.graphics.Bitmap.createBitmap(width, height, android.graphics.Bitmap.Config.ARGB_8888)
    val canvas = android.graphics.Canvas(bitmap)
    val paint = android.graphics.Paint().apply { isAntiAlias = true }

    val cx = width / 2f
    val cy = 38f
    val radius = 30f
    val bodyColor = if (isOnline) "#10B981" else "#64748B"

    // Drop Shadow
    paint.style = android.graphics.Paint.Style.FILL
    paint.color = android.graphics.Color.parseColor("#44000000")
    canvas.drawCircle(cx, cy + 3f, radius + 2f, paint)

    // White disc background
    paint.color = android.graphics.Color.WHITE
    canvas.drawCircle(cx, cy, radius, paint)

    // Colored / dark status ring
    paint.style = android.graphics.Paint.Style.STROKE
    paint.strokeWidth = 3.5f
    paint.color = android.graphics.Color.parseColor(bodyColor)
    canvas.drawCircle(cx, cy, radius - 1.75f, paint)

    // Heading pointer triangle at top
    val triPath = android.graphics.Path().apply {
        moveTo(cx - 6f, cy - radius - 1f)
        lineTo(cx + 6f, cy - radius - 1f)
        lineTo(cx, cy - radius - 8f)
        close()
    }
    paint.style = android.graphics.Paint.Style.FILL
    paint.color = android.graphics.Color.parseColor(bodyColor)
    canvas.drawPath(triPath, paint)

    // Bus Silhouette — Dark body (#111827)
    paint.color = android.graphics.Color.parseColor("#111827")

    // Left and right rear-view mirrors
    canvas.drawRoundRect(cx - 24f, cy - 8f, cx - 20f, cy + 1.5f, 2f, 2f, paint)
    canvas.drawRoundRect(cx + 20f, cy - 8f, cx + 24f, cy + 1.5f, 2f, 2f, paint)

    // Wheels
    canvas.drawRoundRect(cx - 15f, cy + 13f, cx - 8f, cy + 20f, 2f, 2f, paint)
    canvas.drawRoundRect(cx + 8f, cy + 13f, cx + 15f, cy + 20f, 2f, 2f, paint)

    // Bus Body
    canvas.drawRoundRect(cx - 18f, cy - 19f, cx + 18f, cy + 13f, 10f, 10f, paint)

    // Route Destination Box (White)
    paint.color = android.graphics.Color.WHITE
    canvas.drawRoundRect(cx - 7.5f, cy - 16f, cx + 7.5f, cy - 12f, 2f, 2f, paint)

    // Front Windshield (White)
    canvas.drawRoundRect(cx - 14f, cy - 10f, cx + 14f, cy + 3.5f, 3.5f, 3.5f, paint)

    // Headlights (White circles)
    canvas.drawCircle(cx - 10f, cy + 8f, 2.8f, paint)
    canvas.drawCircle(cx + 10f, cy + 8f, 2.8f, paint)

    // Bus Number Pill Badge at bottom
    val label = if (busNumber.contains("-")) busNumber.split("-").last() else busNumber
    paint.textSize = 20f
    paint.typeface = android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD)
    val textWidth = paint.measureText(label)
    val pillW = (textWidth + 24f).coerceIn(36f, 76f)
    val pillH = 22f
    val pillTop = cy + radius - 6f

    // Pill background (#0F172A)
    paint.color = android.graphics.Color.parseColor("#0F172A")
    paint.style = android.graphics.Paint.Style.FILL
    canvas.drawRoundRect(cx - pillW / 2f, pillTop, cx + pillW / 2f, pillTop + pillH, 11f, 11f, paint)

    // Pill border (White)
    paint.color = android.graphics.Color.WHITE
    paint.style = android.graphics.Paint.Style.STROKE
    paint.strokeWidth = 1.8f
    canvas.drawRoundRect(cx - pillW / 2f, pillTop, cx + pillW / 2f, pillTop + pillH, 11f, 11f, paint)

    // Pill text
    paint.style = android.graphics.Paint.Style.FILL
    paint.textAlign = android.graphics.Paint.Align.CENTER
    val textY = pillTop + pillH / 2f - ((paint.descent() + paint.ascent()) / 2f)
    canvas.drawText(label, cx, textY, paint)

    return bitmap
}
