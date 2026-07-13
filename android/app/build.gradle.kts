import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.krce.bus"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.krce.bus"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables {
            useSupportLibrary = true
        }

        // Cloud server URLs — set in gradle.properties for production
        // or in local.properties for local dev (local.properties is gitignored)
        val localProperties = Properties()
        val localPropertiesFile = rootProject.file("local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { localProperties.load(it) }
        }

        val apiBaseUrl = localProperties.getProperty("API_BASE_URL")
            ?: project.findProperty("API_BASE_URL")?.toString()
            ?: "http://10.0.2.2:8000/"
        val wsBaseUrl = localProperties.getProperty("WS_BASE_URL")
            ?: project.findProperty("WS_BASE_URL")?.toString()
            ?: "ws://10.0.2.2:8000/"

        buildConfigField("String", "API_BASE_URL", "\"$apiBaseUrl\"")
        buildConfigField("String", "WS_BASE_URL",  "\"$wsBaseUrl\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.8"
    }
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.activity:activity-compose:1.8.2")
    implementation(platform("androidx.compose:compose-bom:2023.10.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    
    // Retrofit & OkHttp
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
    
    // WebSockets via OkHttp (built-in, so standard okhttp dependency is fine)

    // Navigation
    implementation("androidx.navigation:navigation-compose:2.7.6")

    // OSM (OpenStreetMap)
    implementation("org.osmdroid:osmdroid-android:6.1.18")
    
    // GPS Tracking
    implementation("com.google.android.gms:play-services-location:21.1.0")

    // Coroutines — needed for WebSocket reconnection in WebSocketManager
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
