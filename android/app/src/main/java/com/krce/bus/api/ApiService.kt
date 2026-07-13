package com.krce.bus.api

import com.krce.bus.BuildConfig
import com.krce.bus.models.Alert
import com.krce.bus.models.Bus
import com.krce.bus.models.GenericResponse
import com.krce.bus.models.GpsUpdateReq
import com.krce.bus.models.LiveBus
import com.krce.bus.models.LoginReq
import com.krce.bus.models.LoginRes
import com.krce.bus.models.RfidTapReq
import com.krce.bus.models.RfidTapRes
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.POST
import retrofit2.http.Path

interface ApiService {

    @POST("/api/auth/login")
    suspend fun login(@Body req: LoginReq): LoginRes

    // Passenger / Student Endpoints
    @GET("/api/buses")
    suspend fun getBuses(@Header("Authorization") token: String): List<Bus>

    @GET("/api/buses/{bus_id}/live")
    suspend fun getBusLive(
        @Header("Authorization") token: String,
        @Path("bus_id") busId: String
    ): LiveBus

    @GET("/api/alerts")
    suspend fun getAlerts(@Header("Authorization") token: String): List<Alert>

    // Driver Endpoints
    @POST("/api/driver/gps")
    suspend fun pushGps(
        @Header("Authorization") token: String,
        @Body req: GpsUpdateReq
    ): GenericResponse

    @GET("/api/buses/{bus_id}/passengers")
    suspend fun getBusPassengers(
        @Header("Authorization") token: String,
        @Path("bus_id") busId: String
    ): List<com.krce.bus.models.Passenger>

    @GET("/api/my/attendance")
    suspend fun getMyAttendance(@Header("Authorization") token: String): List<com.krce.bus.models.Attendance>

    @GET("/api/admin/attendance")
    suspend fun getAllAttendance(@Header("Authorization") token: String): List<com.krce.bus.models.Attendance>

    @GET("/api/admin/stats")
    suspend fun getAdminStats(@Header("Authorization") token: String): com.krce.bus.models.AdminStats

    @GET("/api/buses/{bus_id}")
    suspend fun getBusDetails(
        @Header("Authorization") token: String,
        @Path("bus_id") busId: String
    ): Bus

    @GET("/api/my/eta")
    suspend fun getMyEta(@Header("Authorization") token: String): com.krce.bus.models.EtaResponse

    @GET("/api/my/child-attendance")
    suspend fun getChildAttendance(@Header("Authorization") token: String): List<com.krce.bus.models.Attendance>

    @POST("/api/my/change-password")
    suspend fun changePassword(
        @Header("Authorization") token: String,
        @Body req: com.krce.bus.models.ChangePasswordReq
    ): GenericResponse

    @POST("/api/driver/emergency")
    suspend fun triggerSos(@Header("Authorization") token: String): GenericResponse

    @POST("/api/rfid/tap")
    suspend fun rfidTap(
        @Header("Authorization") token: String,
        @Body req: RfidTapReq
    ): RfidTapRes

    companion object {
        // URL is read from BuildConfig — set via gradle.properties (production)
        // or local.properties (dev). No hardcoded IPs anywhere.
        private val BASE_URL get() = BuildConfig.API_BASE_URL

        fun create(): ApiService {
            val logger = HttpLoggingInterceptor().apply { level = HttpLoggingInterceptor.Level.BODY }
            val client = OkHttpClient.Builder()
                .addInterceptor(logger)
                .connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
                .readTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
                .build()

            return Retrofit.Builder()
                .baseUrl(BASE_URL)
                .client(client)
                .addConverterFactory(GsonConverterFactory.create())
                .build()
                .create(ApiService::class.java)
        }
    }
}
