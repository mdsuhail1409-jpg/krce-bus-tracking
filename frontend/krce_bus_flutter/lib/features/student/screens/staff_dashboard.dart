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

final busStudentsProvider = FutureProvider.autoDispose<BusStudentsRoster>((ref) async {
  final auth = ref.watch(authProvider);
  final api = ref.read(apiServiceProvider);
  return api.getMyBusStudents(auth.token);
});

class StaffDashboard extends ConsumerStatefulWidget {
  const StaffDashboard({super.key});

  @override
  ConsumerState<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends ConsumerState<StaffDashboard> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final busesAsync = ref.watch(busesProvider);
    final alertsAsync = ref.watch(alertsProvider);
    final etaAsync = ref.watch(etaProvider);
    final activeEmergencyAsync = ref.watch(activeEmergencyProvider);
    final busStudentsAsync = ref.watch(busStudentsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(busesProvider);
            ref.invalidate(alertsProvider);
            ref.invalidate(etaProvider);
            ref.invalidate(activeEmergencyProvider);
            ref.invalidate(busStudentsProvider);
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

              // Bus Students Roster
              busStudentsAsync.when(
                data: (roster) {
                  if (!roster.hasBus) {
                    return GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.directions_bus_outlined, color: AppColors.warningYellow),
                              SizedBox(width: 8),
                              Text('No Bus Assigned', style: TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            roster.message ?? 'You are not currently assigned as a staff coordinator to any bus. Contact the administration to link your bus.',
                            style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  final query = _searchQuery.toLowerCase();
                  final filtered = roster.students.where((s) {
                    return s.name.toLowerCase().contains(query) ||
                        s.collegeId.toLowerCase().contains(query) ||
                        s.busStop.toLowerCase().contains(query);
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Students on This Bus',
                                  style: TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold, fontSize: 17)),
                              const SizedBox(height: 2),
                              Text(
                                '${roster.busNumber ?? "Bus"} • ${roster.routeName ?? "Assigned Route"}',
                                style: const TextStyle(color: AppColors.indigoPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.indigoPrimary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.indigoPrimary.withOpacity(0.3)),
                            ),
                            child: Text(
                              '${roster.boardedCount}/${roster.totalStudents} Boarded',
                              style: const TextStyle(color: AppColors.indigoPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Quick Stats Strip
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Students', style: TextStyle(color: AppColors.mutedText, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text('${roster.totalStudents}', style: const TextStyle(color: AppColors.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppColors.successGreen.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.successGreen.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Boarded Today', style: TextStyle(color: AppColors.successGreen, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text('${roster.boardedCount}', style: const TextStyle(color: AppColors.successGreen, fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppColors.warningYellow.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.warningYellow.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Pending', style: TextStyle(color: AppColors.warningYellow, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text('${roster.totalStudents - roster.boardedCount}', style: const TextStyle(color: AppColors.warningYellow, fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Search box for students
                      TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: const TextStyle(color: AppColors.textColor, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search student by name, roll no, or stop...',
                          hintStyle: const TextStyle(color: AppColors.mutedText, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.mutedText),
                          filled: true,
                          fillColor: AppColors.surfaceColor,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderColor)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (filtered.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderColor),
                          ),
                          child: Center(
                            child: Text(
                              _searchQuery.isEmpty ? 'No students assigned to this bus yet.' : 'No students found matching "$_searchQuery"',
                              style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
                            ),
                          ),
                        )
                      else
                        ...filtered.map((s) => _StudentRosterCard(student: s)),
                    ],
                  );
                },
                loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                )),
                error: (e, _) => GlassCard(
                  child: Text('Failed to load students roster: $e', style: const TextStyle(color: AppColors.errorRed)),
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

class _StudentRosterCard extends StatelessWidget {
  final BusStudent student;
  const _StudentRosterCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: student.isBoarded ? AppColors.successGreen.withOpacity(0.3) : AppColors.borderColor,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: student.isBoarded
                ? AppColors.successGreen.withOpacity(0.15)
                : AppColors.indigoPrimary.withOpacity(0.12),
            child: Icon(
              student.isBoarded ? Icons.check_circle : Icons.person,
              color: student.isBoarded ? AppColors.successGreen : AppColors.indigoPrimary,
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
                    Expanded(
                      child: Text(
                        student.name,
                        style: const TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: student.isBoarded
                            ? AppColors.successGreen.withOpacity(0.15)
                            : AppColors.mutedText.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        student.isBoarded ? 'Boarded' : 'Not Boarded',
                        style: TextStyle(
                          color: student.isBoarded ? AppColors.successGreen : AppColors.mutedText,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text('Roll: ${student.collegeId}', style: const TextStyle(color: AppColors.mutedText, fontSize: 12)),
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: AppColors.mutedText, fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stop: ${student.busStop}',
                        style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (student.phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 11, color: AppColors.mutedText),
                      const SizedBox(width: 4),
                      Text(student.phone, style: const TextStyle(color: AppColors.mutedText, fontSize: 11)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

