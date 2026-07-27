import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/glass_card.dart';
import '../../auth/providers/auth_provider.dart';
import 'users_screen.dart';
import 'registrations_screen.dart';
import '../widgets/send_alert_dialog.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  AdminStats? _stats;
  List<Bus> _buses = [];
  List<Alert> _alerts = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchAll();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _fetchAll());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    final auth = ref.read(authProvider);
    final api = ref.read(apiServiceProvider);
    try {
      final results = await Future.wait(<Future<dynamic>>[
        api.getAdminStats(auth.token),
        api.getBuses(auth.token),
        api.getAlerts(auth.token),
      ]);
      if (mounted) {
        setState(() {
          _stats = results[0] as AdminStats;
          _buses = results[1] as List<Bus>;
          _alerts = results[2] as List<Alert>;
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
                        gradient: AppColors.gradientPrimary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  auth.role == 'committee'
                                      ? 'Committee Mode'
                                      : 'Admin Mode',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                                Text(
                                  auth.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold),
                                ),
                                const Text(
                                  'K. Ramakrishnan College of Engineering',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.admin_panel_settings,
                              color: Colors.white, size: 40),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Admin Controls
                    const Text('Admin Controls',
                        style: TextStyle(
                            color: AppColors.textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const UsersScreen()),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.borderColor),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.supervised_user_circle, color: AppColors.accentCyan, size: 28),
                                  SizedBox(height: 8),
                                  Text('Users', style: TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('Manage roles', style: TextStyle(color: AppColors.mutedText, fontSize: 10), textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const RegistrationsScreen()),
                              );
                              if (result == true) {
                                _fetchAll();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.borderColor),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.how_to_reg, color: AppColors.accentPurple, size: 28),
                                  SizedBox(height: 8),
                                  Text('Approvals', style: TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('Review pending', style: TextStyle(color: AppColors.mutedText, fontSize: 10), textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final result = await showDialog<bool>(
                                context: context,
                                builder: (_) => SendAlertDialog(buses: _buses),
                              );
                              if (result == true) {
                                _fetchAll();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.borderColor),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.campaign, color: AppColors.errorRed, size: 28),
                                  SizedBox(height: 8),
                                  Text('Broadcast', style: TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('Send alerts', style: TextStyle(color: AppColors.mutedText, fontSize: 10), textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Stats Grid
                    if (_stats != null) ...[
                      const Text('Overview',
                          style: TextStyle(
                              color: AppColors.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 10),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.6,
                        children: [
                          _StatCard(
                              icon: Icons.people,
                              value: _stats!.totalStudents.toString(),
                              label: 'Total Students',
                              color: AppColors.indigoPrimary),
                          _StatCard(
                              icon: Icons.directions_bus,
                              value: _stats!.liveBuses.toString(),
                              label: 'Live Buses',
                              color: AppColors.successGreen),
                          _StatCard(
                              icon: Icons.login,
                              value: _stats!.boardedToday.toString(),
                              label: 'Boarded Today',
                              color: AppColors.warningYellow),
                          _StatCard(
                              icon: Icons.notifications,
                              value: _stats!.activeAlerts.toString(),
                              label: 'Active Alerts',
                              color: AppColors.errorRed),
                          _StatCard(
                              icon: Icons.person,
                              value: _stats!.totalDrivers.toString(),
                              label: 'Drivers',
                              color: AppColors.accentCyan),
                          _StatCard(
                              icon: Icons.pending,
                              value: _stats!.pendingRegs.toString(),
                              label: 'Pending Regs',
                              color: AppColors.accentPurple),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Live Buses
                    const Text('Live Fleet',
                        style: TextStyle(
                            color: AppColors.textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(height: 10),
                    ..._buses.map((b) => _BusCard(bus: b)),
                    const SizedBox(height: 20),

                    // Active Alerts
                    if (_alerts.isNotEmpty) ...[
                      const Text('Active Alerts',
                          style: TextStyle(
                              color: AppColors.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 10),
                      ..._alerts
                          .where((a) => a.isResolved == 0)
                          .take(5)
                          .map((a) => _AlertCard(alert: a)),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(
                  color: AppColors.mutedText, fontSize: 11)),
        ],
      ),
    );
  }
}

class _BusCard extends StatelessWidget {
  final Bus bus;
  const _BusCard({required this.bus});

  @override
  Widget build(BuildContext context) {
    final isOnline = bus.live?.status != 'offline' && bus.live != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isOnline
                  ? AppColors.successGreen.withOpacity(0.15)
                  : AppColors.mutedText.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.directions_bus,
                color: isOnline ? AppColors.successGreen : AppColors.mutedText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${bus.number} — ${bus.routeName}',
                    style: const TextStyle(
                        color: AppColors.textColor,
                        fontWeight: FontWeight.bold)),
                Text(
                  isOnline
                      ? '${bus.live!.speed.toInt()} km/h  •  ${bus.live!.passengers} passengers'
                      : 'Offline',
                  style:
                      const TextStyle(color: AppColors.mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isOnline
                  ? AppColors.successGreen.withOpacity(0.1)
                  : AppColors.mutedText.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isOnline ? 'Live' : 'Offline',
              style: TextStyle(
                  color: isOnline
                      ? AppColors.successGreen
                      : AppColors.mutedText,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Alert alert;
  const _AlertCard({required this.alert});

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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold)),
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
