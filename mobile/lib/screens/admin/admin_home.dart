import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';
import 'admin_buses_screen.dart';
import 'admin_requests_screen.dart';
import 'admin_drivers_screen.dart';
import 'admin_routes_screen.dart';
import 'admin_settings_screen.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _AdminDashboard(onManageDepartments: () => setState(() => _currentIndex = 5)),
      const AdminRoutesScreen(),
      const AdminBusesScreen(),
      const AdminRequestsScreen(),
      const AdminDriversScreen(),
      const AdminSettingsScreen(),
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
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.route_rounded), label: 'Routes'),
            BottomNavigationBarItem(icon: Icon(Icons.directions_bus_rounded), label: 'Buses'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment_rounded), label: 'Requests'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Drivers'),
            BottomNavigationBarItem(icon: Icon(Icons.account_tree_rounded), label: 'Departments'),
          ],
        ),
      ),
    );
  }
}

class _AdminDashboard extends StatefulWidget {
  const _AdminDashboard({required this.onManageDepartments});

  final VoidCallback onManageDepartments;

  @override
  State<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<_AdminDashboard> {
  List _buses         = [];
  List _registrations = [];
  List _drivers       = [];
  bool _loading       = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthService>();
    try {
      final results = await Future.wait([
        ApiService.getBuses(),
        ApiService.getRegistrations(auth.token!),
        ApiService.getDrivers(auth.token!),
      ]);
      setState(() {
        _buses         = results[0];
        _registrations = results[1];
        _drivers       = results[2];
        _loading       = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthService>();
    final pending = _registrations.where((r) => r['status'] == 'pending').length;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
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
                        const Text('Admin Panel',
                            style: TextStyle(color: Color(0xFF8892A4), fontSize: 13)),
                        Text(auth.user?['name'] ?? 'Administrator',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: const Color(0xFF16213E),
                          title: const Text('Sign Out',
                              style: TextStyle(color: Colors.white)),
                          content: const Text('Sign out of admin panel?',
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
                            colors: [Color(0xFF7B52FF), Color(0xFF4A9EFF)]),
                      ),
                      child: const Center(
                          child: Icon(Icons.shield_rounded,
                              color: Colors.white, size: 22)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_loading)
                const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
              else ...[
                // Stats grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    _StatCard(label: 'Total Buses',   value: '${_buses.length}',         color: const Color(0xFFFF6B35), icon: Icons.directions_bus_rounded),
                    _StatCard(label: 'Pending',        value: '$pending',                  color: const Color(0xFFF7C948), icon: Icons.hourglass_top_rounded),
                    _StatCard(label: 'Drivers',        value: '${_drivers.length}',        color: const Color(0xFF4A9EFF), icon: Icons.person_rounded),
                    _StatCard(label: 'Total Requests', value: '${_registrations.length}',  color: const Color(0xFF2ECC71), icon: Icons.assignment_rounded),
                  ],
                ),
                const SizedBox(height: 24),


                const Text('Recent Requests',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ..._registrations.take(5).map((reg) {
                  final bus    = reg['busId']  as Map? ?? {};
                  final status = reg['status'] as String? ?? 'pending';
                  Color sc     = status == 'approved'
                      ? const Color(0xFF2ECC71)
                      : status == 'rejected'
                          ? const Color(0xFFE74C3C)
                          : const Color(0xFFF7C948);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16213E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2A3A5C)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(bus['busNumber'] ?? 'N/A',
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.w700)),
                              Text(
                                (reg['requestDate'] as String? ?? '').length >= 10
                                    ? (reg['requestDate'] as String).substring(0, 10)
                                    : '',
                                style: const TextStyle(
                                    color: Color(0xFF8892A4), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: sc.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: sc.withOpacity(0.4)),
                          ),
                          child: Text(
                            status[0].toUpperCase() + status.substring(1),
                            style: TextStyle(
                                color: sc, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
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
      {required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3A5C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color, fontSize: 26, fontWeight: FontWeight.w900)),
              Text(label,
                  style: const TextStyle(color: Color(0xFF8892A4), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
