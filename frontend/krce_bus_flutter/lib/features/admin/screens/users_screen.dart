import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/reassign_bus_dialog.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<User> _allUsers = [];
  List<Bus> _buses = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _roles = ['student', 'driver', 'parent', 'committee'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _roles.length, vsync: this);
    _fetchUsers();
    _fetchBuses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    final auth = ref.read(authProvider);
    final api = ref.read(apiServiceProvider);
    try {
      final users = await api.getAdminUsers(auth.token);
      if (mounted) {
        setState(() {
          _allUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Future<void> _fetchBuses() async {
    final auth = ref.read(authProvider);
    final api = ref.read(apiServiceProvider);
    try {
      final buses = await api.getBuses(auth.token);
      if (mounted) setState(() => _buses = buses);
    } catch (_) {}
  }

  Future<void> _openReassignDialog(User user) async {
    // Only allow reassign for students and staff
    if (user.role != 'student' && user.role != 'staff') return;
    final result = await showReassignBusDialog(
      context,
      user: user,
      buses: _buses,
    );
    if (result == true) {
      _fetchUsers();
    }
  }

  Future<void> _toggleUserStatus(User user) async {
    final auth = ref.read(authProvider);
    final api = ref.read(apiServiceProvider);
    try {
      final res = await api.toggleUser(auth.token, user.id);
      if (res.status == 'ok') {
        _fetchUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User status updated successfully'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle status: $e'), backgroundColor: AppColors.errorRed),
      );
    }
  }

  Future<void> _openAssignWardDialog(User parent) async {
    final students = _allUsers.where((u) => u.role == 'student').toList();
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students found in the directory to assign.'), backgroundColor: AppColors.errorRed),
      );
      return;
    }

    String? selectedStudentId = parent.parentOf ?? (students.isNotEmpty ? (students.first.collegeId ?? students.first.id) : null);
    if (!students.any((s) => s.collegeId == selectedStudentId || s.id == selectedStudentId)) {
      selectedStudentId = students.first.collegeId ?? students.first.id;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedStudent = students.firstWhere(
            (s) => s.collegeId == selectedStudentId || s.id == selectedStudentId,
            orElse: () => students.first,
          );

          return AlertDialog(
            backgroundColor: AppColors.surfaceColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.link, color: AppColors.indigoPrimary),
                SizedBox(width: 8),
                Text('Assign Student Ward', style: TextStyle(color: AppColors.textColor, fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.surfaceColor,
                          child: Icon(Icons.family_restroom, color: AppColors.indigoPrimary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(parent.name, style: const TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold)),
                              Text(parent.email, style: const TextStyle(color: AppColors.mutedText, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Student (Ward)', style: TextStyle(color: AppColors.mutedText, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: AppColors.surfaceColor,
                        value: selectedStudentId,
                        isExpanded: true,
                        items: students.map((s) {
                          final id = s.collegeId ?? s.id;
                          final busDisplay = s.busNumber ?? s.busId ?? 'No Bus';
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(
                              '${s.name} ($id) • Bus: $busDisplay',
                              style: const TextStyle(color: AppColors.textColor, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedStudentId = val;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.indigoPrimary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.indigoPrimary.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Student Bus & Route Details', style: TextStyle(color: AppColors.indigoPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.directions_bus, size: 14, color: AppColors.indigoPrimary),
                            const SizedBox(width: 6),
                            Text(
                              'Bus: ${selectedStudent.busNumber ?? selectedStudent.busId ?? "Unassigned"}',
                              style: const TextStyle(color: AppColors.textColor, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                        if (selectedStudent.routeName != null && selectedStudent.routeName!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Route: ${selectedStudent.routeName}',
                            style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppColors.mutedText)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.indigoPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (selectedStudentId == null) return;
                  Navigator.pop(ctx);
                  final auth = ref.read(authProvider);
                  final api = ref.read(apiServiceProvider);
                  try {
                    final res = await api.assignParentWard(
                      auth.token,
                      parentId: parent.id,
                      studentId: selectedStudentId!,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(res.message ?? 'Ward assigned successfully'), backgroundColor: AppColors.successGreen),
                      );
                      _fetchUsers();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to assign ward: $e'), backgroundColor: AppColors.errorRed),
                      );
                    }
                  }
                },
                child: const Text('Save Ward', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  List<User> _filteredUsers(String role) {
    return _allUsers.where((u) {
      final matchesRole = role == 'student' 
          ? (u.role == 'student' || u.role == 'staff')
          : (u.role == role);
      final query = _searchQuery.toLowerCase();
      final matchesSearch = u.name.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          (u.collegeId?.toLowerCase().contains(query) ?? false) ||
          (u.wardName?.toLowerCase().contains(query) ?? false) ||
          (u.wardCollegeId?.toLowerCase().contains(query) ?? false) ||
          (u.parentOf?.toLowerCase().contains(query) ?? false) ||
          (u.busNumber?.toLowerCase().contains(query) ?? false);
      return matchesRole && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceColor,
        elevation: 0,
        title: const Text(
          'User Management',
          style: TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textColor),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.indigoPrimary,
          unselectedLabelColor: AppColors.mutedText,
          indicatorColor: AppColors.indigoPrimary,
          tabs: const [
            Tab(text: 'Students'),
            Tab(text: 'Drivers'),
            Tab(text: 'Parents'),
            Tab(text: 'Admins'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: AppColors.textColor),
              decoration: InputDecoration(
                hintText: 'Search by name, ID or email...',
                hintStyle: const TextStyle(color: AppColors.mutedText),
                prefixIcon: const Icon(Icons.search, color: AppColors.mutedText),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.mutedText),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.indigoPrimary),
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: _roles.map((role) {
                      final users = _filteredUsers(role);
                      if (users.isEmpty) {
                        return const Center(
                          child: Text(
                            'No users found',
                            style: TextStyle(color: AppColors.mutedText, fontSize: 16),
                          ),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: _fetchUsers,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: users.length,
                          itemBuilder: (context, idx) {
                            final user = users[idx];
                            final isActive = user.isActive == 1;
                            final canReassign = user.role == 'student' || user.role == 'staff';
                            final isParent = user.role == 'parent';
                            final isInteractive = canReassign || isParent;
                            return GestureDetector(
                              onTap: canReassign
                                  ? () => _openReassignDialog(user)
                                  : (isParent ? () => _openAssignWardDialog(user) : null),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isInteractive
                                        ? AppColors.indigoPrimary.withOpacity(0.25)
                                        : AppColors.borderColor,
                                  ),
                                  boxShadow: isInteractive
                                      ? [BoxShadow(color: AppColors.indigoPrimary.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))]
                                      : [],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: isActive
                                          ? AppColors.indigoPrimary.withOpacity(0.1)
                                          : AppColors.mutedText.withOpacity(0.1),
                                      child: Icon(
                                        role == 'driver' 
                                            ? Icons.directions_bus 
                                            : (isParent ? Icons.family_restroom : Icons.person),
                                        color: isActive ? AppColors.indigoPrimary : AppColors.mutedText,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.name,
                                            style: const TextStyle(
                                              color: AppColors.textColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            user.email,
                                            style: const TextStyle(
                                              color: AppColors.mutedText,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (isParent) ...[
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppColors.indigoPrimary.withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.school, size: 12, color: AppColors.indigoPrimary),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      user.wardName != null || user.parentOf != null
                                                          ? 'Ward: ${user.wardName ?? "Student"} (${user.wardCollegeId ?? user.parentOf})'
                                                          : 'No Ward Linked',
                                                      style: TextStyle(
                                                        color: user.wardName != null || user.parentOf != null
                                                            ? AppColors.indigoPrimary
                                                            : AppColors.mutedText,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.directions_bus, size: 12, color: AppColors.mutedText),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    user.wardBusNumber != null || user.busNumber != null || user.busId != null
                                                        ? 'Bus ${user.wardBusNumber ?? user.busNumber ?? user.busId}${user.wardRouteName != null || user.routeName != null ? " • " + (user.wardRouteName ?? user.routeName!) : ""}'
                                                        : 'No bus assigned',
                                                    style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ] else ...[
                                            if (user.collegeId != null && user.collegeId!.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'ID: ${user.collegeId}',
                                                style: const TextStyle(
                                                  color: AppColors.mutedText,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                            if (user.busId != null && user.busId!.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.directions_bus, size: 12, color: AppColors.indigoPrimary),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    user.busId!,
                                                    style: const TextStyle(
                                                      color: AppColors.indigoPrimary,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ] else if (canReassign) ...[
                                              const SizedBox(height: 4),
                                              const Text(
                                                'No bus assigned',
                                                style: TextStyle(
                                                  color: AppColors.mutedText,
                                                  fontSize: 12,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ],
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        if (canReassign)
                                          Tooltip(
                                            message: 'Reassign Bus',
                                            child: IconButton(
                                              icon: const Icon(Icons.edit_note, size: 20),
                                              color: AppColors.indigoPrimary,
                                              onPressed: () => _openReassignDialog(user),
                                            ),
                                          ),
                                        if (isParent)
                                          Tooltip(
                                            message: 'Assign / Change Student Ward',
                                            child: IconButton(
                                              icon: const Icon(Icons.link, size: 20),
                                              color: AppColors.indigoPrimary,
                                              onPressed: () => _openAssignWardDialog(user),
                                            ),
                                          ),
                                        Switch(
                                          value: isActive,
                                          activeColor: AppColors.successGreen,
                                          inactiveThumbColor: AppColors.mutedText,
                                          onChanged: (_) => _toggleUserStatus(user),
                                        ),
                                        Text(
                                          isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            color: isActive ? AppColors.successGreen : AppColors.mutedText,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
