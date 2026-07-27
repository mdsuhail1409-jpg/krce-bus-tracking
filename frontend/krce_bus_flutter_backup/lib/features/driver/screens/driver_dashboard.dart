import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSavedState();
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
