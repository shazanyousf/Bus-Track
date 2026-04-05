import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'registration_screen.dart';
import 'live_tracking_screen.dart';

class BusDetailScreen extends StatelessWidget {
  final Map bus;
  const BusDetailScreen({super.key, required this.bus});

  Future<void> _makeCall(String? phone, BuildContext context) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Phone number not available'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    final sanitizedPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: sanitizedPhone);
    if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not launch dialer'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _trackBus(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LiveTrackingScreen(bus: bus)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driver    = bus['driverId'] as Map? ?? {};
    final route     = bus['routeId']  as Map? ?? {};
    final stops     = (route['stops']  as List?) ?? [];
    final available = bus['availableSeats'] ?? 0;
    final total     = bus['totalSeats']     ?? 0;
    final occupied  = total - available;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        title: Text(bus['busNumber'] ?? 'Bus Detail',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bus info card
            _InfoCard(
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                        child: Text('🚌', style: TextStyle(fontSize: 30))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bus['busNumber'] ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                        Text(route['routeName'] ?? 'No route assigned',
                            style: const TextStyle(
                                color: Color(0xFFFF6B35), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Seat stats
            Row(
              children: [
                _StatTile(label: 'Total Seats', value: '$total', color: Colors.white),
                const SizedBox(width: 12),
                _StatTile(label: 'Available', value: '$available', color: const Color(0xFF2ECC71)),
                const SizedBox(width: 12),
                _StatTile(label: 'Occupied', value: '$occupied', color: const Color(0xFFE74C3C)),
              ],
            ),
            const SizedBox(height: 16),

            // Seat map
            _InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Seat Map',
                      style: TextStyle(
                          color: Color(0xFF8892A4),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(total, (i) {
                      final isTaken = i < occupied;
                      return Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isTaken
                              ? const Color(0xFFE74C3C).withOpacity(0.7)
                              : const Color(0xFF2ECC71).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Legend(color: const Color(0xFF2ECC71), label: 'Available'),
                      const SizedBox(width: 16),
                      _Legend(color: const Color(0xFFE74C3C), label: 'Occupied'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Driver card
            _InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DRIVER DETAILS',
                      style: TextStyle(
                          color: Color(0xFF8892A4),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFF4A9EFF).withOpacity(0.2),
                        child: Text(
                          (driver['name'] as String? ?? 'D').isNotEmpty
                              ? (driver['name'] as String)[0]
                              : 'D',
                          style: const TextStyle(
                              color: Color(0xFF4A9EFF),
                              fontSize: 20,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(driver['name'] ?? 'Not assigned',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16)),
                            Text(driver['phone'] ?? '',
                                style: const TextStyle(
                                    color: Color(0xFF8892A4), fontSize: 13)),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => _makeCall(driver['phone'] as String?, context),
                            icon: const Icon(Icons.phone_rounded,
                                color: Color(0xFF2ECC71), size: 18),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => _trackBus(context),
                            icon: const Icon(Icons.location_on_rounded,
                                color: Color(0xFF4A9EFF), size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Route stops
            if (stops.isNotEmpty) ...[
              _InfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ROUTE STOPS',
                        style: TextStyle(
                            color: Color(0xFF8892A4),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                    const SizedBox(height: 14),
                    ...List.generate(stops.length, (i) {
                      final stop = stops[i] as Map;
                      final isFirst = i == 0;
                      final isLast  = i == stops.length - 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isFirst || isLast
                                        ? const Color(0xFFFF6B35)
                                        : const Color(0xFF4A9EFF).withOpacity(0.2),
                                    border: Border.all(
                                      color: isFirst || isLast
                                          ? const Color(0xFFFF6B35)
                                          : const Color(0xFF4A9EFF),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text('${i + 1}',
                                        style: TextStyle(
                                            color: isFirst || isLast
                                                ? Colors.white
                                                : const Color(0xFF4A9EFF),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                                if (!isLast)
                                  Container(
                                      width: 2,
                                      height: 16,
                                      color: const Color(0xFF2A3A5C)),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(stop['name'] ?? '',
                                  style: TextStyle(
                                      color: isFirst
                                          ? const Color(0xFFFF6B35)
                                          : Colors.white,
                                      fontWeight: isFirst
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      fontSize: 14)),
                            ),
                            if (isFirst)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B35).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFFF6B35)
                                          .withOpacity(0.3)),
                                ),
                                child: const Text('Start',
                                    style: TextStyle(
                                        color: Color(0xFFFF6B35),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Register button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: available == 0
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RegistrationScreen(preselectedBus: bus),
                          ),
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  disabledBackgroundColor: const Color(0xFF2A3A5C),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  available == 0 ? 'Bus Full — Join Waitlist' : 'Register for This Bus →',
                  style: TextStyle(
                    color: available == 0
                        ? const Color(0xFF8892A4)
                        : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A3A5C)),
      ),
      child: child,
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final Color color;

  const _StatTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A3A5C)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF8892A4), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label,
            style:
                const TextStyle(color: Color(0xFF8892A4), fontSize: 11)),
      ],
    );
  }
}
