import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';
import '../account_screen.dart';
import 'admin_buses_screen.dart';
import 'admin_requests_screen.dart';
import 'admin_drivers_screen.dart';
import 'admin_routes_screen.dart';
import 'admin_users_screen.dart';
import 'admin_settings_screen.dart';
import '../shared/notices_screen.dart';

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
      _AdminDashboard(
        onOpenBuses: () => setState(() => _currentIndex = 2),
        onOpenRequests: () => setState(() => _currentIndex = 3),
        onOpenDrivers: () => setState(() => _currentIndex = 4),
        onManageDepartments: () => setState(() => _currentIndex = 6),
        onManageNotices: () => setState(() => _currentIndex = 5),
      ),
      const AdminRoutesScreen(),
      const AdminBusesScreen(),
      const AdminRequestsScreen(),
      const AdminDriversScreen(),
      const AdminUsersScreen(),
      const NoticesScreen(adminMode: true),
      const AdminSettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
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
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.route_rounded), label: 'Routes'),
            BottomNavigationBarItem(icon: Icon(Icons.directions_bus_rounded), label: 'Buses'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment_rounded), label: 'Requests'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Drivers'),
            BottomNavigationBarItem(icon: Icon(Icons.group_rounded), label: 'Users'),
            BottomNavigationBarItem(icon: Icon(Icons.campaign_rounded), label: 'Notices'),
            BottomNavigationBarItem(icon: Icon(Icons.account_tree_rounded), label: 'Departments'),
          ],
        ),
      ),
    );
  }
}

class _AdminDashboard extends StatefulWidget {
  const _AdminDashboard({
    required this.onOpenBuses,
    required this.onOpenRequests,
    required this.onOpenDrivers,
    required this.onManageDepartments,
    required this.onManageNotices,
  });

  final VoidCallback onOpenBuses;
  final VoidCallback onOpenRequests;
  final VoidCallback onOpenDrivers;
  final VoidCallback onManageDepartments;
  final VoidCallback onManageNotices;

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
    final adminName = (auth.user?['name'] as String?)?.trim();

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A9EFF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: const Color(0xFF4A9EFF).withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insights_rounded, color: Color(0xFF79BCFF), size: 15),
                        SizedBox(width: 6),
                        Text(
                          'Admin Overview',
                          style: TextStyle(
                            color: Color(0xFF94CBFF),
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
              const SizedBox(height: 12),

              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF16213E), Color(0xFF132742)],
                  ),
                  border: Border.all(color: const Color(0xFF2A3A5C)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Admin Panel',
                              style: TextStyle(color: Color(0xFF8892A4), fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(adminName == null || adminName.isEmpty ? 'Administrator' : adminName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final choice = await showModalBottomSheet<String>(
                          context: context,
                          backgroundColor: const Color(0xFF16213E),
                          builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            ListTile(leading: const Icon(Icons.person), title: const Text('My Account'), onTap: () => Navigator.pop(context, 'account')),
                            ListTile(leading: const Icon(Icons.logout), title: const Text('Sign Out'), onTap: () => Navigator.pop(context, 'logout')),
                          ])),
                        );
                        if (choice == 'account' && context.mounted) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
                          return;
                        }
                        if (choice == 'logout') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: const Color(0xFF16213E),
                              title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                              content: const Text('Sign out of admin panel?', style: TextStyle(color: Color(0xFF8892A4))),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            await context.read<AuthService>().logout();
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                          }
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
              ),
              const SizedBox(height: 24),

              if (_loading)
                const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
              else ...[
                // Stats grid
                const _SectionHeader(
                  title: 'Live Snapshot',
                  subtitle: 'Tap a metric card to jump to that section',
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  children: [
                    _StatCard(
                      label: 'Total Buses',
                      value: '${_buses.length}',
                      color: const Color(0xFFFF6B35),
                      icon: Icons.directions_bus_rounded,
                      onTap: widget.onOpenBuses,
                    ),
                    _StatCard(
                      label: 'Pending',
                      value: '$pending',
                      color: const Color(0xFFF7C948),
                      icon: Icons.hourglass_top_rounded,
                      onTap: widget.onOpenRequests,
                    ),
                    _StatCard(
                      label: 'Drivers',
                      value: '${_drivers.length}',
                      color: const Color(0xFF4A9EFF),
                      icon: Icons.person_rounded,
                      onTap: widget.onOpenDrivers,
                    ),
                    _StatCard(
                      label: 'Total Requests',
                      value: '${_registrations.length}',
                      color: const Color(0xFF2ECC71),
                      icon: Icons.assignment_rounded,
                      onTap: widget.onOpenRequests,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const _SectionHeader(
                  title: 'Management',
                  subtitle: 'Fast actions for notices and departments',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.campaign_rounded,
                        label: 'Notice Board',
                        color: const Color(0xFFFF6B35),
                        onTap: widget.onManageNotices,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.account_tree_rounded,
                        label: 'Manage Departments',
                        color: const Color(0xFF4A9EFF),
                        onTap: widget.onManageDepartments,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),


                const _SectionHeader(
                  title: 'Recent Requests',
                  subtitle: 'Latest registration updates from parents',
                ),
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
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF16213E), Color(0xFF1A2A4D)],
                      ),
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
                            color: sc.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: sc.withValues(alpha: 0.4)),
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
  final VoidCallback? onTap;

  const _StatCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF16213E),
                color.withValues(alpha: 0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2A3A5C)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded,
                      color: color.withValues(alpha: 0.8), size: 16),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          color: color, fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(label,
                      style: const TextStyle(color: Color(0xFF8892A4), fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF16213E),
                color.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: color.withValues(alpha: 0.85), size: 18),
            ],
          ),
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
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF8892A4),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
