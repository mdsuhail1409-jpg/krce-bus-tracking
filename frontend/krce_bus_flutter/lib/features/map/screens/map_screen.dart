import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:ui' as ui;
import '../../../core/config/app_config.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/websocket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:dio/dio.dart';

// ── Bus marker custom painter ─────────────────────────────
class BusMarkerPainter extends CustomPainter {
  final String label;
  final bool isOnline;
  final Color? customColor;

  BusMarkerPainter({required this.label, required this.isOnline, this.customColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final paint = Paint()..isAntiAlias = true;
    final bodyColor = customColor ??
        (isOnline ? const Color(0xFF10B981) : const Color(0xFF64748B));

    final cx = w / 2;
    const cy = 38.0;
    const radius = 30.0;

    // Drop shadow
    paint.style = PaintingStyle.fill;
    paint.color = Colors.black.withOpacity(0.25);
    canvas.drawCircle(Offset(cx, cy + 3), radius + 2, paint);

    // White disc background
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), radius, paint);

    // Colored / dark status ring
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3.2;
    paint.color = bodyColor;
    canvas.drawCircle(Offset(cx, cy), radius - 1.6, paint);

    // Heading pointer at top
    final triPath = ui.Path()
      ..moveTo(cx - 5, cy - radius - 1)
      ..lineTo(cx + 5, cy - radius - 1)
      ..lineTo(cx, cy - radius - 7)
      ..close();
    paint.style = PaintingStyle.fill;
    paint.color = bodyColor;
    canvas.drawPath(triPath, paint);

    // Bus silhouette - Dark body color (#111827)
    const darkBusColor = Color(0xFF111827);
    paint.color = darkBusColor;

    // Side mirrors
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 23, cy - 8, 3.5, 9),
        const Radius.circular(1.5),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + 19.5, cy - 8, 3.5, 9),
        const Radius.circular(1.5),
      ),
      paint,
    );

    // Wheels
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 15, cy + 12.5, 6.5, 7),
        const Radius.circular(2),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + 8.5, cy + 12.5, 6.5, 7),
        const Radius.circular(2),
      ),
      paint,
    );

    // Main Bus Body
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - 17.5, cy - 18, 35, 31),
        topLeft: const Radius.circular(10),
        topRight: const Radius.circular(10),
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      ),
      paint,
    );

    // Route display board (White)
    paint.color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 7, cy - 15.5, 14, 3.5),
        const Radius.circular(1.5),
      ),
      paint,
    );

    // Front windshield (White)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 13.5, cy - 10, 27, 13),
        const Radius.circular(3),
      ),
      paint,
    );

    // Headlights (White circles)
    canvas.drawCircle(Offset(cx - 9.5, cy + 7.5), 2.7, paint);
    canvas.drawCircle(Offset(cx + 9.5, cy + 7.5), 2.7, paint);

    // Bus Number Pill Badge at bottom
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();

    final badgeW = (tp.width + 14).clamp(32.0, 70.0);
    const badgeH = 18.0;
    final badgeRect = Rect.fromLTWH(cx - badgeW / 2, cy + radius - 5, badgeW, badgeH);

    // Pill background
    paint.color = const Color(0xFF0F172A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(9)),
      paint,
    );

    // Pill border
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    paint.color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(9)),
      paint,
    );

    // Pill text
    tp.paint(
      canvas,
      Offset(cx - tp.width / 2, cy + radius - 5 + (badgeH - tp.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant BusMarkerPainter old) =>
      old.label != label || old.isOnline != isOnline;
}

// ── Map Screen ────────────────────────────────────────────
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  static const _campus = LatLng(AppConfig.collegeLat, AppConfig.collegeLon);

  GoogleMapController? _mapCtrl;
  List<Bus> _buses = [];
  Map<String, LatLng> _animatedPositions = {};
  Map<String, AnimationController> _animControllers = {};
  Map<String, Animation<LatLng>> _animations = {};
  String? _errorMsg;
  bool _isDarkMode = false;
  bool _isFullscreen = false;
  LatLng? _myLocation;
  Timer? _pollTimer;
  final WebSocketService _wsService = WebSocketService();

  // Cache for marker icons
  BitmapDescriptor? _campusIcon;
  BitmapDescriptor? _busStopIcon;
  final Map<String, BitmapDescriptor> _busIcons = {};

  // Route state
  List<LatLng> _completedRoute = [];
  List<LatLng> _remainingRoute = [];
  double _remainingDist = 0;
  double _remainingDuration = 0;
  Bus? _trackedBus;
  bool _showRoutePanel = false;
  EmergencyAssignmentResponse? _activeEmergency;

  static const String _darkMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [{"color": "#212121"}]
    },
    {
      "elementType": "labels.icon",
      "stylers": [{"visibility": "off"}]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#757575"}]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [{"color": "#212121"}]
    },
    {
      "featureType": "road",
      "elementType": "geometry.fill",
      "stylers": [{"color": "#2c2c2c"}]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [{"color": "#000000"}]
    }
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _initMarkerIcons();
    _startPolling();
    _getMyLocation();
    // Connect WebSocket for real-time bus updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authProvider);
      if (auth.token.isNotEmpty && !auth.token.startsWith('demo_')) {
        _wsService.connect(auth.token, _handleWsMessage);
      }
      // Auto-load single bus for student/parent roles
      final role = auth.role;
      if (role == 'student' || role == 'parent') {
        _autoLoadMyBus();
      }
    });
  }

  /// Handle incoming WebSocket messages — update bus position instantly
  void _handleWsMessage(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    if (type == 'gps_update' || type == 'bus_update') {
      final busId = data['bus_id'] as String? ?? '';
      if (busId.isEmpty || !mounted) return;
      final updatedBus = _buses.indexWhere((b) => 
        b.id == busId || 
        b.number == busId ||
        (busId == 'B07' && b.number == 'TN-07') ||
        (busId == 'TN-07' && b.id == 'B07')
      );
      if (updatedBus == -1 && _buses.isNotEmpty) return;
      // Refresh the full bus list on any GPS update
      _fetchBuses();
    } else if (type == 'alert') {
      final title = data['title'] as String? ?? 'Bus Alert';
      final msg = data['message'] as String? ?? '';

      // Trigger audio alert ringtone, vibration, and system notification
      NotificationService.showNotification(
        title: title,
        body: msg,
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        playAudioFeedback: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('$title: $msg', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF4F46E5),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _wsService.disconnect();
    for (final c in _animControllers.values) {
      c.dispose();
    }
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _initMarkerIcons() async {
    final campusIcon = await _getCampusMarkerIcon();
    final stopIcon = await _getBusStopMarkerIcon();
    if (mounted) {
      setState(() {
        _campusIcon = campusIcon;
        _busStopIcon = stopIcon;
      });
    }
  }

  void _startPolling() {
    _fetchBuses();
    _pollTimer = Timer.periodic(AppConfig.busPollInterval, (_) => _fetchBuses());
  }

  Future<void> _autoLoadMyBus() async {
    await Future.delayed(const Duration(seconds: 2)); // wait for first poll
    if (!mounted || _buses.isEmpty) return;
    final bus = _buses.first;
    if (bus.live != null && _mapCtrl != null) {
      _mapCtrl!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(bus.live!.lat, bus.live!.lon), 15),
      );
      _drawRoute(bus);
    }
  }

  Future<void> _fetchBuses() async {
    final auth = ref.read(authProvider);
    final api = ref.read(apiServiceProvider);
    try {
      final buses = await api.getBuses(auth.token);
      EmergencyAssignmentResponse? activeEmergency;
      try {
        activeEmergency = await api.getActiveEmergency(auth.token);
      } catch (_) {}
      
      if (!mounted) return;
      setState(() {
        _buses = buses;
        _activeEmergency = activeEmergency;
        _errorMsg = null;
      });
      _updateAnimatedPositions(buses);
      _updateBusIcons(buses, activeEmergency);
      if (_trackedBus != null) {
        final updated = buses.firstWhere(
          (b) => b.id == _trackedBus!.id,
          orElse: () => _trackedBus!,
        );
        if (updated.live != null) {
          _drawRoute(updated);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Failed to load live bus data');
    }
  }

  void _updateAnimatedPositions(List<Bus> buses) {
    for (final bus in buses) {
      if (bus.live == null) continue;
      final target = LatLng(bus.live!.lat, bus.live!.lon);
      final current = _animatedPositions[bus.id];

      if (current == null) {
        _animatedPositions[bus.id] = target;
        continue;
      }

      _animControllers[bus.id]?.dispose();
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      );
      _animControllers[bus.id] = ctrl;

      final anim = LatLngTween(begin: current, end: target).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
      );
      _animations[bus.id] = anim;

      anim.addListener(() {
        if (mounted) {
          setState(() => _animatedPositions[bus.id] = anim.value);
        }
      });
      ctrl.forward();
    }
  }

  Future<void> _updateBusIcons(List<Bus> buses, EmergencyAssignmentResponse? activeEmergency) async {
    for (final bus in buses) {
      if (bus.live == null) continue;
      final isOnline = bus.live!.status != 'offline';
      final label = bus.number.contains('-')
          ? bus.number.split('-').last
          : bus.number;
      
      final isBroken = activeEmergency != null && activeEmergency.brokenBusId == bus.id;
      final isBackup = activeEmergency != null &&
          activeEmergency.backupBusNumber != null &&
          bus.number.contains(activeEmergency.backupBusNumber!);
      Color? customColor;
      if (isBroken) {
        customColor = Colors.red;
      } else if (isBackup) {
        customColor = Colors.blue;
      }

      final key = '${bus.id}_${isOnline}_${label}_${customColor?.value}';
      if (!_busIcons.containsKey(key)) {
        final icon = await _getBusMarkerIcon(label, isOnline, customColor: customColor);
        if (mounted) {
          setState(() {
            _busIcons[key] = icon;
          });
        }
      }
    }
  }

  Future<void> _getMyLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) return;
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {}
  }

  Future<void> _drawRoute(Bus bus) async {
    if (bus.live == null) return;
    setState(() {
      _trackedBus = bus;
      _showRoutePanel = true;
    });

    final busPos = LatLng(bus.live!.lat, bus.live!.lon);
    try {
      final dio = Dio();
      final dLon = bus.live!.destinationLon ?? AppConfig.collegeLon;
      final dLat = bus.live!.destinationLat ?? AppConfig.collegeLat;
      final wps =
          '${bus.live!.lon},${bus.live!.lat};${dLon},${dLat}';
      final res = await dio.get(
          'https://router.project-osrm.org/route/v1/driving/$wps?overview=full&geometries=geojson');
      if (res.statusCode == 200) {
        final coords = (res.data['routes'][0]['geometry']['coordinates'] as List)
            .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
            .toList();
        setState(() {
          _completedRoute = [busPos];
          _remainingRoute = coords;
          _remainingDist = res.data['routes'][0]['distance'].toDouble();
          _remainingDuration = res.data['routes'][0]['duration'].toDouble();
        });
      }
    } catch (_) {
      setState(() {
        final dLon = bus.live!.destinationLon ?? AppConfig.collegeLon;
        final dLat = bus.live!.destinationLat ?? AppConfig.collegeLat;
        _remainingRoute = [busPos, LatLng(dLat, dLon)];
      });
    }
  }

  void _clearRoute() {
    setState(() {
      _trackedBus = null;
      _showRoutePanel = false;
      _completedRoute = [];
      _remainingRoute = [];
    });
  }

  String _formatEta(double seconds) {
    if (seconds <= 0) return 'Arrived';
    final mins = (seconds / 60).round();
    if (mins < 60) return '$mins mins';
    return '${mins ~/ 60}h ${mins % 60}m';
  }

  Future<BitmapDescriptor> _getCampusMarkerIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(96, 96);
    
    final paint = Paint()..isAntiAlias = true;
    paint.color = Colors.white;
    canvas.drawCircle(const Offset(48, 48), 48, paint);
    
    paint.color = const Color(0xFF8B5CF6);
    canvas.drawCircle(const Offset(48, 48), 42, paint);
    
    paint.color = Colors.white;
    canvas.drawCircle(const Offset(48, 48), 19, paint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(96, 96);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  Future<BitmapDescriptor> _getBusStopMarkerIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(60, 84);

    final path = Path()
      ..moveTo(30, 82)
      ..cubicTo(27, 78, 2, 50, 2, 30)
      ..arcTo(Rect.fromCircle(center: const Offset(30, 30), radius: 28), 3.14159, 3.14159, false)
      ..cubicTo(58, 50, 33, 78, 30, 82)
      ..close();

    final pinPaint = Paint()
      ..color = const Color(0xFF111827)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, pinPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(path, borderPaint);

    final whiteCirclePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(30, 30), 20, whiteCirclePaint);

    // Front-facing bus icon inside circle
    final busPaint = Paint()..color = const Color(0xFF111827);
    final whitePaint = Paint()..color = Colors.white;

    // Bus body
    final busRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(19, 16, 22, 26),
      const Radius.circular(5),
    );
    canvas.drawRRect(busRect, busPaint);

    // Top sign board
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(24, 18, 12, 2.5), const Radius.circular(1)),
      whitePaint,
    );

    // Windshield
    final windshieldRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(21.5, 22, 17, 10),
      const Radius.circular(2),
    );
    canvas.drawRRect(windshieldRect, whitePaint);

    // Headlights
    canvas.drawRect(const Rect.fromLTWH(21.5, 35, 4.5, 2.5), whitePaint);
    canvas.drawRect(const Rect.fromLTWH(34, 35, 4.5, 2.5), whitePaint);

    // Bumper / Grille
    canvas.drawRect(const Rect.fromLTWH(28, 39, 4, 1.5), whitePaint);

    // Mirrors
    canvas.drawRect(const Rect.fromLTWH(17, 24, 2, 4.5), busPaint);
    canvas.drawRect(const Rect.fromLTWH(41, 24, 2, 4.5), busPaint);

    // Wheels
    canvas.drawRect(const Rect.fromLTWH(21, 41, 3.5, 2.5), busPaint);
    canvas.drawRect(const Rect.fromLTWH(35.5, 41, 3.5, 2.5), busPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(60, 84);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  Future<BitmapDescriptor> _getBusMarkerIcon(String label, bool isOnline, {Color? customColor}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(140, 100);
    final painter = BusMarkerPainter(label: label, isOnline: isOnline, customColor: customColor);
    painter.paint(canvas, size);
    final picture = recorder.endRecording();
    final img = await picture.toImage(140, 100);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // Campus marker
    markers.add(Marker(
      markerId: const MarkerId('campus'),
      position: _campus,
      icon: _campusIcon ?? BitmapDescriptor.defaultMarker,
    ));

    // My location marker
    if (_myLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('my_location'),
        position: _myLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    // Bus markers
    for (final bus in _buses) {
      if (bus.live == null) continue;
      final pos = _animatedPositions[bus.id] ?? LatLng(bus.live!.lat, bus.live!.lon);
      final isOnline = bus.live!.status != 'offline';
      final label = bus.number.contains('-')
          ? bus.number.split('-').last
          : bus.number;

      final isBroken = _activeEmergency != null && _activeEmergency!.brokenBusId == bus.id;
      final isBackup = _activeEmergency != null &&
          _activeEmergency!.backupBusNumber != null &&
          bus.number.contains(_activeEmergency!.backupBusNumber!);
      Color? customColor;
      if (isBroken) {
        customColor = Colors.red;
      } else if (isBackup) {
        customColor = Colors.blue;
      }

      final key = '${bus.id}_${isOnline}_${label}_${customColor?.value}';

      markers.add(Marker(
        markerId: MarkerId(bus.id),
        position: pos,
        icon: _busIcons[key] ?? BitmapDescriptor.defaultMarker,
        rotation: bus.live!.heading.toDouble(),
        infoWindow: InfoWindow(
          title: 'Bus ${bus.number} - ${bus.routeName}',
          snippet: 'Status: ${isOnline ? "Online" : "Offline"} | Speed: ${bus.live!.speed.toStringAsFixed(1)} km/h | Occupancy: ${bus.live!.passengers}/${bus.capacity}',
        ),
        onTap: () => _drawRoute(bus),
      ));
    }

    // Bus stop markers along the route
    final activeBus = _trackedBus ?? (_buses.isNotEmpty ? _buses.first : null);
    if (activeBus != null && activeBus.stops.isNotEmpty) {
      for (int i = 0; i < activeBus.stops.length; i++) {
        final stopName = activeBus.stops[i];
        final coords = AppConfig.stopCoords[stopName];
        if (coords != null) {
          final isCampus = stopName == 'KRCE Campus';
          if (isCampus) continue; // campus marker already added above

          final isDest = i == activeBus.stops.length - 1;
          markers.add(Marker(
            markerId: MarkerId('stop_${activeBus.id}_$i'),
            position: LatLng(coords[0], coords[1]),
            icon: _busStopIcon ?? (isDest
                ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
                : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange)),
            infoWindow: InfoWindow(
              title: isDest ? 'Destination: $stopName' : 'Stop #${i + 1}: $stopName',
              snippet: 'Route: ${activeBus.routeName}',
            ),
          ));
        }
      }
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};

    if (_completedRoute.isNotEmpty) {
      polylines.add(Polyline(
        polylineId: const PolylineId('completed_route'),
        points: _completedRoute,
        color: AppColors.successGreen,
        width: 6,
      ));
    }

    if (_remainingRoute.isNotEmpty) {
      polylines.add(Polyline(
        polylineId: const PolylineId('remaining_route'),
        points: _remainingRoute,
        color: AppColors.indigoPrimary,
        width: 6,
      ));
    }

    return polylines;
  }

  void _updateMapStyle() {
    if (_mapCtrl != null) {
      if (_isDarkMode) {
        _mapCtrl!.setMapStyle(_darkMapStyle);
      } else {
        _mapCtrl!.setMapStyle(null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _campus,
              zoom: 12.5,
            ),
            minMaxZoomPreference: const MinMaxZoomPreference(7.0, null),
            zoomControlsEnabled: false,
            compassEnabled: true,
            myLocationButtonEnabled: false,
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
            onMapCreated: (controller) {
              _mapCtrl = controller;
              _updateMapStyle();
            },
          ),

          // ── Error Banner ─────────────────────────────────
          if (_errorMsg != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_errorMsg!,
                    style: const TextStyle(color: Colors.white)),
              ),
            ),

          // ── FAB Controls ─────────────────────────────────
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 60,
            child: Column(
              children: [
                _mapFab(
                    icon: Icons.layers,
                    onTap: () {
                      setState(() => _isDarkMode = !_isDarkMode);
                      _updateMapStyle();
                    }),
                const SizedBox(height: 10),
                _mapFab(
                    icon: Icons.my_location,
                    onTap: () {
                      _getMyLocation();
                      if (_myLocation != null && _mapCtrl != null) {
                        _mapCtrl!.animateCamera(
                          CameraUpdate.newLatLngZoom(_myLocation!, 16),
                        );
                      }
                    }),
                const SizedBox(height: 10),
                _mapFab(
                    icon: _isFullscreen
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen,
                    onTap: () =>
                        setState(() => _isFullscreen = !_isFullscreen)),
              ],
            ),
          ),

          // ── Route Info Panel ─────────────────────────────
          if (_showRoutePanel && _trackedBus != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: _RouteInfoPanel(
                bus: _trackedBus!,
                remainingDist: _remainingDist,
                remainingDuration: _remainingDuration,
                onClose: _clearRoute,
                formatEta: _formatEta,
              ),
            ),

          // ── Bus List bottom card (scrollable) ──────────────
          if (!_showRoutePanel)
            DraggableScrollableSheet(
              initialChildSize: 0.25,
              minChildSize: 0.10,
              maxChildSize: 0.6,
              snap: true,
              snapSizes: const [0.10, 0.25, 0.6],
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceColor,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 16)
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 0),
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 10),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.mutedText.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        'Campus Bus Fleet  •  Total Active: ${_buses.where((b) => b.live?.status != "offline" && b.live != null).length}',
                        style: const TextStyle(
                            color: AppColors.textColor,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._buses.map((b) => _BusListItem(
                            bus: b,
                            onTap: () {
                              if (b.live != null && _mapCtrl != null) {
                                _mapCtrl!.animateCamera(
                                  CameraUpdate.newLatLngZoom(
                                    LatLng(b.live!.lat, b.live!.lon),
                                    14,
                                  ),
                                );
                                _drawRoute(b);
                              }
                            },
                          )),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _mapFab({required IconData icon, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)
            ],
          ),
          child: Icon(icon, color: AppColors.indigoPrimary),
        ),
      );
}

// ── LatLng Tween ──────────────────────────────────────────
class LatLngTween extends Tween<LatLng> {
  LatLngTween({required LatLng begin, required LatLng end})
      : super(begin: begin, end: end);

  @override
  LatLng lerp(double t) {
    return LatLng(
      begin!.latitude + (end!.latitude - begin!.latitude) * t,
      begin!.longitude + (end!.longitude - begin!.longitude) * t,
    );
  }
}

// ── Route Info Panel ──────────────────────────────────────
class _RouteInfoPanel extends StatelessWidget {
  final Bus bus;
  final double remainingDist;
  final double remainingDuration;
  final VoidCallback onClose;
  final String Function(double) formatEta;

  const _RouteInfoPanel({
    required this.bus,
    required this.remainingDist,
    required this.remainingDuration,
    required this.onClose,
    required this.formatEta,
  });

  @override
  Widget build(BuildContext context) {
    final totalDist = 15000.0;
    final coveredDist = (totalDist - remainingDist).clamp(0, totalDist);
    final progress = (coveredDist / totalDist).clamp(0.0, 1.0);
    final live = bus.live;
    final remaining = live?.remainingStops ?? [];
    final nextStop = remaining.isNotEmpty ? remaining[0] : null;
    final destStop = live?.destinationStop;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor, width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(children: [
                  const Icon(Icons.route, color: AppColors.indigoPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${bus.number} — ${bus.routeName}',
                      style: const TextStyle(
                          color: AppColors.textColor, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.mutedText),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Live stats chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _infoChip('Driver', bus.live?.driverName ?? '--'),
                const SizedBox(width: 18),
                _infoChip('Speed', '${bus.live?.speed.toInt() ?? 0} km/h'),
                const SizedBox(width: 18),
                _infoChip('ETA',
                    formatEta(remainingDuration),
                    color: AppColors.successGreen),
                const SizedBox(width: 18),
                _infoChip('Passengers', '${bus.live?.passengers ?? 0}/${bus.capacity}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Stop info row
          Row(
            children: [
              Expanded(
                child: _stopChip(
                  label: 'Next Stop',
                  value: nextStop ?? '—',
                  color: const Color(0xFFFBBF24),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _stopChip(
                  label: 'Destination',
                  value: destStop ?? '—',
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          // Upcoming stops compact list (up to 4)
          if (remaining.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Upcoming Stops',
                style: TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 6),
            ...remaining.take(4).map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: s == destStop
                            ? const Color(0xFFEF4444)
                            : s == nextStop
                                ? const Color(0xFFFBBF24)
                                : AppColors.borderColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s,
                          style: const TextStyle(
                              color: AppColors.textColor, fontSize: 12)),
                    ),
                  ]),
                )),
            if (remaining.length > 4)
              Text('+ ${remaining.length - 4} more stops',
                  style: const TextStyle(
                      color: AppColors.mutedText, fontSize: 11)),
          ],
          const SizedBox(height: 10),
          // Progress bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(progress * 100).toInt()}% completed',
                  style: const TextStyle(
                      color: AppColors.successGreen, fontSize: 12)),
              Text('${(remainingDist / 1000).toStringAsFixed(1)} km remaining',
                  style: const TextStyle(
                      color: AppColors.indigoPrimary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.borderColor,
              valueColor: const AlwaysStoppedAnimation(AppColors.successGreen),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value, {Color? color}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.mutedText, fontSize: 11)),
          Text(value,
              style: TextStyle(
                  color: color ?? AppColors.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      );

  Widget _stopChip({required String label, required String value, required Color color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: color.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
            overflow: TextOverflow.ellipsis, maxLines: 1),
      ],
    ),
  );
}

// ── Bus List Item ─────────────────────────────────────────
class _BusListItem extends StatelessWidget {
  final Bus bus;
  final VoidCallback onTap;

  const _BusListItem({required this.bus, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOnline = bus.live?.status != 'offline' && bus.live != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isOnline
                    ? AppColors.successGreen
                    : AppColors.mutedText,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${bus.number} — ${bus.routeName}',
                    style: const TextStyle(
                        color: AppColors.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  Text(
                    '${bus.live?.speed.toInt() ?? 0} km/h  •  ${bus.live?.passengers ?? 0} passengers',
                    style: const TextStyle(
                        color: AppColors.mutedText, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.mutedText),
          ],
        ),
      ),
    );
  }
}
