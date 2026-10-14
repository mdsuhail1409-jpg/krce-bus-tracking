import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class PasswordResetsScreen extends ConsumerStatefulWidget {
  const PasswordResetsScreen({super.key});

  @override
  ConsumerState<PasswordResetsScreen> createState() => _PasswordResetsScreenState();
}

class _PasswordResetsScreenState extends ConsumerState<PasswordResetsScreen> {
  List<dynamic> _requests = [];
  bool _isLoading = true;
  String _filter = 'pending';

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    final auth = ref.read(authProvider);
    final api = ref.read(apiServiceProvider);
    try {
      final res = await api.getAdminPasswordResets(auth.token, status: _filter);
      if (mounted) {
        setState(() {
          _requests = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load password resets: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Future<void> _showApproveDialog(Map<String, dynamic> req) async {
    final reqId = req['id'] as String;
    final userName = req['name'] ?? 'User';
    final userRole = req['role'] ?? 'student';
    final defaultPassword = '${userRole}@123';
    final passwordController = TextEditingController(text: defaultPassword);

    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.lock_reset, color: AppColors.successGreen),
            SizedBox(width: 8),
            Text('Approve Password Reset', style: TextStyle(color: AppColors.textColor, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set temporary login password for $userName:', style: const TextStyle(color: AppColors.textColor, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              style: const TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Temporary Password',
                labelStyle: const TextStyle(color: AppColors.mutedText),
                filled: true,
                fillColor: AppColors.backgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'User can log in with this temporary password immediately.',
              style: TextStyle(color: AppColors.mutedText, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.mutedText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve & Set Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (proceed == true) {
      final tempPassword = passwordController.text.trim();
      if (tempPassword.isEmpty) return;

      final auth = ref.read(authProvider);
      final api = ref.read(apiServiceProvider);
      try {
        final res = await api.actionAdminPasswordReset(
          token: auth.token,
          reqId: reqId,
          action: 'approve',
          tempPassword: tempPassword,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? 'Password reset approved! Temporary password: $tempPassword'),
              backgroundColor: AppColors.successGreen,
              duration: const Duration(seconds: 4),
            ),
          );
          _fetchRequests();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.errorRed),
          );
        }
      }
    }
  }

  Future<void> _handleReject(Map<String, dynamic> req) async {
    final reqId = req['id'] as String;
    final auth = ref.read(authProvider);
    final api = ref.read(apiServiceProvider);
    try {
      final res = await api.actionAdminPasswordReset(
        token: auth.token,
        reqId: reqId,
        action: 'reject',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Request rejected'), backgroundColor: AppColors.errorRed),
        );
        _fetchRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceColor,
        elevation: 0,
        title: const Text(
          'Password Reset Requests',
          style: TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textColor),
      ),
      body: Column(
        children: [
          // Filter Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('Pending', 'pending'),
                const SizedBox(width: 8),
                _buildFilterChip('Approved', 'approved'),
                const SizedBox(width: 8),
                _buildFilterChip('All', 'all'),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _requests.isEmpty
                    ? Center(
                        child: Text(
                          'No ${_filter == 'all' ? '' : _filter} password reset requests.',
                          style: const TextStyle(color: AppColors.mutedText, fontSize: 14),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchRequests,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _requests.length,
                          itemBuilder: (ctx, idx) {
                            final req = Map<String, dynamic>.from(_requests[idx] as Map);
                            final name = req['name'] ?? 'Unknown';
                            final email = req['email'] ?? '';
                            final rollNo = req['roll_no'] ?? 'N/A';
                            final role = req['role'] ?? 'user';
                            final status = req['status'] ?? 'pending';
                            final isPending = status == 'pending';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isPending
                                      ? AppColors.warningYellow.withOpacity(0.3)
                                      : AppColors.borderColor,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          color: AppColors.textColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isPending
                                              ? AppColors.warningYellow.withOpacity(0.15)
                                              : (status == 'approved'
                                                  ? AppColors.successGreen.withOpacity(0.15)
                                                  : AppColors.errorRed.withOpacity(0.15)),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            color: isPending
                                                ? AppColors.warningYellow
                                                : (status == 'approved'
                                                    ? AppColors.successGreen
                                                    : AppColors.errorRed),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Email: $email', style: const TextStyle(color: AppColors.mutedText, fontSize: 13)),
                                  const SizedBox(height: 3),
                                  Text('Roll / College ID: $rollNo • Role: ${role.toUpperCase()}',
                                      style: const TextStyle(color: AppColors.mutedText, fontSize: 12)),
                                  if (req['temp_password_hint'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text('Temp Pass Set: ${req['temp_password_hint']}',
                                        style: const TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                  if (isPending) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: AppColors.errorRed),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => _handleReject(req),
                                          child: const Text('Reject', style: TextStyle(color: AppColors.errorRed)),
                                        ),
                                        const SizedBox(width: 10),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.check, size: 16, color: Colors.white),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.successGreen,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => _showApproveDialog(req),
                                          label: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.indigoPrimary.withOpacity(0.2),
      backgroundColor: AppColors.surfaceColor,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.indigoPrimary : AppColors.mutedText,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) {
        setState(() {
          _filter = value;
          _isLoading = true;
        });
        _fetchRequests();
      },
    );
  }
}
