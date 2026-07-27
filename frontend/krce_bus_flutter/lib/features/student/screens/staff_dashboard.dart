import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/glass_card.dart';
import '../../auth/providers/auth_provider.dart';

final busesProvider = FutureProvider.autoDispose<List<Bus>>((ref) async {
  final auth = ref.watch(authProvider);
  final api = ref.read(apiServiceProvider);
  return api.getBuses(auth.token);
});

final alertsProvider = FutureProvider.autoDispose<List<Alert>>((ref) async {
  final auth = ref.watch(authProvider);
  final api = ref.read(apiServiceProvider);
  return api.getAlerts(auth.token);
});

final etaProvider = FutureProvider.autoDispose<EtaResponse>((ref) async {
  final auth = ref.watch(authProvider);
  final api = ref.read(apiServiceProvider);
  return api.getMyEta(auth.token);
});

final activeEmergencyProvider = FutureProvider.autoDispose<EmergencyAssignmentResponse?>((ref) async {
  final auth = ref.watch(authProvider);
  final api = ref.read(apiServiceProvider);
  return api.getActiveEmergency(auth.token);
});

class StaffDashboard extends ConsumerStatefulWidget {
  const StaffDashboard({super.key});

  @override
  ConsumerState<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends ConsumerState<StaffDashboard> {
  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final busesAsync = ref.watch(busesProvider);
    final alertsAsync = ref.watch(alertsProvider);
    final etaAsync = ref.watch(etaProvider);
    final activeEmergencyAsync = ref.watch(activeEmergencyProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(busesProvider);
            ref.invalidate(alertsProvider);
            ref.invalidate(etaProvider);
            ref.invalidate(activeEmergencyProvider);
          },
          child: ListView(
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
                          const Text('Staff Mode',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                          Text(
                            'Hello, ${auth.name}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Staff ID: ${auth.collegeId ?? "--"}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.badge, color: Colors.white, size: 40),
                  ],
                ),
              ),
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
                            const Text('Active SOS / Emergency',
                                style: TextStyle(
                                    color: AppColors.errorRed,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('An emergency has been reported on your route.',
                            style: const TextStyle(color: AppColors.textColor)),
                        const SizedBox(height: 8),
                        if (hasBackup && emerg.backupBusNumber != null)
                          Text('Backup Bus ${emerg.backupBusNumber} has been dispatched.',
                              style: const TextStyle(
                                  color: AppColors.successGreen,
                                  fontWeight: FontWeight.bold))
                        else
                          const Text('Awaiting backup bus dispatch from administration.',
                              style: TextStyle(color: AppColors.mutedText)),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // ETA Card
              etaAsync.when(
                data: (eta) => GlassCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.access_time,
                            color: AppColors.successGreen),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ETA to Campus',
                              style: TextStyle(color: AppColors.mutedText)),
                          Text(
                            eta.eta,
                            style: const TextStyle(
                                color: AppColors.successGreen,
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                          ),
                          Text('Next Stop: ${eta.nextStop}',
                              style: const TextStyle(
                                  color: AppColors.mutedText, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),

              // Track Bus Button
              busesAsync.when(
                data: (list) {
                  final myBus = list.firstWhere(
                    (b) => b.id == auth.busId,
                    orElse: () => list.isNotEmpty
                        ? list.first
                        : Bus(
                            id: '',
                            number: 'Unassigned',
                            routeName: 'No Assigned Route',
                            capacity: 0,
                            stops: []),
                  );

                  return Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          context.go('/map');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.indigoPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          minimumSize: const Size(double.infinity, 50),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map_outlined),
                            SizedBox(width: 10),
                            Text('Track Assigned Bus Live',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Route Overview',
                                style: TextStyle(
                                    color: AppColors.textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            const SizedBox(height: 8),
                            Text(myBus.routeName,
                                style: const TextStyle(
                                    color: AppColors.mutedText,
                                    fontSize: 13)),
                            const Divider(height: 20),
                            if (myBus.stops.isNotEmpty)
                              ...myBus.stops.map((s) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4),
                                    child: Row(
                                      children: [
                                        const Icon(
                                            Icons.radio_button_checked,
                                            color: AppColors.indigoPrimary,
                                            size: 14),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(s,
                                              style: const TextStyle(
                                                  color: AppColors.textColor,
                                                  fontSize: 13)),
                                        ),
                                      ],
                                    ),
                                  )),
                          ],
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => GlassCard(
                  child: Text('Failed to load bus: $e',
                      style:
                          const TextStyle(color: AppColors.errorRed)),
                ),
              ),
              const SizedBox(height: 16),

              // Alerts
              alertsAsync.when(
                data: (alerts) {
                  if (alerts.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('System Alerts',
                          style: TextStyle(
                              color: AppColors.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 10),
                      ...alerts.take(3).map((a) => _AlertCard(alert: a)),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications, color: color, size: 20),
          const SizedBox(width: 12),
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
