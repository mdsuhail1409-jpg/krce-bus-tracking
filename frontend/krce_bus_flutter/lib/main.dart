// ============================================================
// KRCE Bus Track — Flutter Entry Point
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'core/services/notification_service.dart';
import 'routes/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Hive offline cache
  await Hive.initFlutter();

  // Init local notifications
  await NotificationService.init();

  runApp(
    const ProviderScope(
      child: KrceBusApp(),
    ),
  );
}

class KrceBusApp extends ConsumerWidget {
  const KrceBusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'KRCE BusTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
