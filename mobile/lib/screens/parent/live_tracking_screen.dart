// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../services/socket_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class LiveTrackingScreen extends StatefulWidget {
  final Map bus;
  final bool adminMode;

  const LiveTrackingScreen({super.key, required this.bus, this.adminMode = false});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final MapController _mapController = MapController();
  final SocketService _socket = SocketService();

  LatLng _busPosition = const LatLng(24.8607, 67.0011);
  double _speed = 0;
  String _lastUpdate = 'Waiting for signal...';
  bool _connected = false;
  bool _tripCompleted = false;
  String? _tripId;
  Map<String, dynamic>? _lastAlert;

  List<Marker> _markers = [];
  List<Polyline> _polylines = [];

  Map _safeMap(dynamic value) => value is Map ? value : {};
  List _safeList(dynamic value) => value is List ? value : [];

  List<LatLng> get _stopPositions {
    final route = _safeMap(widget.bus['routeId']);
    final stops = _safeList(route['stops']);
    return stops.map<LatLng>((stop) {
      if (stop is! Map) return const LatLng(24.8607, 67.0011);
      return LatLng(
        (stop['latitude'] as num?)?.toDouble() ?? 24.8607,
        (stop['longitude'] as num?)?.toDouble() ?? 67.0011,
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
      final lat = (stop['latitude'] as num?)?.toDouble() ?? 24.8607;
      final lng = (stop['longitude'] as num?)?.toDouble() ?? 67.0011;
      markers.add(
        Marker(
          key: ValueKey('stop_$i'),
          point: LatLng(lat, lng),
          width: 40,
          height: 40,
          builder: (ctx) => Icon(
            Icons.location_on,
            color: i == 0
                ? const Color(0xFF2ECC71)
                : i == stops.length - 1
                    ? const Color(0xFFE74C3C)
                    : const Color(0xFF4A9EFF),
            size: 28,
          ),
        ),
      );
    }

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

  Future<void> _startListening() async {
    final busId = widget.bus['_id'] as String? ??
        widget.bus['busNumber'] as String? ??
        'BUS001';

    _socket.listenToTripStarted((data) {
      if (data['busId']?.toString() != busId || !mounted) return;
      _startListening();
    });

    _socket.listenToBusAlerts(busId, (alert) {
      if (!mounted) return;
      setState(() => _lastAlert = alert);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${alert['type'].toString().toUpperCase()}: ${alert['message']}',
          ),
          backgroundColor: const Color(0xFFE74C3C),
          duration: const Duration(seconds: 5),
        ),
      );
    });

    _socket.listenToBus(busId, (data) {
      if (_tripCompleted || _tripId == null || data['tripId']?.toString() != _tripId) return;
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      final speed = (data['speed'] as num?)?.toDouble() ?? 0;

      if (lat == null || lng == null) return;

      final newPos = LatLng(lat, lng);
      _mapController.move(newPos, 15);

      setState(() {
        _busPosition = newPos;
        _speed = speed;
        _connected = true;
        _lastUpdate = _formatTime(data['timestamp'] as String?);

        _markers.removeWhere((marker) => marker.key == const ValueKey('bus'));
        _markers.add(
          Marker(
            key: const ValueKey('bus'),
            point: newPos,
            width: 40,
            height: 40,
            builder: (ctx) => const Icon(
              Icons.directions_bus_rounded,
              color: Color(0xFFFFA15F),
              size: 32,
            ),
          ),
        );
      });
    });

    try {
      final token = context.read<AuthService>().token;
      if (token == null) throw Exception('Not authenticated');
      final activeTrip = await ApiService.getActiveTrip(busId, token);
      if (!mounted) return;
      setState(() {
        _tripId = activeTrip['tripId']?.toString();
        _tripCompleted = false;
        _lastUpdate = 'Waiting for signal...';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tripId = null;
        _tripCompleted = true;
        _connected = false;
        _speed = 0;
        _lastUpdate = 'Location unavailable';
      });
    }
    _socket.requestBusLocation(busId);
    _socket.listenToTripCompleted((data) {
      if (data['busId']?.toString() != busId) return;
      if (!mounted) return;
      setState(() {
        _tripCompleted = true;
        _tripId = null;
        _connected = false;
        _speed = 0;
        _lastUpdate = 'Trip completed';
      });
    });
  }

  String _formatTime(String? iso) {
    if (iso == null) return 'Just now';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
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
    _socket.stopListeningToTripEvents();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driver = _safeMap(widget.bus['driverId']);
    final route = _safeMap(widget.bus['routeId']);
    return Scaffold(
      backgroundColor: const Color(0xFF08101D),
      body: Stack(
        children: [
          // Full-bleed map
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: _busPosition,
                zoom: 15,
                minZoom: 3,
                maxZoom: 18,
                interactiveFlags: InteractiveFlag.all,
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
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF0F172A).withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF20304A)),
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF101A2C), Color(0xFF12223B)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFF20304A)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B35)
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(12),
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
                                      widget.bus['busNumber'] ?? 'Bus',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      route['routeName'] ??
                                          'Route details unavailable',
                                      style: const TextStyle(
                                        color: Color(0xFF9AA7BE),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _connected
                                      ? const Color(0xFF2ECC71)
                                          .withValues(alpha: 0.14)
                                      : const Color(0xFFF7C948)
                                          .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: _connected
                                        ? const Color(0xFF2ECC71)
                                            .withValues(alpha: 0.32)
                                        : const Color(0xFFF7C948)
                                            .withValues(alpha: 0.32),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _PulseDot(
                                      color: _connected
                                          ? const Color(0xFF2ECC71)
                                          : const Color(0xFFF7C948),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                        _connected
                                          ? 'LIVE'
                                            : _tripCompleted && _lastUpdate == 'Trip completed'
                                              ? 'COMPLETED'
                                          : widget.adminMode
                                            ? 'LOCATION UNAVAILABLE'
                                            : 'WAITING',
                                      style: TextStyle(
                                        color: _connected
                                            ? const Color(0xFF2ECC71)
                                            : _tripCompleted && _lastUpdate == 'Trip completed'
                                              ? const Color(0xFF8892A4)
                                            : _tripCompleted && _lastUpdate == 'Trip completed'
                                              ? const Color(0xFF8892A4)
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatPill(
                        icon: Icons.speed_rounded,
                        label: 'Speed',
                        value: '${_speed.toStringAsFixed(0)} km/h',
                        accent: const Color(0xFFFF6B35),
                      ),
                      const SizedBox(width: 10),
                      _StatPill(
                        icon: Icons.access_time_rounded,
                        label: 'Updated',
                        value: _lastUpdate,
                        accent: const Color(0xFF4A9EFF),
                      ),
                      const SizedBox(width: 10),
                      _StatPill(
                        icon: Icons.airline_seat_recline_normal_rounded,
                        label: 'Seats',
                        value: '${widget.bus['availableSeats'] ?? 0} left',
                        accent: const Color(0xFF2ECC71),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.36,
            minChildSize: 0.18,
            maxChildSize: 0.68,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: const Color(0xFF20304A))),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  const _PanelHandle(),
                  const SizedBox(height: 14),
                  _SectionHeader(
                    title: 'Trip Intelligence',
                    subtitle: _connected
                        ? 'Live bus data, driver details and route stops in one view'
                        : _tripCompleted && _lastUpdate == 'Trip completed'
                          ? 'Trip completed: live location has ended'
                        : widget.adminMode
                            ? 'Location unavailable: this bus is not sending a live position'
                            : 'Waiting for the driver to broadcast location',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _MetricTile(icon: Icons.speed_rounded, label: 'Speed', value: '${_speed.toStringAsFixed(0)} km/h', accent: const Color(0xFFFF6B35)),
                      const SizedBox(width: 10),
                      _MetricTile(icon: Icons.access_time_rounded, label: 'Updated', value: _lastUpdate, accent: const Color(0xFF4A9EFF)),
                      const SizedBox(width: 10),
                      _MetricTile(icon: Icons.airline_seat_recline_normal_rounded, label: 'Seats', value: '${widget.bus['availableSeats'] ?? 0} left', accent: const Color(0xFF2ECC71)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoCard(
                    title: 'Driver',
                    leading: CircleAvatar(radius: 22, backgroundColor: const Color(0xFF4A9EFF).withOpacity(0.16), child: Text((driver['name'] is String && (driver['name'] as String).isNotEmpty) ? (driver['name'] as String)[0].toUpperCase() : 'D', style: const TextStyle(color: Color(0xFF4A9EFF), fontWeight: FontWeight.w800, fontSize: 18))),
                    trailing: GestureDetector(onTap: () {}, child: Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF2ECC71).withOpacity(0.15), border: Border.all(color: const Color(0xFF2ECC71).withOpacity(0.32))), child: const Icon(Icons.phone_rounded, color: Color(0xFF2ECC71), size: 18))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(driver['name'] ?? 'Driver', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)), const SizedBox(height: 4), Text(driver['phone'] ?? 'No phone number', style: const TextStyle(color: Color(0xFF9AA7BE), fontSize: 12))]),
                  ),
                  const SizedBox(height: 16),
                  _InfoCard(title: 'Route Stops', leading: const Icon(Icons.route_rounded, color: Color(0xFF8EC5FF)), child: _StopsList(stops: _safeList(route['stops']), busPosition: _busPosition)),
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
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
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

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1625).withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 17),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF9AA7BE),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

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
              const Color(0xFF111B2D),
              accent.withValues(alpha: 0.14),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
        ),
        child: Column(
          children: [
            Icon(icon, color: accent, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9AA7BE),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? leading;
  final Widget? trailing;

  const _InfoCard({
    required this.title,
    required this.child,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF101A2C), Color(0xFF0E1625)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF20304A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) leading!,
              if (leading != null) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF9AA7BE),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    child,
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StopsList extends StatelessWidget {
  final List stops;
  final LatLng busPosition;

  const _StopsList({required this.stops, required this.busPosition});

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) {
      return const Text(
        'No route stops available.',
        style: TextStyle(color: Color(0xFF9AA7BE), fontSize: 12),
      );
    }

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stops.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final stop = stops[index] as Map;
          final isFirst = index == 0;
          final isLast = index == stops.length - 1;
          final isCurrent = _distanceBetween(stop, busPosition) < 0.002;

          final accent = isFirst
              ? const Color(0xFF2ECC71)
              : isLast
                  ? const Color(0xFFE74C3C)
                  : isCurrent
                      ? const Color(0xFF4A9EFF)
                      : const Color(0xFF9AA7BE);

          return Container(
            width: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isFirst
                          ? Icons.school_rounded
                          : isLast
                              ? Icons.home_rounded
                              : Icons.location_on_rounded,
                      color: accent,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        stop['name'] ?? 'Stop ${index + 1}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  isFirst
                      ? 'Origin stop'
                      : isLast
                          ? 'Destination'
                          : isCurrent
                              ? 'Near current bus position'
                              : 'On route',
                  style: const TextStyle(
                    color: Color(0xFF9AA7BE),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  double _distanceBetween(Map stop, LatLng position) {
    final lat = (stop['latitude'] as num?)?.toDouble() ?? 0;
    final lng = (stop['longitude'] as num?)?.toDouble() ?? 0;
    return ((lat - position.latitude).abs() + (lng - position.longitude).abs());
  }
}
