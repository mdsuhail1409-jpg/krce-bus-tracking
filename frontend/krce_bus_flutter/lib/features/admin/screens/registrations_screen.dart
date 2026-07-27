import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class RegistrationsScreen extends ConsumerStatefulWidget {
  const RegistrationsScreen({super.key});

  @override
  ConsumerState<RegistrationsScreen> createState() => _RegistrationsScreenState();
}

class _RegistrationsScreenState extends ConsumerState<RegistrationsScreen> {
  List<Registration> _registrations = [];
  List<Bus> _buses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final auth = ref.read(authProvider);
    final api = ref.read(apiServiceProvider);
    try {
      final results = await Future.wait([
        api.getAdminRegistrations(auth.token, status: 'pending'),
        api.getBuses(auth.token),
      ]);
      if (mounted) {
        setState(() {
          _registrations = results[0] as List<Registration>;
          _buses = results[1] as List<Bus>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Future<void> _handleAction(Registration reg, String action) async {
    if (action == 'approved') {
      _showApproveDialog(reg);
    } else {
      _showRejectDialog(reg);
    }
  }

  void _showApproveDialog(Registration reg) {
    String? selectedBusId = reg.busId ?? (_buses.isNotEmpty ? _buses.first.id : null);
    final rfidController = TextEditingController(text: reg.rfidCard ?? '');
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceColor,
              shape: RoundedCornerShape(16),
              title: const Text(
                'Approve Registration',
                style: TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name: ${reg.name}', style: const TextStyle(color: AppColors.textColor)),
                    const SizedBox(height: 8),
                    Text('Email: ${reg.email}', style: const TextStyle(color: AppColors.mutedText, fontSize: 13)),
                    const SizedBox(height: 16),
                    const Text('Assign RFID Card (Optional)', style: TextStyle(color: AppColors.mutedText, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: rfidController,
                      style: const TextStyle(color: AppColors.textColor),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.backgroundColor,
                        hintText: 'e.g. RF928410',
                        hintStyle: const TextStyle(color: AppColors.mutedText, fontSize: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Assign Bus (Optional)', style: TextStyle(color: AppColors.mutedText, fontSize: 12)),
                    const SizedBox(height: 6),
                    if (_buses.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: AppColors.surfaceColor,
                            value: selectedBusId,
                            isExpanded: true,
                            items: _buses.map((bus) {
                              return DropdownMenuItem<String>(
                                value: bus.id,
                                child: Text('Bus ${bus.number} (${bus.routeName})',
                                    style: const TextStyle(color: AppColors.textColor, fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setDialogState(() {
                                selectedBusId = val;
                              });
                            },
                          ),
                        ),
                      )
                    else
                      const Text('No active buses available', style: TextStyle(color: AppColors.errorRed)),
                    const SizedBox(height: 16),
                    const Text('Approval Notes', style: TextStyle(color: AppColors.mutedText, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      style: const TextStyle(color: AppColors.textColor),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.backgroundColor,
                        hintText: 'Add remarks...',
                        hintStyle: const TextStyle(color: AppColors.mutedText, fontSize: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.mutedText)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successGreen,
                    shape: RoundedCornerShape(10),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    final auth = ref.read(authProvider);
                    final api = ref.read(apiServiceProvider);
                    try {
                      final res = await api.actionRegistration(
                        auth.token,
                        regId: reg.id,
                        action: 'approved',
                        notes: notesController.text,
                        rfidCard: rfidController.text.isNotEmpty ? rfidController.text : null,
                        busId: selectedBusId,
                      );
                      if (res.status == 'ok') {
                        _fetchData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Registration approved successfully'), backgroundColor: AppColors.successGreen),
                        );
                      }
                    } catch (e) {
                      setState(() => _isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
                      );
                    }
                  },
                  child: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRejectDialog(Registration reg) {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceColor,
          shape: RoundedCornerShape(16),
          title: const Text(
            'Reject Registration',
            style: TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: ${reg.name}', style: const TextStyle(color: AppColors.textColor)),
              const SizedBox(height: 8),
              Text('Email: ${reg.email}', style: const TextStyle(color: AppColors.mutedText, fontSize: 13)),
              const SizedBox(height: 16),
              const Text('Reason for Rejection', style: TextStyle(color: AppColors.mutedText, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: notesController,
                style: const TextStyle(color: AppColors.textColor),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.backgroundColor,
                  hintText: 'Provide details...',
                  hintStyle: const TextStyle(color: AppColors.mutedText, fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.mutedText)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                shape: RoundedCornerShape(10),
              ),
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                final auth = ref.read(authProvider);
                final api = ref.read(apiServiceProvider);
                try {
                  final res = await api.actionRegistration(
                    auth.token,
                    regId: reg.id,
                    action: 'rejected',
                    notes: notesController.text,
                  );
                  if (res.status == 'ok') {
                    _fetchData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Registration rejected'), backgroundColor: AppColors.errorRed),
                    );
                  }
                } catch (e) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
                  );
                }
              },
              child: const Text('Reject', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceColor,
        elevation: 0,
        title: const Text(
          'Pending Approvals',
          style: TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _registrations.isEmpty
              ? const Center(
                  child: Text(
                    'No pending registrations found',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _registrations.length,
                    itemBuilder: (context, idx) {
                      final reg = _registrations[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  reg.name,
                                  style: const TextStyle(
                                    color: AppColors.textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.indigoPrimary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    reg.role.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.indigoPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Email: ${reg.email}', style: const TextStyle(color: AppColors.mutedText, fontSize: 13)),
                            if (reg.phone != null && reg.phone!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Phone: ${reg.phone}', style: const TextStyle(color: AppColors.mutedText, fontSize: 13)),
                            ],
                            if (reg.collegeId != null && reg.collegeId!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('College ID: ${reg.collegeId}', style: const TextStyle(color: AppColors.mutedText, fontSize: 13)),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppColors.errorRed),
                                    shape: RoundedCornerShape(10),
                                  ),
                                  onPressed: () => _handleAction(reg, 'rejected'),
                                  child: const Text('Reject', style: TextStyle(color: AppColors.errorRed)),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.successGreen,
                                    shape: RoundedCornerShape(10),
                                  ),
                                  onPressed: () => _handleAction(reg, 'approved'),
                                  child: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// Extension to simplify RoundedRectangleBorder instantiation
RoundedRectangleBorder RoundedCornerShape(double radius) {
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
  );
}
