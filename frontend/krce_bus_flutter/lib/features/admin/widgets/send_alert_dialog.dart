import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class SendAlertDialog extends ConsumerStatefulWidget {
  final List<Bus> buses;
  const SendAlertDialog({super.key, required this.buses});

  @override
  ConsumerState<SendAlertDialog> createState() => _SendAlertDialogState();
}

class _SendAlertDialogState extends ConsumerState<SendAlertDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _alertType = 'info';
  String _targetRole = 'all';
  String? _targetBusId;
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSending = true);

    final auth = ref.read(authProvider);
    final api = ref.read(apiServiceProvider);

    try {
      final res = await api.sendAlert(
        auth.token,
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        alertType: _alertType,
        targetRole: _targetRole,
        targetBus: _targetBusId,
      );

      if (res.status == 'ok' && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alert broadcasted successfully'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send alert: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.campaign_outlined, color: AppColors.indigoPrimary),
          SizedBox(width: 10),
          Text(
            'Broadcast Alert',
            style: TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Field
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: AppColors.textColor),
                decoration: InputDecoration(
                  labelText: 'Alert Title',
                  labelStyle: const TextStyle(color: AppColors.mutedText),
                  filled: true,
                  fillColor: AppColors.backgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.indigoPrimary),
                  ),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Message Field
              TextFormField(
                controller: _messageController,
                maxLines: 3,
                style: const TextStyle(color: AppColors.textColor),
                decoration: InputDecoration(
                  labelText: 'Detailed Message',
                  labelStyle: const TextStyle(color: AppColors.mutedText),
                  filled: true,
                  fillColor: AppColors.backgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.indigoPrimary),
                  ),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Alert Type
              const Text('Severity Level', style: TextStyle(color: AppColors.mutedText, fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                dropdownColor: AppColors.surfaceColor,
                value: _alertType,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.backgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'info',
                    child: Text('Information', style: TextStyle(color: AppColors.textColor)),
                  ),
                  DropdownMenuItem(
                    value: 'warning',
                    child: Text('Warning', style: TextStyle(color: AppColors.warningYellow)),
                  ),
                  DropdownMenuItem(
                    value: 'emergency',
                    child: Text('Emergency', style: TextStyle(color: AppColors.errorRed)),
                  ),
                ],
                onChanged: (val) => setState(() => _alertType = val!),
              ),
              const SizedBox(height: 16),

              // Target Audience
              const Text('Target Audience', style: TextStyle(color: AppColors.mutedText, fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                dropdownColor: AppColors.surfaceColor,
                value: _targetRole,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.backgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('All Users', style: TextStyle(color: AppColors.textColor)),
                  ),
                  DropdownMenuItem(
                    value: 'student',
                    child: Text('Students & Staff', style: TextStyle(color: AppColors.textColor)),
                  ),
                  DropdownMenuItem(
                    value: 'driver',
                    child: Text('Drivers', style: TextStyle(color: AppColors.textColor)),
                  ),
                  DropdownMenuItem(
                    value: 'parent',
                    child: Text('Parents', style: TextStyle(color: AppColors.textColor)),
                  ),
                ],
                onChanged: (val) => setState(() => _targetRole = val!),
              ),
              const SizedBox(height: 16),

              // Target Bus (Optional)
              const Text('Target Bus (Optional)', style: TextStyle(color: AppColors.mutedText, fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                dropdownColor: AppColors.surfaceColor,
                value: _targetBusId,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.backgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('No Bus Filtering', style: TextStyle(color: AppColors.mutedText)),
                  ),
                  ...widget.buses.map((bus) {
                    return DropdownMenuItem(
                      value: bus.id,
                      child: Text('Bus ${bus.number} (${bus.routeName})', style: const TextStyle(color: AppColors.textColor)),
                    );
                  }),
                ],
                onChanged: (val) => setState(() => _targetBusId = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.mutedText)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.indigoPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: _isSending ? null : _submit,
          child: _isSending
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Send Alert', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
