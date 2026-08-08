import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

/// Shows the 4-step reassign-bus bottom sheet.
/// Returns `true` when the reassignment was successfully completed.
Future<bool?> showReassignBusDialog(
  BuildContext context, {
  required User user,
  required List<Bus> buses,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ReassignBusDialog(user: user, buses: buses),
  );
}

class ReassignBusDialog extends ConsumerStatefulWidget {
  final User user;
  final List<Bus> buses;

  const ReassignBusDialog({
    super.key,
    required this.user,
    required this.buses,
  });

  @override
  ConsumerState<ReassignBusDialog> createState() => _ReassignBusDialogState();
}

class _ReassignBusDialogState extends ConsumerState<ReassignBusDialog>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  Bus? _selectedBus;
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _nextStep() {
    _animCtrl.reverse().then((_) {
      setState(() => _step++);
      _animCtrl.forward();
    });
  }

  void _prevStep() {
    _animCtrl.reverse().then((_) {
      setState(() => _step--);
      _animCtrl.forward();
    });
  }

  List<Bus> get _availableBuses =>
      widget.buses.where((b) => b.id != widget.user.busId).toList();

  Future<void> _doReassign() async {
    if (_selectedBus == null) return;
    setState(() => _isLoading = true);
    final auth = ref.read(authProvider);
    final api = ref.read(apiServiceProvider);
    try {
      final result = await api.reassignBus(
        auth.token,
        widget.user.id,
        _selectedBus!.id,
        reason: _reasonController.text.trim(),
      );
      if (!mounted) return;
      if (result.status == 'ok') {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${widget.user.name} reassigned to ${_selectedBus!.number}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reassignment failed: $e'),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_note, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reassign Bus',
                        style: TextStyle(
                          color: AppColors.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Step ${_step + 1} of 4',
                        style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.mutedText),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _StepIndicator(currentStep: _step),
          const SizedBox(height: 24),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildStepContent(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: _buildActions(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _StepConfirmPassenger(user: widget.user);
      case 1:
        return _StepSelectBus(
          buses: _availableBuses,
          selected: _selectedBus,
          onSelect: (b) => setState(() => _selectedBus = b),
        );
      case 2:
        return _StepReason(controller: _reasonController);
      case 3:
        return _StepReview(
          user: widget.user,
          selectedBus: _selectedBus,
          reason: _reasonController.text.trim(),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActions() {
    if (_step == 0) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.mutedText,
                side: const BorderSide(color: AppColors.borderColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _GradientButton(
              label: 'Yes, Correct Passenger',
              icon: Icons.check,
              onPressed: _nextStep,
            ),
          ),
        ],
      );
    }

    if (_step == 1) {
      return Row(
        children: [
          _BackButton(onPressed: _prevStep),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _GradientButton(
              label: 'Next',
              icon: Icons.arrow_forward,
              onPressed: _selectedBus != null ? _nextStep : null,
            ),
          ),
        ],
      );
    }

    if (_step == 2) {
      return Row(
        children: [
          _BackButton(onPressed: _prevStep),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _GradientButton(
              label: 'Review Assignment',
              icon: Icons.preview,
              onPressed: _nextStep,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        _BackButton(onPressed: _isLoading ? null : _prevStep),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _isLoading
              ? Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ),
                )
              : _GradientButton(
                  label: 'Confirm Reassignment',
                  icon: Icons.done_all,
                  onPressed: _doReassign,
                ),
        ),
      ],
    );
  }
}

// ─── Step 1: Confirm Passenger ───────────────────────
class _StepConfirmPassenger extends StatelessWidget {
  final User user;
  const _StepConfirmPassenger({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Is this the correct passenger?',
          style: TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text(
          'Please verify the details below before proceeding.',
          style: TextStyle(color: AppColors.mutedText, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderColor),
            boxShadow: [BoxShadow(color: AppColors.indigoPrimary.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: const BoxDecoration(gradient: AppColors.gradientPrimary, shape: BoxShape.circle),
                child: const Icon(Icons.person, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: const TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold, fontSize: 17)),
                    const SizedBox(height: 4),
                    _InfoRow(icon: Icons.badge, label: user.role.toUpperCase()),
                    if (user.collegeId != null && user.collegeId!.isNotEmpty)
                      _InfoRow(icon: Icons.numbers, label: 'ID: ${user.collegeId}'),
                    _InfoRow(icon: Icons.email_outlined, label: user.email),
                    user.busId != null && user.busId!.isNotEmpty
                        ? _InfoRow(icon: Icons.directions_bus, label: 'Current Bus: ${user.busId}', color: AppColors.indigoPrimary)
                        : const _InfoRow(icon: Icons.directions_bus_outlined, label: 'No bus assigned'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warningYellow.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.warningYellow.withOpacity(0.4)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.warningYellow, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Confirming will permanently update the bus assignment.',
                  style: TextStyle(color: AppColors.warningYellow, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoRow({required this.icon, required this.label, this.color = AppColors.mutedText});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 12), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

// ─── Step 2: Select Bus ──────────────────────────────
class _StepSelectBus extends StatelessWidget {
  final List<Bus> buses;
  final Bus? selected;
  final ValueChanged<Bus> onSelect;

  const _StepSelectBus({required this.buses, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select the new bus', style: TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        const Text('Choose which bus to assign this passenger to.', style: TextStyle(color: AppColors.mutedText, fontSize: 13)),
        const SizedBox(height: 16),
        if (buses.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderColor)),
            child: const Center(child: Text('No other buses available.', style: TextStyle(color: AppColors.mutedText))),
          )
        else
          ...buses.map((bus) {
            final isSelected = selected?.id == bus.id;
            return GestureDetector(
              onTap: () => onSelect(bus),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.indigoPrimary.withOpacity(0.08) : AppColors.surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isSelected ? AppColors.indigoPrimary : AppColors.borderColor, width: isSelected ? 2 : 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.indigoPrimary.withOpacity(0.15) : AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.directions_bus, color: isSelected ? AppColors.indigoPrimary : AppColors.mutedText, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(bus.number, style: TextStyle(color: isSelected ? AppColors.indigoPrimary : AppColors.textColor, fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(bus.routeName, style: const TextStyle(color: AppColors.mutedText, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (isSelected) const Icon(Icons.check_circle, color: AppColors.indigoPrimary, size: 22),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Step 3: Reason ──────────────────────────────────
class _StepReason extends StatelessWidget {
  final TextEditingController controller;
  const _StepReason({required this.controller});

  @override
  Widget build(BuildContext context) {
    const suggestions = ['Student relocated', 'Route change request', 'Capacity management', 'Administrative update'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Reason for reassignment', style: TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        const Text('This is optional but helps track bus assignment history.', style: TextStyle(color: AppColors.mutedText, fontSize: 13)),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: AppColors.textColor),
          decoration: InputDecoration(
            hintText: 'Enter a reason (optional)...',
            hintStyle: const TextStyle(color: AppColors.mutedText),
            filled: true,
            fillColor: AppColors.surfaceColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.indigoPrimary, width: 2)),
          ),
        ),
        const SizedBox(height: 14),
        const Text('Quick suggestions:', style: TextStyle(color: AppColors.mutedText, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: suggestions.map((s) => GestureDetector(
            onTap: () => controller.text = s,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.indigoPrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.indigoPrimary.withOpacity(0.25)),
              ),
              child: Text(s, style: const TextStyle(color: AppColors.indigoPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          )).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── Step 4: Review ──────────────────────────────────
class _StepReview extends StatelessWidget {
  final User user;
  final Bus? selectedBus;
  final String reason;

  const _StepReview({required this.user, required this.selectedBus, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Review & Confirm', style: TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        const Text('Please review the details below before confirming.', style: TextStyle(color: AppColors.mutedText, fontSize: 13)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderColor),
            boxShadow: [BoxShadow(color: AppColors.indigoPrimary.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              _ReviewRow(label: 'Passenger', value: user.name, icon: Icons.person),
              const Divider(color: AppColors.borderColor, height: 1),
              _ReviewRow(label: 'Role', value: user.role.toUpperCase(), icon: Icons.badge),
              if (user.collegeId != null && user.collegeId!.isNotEmpty) ...[
                const Divider(color: AppColors.borderColor, height: 1),
                _ReviewRow(label: 'College ID', value: user.collegeId!, icon: Icons.numbers),
              ],
              const Divider(color: AppColors.borderColor, height: 1),
              _ReviewRow(label: 'From Bus', value: user.busId ?? 'None', icon: Icons.directions_bus_outlined, valueColor: AppColors.mutedText),
              const Divider(color: AppColors.borderColor, height: 1),
              _ReviewRow(
                label: 'To Bus',
                value: selectedBus != null ? '${selectedBus!.number} — ${selectedBus!.routeName}' : '—',
                icon: Icons.directions_bus,
                valueColor: AppColors.indigoPrimary,
                valueBold: true,
              ),
              if (reason.isNotEmpty) ...[
                const Divider(color: AppColors.borderColor, height: 1),
                _ReviewRow(label: 'Reason', value: reason, icon: Icons.notes),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.errorRed.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.errorRed.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.errorRed, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text("This will permanently update the passenger's bus assignment.", style: TextStyle(color: AppColors.errorRed, fontSize: 12))),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final bool valueBold;

  const _ReviewRow({required this.label, required this.value, required this.icon, this.valueColor, this.valueBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.mutedText),
          const SizedBox(width: 10),
          SizedBox(width: 85, child: Text(label, style: const TextStyle(color: AppColors.mutedText, fontSize: 13))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.textColor,
                fontSize: 13,
                fontWeight: valueBold ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step Indicator ──────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  static const _labels = ['Confirm', 'Select Bus', 'Reason', 'Review'];
  static const _icons = [Icons.person_search, Icons.directions_bus, Icons.edit_note, Icons.done_all];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final isDone = i < currentStep;
          final isCurrent = i == currentStep;
          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: isCurrent ? AppColors.indigoPrimary : isDone ? AppColors.successGreen : AppColors.bgSecondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: isCurrent || isDone ? Colors.transparent : AppColors.borderColor),
                      ),
                      child: Icon(isDone ? Icons.check : _icons[i], color: isCurrent || isDone ? Colors.white : AppColors.mutedText, size: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _labels[i],
                      style: TextStyle(color: isCurrent ? AppColors.indigoPrimary : AppColors.mutedText, fontSize: 9, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
                    ),
                  ],
                ),
                if (i < _labels.length - 1)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      height: 2,
                      color: isDone ? AppColors.successGreen : AppColors.borderColor,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─── Shared Buttons ──────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _GradientButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 50,
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.gradientPrimary : null,
          color: enabled ? null : AppColors.borderColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: enabled ? Colors.white : AppColors.mutedText, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: enabled ? Colors.white : AppColors.mutedText, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(color: AppColors.surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderColor)),
        child: const Icon(Icons.arrow_back, color: AppColors.mutedText, size: 20),
      ),
    );
  }
}
