import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/student/screens/student_dashboard.dart';
import '../features/parent/screens/parent_dashboard.dart';
import '../features/driver/screens/driver_dashboard.dart';
import '../features/admin/screens/admin_dashboard.dart';
import '../features/map/screens/map_screen.dart';
import '../features/history/screens/history_screen.dart';
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
      final isLoginPage = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginPage) return '/login';
      if (isLoggedIn && isLoginPage) return _homeRoute(auth.role);
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            _AppShell(child: child, role: auth.role),
        routes: [
          GoRoute(
              path: '/home',
              builder: (_, __) => _dashboardFor(auth.role)),
          GoRoute(
              path: '/map',
              builder: (_, __) => const MapScreen()),
          GoRoute(
              path: '/history',
              builder: (_, __) => const HistoryScreen()),
          GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfileScreen()),
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
      _NavItem(icon: Icons.list_alt_outlined, label: 'History', route: '/history'),
      _NavItem(icon: Icons.person_outlined, label: 'Profile', route: '/profile'),
    ];

    int selectedIndex = navItems.indexWhere((n) => n.route == location);
    if (selectedIndex == -1) selectedIndex = 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.3), blurRadius: 10)
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
