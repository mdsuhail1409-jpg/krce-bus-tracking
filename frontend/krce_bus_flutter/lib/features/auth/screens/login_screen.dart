import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

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
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Wave Header
            ClipPath(
              clipper: _TopWaveClipper(),
              child: Container(
                height: 250,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                ),
                child: SafeArea(
                  child: Stack(
                    children: [
                      Positioned(
                        top: 10,
                        right: 16,
                        child: IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white),
                          onPressed: () => _showServerSettingsDialog(context),
                        ),
                      ),
                      const Positioned(
                        bottom: 60,
                        left: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome Back',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Track your college bus in real time.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  // Email Field
                  TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  // Password Field
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
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
                  const SizedBox(height: 16),
                  
                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // TODO: Implement forgot password
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Login Button
                  ElevatedButton(
                    onPressed: auth.isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Text('Login'),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Create Account
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'New user? ',
                        style: TextStyle(color: AppColors.mutedText),
                      ),
                      GestureDetector(
                        onTap: () {
                          context.push('/register');
                        },
                        child: const Text(
                          'Register Now',
                          style: TextStyle(
                            color: AppColors.indigoPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
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
              'Enter custom backend URL:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'https://example.com',
                labelText: 'Backend URL',
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
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// Custom Clipper for the Top Wave
class _TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 60);
    
    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2, size.height - 30);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy,
        firstEndPoint.dx, firstEndPoint.dy);
        
    var secondControlPoint = Offset(size.width - (size.width / 4), size.height - 60);
    var secondEndPoint = Offset(size.width, size.height - 10);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy,
        secondEndPoint.dx, secondEndPoint.dy);
        
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
