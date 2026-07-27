import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<User> _allUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _roles = ['student', 'driver', 'parent', 'committee'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _roles.length, vsync: this);
    _fetchUsers();
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

  List<User> _filteredUsers(String role) {
    return _allUsers.where((u) {
      final matchesRole = role == 'student' 
          ? (u.role == 'student' || u.role == 'staff')
          : (u.role == role);
      final query = _searchQuery.toLowerCase();
      final matchesSearch = u.name.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          (u.collegeId?.toLowerCase().contains(query) ?? false);
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
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.borderColor),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isActive 
                                        ? AppColors.indigoPrimary.withOpacity(0.1)
                                        : AppColors.mutedText.withOpacity(0.1),
                                    child: Icon(
                                      role == 'driver' ? Icons.directions_bus : Icons.person,
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
                                          Text(
                                            'Assigned Bus: ${user.busId}',
                                            style: const TextStyle(
                                              color: AppColors.indigoPrimary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
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
