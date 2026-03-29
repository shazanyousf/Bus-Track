import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/socket_service.dart';

class LiveTrackingScreen extends StatefulWidget {
  final Map bus;

  const LiveTrackingScreen({super.key, required this.bus});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final SocketService _socket = SocketService();

  LatLng _busPosition = const LatLng(24.8607, 67.0011); // default Karachi
  double _speed       = 0;
  String _lastUpdate  = 'Waiting for signal...';
  bool   _connected   = false;

  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};

  // Build route stop markers from bus data
  List<LatLng> get _stopPositions {
    final route = widget.bus['routeId'] as Map? ?? {};
    final stops = (route['stops'] as List?) ?? [];
    return stops.map<LatLng>((s) {
      return LatLng(
        (s['latitude']  as num?)?.toDouble() ?? 24.8607,
        (s['longitude'] as num?)?.toDouble() ?? 67.0011,
      );
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _socket.connect();
    _buildInitialMarkers();
    _startListening();
  }

  void _buildInitialMarkers() {
    final route = widget.bus['routeId'] as Map? ?? {};
    final stops = (route['stops'] as List?) ?? [];
    final Set<Marker> markers = {};

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i] as Map;
      final lat  = (stop['latitude']  as num?)?.toDouble() ?? 24.8607;
      final lng  = (stop['longitude'] as num?)?.toDouble() ?? 67.0011;
      markers.add(
        Marker(
          markerId: MarkerId('stop_$i'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: stop['name'] ?? 'Stop ${i + 1}',
            snippet: i == 0 ? 'Start' : i == stops.length - 1 ? 'End' : 'Stop',
          ),
        ),
      );
    }

    // Route polyline
    if (_stopPositions.length >= 2) {
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points:  _stopPositions,
        color:   const Color(0xFF4A9EFF),
        width:   4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ));
    }

    setState(() => _markers = markers);
  }

  void _startListening() {
    final busId = widget.bus['_id'] as String? ??
        widget.bus['busNumber'] as String? ??
        'BUS001';

    _socket.listenToBus(busId, (data) async {
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      final speed = (data['speed']     as num?)?.toDouble() ?? 0;

      if (lat == null || lng == null) return;

      final newPos = LatLng(lat, lng);

      // Animate camera to follow bus
      final ctrl = await _mapController.future;
      ctrl.animateCamera(CameraUpdate.newLatLng(newPos));

      setState(() {
        _busPosition = newPos;
        _speed       = speed;
        _connected   = true;
        _lastUpdate  = _formatTime(data['timestamp'] as String?);

        // Update bus marker
        _markers.removeWhere((m) => m.markerId.value == 'bus');
        _markers.add(
          Marker(
            markerId: const MarkerId('bus'),
            position: newPos,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(
              title: widget.bus['busNumber'] ?? 'Bus',
              snippet: '${speed.toStringAsFixed(0)} km/h',
            ),
            zIndex: 2,
          ),
        );
      });
    });

    _socket.requestBusLocation(busId);
  }

  String _formatTime(String? iso) {
    if (iso == null) return 'Just now';
    try {
      final dt  = DateTime.parse(iso).toLocal();
      final h   = dt.hour.toString().padLeft(2, '0');
      final m   = dt.minute.toString().padLeft(2, '0');
      final s   = dt.second.toString().padLeft(2, '0');
      return '$h:$m:$s';
    } catch (_) {
      return 'Just now';
    }
  }

  @override
  void dispose() {
    final busId = widget.bus['_id'] as String? ?? 'BUS001';
    _socket.stopListening(busId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.bus['driverId'] as Map? ?? {};
    final route  = widget.bus['routeId']  as Map? ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Stack(
        children: [
          // ── Google Map ──────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _busPosition,
              zoom:   15,
            ),
            onMapCreated: (ctrl) => _mapController.complete(ctrl),
            markers:   _markers,
            polylines: _polylines,
            myLocationButtonEnabled: false,
            zoomControlsEnabled:     false,
            mapToolbarEnabled:       false,
            mapType: MapType.normal,
          ),

          // ── Top bar ─────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F1A).withOpacity(0.85),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF2A3A5C)),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                          const Text('🚌',
                              style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.bus['busNumber'] ?? 'Bus',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14),
                                ),
                                Text(
                                  route['routeName'] ?? 'Route',
                                  style: const TextStyle(
                                      color: Color(0xFF8892A4),
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          // Live indicator
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _connected
                                  ? const Color(0xFF2ECC71).withOpacity(0.15)
                                  : const Color(0xFFF7C948).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _connected
                                    ? const Color(0xFF2ECC71).withOpacity(0.5)
                                    : const Color(0xFFF7C948).withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _PulseDot(
                                    color: _connected
                                        ? const Color(0xFF2ECC71)
                                        : const Color(0xFFF7C948)),
                                const SizedBox(width: 5),
                                Text(
                                  _connected ? 'LIVE' : 'WAITING',
                                  style: TextStyle(
                                    color: _connected
                                        ? const Color(0xFF2ECC71)
                                        : const Color(0xFFF7C948),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom info panel ───────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1A).withOpacity(0.96),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: const Border(
                    top: BorderSide(color: Color(0xFF2A3A5C))),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A3A5C),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stats row
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.speed_rounded,
                        label: 'Speed',
                        value: '${_speed.toStringAsFixed(0)} km/h',
                        color: const Color(0xFFFF6B35),
                      ),
                      const SizedBox(width: 10),
                      _InfoChip(
                        icon: Icons.access_time_rounded,
                        label: 'Updated',
                        value: _lastUpdate,
                        color: const Color(0xFF4A9EFF),
                      ),
                      const SizedBox(width: 10),
                      _InfoChip(
                        icon: Icons.airline_seat_recline_normal_rounded,
                        label: 'Seats',
                        value: '${widget.bus['availableSeats'] ?? 0} left',
                        color: const Color(0xFF2ECC71),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Driver row
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16213E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2A3A5C)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              const Color(0xFF4A9EFF).withOpacity(0.15),
                          child: Text(
                            (driver['name'] as String? ?? 'D').isNotEmpty
                                ? (driver['name'] as String)[0].toUpperCase()
                                : 'D',
                            style: const TextStyle(
                                color: Color(0xFF4A9EFF),
                                fontWeight: FontWeight.w800,
                                fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(driver['name'] ?? 'Driver',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              Text(driver['phone'] ?? '',
                                  style: const TextStyle(
                                      color: Color(0xFF8892A4),
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        // Call button
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF2ECC71).withOpacity(0.15),
                              border: Border.all(
                                  color: const Color(0xFF2ECC71)
                                      .withOpacity(0.4)),
                            ),
                            child: const Icon(Icons.phone_rounded,
                                color: Color(0xFF2ECC71), size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stops list
                  const SizedBox(height: 16),
                  _StopsList(
                      stops: (route['stops'] as List?) ?? [],
                      busPosition: _busPosition),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated pulse dot ─────────────────────────────────────────────────────
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
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(
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
          decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
        ),
      );
}

// ── Info chip ──────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;

  const _InfoChip(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
                    fontSize: 11,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF8892A4), fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

// ── Stops list at bottom ───────────────────────────────────────────────────
class _StopsList extends StatelessWidget {
  final List stops;
  final LatLng busPosition;

  const _StopsList({required this.stops, required this.busPosition});

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Route Stops',
            style: TextStyle(
                color: Color(0xFF8892A4),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: stops.length,
            itemBuilder: (_, i) {
              final stop  = stops[i] as Map;
              final isFirst = i == 0;
              final isLast  = i == stops.length - 1;
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isFirst || isLast
                      ? const Color(0xFFFF6B35).withOpacity(0.15)
                      : const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isFirst || isLast
                        ? const Color(0xFFFF6B35).withOpacity(0.4)
                        : const Color(0xFF2A3A5C),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isFirst
                          ? Icons.school_rounded
                          : isLast
                              ? Icons.home_rounded
                              : Icons.location_on_rounded,
                      size: 12,
                      color: isFirst || isLast
                          ? const Color(0xFFFF6B35)
                          : const Color(0xFF8892A4),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      stop['name'] ?? 'Stop ${i + 1}',
                      style: TextStyle(
                        color: isFirst || isLast
                            ? const Color(0xFFFF6B35)
                            : const Color(0xFF8892A4),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
