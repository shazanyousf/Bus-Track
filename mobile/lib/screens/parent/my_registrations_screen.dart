import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class MyRegistrationsScreen extends StatefulWidget {
  const MyRegistrationsScreen({super.key});

  @override
  State<MyRegistrationsScreen> createState() => _MyRegistrationsScreenState();
}

class _MyRegistrationsScreenState extends State<MyRegistrationsScreen> {
  List _registrations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    try {
      final data = await ApiService.getRegistrations(auth.token!);
      setState(() { _registrations = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'approved':  return const Color(0xFF2ECC71);
      case 'rejected':  return const Color(0xFFE74C3C);
      case 'cancelled': return const Color(0xFFF7C948);
      default:          return const Color(0xFFF7C948);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Requests',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                Text('${_registrations.length} total registrations',
                    style: const TextStyle(color: Color(0xFF8892A4), fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: const Color(0xFFFF6B35),
                    child: _registrations.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('🚌', style: TextStyle(fontSize: 48)),
                                SizedBox(height: 16),
                                Text('No registrations yet',
                                    style: TextStyle(color: Color(0xFF8892A4))),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _registrations.length,
                            itemBuilder: (_, i) {
                              final reg    = _registrations[i] as Map;
                              Map _safeMap(dynamic v) => v is Map ? v as Map : {};
                              final bus    = _safeMap(reg['busId']);
                              final route  = _safeMap(reg['routeId']).isNotEmpty
                                  ? _safeMap(reg['routeId'])
                                  : _safeMap(bus['routeId']);
                              final driver = _safeMap(bus['driverId']);
                              final status = reg['status'] as String? ?? 'pending';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16213E),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: const Color(0xFF2A3A5C)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(bus['busNumber'] ?? 'N/A',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _statusColor(status).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                                color: _statusColor(status).withOpacity(0.4)),
                                          ),
                                          child: Text(
                                            status[0].toUpperCase() + status.substring(1),
                                            style: TextStyle(
                                                color: _statusColor(status),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(route['routeName'] ?? 'No route',
                                        style: const TextStyle(
                                            color: Color(0xFF8892A4), fontSize: 13)),
                                    const SizedBox(height: 8),
                                    const Divider(color: Color(0xFF2A3A5C)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Text('👨', style: TextStyle(fontSize: 14)),
                                        const SizedBox(width: 8),
                                        Text(driver['name'] ?? 'Not assigned',
                                            style: const TextStyle(
                                                color: Color(0xFF8892A4), fontSize: 12)),
                                        const Spacer(),
                                        Text(
                                          (reg['requestDate'] as String? ?? '').length >= 10
                                              ? (reg['requestDate'] as String).substring(0, 10)
                                              : '',
                                          style: const TextStyle(
                                              color: Color(0xFF8892A4), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    if (status == 'rejected' &&
                                        (reg['remarks'] as String? ?? '').isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE74C3C).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                              color: const Color(0xFFE74C3C).withOpacity(0.3)),
                                        ),
                                        child: Text('Reason: ${reg['remarks']}',
                                            style: const TextStyle(
                                                color: Color(0xFFE74C3C), fontSize: 12)),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
