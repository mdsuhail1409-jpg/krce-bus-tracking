// ============================================================
// App Configuration — Server URL, WS URL
// ============================================================
class AppConfig {
  // Change this to your server IP / domain
  static const String apiBaseUrl = 'http://10.245.235.53:8000';
  static const String wsBaseUrl = 'ws://10.245.235.53:8000';

  // KRCE Campus coordinates
  static const double collegeLat = 10.927669;
  static const double collegeLon = 78.7410;

  // Polling intervals
  static const Duration busPollInterval = Duration(seconds: 5);
  static const Duration gpsBroadcastInterval = Duration(seconds: 4);
}
