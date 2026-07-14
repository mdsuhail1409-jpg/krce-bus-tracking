import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/premium_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showCredentials = false;
  bool _obscurePassword = true;

  static const _collegeLatLng = LatLng(10.927669, 78.7410);

  final List<Map<String, String>> _demoCredentials = [
    {'role': 'Admin', 'email': 'admin@krce.ac.in', 'password': 'admin@krce'},
    {'role': 'Driver', 'email': 'rajan@krce.ac.in', 'password': 'driver@123'},
    {'role': 'Student', 'email': 'aravind@krce.ac.in', 'password': 'student@123'},
    {'role': 'Parent', 'email': 'suresh.p@gmail.com', 'password': 'parent@123'},
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.trim().isEmpty) {
      return;
    }
    await ref
        .read(authProvider.notifier)
        .login(_emailCtrl.text.trim(), _passwordCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    // Error snackbar
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.error != null && next.error!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _collegeLatLng,
              zoom: 15,
            ),
            zoomControlsEnabled: false,
            compassEnabled: false,
            myLocationButtonEnabled: false,
            onMapCreated: (controller) {
              controller.setMapStyle('''
              [
                {
                  "elementType": "geometry",
                  "stylers": [{"color": "#212121"}]
                },
                {
                  "elementType": "labels.icon",
                  "stylers": [{"visibility": "off"}]
                },
                {
                  "elementType": "labels.text.fill",
                  "stylers": [{"color": "#757575"}]
                },
                {
                  "elementType": "labels.text.stroke",
                  "stylers": [{"color": "#212121"}]
                },
                {
                  "featureType": "road",
                  "elementType": "geometry.fill",
                  "stylers": [{"color": "#2c2c2c"}]
                },
                {
                  "featureType": "water",
                  "elementType": "geometry",
                  "stylers": [{"color": "#000000"}]
                }
              ]
              ''');
            },
          ),

          // Dark overlay
          Container(color: Colors.black.withOpacity(0.55)),

          // Settings button in top-right corner
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.settings, color: Colors.white70),
                onPressed: () => _showServerSettingsDialog(context),
              ),
            ),
          ),

          // Login form
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // Logo / title
                  const Text(
                    'KRCE BusTrack',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'K. Ramakrishnan College of Engineering',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 14),
                  ),
                  const SizedBox(height: 40),

                  // Login Card
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sign In',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Track your campus journey',
                          style: TextStyle(
                              color: AppColors.mutedText, fontSize: 13),
                        ),
                        const SizedBox(height: 28),
                        TextField(
                          controller: _emailCtrl,
                          style: const TextStyle(color: AppColors.textColor),
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: AppColors.textColor),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 32),
                        PremiumButton(
                          text: 'Sign In',
                          isLoading: auth.isLoading,
                          onPressed: _login,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Demo Credentials Card
                  GlassCard(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => setState(
                              () => _showCredentials = !_showCredentials),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '💡 Demo Credentials (Quick-Fill)',
                                style: TextStyle(
                                    color: AppColors.textColor,
                                    fontWeight: FontWeight.bold),
                              ),
                              Icon(
                                _showCredentials
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: AppColors.mutedText,
                              )
                            ],
                          ),
                        ),
                        if (_showCredentials) ...[
                          const SizedBox(height: 12),
                          ..._demoCredentials.map((c) => InkWell(
                                onTap: () {
                                  _emailCtrl.text = c['email']!;
                                  _passwordCtrl.text = c['password']!;
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppColors.borderColor),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c['role']!,
                                            style: const TextStyle(
                                                color: AppColors.indigoPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13),
                                          ),
                                          Text(c['email']!,
                                              style: const TextStyle(
                                                  color: AppColors.mutedText,
                                                  fontSize: 12)),
                                        ],
                                      ),
                                      const Text('Tap to fill',
                                          style: TextStyle(
                                              color: AppColors.mutedText,
                                              fontSize: 11)),
                                    ],
                                  ),
                                ),
                              )),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showServerSettingsDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUrl = prefs.getString('custom_api_url') ?? '';
    final ctrl = TextEditingController(text: currentUrl);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server Connection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter custom backend URL (leave blank to use default production Render server):',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.black87),
              decoration: const InputDecoration(
                hintText: 'https://example.com or http://ip:port',
                hintStyle: TextStyle(color: Colors.black38),
                labelText: 'Backend URL',
                labelStyle: TextStyle(color: Colors.black87),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              String enteredUrl = ctrl.text.trim();
              if (enteredUrl.isNotEmpty &&
                  !enteredUrl.startsWith('http://') &&
                  !enteredUrl.startsWith('https://')) {
                enteredUrl = 'http://$enteredUrl';
              }
              await prefs.setString('custom_api_url', enteredUrl);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      enteredUrl.isEmpty
                          ? 'Reset to default production URL'
                          : 'Server URL set to: $enteredUrl',
                    ),
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
