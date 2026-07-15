import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/models.dart';

class ApiService {
  late final Dio _dio;

  // Held externally so the 401 interceptor can call refreshSession()
  Future<bool> Function()? onTokenExpired;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));

    // Dynamic base URL interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final customUrl = prefs.getString('custom_api_url') ?? '';
        if (customUrl.isNotEmpty) {
          options.baseUrl = customUrl;
        }
        return handler.next(options);
      },
      onError: (DioException err, handler) async {
        // Auto-refresh on 401 Unauthorized (token expired)
        if (err.response?.statusCode == 401 && onTokenExpired != null) {
          final refreshed = await onTokenExpired!();
          if (refreshed) {
            // Retry the original request with the new token from SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            final newToken = prefs.getString('auth_token') ?? '';
            final opts = err.requestOptions;
            opts.headers['Authorization'] = newToken;
            try {
              final response = await _dio.fetch(opts);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(err);
            }
          }
        }
        return handler.next(err);
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (o) => print(o),
    ));
  }

  Map<String, String> _authHeader(String token) => {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
      };

  // ── Auth ──────────────────────────────────────────────────
  Future<LoginRes> login(String email, String password) async {
    final res = await _dio.post('/api/auth/login',
        data: {'email': email, 'password': password});
    return LoginRes.fromJson(res.data);
  }

  // ── Buses ─────────────────────────────────────────────────
  Future<List<Bus>> getBuses(String token) async {
    if (token.startsWith('demo_token_')) {
      return [
        Bus(
          id: 'B01',
          number: 'TN-01',
          routeName: 'Route A — Woraiyur',
          driverId: 'drv01',
          driverName: 'Rajan S. (Demo)',
          driverPhone: '9840111111',
          capacity: 50,
          stops: ['KRCE Campus', 'Samayapuram', 'Woraiyur Bus Stand', 'Woraiyur Town', 'Gandhi Market', 'KRCE Campus'],
          live: LiveBus(
            busId: 'B01',
            driverId: 'drv01',
            driverName: 'Rajan S. (Demo)',
            lat: 10.7905,
            lon: 78.7047,
            speed: 40.0,
            heading: 90.0,
            passengers: 12,
            updatedAt: DateTime.now().millisecondsSinceEpoch / 1000,
            status: 'online',
          ),
          boardedToday: 15,
        ),
        Bus(
          id: 'B02',
          number: 'TN-02',
          routeName: 'Route B — Srirangam',
          driverId: 'drv02',
          driverName: 'Murugan K. (Demo)',
          driverPhone: '9840122222',
          capacity: 45,
          stops: ['KRCE Campus', 'Panjappur', 'Srirangam', 'Cauvery Bridge', 'K.K. Nagar', 'KRCE Campus'],
          boardedToday: 8,
        ),
      ];
    }
    final res = await _dio.get('/api/buses',
        options: Options(headers: _authHeader(token)));
    return (res.data as List).map((e) => Bus.fromJson(e)).toList();
  }

  Future<Bus> getBusDetails(String token, String busId) async {
    if (token.startsWith('demo_token_')) {
      return Bus(
        id: busId,
        number: busId == 'B02' ? 'TN-02' : 'TN-01',
        routeName: busId == 'B02' ? 'Route B — Srirangam' : 'Route A — Woraiyur',
        driverId: busId == 'B02' ? 'drv02' : 'drv01',
        driverName: busId == 'B02' ? 'Murugan K. (Demo)' : 'Rajan S. (Demo)',
        driverPhone: busId == 'B02' ? '9840122222' : '9840111111',
        capacity: busId == 'B02' ? 45 : 50,
        stops: busId == 'B02'
            ? ['KRCE Campus', 'Panjappur', 'Srirangam', 'Cauvery Bridge', 'K.K. Nagar', 'KRCE Campus']
            : ['KRCE Campus', 'Samayapuram', 'Woraiyur Bus Stand', 'Woraiyur Town', 'Gandhi Market', 'KRCE Campus'],
        boardedToday: busId == 'B02' ? 8 : 15,
      );
    }
    final res = await _dio.get('/api/buses/$busId',
        options: Options(headers: _authHeader(token)));
    return Bus.fromJson(res.data);
  }

  Future<LiveBus> getBusLive(String token, String busId) async {
    if (token.startsWith('demo_token_')) {
      return LiveBus(
        busId: busId,
        driverId: 'drv01',
        driverName: 'Rajan S. (Demo)',
        lat: 10.7905,
        lon: 78.7047,
        speed: 42.5,
        heading: 180.0,
        passengers: 15,
        updatedAt: DateTime.now().millisecondsSinceEpoch / 1000,
        status: 'online',
      );
    }
    final res = await _dio.get('/api/buses/$busId/live',
        options: Options(headers: _authHeader(token)));
    return LiveBus.fromJson(res.data);
  }

  // ── Alerts ────────────────────────────────────────────────
  Future<List<Alert>> getAlerts(String token) async {
    if (token.startsWith('demo_token_')) {
      return [
        Alert(
          id: 'A1',
          title: 'Welcome to KRCE Bus Tracker',
          message: 'The new real-time bus tracking system is now live. Your bus location updates every 5 seconds.',
          alertType: 'info',
          targetRole: 'all',
          sentAt: DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
          isResolved: 0,
        ),
        Alert(
          id: 'A2',
          title: 'Route A — Minor Delay',
          message: 'Bus TN-01 is running approximately 10 minutes late due to traffic near Woraiyur Junction.',
          alertType: 'delay',
          targetRole: 'all',
          targetBus: 'B01',
          sentAt: DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
          isResolved: 0,
        ),
      ];
    }
    final res = await _dio.get('/api/alerts',
        options: Options(headers: _authHeader(token)));
    return (res.data as List).map((e) => Alert.fromJson(e)).toList();
  }

  // ── Driver ────────────────────────────────────────────────
  Future<GenericResponse> pushGps(String token,
      {required double lat,
      required double lon,
      double speed = 0,
      double heading = 0,
      int passengers = 0}) async {
    if (token.startsWith('demo_token_')) {
      return GenericResponse(status: 'ok', message: 'GPS updated (Demo)');
    }
    final res = await _dio.post('/api/driver/gps',
        data: {
          'lat': lat,
          'lon': lon,
          'speed': speed,
          'heading': heading,
          'passengers': passengers,
        },
        options: Options(headers: _authHeader(token)));
    return GenericResponse.fromJson(res.data);
  }

  Future<GenericResponse> triggerSos(String token) async {
    if (token.startsWith('demo_token_')) {
      return GenericResponse(status: 'ok', message: 'SOS signal sent (Demo)');
    }
    final res = await _dio.post('/api/driver/emergency',
        options: Options(headers: _authHeader(token)));
    return GenericResponse.fromJson(res.data);
  }

  Future<List<Passenger>> getBusPassengers(String token, String busId) async {
    if (token.startsWith('demo_token_')) {
      return [
        Passenger(
          name: 'Aravind Kumar',
          collegeId: '21CS001',
          rfidCard: 'RF001',
          tapType: 'boarded',
          tapTime: '08:30',
          stopName: 'Woraiyur Bus Stand',
        ),
        Passenger(
          name: 'Nandhini R',
          collegeId: '21CS004',
          rfidCard: 'RF004',
          tapType: 'boarded',
          tapTime: '08:45',
          stopName: 'Samayapuram',
        ),
      ];
    }
    final res = await _dio.get('/api/buses/$busId/passengers',
        options: Options(headers: _authHeader(token)));
    return (res.data as List).map((e) => Passenger.fromJson(e)).toList();
  }

  // ── Attendance ────────────────────────────────────────────
  Future<List<Attendance>> getMyAttendance(String token) async {
    if (token.startsWith('demo_token_')) {
      return [
        Attendance(
          id: 'ATT01',
          userId: 'stu01',
          busId: 'B01',
          tapType: 'boarded',
          tapTime: '2026-07-15T08:30:00',
          stopName: 'Woraiyur Bus Stand',
          lat: 10.7905,
          lon: 78.7047,
          date: '2026-07-15',
          studentName: 'Aravind Kumar (Demo)',
          collegeId: '21CS001',
          busNumber: 'TN-01',
          routeName: 'Route A — Woraiyur',
        ),
      ];
    }
    final res = await _dio.get('/api/my/attendance',
        options: Options(headers: _authHeader(token)));
    return (res.data as List).map((e) => Attendance.fromJson(e)).toList();
  }

  Future<List<Attendance>> getAllAttendance(String token) async {
    if (token.startsWith('demo_token_')) {
      return [
        Attendance(
          id: 'ATT01',
          userId: 'stu01',
          busId: 'B01',
          tapType: 'boarded',
          tapTime: '2026-07-15T08:30:00',
          stopName: 'Woraiyur Bus Stand',
          lat: 10.7905,
          lon: 78.7047,
          date: '2026-07-15',
          studentName: 'Aravind Kumar',
          collegeId: '21CS001',
          busNumber: 'TN-01',
          routeName: 'Route A — Woraiyur',
        ),
        Attendance(
          id: 'ATT02',
          userId: 'stu02',
          busId: 'B02',
          tapType: 'boarded',
          tapTime: '2026-07-15T08:35:00',
          stopName: 'Srirangam',
          lat: 10.8631,
          lon: 78.6933,
          date: '2026-07-15',
          studentName: 'Priya Devi',
          collegeId: '21EC002',
          busNumber: 'TN-02',
          routeName: 'Route B — Srirangam',
        ),
      ];
    }
    final res = await _dio.get('/api/admin/attendance',
        options: Options(headers: _authHeader(token)));
    return (res.data as List).map((e) => Attendance.fromJson(e)).toList();
  }

  Future<List<Attendance>> getChildAttendance(String token) async {
    if (token.startsWith('demo_token_')) {
      return [
        Attendance(
          id: 'ATT01',
          userId: 'stu01',
          busId: 'B01',
          tapType: 'boarded',
          tapTime: '2026-07-15T08:30:00',
          stopName: 'Woraiyur Bus Stand',
          lat: 10.7905,
          lon: 78.7047,
          date: '2026-07-15',
          studentName: 'Aravind Kumar (Demo)',
          collegeId: '21CS001',
          busNumber: 'TN-01',
          routeName: 'Route A — Woraiyur',
        ),
      ];
    }
    final res = await _dio.get('/api/my/child-attendance',
        options: Options(headers: _authHeader(token)));
    return (res.data as List).map((e) => Attendance.fromJson(e)).toList();
  }

  // ── Admin ─────────────────────────────────────────────────
  Future<AdminStats> getAdminStats(String token) async {
    if (token.startsWith('demo_token_')) {
      return AdminStats(
        totalStudents: 450,
        activeBuses: 12,
        boardedToday: 380,
        pendingRegs: 5,
        totalDrivers: 14,
        activeAlerts: 2,
        liveBuses: 8,
      );
    }
    final res = await _dio.get('/api/admin/stats',
        options: Options(headers: _authHeader(token)));
    return AdminStats.fromJson(res.data);
  }

  // ── ETA ───────────────────────────────────────────────────
  Future<EtaResponse> getMyEta(String token) async {
    if (token.startsWith('demo_token_')) {
      return EtaResponse(
        eta: '12 min',
        nextStop: 'Samayapuram',
        delay: '2 min',
        distance: '3.5 km',
        remainingStops: ['Samayapuram', 'Woraiyur Bus Stand', 'Woraiyur Town'],
      );
    }
    final res = await _dio.get('/api/my/eta',
        options: Options(headers: _authHeader(token)));
    return EtaResponse.fromJson(res.data);
  }

  // ── Profile ───────────────────────────────────────────────
  Future<GenericResponse> changePassword(
      String token, String oldPassword, String newPassword) async {
    if (token.startsWith('demo_token_')) {
      return GenericResponse(status: 'ok', message: 'Password updated (Demo)');
    }
    final res = await _dio.post('/api/my/change-password',
        data: {'old_password': oldPassword, 'new_password': newPassword},
        options: Options(headers: _authHeader(token)));
    return GenericResponse.fromJson(res.data);
  }

  // ── Admin Users ───────────────────────────────────────────
  Future<List<User>> getAdminUsers(String token, {String role = ""}) async {
    if (token.startsWith('demo_token_')) {
      return [
        User(
          id: 'stu01',
          name: 'Aravind Kumar',
          email: 'aravind@krce.ac.in',
          role: 'student',
          collegeId: '21CS001',
          rfidCard: 'RF001',
          busId: 'B01',
          isActive: 1,
        ),
        User(
          id: 'drv01',
          name: 'Rajan S.',
          email: 'rajan@krce.ac.in',
          role: 'driver',
          busId: 'B01',
          isActive: 1,
        ),
      ];
    }
    final res = await _dio.get('/api/admin/users',
        queryParameters: role.isNotEmpty ? {'role': role} : null,
        options: Options(headers: _authHeader(token)));
    return (res.data as List).map((e) => User.fromJson(e)).toList();
  }

  Future<GenericResponse> toggleUser(String token, String userId) async {
    if (token.startsWith('demo_token_')) {
      return GenericResponse(status: 'ok', message: 'User status toggled (Demo)');
    }
    final res = await _dio.post('/api/admin/users/$userId/toggle',
        options: Options(headers: _authHeader(token)));
    return GenericResponse.fromJson(res.data);
  }

  // ── Admin Registrations ────────────────────────────────────
  Future<List<Registration>> getAdminRegistrations(String token, {String status = "pending"}) async {
    if (token.startsWith('demo_token_')) {
      return [
        Registration(
          id: 'REG01',
          name: 'Suresh Kumar',
          email: 'suresh.p@gmail.com',
          role: 'parent',
          parentOf: '21CS001',
          status: 'pending',
          submittedAt: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        ),
      ];
    }
    final res = await _dio.get('/api/admin/registrations',
        queryParameters: {'status': status},
        options: Options(headers: _authHeader(token)));
    return (res.data as List).map((e) => Registration.fromJson(e)).toList();
  }

  Future<GenericResponse> actionRegistration(
      String token, {
      required String regId,
      required String action,
      required String notes,
      String? rfidCard,
      String? busId,
  }) async {
    if (token.startsWith('demo_token_')) {
      return GenericResponse(status: 'ok', message: 'Registration approved/rejected (Demo)');
    }
    final res = await _dio.post('/api/admin/registrations/action',
        data: {
          'reg_id': regId,
          'action': action,
          'notes': notes,
          'rfid_card': rfidCard,
          'bus_id': busId,
        },
        options: Options(headers: _authHeader(token)));
    return GenericResponse.fromJson(res.data);
  }

  // ── Admin Alerts ──────────────────────────────────────────
  Future<GenericResponse> sendAlert(
      String token, {
      required String title,
      required String message,
      required String alertType,
      required String targetRole,
      String? targetBus,
  }) async {
    if (token.startsWith('demo_token_')) {
      return GenericResponse(status: 'ok', message: 'Alert broadcasted (Demo)');
    }
    final res = await _dio.post('/api/admin/alerts',
        data: {
          'title': title,
          'message': message,
          'alert_type': alertType,
          'target_role': targetRole,
          'target_bus': targetBus,
        },
        options: Options(headers: _authHeader(token)));
    return GenericResponse.fromJson(res.data);
  }

  Future<GenericResponse> resolveAlert(String token, String alertId) async {
    if (token.startsWith('demo_token_')) {
      return GenericResponse(status: 'ok', message: 'Alert resolved (Demo)');
    }
    final res = await _dio.post('/api/admin/alerts/$alertId/resolve',
        options: Options(headers: _authHeader(token)));
    return GenericResponse.fromJson(res.data);
  }

  // ── Admin Drivers ─────────────────────────────────────────
  Future<List<Driver>> getDrivers(String token) async {
    if (token.startsWith('demo_token_')) {
      return [
        Driver(
          id: 'drv01',
          name: 'Rajan S.',
          phone: '9840111111',
          busId: 'B01',
          busNumber: 'TN-01',
          routeName: 'Route A — Woraiyur',
          isOnline: true,
        ),
      ];
    }
    final res = await _dio.get('/api/admin/drivers',
        options: Options(headers: _authHeader(token)));
    return (res.data as List).map((e) => Driver.fromJson(e)).toList();
  }

  // ── RFID ──────────────────────────────────────────────────
  Future<RfidTapRes> rfidTap(String token, RfidTapReq req) async {
    if (token.startsWith('demo_token_')) {
      return RfidTapRes(
        status: 'ok',
        tapType: 'boarded',
        studentName: 'Aravind Kumar (Demo)',
      );
    }
    final res = await _dio.post('/api/rfid/tap',
        data: req.toJson(),
        options: Options(headers: _authHeader(token)));
    return RfidTapRes.fromJson(res.data);
  }

  // ── Token Refresh ─────────────────────────────────────────
  Future<Map<String, String>> refreshToken(String refreshToken) async {
    final res = await _dio.post('/api/auth/refresh',
        data: {'refresh_token': refreshToken});
    return {
      'token': res.data['token'] ?? '',
      'refresh_token': res.data['refresh_token'] ?? '',
    };
  }

  // ── Breakdown Emergency Module ──────────────────────────────
  Future<GenericResponse> reportBreakdown(String token, double lat, double lon) async {
    if (token.startsWith('demo_token_')) {
      return GenericResponse(status: 'ok', message: 'Breakdown reported (Demo)');
    }
    final res = await _dio.post('/api/driver/breakdown',
        data: {'lat': lat, 'lon': lon, 'emergency_type': 'breakdown'},
        options: Options(headers: _authHeader(token)));
    return GenericResponse.fromJson(res.data);
  }

  Future<EmergencyAssignmentResponse?> getEmergencyAssignment(String token) async {
    if (token.startsWith('demo_token_')) {
      return null;
    }
    try {
      final res = await _dio.get('/api/driver/emergency-assignment',
          options: Options(headers: _authHeader(token)));
      if (res.data == null) return null;
      return EmergencyAssignmentResponse.fromJson(res.data);
    } catch (e) {
      return null;
    }
  }

  Future<GenericResponse> acceptEmergencyAssignment(String token, String emergencyId) async {
    if (token.startsWith('demo_token_')) {
      return GenericResponse(status: 'ok', message: 'Assignment accepted (Demo)');
    }
    final res = await _dio.post('/api/driver/emergency-assignment/$emergencyId/accept',
        options: Options(headers: _authHeader(token)));
    return GenericResponse.fromJson(res.data);
  }

  Future<GenericResponse> rejectEmergencyAssignment(String token, String emergencyId) async {
    if (token.startsWith('demo_token_')) {
      return GenericResponse(status: 'ok', message: 'Assignment rejected (Demo)');
    }
    final res = await _dio.post('/api/driver/emergency-assignment/$emergencyId/reject',
        options: Options(headers: _authHeader(token)));
    return GenericResponse.fromJson(res.data);
  }

  Future<EmergencyAssignmentResponse?> getActiveEmergency(String token) async {
    if (token.startsWith('demo_token_')) {
      return null;
    }
    try {
      final res = await _dio.get('/api/user/active-emergency',
          options: Options(headers: _authHeader(token)));
      if (res.data == null) return null;
      return EmergencyAssignmentResponse.fromJson(res.data);
    } catch (e) {
      return null;
    }
  }
}
