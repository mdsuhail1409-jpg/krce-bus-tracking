package com.krce.bus.models

import com.google.gson.annotations.SerializedName

data class LoginReq(
    val email: String,
    val password: String
)

data class LoginRes(
    val token: String,
    @SerializedName("user_id") val userId: String,
    val name: String,
    val role: String,
    @SerializedName("bus_id") val busId: String?,
    @SerializedName("college_id") val collegeId: String?,
    @SerializedName("rfid_card") val rfidCard: String?,
    @SerializedName("parent_of") val parentOf: String?,
    val phone: String?
)

data class Bus(
    val id: String,
    val number: String,
    @SerializedName("route_name") val routeName: String,
    @SerializedName("driver_id") val driverId: String?,
    val capacity: Int,
    val stops: List<String>,
    val live: LiveBus? = null
)

data class LiveBus(
    @SerializedName("bus_id") val busId: String,
    @SerializedName("driver_id") val driverId: String,
    @SerializedName("driver_name") val driverName: String,
    val lat: Double,
    val lon: Double,
    val speed: Double,
    val heading: Double,
    val passengers: Int,
    @SerializedName("updated_at") val updatedAt: Double,
    val status: String // "moving", "idle", "offline"
)

data class Alert(
    val id: String,
    val title: String,
    val message: String,
    @SerializedName("alert_type") val alertType: String,
    @SerializedName("target_role") val targetRole: String,
    @SerializedName("target_bus") val targetBus: String?,
    @SerializedName("sent_by") val sentBy: String?,
    @SerializedName("sent_at") val sentAt: String,
    @SerializedName("is_resolved") val isResolved: Int
)

data class RfidTapReq(
    @SerializedName("rfid_card") val rfidCard: String,
    @SerializedName("bus_id") val busId: String,
    @SerializedName("stop_name") val stopName: String = "",
    val lat: Double = 0.0,
    val lon: Double = 0.0
)

data class RfidTapRes(
    val status: String,
    @SerializedName("tap_type") val tapType: String,
    @SerializedName("student_name") val studentName: String
)

data class GpsUpdateReq(
    val lat: Double,
    val lon: Double,
    val speed: Double = 0.0,
    val heading: Double = 0.0,
    val passengers: Int = 0
)

// Simplified response wrapper
data class GenericResponse(
    val status: String,
    val message: String?
)

data class EtaResponse(
    val eta: String,
    @SerializedName("next_stop") val nextStop: String
)

data class ChangePasswordReq(
    @SerializedName("old_password") val oldPassword: String,
    @SerializedName("new_password") val newPassword: String
)

data class Attendance(
    val id: String,
    @SerializedName("user_id") val userId: String,
    @SerializedName("bus_id") val busId: String,
    @SerializedName("tap_type") val tapType: String,
    @SerializedName("tap_time") val tapTime: String,
    @SerializedName("stop_name") val stopName: String?,
    val lat: Double,
    val lon: Double,
    val date: String,
    @SerializedName("student_name") val studentName: String? = null,
    @SerializedName("college_id") val collegeId: String? = null,
    @SerializedName("bus_number") val busNumber: String? = null,
    @SerializedName("route_name") val routeName: String? = null
)

data class Passenger(
    val name: String,
    @SerializedName("college_id") val collegeId: String,
    @SerializedName("rfid_card") val rfidCard: String,
    @SerializedName("tap_type") val tapType: String,
    @SerializedName("tap_time") val tapTime: String,
    @SerializedName("stop_name") val stopName: String?
)

data class AdminStats(
    @SerializedName("total_students") val totalStudents: Int,
    @SerializedName("active_buses") val activeBuses: Int,
    @SerializedName("boarded_today") val boardedToday: Int,
    @SerializedName("pending_regs") val pendingRegs: Int,
    @SerializedName("total_drivers") val totalDrivers: Int,
    @SerializedName("active_alerts") val activeAlerts: Int,
    @SerializedName("live_buses") val liveBuses: Int
)
