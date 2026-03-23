import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/socket_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  final SocketService _socket = SocketService();
  final Completer<GoogleMapController> _mapController = Completer();

  List   _buses         = [];
  Map?   _selectedBus;
  bool   _isTracking    = false;
  bool   _loading       = true;
  double _speed         = 0;
  int    _duration      = 0; // seconds since tracking started
  LatLng _currentPos    = const LatLng(24.8607, 67.0011);
  StreamSubscription<Position>? _posStream;
  Timer?  _durationTimer;
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _socket.connect();
    _loadBuses();
  }

  Future<void> _loadBuses() async {
    try {
      final data = await ApiService.getBuses();
      setState(() { _buses = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<bool> _checkPermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission denied. Enable in Settings.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable Location Services on your device.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _startTracking() async {
    if (_selectedBus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a bus first'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final hasPermission = await _checkPermission();
    if (!hasPermission) return;

    setState(() => _isTracking = true);

    // Start duration timer
    _duration = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _duration++);
    });

    // Listen to GPS position stream
    _posStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // update every 5 metres
      ),
    ).listen((Position pos) async {
      final newPos = LatLng(pos.latitude, pos.longitude);
      final busId  = _selectedBus!['_id'] as String? ??
          _selectedBus!['busNumber'] as String? ??
          'BUS001';

      // Emit to server → all parents watching this bus get updated
      _socket.emitLocation(
        busId:     busId,
        latitude:  pos.latitude,
        longitude: pos.longitude,
        speed:     pos.speed * 3.6, // m/s → km/h
      );

      // Animate map camera
      final ctrl = await _mapController.future;
      ctrl.animateCamera(CameraUpdate.newLatLng(newPos));

      setState(() {
        _currentPos = newPos;
        _speed = pos.speed * 3.6;

        // Update bus marker
        _markers.removeWhere((m) => m.markerId.value == 'driver');
        _markers.add(Marker(
          markerId: const MarkerId('driver'),
          position: newPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: _selectedBus!['busNumber'] ?? 'My Bus',
            snippet: '${_speed.toStringAsFixed(0)} km/h',
          ),
          zIndex: 2,
        ));
      });
    });
  }

  void _stopTracking() {
    _posStream?.cancel();
    _posStream = null;
    _durationTimer?.cancel();
    _durationTimer = null;
    setState(() {
      _isTracking = false;
      _speed      = 0;
    });
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  void _buildRouteOverlay() {
    if (_selectedBus == null) return;
    final route = _selectedBus!['routeId'] as Map? ?? {};
    final stops = (route['stops'] as List?) ?? [];
    final Set<Marker> markers = {};
    final List<LatLng> points = [];

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i] as Map;
      final lat  = (stop['latitude']  as num?)?.toDouble() ?? 24.8607;
      final lng  = (stop['longitude'] as num?)?.toDouble() ?? 67.0011;
      final pos  = LatLng(lat, lng);
      points.add(pos);
      markers.add(Marker(
        markerId: MarkerId('stop_$i'),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(title: stop['name'] ?? 'Stop ${i + 1}'),
      ));
    }

    setState(() {
      _markers = markers;
      if (points.length >= 2) {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points:  points,
            color:   const Color(0xFF4A9EFF),
            width:   4,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        };
      }
    });
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Stack(
        children: [
          // ── Google Map ─────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPos,
              zoom:   15,
            ),
            onMapCreated: (ctrl) => _mapController.complete(ctrl),
            markers:   _markers,
            polylines: _polylines,
            myLocationEnabled:       true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled:     false,
            mapType: MapType.normal,
          ),

          // ── Top bar ────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F1A).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF2A3A5C)),
                      ),
                      child: Row(
                        children: [
                          const Text('🚌', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          const Text('Driver Mode',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                          const Spacer(),
                          if (_isTracking)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2ECC71).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFF2ECC71)
                                        .withOpacity(0.4)),
                              ),
                              child: Row(
                                children: [
                                  _PulseDot(color: const Color(0xFF2ECC71)),
                                  const SizedBox(width: 5),
                                  const Text('BROADCASTING',
                                      style: TextStyle(
                                          color: Color(0xFF2ECC71),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () async {
                      _stopTracking();
                      await auth.logout();
                      if (mounted) {
                        Navigator.pushReplacement(context,
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()));
                      }
                    },
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F1A).withOpacity(0.9),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF2A3A5C)),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: Color(0xFF8892A4), size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom panel ───────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1A).withOpacity(0.97),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: const Border(
                    top: BorderSide(color: Color(0xFF2A3A5C))),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A3A5C),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bus selector (only when not tracking)
                  if (!_isTracking) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('SELECT YOUR BUS',
                          style: TextStyle(
                              color: Color(0xFF8892A4),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1)),
                    ),
                    const SizedBox(height: 10),
                    _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFFFF6B35)))
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16213E),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF2A3A5C)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<Map>(
                                value: _selectedBus,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF16213E),
                                hint: const Text('Choose your bus',
                                    style: TextStyle(
                                        color: Color(0xFF4A5568))),
                                items: _buses.map((b) {
                                  final route = b['routeId'] as Map? ?? {};
                                  return DropdownMenuItem<Map>(
                                    value: b as Map,
                                    child: Text(
                                      '${b['busNumber']} — ${route['routeName'] ?? 'No route'}',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() => _selectedBus = val);
                                  _buildRouteOverlay();
                                },
                              ),
                            ),
                          ),
                    const SizedBox(height: 16),
                  ],

                  // Live stats (only when tracking)
                  if (_isTracking) ...[
                    Row(
                      children: [
                        _StatBox(
                          label: 'Speed',
                          value: '${_speed.toStringAsFixed(0)} km/h',
                          color: const Color(0xFFFF6B35),
                          icon: Icons.speed_rounded,
                        ),
                        const SizedBox(width: 10),
                        _StatBox(
                          label: 'Duration',
                          value: _formatDuration(_duration),
                          color: const Color(0xFF4A9EFF),
                          icon: Icons.timer_rounded,
                        ),
                        const SizedBox(width: 10),
                        _StatBox(
                          label: 'Bus',
                          value: _selectedBus?['busNumber'] ?? 'N/A',
                          color: const Color(0xFF2ECC71),
                          icon: Icons.directions_bus_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Start / Stop button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isTracking ? _stopTracking : _startTracking,
                      icon: Icon(
                        _isTracking
                            ? Icons.stop_circle_rounded
                            : Icons.play_circle_rounded,
                        size: 24,
                      ),
                      label: Text(
                        _isTracking ? 'Stop Broadcasting' : 'Start Route & Broadcast GPS',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTracking
                            ? const Color(0xFFE74C3C)
                            : const Color(0xFF2ECC71),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),

                  if (_isTracking) ...[
                    const SizedBox(height: 10),
                    const Text(
                      '📡 Your location is being shared with all parents on this route',
                      style: TextStyle(
                          color: Color(0xFF8892A4),
                          fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(
          width: 7, height: 7,
          decoration:
              BoxDecoration(shape: BoxShape.circle, color: widget.color),
        ),
      );
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;

  const _StatBox(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF8892A4), fontSize: 9)),
          ],
        ),
      ),
    );
  }
}
