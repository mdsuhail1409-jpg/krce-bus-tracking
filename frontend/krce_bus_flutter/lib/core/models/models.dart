// ============================================================
// Data Models — aligned to backend API responses
// ============================================================

class LoginReq {
  final String email;
  final String password;
  LoginReq({required this.email, required this.password});
  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class LoginRes {
  final String token;
  final String refreshToken;
  final String userId;
  final String name;
  final String role;
  final String? busId;
  final String? collegeId;
  final String? rfidCard;
  final String? parentOf;
  final String? phone;

  LoginRes({
    required this.token,
    required this.refreshToken,
    required this.userId,
    required this.name,
    required this.role,
    this.busId,
    this.collegeId,
    this.rfidCard,
    this.parentOf,
    this.phone,
  });

  factory LoginRes.fromJson(Map<String, dynamic> json) => LoginRes(
        token: json['token'] ?? '',
        refreshToken: json['refresh_token'] ?? '',
        userId: json['user_id'] ?? '',
        name: json['name'] ?? '',
        role: json['role'] ?? 'student',
        busId: json['bus_id'],
        collegeId: json['college_id'],
        rfidCard: json['rfid_card'],
        parentOf: json['parent_of'],
        phone: json['phone'],
      );
}

class LiveBus {
  final String busId;
  final String driverId;
  final String driverName;
  final double lat;
  final double lon;
  final double speed;
  final double heading;
  final int passengers;
  final double updatedAt;
  final String status;

  LiveBus({
    required this.busId,
    required this.driverId,
    required this.driverName,
    required this.lat,
    required this.lon,
    required this.speed,
    required this.heading,
    required this.passengers,
    required this.updatedAt,
    required this.status,
  });

  factory LiveBus.fromJson(Map<String, dynamic> json) => LiveBus(
        busId: json['bus_id'] ?? '',
        driverId: json['driver_id'] ?? '',
        driverName: json['driver_name'] ?? '',
        lat: (json['lat'] ?? 0.0).toDouble(),
        lon: (json['lon'] ?? 0.0).toDouble(),
        speed: (json['speed'] ?? 0.0).toDouble(),
        heading: (json['heading'] ?? 0.0).toDouble(),
        passengers: json['passengers'] ?? 0,
        updatedAt: (json['updated_at'] ?? 0.0).toDouble(),
        status: json['status'] ?? 'offline',
      );
}

class Bus {
  final String id;
  final String number;
  final String routeName;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final int capacity;
  final List<String> stops;
  final LiveBus? live;
  final int boardedToday;

  Bus({
    required this.id,
    required this.number,
    required this.routeName,
    this.driverId,
    this.driverName,
    this.driverPhone,
    required this.capacity,
    required this.stops,
    this.live,
    this.boardedToday = 0,
  });

  factory Bus.fromJson(Map<String, dynamic> json) => Bus(
        id: json['id'] ?? '',
        number: json['number'] ?? '',
        routeName: json['route_name'] ?? '',
        driverId: json['driver_id'],
        driverName: json['driver_name'],
        driverPhone: json['driver_phone'],
        capacity: json['capacity'] ?? 0,
        stops: List<String>.from(json['stops'] ?? []),
        live: json['live'] != null ? LiveBus.fromJson(json['live']) : null,
        boardedToday: json['boarded_today'] ?? 0,
      );
}

class Alert {
  final String id;
  final String title;
  final String message;
  final String alertType;
  final String targetRole;
  final String? targetBus;
  final String? sentBy;
  final String sentAt;
  final int isResolved;

  Alert({
    required this.id,
    required this.title,
    required this.message,
    required this.alertType,
    required this.targetRole,
    this.targetBus,
    this.sentBy,
    required this.sentAt,
    required this.isResolved,
  });

  factory Alert.fromJson(Map<String, dynamic> json) => Alert(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        message: json['message'] ?? '',
        alertType: json['alert_type'] ?? 'info',
        targetRole: json['target_role'] ?? 'all',
        targetBus: json['target_bus'],
        sentBy: json['sent_by'],
        sentAt: json['sent_at'] ?? '',
        isResolved: json['is_resolved'] ?? 0,
      );
}

class Attendance {
  final String id;
  final String userId;
  final String busId;
  final String tapType;
  final String tapTime;
  final String? stopName;
  final double lat;
  final double lon;
  final String date;
  final String? studentName;
  final String? collegeId;
  final String? busNumber;
  final String? routeName;

  Attendance({
    required this.id,
    required this.userId,
    required this.busId,
    required this.tapType,
    required this.tapTime,
    this.stopName,
    required this.lat,
    required this.lon,
    required this.date,
    this.studentName,
    this.collegeId,
    this.busNumber,
    this.routeName,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) => Attendance(
        id: json['id'] ?? '',
        userId: json['user_id'] ?? '',
        busId: json['bus_id'] ?? '',
        tapType: json['tap_type'] ?? '',
        tapTime: json['tap_time'] ?? '',
        stopName: json['stop_name'],
        lat: (json['lat'] ?? 0.0).toDouble(),
        lon: (json['lon'] ?? 0.0).toDouble(),
        date: json['date'] ?? '',
        studentName: json['student_name'],
        collegeId: json['college_id'],
        busNumber: json['bus_number'],
        routeName: json['route_name'],
      );
}

class Passenger {
  final String name;
  final String collegeId;
  final String rfidCard;
  final String tapType;
  final String tapTime;
  final String? stopName;

  Passenger({
    required this.name,
    required this.collegeId,
    required this.rfidCard,
    required this.tapType,
    required this.tapTime,
    this.stopName,
  });

  factory Passenger.fromJson(Map<String, dynamic> json) => Passenger(
        name: json['name'] ?? '',
        collegeId: json['college_id'] ?? '',
        rfidCard: json['rfid_card'] ?? '',
        tapType: json['tap_type'] ?? '',
        tapTime: json['tap_time'] ?? '',
        stopName: json['stop_name'],
      );
}

class AdminStats {
  final int totalStudents;
  final int activeBuses;
  final int boardedToday;
  final int pendingRegs;
  final int totalDrivers;
  final int activeAlerts;
  final int liveBuses;

  AdminStats({
    required this.totalStudents,
    required this.activeBuses,
    required this.boardedToday,
    required this.pendingRegs,
    required this.totalDrivers,
    required this.activeAlerts,
    required this.liveBuses,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) => AdminStats(
        totalStudents: json['total_students'] ?? 0,
        activeBuses: json['active_buses'] ?? 0,
        boardedToday: json['boarded_today'] ?? 0,
        pendingRegs: json['pending_regs'] ?? 0,
        totalDrivers: json['total_drivers'] ?? 0,
        activeAlerts: json['active_alerts'] ?? 0,
        liveBuses: json['live_buses'] ?? 0,
      );
}

class EtaResponse {
  final String eta;
  final String nextStop;
  final String delay;
  final String distance;
  final List<String> remainingStops;

  EtaResponse({
    required this.eta,
    required this.nextStop,
    this.delay = '--',
    this.distance = '--',
    this.remainingStops = const [],
  });

  factory EtaResponse.fromJson(Map<String, dynamic> json) => EtaResponse(
        eta: json['eta'] ?? '--',
        nextStop: json['next_stop'] ?? '--',
        delay: json['delay'] ?? '--',
        distance: json['distance'] ?? '--',
        remainingStops: List<String>.from(json['remaining_stops'] ?? []),
      );
}

class GenericResponse {
  final String status;
  final String? message;

  GenericResponse({required this.status, this.message});

  factory GenericResponse.fromJson(Map<String, dynamic> json) => GenericResponse(
        status: json['status'] ?? '',
        message: json['message'],
      );
}

// Backend: GET /api/admin/drivers
// Returns: id, name, phone, bus_id, bus_number, route_name, is_online
class Driver {
  final String id;
  final String name;
  final String? phone;
  final String? busId;
  final String? busNumber;
  final String? routeName;
  final bool isOnline;

  Driver({
    required this.id,
    required this.name,
    this.phone,
    this.busId,
    this.busNumber,
    this.routeName,
    this.isOnline = false,
  });

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        phone: json['phone'],
        busId: json['bus_id'],
        busNumber: json['bus_number'],
        routeName: json['route_name'],
        isOnline: json['is_online'] == true,
      );
}

// Backend: POST /api/rfid/tap
class RfidTapReq {
  final String rfidCard;
  final String busId;
  final String stopName;
  final double lat;
  final double lon;

  RfidTapReq({
    required this.rfidCard,
    required this.busId,
    this.stopName = '',
    this.lat = 0.0,
    this.lon = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'rfid_card': rfidCard,
        'bus_id': busId,
        'stop_name': stopName,
        'lat': lat,
        'lon': lon,
      };
}

class RfidTapRes {
  final String status;
  final String tapType;
  final String studentName;

  RfidTapRes({
    required this.status,
    required this.tapType,
    required this.studentName,
  });

  factory RfidTapRes.fromJson(Map<String, dynamic> json) => RfidTapRes(
        status: json['status'] ?? '',
        tapType: json['tap_type'] ?? '',
        studentName: json['student_name'] ?? '',
      );
}

class Registration {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? collegeId;
  final String? rfidCard;
  final String? busId;
  final String? parentOf;
  final String? phone;
  final String status;
  final String? submittedAt;

  Registration({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.collegeId,
    this.rfidCard,
    this.busId,
    this.parentOf,
    this.phone,
    required this.status,
    this.submittedAt,
  });

  factory Registration.fromJson(Map<String, dynamic> json) => Registration(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        role: json['role'] ?? 'student',
        collegeId: json['college_id'],
        rfidCard: json['rfid_card'],
        busId: json['bus_id'],
        parentOf: json['parent_of'],
        phone: json['phone'],
        status: json['status'] ?? 'pending',
        submittedAt: json['submitted_at'],
      );
}

class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? collegeId;
  final String? rfidCard;
  final String? busId;
  final String? parentOf;
  final String? phone;
  final int isActive;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.collegeId,
    this.rfidCard,
    this.busId,
    this.parentOf,
    this.phone,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        role: json['role'] ?? 'student',
        collegeId: json['college_id'],
        rfidCard: json['rfid_card'],
        busId: json['bus_id'],
        parentOf: json['parent_of'],
        phone: json['phone'],
        isActive: json['is_active'] ?? 1,
      );
}

class EmergencyAssignmentResponse {
  final String emergencyId;
  final String brokenBusId;
  final String brokenBusNumber;
  final double lat;
  final double lon;
  final int studentsWaiting;
  final List<String> remainingStops;
  final String status;
  final String? backupBusNumber;
  final String? backupDriverName;
  final int? etaMinutes;

  EmergencyAssignmentResponse({
    required this.emergencyId,
    required this.brokenBusId,
    required this.brokenBusNumber,
    required this.lat,
    required this.lon,
    required this.studentsWaiting,
    required this.remainingStops,
    required this.status,
    this.backupBusNumber,
    this.backupDriverName,
    this.etaMinutes,
  });

  factory EmergencyAssignmentResponse.fromJson(Map<String, dynamic> json) =>
      EmergencyAssignmentResponse(
        emergencyId: json['id'] ?? '',
        brokenBusId: json['bus_id'] ?? '',
        brokenBusNumber: json['bus_number'] ?? '',
        lat: (json['gps']?['lat'] ?? 0.0).toDouble(),
        lon: (json['gps']?['lon'] ?? 0.0).toDouble(),
        studentsWaiting: (json['students_onboard'] as List?)?.length ?? 0,
        remainingStops: List<String>.from(json['remaining_stops'] ?? []),
        status: json['status'] ?? '',
        backupBusNumber: json['backup_bus_number'],
        backupDriverName: json['backup_driver_name'],
        etaMinutes: json['eta_minutes'],
      );
}
