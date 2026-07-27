import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/app_config.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _collegeIdCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  
  String _selectedRole = 'student';
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _collegeIdCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty || 
        _emailCtrl.text.trim().isEmpty || 
        _passwordCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: AppColors.warningYellow,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
      final res = await dio.post('/api/auth/register', data: {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text.trim(),
        'role': _selectedRole,
        'college_id': _collegeIdCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'requested_bus': '',
        'rfid_card': '',
        'parent_child_id': ''
      });

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.data['message'] ?? 'Registration submitted successfully!'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      
      // Navigate back to login
      context.pop();
    } on DioException catch (e) {
      final msg = e.response?.data['detail'] ?? 'Registration failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.toString()),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Wave Header
            ClipPath(
              clipper: _TopWaveClipper(),
              child: Container(
                height: 220,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                ),
                child: SafeArea(
                  child: Stack(
                    children: [
                      Positioned(
                        top: 10,
                        left: 10,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => context.pop(),
                        ),
                      ),
                      const Positioned(
                        bottom: 50,
                        left: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Join the KRCE smart tracking system.',
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
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Role Selector
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'student', child: Text('Student')),
                      DropdownMenuItem(value: 'staff', child: Text('Staff')),
                      DropdownMenuItem(value: 'parent', child: Text('Parent')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRole = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Name
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // College ID
                  TextField(
                    controller: _collegeIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'College / Roll ID',
                      prefixIcon: Icon(Icons.numbers_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  TextField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Register Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Text('Register'),
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
}

// Custom Clipper for the Top Wave
class _TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 50);
    
    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2, size.height - 25);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy,
        firstEndPoint.dx, firstEndPoint.dy);
        
    var secondControlPoint = Offset(size.width - (size.width / 4), size.height - 50);
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
