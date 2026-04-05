import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/socket_service.dart';

class LiveTrackingScreen extends StatefulWidget {
  final Map bus;

  const LiveTrackingScreen({super.key, required this.bus});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final MapController _mapController = MapController();
  final SocketService _socket = SocketService();

  LatLng _busPosition = const LatLng(24.8607, 67.0011); // default Karachi
  double _speed       = 0;
  String _lastUpdate  = 'Waiting for signal...';
  bool   _connected   = false;
  Map<String, dynamic>? _lastAlert;

  List<Marker>   _markers   = [];
  List<Polyline> _polylines = [];

  // Build route stop markers from bus data
  Map _safeMap(dynamic value) => value is Map ? value : {};
  List _safeList(dynamic value) => value is List ? value : [];

  List<LatLng> get _stopPositions {
    final route = _safeMap(widget.bus['routeId']);
    final stops = _safeList(route['stops']);
    return stops.map<LatLng>((s) {
      if (s is! Map) return const LatLng(24.8607, 67.0011);
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
    final route = _safeMap(widget.bus['routeId']);
    final stops = _safeList(route['stops']);
    final List<Marker> markers = [];

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i] is Map ? stops[i] as Map : {};
      final lat  = (stop['latitude']  as num?)?.toDouble() ?? 24.8607;
      final lng  = (stop['longitude'] as num?)?.toDouble() ?? 67.0011;
      markers.add(
        Marker(
          key: ValueKey('stop_$i'),
          point: LatLng(lat, lng),
          width: 40,
          height: 40,
          builder: (ctx) => Icon(
            Icons.location_on,
            color: i == 0
                ? Colors.green
                : i == stops.length - 1
                    ? Colors.red
                    : Colors.blue,
            size: 28,
          ),
        ),
      );
    }

    // Route polyline
    final stopPositions = _stopPositions;
    if (stopPositions.length >= 2) {
      _polylines = [
        Polyline(
          points: stopPositions,
          color: const Color(0xFF4A9EFF),
          strokeWidth: 4,
        ),
      ];
    }

    setState(() => _markers = markers);
  }

  void _startListening() {
    final busId = widget.bus['_id'] as String? ??
        widget.bus['busNumber'] as String? ??
        'BUS001';

    _socket.listenToBusAlerts(busId, (alert) {
      if (!mounted) return;
      setState(() => _lastAlert = alert);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${alert['type'].toString().toUpperCase()}: ${alert['message']}'),
        backgroundColor: const Color(0xFFE74C3C),
        duration: const Duration(seconds: 5),
      ));
    });

    _socket.listenToBus(busId, (data) async {
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      final speed = (data['speed']     as num?)?.toDouble() ?? 0;

      if (lat == null || lng == null) return;

      final newPos = LatLng(lat, lng);

      _mapController.move(newPos, 15);

      setState(() {
        _busPosition = newPos;
        _speed       = speed;
        _connected   = true;
        _lastUpdate  = _formatTime(data['timestamp'] as String?);

        // Update bus marker
        _markers.removeWhere((m) => m.key == const ValueKey('bus'));
        _markers.add(
          Marker(
            key: const ValueKey('bus'),
            point: newPos,
            width: 40,
            height: 40,
            builder: (ctx) => const Icon(
              Icons.directions_bus_rounded,
              color: Colors.orange,
              size: 32,
            ),
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
    _socket.stopListeningAlerts(busId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driver = _safeMap(widget.bus['driverId']);
    final route  = _safeMap(widget.bus['routeId']);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _busPosition,
              zoom: 15,
              minZoom: 3,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.bustrack',
              ),
              if (_polylines.isNotEmpty)
                PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: _markers),
            ],
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
                        color: const Color(0xFF0F0F1A).withOpacity(0.55),
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
          DraggableScrollableSheet(
            initialChildSize: 0.30,
            minChildSize: 0.18,
            maxChildSize: 0.4,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F1A).withOpacity(0.5),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  border: const Border(
                      top: BorderSide(color: Color(0xFF2A3A5C))),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A3A5C),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_lastAlert != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE74C3C).withOpacity(0.20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.35)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_rounded, color: Color(0xFFE74C3C)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_lastAlert?['type'].toString().toUpperCase()}: ${_lastAlert?['message']}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

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
                              (driver['name'] is String && (driver['name'] as String).isNotEmpty)
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
                              width: 42,
                              height: 42,
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

                    const SizedBox(height: 16),
                    _StopsList(
                        stops: _safeList(route['stops']),
                        busPosition: _busPosition),
                  ],
                ),
              );
            },
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
