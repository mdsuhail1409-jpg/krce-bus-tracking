import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

import '../../../core/utils/date_utils.dart';

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Attendance> _attendance = [];
  List<Alert> _alerts = [];
  List<EmergencyAssignmentResponse> _breakdowns = [];
  bool _loadingAttendance = true;
  bool _loadingAlerts = true;
  bool _loadingBreakdowns = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    _fetchAttendance();
    _fetchAlerts();
    _fetchBreakdowns();
  }

  Future<void> _fetchAttendance() async {
    final auth = ref.read(authProvider);
    final api = ref.read(apiServiceProvider);
    try {
      List<Attendance> records;
      if (auth.role == 'admin' || auth.role == 'committee') {
        records = await api.getAllAttendance(auth.token);
      } else if (auth.role == 'parent') {
        records = await api.getChildAttendance(auth.token);
      } else {
        records = await api.getMyAttendance(auth.token);
      }
      if (mounted) {
        setState(() {
          _attendance = records;
          _loadingAttendance = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAttendance = false);
    }
  }

  Future<void> _fetchAlerts() async {
    final auth = ref.read(authProvider);
    final api = ref.read(apiServiceProvider);
    try {
      final alerts = await api.getAlerts(auth.token);
      if (mounted) {
        setState(() {
          _alerts = alerts;
          _loadingAlerts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAlerts = false);
    }
  }

  Future<void> _fetchBreakdowns() async {
    final auth = ref.read(authProvider);
    final api = ref.read(apiServiceProvider);
    try {
      final emergency = await api.getActiveEmergency(auth.token);
      if (mounted) {
        setState(() {
          _breakdowns = emergency != null ? [emergency] : [];
          _loadingBreakdowns = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBreakdowns = false);
    }
  }

  // ── Date/Time Formatting Helpers (IST UTC+5:30) ────────────
  String _formatTime(String raw) => AppDateUtils.formatTimeIst(raw);
  String _formatDate(String raw) => AppDateUtils.formatDateIst(raw);
  String _formatDateTime(String raw) => AppDateUtils.formatDateTimeIst(raw);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Logs',
            style: TextStyle(
                color: AppColors.textColor, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surfaceColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textColor),
            onPressed: () {
              setState(() {
                _loadingAttendance = true;
                _loadingAlerts = true;
                _loadingBreakdowns = true;
              });
              _fetchAll();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.indigoPrimary,
          unselectedLabelColor: AppColors.mutedText,
          indicatorColor: AppColors.indigoPrimary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Attendance'),
            Tab(text: 'Alerts'),
            Tab(text: 'Breakdowns'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAttendanceTab(),
          _buildAlertsTab(),
          _buildBreakdownsTab(),
        ],
      ),
    );
  }

  // ── Attendance Tab ─────────────────────────────────────────
  Widget _buildAttendanceTab() {
    if (_loadingAttendance) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_attendance.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, color: AppColors.mutedText, size: 48),
            SizedBox(height: 12),
            Text('No attendance records found',
                style: TextStyle(color: AppColors.mutedText, fontSize: 15)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchAttendance,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _attendance.length,
        itemBuilder: (ctx, i) {
          final rec = _attendance[i];
          final isBoarded = rec.tapType == 'boarded';
          final color =
              isBoarded ? AppColors.successGreen : AppColors.errorRed;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isBoarded ? Icons.login : Icons.logout,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              rec.studentName ?? rec.userId,
                              style: const TextStyle(
                                  color: AppColors.textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (rec.collegeId != null)
                            Text(
                              rec.collegeId!,
                              style: const TextStyle(
                                  color: AppColors.mutedText, fontSize: 11),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${rec.busNumber ?? rec.busId}  •  ${rec.stopName ?? "--"}',
                        style: const TextStyle(
                            color: AppColors.mutedText, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isBoarded ? 'In' : 'Out',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(rec.tapTime),
                      style: const TextStyle(
                          color: AppColors.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(rec.date),
                      style: const TextStyle(
                          color: AppColors.mutedText, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Alerts Tab ─────────────────────────────────────────────
  Widget _buildAlertsTab() {
    if (_loadingAlerts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_alerts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined,
                color: AppColors.mutedText, size: 48),
            SizedBox(height: 12),
            Text('No alerts found',
                style: TextStyle(color: AppColors.mutedText, fontSize: 15)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchAlerts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _alerts.length,
        itemBuilder: (ctx, i) {
          final alert = _alerts[i];
          final isResolved = alert.isResolved == 1;
          Color typeColor;
          String typeLabel;
          switch (alert.alertType) {
            case 'emergency':
              typeColor = AppColors.errorRed;
              typeLabel = 'Emergency';
              break;
            case 'warning':
              typeColor = AppColors.warningYellow;
              typeLabel = 'Warning';
              break;
            default:
              typeColor = AppColors.infoCyan;
              typeLabel = 'Info';
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isResolved
                  ? AppColors.surfaceColor
                  : typeColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isResolved
                      ? AppColors.borderColor
                      : typeColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: typeColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        alert.title,
                        style: TextStyle(
                            color: typeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ),
                    // Type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                            color: typeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  alert.message,
                  style: const TextStyle(
                      color: AppColors.mutedText, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Date & Time
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            color: AppColors.mutedText, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(alert.sentAt),
                          style: const TextStyle(
                              color: AppColors.mutedText, fontSize: 11),
                        ),
                      ],
                    ),
                    // Resolved status
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isResolved
                            ? AppColors.successGreen.withOpacity(0.12)
                            : AppColors.warningYellow.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isResolved ? 'Resolved' : 'Active',
                        style: TextStyle(
                            color: isResolved
                                ? AppColors.successGreen
                                : AppColors.warningYellow,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Breakdowns Tab ─────────────────────────────────────────
  Widget _buildBreakdownsTab() {
    if (_loadingBreakdowns) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_breakdowns.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.build_circle_outlined,
                color: AppColors.mutedText, size: 48),
            SizedBox(height: 12),
            Text('No breakdown records',
                style: TextStyle(color: AppColors.mutedText, fontSize: 15)),
            SizedBox(height: 4),
            Text('Breakdown history will appear here',
                style: TextStyle(color: AppColors.mutedText, fontSize: 12)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchBreakdowns,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _breakdowns.length,
        itemBuilder: (ctx, i) {
          final e = _breakdowns[i];
          Color statusColor;
          switch (e.status) {
            case 'resolved':
              statusColor = AppColors.successGreen;
              break;
            case 'dispatched':
              statusColor = AppColors.infoCyan;
              break;
            default:
              statusColor = AppColors.warningYellow;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.build,
                          color: AppColors.errorRed, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bus ${e.brokenBusNumber} Breakdown',
                            style: const TextStyle(
                                color: AppColors.textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${e.studentsWaiting} students waiting  •  ${e.remainingStops.length} stops remaining',
                            style: const TextStyle(
                                color: AppColors.mutedText, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        e.status.toUpperCase(),
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (e.backupBusNumber != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.infoCyan.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_bus,
                            color: AppColors.infoCyan, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Backup: ${e.backupBusNumber}',
                          style: const TextStyle(
                              color: AppColors.infoCyan,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                        if (e.backupDriverName != null) ...[
                          const Text('  •  ',
                              style: TextStyle(color: AppColors.mutedText)),
                          Text(
                            e.backupDriverName!,
                            style: const TextStyle(
                                color: AppColors.mutedText, fontSize: 12),
                          ),
                        ],
                        if (e.etaMinutes != null) ...[
                          const Spacer(),
                          Text(
                            'ETA: ${e.etaMinutes} min',
                            style: const TextStyle(
                                color: AppColors.successGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
