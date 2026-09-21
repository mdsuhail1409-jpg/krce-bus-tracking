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

  // Stop coordinates
  static const Map<String, List<double>> stopCoords = {
    "KRCE Campus": [10.927669, 78.7410],
    "Samayapuram": [10.9310, 78.8130],
    "Woraiyur Bus Stand": [10.7905, 78.7047],
    "Woraiyur Town": [10.7920, 78.7020],
    "Gandhi Market": [10.8190, 78.6990],
    "Panjappur": [10.7516, 78.6830],
    "Srirangam": [10.8631, 78.6933],
    "Cauvery Bridge": [10.8416, 78.7010],
    "K.K. Nagar": [10.8176, 78.6960],
    "Thuvakudi": [10.8730, 78.7680],
    "Ariyamangalam": [10.8280, 78.7380],
    "Cantonment": [10.8116, 78.6860],
    "Collector Office": [10.8080, 78.6820],
    "Palakarai": [10.8120, 78.6930],
    "Chatram Bus Stand": [10.8096, 78.6964],
    "Central": [10.8050, 78.6840],
    "Junction": [10.8020, 78.6810],
    "Thillai Nagar": [10.8240, 78.6890],
    "Mannarpuram": [10.8182, 78.7030],
    "Rockfort": [10.8300, 78.6970],
    "Chinthamani": [10.8350, 78.7020],
    "TVS Tollgate": [10.8015, 78.6890],
    "SIT": [10.8055, 78.6912],
    "Ambigapuram": [10.7985, 78.7050],
    "Manjathidal": [10.7950, 78.7110],
    "Armory Gate": [10.7915, 78.7180],
    "Panjayat Office": [10.7880, 78.7240],
    "Kalkandar Kottai": [10.7850, 78.7310],
    "BVM Trichy": [10.8100, 78.6950],
    "Kadai Veethi": [10.8050, 78.7000],
    "Mandabam": [10.8000, 78.7080],
    "Aathupalam": [10.7930, 78.7150]
  };

  // Polling intervals
  static const Duration busPollInterval = Duration(seconds: 5);
  static const Duration gpsBroadcastInterval = Duration(seconds: 4);
}
