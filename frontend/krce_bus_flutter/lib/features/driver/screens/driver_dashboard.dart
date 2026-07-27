import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/gps_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/premium_button.dart';
import '../../auth/providers/auth_provider.dart';

class DriverDashboard extends ConsumerStatefulWidget {
  const DriverDashboard({super.key});

  @override
  ConsumerState<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends ConsumerState<DriverDashboard> {
  bool _isTracking = false;
  List<Passenger> _passengers = [];
  String _sosMessage = '';
  Timer? _passengerTimer;
  Timer? _assignmentTimer;
  bool _showingAssignmentDialog = false;

  @override
  void initState() {
    super.initState();
    _loadSavedState();
    _startAssignmentPolling();
  }

  Future<void> _loadSavedState() async {
    final gps = ref.read(gpsServiceProvider);
    final saved = await gps.getSavedState();
    if (saved && mounted) {
      setState(() => _isTracking = true);
      _startPassengerPolling();
      final auth = ref.read(authProvider);
      final api = ref.read(apiServiceProvider);
      if (auth.busId != null) {
        await gps.start(
            token: auth.token, busId: auth.busId!, apiService: api);
      }
    }
  }

  @override
  void dispose() {
    _passengerTimer?.cancel();
    _assignmentTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleTracking(bool value) async {
    final auth = ref.read(authProvider);
    final api = ref.read(apiServiceProvider);
    final gps = ref.read(gpsServiceProvider);

    setState(() => _isTracking = value);

    if (value) {
      if (auth.busId != null) {
        await gps.start(
            token: auth.token, busId: auth.busId!, apiService: api);
      }
      _startPassengerPolling();
    } else {
      await gps.stop();
      _passengerTimer?.cancel();
    }
  }

  void _startPassengerPolling() {
    _fetchPassengers();
    _passengerTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_isTracking) _fetchPassengers();
    });
  }

  Future<void> _fetchPassengers() async {
    final auth = ref.read(authProvider);
    final api = ref.read(apiServiceProvider);
    if (auth.busId == null) return;
    try {
      final p = await api.getBusPassengers(auth.token, auth.busId!);
      if (mounted) setState(() => _passengers = p);
    } catch (_) {}
  }

  Future<void> _triggerSos() async {
    final auth = ref.read(authProvider);
    final api = ref.read(apiServiceProvider);
    try {
      await api.triggerSos(auth.token);
      setState(() => _sosMessage = '🚨 SOS Emergency Broadcasted!');
    } catch (_) {
      setState(() => _sosMessage = 'Failed to trigger SOS');
    }
  }

  Future<void> _reportBreakdown() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceColor,
        title: const Text('Report Breakdown?', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to report a vehicle breakdown? This will alert administrative control and request a replacement bus.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            child: const Text('Report', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final auth = ref.read(authProvider);
    final api = ref.read(apiServiceProvider);
    
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await api.reportBreakdown(auth.token, position.latitude, position.longitude);
      if (mounted) {
        setState(() => _sosMessage = '🚨 Breakdown Reported! Admin control notified.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sosMessage = 'Failed to report breakdown. Check GPS/permissions.');
      }
    }
  }

  void _startAssignmentPolling() {
    _checkAssignment();
    _assignmentTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkAssignment();
    });
  }

  Future<void> _checkAssignment() async {
    final auth = ref.read(authProvider);
    final api = ref.read(apiServiceProvider);
    if (auth.token.isEmpty || auth.token.startsWith('demo_')) return;
    try {
      final assign = await api.getEmergencyAssignment(auth.token);
      if (assign != null && !_showingAssignmentDialog && mounted) {
        setState(() {
          _showingAssignmentDialog = true;
        });
        _showAssignmentDialog(assign);
      }
    } catch (_) {}
  }

  void _showAssignmentDialog(EmergencyAssignmentResponse assign) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceColor,
          title: const Text('🚨 EMERGENCY PICKUP REQUEST',
              style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Broken Bus: ${assign.brokenBusNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textColor)),
              const SizedBox(height: 8),
              Text('Students Onboard: ${assign.studentsWaiting}',
                  style: const TextStyle(color: AppColors.textColor)),
              const SizedBox(height: 8),
              Text('Stops to Cover: ${assign.remainingStops.join(" ➔ ")}',
                  style: const TextStyle(fontSize: 13, color: AppColors.mutedText)),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('REJECT', style: TextStyle(color: AppColors.mutedText)),
              onPressed: () async {
                Navigator.of(context).pop();
                final auth = ref.read(authProvider);
                final api = ref.read(apiServiceProvider);
                try {
                  await api.rejectEmergencyAssignment(auth.token, assign.emergencyId);
                } catch (_) {}
                if (mounted) {
                  setState(() {
                    _showingAssignmentDialog = false;
                  });
                }
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.successGreen),
              child: const Text('ACCEPT', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                Navigator.of(context).pop();
                final auth = ref.read(authProvider);
                final api = ref.read(apiServiceProvider);
                try {
                  await api.acceptEmergencyAssignment(auth.token, assign.emergencyId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pickup accepted. Students transferred to this vehicle.')),
                  );
                } catch (_) {}
                if (mounted) {
                  setState(() {
                    _showingAssignmentDialog = false;
                  });
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.gradientWarning,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Driver Mode',
                            style: TextStyle(color: Colors.white70)),
                        Text(
                          auth.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Bus ${auth.busId ?? "--"} • ${_isTracking ? "Broadcasting Location" : "Not Broadcasting"}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.drive_eta, color: Colors.white, size: 40),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats Row
            Row(
              children: [
                Expanded(
                    child: _StatCard(
                        value: _passengers.length.toString(),
                        label: 'Onboard',
                        color: AppColors.successGreen)),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatCard(
                        value: auth.busId ?? '--',
                        label: 'Bus ID',
                        color: AppColors.indigoPrimary)),
              ],
            ),
            const SizedBox(height: 16),

            // GPS Toggle Card
            GlassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('GPS Broadcasting',
                          style: TextStyle(
                              color: AppColors.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(
                        _isTracking
                            ? 'Live: Background service active'
                            : 'Status: Inactive',
                        style: const TextStyle(
                            color: AppColors.mutedText, fontSize: 13),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isTracking,
                    onChanged: _toggleTracking,
                    activeColor: Colors.white,
                    activeTrackColor: AppColors.indigoPrimary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // SOS Button
            if (_sosMessage.isNotEmpty) ...[
              Text(_sosMessage,
                  style: const TextStyle(
                      color: AppColors.errorRed, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
            ],
            PremiumButton(
              text: '🚨 Trigger SOS Panic Alert',
              gradient: AppColors.gradientDanger,
              onPressed: _triggerSos,
            ),
            const SizedBox(height: 12),
            PremiumButton(
              text: '🚨 Report Vehicle Breakdown',
              gradient: AppColors.gradientWarning,
              onPressed: _reportBreakdown,
            ),
            const SizedBox(height: 24),

            // Passengers List
            Text(
              'Passengers Onboard (${_passengers.length})',
              style: const TextStyle(
                  color: AppColors.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (_passengers.isEmpty)
              const Center(
                  child: Text('No passengers boarded yet',
                      style: TextStyle(color: AppColors.mutedText)))
            else
              ..._passengers.map((p) => _PassengerCard(passenger: p)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCard(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 28, fontWeight: FontWeight.bold)),
          Text(label,
              style:
                  const TextStyle(color: AppColors.mutedText, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PassengerCard extends StatelessWidget {
  final Passenger passenger;
  const _PassengerCard({required this.passenger});

  @override
  Widget build(BuildContext context) {
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: AppColors.gradientPrimary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                passenger.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(passenger.name,
                    style: const TextStyle(
                        color: AppColors.textColor,
                        fontWeight: FontWeight.bold)),
                Text(
                  '${passenger.collegeId}  •  ${passenger.stopName ?? "Unknown stop"}',
                  style: const TextStyle(
                      color: AppColors.mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: passenger.tapType == 'boarded'
                  ? AppColors.successGreen.withOpacity(0.15)
                  : AppColors.errorRed.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              passenger.tapType == 'boarded' ? 'Boarded' : 'Alighted',
              style: TextStyle(
                  color: passenger.tapType == 'boarded'
                      ? AppColors.successGreen
                      : AppColors.errorRed,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
