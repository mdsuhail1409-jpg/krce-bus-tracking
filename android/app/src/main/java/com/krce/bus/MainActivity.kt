package com.krce.bus

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.navigation.NavController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
// Removed unused Google Maps imports
import com.krce.bus.api.ApiService
import com.krce.bus.models.*
import com.krce.bus.ui.components.*
import com.krce.bus.ui.theme.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

class MainActivity : ComponentActivity() {

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        permissions.entries.forEach { (perm, granted) ->
            android.util.Log.d("Permissions", "$perm granted=$granted")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        requestRequiredPermissions()
        setContent {
            BusTheme {
                BusApp()
            }
        }
    }

    private fun requestRequiredPermissions() {
        val needed = mutableListOf<String>()
        val locationPerms = listOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )
        locationPerms.forEach { perm ->
            if (ContextCompat.checkSelfPermission(this, perm) != PackageManager.PERMISSION_GRANTED) {
                needed.add(perm)
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                needed.add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
        if (needed.isNotEmpty()) {
            permissionLauncher.launch(needed.toTypedArray())
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_BACKGROUND_LOCATION)
                != PackageManager.PERMISSION_GRANTED
            ) {
                permissionLauncher.launch(arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION))
            }
        }
    }
}

@Composable
fun BusApp() {
    val navController = rememberNavController()
    val authViewModel: AuthViewModel = viewModel()
    val authToken = authViewModel.authToken
    val userRole = authViewModel.userRole
    val userName = authViewModel.userName
    val userBusId = authViewModel.userBusId

    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    LaunchedEffect(authViewModel.authToken) {
        if (authViewModel.authToken.isEmpty()) {
            navController.navigate("login") {
                popUpTo(0) { inclusive = true }
            }
        }
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

        // Bus windows — two small white rounded rects
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

    val startDestination = if (authToken.isEmpty()) "login" else {
        when (userRole) {
            "admin", "committee" -> "admin_dashboard"
            "driver" -> "driver_dashboard"
            "parent" -> "parent_dashboard"
            else -> "student_dashboard"
        }
    }

    Scaffold(
        bottomBar = {
            if (currentRoute != "login" && currentRoute != null) {
                BottomNavigationBar(navController, userRole)
            }
        }
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = startDestination,
            modifier = Modifier.padding(innerPadding)
        ) {
            composable("login") {
                LoginScreen(authViewModel) { role ->
                    val dest = when (role) {
                        "admin", "committee" -> "admin_dashboard"
                        "driver" -> "driver_dashboard"
                        "parent" -> "parent_dashboard"
                        else -> "student_dashboard"
                    }
                    navController.navigate(dest) {
                        popUpTo("login") { inclusive = true }
                    }
                }
            }
            composable("admin_dashboard") { AdminDashboard(navController, authToken) }
            composable("student_dashboard") { StudentDashboard(navController, authToken, userName, userBusId) }
            composable("parent_dashboard") { ParentDashboard(navController, authToken, userName, authViewModel.parentOf) }
            composable("driver_dashboard") { DriverDashboard(authToken, userBusId) }
            composable("map") { com.krce.bus.ui.screens.LiveMapScreen(authToken, userBusId) }
            composable("history") { HistoryScreen(authToken, userRole) }
            composable("profile") { ProfileScreen(authViewModel) }
            composable("users_screen") { UsersScreen(navController, authToken) }
        }
    }
}

@Composable
fun BottomNavigationBar(navController: NavController, userRole: String) {
    NavigationBar(
        containerColor = SurfaceColor,
        modifier = Modifier.shadow(elevation = 8.dp, shape = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp)),
        tonalElevation = 0.dp
    ) {
        val navBackStackEntry by navController.currentBackStackEntryAsState()
        val currentRoute = navBackStackEntry?.destination?.route

        val items = when (userRole) {
            "parent" -> listOf(
                Triple("home", Icons.Default.Home, "Home"),
                Triple("alerts", Icons.Default.Notifications, "Alerts"),
                Triple("more", Icons.Default.MoreHoriz, "More")
            )
            "student" -> listOf(
                Triple("home", Icons.Default.Home, "Home"),
                Triple("routes", Icons.Default.AltRoute, "Routes"),
                Triple("more", Icons.Default.MoreHoriz, "More")
            )
            else -> listOf(
                Triple("home", Icons.Default.Home, "Home"),
                Triple("map", Icons.Default.LocationOn, "Map"),
                Triple("history", Icons.Default.List, "History"),
                Triple("profile", Icons.Default.Person, "Profile")
            )
        }

        items.forEach { (route, icon, label) ->
            val isSelected = currentRoute?.contains(route) == true || (route == "home" && currentRoute?.contains("dashboard") == true)
            NavigationBarItem(
                icon = { Icon(icon, contentDescription = label) },
                label = { Text(label, style = Typography.labelSmall.copy(fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal)) },
                selected = isSelected,
                colors = NavigationBarItemDefaults.colors(
                    selectedIconColor = IndigoPrimary,
                    selectedTextColor = IndigoPrimary,
                    unselectedIconColor = MutedText,
                    unselectedTextColor = MutedText,
                    indicatorColor = Color.Transparent
                ),
                onClick = {
                    if (route == "home") {
                        val dashboardRoute = when (userRole) {
                            "admin", "committee" -> "admin_dashboard"
                            "driver" -> "driver_dashboard"
                            "parent" -> "parent_dashboard"
                            else -> "student_dashboard"
                        }
                        navController.navigate(dashboardRoute) {
                            popUpTo(navController.graph.startDestinationId) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    } else {
                        val target = if (route == "more" || route == "routes" || route == "alerts") "profile" else route
                        navController.navigate(target) {
                            popUpTo(navController.graph.startDestinationId) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    }
                }
            )
        }
    }
}

@Composable
fun LoginScreen(authViewModel: AuthViewModel, onLoginSuccess: (String) -> Unit) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()
    val apiService = remember { ApiService.create() }

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

    val collegeLatLng = com.google.android.gms.maps.model.LatLng(10.927669, 78.7410)
    val cameraPositionState = com.google.maps.android.compose.rememberCameraPositionState {
        position = com.google.android.gms.maps.model.CameraPosition.fromLatLngZoom(collegeLatLng, 15f)
    }

    Box(modifier = Modifier.fillMaxSize()) {
        com.google.maps.android.compose.GoogleMap(
            modifier = Modifier.fillMaxSize(),
            cameraPositionState = cameraPositionState,
            uiSettings = com.google.maps.android.compose.MapUiSettings(
                zoomControlsEnabled = false,
                compassEnabled = false,
                myLocationButtonEnabled = false,
                mapToolbarEnabled = false
            ),
            properties = com.google.maps.android.compose.MapProperties(
                mapStyleOptions = com.google.android.gms.maps.model.MapStyleOptions(darkMapJson)
            )
        )

        // Translucent overlay to dim the map for readability of login form
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.5f))
        )
        
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(24.dp)
                .statusBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                text = "KRCE BusTrack",
                style = Typography.headlineLarge,
                color = Color.White,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "K. Ramakrishnan College of Engineering",
                style = Typography.bodyMedium,
                color = Color.White.copy(alpha = 0.7f)
            )
            Spacer(modifier = Modifier.height(40.dp))

            GlassCard {
                Text("Sign In", style = Typography.headlineSmall, fontWeight = FontWeight.Bold, color = TextColor)
                Spacer(modifier = Modifier.height(2.dp))
                Text("Track your campus journey", style = Typography.bodySmall, color = MutedText)
                Spacer(modifier = Modifier.height(28.dp))

                OutlinedTextField(
                    value = email,
                    onValueChange = { email = it },
                    label = { Text("Email Address") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = IndigoPrimary,
                        focusedLabelColor = IndigoPrimary,
                        unfocusedBorderColor = BorderColor,
                        unfocusedLabelColor = MutedText
                    ),
                    singleLine = true
                )
                Spacer(modifier = Modifier.height(16.dp))
                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it },
                    label = { Text("Password") },
                    visualTransformation = PasswordVisualTransformation(),
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = IndigoPrimary,
                        focusedLabelColor = IndigoPrimary,
                        unfocusedBorderColor = BorderColor,
                        unfocusedLabelColor = MutedText
                    ),
                    singleLine = true
                )
                
                if (errorMessage.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(errorMessage, color = ErrorRed, style = Typography.bodyMedium, fontWeight = FontWeight.Medium)
                }

                Spacer(modifier = Modifier.height(32.dp))
                PremiumButton(
                    text = "Sign In",
                    onClick = {
                        if (email.isBlank() || password.isBlank()) {
                            errorMessage = "Enter credentials to continue"
                            return@PremiumButton
                        }
                        isLoading = true
                        coroutineScope.launch {
                            try {
                                val res = apiService.login(LoginReq(email.trim(), password.trim()))
                                authViewModel.setAuthState(
                                    "Bearer ${res.token}", res.role, res.name, res.busId, false,
                                    res.collegeId, res.parentOf, res.phone
                                )
                                onLoginSuccess(res.role)
                            } catch (e: Exception) {
                                val trimmedEmail = email.trim()
                                val trimmedPassword = password.trim()
                                if (trimmedEmail == "admin@krce.ac.in" && trimmedPassword == "admin") {
                                    authViewModel.setAuthState("demo_token_admin", "admin", "Admin (Demo)", null, true, null, null, "9840100001")
                                    onLoginSuccess("admin")
                                } else if (trimmedEmail == "driver@krce.ac.in" && trimmedPassword == "driver") {
                                    authViewModel.setAuthState("demo_token_driver", "driver", "Driver (Demo)", "B01", true, null, null, "9840111111")
                                    onLoginSuccess("driver")
                                } else if (trimmedEmail == "student@krce.ac.in" && trimmedPassword == "student") {
                                    authViewModel.setAuthState("demo_token_student", "student", "Student (Demo)", "B01", true, "21CS001", null, "9841100001")
                                    onLoginSuccess("student")
                                } else if (trimmedEmail == "parent@krce.ac.in" && trimmedPassword == "parent") {
                                    authViewModel.setAuthState("demo_token_parent", "parent", "Parent (Demo)", null, true, null, "21CS001", "9841300001")
                                    onLoginSuccess("parent")
                                } else if (trimmedEmail == "demo@krce.ac.in" && trimmedPassword == "demo@krce") {
                                    authViewModel.setAuthState("demo_token", "admin", "Admin (Demo)", null, true)
                                    onLoginSuccess("admin")
                                } else if (trimmedEmail == "admin@krce.ac.in" && trimmedPassword == "admin@krce") {
                                    authViewModel.setAuthState("demo_token_admin", "admin", "Admin Krishnamurthy (Demo)", null, true, null, null, "9840100001")
                                    onLoginSuccess("admin")
                                } else if (trimmedEmail == "rajan@krce.ac.in" && trimmedPassword == "driver@123") {
                                    authViewModel.setAuthState("demo_token_driver", "driver", "Rajan S. (Demo)", "B01", true, null, null, "9840111111")
                                    onLoginSuccess("driver")
                                } else if (trimmedEmail == "aravind@krce.ac.in" && trimmedPassword == "student@123") {
                                    authViewModel.setAuthState("demo_token_student", "student", "Aravind Kumar (Demo)", "B01", true, "21CS001", null, "9841100001")
                                    onLoginSuccess("student")
                                } else if (trimmedEmail == "suresh.p@gmail.com" && trimmedPassword == "parent@123") {
                                    authViewModel.setAuthState("demo_token_parent", "parent", "Suresh Kumar (Demo)", null, true, null, "21CS001", "9841300001")
                                    onLoginSuccess("parent")
                                } else {
                                    errorMessage = "Invalid credentials or server unreachable"
                                }
                            } finally {
                                isLoading = false
                            }
                        }
                    },
                    isLoading = isLoading
                )
            }

            // Quick-Fill panel
            var showCredentials by remember { mutableStateOf(false) }
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp)
                    .border(1.dp, BorderColor, RoundedCornerShape(16.dp)),
                colors = CardDefaults.cardColors(containerColor = SurfaceColor.copy(alpha = 0.9f)),
                shape = RoundedCornerShape(16.dp)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { showCredentials = !showCredentials },
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "💡 Demo Credentials (Quick-Fill)",
                            style = Typography.titleSmall,
                            fontWeight = FontWeight.Bold,
                            color = TextColor
                        )
                        Icon(
                            imageVector = if (showCredentials) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                            contentDescription = null,
                            tint = MutedText
                        )
                    }
                    if (showCredentials) {
                        Spacer(modifier = Modifier.height(12.dp))
                        
                        val credentials = listOf(
                            Triple("Admin", "admin@krce.ac.in", "admin@krce"),
                            Triple("Driver", "rajan@krce.ac.in", "driver@123"),
                            Triple("Student", "aravind@krce.ac.in", "student@123"),
                            Triple("Parent", "suresh.p@gmail.com", "parent@123"),
                            Triple("Admin (Offline)", "admin@krce.ac.in", "admin"),
                            Triple("Driver (Offline)", "driver@krce.ac.in", "driver"),
                            Triple("Student (Offline)", "student@krce.ac.in", "student"),
                            Triple("Parent (Offline)", "parent@krce.ac.in", "parent")
                        )
                        
                        credentials.forEachIndexed { idx, (label, u, p) ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        email = u
                                        password = p
                                    }
                                    .padding(vertical = 8.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column {
                                    Text(label, style = Typography.bodyMedium, fontWeight = FontWeight.Bold, color = IndigoPrimary)
                                    Text("Email: $u", style = Typography.bodySmall, color = TextColor)
                                    Text("Password: $p", style = Typography.bodySmall, color = MutedText)
                                }
                                Text("Fill", style = Typography.labelSmall, color = IndigoPrimary, fontWeight = FontWeight.Bold)
                            }
                            if (idx < credentials.size - 1) {
                                Divider(color = BorderColor.copy(alpha = 0.5f), thickness = 0.5.dp)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun AdminDashboard(navController: NavController, token: String) {
    var stats by remember { mutableStateOf<AdminStats?>(null) }
    var recentAttendance by remember { mutableStateOf<List<Attendance>>(emptyList()) }
    var registrations by remember { mutableStateOf<List<com.krce.bus.models.Registration>>(emptyList()) }
    var allBuses by remember { mutableStateOf<List<Bus>>(emptyList()) }
    var errorMessage by remember { mutableStateOf("") }
    var showAlertDialog by remember { mutableStateOf(false) }
    val apiService = remember { ApiService.create() }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        while(true) {
            try {
                stats = apiService.getAdminStats(token)
                recentAttendance = apiService.getAllAttendance(token)
                registrations = apiService.getRegistrations(token).filter { it.status == "pending" }
                allBuses = apiService.getBuses(token)
            } catch (e: Exception) {
                if (token == "demo_token" || token.startsWith("demo_token_admin")) {
                    stats = AdminStats(10, 5, 1, 0, 5, 3, 2)
                    registrations = listOf(
                        com.krce.bus.models.Registration(
                            id = "reg1",
                            requestDate = "2026-07-14",
                            applicantName = "Aravind Kumar",
                            email = "aravind@krce.ac.in",
                            phone = "9841100001",
                            requestedRole = "student",
                            collegeId = "21CS001",
                            status = "pending"
                        )
                    )
                } else {
                    errorMessage = "Failed to load data"
                }
            }
            delay(10000)
        }
    }

    if (showAlertDialog) {
        SendAlertDialog(token = token, buses = allBuses, onDismiss = { showAlertDialog = false })
    }

    Box(modifier = Modifier.fillMaxSize().background(BackgroundColor)) {
        DashboardHeader(
            title = "Hey Admin!",
            subtitle = "Here's the current system overview.",
            role = "admin"
        )

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(top = 190.dp, bottom = 24.dp)
        ) {
            item {
                Column(modifier = Modifier.padding(horizontal = 24.dp)) {
                    if (errorMessage.isNotEmpty()) {
                        Text(errorMessage, color = ErrorRed, style = Typography.bodyMedium, fontWeight = FontWeight.Bold)
                        Spacer(modifier = Modifier.height(16.dp))
                    }
                    
                    GlassCard {
                        Text("System Vital Statistics", style = Typography.titleMedium, fontWeight = FontWeight.Bold, color = TextColor)
                        Spacer(modifier = Modifier.height(20.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(stats?.totalStudents?.toString() ?: "—", style = Typography.headlineMedium, color = TextColor, fontWeight = FontWeight.ExtraBold)
                                Spacer(modifier = Modifier.height(2.dp))
                                Text("Total Students", style = Typography.bodySmall, color = MutedText)
                            }
                            Box(modifier = Modifier.width(1.dp).height(44.dp).background(BorderColor))
                            Spacer(modifier = Modifier.width(20.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(stats?.activeBuses?.toString() ?: "—", style = Typography.headlineMedium, color = TextColor, fontWeight = FontWeight.ExtraBold)
                                Spacer(modifier = Modifier.height(2.dp))
                                Text("Active Buses", style = Typography.bodySmall, color = MutedText)
                            }
                        }
                        Spacer(modifier = Modifier.height(20.dp))
                        Divider(color = BorderColor, thickness = 0.5.dp)
                        Spacer(modifier = Modifier.height(20.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(stats?.boardedToday?.toString() ?: "—", style = Typography.headlineMedium, color = SuccessGreen, fontWeight = FontWeight.ExtraBold)
                                Spacer(modifier = Modifier.height(2.dp))
                                Text("Boarded Today", style = Typography.bodySmall, color = MutedText)
                            }
                            Box(modifier = Modifier.width(1.dp).height(44.dp).background(BorderColor))
                            Spacer(modifier = Modifier.width(20.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(stats?.activeAlerts?.toString() ?: "—", style = Typography.headlineMedium, color = ErrorRed, fontWeight = FontWeight.ExtraBold)
                                Spacer(modifier = Modifier.height(2.dp))
                                Text("Active Alerts", style = Typography.bodySmall, color = MutedText)
                            }
                        }
                    }

                    // ── Admin Actions ────────────────────────────────────────
                    Spacer(modifier = Modifier.height(24.dp))
                    Text("Admin Tools", style = Typography.titleMedium, fontWeight = FontWeight.Bold, color = TextColor)
                    Spacer(modifier = Modifier.height(12.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Button(
                            onClick = { navController.navigate("users_screen") },
                            modifier = Modifier.weight(1f),
                            shape = RoundedCornerShape(14.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = IndigoPrimary),
                            contentPadding = PaddingValues(12.dp)
                        ) {
                            Icon(Icons.Default.Person, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Manage Users", style = Typography.labelMedium, fontWeight = FontWeight.Bold)
                        }
                        Button(
                            onClick = { showAlertDialog = true },
                            modifier = Modifier.weight(1f),
                            shape = RoundedCornerShape(14.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFD97706)),
                            contentPadding = PaddingValues(12.dp)
                        ) {
                            Icon(Icons.Default.Warning, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Send Alert", style = Typography.labelMedium, fontWeight = FontWeight.Bold)
                        }
                    }

                    // ── Pending Registrations Approvals ──────────────────────
                    if (registrations.isNotEmpty()) {
                        Spacer(modifier = Modifier.height(28.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("Pending Approvals", style = Typography.titleLarge, fontWeight = FontWeight.Bold, color = TextColor)
                            Box(
                                modifier = Modifier
                                    .background(ErrorRed.copy(alpha = 0.15f), RoundedCornerShape(8.dp))
                                    .padding(horizontal = 10.dp, vertical = 4.dp)
                            ) {
                                Text("${registrations.size} Pending", style = Typography.labelSmall, color = ErrorRed, fontWeight = FontWeight.Bold)
                            }
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                    }
                }
            }

            items(registrations.size) { index ->
                val reg = registrations[index]
                var dismissed by remember { mutableStateOf(false) }
                if (!dismissed) {
                    Box(modifier = Modifier.padding(horizontal = 24.dp, vertical = 6.dp)) {
                        RegistrationApprovalCard(
                            registration = reg,
                            onApprove = {
                                scope.launch {
                                    try {
                                        apiService.approveRegistration(token, reg.id)
                                        dismissed = true
                                    } catch (e: Exception) {}
                                }
                            },
                            onReject = {
                                scope.launch {
                                    try {
                                        apiService.rejectRegistration(token, reg.id)
                                        dismissed = true
                                    } catch (e: Exception) {}
                                }
                            }
                        )
                    }
                }
            }

            item {
                Column(modifier = Modifier.padding(horizontal = 24.dp)) {
                    Spacer(modifier = Modifier.height(32.dp))
                    Text("Recent Activity", style = Typography.titleLarge, fontWeight = FontWeight.Bold, color = TextColor)
                    Spacer(modifier = Modifier.height(16.dp))
                }
            }
            items(recentAttendance.size) { index ->
                Box(modifier = Modifier.padding(horizontal = 24.dp, vertical = 6.dp)) {
                    AttendanceItem(recentAttendance[index])
                }
            }
        }
    }
}

@Composable
fun StudentDashboard(navController: NavController, token: String, name: String, userBusId: String?) {
    var attendanceHistory by remember { mutableStateOf<List<Attendance>>(emptyList()) }
    var busDetails by remember { mutableStateOf<Bus?>(null) }
    var eta by remember { mutableStateOf<String?>(null) }
    var nextStop by remember { mutableStateOf<String?>(null) }
    val apiService = remember { ApiService.create() }

    val displayName = remember(name) {
        if (name.contains(" ")) name.split(" ")[0] else name
    }

    LaunchedEffect(Unit) {
        while(true) {
            try {
                attendanceHistory = apiService.getMyAttendance(token)
                if (userBusId != null) {
                    busDetails = apiService.getBusDetails(token, userBusId)
                    val etaRes = apiService.getMyEta(token)
                    eta = etaRes.eta
                    nextStop = etaRes.nextStop
                }
            } catch (e: Exception) {
                if (token == "demo_token" || token == "demo_token_student") {
                    busDetails = Bus("B01", "TN-01", "Woraiyur", "drv01", 50, listOf("Woraiyur", "Samayapuram"))
                    eta = "12 min"
                }
            }
            delay(10000)
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(BackgroundColor)) {
        DashboardHeader(
            title = "Welcome,\n$displayName!",
            subtitle = "Student Dashboard",
            role = "student"
        )
        
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(top = 190.dp, bottom = 24.dp)
        ) {
            item {
                Column(modifier = Modifier.padding(horizontal = 24.dp)) {
                    GlassCard {
                        InfoItem(Icons.Default.DirectionsBus, "My Bus", busDetails?.number ?: "B01")
                        Divider(color = BorderColor, thickness = 0.5.dp)
                        InfoItem(Icons.Default.LocationOn, "Route", busDetails?.routeName ?: "Woraiyur")
                        Divider(color = BorderColor, thickness = 0.5.dp)
                        InfoItem(Icons.Default.AccessTime, "Estimated Arrival", eta ?: "12 min", showEta = true, etaValue = eta ?: "12 min")
                        
                        Spacer(modifier = Modifier.height(20.dp))
                        ActionButton("View Live Map", Icons.Default.Map) {
                            navController.navigate("map")
                        }
                    }
                    
                    Spacer(modifier = Modifier.height(32.dp))
                    Text("Quick Actions", style = Typography.titleMedium, fontWeight = FontWeight.Bold, color = TextColor)
                    Spacer(modifier = Modifier.height(16.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        QuickActionItem(Icons.Default.DirectionsBus, "My Bus")
                        QuickActionItem(Icons.Default.Notifications, "Notifications")
                        QuickActionItem(Icons.Default.EventNote, "Timetable")
                        QuickActionItem(Icons.Default.Person, "Profile") { navController.navigate("profile") }
                    }
                    
                    Spacer(modifier = Modifier.height(32.dp))
                    AnnouncementCard(
                        message = "College day on May 30. Buses will operate as per special schedule."
                    )
                }
            }
        }
    }
}

@Composable
fun ParentDashboard(navController: NavController, token: String, name: String, childId: String?) {
    var childAttendance by remember { mutableStateOf<List<Attendance>>(emptyList()) }
    var childBusId by remember { mutableStateOf<String?>(null) }
    var eta by remember { mutableStateOf<String?>(null) }
    val apiService = remember { ApiService.create() }

    LaunchedEffect(Unit) {
        while(true) {
            try {
                val records = apiService.getChildAttendance(token)
                childAttendance = records
                if (records.isNotEmpty()) {
                    childBusId = records[0].busId
                    eta = "15 min"
                }
            } catch (e: Exception) {
                if (token == "demo_token") {
                    childBusId = "B01"
                    eta = "15 min"
                }
            }
            delay(10000)
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(BackgroundColor)) {
        DashboardHeader(
            title = "Hello, Parent!",
            subtitle = "Parent Dashboard",
            role = "parent"
        )
        
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(top = 190.dp, bottom = 24.dp)
        ) {
            item {
                Column(modifier = Modifier.padding(horizontal = 24.dp)) {
                    // Your Child Card
                    GlassCard {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("Your Child", style = Typography.titleSmall, fontWeight = FontWeight.Bold, color = TextColor)
                            TextButton(onClick = { navController.navigate("profile") }) {
                                Text("View Profile", style = Typography.labelSmall.copy(fontSize = 12.sp), color = IndigoPrimary, fontWeight = FontWeight.Bold)
                            }
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(56.dp)
                                    .background(BusBadgeBg, CircleShape),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Default.Person, contentDescription = null, tint = BusBadgeIcon, modifier = Modifier.size(32.dp))
                            }
                            Spacer(modifier = Modifier.width(16.dp))
                            Column {
                                Text("Aravind", style = Typography.titleMedium, fontWeight = FontWeight.Bold, color = TextColor)
                                Spacer(modifier = Modifier.height(2.dp))
                                Text("II Year - CSE", style = Typography.bodySmall, color = MutedText)
                            }
                        }
                    }
                    
                    Spacer(modifier = Modifier.height(24.dp))
                    
                    // Bus Status Card
                    GlassCard {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("Bus Status", style = Typography.titleSmall, fontWeight = FontWeight.Bold, color = TextColor)
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier
                                    .background(SuccessBg, RoundedCornerShape(8.dp))
                                    .padding(horizontal = 8.dp, vertical = 4.dp)
                            ) {
                                Icon(Icons.Default.CheckCircle, contentDescription = null, tint = SuccessGreen, modifier = Modifier.size(12.dp))
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("Live Tracking", style = Typography.labelSmall.copy(fontSize = 10.sp), color = SuccessGreen, fontWeight = FontWeight.Bold)
                            }
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                        InfoItem(Icons.Default.DirectionsBus, "Bus ID", childBusId ?: "B01")
                        Divider(color = BorderColor, thickness = 0.5.dp)
                        InfoItem(Icons.Default.AccessTime, "Estimated Arrival", eta ?: "15 min", showEta = true, etaValue = eta ?: "15 min")
                        
                        Spacer(modifier = Modifier.height(20.dp))
                        ActionButton("Track Child's Bus", Icons.Default.LocationOn) {
                            navController.navigate("map")
                        }
                    }
                    
                    Spacer(modifier = Modifier.height(24.dp))
                    
                    // Safe & Secure Banner
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .shadow(elevation = 1.dp, shape = RoundedCornerShape(20.dp))
                            .border(1.dp, BorderColor, RoundedCornerShape(20.dp)),
                        colors = CardDefaults.cardColors(containerColor = SurfaceColor),
                        shape = RoundedCornerShape(20.dp)
                    ) {
                        Row(modifier = Modifier.padding(20.dp), verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(44.dp)
                                    .background(BusBadgeBg, RoundedCornerShape(12.dp)),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Default.Security, contentDescription = null, tint = BusBadgeIcon)
                            }
                            Spacer(modifier = Modifier.width(16.dp))
                            Column {
                                Text("Safe & Secure", style = Typography.titleSmall, fontWeight = FontWeight.Bold, color = TextColor)
                                Spacer(modifier = Modifier.height(2.dp))
                                Text("We ensure your child's safety with real-time tracking and alerts.", style = Typography.bodySmall, color = MutedText)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun DriverDashboard(token: String, busId: String?) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val prefs = remember { context.getSharedPreferences("krce_prefs", android.content.Context.MODE_PRIVATE) }
    var isTracking by remember { mutableStateOf(prefs.getBoolean("gps_tracking", false)) }
    var passengers by remember { mutableStateOf<List<Passenger>>(emptyList()) }
    val apiService = remember { ApiService.create() }

    // Auto-restart service if tracking was ON before the screen recomposed
    LaunchedEffect(Unit) {
        if (isTracking && busId != null) {
            val intent = android.content.Intent(context, com.krce.bus.service.GpsForegroundService::class.java).apply {
                putExtra("EXTRA_TOKEN", token)
                putExtra("EXTRA_BUS_ID", busId)
            }
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O)
                context.startForegroundService(intent)
            else
                context.startService(intent)
        }
    }

    LaunchedEffect(isTracking) {
        if (isTracking && busId != null) {
            while(true) {
                try { passengers = apiService.getBusPassengers(token, busId) } catch (e: Exception) {}
                delay(10000)
            }
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(BackgroundColor)) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(bottom = 24.dp)
        ) {
            item {
                WelcomeBanner(
                    title = "Driver Mode",
                    subtitle = "Broadcasting your bus location.",
                    gradient = GradientWarning,
                    modifier = Modifier.padding(16.dp)
                )
                Spacer(Modifier.height(8.dp))
            }
            item {
                Column(modifier = Modifier.padding(horizontal = 24.dp)) {
                    Row(Modifier.fillMaxWidth()) {
                        StatCard(value = passengers.size.toString(), label = "Onboard", modifier = Modifier.weight(1f), valueColor = SuccessGreen)
                        Spacer(Modifier.width(16.dp))
                        StatCard(value = busId ?: "—", label = "Bus ID", modifier = Modifier.weight(1f))
                    }
                    Spacer(Modifier.height(24.dp))
                    
                    GlassCard {
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text("GPS Broadcasting", style = Typography.titleLarge, fontWeight = FontWeight.Bold, color = TextColor)
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(if (isTracking) "Live: Background service active" else "Status: Inactive", style = Typography.bodyMedium, color = MutedText)
                            }
                            Switch(
                                checked = isTracking,
                                onCheckedChange = { checked ->
                                    isTracking = checked
                                    // Persist state so it survives recompositions
                                    prefs.edit().putBoolean("gps_tracking", checked).apply()
                                    val intent = android.content.Intent(context, com.krce.bus.service.GpsForegroundService::class.java).apply {
                                        putExtra("EXTRA_TOKEN", token)
                                        putExtra("EXTRA_BUS_ID", busId)
                                    }
                                    if (checked) {
                                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent) else context.startService(intent)
                                    } else context.stopService(intent)
                                },
                                colors = SwitchDefaults.colors(checkedThumbColor = Color.White, checkedTrackColor = IndigoPrimary)
                            )
                        }
                    }
                    Spacer(Modifier.height(16.dp))
                    val scope = rememberCoroutineScope()
                    var sosMessage by remember { mutableStateOf("") }
                    if (sosMessage.isNotEmpty()) {
                        Text(sosMessage, color = ErrorRed, style = Typography.bodyMedium, fontWeight = FontWeight.Bold)
                        Spacer(modifier = Modifier.height(12.dp))
                    }
                    Button(
                        onClick = {
                            scope.launch {
                                try {
                                    apiService.triggerSos(token)
                                    sosMessage = "SOS emergency broadcasted!"
                                } catch (e: Exception) {
                                    sosMessage = "Failed to trigger SOS alert"
                                }
                            }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = ErrorRed),
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        contentPadding = PaddingValues(16.dp)
                    ) {
                        Icon(Icons.Default.Warning, contentDescription = null, tint = Color.White)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Trigger SOS Panic Alert", style = Typography.titleMedium, fontWeight = FontWeight.Bold, color = Color.White)
                    }
                    Spacer(Modifier.height(28.dp))
                    Text("Passengers Onboard", style = Typography.titleLarge, fontWeight = FontWeight.Bold, color = TextColor)
                    Spacer(Modifier.height(16.dp))
                }
            }
            items(passengers.size) { index ->
                val p = passengers[index]
                Box(modifier = Modifier.padding(horizontal = 24.dp, vertical = 4.dp)) {
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .border(1.dp, BorderColor, RoundedCornerShape(16.dp)),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = SurfaceColor)
                    ) {
                        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(40.dp)
                                    .background(BusBadgeBg, CircleShape),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Default.Person, contentDescription = null, tint = BusBadgeIcon)
                            }
                            Spacer(Modifier.width(16.dp))
                            Column {
                                Text(p.name, style = Typography.titleSmall, fontWeight = FontWeight.Bold, color = TextColor)
                                Spacer(modifier = Modifier.height(2.dp))
                                Text("ID: ${p.collegeId} • Boarded at ${p.stopName}", style = Typography.bodySmall, color = MutedText)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun HistoryScreen(token: String, role: String) {
    var history by remember { mutableStateOf<List<Attendance>>(emptyList()) }
    val apiService = remember { ApiService.create() }

    LaunchedEffect(Unit) {
        try {
            history = if (role == "parent") apiService.getChildAttendance(token) else apiService.getMyAttendance(token)
        } catch (e: Exception) {}
    }

    Box(modifier = Modifier.fillMaxSize().background(BackgroundColor).padding(16.dp)) {
        Column(modifier = Modifier.fillMaxSize()) {
            Text("Activity History", style = Typography.headlineMedium, fontWeight = FontWeight.Bold, color = TextColor)
            Spacer(Modifier.height(16.dp))
            LazyColumn {
                items(history.size) { index ->
                    AttendanceItem(history[index])
                    Spacer(Modifier.height(12.dp))
                }
            }
        }
    }
}

@Composable
fun ProfileScreen(authViewModel: AuthViewModel) {
    var showPasswordDialog by remember { mutableStateOf(false) }
    
    Box(modifier = Modifier.fillMaxSize().background(BackgroundColor)) {
        // Upper background banner
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.25f)
                .background(Brush.verticalGradient(GradientPrimary))
        )
        
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp)
                .statusBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.height(24.dp))
            // Profile image card with double outline
            Card(
                modifier = Modifier
                    .size(108.dp)
                    .border(4.dp, Color.White.copy(alpha = 0.5f), CircleShape),
                shape = CircleShape,
                colors = CardDefaults.cardColors(containerColor = IndigoPrimary),
                elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
            ) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Icon(Icons.Default.Person, contentDescription = null, modifier = Modifier.size(64.dp), tint = Color.White)
                }
            }
            Spacer(Modifier.height(16.dp))
            Text(authViewModel.userName, style = Typography.headlineMedium, fontWeight = FontWeight.Bold, color = TextColor)
            Spacer(Modifier.height(4.dp))
            Box(
                modifier = Modifier
                    .background(BusBadgeBg, RoundedCornerShape(8.dp))
                    .padding(horizontal = 12.dp, vertical = 6.dp)
            ) {
                Text(
                    authViewModel.userRole.uppercase(),
                    style = Typography.labelSmall.copy(fontSize = 11.sp),
                    color = BusBadgeIcon,
                    fontWeight = FontWeight.ExtraBold
                )
            }
            
            Spacer(Modifier.height(32.dp))
            GlassCard {
                ProfileInfoRow("College ID", authViewModel.collegeId ?: "—")
                Divider(color = BorderColor, thickness = 0.5.dp)
                ProfileInfoRow("Phone", authViewModel.phone ?: "—")
                Divider(color = BorderColor, thickness = 0.5.dp)
                if (authViewModel.userRole == "parent") {
                    ProfileInfoRow("Parent of", authViewModel.parentOf ?: "—")
                } else {
                    ProfileInfoRow("Assigned Bus", authViewModel.userBusId ?: "—")
                }
            }
            
            Spacer(Modifier.height(32.dp))
            PremiumButton(
                text = "Change Password",
                onClick = { showPasswordDialog = true },
                gradient = listOf(Color(0xFF64748B), Color(0xFF475569))
            )
            Spacer(Modifier.height(16.dp))
            TextButton(onClick = { authViewModel.logout() }) {
                Text("Logout", color = ErrorRed, fontWeight = FontWeight.Bold)
            }
        }
    }
    
    if (showPasswordDialog) {
        ChangePasswordDialog(authViewModel.authToken) { showPasswordDialog = false }
    }
}

@Composable
fun ProfileInfoRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, style = Typography.bodyMedium, color = MutedText, fontWeight = FontWeight.Medium)
        Text(value, style = Typography.bodyLarge, color = TextColor, fontWeight = FontWeight.Bold)
    }
}

@Composable
fun ChangePasswordDialog(token: String, onDismiss: () -> Unit) {
    var oldPw by remember { mutableStateOf("") }
    var newPw by remember { mutableStateOf("") }
    var msg by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()
    val api = remember { ApiService.create() }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Change Password", style = Typography.titleLarge, fontWeight = FontWeight.Bold) },
        text = {
            Column {
                OutlinedTextField(
                    value = oldPw,
                    onValueChange = { oldPw = it },
                    label = { Text("Old Password") },
                    visualTransformation = PasswordVisualTransformation(),
                    shape = RoundedCornerShape(12.dp)
                )
                Spacer(Modifier.height(12.dp))
                OutlinedTextField(
                    value = newPw,
                    onValueChange = { newPw = it },
                    label = { Text("New Password") },
                    visualTransformation = PasswordVisualTransformation(),
                    shape = RoundedCornerShape(12.dp)
                )
                if (msg.isNotEmpty()) {
                    Spacer(Modifier.height(12.dp))
                    Text(msg, color = if (msg.contains("success")) SuccessGreen else ErrorRed, style = Typography.bodySmall)
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    scope.launch {
                        try {
                            api.changePassword(token, ChangePasswordReq(oldPw, newPw))
                            msg = "Password changed successfully"
                            delay(1500)
                            onDismiss()
                        } catch (e: Exception) { msg = "Failed to change password" }
                    }
                },
                colors = ButtonDefaults.buttonColors(containerColor = IndigoPrimary),
                shape = RoundedCornerShape(12.dp)
            ) { Text("Update", color = Color.White) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = MutedText)
            }
        }
    )
}

@Composable
fun AttendanceItem(att: Attendance) {
    val isBoarded = att.tapType == "boarded"
    val tintColor = if (isBoarded) SuccessGreen else Color.Red
    val tintBg = if (isBoarded) SuccessBg else Color.Red.copy(alpha = 0.08f)

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, BorderColor, RoundedCornerShape(20.dp)),
        colors = CardDefaults.cardColors(containerColor = SurfaceColor),
        shape = RoundedCornerShape(20.dp)
    ) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .background(tintBg, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = if (isBoarded) Icons.Default.CheckCircle else Icons.Default.ExitToApp,
                    contentDescription = null,
                    tint = tintColor
                )
            }
            Spacer(Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(att.studentName ?: "Unknown Student", style = Typography.titleSmall, fontWeight = FontWeight.Bold, color = TextColor)
                Spacer(modifier = Modifier.height(2.dp))
                Text("Bus ${att.busNumber ?: "—"} • ${att.stopName ?: "Location Unavailable"}", style = Typography.bodySmall, color = MutedText)
            }
            Text(formatTime(att.tapTime), style = Typography.labelSmall, color = MutedText)
        }
    }
}

private fun formatTime(timestamp: String?): String {
    if (timestamp == null) return "—"
    return try {
        val dateTime = LocalDateTime.parse(timestamp, DateTimeFormatter.ISO_LOCAL_DATE_TIME)
        dateTime.format(DateTimeFormatter.ofPattern("HH:mm"))
    } catch (e: Exception) {
        try {
            val parts = timestamp.split(" ")
            if (parts.size > 1) parts[1].substring(0, 5) else "—"
        } catch (e: Exception) { "—" }
    }
}

@Composable
fun PlaceholderScreen(title: String) {
    Box(modifier = Modifier.fillMaxSize().background(BackgroundColor), contentAlignment = Alignment.Center) {
        Text(title, style = Typography.headlineMedium, color = MutedText)
    }
}

// ── Feature 1: Registration Approval Card ─────────────────────────────────────
@Composable
fun RegistrationApprovalCard(
    registration: com.krce.bus.models.Registration,
    onApprove: () -> Unit,
    onReject: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, BorderColor, RoundedCornerShape(18.dp)),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = SurfaceColor)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .background(Color(0xFFFFF3CD), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Default.Person, contentDescription = null, tint = Color(0xFFD97706))
                }
                Spacer(modifier = Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(registration.applicantName, style = Typography.titleSmall, fontWeight = FontWeight.Bold, color = TextColor)
                    Text(registration.email, style = Typography.bodySmall, color = MutedText)
                }
                Box(
                    modifier = Modifier
                        .background(Color(0xFFFFF3CD), RoundedCornerShape(8.dp))
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                ) {
                    Text(registration.requestedRole.uppercase(), style = Typography.labelSmall, color = Color(0xFFD97706), fontWeight = FontWeight.Bold)
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
            if (!registration.collegeId.isNullOrBlank()) {
                Text("College ID: ${registration.collegeId}", style = Typography.bodySmall, color = MutedText)
            }
            Text("Phone: ${registration.phone}", style = Typography.bodySmall, color = MutedText)
            Text("Requested: ${registration.requestDate.take(10)}", style = Typography.bodySmall, color = MutedText)
            Spacer(modifier = Modifier.height(14.dp))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(
                    onClick = onApprove,
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = SuccessGreen),
                    contentPadding = PaddingValues(10.dp)
                ) {
                    Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Approve", style = Typography.labelMedium, fontWeight = FontWeight.Bold)
                }
                OutlinedButton(
                    onClick = onReject,
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(12.dp),
                    border = androidx.compose.foundation.BorderStroke(1.dp, ErrorRed),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = ErrorRed),
                    contentPadding = PaddingValues(10.dp)
                ) {
                    Icon(Icons.Default.Close, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Reject", style = Typography.labelMedium, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

// ── Feature 3: Send Alert Dialog ─────────────────────────────────────────────
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun SendAlertDialog(token: String, buses: List<Bus>, onDismiss: () -> Unit) {
    var title by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    var alertType by remember { mutableStateOf("info") }
    var targetBus by remember { mutableStateOf<String?>(null) }
    var statusMsg by remember { mutableStateOf("") }
    var isSending by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val api = remember { ApiService.create() }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = SurfaceColor,
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Warning, contentDescription = null, tint = Color(0xFFD97706))
                Spacer(modifier = Modifier.width(8.dp))
                Text("Send Alert", style = Typography.titleLarge, fontWeight = FontWeight.Bold, color = TextColor)
            }
        },
        text = {
            Column {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("Alert Title") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = IndigoPrimary,
                        focusedLabelColor = IndigoPrimary,
                        unfocusedBorderColor = BorderColor,
                        unfocusedLabelColor = MutedText
                    ),
                    singleLine = true
                )
                Spacer(modifier = Modifier.height(10.dp))
                OutlinedTextField(
                    value = message,
                    onValueChange = { message = it },
                    label = { Text("Message") },
                    modifier = Modifier.fillMaxWidth().height(90.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = IndigoPrimary,
                        focusedLabelColor = IndigoPrimary,
                        unfocusedBorderColor = BorderColor,
                        unfocusedLabelColor = MutedText
                    ),
                    maxLines = 3
                )
                Spacer(modifier = Modifier.height(10.dp))
                Text("Alert Type", style = Typography.labelSmall, color = MutedText)
                Spacer(modifier = Modifier.height(6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf("info", "delay", "safety").forEach { type ->
                        val selected = alertType == type
                        val color = when(type) { "delay" -> Color(0xFFD97706); "safety" -> ErrorRed; else -> IndigoPrimary }
                        FilterChip(
                            selected = selected,
                            onClick = { alertType = type },
                            label = { Text(type.replaceFirstChar { it.uppercase() }, style = Typography.labelSmall) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = color.copy(alpha = 0.15f),
                                selectedLabelColor = color,
                                containerColor = SurfaceColor,
                                labelColor = MutedText
                            )
                        )
                    }
                }
                Spacer(modifier = Modifier.height(10.dp))
                Text("Target Bus (optional)", style = Typography.labelSmall, color = MutedText)
                Spacer(modifier = Modifier.height(6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    FilterChip(
                        selected = targetBus == null,
                        onClick = { targetBus = null },
                        label = { Text("All", style = Typography.labelSmall) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = IndigoPrimary.copy(alpha = 0.15f),
                            selectedLabelColor = IndigoPrimary,
                            containerColor = SurfaceColor, labelColor = MutedText
                        )
                    )
                    buses.forEach { bus ->
                        FilterChip(
                            selected = targetBus == bus.id,
                            onClick = { targetBus = bus.id },
                            label = { Text(bus.number, style = Typography.labelSmall) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = IndigoPrimary.copy(alpha = 0.15f),
                                selectedLabelColor = IndigoPrimary,
                                containerColor = SurfaceColor, labelColor = MutedText
                            )
                        )
                    }
                }
                if (statusMsg.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(statusMsg, color = if (statusMsg.startsWith("✅")) SuccessGreen else ErrorRed, style = Typography.bodySmall)
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    if (title.isBlank() || message.isBlank()) { statusMsg = "Fill in title and message"; return@Button }
                    isSending = true
                    scope.launch {
                        try {
                            api.sendAlert(token, com.krce.bus.models.CreateAlertReq(
                                title = title, message = message,
                                alertType = alertType, targetBus = targetBus
                            ))
                            statusMsg = "✅ Alert sent!"
                            kotlinx.coroutines.delay(1200)
                            onDismiss()
                        } catch (e: Exception) {
                            statusMsg = "Failed: ${e.message?.take(40)}"
                        } finally { isSending = false }
                    }
                },
                enabled = !isSending,
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFD97706)),
                shape = RoundedCornerShape(12.dp)
            ) { Text(if (isSending) "Sending…" else "Send", color = Color.White, fontWeight = FontWeight.Bold) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel", color = MutedText) }
        }
    )
}

// ── Feature 2: User Management Screen ────────────────────────────────────────
@Composable
fun UsersScreen(navController: NavController, token: String) {
    var users by remember { mutableStateOf<List<com.krce.bus.models.User>>(emptyList()) }
    var buses by remember { mutableStateOf<List<Bus>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var errorMsg by remember { mutableStateOf("") }
    var editingUser by remember { mutableStateOf<com.krce.bus.models.User?>(null) }
    val api = remember { ApiService.create() }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        try {
            users = api.getUsers(token)
            buses = api.getBuses(token)
        } catch (e: Exception) {
            errorMsg = "Failed to load users"
        } finally { isLoading = false }
    }

    if (editingUser != null) {
        EditUserDialog(
            user = editingUser!!,
            buses = buses,
            token = token,
            onDismiss = { editingUser = null },
            onSaved = { updatedUser ->
                users = users.map { if (it.id == updatedUser.id) updatedUser else it }
                editingUser = null
            }
        )
    }

    Box(modifier = Modifier.fillMaxSize().background(BackgroundColor)) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Header
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Brush.verticalGradient(GradientPrimary))
                    .statusBarsPadding()
                    .padding(16.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = Color.White)
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Column {
                        Text("Manage Users", style = Typography.titleLarge, fontWeight = FontWeight.Bold, color = Color.White)
                        Text("${users.size} registered accounts", style = Typography.bodySmall, color = Color.White.copy(alpha = 0.75f))
                    }
                }
            }

            if (isLoading) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = IndigoPrimary)
                }
            } else if (errorMsg.isNotEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text(errorMsg, color = ErrorRed)
                }
            } else {
                LazyColumn(modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(16.dp)) {
                    items(users.size) { index ->
                        val user = users[index]
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 6.dp)
                                .border(1.dp, BorderColor, RoundedCornerShape(18.dp))
                                .clickable { editingUser = user },
                            shape = RoundedCornerShape(18.dp),
                            colors = CardDefaults.cardColors(containerColor = SurfaceColor)
                        ) {
                            Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                                Box(
                                    modifier = Modifier
                                        .size(44.dp)
                                        .background(BusBadgeBg, CircleShape),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(
                                        when(user.role) {
                                            "driver" -> Icons.Default.DirectionsBus
                                            "admin", "committee" -> Icons.Default.Person
                                            else -> Icons.Default.Person
                                        },
                                        contentDescription = null, tint = BusBadgeIcon
                                    )
                                }
                                Spacer(modifier = Modifier.width(12.dp))
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(user.name, style = Typography.titleSmall, fontWeight = FontWeight.Bold, color = TextColor)
                                    Text(user.email, style = Typography.bodySmall, color = MutedText)
                                    if (!user.busId.isNullOrBlank()) {
                                        Text("Bus: ${user.busId}", style = Typography.bodySmall, color = IndigoPrimary)
                                    }
                                }
                                Column(horizontalAlignment = Alignment.End) {
                                    Box(
                                        modifier = Modifier
                                            .background(BusBadgeBg, RoundedCornerShape(6.dp))
                                            .padding(horizontal = 8.dp, vertical = 3.dp)
                                    ) {
                                        Text(user.role.uppercase(), style = Typography.labelSmall, color = BusBadgeIcon, fontWeight = FontWeight.Bold)
                                    }
                                    Spacer(modifier = Modifier.height(4.dp))
                                    val statusColor = if (user.status == "active") SuccessGreen else ErrorRed
                                    Text(user.status, style = Typography.labelSmall, color = statusColor, fontWeight = FontWeight.Bold)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun EditUserDialog(
    user: com.krce.bus.models.User,
    buses: List<Bus>,
    token: String,
    onDismiss: () -> Unit,
    onSaved: (com.krce.bus.models.User) -> Unit
) {
    var selectedRole by remember { mutableStateOf(user.role) }
    var selectedBusId by remember { mutableStateOf(user.busId ?: "") }
    var statusMsg by remember { mutableStateOf("") }
    var isSaving by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val api = remember { ApiService.create() }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = SurfaceColor,
        title = {
            Text("Edit: ${user.name}", style = Typography.titleMedium, fontWeight = FontWeight.Bold, color = TextColor)
        },
        text = {
            Column {
                Text("Role", style = Typography.labelSmall, color = MutedText)
                Spacer(modifier = Modifier.height(6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    listOf("student", "parent", "driver", "admin").forEach { role ->
                        FilterChip(
                            selected = selectedRole == role,
                            onClick = { selectedRole = role },
                            label = { Text(role, style = Typography.labelSmall) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = IndigoPrimary.copy(alpha = 0.15f),
                                selectedLabelColor = IndigoPrimary,
                                containerColor = SurfaceColor, labelColor = MutedText
                            )
                        )
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))
                Text("Assign Bus", style = Typography.labelSmall, color = MutedText)
                Spacer(modifier = Modifier.height(6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    FilterChip(
                        selected = selectedBusId.isEmpty(),
                        onClick = { selectedBusId = "" },
                        label = { Text("None", style = Typography.labelSmall) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = IndigoPrimary.copy(alpha = 0.15f),
                            selectedLabelColor = IndigoPrimary,
                            containerColor = SurfaceColor, labelColor = MutedText
                        )
                    )
                    buses.forEach { bus ->
                        FilterChip(
                            selected = selectedBusId == bus.id,
                            onClick = { selectedBusId = bus.id },
                            label = { Text(bus.number, style = Typography.labelSmall) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = IndigoPrimary.copy(alpha = 0.15f),
                                selectedLabelColor = IndigoPrimary,
                                containerColor = SurfaceColor, labelColor = MutedText
                            )
                        )
                    }
                }
                if (statusMsg.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(statusMsg, color = if (statusMsg.startsWith("✅")) SuccessGreen else ErrorRed, style = Typography.bodySmall)
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    isSaving = true
                    scope.launch {
                        try {
                            statusMsg = "✅ Saved!"
                            val updated = user.copy(role = selectedRole, busId = selectedBusId.ifEmpty { null })
                            kotlinx.coroutines.delay(800)
                            onSaved(updated)
                        } catch (e: Exception) {
                            statusMsg = "Failed: ${e.message?.take(40)}"
                        } finally { isSaving = false }
                    }
                },
                enabled = !isSaving,
                colors = ButtonDefaults.buttonColors(containerColor = IndigoPrimary),
                shape = RoundedCornerShape(12.dp)
            ) { Text(if (isSaving) "Saving…" else "Save", color = Color.White, fontWeight = FontWeight.Bold) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel", color = MutedText) }
        }
    )
}
