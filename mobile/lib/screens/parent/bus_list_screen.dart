import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'bus_detail_screen.dart';

class BusListScreen extends StatefulWidget {
  const BusListScreen({super.key});

  @override
  State<BusListScreen> createState() => _BusListScreenState();
}

class _BusListScreenState extends State<BusListScreen> {
  List _buses = [];
  List _routes = [];
  String? _selectedRouteId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getBuses(routeId: _selectedRouteId),
        ApiService.getRoutes(),
      ]);
      setState(() {
        _buses  = results[0];
        _routes = results[1];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Available Buses',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${_buses.length} buses found',
                    style: const TextStyle(
                        color: Color(0xFF8892A4), fontSize: 13)),
                const SizedBox(height: 16),
                // Route filter chips
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'All Routes',
                        selected: _selectedRouteId == null,
                        onTap: () {
                          setState(() => _selectedRouteId = null);
                          _loadAll();
                        },
                      ),
                      ..._routes.map((r) => _FilterChip(
                            label: r['routeName'] ?? '',
                            selected: _selectedRouteId == r['_id'],
                            onTap: () {
                              setState(() => _selectedRouteId = r['_id']);
                              _loadAll();
                            },
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFFF6B35)))
                : RefreshIndicator(
                    onRefresh: _loadAll,
                    color: const Color(0xFFFF6B35),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _buses.length,
                      itemBuilder: (_, i) => _BusCard(
                        bus: _buses[i],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BusDetailScreen(bus: _buses[i]),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFF6B35)
              : const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFFFF6B35)
                : const Color(0xFF2A3A5C),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF8892A4),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _BusCard extends StatelessWidget {
  final Map bus;
  final VoidCallback onTap;

  const _BusCard({required this.bus, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final available = bus['availableSeats'] ?? 0;
    final total     = bus['totalSeats'] ?? 1;
    final driver    = bus['driverId'] as Map? ?? {};
    final route     = bus['routeId']  as Map? ?? {};
    final pct       = (total - available) / total;

    Color seatColor = available == 0
        ? const Color(0xFFE74C3C)
        : available < 8
            ? const Color(0xFFF7C948)
            : const Color(0xFF2ECC71);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF2A3A5C)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                      child: Text('🚌', style: TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bus['busNumber'] ?? '',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      Text(route['routeName'] ?? 'No route',
                          style: const TextStyle(
                              color: Color(0xFF8892A4), fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$available',
                        style: TextStyle(
                            color: seatColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                    const Text('seats left',
                        style: TextStyle(
                            color: Color(0xFF8892A4), fontSize: 10)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: const Color(0xFF2A3A5C),
                valueColor: AlwaysStoppedAnimation<Color>(seatColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('👨', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(driver['name'] ?? 'No driver assigned',
                      style: const TextStyle(
                          color: Color(0xFF8892A4), fontSize: 12)),
                ),
                Text('${(total - available)}/$total occupied',
                    style: const TextStyle(
                        color: Color(0xFF8892A4), fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
