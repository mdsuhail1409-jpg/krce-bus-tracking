import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/glass_card.dart';
import '../../auth/providers/auth_provider.dart';

import '../../../core/utils/date_utils.dart';

final activeEmergencyProvider = FutureProvider.autoDispose<EmergencyAssignmentResponse?>((ref) async {
  final auth = ref.watch(authProvider);
  final api = ref.read(apiServiceProvider);
  return api.getActiveEmergency(auth.token);
});

class ParentDashboard extends ConsumerStatefulWidget {
  const ParentDashboard({super.key});

  @override
  ConsumerState<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends ConsumerState<ParentDashboard> {
  List<Attendance> _attendance = [];
  List<Alert> _alerts = [];
  Map<String, dynamic>? _wardData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    final auth = ref.read(authProvider);
    final api = ref.read(apiServiceProvider);
    try {
      ref.invalidate(activeEmergencyProvider);
      final results = await Future.wait(<Future<dynamic>>[
        api.getChildAttendance(auth.token),
        api.getAlerts(auth.token),
        api.getMyWard(auth.token),
      ]);
      if (mounted) {
        setState(() {
          _attendance = results[0] as List<Attendance>;
          _alerts = results[1] as List<Alert>;
          _wardData = results[2] as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final activeEmergencyAsync = ref.watch(activeEmergencyProvider);
    final today = _attendance.where((a) {
      final now = DateTime.now();
      return a.date.startsWith(
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchAll,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Welcome Banner
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppColors.gradientSuccess,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Parent Mode',
                                    style: TextStyle(color: Colors.white70)),
                                Text(auth.name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold)),
                                Text('Ward ID: ${auth.parentOf ?? "--"}',
                                    style: const TextStyle(
                                        color: Colors.white70)),
                              ],
                            ),
                          ),
                          const Icon(Icons.family_restroom,
                              color: Colors.white, size: 40),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Child's Assigned Bus & Live Tracking Card
                    _buildChildBusCard(context, _wardData),
                    const SizedBox(height: 16),

                    activeEmergencyAsync.when(
                      data: (emerg) {
                        if (emerg == null) return const SizedBox.shrink();
                        
                        final hasBackup = emerg.status == 'assigned' || emerg.status == 'accepted';
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.errorRed.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: AppColors.errorRed),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '🚨 EMERGENCY: Child\'s Bus Breakdown (${emerg.brokenBusNumber})',
                                      style: const TextStyle(
                                        color: AppColors.errorRed,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your child\'s assigned Bus ${emerg.brokenBusNumber} has encountered a breakdown.',
                                style: const TextStyle(color: AppColors.textColor, fontSize: 13),
                              ),
                              if (hasBackup && emerg.backupBusNumber != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Replacement Bus: ${emerg.backupBusNumber} has been assigned.\nDriver: ${emerg.backupDriverName} | ETA: ${emerg.etaMinutes ?? "--"} mins.',
                                  style: const TextStyle(
                                    color: AppColors.successGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Administrative control is routing a replacement bus. Your child will be safely transferred.',
                                  style: TextStyle(
                                    color: AppColors.warningYellow,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    // Today's Status
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Today's Status",
                              style: TextStyle(
                                  color: AppColors.textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          const SizedBox(height: 12),
                          if (today.isEmpty)
                            const Text('No attendance records for today',
                                style: TextStyle(color: AppColors.mutedText))
                          else
                            ...today.map((a) => _AttendanceRow(record: a)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Recent Alerts
                    const Text('Alerts',
                        style: TextStyle(
                            color: AppColors.textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(height: 10),
                    if (_alerts.isEmpty)
                      const Text('No alerts',
                          style: TextStyle(color: AppColors.mutedText))
                    else
                      ..._alerts.take(5).map((a) => _AlertChip(alert: a)),

                    const SizedBox(height: 16),

                    // Recent Attendance
                    const Text('Attendance History',
                        style: TextStyle(
                            color: AppColors.textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(height: 10),
                    if (_attendance.isEmpty)
                      const Text('No attendance records',
                          style: TextStyle(color: AppColors.mutedText))
                    else
                      ..._attendance
                          .take(10)
                          .map((a) => _AttendanceRow(record: a)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildChildBusCard(BuildContext context, Map<String, dynamic>? data) {
    final hasWard = data != null && data['has_ward'] == true;
    final ward = hasWard ? data['ward'] as Map<String, dynamic>? : null;
    final bus = hasWard ? data['bus'] as Map<String, dynamic>? : null;
    final live = bus != null ? bus['live'] as Map<String, dynamic>? : null;

    if (!hasWard) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningYellow.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_search, color: AppColors.warningYellow, size: 28),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Ward Assigned Yet',
                    style: TextStyle(
                      color: AppColors.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Please contact the administrator to link your child\'s student ID to track their assigned bus.',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final wardName = ward?['name'] ?? 'Student';
    final wardId = ward?['college_id'] ?? ward?['id'] ?? '--';
    final busNumber = bus?['number'] ?? 'Not Assigned';
    final routeName = bus?['route_name'] ?? 'Route information pending';
    final driverName = bus?['driver_name'];
    final driverPhone = bus?['driver_phone'];

    String statusText = 'Offline / Depot';
    Color statusColor = AppColors.mutedText;
    if (live != null) {
      final st = live['status'];
      final spd = live['speed'] ?? 0;
      if (st == 'in_transit') {
        statusText = 'Moving • ${spd is num ? spd.toStringAsFixed(0) : spd} km/h';
        statusColor = AppColors.successGreen;
      } else if (st == 'stopped') {
        statusText = 'At Stop / Halted';
        statusColor = AppColors.warningYellow;
      } else {
        statusText = 'Offline';
        statusColor = AppColors.mutedText;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.indigoPrimary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.indigoPrimary.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Child Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.indigoPrimary.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.school, color: AppColors.indigoPrimary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$wardName ($wardId)',
                    style: const TextStyle(
                      color: AppColors.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body: Bus Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.indigoPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.directions_bus, color: AppColors.indigoPrimary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bus $busNumber',
                            style: const TextStyle(
                              color: AppColors.textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            routeName,
                            style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
                          ),
                          if (driverName != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.badge, size: 14, color: AppColors.mutedText),
                                const SizedBox(width: 4),
                                Text('Driver: $driverName', style: const TextStyle(color: AppColors.textColor, fontSize: 12)),
                                if (driverPhone != null) ...[
                                  const SizedBox(width: 8),
                                  Text('($driverPhone)', style: const TextStyle(color: AppColors.mutedText, fontSize: 12)),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.indigoPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => context.go('/map'),
                    icon: const Icon(Icons.navigation, color: Colors.white, size: 18),
                    label: const Text(
                      "Track Child's Live Bus",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final Attendance record;
  const _AttendanceRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final isBoarded = record.tapType == 'boarded';
    final color = isBoarded ? AppColors.successGreen : AppColors.errorRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isBoarded ? Icons.login : Icons.logout,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBoarded ? 'Boarded' : 'Alighted',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${record.stopName ?? "--"}  •  ${AppDateUtils.formatTimeIst(record.tapTime)}',
                  style: const TextStyle(
                      color: AppColors.mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(AppDateUtils.formatDateIst(record.date),
              style:
                  const TextStyle(color: AppColors.mutedText, fontSize: 11)),
        ],
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  final Alert alert;
  const _AlertChip({required this.alert});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (alert.alertType) {
      case 'emergency':
        color = AppColors.errorRed;
        break;
      case 'warning':
        color = AppColors.warningYellow;
        break;
      default:
        color = AppColors.indigoPrimary;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(alert.message,
                    style: const TextStyle(
                        color: AppColors.mutedText, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
