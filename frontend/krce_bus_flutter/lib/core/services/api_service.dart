import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/models.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
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
    final res = await _dio.get('/api/buses',
        options: Options(headers: _authHeader(token)));
    return (res.data as List).map((e) => Bus.fromJson(e)).toList();
  }

  Future<Bus> getBusDetails(String token, String busId) async {
    final res = await _dio.get('/api/buses/$busId',
        options: Options(headers: _authHeader(token)));
    return Bus.fromJson(res.data);
  }

  Future<LiveBus> getBusLive(String token, String busId) async {
    final res = await _dio.get('/api/buses/$busId/live',
        options: Options(headers: _authHeader(token)));
    return LiveBus.fromJson(res.data);
  }

  // ── Alerts ────────────────────────────────────────────────
  Future<List<Alert>> getAlerts(String token) async {
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
    final res = await _dio.post('/api/driver/emergency',
        options: Options(headers: _authHeader(token)));
    return GenericResponse.fromJson(res.data);
  }

  Future<List<Passenger>> getBusPassengers(String token, String busId) async {
    final res = await _dio.get('/api/buses/$busId/passengers',
        options: Options(headers: _authHeader(token)));
    return (res.data as List).map((e) => Passenger.fromJson(e)).toList();
  }

  // ── Attendance ────────────────────────────────────────────
  Future<List<Attendance>> getMyAttendance(String token) async {
    final res = await _dio.get('/api/my/attendance',
        options: Options(headers: _authHeader(token)));
    return (res.data as List).map((e) => Attendance.fromJson(e)).toList();
  }

  Future<List<Attendance>> getAllAttendance(String token) async {
    final res = await _dio.get('/api/admin/attendance',
        options: Options(headers: _authHeader(token)));
    return (res.data as List).map((e) => Attendance.fromJson(e)).toList();
  }

  Future<List<Attendance>> getChildAttendance(String token) async {
    final res = await _dio.get('/api/my/child-attendance',
        options: Options(headers: _authHeader(token)));
    return (res.data as List).map((e) => Attendance.fromJson(e)).toList();
  }

  // ── Admin ─────────────────────────────────────────────────
  Future<AdminStats> getAdminStats(String token) async {
    final res = await _dio.get('/api/admin/stats',
        options: Options(headers: _authHeader(token)));
    return AdminStats.fromJson(res.data);
  }

  // ── ETA ───────────────────────────────────────────────────
  Future<EtaResponse> getMyEta(String token) async {
    final res = await _dio.get('/api/my/eta',
        options: Options(headers: _authHeader(token)));
    return EtaResponse.fromJson(res.data);
  }

  // ── Profile ───────────────────────────────────────────────
  Future<GenericResponse> changePassword(
      String token, String oldPassword, String newPassword) async {
    final res = await _dio.post('/api/my/change-password',
        data: {'old_password': oldPassword, 'new_password': newPassword},
        options: Options(headers: _authHeader(token)));
    return GenericResponse.fromJson(res.data);
  }

  // ── Admin Users ───────────────────────────────────────────
  Future<List<User>> getAdminUsers(String token, {String role = ""}) async {
    final res = await _dio.get('/api/admin/users',
        queryParameters: role.isNotEmpty ? {'role': role} : null,
        options: Options(headers: _authHeader(token)));
    return (res.data as List).map((e) => User.fromJson(e)).toList();
  }

  Future<GenericResponse> toggleUser(String token, String userId) async {
    final res = await _dio.post('/api/admin/users/$userId/toggle',
        options: Options(headers: _authHeader(token)));
    return GenericResponse.fromJson(res.data);
  }

  // ── Admin Registrations ────────────────────────────────────
  Future<List<Registration>> getAdminRegistrations(String token, {String status = "pending"}) async {
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
    final res = await _dio.post('/api/admin/alerts/$alertId/resolve',
        options: Options(headers: _authHeader(token)));
    return GenericResponse.fromJson(res.data);
  }
}
