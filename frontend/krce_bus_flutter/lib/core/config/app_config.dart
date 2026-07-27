// ============================================================
// App Configuration — Server URL, WS URL
// ============================================================
class AppConfig {
  // Change this to your server IP / domain
  static const String apiBaseUrl = 'https://krce-bus-tracking.onrender.com';
  static const String wsBaseUrl = 'wss://krce-bus-tracking.onrender.com';

  // KRCE Campus coordinates
  static const double collegeLat = 10.927669;
  static const double collegeLon = 78.7410;

  // Polling intervals
  static const Duration busPollInterval = Duration(seconds: 5);
  static const Duration gpsBroadcastInterval = Duration(seconds: 4);
}
