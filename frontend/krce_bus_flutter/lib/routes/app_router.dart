import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/student/screens/student_dashboard.dart';
import '../features/student/screens/staff_dashboard.dart';
import '../features/parent/screens/parent_dashboard.dart';
import '../features/driver/screens/driver_dashboard.dart';
import '../features/admin/screens/admin_dashboard.dart';
import '../features/map/screens/map_screen.dart';
import '../features/history/screens/logs_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../core/theme/app_colors.dart';

// Shell route with bottom nav
final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authProvider.notifier);
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: auth.isAuthenticated ? _homeRoute(auth.role) : '/login',
    redirect: (context, state) {
      final isLoggedIn = auth.isAuthenticated;
      final isAuthPage = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthPage) return '/login';
      if (isLoggedIn && isAuthPage) return _homeRoute(auth.role);
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            _AppShell(child: child, role: auth.role),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => _dashboardFor(auth.role)),
          GoRoute(
            path: '/map',
            builder: (context, state) => const MapScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const LogsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});

String _homeRoute(String role) => '/home';

Widget _dashboardFor(String role) {
  switch (role) {
    case 'admin':
    case 'committee':
      return const AdminDashboard();
    case 'driver':
      return const DriverDashboard();
    case 'staff':
      return const StaffDashboard();
    case 'parent':
      return const ParentDashboard();
    default:
      return const StudentDashboard();
  }
}

class _AppShell extends StatelessWidget {
  final Widget child;
  final String role;

  const _AppShell({required this.child, required this.role});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    final navItems = [
      _NavItem(icon: Icons.home_outlined, label: 'Home', route: '/home'),
      _NavItem(
          icon: Icons.location_on_outlined, label: 'Map', route: '/map'),
      _NavItem(icon: Icons.list_alt_outlined, label: 'Logs', route: '/history'),
      _NavItem(icon: Icons.person_outlined, label: 'Profile', route: '/profile'),
    ];

    int selectedIndex = navItems.indexWhere((n) => n.route == location);
    if (selectedIndex == -1) selectedIndex = 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedIndex: selectedIndex,
          onDestinationSelected: (i) {
            context.go(navItems[i].route);
          },
          destinations: navItems
              .map((n) => NavigationDestination(
                    icon: Icon(n.icon),
                    label: n.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem(
      {required this.icon, required this.label, required this.route});
}
