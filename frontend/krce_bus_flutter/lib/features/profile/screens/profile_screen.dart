import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/premium_button.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  String _message = '';
  bool _isChangingPassword = false;
  bool _showChangePw = false;

  @override
  void dispose() {
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      setState(() => _message = 'Passwords do not match');
      return;
    }
    setState(() => _isChangingPassword = true);
    final auth = ref.read(authProvider);
    final api = ref.read(apiServiceProvider);
    try {
      await api.changePassword(
          auth.token, _oldPassCtrl.text, _newPassCtrl.text);
      setState(() => _message = '✅ Password changed successfully');
      _oldPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
    } catch (e) {
      setState(() => _message = 'Failed to change password');
    } finally {
      setState(() => _isChangingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final roleLabel = {
          'admin': 'Administrator',
          'committee': 'Transport Committee',
          'driver': 'Bus Driver',
          'parent': 'Parent',
          'student': 'Student',
        }[auth.role] ??
        auth.role;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Profile',
            style: TextStyle(color: AppColors.textColor)),
        backgroundColor: AppColors.surfaceColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar + name
          Center(
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      auth.name.isNotEmpty
                          ? auth.name.substring(0, 1).toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(auth.name,
                    style: const TextStyle(
                        color: AppColors.textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                Text(roleLabel,
                    style:
                        const TextStyle(color: AppColors.indigoPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Info Card
          GlassCard(
            child: Column(
              children: [
                if (auth.collegeId != null)
                  _InfoRow(label: 'College ID', value: auth.collegeId!),
                if (auth.busId != null)
                  _InfoRow(label: 'Bus ID', value: auth.busId!),
                if (auth.parentOf != null)
                  _InfoRow(label: "Ward's ID", value: auth.parentOf!),
                if (auth.phone != null)
                  _InfoRow(label: 'Phone', value: auth.phone!),
                _InfoRow(label: 'Role', value: roleLabel),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Change Password
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () =>
                      setState(() => _showChangePw = !_showChangePw),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Change Password',
                          style: TextStyle(
                              color: AppColors.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Icon(
                        _showChangePw
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: AppColors.mutedText,
                      )
                    ],
                  ),
                ),
                if (_showChangePw) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _oldPassCtrl,
                    obscureText: true,
                    style: const TextStyle(color: AppColors.textColor),
                    decoration: const InputDecoration(
                        labelText: 'Current Password'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPassCtrl,
                    obscureText: true,
                    style: const TextStyle(color: AppColors.textColor),
                    decoration: const InputDecoration(
                        labelText: 'New Password'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPassCtrl,
                    obscureText: true,
                    style: const TextStyle(color: AppColors.textColor),
                    decoration: const InputDecoration(
                        labelText: 'Confirm New Password'),
                  ),
                  if (_message.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(_message,
                        style: TextStyle(
                            color: _message.startsWith('✅')
                                ? AppColors.successGreen
                                : AppColors.errorRed)),
                  ],
                  const SizedBox(height: 16),
                  PremiumButton(
                    text: 'Update Password',
                    isLoading: _isChangingPassword,
                    onPressed: _changePassword,
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Logout
          GestureDetector(
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.errorRed.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.logout, color: AppColors.errorRed),
                  SizedBox(width: 12),
                  Text('Sign Out',
                      style: TextStyle(
                          color: AppColors.errorRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.mutedText)),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textColor,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
