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

class StudentDashboard extends ConsumerStatefulWidget {
  const StudentDashboard({super.key});

  @override
  ConsumerState<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends ConsumerState<StudentDashboard> {
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
                          const Text('Student Mode',
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
                            'College ID: ${auth.collegeId ?? "--"}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.school, color: Colors.white, size: 40),
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
                            Expanded(
                              child: Text(
                                '🚨 EMERGENCY: Bus Breakdown (${emerg.brokenBusNumber})',
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
                          'Your assigned Bus ${emerg.brokenBusNumber} has encountered a breakdown.',
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
                            'Administrative control is routing a replacement bus. Please hold at your current location.',
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

              // Live Bus Card
              busesAsync.when(
                data: (buses) {
                  final myBus = buses.firstWhere(
                    (b) => b.id == auth.busId || b.number == auth.busId,
                    orElse: () => buses.isNotEmpty ? buses.first : Bus(
                      id: '', number: 'N/A', routeName: 'N/A',
                      capacity: 0, stops: [],
                    ),
                  );
                  final isOnline = myBus.live?.status != 'offline' &&
                      myBus.live != null;

                  return GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${myBus.number} — ${myBus.routeName}',
                              style: const TextStyle(
                                  color: AppColors.textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? AppColors.successGreen.withOpacity(0.15)
                                    : AppColors.mutedText.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  color: isOnline
                                      ? AppColors.successGreen
                                      : AppColors.mutedText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (myBus.live != null) ...[
                          Row(children: [
                            const Icon(Icons.speed,
                                color: AppColors.mutedText, size: 16),
                            const SizedBox(width: 6),
                            Text(
                                '${myBus.live!.speed.toInt()} km/h',
                                style: const TextStyle(
                                    color: AppColors.mutedText)),
                            const SizedBox(width: 20),
                            const Icon(Icons.people,
                                color: AppColors.mutedText, size: 16),
                            const SizedBox(width: 6),
                            Text('${myBus.live!.passengers} onboard',
                                style: const TextStyle(
                                    color: AppColors.mutedText)),
                          ]),
                          const SizedBox(height: 8),
                          Text(
                            'Driver: ${myBus.live!.driverName}',
                            style: const TextStyle(color: AppColors.mutedText),
                          ),
                        ],
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => context.go('/map'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              gradient: AppColors.gradientPrimary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text('Track on Map',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
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
