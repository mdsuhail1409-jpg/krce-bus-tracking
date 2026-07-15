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
    final h = size.height;
    final paint = Paint()..isAntiAlias = true;
    final bodyColor = customColor ??
        (isOnline ? const Color(0xFF10B981) : const Color(0xFF64748B));

    // Shadow
    paint.color = Colors.black.withOpacity(0.3);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(4, 6, w - 8, h - 8), const Radius.circular(14)),
        paint);

    // White outline body
    paint.color = Colors.white;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(2, 2, w - 4, h - 14), const Radius.circular(12)),
        paint);

    // Colored body
    paint.color = bodyColor;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(6, 6, w - 12, h - 18), const Radius.circular(10)),
        paint);

    // Triangle pointer
    final triPath = ui.Path()
      ..moveTo(w / 2 - 10, h - 14)
      ..lineTo(w / 2 + 10, h - 14)
      ..lineTo(w / 2, h)
      ..close();
    paint.color = bodyColor;
    canvas.drawPath(triPath, paint);

    // Windows
    paint.color = Colors.white.withOpacity(0.8);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(10, 10, 24, 22), const Radius.circular(4)),
        paint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w / 2 - 12, 10, 24, 22), const Radius.circular(4)),
        paint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w - 34, 10, 24, 22), const Radius.circular(4)),
        paint);

    // Label
    final tp = TextPainter(
      text: TextSpan(
          text: label,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, h - 16 - tp.height / 2 - 4));
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
    });
  }

  /// Handle incoming WebSocket messages — update bus position instantly
  void _handleWsMessage(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    if (type == 'gps_update' || type == 'bus_update') {
      final busId = data['bus_id'] as String? ?? '';
      if (busId.isEmpty || !mounted) return;
      final updatedBus = _buses.indexWhere((b) => b.id == busId);
      if (updatedBus == -1) return;
      // Refresh the full bus list on any GPS update
      _fetchBuses();
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
    if (mounted) {
      setState(() {
        _campusIcon = campusIcon;
      });
    }
  }

  void _startPolling() {
    _fetchBuses();
    _pollTimer = Timer.periodic(AppConfig.busPollInterval, (_) => _fetchBuses());
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
      final wps =
          '${bus.live!.lon},${bus.live!.lat};${AppConfig.collegeLon},${AppConfig.collegeLat}';
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
        _remainingRoute = [busPos, _campus];
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
        onTap: () => _drawRoute(bus),
      ));
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

          // ── Bus List bottom card ──────────────────────────
          if (!_showRoutePanel)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceColor,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.4), blurRadius: 12)
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Campus Bus Fleet  •  Total Active: ${_buses.where((b) => b.live?.status != "offline" && b.live != null).length}',
                      style: const TextStyle(
                          color: AppColors.textColor,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._buses.take(3).map((b) => _BusListItem(
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
                  ],
                ),
              ),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xE61E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 16)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.route, color: AppColors.indigoPrimary),
                const SizedBox(width: 8),
                Text(
                  '${bus.number} — ${bus.routeName}',
                  style: const TextStyle(
                      color: AppColors.textColor, fontWeight: FontWeight.bold),
                ),
              ]),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.mutedText),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _infoChip('Driver', bus.live?.driverName ?? '--'),
              _infoChip('Speed', '${bus.live?.speed.toInt() ?? 0} km/h'),
              _infoChip('ETA',
                  formatEta(remainingDuration),
                  color: AppColors.successGreen),
              _infoChip('Passengers', '${bus.live?.passengers ?? 0}'),
            ],
          ),
          const SizedBox(height: 10),
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
