import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _rollNoCtrl = TextEditingController();

  final _apiService = ApiService();

  bool _isLoading = false;
  bool _isSubmitted = false;
  String? _submittedName;
  String? _submittedEmail;
  String? _submittedRole;
  String? _responseMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _rollNoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final rollNo = _rollNoCtrl.text.trim();

    if (name.isEmpty) {
      _showSnack('Please enter your full name', AppColors.warningYellow);
      return;
    }
    if (email.isEmpty) {
      _showSnack('Please enter your registered email address', AppColors.warningYellow);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await _apiService.submitPasswordResetRequest(
        name: name,
        email: email,
        rollNo: rollNo,
      );

      setState(() {
        _isSubmitted = true;
        _submittedName = res['user_name'] ?? name;
        _submittedEmail = email;
        _submittedRole = res['role'] ?? 'Student';
        _responseMessage = res['message'];
      });

      _showSnack(
        res['message'] ?? 'Password reset request submitted successfully!',
        AppColors.successGreen,
      );
    } on DioException catch (e) {
      final msg = e.response?.data['detail'] ?? 'Could not find matching account. Please verify your details.';
      _showSnack(msg.toString(), AppColors.errorRed);
    } catch (e) {
      _showSnack('Connection error: $e', AppColors.errorRed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Banner with back button
            ClipPath(
              clipper: _TopWaveClipper(),
              child: Container(
                height: 220,
                decoration: const BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                          onPressed: () => context.pop(),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Forgot Password',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 48, top: 4),
                      child: Text(
                        'Request admin password reset permission',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Form Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _isSubmitted ? _buildSubmittedCard() : _buildRequestForm(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.admin_panel_settings_outlined, color: AppColors.indigoPrimary, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Admin Reset Request',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your registered name, email, and roll number. The transit administrator will verify your request and approve your temporary password reset.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.mutedText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Full Name
              TextField(
                controller: _nameCtrl,
                keyboardType: TextInputType.name,
                decoration: InputDecoration(
                  labelText: 'Full Name *',
                  hintText: 'e.g. Jacob Immanuvel',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 16),

              // Email
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Registered Email ID *',
                  hintText: 'e.g. jacob@krce.ac.in',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 16),

              // Roll No / College ID
              TextField(
                controller: _rollNoCtrl,
                decoration: InputDecoration(
                  labelText: 'Roll No / College ID',
                  hintText: 'e.g. ADA24038 (Optional for Parents/Drivers)',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  helperText: 'Required for Students/Staff, optional for Parents',
                  helperStyle: const TextStyle(fontSize: 11, color: AppColors.mutedText),
                ),
                onSubmitted: (_) => _submitRequest(),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.indigoPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Send Request to Admin',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, size: 16, color: AppColors.mutedText),
            label: const Text(
              'Back to Login',
              style: TextStyle(color: AppColors.indigoPrimary, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmittedCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline, color: AppColors.successGreen, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Request Sent to Admin!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _responseMessage ??
                    'Your password reset request has been forwarded to the Transit Administrator.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.mutedText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Summary box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _summaryRow('Name', _submittedName ?? '—'),
                    const Divider(height: 12),
                    _summaryRow('Email', _submittedEmail ?? '—'),
                    const Divider(height: 12),
                    _summaryRow('Role', _submittedRole?.toUpperCase() ?? 'STUDENT'),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningYellow.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warningYellow.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: AppColors.warningYellow),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Once approved by the Administrator, your temporary password (e.g. student@123 / parent@123) will be activated for login.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.indigoPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text(
                  'Back to Login',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.mutedText)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textColor)),
      ],
    );
  }
}

class _TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 40);

    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2, size.height - 20);
    path.quadraticBezierTo(
        firstControlPoint.dx, firstControlPoint.dy, firstEndPoint.dx, firstEndPoint.dy);

    var secondControlPoint = Offset(size.width - (size.width / 4), size.height - 40);
    var secondEndPoint = Offset(size.width, size.height - 10);
    path.quadraticBezierTo(
        secondControlPoint.dx, secondControlPoint.dy, secondEndPoint.dx, secondEndPoint.dy);

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
