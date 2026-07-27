package com.krce.bus.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.krce.bus.ui.theme.*

@Composable
fun CollegeGateIllustration(modifier: Modifier = Modifier) {
    Box(modifier = modifier, contentAlignment = Alignment.BottomCenter) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val width = size.width
            val height = size.height
            
            // Draw soft clouds in the background
            val cloudColor = Color.White.copy(alpha = 0.08f)
            drawCircle(
                color = cloudColor,
                radius = width * 0.18f,
                center = androidx.compose.ui.geometry.Offset(width * 0.15f, height * 0.3f)
            )
            drawCircle(
                color = cloudColor,
                radius = width * 0.22f,
                center = androidx.compose.ui.geometry.Offset(width * 0.32f, height * 0.25f)
            )
            drawCircle(
                color = cloudColor,
                radius = width * 0.15f,
                center = androidx.compose.ui.geometry.Offset(width * 0.85f, height * 0.35f)
            )
            
            // Draw subtle tree silhouettes (darker navy-blue)
            val treeColor = Color(0xFF1B3580).copy(alpha = 0.35f)
            drawPath(
                path = Path().apply {
                    moveTo(0f, height)
                    quadraticBezierTo(width * 0.12f, height * 0.55f, width * 0.28f, height)
                    close()
                },
                color = treeColor
            )
            drawPath(
                path = Path().apply {
                    moveTo(width * 0.72f, height)
                    quadraticBezierTo(width * 0.88f, height * 0.6f, width, height)
                    close()
                },
                color = treeColor
            )

            // Draw gate structure
            val structureColor = Color.White.copy(alpha = 0.12f)
            val archCenterX = width * 0.5f
            val archWidth = width * 0.44f
            val archHeight = height * 0.58f
            val archY = height - archHeight
            
            // Left Pillar
            drawRect(
                color = structureColor,
                topLeft = androidx.compose.ui.geometry.Offset(archCenterX - archWidth * 0.5f, archY + archHeight * 0.3f),
                size = androidx.compose.ui.geometry.Size(archWidth * 0.14f, archHeight * 0.7f)
            )
            // Right Pillar
            drawRect(
                color = structureColor,
                topLeft = androidx.compose.ui.geometry.Offset(archCenterX + archWidth * 0.5f - archWidth * 0.14f, archY + archHeight * 0.3f),
                size = androidx.compose.ui.geometry.Size(archWidth * 0.14f, archHeight * 0.7f)
            )
            
            // Arch top curved bar
            drawPath(
                path = Path().apply {
                    moveTo(archCenterX - archWidth * 0.5f, archY + archHeight * 0.3f)
                    quadraticBezierTo(
                        archCenterX, archY - archHeight * 0.06f,
                        archCenterX + archWidth * 0.5f, archY + archHeight * 0.3f
                    )
                    lineTo(archCenterX + archWidth * 0.5f - archWidth * 0.14f, archY + archHeight * 0.3f)
                    quadraticBezierTo(
                        archCenterX, archY + archHeight * 0.08f,
                        archCenterX - archWidth * 0.5f + archWidth * 0.14f, archY + archHeight * 0.3f
                    )
                    close()
                },
                color = structureColor
            )

            // Brick wall above arch
            drawRect(
                color = structureColor,
                topLeft = androidx.compose.ui.geometry.Offset(archCenterX - archWidth * 0.35f, archY + archHeight * 0.12f),
                size = androidx.compose.ui.geometry.Size(archWidth * 0.7f, archHeight * 0.22f)
            )
            
            // Behind Tower Left
            drawRect(
                color = structureColor,
                topLeft = androidx.compose.ui.geometry.Offset(archCenterX - archWidth * 0.95f, archY + archHeight * 0.35f),
                size = androidx.compose.ui.geometry.Size(archWidth * 0.35f, archHeight * 0.65f)
            )
            // Behind Tower Right
            drawRect(
                color = structureColor,
                topLeft = androidx.compose.ui.geometry.Offset(archCenterX + archWidth * 0.95f - archWidth * 0.35f, archY + archHeight * 0.35f),
                size = androidx.compose.ui.geometry.Size(archWidth * 0.35f, archHeight * 0.65f)
            )
        }
        
        // Position "KRCE" text centered on the brick wall
        Box(
            modifier = Modifier
                .fillMaxWidth(0.3f)
                .align(Alignment.BottomCenter)
                .padding(bottom = 64.dp)
                .background(Color.White.copy(alpha = 0.15f), RoundedCornerShape(3.dp))
                .padding(horizontal = 4.dp, vertical = 2.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "KRCE",
                fontSize = 10.sp,
                fontWeight = FontWeight.Black,
                color = Color.White.copy(alpha = 0.8f),
                letterSpacing = 0.5.sp
            )
        }
    }
}

@Composable
fun ParentChildIllustration(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val width = size.width
        val height = size.height
        
        // Mother silhouette
        val motherHeadRadius = width * 0.18f
        val motherHeadCenter = androidx.compose.ui.geometry.Offset(width * 0.5f, height * 0.36f)
        drawCircle(
            color = Color.White.copy(alpha = 0.15f),
            radius = motherHeadRadius,
            center = motherHeadCenter
        )
        // Hair
        drawPath(
            path = Path().apply {
                addArc(
                    oval = androidx.compose.ui.geometry.Rect(
                        motherHeadCenter.x - motherHeadRadius,
                        motherHeadCenter.y - motherHeadRadius,
                        motherHeadCenter.x + motherHeadRadius,
                        motherHeadCenter.y + motherHeadRadius
                    ),
                    startAngleDegrees = 180f,
                    sweepAngleDegrees = 180f
                )
                quadraticBezierTo(
                    motherHeadCenter.x + motherHeadRadius * 1.2f, motherHeadCenter.y,
                    motherHeadCenter.x + motherHeadRadius * 0.8f, motherHeadCenter.y + motherHeadRadius * 0.8f
                )
                close()
            },
            color = Color.White.copy(alpha = 0.22f)
        )
        // Torso
        drawPath(
            path = Path().apply {
                moveTo(width * 0.15f, height)
                quadraticBezierTo(width * 0.25f, height * 0.6f, width * 0.5f, height * 0.6f)
                quadraticBezierTo(width * 0.75f, height * 0.6f, width * 0.85f, height)
                close()
            },
            color = Color.White.copy(alpha = 0.18f)
        )

        // Child silhouette
        val childHeadRadius = width * 0.13f
        val childHeadCenter = androidx.compose.ui.geometry.Offset(width * 0.78f, height * 0.52f)
        drawCircle(
            color = Color.White.copy(alpha = 0.2f),
            radius = childHeadRadius,
            center = childHeadCenter
        )
        // Torso
        drawPath(
            path = Path().apply {
                moveTo(width * 0.52f, height)
                quadraticBezierTo(width * 0.62f, height * 0.72f, width * 0.78f, height * 0.72f)
                quadraticBezierTo(width * 0.92f, height * 0.72f, width, height)
                close()
            },
            color = Color.White.copy(alpha = 0.22f)
        )
    }
}

@Composable
fun AnalyticsIllustration(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val width = size.width
        val height = size.height
        
        // Draw soft vertical lines in the background
        val gridColor = Color.White.copy(alpha = 0.08f)
        for (i in 1..3) {
            val y = height * (i / 4f)
            drawLine(
                color = gridColor,
                start = androidx.compose.ui.geometry.Offset(0f, y),
                end = androidx.compose.ui.geometry.Offset(width, y),
                strokeWidth = 1.dp.toPx()
            )
        }
        
        // Draw an analytical line graph
        val linePath = Path().apply {
            moveTo(0f, height * 0.8f)
            quadraticBezierTo(width * 0.25f, height * 0.5f, width * 0.5f, height * 0.7f)
            quadraticBezierTo(width * 0.75f, height * 0.35f, width, height * 0.45f)
        }
        drawPath(
            path = linePath,
            color = Color.White.copy(alpha = 0.15f),
            style = androidx.compose.ui.graphics.drawscope.Stroke(width = 3.dp.toPx())
        )
        
        // Draw little nodes on the chart
        drawCircle(
            color = Color.White.copy(alpha = 0.25f),
            radius = 5.dp.toPx(),
            center = androidx.compose.ui.geometry.Offset(width * 0.5f, height * 0.7f)
        )
        drawCircle(
            color = Color.White.copy(alpha = 0.25f),
            radius = 5.dp.toPx(),
            center = androidx.compose.ui.geometry.Offset(width * 0.75f, height * 0.44f)
        )
        
        // Draw bar chart shapes
        val barColor = Color.White.copy(alpha = 0.1f)
        drawRect(
            color = barColor,
            topLeft = androidx.compose.ui.geometry.Offset(width * 0.12f, height * 0.55f),
            size = androidx.compose.ui.geometry.Size(width * 0.08f, height * 0.45f)
        )
        drawRect(
            color = barColor,
            topLeft = androidx.compose.ui.geometry.Offset(width * 0.28f, height * 0.4f),
            size = androidx.compose.ui.geometry.Size(width * 0.08f, height * 0.6f)
        )
        drawRect(
            color = barColor,
            topLeft = androidx.compose.ui.geometry.Offset(width * 0.44f, height * 0.48f),
            size = androidx.compose.ui.geometry.Size(width * 0.08f, height * 0.52f)
        )
    }
}

@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .shadow(elevation = 3.dp, shape = RoundedCornerShape(24.dp))
            .border(1.dp, BorderColor, RoundedCornerShape(24.dp)),
        colors = CardDefaults.cardColors(containerColor = SurfaceColor),
        shape = RoundedCornerShape(24.dp)
    ) {
        Column(
            modifier = Modifier.padding(24.dp),
            content = content
        )
    }
}

@Composable
fun DashboardHeader(
    title: String,
    subtitle: String,
    role: String,
    onNotificationClick: () -> Unit = {}
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(260.dp)
            .background(
                brush = Brush.verticalGradient(
                    colors = GradientPrimary
                )
            )
            .padding(horizontal = 24.dp, vertical = 16.dp)
    ) {
        Column {
            Row(
                modifier = Modifier.fillMaxWidth().statusBarsPadding(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "KRCE BusTrack",
                    style = Typography.titleLarge,
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )
                IconButton(onClick = onNotificationClick) {
                    Icon(
                        imageVector = Icons.Default.Notifications,
                        contentDescription = "Notifications",
                        tint = Color.White
                    )
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = title,
                style = Typography.headlineLarge,
                color = Color.White,
                fontWeight = FontWeight.Bold,
                lineHeight = 36.sp
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = subtitle,
                style = Typography.bodyMedium,
                color = Color.White.copy(alpha = 0.7f)
            )
        }
        
        // Render custom background illustration based on dashboard type
        if (role == "student") {
            CollegeGateIllustration(
                modifier = Modifier
                    .width(180.dp)
                    .height(130.dp)
                    .align(Alignment.BottomEnd)
                    .offset(x = 10.dp, y = 0.dp)
            )
        } else if (role == "parent") {
            ParentChildIllustration(
                modifier = Modifier
                    .width(160.dp)
                    .height(120.dp)
                    .align(Alignment.BottomEnd)
                    .offset(x = 10.dp, y = 0.dp)
            )
        } else if (role == "admin" || role == "committee") {
            AnalyticsIllustration(
                modifier = Modifier
                    .width(170.dp)
                    .height(110.dp)
                    .align(Alignment.BottomEnd)
                    .offset(x = 10.dp, y = 0.dp)
            )
        } else {
            Icon(
                imageVector = Icons.Default.DirectionsBus,
                contentDescription = null,
                modifier = Modifier
                    .size(130.dp)
                    .align(Alignment.BottomEnd)
                    .offset(x = 20.dp, y = 20.dp),
                tint = Color.White.copy(alpha = 0.08f)
            )
        }
    }
}

@Composable
fun InfoItem(
    icon: ImageVector,
    label: String,
    value: String,
    showEta: Boolean = false,
    etaValue: String = ""
) {
    // Determine colors based on action type/label
    val (badgeBg, badgeIcon) = when {
        label.contains("Bus", ignoreCase = true) -> Pair(BusBadgeBg, BusBadgeIcon)
        label.contains("Route", ignoreCase = true) -> Pair(RouteBadgeBg, RouteBadgeIcon)
        label.contains("Arrival", ignoreCase = true) -> Pair(ArrivalBadgeBg, ArrivalBadgeIcon)
        else -> Pair(BackgroundColor, IndigoPrimary)
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .background(badgeBg, RoundedCornerShape(14.dp)),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = null, tint = badgeIcon)
        }
        Spacer(modifier = Modifier.width(16.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(label, style = Typography.bodySmall, color = MutedText)
            Spacer(modifier = Modifier.height(2.dp))
            Text(value, style = Typography.titleLarge, fontWeight = FontWeight.Bold)
        }
        if (showEta) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = etaValue,
                    style = Typography.titleLarge,
                    color = SuccessGreen,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.width(8.dp))
                Box(
                    modifier = Modifier
                        .background(ETAChipBg, RoundedCornerShape(8.dp))
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                ) {
                    Text("ETA", style = Typography.labelSmall, color = ETAChipText, fontWeight = FontWeight.ExtraBold)
                }
            }
        }
    }
}

@Composable
fun ActionButton(
    text: String,
    icon: ImageVector,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp),
        shape = RoundedCornerShape(16.dp),
        colors = ButtonDefaults.buttonColors(containerColor = IndigoPrimary)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(icon, contentDescription = null, tint = Color.White)
                Spacer(modifier = Modifier.width(12.dp))
                Text(text, style = Typography.bodyLarge, color = Color.White, fontWeight = FontWeight.Bold)
            }
            Icon(Icons.Default.KeyboardArrowRight, contentDescription = null, tint = Color.White)
        }
    }
}

@Composable
fun QuickActionItem(
    icon: ImageVector,
    label: String,
    onClick: () -> Unit = {}
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.padding(horizontal = 4.dp)
    ) {
        Card(
            modifier = Modifier
                .size(64.dp)
                .clickable { onClick() }
                .border(1.dp, BorderColor, RoundedCornerShape(16.dp)),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = SurfaceColor),
            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
        ) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Icon(icon, contentDescription = label, tint = IndigoPrimary, modifier = Modifier.size(24.dp))
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = label,
            style = Typography.bodySmall,
            color = TextColor,
            fontWeight = FontWeight.Medium
        )
    }
}

@Composable
fun AnnouncementCard(
    message: String,
    onClick: () -> Unit = {}
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(elevation = 1.dp, shape = RoundedCornerShape(20.dp))
            .border(1.dp, BorderColor, RoundedCornerShape(20.dp)),
        colors = CardDefaults.cardColors(containerColor = SurfaceColor),
        shape = RoundedCornerShape(20.dp)
    ) {
        Row(
            modifier = Modifier
                .clickable { onClick() }
                .padding(20.dp)
                .fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .background(BusBadgeBg, RoundedCornerShape(12.dp)),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Default.VolumeUp, contentDescription = null, tint = BusBadgeIcon)
            }
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text("Announcements", style = Typography.titleSmall, fontWeight = FontWeight.Bold, color = IndigoPrimary)
                Spacer(modifier = Modifier.height(2.dp))
                Text(message, style = Typography.bodySmall, color = MutedText, maxLines = 2)
            }
            Icon(Icons.Default.KeyboardArrowRight, contentDescription = null, tint = MutedText)
        }
    }
}

@Composable
fun PremiumButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    isLoading: Boolean = false,
    gradient: List<Color> = GradientPrimary
) {
    Button(
        onClick = onClick,
        modifier = modifier
            .height(54.dp)
            .clip(RoundedCornerShape(16.dp)),
        colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
        contentPadding = PaddingValues(),
        enabled = !isLoading
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Brush.linearGradient(gradient)),
            contentAlignment = Alignment.Center
        ) {
            if (isLoading) {
                CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
            } else {
                Text(
                    text = text,
                    style = Typography.titleLarge,
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

@Composable
fun WelcomeBanner(
    title: String,
    subtitle: String,
    modifier: Modifier = Modifier,
    gradient: List<Color> = GradientPrimary
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(140.dp)
            .shadow(elevation = 2.dp, shape = RoundedCornerShape(24.dp))
            .clip(RoundedCornerShape(24.dp))
            .background(Brush.linearGradient(gradient))
            .padding(24.dp)
    ) {
        Column(modifier = Modifier.align(Alignment.CenterStart)) {
            Text(title, style = Typography.headlineMedium, color = Color.White, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(4.dp))
            Text(subtitle, style = Typography.bodyMedium, color = Color.White.copy(alpha = 0.8f))
        }
    }
}

@Composable
fun StatCard(
    value: String,
    label: String,
    modifier: Modifier = Modifier,
    valueColor: Color = TextColor,
    icon: ImageVector? = null,
    badge: String? = null
) {
    Card(
        modifier = modifier
            .shadow(elevation = 2.dp, shape = RoundedCornerShape(20.dp))
            .border(1.dp, BorderColor, RoundedCornerShape(20.dp)),
        colors = CardDefaults.cardColors(containerColor = SurfaceColor),
        shape = RoundedCornerShape(20.dp)
    ) {
        Column(
            modifier = Modifier.padding(18.dp),
            horizontalAlignment = Alignment.Start
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (icon != null) {
                    Box(
                        modifier = Modifier
                            .size(32.dp)
                            .background(IndigoPrimary.copy(alpha = 0.1f), CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(icon, contentDescription = null, tint = IndigoPrimary, modifier = Modifier.size(18.dp))
                    }
                }
                if (badge != null) {
                    Box(
                        modifier = Modifier
                            .background(Color(0xFFF59E0B).copy(alpha = 0.15f), RoundedCornerShape(6.dp))
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    ) {
                        Text(badge, style = Typography.labelSmall.copy(fontSize = 10.sp), color = Color(0xFFD97706), fontWeight = FontWeight.Bold)
                    }
                }
            }
            Spacer(Modifier.height(12.dp))
            Text(value, style = Typography.headlineMedium, color = valueColor, fontWeight = FontWeight.ExtraBold)
            Spacer(Modifier.height(4.dp))
            Text(label, style = Typography.labelSmall, color = MutedText, fontWeight = FontWeight.Bold)
        }
    }
}
