import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';

// ── Providers ─────────────────────────────────────────────
final apiServiceProvider = Provider((ref) => ApiService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(apiServiceProvider)),
);

// ── State ─────────────────────────────────────────────────
class AuthState {
  final String token;
  final String role;
  final String name;
  final String? busId;
  final String? collegeId;
  final String? parentOf;
  final String? phone;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.token = '',
    this.role = '',
    this.name = '',
    this.busId,
    this.collegeId,
    this.parentOf,
    this.phone,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => token.isNotEmpty;

  AuthState copyWith({
    String? token,
    String? role,
    String? name,
    String? busId,
    String? collegeId,
    String? parentOf,
    String? phone,
    bool? isLoading,
    String? error,
  }) =>
      AuthState(
        token: token ?? this.token,
        role: role ?? this.role,
        name: name ?? this.name,
        busId: busId ?? this.busId,
        collegeId: collegeId ?? this.collegeId,
        parentOf: parentOf ?? this.parentOf,
        phone: phone ?? this.phone,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Notifier ──────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;

  AuthNotifier(this._api) : super(const AuthState()) {
    _loadSavedSession();
  }

  Future<void> _loadSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final role = prefs.getString('user_role') ?? '';
    final name = prefs.getString('user_name') ?? '';
    final busId = prefs.getString('bus_id');
    final collegeId = prefs.getString('college_id');
    final parentOf = prefs.getString('parent_of');
    final phone = prefs.getString('phone');

    if (token.isNotEmpty) {
      state = state.copyWith(
        token: token,
        role: role,
        name: name,
        busId: busId,
        collegeId: collegeId,
        parentOf: parentOf,
        phone: phone,
      );
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.login(email, password);
      final token = 'Bearer ${res.token}';
      await _saveSession(res, token);
      state = state.copyWith(
        token: token,
        role: res.role,
        name: res.name,
        busId: res.busId,
        collegeId: res.collegeId,
        parentOf: res.parentOf,
        phone: res.phone,
        isLoading: false,
      );
    } catch (e) {
      // Demo mode fallback
      final demo = _tryDemoLogin(email, password);
      if (demo != null) {
        await _saveDemoSession(demo);
        state = state.copyWith(
          token: demo['token']!,
          role: demo['role']!,
          name: demo['name']!,
          busId: demo['busId'],
          collegeId: demo['collegeId'],
          parentOf: demo['parentOf'],
          phone: demo['phone'],
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Invalid credentials or server unreachable',
        );
      }
    }
  }

  Map<String, String?>? _tryDemoLogin(String email, String password) {
    final credentials = {
      'admin@krce.ac.in:admin@krce': {
        'token': 'demo_token_admin',
        'role': 'admin',
        'name': 'Admin Krishnamurthy (Demo)',
        'busId': null,
        'collegeId': null,
        'parentOf': null,
        'phone': '9840100001',
      },
      'rajan@krce.ac.in:driver@123': {
        'token': 'demo_token_driver',
        'role': 'driver',
        'name': 'Rajan S. (Demo)',
        'busId': 'B01',
        'collegeId': null,
        'parentOf': null,
        'phone': '9840111111',
      },
      'aravind@krce.ac.in:student@123': {
        'token': 'demo_token_student',
        'role': 'student',
        'name': 'Aravind Kumar (Demo)',
        'busId': 'B01',
        'collegeId': '21CS001',
        'parentOf': null,
        'phone': '9841100001',
      },
      'suresh.p@gmail.com:parent@123': {
        'token': 'demo_token_parent',
        'role': 'parent',
        'name': 'Suresh Kumar (Demo)',
        'busId': null,
        'collegeId': null,
        'parentOf': '21CS001',
        'phone': '9841300001',
      },
    };
    return credentials['$email:$password'];
  }

  Future<void> _saveSession(LoginRes res, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_role', res.role);
    await prefs.setString('user_name', res.name);
    if (res.busId != null) await prefs.setString('bus_id', res.busId!);
    if (res.collegeId != null) await prefs.setString('college_id', res.collegeId!);
    if (res.parentOf != null) await prefs.setString('parent_of', res.parentOf!);
    if (res.phone != null) await prefs.setString('phone', res.phone!);
  }

  Future<void> _saveDemoSession(Map<String, String?> demo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', demo['token']!);
    await prefs.setString('user_role', demo['role']!);
    await prefs.setString('user_name', demo['name']!);
    if (demo['busId'] != null) await prefs.setString('bus_id', demo['busId']!);
    if (demo['collegeId'] != null) await prefs.setString('college_id', demo['collegeId']!);
    if (demo['parentOf'] != null) await prefs.setString('parent_of', demo['parentOf']!);
    if (demo['phone'] != null) await prefs.setString('phone', demo['phone']!);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = const AuthState();
  }
}
