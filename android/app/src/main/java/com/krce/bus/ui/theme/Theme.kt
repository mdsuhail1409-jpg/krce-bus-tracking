package com.krce.bus.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val LightColorScheme = lightColorScheme(
    primary = IndigoPrimary,
    secondary = VioletSecondary,
    tertiary = InfoTeal,
    background = BackgroundColor,
    surface = SurfaceColor,
    error = ErrorRed,
    onPrimary = SurfaceColor,
    onSecondary = SurfaceColor,
    onBackground = TextColor,
    onSurface = TextColor,
    onError = SurfaceColor
)

@Composable
fun BusTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    // We will stick to Light Theme for now to match the website's default clean look,
    // but the system is ready for Dark Theme if needed.
    val colorScheme = LightColorScheme

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
