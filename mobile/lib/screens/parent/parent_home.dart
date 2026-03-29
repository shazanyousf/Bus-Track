import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';
import 'bus_list_screen.dart';
import 'registration_screen.dart';
import 'my_registrations_screen.dart';
import 'live_tracking_screen.dart';

class ParentHome extends StatefulWidget {
  const ParentHome({super.key});

  @override
  State<ParentHome> createState() => _ParentHomeState();
}

class _ParentHomeState extends State<ParentHome> {
  int _currentIndex = 0;
  List _registrations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthService>();
    try {
      final regs = await ApiService.getRegistrations(auth.token!);
      setState(() {
        _registrations = regs;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final approved = _registrations.where((r) => r['status'] == 'approved').toList();
    final pending  = _registrations.where((r) => r['status'] == 'pending').toList();

    final pages = [
      _DashboardTab(
        userName: auth.user?['name'] ?? 'Parent',
        approved: approved,
        pending: pending,
        loading: _loading,
        onRefresh: _loadData,
        onRegister: () => setState(() => _currentIndex = 2),
        onViewBuses: () => setState(() => _currentIndex = 1),
      ),
      approved.isNotEmpty
          ? _AssignedBusPage(registration: approved.first)
          : const BusListScreen(),
      RegistrationScreen(onDone: () => setState(() => _currentIndex = 0)),
      const MyRegistrationsScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF16213E),
          border: Border(top: BorderSide(color: Color(0xFF2A3A5C))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.transparent,
          selectedItemColor: const Color(0xFFFF6B35),
          unselectedItemColor: const Color(0xFF8892A4),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.directions_bus_rounded), label: 'Buses'),
            BottomNavigationBarItem(icon: Icon(Icons.app_registration_rounded), label: 'Register'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'My Requests'),
          ],
        ),
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final String userName;
  final List approved;
  final List pending;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onRegister;
  final VoidCallback onViewBuses;

  const _DashboardTab({
    required this.userName,
    required this.approved,
    required this.pending,
    required this.loading,
    required this.onRefresh,
    required this.onRegister,
    required this.onViewBuses,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => onRefresh(),
        color: const Color(0xFFFF6B35),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Good Day,',
                            style: TextStyle(color: Color(0xFF8892A4), fontSize: 14)),
                        Text(userName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  _Avatar(name: userName),
                ],
              ),
              const SizedBox(height: 24),

              // Stats row
              Row(
                children: [
                  _StatCard(
                    label: 'Active Buses',
                    value: approved.length.toString(),
                    color: const Color(0xFF2ECC71),
                    icon: Icons.directions_bus_rounded,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Pending',
                    value: pending.length.toString(),
                    color: const Color(0xFFF7C948),
                    icon: Icons.hourglass_top_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Assigned bus card
              if (approved.isNotEmpty) ...[
                const Text('Assigned Bus',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _AssignedBusCard(registration: approved.first),
                const SizedBox(height: 24),
              ],

              // Quick actions
              const Text('Quick Actions',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.app_registration_rounded,
                      label: 'Register Bus',
                      color: const Color(0xFFFF6B35),
                      onTap: onRegister,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.directions_bus_rounded,
                      label: approved.isNotEmpty ? 'My Bus' : 'View Buses',
                      color: const Color(0xFF4A9EFF),
                      onTap: onViewBuses,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF16213E),
            title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
            content: const Text('Are you sure you want to sign out?',
                style: TextStyle(color: Color(0xFF8892A4))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Sign Out',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          await context.read<AuthService>().logout();
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const LoginScreen()));
        }
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFFF8C55)]),
        ),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'P',
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;

  const _StatCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A3A5C)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 26, fontWeight: FontWeight.w900)),
            Text(label,
                style: const TextStyle(color: Color(0xFF8892A4), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _AssignedBusCard extends StatelessWidget {
  final Map registration;
  const _AssignedBusCard({required this.registration});

  Map _safeMap(dynamic value) {
    if (value is Map) return value as Map;
    return {};
  }

  Future<void> _makeCall(String? phone, BuildContext context) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Phone number not available'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not launch dialer'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _trackBus(Map bus, BuildContext context) {
    final busId = bus['_id'] ?? bus['busNumber'];
    if (busId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bus ID unavailable for tracking'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LiveTrackingScreen(bus: bus)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bus    = _safeMap(registration['busId']);
    final driver = _safeMap(bus['driverId']);
    final route  = _safeMap(registration['routeId']).isNotEmpty
        ? _safeMap(registration['routeId'])
        : _safeMap(bus['routeId']);

    return Container(
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
                  color: const Color(0xFFFF6B35).withOpacity(0.15),
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
                    Text(bus['busNumber'] ?? 'N/A',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                    Text(route['routeName'] ?? 'Route not assigned',
                        style: const TextStyle(
                            color: Color(0xFF8892A4), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF2ECC71).withOpacity(0.4)),
                ),
                child: const Text('Active',
                    style: TextStyle(
                        color: Color(0xFF2ECC71),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF2A3A5C)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('👨', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver['name'] ?? 'Not assigned',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    Text(driver['phone'] ?? '',
                        style: const TextStyle(
                            color: Color(0xFF8892A4), fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _makeCall(driver['phone'] as String?, context),
                icon: const Icon(Icons.phone_rounded,
                    color: Color(0xFF2ECC71), size: 22),
              ),
              IconButton(
                onPressed: () => _trackBus(bus, context),
                icon: const Icon(Icons.location_on_rounded,
                    color: Color(0xFF4A9EFF), size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssignedBusPage extends StatelessWidget {
  final Map registration;
  const _AssignedBusPage({required this.registration});

  Map _safeMap(dynamic value) {
    if (value is Map) return value as Map;
    return {};
  }

  void _trackBus(Map bus, BuildContext context) {
    final busId = bus['_id'] ?? bus['busNumber'];
    if (busId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bus ID unavailable for tracking'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LiveTrackingScreen(bus: bus)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bus    = _safeMap(registration['busId']);
    final route  = _safeMap(registration['routeId']).isNotEmpty
        ? _safeMap(registration['routeId'])
        : _safeMap(bus['routeId']);
    final driver = _safeMap(bus['driverId']);
    final stops  = (route['stops'] as List?) ?? [];

    return SafeArea(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_bus_rounded, color: Color(0xFFFF6B35), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bus['busNumber'] ?? 'My Bus',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('Route: ${route['routeName'] ?? 'N/A'}',
                          style: const TextStyle(color: Color(0xFF8892A4), fontSize: 13)),
                      Text('Code: ${bus['busNumber'] ?? 'N/A'}',
                          style: const TextStyle(color: Color(0xFF8892A4), fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF2A3A5C)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Driver', style: TextStyle(color: Color(0xFF8892A4), fontSize: 12)),
                  const SizedBox(height: 10),
                  Text(driver['name'] ?? 'Not assigned', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  if (driver['phone'] != null && driver['phone'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(driver['phone'], style: const TextStyle(color: Color(0xFF8892A4), fontSize: 13)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (stops.isNotEmpty) ...[
              const Text('Route Stops', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...List.generate(stops.length, (i) {
                final stop = stops[i] as Map;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2A3A5C)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF4A9EFF).withOpacity(0.2),
                        child: Text('${i + 1}', style: const TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(stop['name'] ?? 'Stop', style: const TextStyle(color: Colors.white, fontSize: 14)),
                      ),
                    ],
                  ),
                );
              }),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF2A3A5C)),
                ),
                child: const Text('Route stops are not configured yet. Please contact the admin.',
                    style: TextStyle(color: Color(0xFF8892A4), fontSize: 13)),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _trackBus(bus, context),
                icon: const Icon(Icons.location_on_rounded),
                label: const Text('Track Assigned Bus'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A9EFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
