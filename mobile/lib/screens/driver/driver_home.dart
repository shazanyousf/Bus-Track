// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../services/socket_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../account_screen.dart';
import '../login_screen.dart';
import '../shared/notices_screen.dart';

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  final SocketService _socket = SocketService();
  final MapController _mapController = MapController();
  int _currentIndex = 0;

  List _buses = [];
  Map? _selectedBus;
  bool _isTracking = false;
  String? _tripId;
  bool _loading = true;
  bool _sendingAlert = false;
  double _speed = 0;
  int _duration = 0; // seconds since tracking started
  LatLng _currentPos = const LatLng(24.8607, 67.0011);
  StreamSubscription<Position>? _posStream;
  Timer? _durationTimer;
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];

  final TextEditingController _alertController = TextEditingController();
  String _alertType = 'traffic';

  @override
  void initState() {
    super.initState();
    _socket.connect(token: context.read<AuthService>().token);
    _socket.listenToProfileUpdates((_) {
      if (mounted) _loadBuses();
    });
    _loadBuses();
  }

  Future<void> _loadBuses() async {
    try {
      final data = await ApiService.getBuses();
      setState(() {
        _buses = data;
        _loading = false;
      });
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
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission denied. Enable in Settings.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable Location Services on your device.'),
          backgroundColor: Colors.orange,
        ),
      );
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

    final busId = _selectedBus!['_id']?.toString();
    if (busId == null || busId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Selected bus has no valid database ID'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }
    final connected = await _socket.waitForConnection();
    if (!connected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tracking server is not connected'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    setState(() => _isTracking = true);
    _tripId = 'trip-${busId}-${DateTime.now().millisecondsSinceEpoch}';
    _socket.emitTripStarted(busId: busId, tripId: _tripId!);

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
        final currentTripId = _tripId;
        if (currentTripId == null) return;

      // Emit to server → all parents watching this bus get updated
      _socket.emitLocation(
        busId: busId,
        tripId: currentTripId,
        latitude: pos.latitude,
        longitude: pos.longitude,
        speed: pos.speed * 3.6, // m/s → km/h
      );

      _mapController.move(newPos, 15);

      setState(() {
        _currentPos = newPos;
        _speed = pos.speed * 3.6;

        // Update bus marker
        _markers.removeWhere((m) => m.key == const ValueKey('driver'));
        _markers.add(Marker(
          key: const ValueKey('driver'),
          point: newPos,
          width: 40,
          height: 40,
          builder: (ctx) => const Icon(
            Icons.directions_bus_rounded,
            color: Colors.orange,
            size: 32,
          ),
        ));
      });
    });
  }

  void _stopTracking() {
    final busId = _selectedBus?['_id'] as String? ?? _selectedBus?['busNumber'] as String?;
    final tripId = _tripId;
    if (busId != null && tripId != null) {
      _socket.emitTripCompleted(busId: busId, tripId: tripId);
    }
    _socket.stopListeningToProfileUpdates();
    _posStream?.cancel();
    _posStream = null;
    _durationTimer?.cancel();
    _durationTimer = null;
    setState(() {
      _isTracking = false;
      _speed = 0;
      _tripId = null;
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
    final List<Marker> markers = [];
    final List<LatLng> points = [];

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i] as Map;
      final lat = (stop['latitude'] as num?)?.toDouble() ?? 24.8607;
      final lng = (stop['longitude'] as num?)?.toDouble() ?? 67.0011;
      final pos = LatLng(lat, lng);
      points.add(pos);
      markers.add(Marker(
        key: ValueKey('stop_$i'),
        point: pos,
        width: 40,
        height: 40,
        builder: (ctx) => const Icon(
          Icons.location_on,
          color: Colors.blue,
          size: 28,
        ),
      ));
    }

    setState(() {
      _markers = markers;
      if (points.length >= 2) {
        _polylines = [
          Polyline(
            points: points,
            color: const Color(0xFF4A9EFF),
            strokeWidth: 4,
          ),
        ];
      } else {
        _polylines = [];
      }
    });
  }

  Future<void> _sendAlert() async {
    if (_selectedBus == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a bus first before sending alert'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    if (_alertController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter an alert message'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final busId = _selectedBus!['_id'] as String? ??
        _selectedBus!['busNumber'] as String? ??
        'BUS001';

    setState(() => _sendingAlert = true);

    try {
      _socket.emitAlert(
        busId: busId,
        type: _alertType,
        message: _alertController.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Alert sent to parents'),
        backgroundColor: Colors.green,
      ));
      _alertController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to send alert: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() => _sendingAlert = false);
    }
  }

  @override
  void dispose() {
    _stopTracking();
    _alertController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // New simplified full-bleed map UI. Controls moved into a translucent
    // draggable bottom sheet for clarity and reliability.
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: _currentIndex == 0
          ? Stack(
        children: [
          // Map as the base layer
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: _currentPos,
                zoom: 15,
                minZoom: 3,
                maxZoom: 18,
                interactiveFlags: InteractiveFlag.all,
              ),
              children: [
                // Visible debug background to confirm map area
                TileLayer(
                  urlTemplate: 'https://a.tile.openstreetmap.de/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.bustrack',
                  tileProvider: NetworkTileProvider(
                    headers: {'User-Agent': 'com.example.bustrack'},
                  ),
                ),
                if (_polylines.isNotEmpty) PolylineLayer(polylines: _polylines),
                MarkerLayer(markers: _markers),
              ],
            ),
          ),

          // Top controls (compact) — keep access to logout/quick actions
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  _TopCircleButton(
                    icon: Icons.menu_rounded,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
                    },
                  ),
                  const Spacer(),
                  if (_isTracking)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFF2ECC71).withOpacity(0.32)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PulseDot(color: Color(0xFF2ECC71)),
                          SizedBox(width: 8),
                          Text('BROADCASTING', style: TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.w800, fontSize: 11)),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Logout button for compact top bar
                  _TopCircleButton(
                    icon: Icons.logout_rounded,
                    onTap: () async {
                      final navigator = Navigator.of(context);
                      _stopTracking();
                      await context.read<AuthService>().logout();
                      if (!mounted) return;
                      navigator.pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Bottom sheet with controls
          DraggableScrollableSheet(
            initialChildSize: 0.36,
            minChildSize: 0.18,
            maxChildSize: 0.68,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  const _PanelHandle(),
                  const SizedBox(height: 12),
                  const _PanelHeading(
                    title: 'Driver Dashboard',
                    subtitle: 'Choose a bus, then start route sharing',
                  ),
                  const SizedBox(height: 12),
                  _loading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<Map>(
                            value: _selectedBus,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF111B2D),
                            hint: const Text('Choose your bus', style: TextStyle(color: Color(0xFF7B8BA3))),
                            items: _buses.map((b) {
                              final route = b['routeId'] as Map? ?? {};
                              return DropdownMenuItem<Map>(
                                value: b as Map,
                                child: Text('${b['busNumber']} — ${route['routeName'] ?? 'No route'}', style: const TextStyle(color: Colors.white)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _selectedBus = val);
                              _buildRouteOverlay();
                            },
                          ),
                        ),
                  const SizedBox(height: 12),
                  if (_selectedBus != null) _TripSummaryCard(selectedBus: _selectedBus!),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isTracking ? _stopTracking : _startTracking,
                        icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                        label: Text(_isTracking ? 'Stop Broadcasting' : 'Start & Broadcast'),
                        style: ElevatedButton.styleFrom(backgroundColor: _isTracking ? const Color(0xFFE74C3C) : const Color(0xFF2ECC71)),
                      ),
                    ),
                  ]),
                  if (_isTracking) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF111B2D), Color(0xFF16213E)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF20304A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Send update to parents',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _alertType,
                                  dropdownColor: const Color(0xFF16213E),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFF0B1220),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'traffic',
                                        child: Text('Traffic jam')),
                                    DropdownMenuItem(
                                        value: 'accident',
                                        child: Text('Accident')),
                                    DropdownMenuItem(
                                        value: 'delay', child: Text('Delay')),
                                    DropdownMenuItem(
                                        value: 'other', child: Text('Other')),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _alertType = value);
                                    }
                                  },
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _sendingAlert
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : GestureDetector(
                                      onTap: _sendAlert,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 11),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2ECC71),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'Send',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _alertController,
                            maxLines: 2,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText:
                                  'Enter issue e.g. traffic jam near exit',
                              hintStyle:
                                  const TextStyle(color: Color(0xFF8892A4)),
                              filled: true,
                              fillColor: const Color(0xFF0B1220),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    _StatBox(label: 'Speed', value: '${_speed.toStringAsFixed(0)} km/h', color: const Color(0xFFFF6B35), icon: Icons.speed_rounded),
                    const SizedBox(width: 8),
                    _StatBox(label: 'Duration', value: _formatDuration(_duration), color: const Color(0xFF4A9EFF), icon: Icons.timer_rounded),
                    const SizedBox(width: 8),
                    _StatBox(label: 'Bus', value: _selectedBus?['busNumber'] ?? 'N/A', color: const Color(0xFF2ECC71), icon: Icons.directions_bus_rounded),
                  ]),
                ],
              ),
            ),
          ),
        ],
      )
          : const NoticesScreen(),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF16213E),
          border: Border(top: BorderSide(color: Color(0xFF2A3A5C))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            if (i == _currentIndex) return;
            setState(() => _currentIndex = i);
          },
          backgroundColor: Colors.transparent,
          selectedItemColor: const Color(0xFFFF6B35),
          unselectedItemColor: const Color(0xFF8892A4),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.campaign_rounded),
              label: 'Notices',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(AuthService auth) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0F0F1A).withValues(alpha: 0.08),
                  const Color(0xFF0F0F1A).withValues(alpha: 0.4),
                ],
              ),
            ),
          ),
        ),

        Positioned.fill(
          child: Container(color: const Color(0xFF0B1220)),
        ),

        // ── Map ─────────────────────────────────────────────
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _currentPos,
              zoom: 15,
              minZoom: 3,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://a.tile.openstreetmap.de/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.bustrack',
                tileProvider: NetworkTileProvider(
                  headers: {'User-Agent': 'com.example.bustrack'},
                ),
              ),
              if (_polylines.isNotEmpty) PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: _markers),
            ],
          ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A9EFF).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: const Color(0xFF4A9EFF)
                                .withValues(alpha: 0.32)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.navigation_rounded,
                              color: Color(0xFF8EC5FF), size: 14),
                          SizedBox(width: 6),
                          Text(
                            'Driver Command',
                            style: TextStyle(
                              color: Color(0xFF8EC5FF),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (_loading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF101A2C), Color(0xFF0E1625)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF20304A)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFFF6B35).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.directions_bus_rounded,
                            color: Color(0xFFFFA15F), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Driver Dashboard',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _isTracking
                                  ? 'Broadcasting live GPS to parents'
                                  : 'Choose a bus, then start route sharing',
                              style: const TextStyle(
                                color: Color(0xFF9AA7BE),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isTracking)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF2ECC71).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFF2ECC71)
                                  .withValues(alpha: 0.32),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PulseDot(color: Color(0xFF2ECC71)),
                              SizedBox(width: 6),
                              Text(
                                'BROADCASTING',
                                style: TextStyle(
                                  color: Color(0xFF2ECC71),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 10),
                      _TopCircleButton(
                        icon: Icons.campaign_rounded,
                        onTap: () => setState(() => _currentIndex = 1),
                      ),
                      const SizedBox(width: 10),
                      _TopCircleButton(
                        icon: Icons.logout_rounded,
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          _stopTracking();
                          await auth.logout();
                          if (!mounted) return;
                          navigator.pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF11182D), Color(0xFF0F0F1A)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Color(0xFF2A3A5C))),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFF3A4D73),
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),

                if (!_isTracking) ...[
                  const _PanelHeading(
                    title: 'Trip Setup',
                    subtitle:
                        'Select your bus before broadcasting route updates',
                  ),
                  const SizedBox(height: 12),
                  _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFFF6B35)))
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF111B2D), Color(0xFF0E1625)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF20304A)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Map>(
                              value: _selectedBus,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF111B2D),
                              hint: const Text('Choose your bus',
                                  style: TextStyle(color: Color(0xFF7B8BA3))),
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
                  const SizedBox(height: 14),
                  if (_selectedBus != null)
                    _TripSummaryCard(selectedBus: _selectedBus!),
                  const SizedBox(height: 16),
                ],

                if (_isTracking) ...[
                  const _PanelHeading(
                    title: 'Live Snapshot',
                    subtitle: 'Real-time speed, duration and active bus status',
                  ),
                  const SizedBox(height: 12),
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF111B2D), Color(0xFF16213E)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF20304A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Send update to parents',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _alertType,
                                dropdownColor: const Color(0xFF16213E),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF0B1220),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'traffic',
                                      child: Text('Traffic jam')),
                                  DropdownMenuItem(
                                      value: 'accident',
                                      child: Text('Accident')),
                                  DropdownMenuItem(
                                      value: 'delay', child: Text('Delay')),
                                  DropdownMenuItem(
                                      value: 'other', child: Text('Other')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _alertType = value);
                                  }
                                },
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _sendingAlert
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : GestureDetector(
                                    onTap: _sendAlert,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 11),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2ECC71),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text('Send',
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _alertController,
                          maxLines: 2,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Enter issue e.g. traffic jam near exit',
                            hintStyle:
                                const TextStyle(color: Color(0xFF8892A4)),
                            filled: true,
                            fillColor: const Color(0xFF0B1220),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Start / Stop button
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton.icon(
                    onPressed: _isTracking ? _stopTracking : _startTracking,
                    icon: Icon(
                      _isTracking
                          ? Icons.stop_circle_rounded
                          : Icons.play_circle_rounded,
                      size: 24,
                    ),
                    label: Text(
                      _isTracking
                          ? 'Stop Broadcasting'
                          : 'Start Route & Broadcast GPS',
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
                    'Your live location is visible to parents on this route.',
                    style: TextStyle(color: Color(0xFF9AA7BE), fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
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
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(
          width: 7,
          height: 7,
          decoration:
              BoxDecoration(shape: BoxShape.circle, color: widget.color),
        ),
      );
}

class _PanelHandle extends StatelessWidget {
  const _PanelHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFF26354D),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class _PanelHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PanelHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF9AA7BE),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _TripSummaryCard extends StatelessWidget {
  final Map selectedBus;

  const _TripSummaryCard({required this.selectedBus});

  @override
  Widget build(BuildContext context) {
    final route = selectedBus['routeId'] as Map? ?? {};
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF101A2C), Color(0xFF0E1625)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF20304A)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.directions_bus_rounded,
                color: Color(0xFFFFA15F), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedBus['busNumber'] ?? 'Bus',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  route['routeName'] ?? 'Route not assigned',
                  style: const TextStyle(
                    color: Color(0xFF9AA7BE),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4A9EFF).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: const Color(0xFF4A9EFF).withValues(alpha: 0.28)),
            ),
            child: Text(
              '${selectedBus['availableSeats'] ?? 0} seats',
              style: const TextStyle(
                color: Color(0xFF8EC5FF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF132742)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF2A3A5C)),
          ),
          child: Icon(icon, color: const Color(0xFF9AA7BE), size: 18),
        ),
      ),
    );
  }
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF16213E),
              color.withValues(alpha: 0.18),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Color(0xFF8892A4), fontSize: 9)),
          ],
        ),
      ),
    );
  }
}
