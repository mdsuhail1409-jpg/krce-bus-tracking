import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/glass_card.dart';
import '../../auth/providers/auth_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<Attendance> _records = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
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
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Attendance History',
            style: TextStyle(color: AppColors.textColor)),
        backgroundColor: AppColors.surfaceColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textColor),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetch();
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Text(_error,
                      style: const TextStyle(color: AppColors.errorRed)))
              : _records.isEmpty
                  ? const Center(
                      child: Text('No attendance records found',
                          style: TextStyle(color: AppColors.mutedText)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _records.length,
                      itemBuilder: (ctx, i) {
                        final rec = _records[i];
                        final isBoarded = rec.tapType == 'boarded';
                        final color = isBoarded
                            ? AppColors.successGreen
                            : AppColors.errorRed;

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
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isBoarded ? Icons.login : Icons.logout,
                                  color: color,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          rec.studentName ?? rec.userId,
                                          style: const TextStyle(
                                              color: AppColors.textColor,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 8),
                                        if (rec.collegeId != null)
                                          Text(
                                            rec.collegeId!,
                                            style: const TextStyle(
                                                color: AppColors.mutedText,
                                                fontSize: 11),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${rec.busNumber ?? rec.busId}  •  ${rec.stopName ?? "--"}  •  ${rec.tapTime}',
                                      style: const TextStyle(
                                          color: AppColors.mutedText,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.12),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isBoarded ? 'In' : 'Out',
                                      style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(rec.date,
                                      style: const TextStyle(
                                          color: AppColors.mutedText,
                                          fontSize: 10)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
